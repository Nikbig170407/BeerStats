//
//  ThrowRepository.swift
//  BeerStats
//
//  Fachliche Schicht über dem Wurf-Log.
//
//  Zwei Aufgaben: Aktionen in Throw-Dokumente übersetzen (inklusive der
//  fachlichen Felder, aus denen später die Statistik aggregiert wird), und
//  aus einem Log wieder einen Spielstand machen.
//
//  Das Nachspielen ist der Kern der Geräte-Synchronisation: Der Server
//  rechnet nichts, er speichert nur die Reihenfolge. Weil die Engine eine
//  reine Funktion ist, kommt jedes Gerät aus demselben Log zwangsläufig auf
//  denselben Spielstand.
//

import Foundation

protocol ThrowRepositoryProtocol {
    func observeThrows(gameId: String) -> AsyncStream<[Throw]>

    func record(
        action: GameAction,
        by player: PlayerRef,
        before: LiveGameState,
        after: LiveGameState,
        gameId: String,
        teams: [Team]
    ) async throws

    func recordUndo(
        by player: PlayerRef,
        in state: LiveGameState,
        gameId: String,
        teams: [Team]
    ) async throws

    func replay(_ entries: [Throw], format: GameFormat, playersPerTeam: Int) -> LiveGameState
}

final class ThrowRepository: ThrowRepositoryProtocol {

    private let throwService: ThrowServiceProtocol

    init(throwService: ThrowServiceProtocol) {
        self.throwService = throwService
    }

    func observeThrows(gameId: String) -> AsyncStream<[Throw]> {
        throwService.observeThrows(gameId: gameId)
    }

    // MARK: - Schreiben

    func record(
        action: GameAction,
        by player: PlayerRef,
        before: LiveGameState,
        after: LiveGameState,
        gameId: String,
        teams: [Team]
    ) async throws {
        guard action.isPersistable else { return }

        // Wichtig: Wurf-Typ und Bounce-Kennzeichen stammen aus dem Zustand
        // VOR der Aktion. Danach ist der Bounce-Schalter bereits
        // zurückgesetzt und `pending` beschreibt schon den nächsten Wurf –
        // beides wäre für diesen Eintrag falsch. Die laufenden Nummern
        // kommen dagegen aus dem Zustand danach, weil sie erst dort
        // hochgezählt wurden.
        let entry = Throw(
            playerId: playerId(for: player, teams: teams),
            teamId: teamId(at: player.teamIndex, teams: teams),
            targetTeamId: teamId(at: before.opponent(of: player.teamIndex), teams: teams),
            cupId: cupId(for: action),
            result: action.throwResult,
            throwType: throwType(for: before),
            sequenceNumber: after.sequenceNumber,
            roundNumber: after.roundNumber,
            isBounce: before.bounceArmed && isThrowAtCup(action),
            enablesTrickshot: action == .rebound,
            cupsRemoved: cupsRemoved(for: action),
            action: action
        )
        try await throwService.appendThrow(entry, gameId: gameId)
    }

    /// Eine Korrektur wird als eigener Eintrag angehängt, nicht durch
    /// Löschen – siehe Kommentar in ThrowServiceProtocol.
    func recordUndo(
        by player: PlayerRef,
        in state: LiveGameState,
        gameId: String,
        teams: [Team]
    ) async throws {
        let entry = Throw(
            playerId: playerId(for: player, teams: teams),
            teamId: teamId(at: player.teamIndex, teams: teams),
            targetTeamId: teamId(at: state.opponent(of: player.teamIndex), teams: teams),
            result: .undo,
            sequenceNumber: state.sequenceNumber + 1,
            roundNumber: state.roundNumber
        )
        try await throwService.appendThrow(entry, gameId: gameId)
    }

    // MARK: - Nachspielen

    func replay(_ entries: [Throw], format: GameFormat, playersPerTeam: Int) -> LiveGameState {
        // Erst die Undo-Einträge auflösen: Jeder von ihnen streicht den
        // zuletzt noch gültigen Eintrag.
        var effective: [GameAction] = []
        for entry in entries.sorted(by: { $0.sequenceNumber < $1.sequenceNumber }) {
            if entry.result == .undo {
                if !effective.isEmpty { effective.removeLast() }
                continue
            }
            guard let action = entry.action else { continue }
            effective.append(action)
        }

        var state = GameEngine.makeInitialState(format: format, playersPerTeam: playersPerTeam)
        for action in effective {
            state = GameEngine.apply(action, to: state, format: format).state
        }
        return state
    }

    // MARK: - Ableitungen für die fachlichen Felder

    private func playerId(for player: PlayerRef, teams: [Team]) -> String {
        guard teams.indices.contains(player.teamIndex) else { return "" }
        let ids = teams[player.teamIndex].playerIds
        guard ids.indices.contains(player.slot) else { return "" }
        return ids[player.slot]
    }

    private func teamId(at index: Int, teams: [Team]) -> String {
        teams.indices.contains(index) ? teams[index].id : ""
    }

    private func cupId(for action: GameAction) -> String? {
        switch action {
        case .hitCup(let index), .chooseCup(let index): return String(index)
        default: return nil
        }
    }

    private func isThrowAtCup(_ action: GameAction) -> Bool {
        if case .hitCup = action { return true }
        return false
    }

    private func throwType(for state: LiveGameState) -> ThrowType {
        switch state.pending {
        case .normal: return .normal
        case .onFireBonus: return .onFireBonus
        case .trickshot: return .trickshotAttempt
        }
    }

    /// Wie viele Becher dieser eine Eintrag vom Tisch nimmt.
    ///
    /// Bewusst nur der unmittelbare Abgang: Die zusätzlichen Becher bei
    /// Bounce, Trickshot und Bombe werden vom Gegner ausgewählt und landen
    /// als eigene `chooseCup`-Einträge im Log – so bleibt nachvollziehbar,
    /// welche Becher das waren. Die Bombe selbst nimmt gar keinen Becher:
    /// Der Treffer galt dem Becher, den der Teamkollege schon abgeräumt hat.
    private func cupsRemoved(for action: GameAction) -> Int {
        switch action {
        case .hitCup, .chooseCup: return 1
        default: return 0
        }
    }
}
