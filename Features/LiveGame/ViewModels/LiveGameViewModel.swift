//
//  LiveGameViewModel.swift
//  BeerStats
//
//  Hält den Spielzustand und übersetzt zwischen Engine und View.
//
//  Das ViewModel enthält bewusst KEINE Regel-Logik – die liegt vollständig
//  in GameEngine. Hier passiert nur: Aktion weiterreichen, Verlauf für Undo
//  mitschreiben, Ereignisse in Anzeigetexte, Haptik und Overlays übersetzen.
//

import SwiftUI

@MainActor
final class LiveGameViewModel: ObservableObject {

    // MARK: - Veröffentlichter Zustand

    @Published private(set) var state: LiveGameState
    /// Kurzlebiges Overlay für die auffälligen Momente (Airball, Bombe, …).
    @Published private(set) var highlight: Highlight?
    /// Mitlaufendes Protokoll, neuester Eintrag zuerst.
    @Published private(set) var eventLog: [String] = []
    @Published var isShowingReRackSheet = false
    @Published private(set) var isStartingRematch = false
    @Published var errorMessage: String?

    /// Ein Schreibvorgang im laufenden Spiel ist gescheitert. Bleibt sichtbar,
    /// bis jemand ihn wegtippt – ein Hinweis, der von selbst verschwindet,
    /// wird am Tisch garantiert übersehen.
    @Published private(set) var syncWarning: String?

    /// Läuft, während das Ergebnis geschrieben wird.
    @Published private(set) var isSettling = false
    @Published private(set) var settleError: String?

    // MARK: - Unveränderliche Spieldaten

    let teams: [Team]
    let format: GameFormat

    private let playersPerTeam: Int
    /// Wechselt bei einer Revanche auf das neu angelegte Spiel.
    private var gameId: String?
    private let gameType: GameType
    private let throwRepository: ThrowRepositoryProtocol?
    private let gameRepository: GameRepositoryProtocol?
    private let profileRepository: PlayerProfileRepositoryProtocol?
    private let ownerId: String?

    /// Verhindert doppelte Auswertung: Das Spielende kann sowohl lokal als
    /// auch erneut durch den Log-Stream auftreten, gezählt werden darf es
    /// aber nur einmal.
    private var didSettleGame = false

    /// Lokale Zustands-Schnappschüsse. Sie machen Undo sofort sichtbar,
    /// unabhängig davon, ob der kompensierende Log-Eintrag schon
    /// zurückbestätigt wurde – und sie sind der einzige Undo-Weg, wenn gar
    /// kein Repository angebunden ist.
    private var history: [LiveGameState] = []
    private var highlightDismissTask: Task<Void, Never>?
    private var observationTask: Task<Void, Never>?

    // MARK: - Beerpong Extreme

    private let extreme: ExtremeSettings
    /// Geladene Becher je Team, ausgelost beim Start.
    private var loadedCups: [Set<Int>] = [[], []]
    /// Die Karte, die gerade auf dem Bildschirm liegt.
    @Published private(set) var extremeCard: ExtremeCard?

    private static let maxHistory = 60
    private static let maxLogEntries = 30

    // MARK: - Aufbau

    /// `gameId` und `throwRepository` sind optional, damit sich der Screen
    /// auch ohne Firestore betreiben lässt – etwa in SwiftUI-Previews.
    init(
        teams: [Team],
        format: GameFormat,
        playersPerTeam: Int,
        gameId: String? = nil,
        throwRepository: ThrowRepositoryProtocol? = nil,
        gameRepository: GameRepositoryProtocol? = nil,
        profileRepository: PlayerProfileRepositoryProtocol? = nil,
        ownerId: String? = nil,
        extreme: ExtremeSettings = .off
    ) {
        self.teams = teams
        self.format = format
        self.playersPerTeam = playersPerTeam
        self.gameType = playersPerTeam == 1 ? .oneVsOne : .twoVsTwo
        self.gameId = gameId
        self.throwRepository = throwRepository
        self.gameRepository = gameRepository
        self.profileRepository = profileRepository
        self.ownerId = ownerId
        self.extreme = extreme
        self.state = GameEngine.makeInitialState(format: format, playersPerTeam: playersPerTeam)

        // Welche Becher geladen sind, wird EINMAL zu Beginn ausgelost und
        // nicht bei jedem Treffer neu gewuerfelt. Sonst waere es keine
        // Eigenschaft des Bechers mehr, sondern nur eine Wahrscheinlichkeit
        // pro Wurf – und der Reiz des Modus ist gerade, dass ein bestimmter
        // Becher geladen IST und niemand weiss, welcher.
        //
        // Jedes Team hat eigene geladene Becher: Beide Racks stehen sich
        // gegenueber, und ein gemeinsamer Satz haette bedeutet, dass ein
        // Treffer auf Position 3 immer auf beiden Seiten ausloest.
        if extreme.isEnabled {
            let indices = Array(0..<format.cupCount)
            loadedCups = (0..<2).map { _ in
                Set(indices.shuffled().prefix(min(extreme.loadedCups, format.cupCount)))
            }
        }

        observeThrows()
    }

