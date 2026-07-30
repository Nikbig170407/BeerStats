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

    // MARK: - Unveränderliche Spieldaten

    let teams: [Team]
    let format: GameFormat

    private var history: [LiveGameState] = []
    private var highlightDismissTask: Task<Void, Never>?

    private static let maxHistory = 60
    private static let maxLogEntries = 30

    // MARK: - Aufbau

    init(teams: [Team], format: GameFormat, playersPerTeam: Int) {
        self.teams = teams
        self.format = format
        self.state = GameEngine.makeInitialState(format: format, playersPerTeam: playersPerTeam)
    }

    // MARK: - Aktionen

    func perform(_ action: GameAction) {
        // Der Zustand ist ein Wert-Typ, ein Snapshot ist daher schlicht eine
        // Kopie – das macht Undo beliebig tief und kostet fast nichts.
        let snapshot = state
        let result = GameEngine.apply(action, to: state, format: format)

        guard result.state != state else { return }   // Aktion war nicht erlaubt

        history.append(snapshot)
        if history.count > Self.maxHistory { history.removeFirst() }

        state = result.state
        handle(result.events)
    }

    var canUndo: Bool { !history.isEmpty }

    func undo() {
        guard let previous = history.popLast() else { return }
        state = previous
        highlightDismissTask?.cancel()
        highlight = nil
        appendLog("↶ Letzte Aktion rückgängig gemacht.")
        HapticManager.lightImpact()
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
            if bounce || trickshot { show(.init(kind: .neutral, title: bounce ? "BOUNCE" : "TRICKSHOT", subtitle: "Zwei Becher – der Gegner wählt den zweiten")) }
        case .airball(let thrower, let penalised):
            HapticManager.error()
            if penalised {
                show(.init(kind: .warning, title: "AIRBALL!", subtitle: "\(playerName(thrower)) muss shotten"))
            }
        case .caughtFire(let player):
            HapticManager.success()
            show(.init(kind: .fire, title: "ON FIRE!", subtitle: "\(playerName(player)) behält den Ball bis zum ersten Fehlwurf"))
        case .ballsBack(let teamIndex):
            HapticManager.success()
            show(.init(kind: .positive, title: "BALLS BACK!", subtitle: "\(teamName(teamIndex)) wirft nochmal"))
        case .bombe(let choosingTeamIndex):
            HapticManager.success()
            show(.init(kind: .warning, title: "BOMBE!", subtitle: "\(teamName(choosingTeamIndex)) wählt 2 weitere Becher"))
        case .redemptionStarted(let teamIndex):
            HapticManager.mediumImpact()
            show(.init(kind: .warning, title: "REDEMPTION", subtitle: "\(teamName(teamIndex)) wirft nach"))
        case .finished:
            HapticManager.success()
        case .reRacked, .cupChosen, .missed, .rebound:
            HapticManager.lightImpact()
        }
    }

    private func show(_ newHighlight: Highlight) {
        highlightDismissTask?.cancel()
        withAnimation(AppAnimation.standard) { highlight = newHighlight }

        // Die Klasse ist @MainActor, der Task erbt diese Isolation – ein
        // zusätzliches MainActor.run wäre überflüssig.
        highlightDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
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
        enum Kind: Equatable { case positive, warning, fire, neutral }

        let id = UUID()
        let kind: Kind
        let title: String
        let subtitle: String

        var tint: Color {
            switch kind {
            case .positive: return BeerStatsColor.success
            case .warning: return BeerStatsColor.accentSecondary
            case .fire: return BeerStatsColor.accent
            case .neutral: return BeerStatsColor.textPrimary
            }
        }
    }
}
