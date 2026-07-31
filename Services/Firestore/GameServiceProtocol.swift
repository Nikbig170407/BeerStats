//
//  GameServiceProtocol.swift
//  BeerStats
//
//  Kapselt alle Firestore-Zugriffe auf die `games`-Collection.
//

import Foundation

protocol GameServiceProtocol {

    /// Erstellt ein neues Spiel und gibt die neue Dokument-ID zurück.
    func createGame(_ game: Game) async throws -> String

    /// Echtzeit-Stream eines einzelnen Spiels – Grundlage für Lobby und
    /// (ab Schritt 7) das Live-Tracking.
    func observeGame(gameId: String) -> AsyncStream<Game?>

    /// Echtzeit-Stream aller nicht abgeschlossenen Spiele eines Nutzers
    /// (lobby/active/paused), für den Home-Screen.
    func observeUserGames(userId: String) -> AsyncStream<[Game]>

    func updateGameStatus(gameId: String, status: GameStatus, startedAt: Date?) async throws

    /// Schließt ein Spiel ab: Status, Sieger und Endzeitpunkt in einem
    /// Schreibvorgang. `winnerTeamId` ist bei einem Unentschieden `nil`.
    func finishGame(gameId: String, winnerTeamId: String?) async throws
}