    deinit {
        observationTask?.cancel()
        highlightDismissTask?.cancel()
    }

    /// Der Log ist die Wahrheit: Sobald ein Eintrag ankommt – vom eigenen
    /// Gerät oder von einem Mitspieler – wird der Spielstand daraus neu
    /// aufgebaut.
    private func observeThrows() {
        guard let gameId, let throwRepository else { return }
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await entries in throwRepository.observeThrows(gameId: gameId) {
                var rebuilt = throwRepository.replay(
                    entries,
                    format: self.format,
                    playersPerTeam: self.playersPerTeam
                )
                // Der Bounce-Schalter ist reine Bedienung und steht bewusst
                // nicht im Log. Ohne diese Zeile würde er von jeder
                // Listener-Rückmeldung stillschweigend zurückgesetzt – man
                // schaltet scharf, Firestore bestätigt einen älteren
                // Schreibvorgang, und der Aufsetzer zählt plötzlich einfach.
                rebuilt.bounceArmed = self.state.bounceArmed

                // Firestore liefert eigene Schreibvorgänge sofort aus dem
                // lokalen Cache mit. Ein Unterschied zum aktuellen Zustand
                // bedeutet hier also: Ein Mitspieler hat etwas eingegeben.
                if rebuilt != self.state {
                    withAnimation(AppAnimation.standard) { self.state = rebuilt }
                    self.refreshLiveActivity()
                }
            }
        }
    }

    // MARK: - Aktionen

    func perform(_ action: GameAction) {
        let thrower = state.currentThrower
        let result = GameEngine.apply(action, to: state, format: format)

        guard result.state != state else { return }   // Aktion war nicht erlaubt

        // Optimistisch sofort anzeigen: Am Tisch darf zwischen Tippen und
        // sichtbarer Reaktion keine Netzwerk-Latenz liegen.
        let snapshot = state
        let previousThrower = snapshot.currentThrower
        state = result.state
        handle(result.events)
        announceThrowerChange(from: previousThrower)
        refreshLiveActivity()

        guard action.isPersistable else { return }
        history.append(snapshot)
        if history.count > Self.maxHistory { history.removeFirst() }
        persist(action, by: thrower, before: snapshot, after: result.state)
    }

    private func persist(
        _ action: GameAction,
        by thrower: PlayerRef,
        before: LiveGameState,
        after: LiveGameState
    ) {
        guard let gameId, let throwRepository else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await throwRepository.record(
                    action: action,
                    by: thrower,
                    before: before,
                    after: after,
                    gameId: gameId,
                    teams: self.teams
                )
            } catch {
                AppLogger.firestore.error("Wurf konnte nicht gespeichert werden: \(error.localizedDescription)")
                // Der Wurf steht lokal schon auf dem Schirm, im Log aber
                // nicht. Spätestens beim nächsten Nachspielen verschwindet er
                // wieder – das darf nicht unbemerkt passieren.
                self.syncWarning = "Ein Wurf wurde nicht gespeichert. Prüft die Verbindung."
            }
        }
    }

    // MARK: - Spielende auswerten

    /// Hält das Ergebnis fest und schreibt die Kennzahlen auf die Profile.
    ///
    /// Zwei bewusste Entscheidungen: Die Auswertung passiert erst am Ende
    /// und nicht nach jedem Wurf, weil der Spielstand durch Nachspielen des
    /// Logs entsteht – zurückgenommene Würfe sind darin bereits
    /// herausgerechnet. Und sie passiert erst auf ausdrückliche Bestätigung
    /// im Sieger-Screen, damit „Rückgängig" bis dahin nutzbar bleibt, ohne
    /// dass bereits geschriebene Zahlen wieder falsch würden.
    /// Gibt zurueck, ob wirklich alles geschrieben wurde.
    ///
    /// Vorher lief das in einem losgeloesten Task, waehrend sich die Ansicht
    /// bereits schloss. Scheiterte das Schreiben, waren die Zahlen des Abends
    /// weg und niemand erfuhr davon – bei einer App, deren einziger Zweck das
    /// Mitschreiben ist, die falsche Fehlerkultur.
    ///
    /// `didSettleGame` wird erst bei Erfolg gesetzt, sonst waere ein zweiter
    /// Versuch gesperrt.
    @discardableResult
    func confirmResult() async -> Bool {
        guard state.isFinished else { return true }
        guard !didSettleGame else { return true }

        isSettling = true
        settleError = nil
        defer { isSettling = false }

        let finishedState = state
        let winningTeamId = finishedState.winnerTeamIndex.flatMap { index -> String? in
            teams.indices.contains(index) ? teams[index].id : nil
        }
        let profileIdsByTeam = teams.map(\.playerIds)
        // Die Kennung JETZT festhalten, nicht erst spaeter lesen: Eine
        // Revanche schreibt `gameId` unmittelbar danach um, und dann wuerde
        // das falsche Spiel als beendet markiert.
        let settledGameId = gameId

        do {
            if let settledGameId, let gameRepository {
                try await gameRepository.finishGame(gameId: settledGameId, winnerTeamId: winningTeamId)
            }
            // Beerpong Extreme zahlt bewusst NICHT auf die Statistiken ein.
            // Karten wie "wirf blind" oder "auf einem Bein" verschlechtern
            // die Würfe künstlich – eine Trefferquote daraus wäre mit einer
            // normalen Partie nicht vergleichbar und würde die Rangliste
            // still verfälschen. Die Partie selbst wird trotzdem beendet und
            // bleibt im Spielverlauf stehen.
            // In den Abend geht die Partie IMMER ein, auch Extreme: Dort
            // zaehlt, was gespielt wurde, nicht ob es die Trefferquote
            // verfaelscht. Die Statistiken darunter bleiben getrennt.
            EveningLog.record(
                title: extreme.isEnabled ? "Beerpong Extreme" : "Beerpong",
                emoji: "🍺",
                winner: finishedState.winnerTeamIndex.map { teamName($0) }
            )

            if let ownerId, let profileRepository, !extreme.isEnabled {
                try await profileRepository.applyFinishedGame(
                    state: finishedState,
                    profileIdsByTeam: profileIdsByTeam,
                    ownerId: ownerId
                )
            }
        } catch {
            AppLogger.firestore.error("Ergebnis nicht gespeichert: \(error.localizedDescription)")
            settleError = AppError.from(error).errorDescription
                ?? "Das Ergebnis konnte nicht gespeichert werden."
            return false
        }

        didSettleGame = true
        return true
    }

    /// Bester Spieler der Partie.
    ///
    /// Gewichtet bewusst Treffer vor Quote: Wer zwei von zwei trifft, hat
    /// eine perfekte Quote, aber die Partie nicht getragen. Erst bei
    /// gleicher Trefferzahl entscheidet die Quote, danach die längste Serie.
    var matchMVP: (player: PlayerRef, stats: PlayerStats)? {
        var candidates: [(PlayerRef, PlayerStats)] = []
        for teamIndex in state.stats.indices {
            for slot in state.stats[teamIndex].indices {
                let stats = state.stats[teamIndex][slot]
                guard stats.attempts > 0 else { continue }
                candidates.append((PlayerRef(teamIndex: teamIndex, slot: slot), stats))
            }
        }

        return candidates.max { left, right in
            let leftStreak = state.bestStreaks[left.0.teamIndex][left.0.slot]
            let rightStreak = state.bestStreaks[right.0.teamIndex][right.0.slot]
            return (left.1.hits, left.1.accuracy ?? 0, leftStreak)
                < (right.1.hits, right.1.accuracy ?? 0, rightStreak)
        }
    }

    /// Bricht die laufende Partie ohne Wertung ab.
    ///
    /// Ohne das bliebe ein abgebrochenes Spiel dauerhaft als
    /// „Spiel fortsetzen" im Hauptmenü stehen – es gäbe keinen Weg, es
    /// wieder loszuwerden.
    func abandonGame() {
        guard let gameId, let gameRepository else { return }
        // Kein Ergebnis festschreiben: Die Partie wurde nicht zu Ende
        // gespielt und darf keine Statistik erzeugen.
        didSettleGame = true
        Task {
            do {
                try await gameRepository.cancelGame(gameId: gameId)
            } catch {
                AppLogger.firestore.error("Abbruch konnte nicht gespeichert werden: \(error.localizedDescription)")
            }
        }
    }

    /// Startet dieselbe Aufstellung nochmal.
    ///
    /// Legt ein neues Spiel an, statt das alte weiterzubenutzen – sonst
    /// würden beide Partien im selben Wurf-Log landen und die Auswertung
    /// wäre nicht mehr trennbar.
    func startRematch() async {
        guard let gameRepository else { return }
        isStartingRematch = true
        defer { isStartingRematch = false }

        // Das laufende Ergebnis zuerst festschreiben, sonst ginge es verloren.
        // Scheitert das, geht die Revanche trotzdem los – der Hinweis dazu
        // steht im Sieger-Screen, den man dafuer verlassen hat.
        await confirmResult()

        do {
            let newGameId = try await gameRepository.createGame(
                type: gameType,
                teams: teams,
                format: format,
                createdBy: ownerId ?? "",
                accessUserIds: ownerId.map { [$0] }
            )
            try await gameRepository.startGame(gameId: newGameId)

            observationTask?.cancel()
            gameId = newGameId
            history.removeAll()
            eventLog.removeAll()
            didSettleGame = false
            hideHighlight()
            state = GameEngine.makeInitialState(format: format, playersPerTeam: playersPerTeam)
            observeThrows()
            HapticManager.success()
        } catch {
            HapticManager.error()
            errorMessage = AppError.from(error).errorDescription
        }
    }

    private func hideHighlight() {
        highlightDismissTask?.cancel()
        highlight = nil
    }

    func dismissSyncWarning() {
        syncWarning = nil
    }

    var canUndo: Bool { !history.isEmpty }

    /// Rückgängig heißt: lokal sofort zurückspringen und zusätzlich einen
    /// kompensierenden Eintrag anhängen. Der Log bleibt dadurch vollständig
    /// – nichts wird gelöscht – und die Mitspieler sehen die Korrektur.
    func undo() {
        guard let previous = history.popLast() else { return }

        let thrower = state.currentThrower
        let snapshot = state
        state = previous

        highlightDismissTask?.cancel()
        highlight = nil
        appendLog("↶ Letzte Aktion rückgängig gemacht.")
        HapticManager.lightImpact()

        guard let gameId, let throwRepository else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await throwRepository.recordUndo(
                    by: thrower,
                    in: snapshot,
                    gameId: gameId,
                    teams: self.teams
                )
            } catch {
                AppLogger.firestore.error("Undo konnte nicht gespeichert werden: \(error.localizedDescription)")
                self.syncWarning = "Das Rückgängigmachen wurde nicht gespeichert."
            }
        }
    }

    // MARK: - Sperrbildschirm

    /// Die Anzeige lebt genau so lange wie der Spielscreen. Das Handy liegt
    /// in dieser Zeit auf dem Tisch – gesperrt oder in einer anderen App ist
    /// dann trotzdem zu sehen, wer wirft.
    func startLiveActivity() {
        LiveGameActivity.start(
            teamOne: teamName(0),
            teamTwo: teamName(1),
            cupsTeamOne: state.racks[0].remainingCount,
            cupsTeamTwo: state.racks[1].remainingCount,
            thrower: currentThrowerName,
            detail: turnDescription
        )
    }

    func stopLiveActivity() {
        LiveGameActivity.end()
    }

    private func refreshLiveActivity() {
        guard !state.isFinished else { return LiveGameActivity.end() }
        LiveGameActivity.update(
            cupsTeamOne: state.racks[0].remainingCount,
            cupsTeamTwo: state.racks[1].remainingCount,
            thrower: currentThrowerName,
            detail: turnDescription
        )
    }

    // MARK: - Abfragen für die View

    func playerName(_ player: PlayerRef) -> String {
        let names = teams[player.teamIndex].playerNames
        guard names.indices.contains(player.slot) else { return "Spieler \(player.slot + 1)" }
        return names[player.slot]
    }

    func teamName(_ teamIndex: Int) -> String {
        "Team \(teamIndex + 1)"
    }

    var currentThrowerName: String { playerName(state.currentThrower) }

    var canThrow: Bool { GameEngine.canThrow(in: state) }
    var canRebound: Bool { GameEngine.canRebound(in: state, format: format) }
    var canArmBounce: Bool { GameEngine.canArmBounce(in: state, format: format) }
    var canDeclareBombe: Bool { GameEngine.canDeclareBombe(in: state) }
    var canReRack: Bool { GameEngine.canReRack(in: state, format: format) }
    var availableFormations: [RackFormation] { GameEngine.availableFormations(in: state) }

    /// Zustand eines Bechers im Rack von `teamIndex`.
    func cupState(teamIndex: Int, cupIndex: Int) -> CupState {
        let rack = state.racks[teamIndex]

        if !rack.isAlive(at: cupIndex) {
            let isMarked = teamIndex == state.targetRackIndex
                && state.lastHitCupIndex == cupIndex
                && state.pendingChoice == nil
            return isMarked ? .removedHighlighted : .removed
        }

        if let choice = state.pendingChoice {
            return choice.rackTeamIndex == teamIndex ? .choosable : .idle
        }

        guard state.phase != .finished, teamIndex == state.targetRackIndex else { return .idle }
        return .active
    }

    func handleCupTap(teamIndex: Int, cupIndex: Int) {
        if let choice = state.pendingChoice {
            // Nur aus dem Rack, um das es geht. Ohne die Prüfung würde ein
            // Tipp auf das andere Rack denselben Index hier entfernen – die
            // Engine kennt nur den Index, nicht das angetippte Rack.
            guard choice.rackTeamIndex == teamIndex else { return }
            perform(.chooseCup(index: cupIndex))
        } else if teamIndex == state.targetRackIndex {
            perform(.hitCup(index: cupIndex))
        }
    }

    /// Beschreibt, wer gerade wirft und woher der Ball kommt.
    var turnDescription: String {
        guard !state.isFinished else { return "Spiel beendet" }
        let base = "\(currentThrowerName) · \(teamName(state.turnTeamIndex))"
        switch state.pending {
        case .onFireBonus:
            return "\(base) · 🔥 behält den Ball"
        case .trickshot:
            return "\(base) · 🌀 Trickshot"
        case .normal:
            // Auch im 1 gegen 1 relevant: Dort wirft dieselbe Person beide
            // Bälle, und ohne die Anzeige wüsste man nicht, der wievielte
            // gerade dran ist.
            return "\(base) · Ball \(state.currentBallIndex + 1)/\(state.ballsPerTurn)"
        }
    }

    var choicePrompt: String? {
        guard let choice = state.pendingChoice else { return nil }
        let cups = choice.remaining > 1 ? "\(choice.remaining) weitere Becher" : "einen weiteren Becher"
        return "🍺 \(teamName(choice.choosingTeamIndex)) wählt \(cups) zum Wegstellen"
    }

    var trickshotHint: String? {
        guard state.pendingChoice == nil, state.pending == .trickshot, !state.isFinished else { return nil }
        return "🌀 Trickshot für \(currentThrowerName) — Treffer zählt 2 Becher"
    }

    // MARK: - Ereignisse verarbeiten

    private func handle(_ events: [GameEvent]) {
        for event in events {
            appendLog(logText(for: event))
            applyFeedback(for: event)
            drawExtremeCardIfLoaded(for: event)
        }
        // Ist die Partie vorbei, hat der Sieger-Screen Vorrang. Eine noch
        // laufende Einblendung würde ihn sonst überdecken.
        if state.isFinished { dismissHighlight() }
    }

    // MARK: - Beerpong Extreme

    /// Zieht eine Karte, wenn der getroffene Becher geladen war.
    ///
    /// Ein Becher loest nur EINMAL aus: Die Kennung wird beim Ziehen aus der
    /// Menge entfernt. Sonst wuerde dieselbe Position nach einem Umstellen
    /// oder in der Redemption erneut feuern, obwohl der Becher laengst weg ist.
    private func drawExtremeCardIfLoaded(for event: GameEvent) {
        guard extreme.isEnabled, !state.isFinished else { return }

        let hitTeam: Int
        let cupIndex: Int

        switch event {
        case .hit(let thrower, _, _, let index):
            // Getroffen wird immer das Rack des Gegners.
            hitTeam = 1 - thrower.teamIndex
            cupIndex = index
        case .cupChosen(let byTeamIndex, let index):
            // Bombe und Bounce: Die Zusatzbecher waehlt das Team, dem sie
            // gehoeren – hier ist der Waehlende also der Betroffene.
            hitTeam = byTeamIndex
            cupIndex = index
        default:
            return
        }

        guard loadedCups.indices.contains(hitTeam),
              loadedCups[hitTeam].contains(cupIndex) else { return }

        loadedCups[hitTeam].remove(cupIndex)

        guard let card = ExtremeDeck.draw(mode: extreme.mode) else { return }

        // Die Karte verdeckt den Tisch. Eine gleichzeitig laufende
        // Einblendung darunter waere nur Unruhe.
        dismissHighlight()
        extremeCard = card
        HapticManager.success()
        SoundManager.play(.victory)
    }

    func dismissExtremeCard() {
        extremeCard = nil
    }

    private func applyFeedback(for event: GameEvent) {
        switch event {
        case .hit(_, let bounce, let trickshot, _):
            HapticManager.mediumImpact()
            SoundManager.play(.cupHit)
            if bounce {
                show(.init(
                    kind: .bounce,
                    title: "BOUNCE!",
                    subtitle: "Aufsetzer im Becher – zwei Becher, der Gegner wählt den zweiten"
                ))
            } else if trickshot {
                show(.init(
                    kind: .trickshot,
                    title: "TRICKSHOT!",
                    subtitle: "Zwei Becher – der Gegner wählt den zweiten"
                ))
            }
        case .airball(let thrower, let penalised):
            HapticManager.error()
            if penalised {
                SoundManager.play(.airball)
                show(.init(kind: .airball, title: "AIRBALL!", subtitle: "\(playerName(thrower)) muss shotten"))
            }
        case .caughtFire(let player):
            HapticManager.success()
            SoundManager.play(.onFire)
            show(.init(kind: .onFire, title: "ON FIRE!", subtitle: "\(playerName(player)) behält den Ball bis zum ersten Fehlwurf"))
        case .ballsBack(let teamIndex):
            HapticManager.success()
            SoundManager.play(.ballsBack)
            show(.init(kind: .ballsBack, title: "BALLS BACK!", subtitle: "\(teamName(teamIndex)) wirft nochmal"))
        case .bombe(let choosingTeamIndex):
            HapticManager.success()
            SoundManager.play(.bombe)
            show(.init(kind: .bombe, title: "BOMBE!", subtitle: "\(teamName(choosingTeamIndex)) wählt 2 weitere Becher"))
        case .redemptionStarted(let teamIndex):
            HapticManager.mediumImpact()
            SoundManager.play(.onFire)
            show(.init(kind: .redemption, title: "REDEMPTION", subtitle: "\(teamName(teamIndex)) wirft nach"))
        case .reRacked(let teamIndex, let formation):
            HapticManager.mediumImpact()
            SoundManager.play(.reRack)
            show(.init(kind: .reRack, title: "UMGESTELLT", subtitle: "\(teamName(teamIndex)) stellt auf \(formation.name) um"))
        case .finished:
            HapticManager.success()
            SoundManager.play(.victory)
        case .cupChosen:
            HapticManager.lightImpact()
            SoundManager.play(.tap)
        case .missed, .rebound:
            HapticManager.lightImpact()
            SoundManager.play(.miss)
        }
    }

    /// Sagt den nächsten Werfer an, wenn er sich geändert hat.
    ///
    /// Nur bei echtem Wechsel: Bei einem Bonuswurf bleibt derselbe Spieler
    /// am Ball, und eine Wiederholung seines Namens wäre nur lästig.
    private func announceThrowerChange(from previous: PlayerRef) {
        guard !state.isFinished, state.currentThrower != previous else { return }
        SpeechAnnouncer.announceTurn(playerName: playerName(state.currentThrower))
    }

    /// Blendet die laufende Einblendung sofort aus – für „antippen zum
    /// Überspringen".
    func dismissHighlight() {
        guard highlight != nil else { return }
        highlightDismissTask?.cancel()
        withAnimation(AppAnimation.smoothFade) { highlight = nil }
    }

    private func show(_ newHighlight: Highlight) {
        highlightDismissTask?.cancel()
        withAnimation(AppAnimation.standard) { highlight = newHighlight }

        // Steht direkt danach eine erzwungene Becher-Auswahl an (Bombe,
        // Bounce, Trickshot), wird deutlich kürzer eingeblendet. Die
        // Einblendung liegt über dem Raster und fängt Tipper ab – wer gerade
        // wählen soll, tippt sonst ins Leere und hält das Spiel für kaputt.
        //
        // Sonst rund 1,2 Sekunden: lang genug zum Wahrnehmen, kurz genug,
        // dass es auch beim fünften Airball hintereinander nicht bremst.
        let duration: UInt64 = state.pendingChoice == nil ? 1_200_000_000 : 650_000_000

        // Die Klasse ist @MainActor, der Task erbt diese Isolation – ein
        // zusätzliches MainActor.run wäre überflüssig.
        highlightDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: duration)
            guard !Task.isCancelled else { return }
            withAnimation(AppAnimation.smoothFade) { self?.highlight = nil }
        }
    }

    private func appendLog(_ text: String) {
        eventLog.insert(text, at: 0)
        if eventLog.count > Self.maxLogEntries { eventLog.removeLast() }
    }

    private func logText(for event: GameEvent) -> String {
        switch event {
        case .hit(let thrower, let bounce, let trickshot, _):
            let suffix = bounce ? " 🏓 Bounce Shot" : (trickshot ? " 🌀 Trickshot" : "")
            return "\(playerName(thrower))\(suffix) trifft."
        case .missed(let thrower):
            return "\(playerName(thrower)) wirft daneben."
        case .airball(let thrower, let penalised):
            return penalised
                ? "💀 Airball! \(playerName(thrower)) muss shotten."
                : "💀 Airball im Trickshot — \(playerName(thrower)) bleibt verschont."
        case .rebound(let thrower):
            return "🌀 Rebound! \(playerName(thrower)) fängt den Ball."
        case .caughtFire(let player):
            return "🔥 \(playerName(player)) ist ON FIRE."
        case .ballsBack(let teamIndex):
            return "🙌 Balls Back! \(teamName(teamIndex)) wirft nochmal."
        case .bombe(let choosingTeamIndex):
            return "💣 BOMBE! \(teamName(choosingTeamIndex)) wählt 2 weitere Becher."
        case .cupChosen(let byTeamIndex, _):
            return "🍺 \(teamName(byTeamIndex)) stellt einen Becher weg."
        case .reRacked(let teamIndex, let formation):
            return "🔄 \(teamName(teamIndex)) stellt auf \(formation.name) um."
        case .redemptionStarted(let teamIndex):
            return "🥤 Rack leer — Redemption für \(teamName(teamIndex))."
        case .finished(let winner):
            guard let winner else { return "🤝 Unentschieden — beide Racks leer." }
            return "🏆 \(teamName(winner)) gewinnt!"
        }
    }

    // MARK: - Overlay-Modell

    struct Highlight: Equatable, Identifiable {
        /// Bestimmt Farbe **und** Animation – deshalb nach dem Ereignis
        /// benannt und nicht nach der Stimmung.
        enum Kind: Equatable {
            case airball, ballsBack, bombe, onFire, reRack, redemption, bounce, trickshot, neutral
        }

        let id = UUID()
        let kind: Kind
        let title: String
        let subtitle: String

        var tint: Color {
            switch kind {
            case .airball:    return BeerStatsColor.error
            case .ballsBack:  return BeerStatsColor.success
            case .bombe:      return BeerStatsColor.accentSecondary
            case .onFire:     return BeerStatsColor.accent
            case .reRack:     return BeerStatsColor.accent
            case .redemption: return BeerStatsColor.accentSecondary
            case .bounce:     return BeerStatsColor.warning
            case .trickshot:  return BeerStatsColor.success
            case .neutral:    return BeerStatsColor.textPrimary
            }
        }
    }
}
