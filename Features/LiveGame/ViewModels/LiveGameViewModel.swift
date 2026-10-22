//
//  LiveGameViewModel.swift
//  BeerStats
//
//  Hält den Spielzustand und übersetzt zwischen Engine und View.
//
//  Das ViewModel enthält bewusst KEINE Regel-Logik – die liegt vollständig
//  in GameEngine. Hier passiert nur: Aktion weiterreichen, Verlauf für Undo
//  mitschreiben, Ereignisse weiterleiten und den Zustand veröffentlichen.
//
//  Seit dem 18. Oktober liegt daneben, was vorher mit drin lag. Die Datei
//  war auf 899 Zeilen gewachsen, und vier der acht Funde aus der
//  Cloud-Prüfung vom 15. August lagen genau hier – alle mit derselben
//  Ursache: derselbe Zustand an zwei Stellen gehalten. Geschnitten ist
//  entlang der Frage, was man zum Prüfen braucht:
//
//  - `LiveGameNaming` / `LiveGameNarrator` – wie etwas heißt und wie es
//    heißt, wenn es passiert. Reine Rechnung, ohne Gerät prüfbar.
//  - `LiveGameFeedback` – Rütteln und Klang. Reine Nebenwirkung.
//  - `ExtremeCardDealer` – welche Becher geladen sind.
//  - `LiveGameSync` – alles, was zum Wurf-Log geht, samt Warteschlange.
//
//  Was hier bleibt, ist die Klammer: der Zustand, der Verlauf für Undo und
//  die Reihenfolge, in der das alles passiert.
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

    /// Wie viele Eintraege nicht im Log gelandet sind.
    ///
    /// Die Warnung allein war eine Sackgasse: Sie sagte „prueft die
    /// Verbindung", und wenn die wieder da war, gab es trotzdem keinen Weg,
    /// den Wurf nachzureichen. Der Wurf-Log ist aber die Wahrheit – fehlt
    /// dort ein Eintrag, laeuft die nachgespielte Partie fuer immer anders
    /// als die gespielte.
    @Published private(set) var unsavedCount = 0
    @Published private(set) var isRetryingWrites = false

    /// Läuft, während das Ergebnis geschrieben wird.
    @Published private(set) var isSettling = false
    @Published private(set) var settleError: String?

    // MARK: - Unveränderliche Spieldaten

    let teams: [Team]
    let format: GameFormat

    private let playersPerTeam: Int
    private let gameType: GameType
    private let gameRepository: GameRepositoryProtocol?
    private let profileRepository: PlayerProfileRepositoryProtocol?
    private let ownerId: String?

    /// Der Weg zum Wurf-Log – samt Spielkennung und Warteschlange.
    private let sync: LiveGameSync
    /// Wie Leute und Teams heissen.
    private let naming: LiveGameNaming
    /// Was zu einem Ereignis gesagt und eingeblendet wird.
    private let narrator: LiveGameNarrator

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

    /// Welche Becher geladen sind und wann daraus eine Karte wird.
    private var dealer: ExtremeCardDealer
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
        self.gameRepository = gameRepository
        self.profileRepository = profileRepository
        self.ownerId = ownerId
        self.sync = LiveGameSync(repository: throwRepository, gameId: gameId, teams: teams)

        let naming = LiveGameNaming(teams: teams)
        self.naming = naming
        self.narrator = LiveGameNarrator(naming: naming)
        self.dealer = ExtremeCardDealer(settings: extreme)
        self.state = GameEngine.makeInitialState(format: format, playersPerTeam: playersPerTeam)

        // Nach dem Anlegen des Zustands, weil die Auslosung die lebenden
        // Becher daraus liest.
        dealer.reload(from: state, format: format)
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
        guard let strom = sync.stream() else { return }
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await entries in strom {
                guard var rebuilt = self.sync.replay(
                    entries,
                    format: self.format,
                    playersPerTeam: self.playersPerTeam
                ) else { continue }
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

        Task { [weak self] in
            guard let self else { return }
            let geschrieben = await self.sync.record(
                action, by: thrower, before: snapshot, after: result.state
            )
            if !geschrieben { self.refreshSyncStatus() }
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
        let settledGameId = sync.gameId

        // Der Endstand, wie er aus dem Wurf-Log entstanden ist. Ohne ihn
        // bliebe im Spiel-Dokument die volle Becherzahl vom Anlegen stehen,
        // und der Spielverlauf zeigte 10 : 10.
        let endstand = Dictionary(
            teams.indices.compactMap { index -> (String, Int)? in
                guard finishedState.racks.indices.contains(index) else { return nil }
                return (teams[index].id, finishedState.racks[index].remainingCount)
            },
            uniquingKeysWith: { first, _ in first }
        )

        do {
            if let settledGameId, let gameRepository {
                try await gameRepository.finishGame(
                    gameId: settledGameId,
                    winnerTeamId: winningTeamId,
                    cupsRemaining: endstand
                )
            }
            // Beerpong Extreme zahlt bewusst NICHT auf die Statistiken ein.
            // Karten wie "wirf blind" oder "auf einem Bein" verschlechtern
            // die Würfe künstlich – eine Trefferquote daraus wäre mit einer
            // normalen Partie nicht vergleichbar und würde die Rangliste
            // still verfälschen. Die Partie selbst wird trotzdem beendet und
            // bleibt im Spielverlauf stehen.
            if let ownerId, let profileRepository, !dealer.isEnabled {
                try await profileRepository.applyFinishedGame(
                    state: finishedState,
                    profileIdsByTeam: profileIdsByTeam,
                    ownerId: ownerId
                )
            }

            // Ganz zum Schluss, nach allem, was scheitern kann. Der Eintrag
            // ist ein reines Anhaengen ohne Kennung – schlaegt eine der
            // Schreiboperationen darueber fehl, bleibt `didSettleGame` false,
            // der Sieger-Screen bietet "nochmal versuchen" an, und beim
            // zweiten Anlauf stuende die Partie zweimal im Abend.
            //
            // In den Abend geht die Partie IMMER ein, auch Extreme: Dort
            // zaehlt, was gespielt wurde, nicht ob es die Trefferquote
            // verfaelscht. Die Statistiken darueber bleiben getrennt.
            let siegerTeam = finishedState.winnerTeamIndex.flatMap { index in
                teams.indices.contains(index) ? teams[index] : nil
            }

            EveningLog.record(
                title: dealer.isEnabled ? "Beerpong Extreme" : "Beerpong",
                emoji: "🍺",
                // Die Namen der Gewinner, nicht "Team 1". Die Aufstellung
                // wechselt zwischen den Partien eines Abends, ein Platzhalter
                // wuerde also zaehlen, wie oft der linke Platz gewonnen hat.
                winner: siegerTeam?.playerNames.joined(separator: " & "),
                // Fuer den Pokal zaehlt die PERSON, nicht der Text: Bei
                // einem 2-gegen-2 stuende sonst "Lena & Jan" als ein
                // Schluessel in der Wertung und beide gingen leer aus. Die
                // Spieler-IDs eines Teams sind Profil-IDs, und genau die
                // tragen auch die Teilnehmer des Abends.
                winnerIds: siegerTeam?.playerIds ?? [],
                // So viel wie ein langes Partyspiel – eine Partie Beerpong
                // dauert eine Viertelstunde und ist das Spiel, um das es
                // in dieser App geht.
                points: PartyGame.Length.long.points
            )
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
        guard let gameId = sync.gameId, let gameRepository else { return }
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
            // Liegengebliebenes der Vorpartie wandert NICHT mit: Jeder
            // Eintrag kennt seine eigene Partie, siehe `LiveGameSync`.
            sync.rebind(to: newGameId)
            history.removeAll()
            eventLog.removeAll()
            didSettleGame = false
            hideHighlight()
            state = GameEngine.makeInitialState(format: format, playersPerTeam: playersPerTeam)
            // Nach dem neuen Rack, weil die Auslosung die lebenden Becher
            // daraus liest.
            dealer.reload(from: state, format: format)
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

    // MARK: - Liegengebliebenes nachreichen

    /// Die EINZIGE Stelle, an der die Anzeige dem Stand der Warteschlange
    /// folgt.
    ///
    /// Vorher stand dieselbe Rechnung an drei Stellen – beim Merken, beim
    /// Nachreichen und am Ende des Nachreichens – und jede konnte fuer sich
    /// falsch werden. Genau diese Fehlerklasse ("derselbe Zustand an zwei
    /// Stellen") war der Anlass fuer den Schnitt.
    private func refreshSyncStatus(message: String? = nil) {
        unsavedCount = sync.pendingCount

        if let message {
            syncWarning = message
        } else if unsavedCount == 0 {
            syncWarning = nil
        } else {
            syncWarning = unsavedCount == 1
                ? "Ein Eintrag ist nicht im Log gelandet."
                : "\(unsavedCount) Einträge sind nicht im Log gelandet."
        }
    }

    /// Schickt alles Liegengebliebene noch einmal los.
    func retryUnsavedWrites() async {
        guard sync.pendingCount > 0 else { return }

        isRetryingWrites = true
        defer { isRetryingWrites = false }

        let durch = await sync.retryPending()
        refreshSyncStatus(message: durch ? nil : "Nachreichen hat nicht geklappt. Prüft die Verbindung.")
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

        Task { [weak self] in
            guard let self else { return }
            let geschrieben = await self.sync.recordUndo(by: thrower, in: snapshot)
            if !geschrieben { self.refreshSyncStatus() }
        }
    }

    // MARK: - Sperrbildschirm

    /// Die Anzeige lebt genau so lange wie der Spielscreen. Das Handy liegt
    /// in dieser Zeit auf dem Tisch – gesperrt oder in einer anderen App ist
    /// dann trotzdem zu sehen, wer wirft.
    func startLiveActivity() {
        LiveGameActivity.start(
            teamOne: teamShortName(0),
            teamTwo: teamShortName(1),
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

    // Duenne Weiterreicher auf `LiveGameNaming`. Sie bleiben am ViewModel,
    // weil die Ansichten sie so kennen – die Arbeit steht aber dort, wo sie
    // ohne ViewModel pruefbar ist.
    func playerName(_ player: PlayerRef) -> String { naming.player(player) }
    func teamName(_ teamIndex: Int) -> String { naming.team(teamIndex) }
    func teamShortName(_ teamIndex: Int) -> String { naming.shortTeam(teamIndex) }

    func teamVerb(_ teamIndex: Int, _ singular: String, _ plural: String) -> String {
        naming.verb(teamIndex, singular, plural)
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
        let team = choice.choosingTeamIndex
        return "🍺 \(teamName(team)) \(teamVerb(team, "wählt", "wählen")) \(cups) zum Wegstellen"
    }

    var trickshotHint: String? {
        guard state.pendingChoice == nil, state.pending == .trickshot, !state.isFinished else { return nil }
        return "🌀 Trickshot für \(currentThrowerName) — Treffer zählt 2 Becher"
    }

    // MARK: - Ereignisse verarbeiten

    private func handle(_ events: [GameEvent]) {
        for event in events {
            appendLog(narrator.logText(for: event))
            LiveGameFeedback.play(for: event)
            if let einblendung = narrator.highlight(for: event) { show(einblendung) }
            drawExtremeCardIfLoaded(for: event)
        }
        // Ist die Partie vorbei, hat der Sieger-Screen Vorrang. Eine noch
        // laufende Einblendung würde ihn sonst überdecken.
        if state.isFinished { dismissHighlight() }
    }

    // MARK: - Beerpong Extreme

    /// Zieht eine Karte, wenn der getroffene Becher geladen war.
    ///
    /// Welcher Becher geladen ist und dass er nur EINMAL ausloest, weiss der
    /// `ExtremeCardDealer`. Hier steht nur noch, was auf dem Bildschirm
    /// passiert – und die eine Bedingung, die den Spielstand betrifft: Nach
    /// dem letzten Becher hat der Sieger-Screen Vorrang.
    private func drawExtremeCardIfLoaded(for event: GameEvent) {
        guard !state.isFinished, let card = dealer.card(for: event) else { return }

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

    // MARK: - Overlay-Modell

    /// Zweitname, damit `HighlightOverlayView` und der Spielscreen
    /// unveraendert weiterlaufen. Der Typ selbst steht in
    /// `GameHighlight` – dort laesst er sich bauen, ohne ein ganzes
    /// ViewModel zu bauen.
    typealias Highlight = GameHighlight
}
