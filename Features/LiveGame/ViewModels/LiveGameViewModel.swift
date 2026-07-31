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
        ownerId: String? = nil
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
        self.state = GameEngine.makeInitialState(format: format, playersPerTeam: playersPerTeam)
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
                let rebuilt = throwRepository.replay(
                    entries,
                    format: self.format,
                    playersPerTeam: self.playersPerTeam
                )
                // Firestore liefert eigene Schreibvorgänge sofort aus dem
                // lokalen Cache mit. Ein Unterschied zum aktuellen Zustand
                // bedeutet hier also: Ein Mitspieler hat etwas eingegeben.
                if rebuilt != self.state {
                    withAnimation(AppAnimation.standard) { self.state = rebuilt }
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
        state = result.state
        handle(result.events)

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
    func confirmResult() {
        guard state.isFinished, !didSettleGame else { return }
        didSettleGame = true

        let finishedState = state
        let winningTeamId = finishedState.winnerTeamIndex.flatMap { index -> String? in
            teams.indices.contains(index) ? teams[index].id : nil
        }
        let profileIdsByTeam = teams.map(\.playerIds)
        // Die Kennung JETZT festhalten, nicht erst im Task lesen: Eine
        // Revanche schreibt `gameId` unmittelbar danach um, und dann würde
        // das falsche – nämlich das gerade erst begonnene – Spiel als beendet
        // markiert.
        let settledGameId = gameId

        Task { [weak self] in
            guard let self else { return }

            if let settledGameId, let gameRepository {
                do {
                    try await gameRepository.finishGame(gameId: settledGameId, winnerTeamId: winningTeamId)
                } catch {
                    AppLogger.firestore.error("Spielende konnte nicht gespeichert werden: \(error.localizedDescription)")
                }
            }

            if let ownerId, let profileRepository {
                do {
                    try await profileRepository.applyFinishedGame(
                        state: finishedState,
                        profileIdsByTeam: profileIdsByTeam,
                        ownerId: ownerId
                    )
                } catch {
                    AppLogger.firestore.error("Statistiken konnten nicht geschrieben werden: \(error.localizedDescription)")
                }
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
        confirmResult()

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
            }
        }
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
        if state.pendingChoice != nil {
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
            guard state.playersPerTeam > 1 else { return base }
            return "\(base) · Ball \(state.throwerSlot + 1)/\(state.playersPerTeam)"
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
        }
    }

    private func applyFeedback(for event: GameEvent) {
        switch event {
        case .hit(_, let bounce, let trickshot, _):
            HapticManager.mediumImpact()
            if bounce || trickshot {
                show(.init(
                    kind: .neutral,
                    title: bounce ? "BOUNCE" : "TRICKSHOT",
                    subtitle: "Zwei Becher – der Gegner wählt den zweiten"
                ))
            }
        case .airball(let thrower, let penalised):
            HapticManager.error()
            if penalised {
                show(.init(kind: .airball, title: "AIRBALL!", subtitle: "\(playerName(thrower)) muss shotten"))
            }
        case .caughtFire(let player):
            HapticManager.success()
            show(.init(kind: .onFire, title: "ON FIRE!", subtitle: "\(playerName(player)) behält den Ball bis zum ersten Fehlwurf"))
        case .ballsBack(let teamIndex):
            HapticManager.success()
            show(.init(kind: .ballsBack, title: "BALLS BACK!", subtitle: "\(teamName(teamIndex)) wirft nochmal"))
        case .bombe(let choosingTeamIndex):
            HapticManager.success()
            show(.init(kind: .bombe, title: "BOMBE!", subtitle: "\(teamName(choosingTeamIndex)) wählt 2 weitere Becher"))
        case .redemptionStarted(let teamIndex):
            HapticManager.mediumImpact()
            show(.init(kind: .redemption, title: "REDEMPTION", subtitle: "\(teamName(teamIndex)) wirft nach"))
        case .reRacked(let teamIndex, let formation):
            HapticManager.mediumImpact()
            show(.init(kind: .reRack, title: "UMGESTELLT", subtitle: "\(teamName(teamIndex)) stellt auf \(formation.name) um"))
        case .finished:
            HapticManager.success()
        case .cupChosen, .missed, .rebound:
            HapticManager.lightImpact()
        }
    }

    private func show(_ newHighlight: Highlight) {
        highlightDismissTask?.cancel()
        withAnimation(AppAnimation.standard) { highlight = newHighlight }

        // Die Klasse ist @MainActor, der Task erbt diese Isolation – ein
        // zusätzliches MainActor.run wäre überflüssig.
        // Rund 1,2 Sekunden: lang genug zum Wahrnehmen, kurz genug, dass es
        // auch beim fünften Airball hintereinander nicht bremst.
        highlightDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
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
            case airball, ballsBack, bombe, onFire, reRack, redemption, neutral
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
            case .neutral:    return BeerStatsColor.textPrimary
            }
        }
    }
}
