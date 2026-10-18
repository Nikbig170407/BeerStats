//
//  LiveGameSync.swift
//  BeerStats
//
//  Alles, was zwischen dem Tisch und dem Wurf-Log liegt.
//
//  Der Wurf-Log ist die Wahrheit: Fehlt dort ein Eintrag, laeuft die
//  nachgespielte Partie dauerhaft anders als die gespielte. Deshalb gibt es
//  hier eine Warteschlange statt eines verlorenen Fehlers – was nicht
//  geschrieben werden konnte, bleibt liegen und kann nachgereicht werden.
//
//  Die laufende Nummer steckt im mitgegebenen Spielzustand und nicht in der
//  Uhrzeit des Schreibens. Nur deshalb darf ein Eintrag beliebig spaeter
//  nachkommen, ohne dass die Reihenfolge im Log durcheinandergeraet.
//
//  **Jeder liegengebliebene Eintrag merkt sich seine Partie.** Das klingt
//  nach Kleinkram, ist aber der Grund, warum es diese Klasse gibt: Vorher
//  lagen die Warteschlange und die Spielkennung getrennt im ViewModel. Eine
//  Revanche schrieb die Kennung um, die Warteschlange blieb stehen – und
//  ein nachgereichter Wurf der Vorpartie waere in den Log der NEUEN Partie
//  gelaufen. Dort haette ihn niemand gesucht, und nachgespielt haette die
//  Revanche einen Treffer enthalten, den es nie gab.
//

import Foundation

@MainActor
final class LiveGameSync {

    private let repository: ThrowRepositoryProtocol?
    private let teams: [Team]

    /// Die Partie, in die gerade geschrieben wird.
    private(set) var gameId: String?

    /// Was nicht geschrieben werden konnte, in der Reihenfolge des Spiels.
    private var pending: [PendingWrite] = []

    var pendingCount: Int { pending.count }

    /// Ohne Repository oder Kennung laeuft der Screen ohne Log – etwa in
    /// einer SwiftUI-Vorschau. Dann wird nichts gemerkt und nichts gewarnt.
    var isConnected: Bool { repository != nil && gameId != nil }

    private struct PendingWrite {
        /// Die Partie, zu der dieser Eintrag gehoert – nicht die, die
        /// gerade laeuft.
        let gameId: String
        let kind: Kind

        enum Kind {
            case action(GameAction, thrower: PlayerRef, before: LiveGameState, after: LiveGameState)
            case undo(thrower: PlayerRef, state: LiveGameState)
        }
    }

    init(repository: ThrowRepositoryProtocol?, gameId: String?, teams: [Team]) {
        self.repository = repository
        self.gameId = gameId
        self.teams = teams
    }

    // MARK: - Zuhoeren

    /// Der Strom der Eintraege – vom eigenen Geraet wie von Mitspielern.
    func stream() -> AsyncStream<[Throw]>? {
        guard let repository, let gameId else { return nil }
        return repository.observeThrows(gameId: gameId)
    }

    func replay(_ entries: [Throw], format: GameFormat, playersPerTeam: Int) -> LiveGameState? {
        repository?.replay(entries, format: format, playersPerTeam: playersPerTeam)
    }

    /// Ab jetzt gilt eine neue Partie.
    ///
    /// Liegengebliebenes wird NICHT mitgenommen: Jeder Eintrag kennt seine
    /// eigene Partie und wird auch spaeter noch dorthin geschrieben.
    func rebind(to newGameId: String) {
        gameId = newGameId
    }

    // MARK: - Schreiben

    /// Schreibt eine Aktion. Gibt `false` zurueck, wenn sie liegen blieb.
    @discardableResult
    func record(
        _ action: GameAction,
        by thrower: PlayerRef,
        before: LiveGameState,
        after: LiveGameState
    ) async -> Bool {
        guard let repository, let gameId else { return true }
        do {
            try await repository.record(
                action: action,
                by: thrower,
                before: before,
                after: after,
                gameId: gameId,
                teams: teams
            )
            return true
        } catch {
            AppLogger.firestore.error("Wurf konnte nicht gespeichert werden: \(error.localizedDescription)")
            // Der Wurf steht lokal schon auf dem Schirm, im Log aber nicht.
            // Spaetestens beim naechsten Nachspielen verschwindet er wieder
            // – das darf nicht unbemerkt passieren.
            pending.append(
                PendingWrite(
                    gameId: gameId,
                    kind: .action(action, thrower: thrower, before: before, after: after)
                )
            )
            return false
        }
    }

    /// Schreibt den kompensierenden Eintrag fuer ein Rueckgaengig.
    @discardableResult
    func recordUndo(by thrower: PlayerRef, in state: LiveGameState) async -> Bool {
        guard let repository, let gameId else { return true }
        do {
            try await repository.recordUndo(by: thrower, in: state, gameId: gameId, teams: teams)
            return true
        } catch {
            AppLogger.firestore.error("Undo konnte nicht gespeichert werden: \(error.localizedDescription)")
            pending.append(
                PendingWrite(gameId: gameId, kind: .undo(thrower: thrower, state: state))
            )
            return false
        }
    }

    // MARK: - Nachreichen

    /// Schickt alles Liegengebliebene noch einmal los.
    ///
    /// Der Reihe nach und abbrechend beim ersten erneuten Fehlschlag: Die
    /// Eintraege haengen in ihrer Reihenfolge aneinander, und einen Wurf
    /// nachzureichen, dessen Vorgaenger weiterhin fehlt, macht den Log nicht
    /// richtiger – nur laenger.
    ///
    /// Gibt zurueck, ob alles durchging.
    func retryPending() async -> Bool {
        guard let repository else { return pending.isEmpty }

        while let naechster = pending.first {
            do {
                switch naechster.kind {
                case let .action(action, thrower, before, after):
                    try await repository.record(
                        action: action,
                        by: thrower,
                        before: before,
                        after: after,
                        gameId: naechster.gameId,
                        teams: teams
                    )
                case let .undo(thrower, state):
                    try await repository.recordUndo(
                        by: thrower,
                        in: state,
                        gameId: naechster.gameId,
                        teams: teams
                    )
                }
                pending.removeFirst()
            } catch {
                AppLogger.firestore.error("Nachreichen gescheitert: \(error.localizedDescription)")
                return false
            }
        }

        return true
    }
}
