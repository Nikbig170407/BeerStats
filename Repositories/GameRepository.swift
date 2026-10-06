//
//  GameRepository.swift
//  BeerStats
//
//  Fachliche Logik rund um Spiele: validiert, dass die Team-Größen zum
//  gewählten Spielmodus passen, bevor überhaupt ein Firestore-Schreibzugriff
//  passiert – spart unnötige Schreibvorgänge bei offensichtlich ungültigen
//  Eingaben.
//

import Foundation

protocol GameRepositoryProtocol {
    func observeUserGames(currentUserId: String) -> AsyncStream<[Game]>
    func observeGame(gameId: String) -> AsyncStream<Game?>
    func createGame(
        type: GameType,
        teams: [Team],
        format: GameFormat,
        createdBy: String,
        accessUserIds: [String]?
    ) async throws -> String
    func startGame(gameId: String) async throws
    func finishGame(gameId: String, winnerTeamId: String?, cupsRemaining: [String: Int]?) async throws
    /// Bricht ein Spiel ohne Wertung ab.
    func cancelGame(gameId: String) async throws
    func fetchFinishedGames(userId: String) async throws -> [Game]
}

extension GameRepositoryProtocol {

    /// Legt eine Partie an und startet sie sofort – der ganze Weg vom
    /// „Spiel starten" bis zum Spielscreen.
    ///
    /// Stand vorher nur im Neues-Spiel-Screen. Seit es einen zweiten Weg in
    /// eine Partie gibt (dieselbe Aufstellung nochmal), waeren es zwei
    /// Kopien – und die zweite haette garantiert irgendwann vergessen, die
    /// Partie auch zu starten.
    ///
    /// Die Lobby wird dabei uebersprungen: Sie ergibt keinen Sinn, solange
    /// die App auf einem Geraet liegt.
    func createAndStart(
        type: GameType,
        teams: [Team],
        format: GameFormat,
        ownerId: String
    ) async throws -> String {
        let gameId = try await createGame(
            type: type,
            teams: teams,
            format: format,
            createdBy: ownerId,
            // Nur mein Konto darf das Spiel lesen und schreiben – die
            // Mitspieler sind Profile ohne eigenen Zugang.
            accessUserIds: [ownerId]
        )
        try await startGame(gameId: gameId)
        LastLineup.remember(type: type, teams: teams)
        return gameId
    }
}

final class GameRepository: GameRepositoryProtocol {

    private let gameService: GameServiceProtocol

    init(gameService: GameServiceProtocol) {
        self.gameService = gameService
    }

    func observeUserGames(currentUserId: String) -> AsyncStream<[Game]> {
        gameService.observeUserGames(userId: currentUserId)
    }

    func observeGame(gameId: String) -> AsyncStream<Game?> {
        gameService.observeGame(gameId: gameId)
    }

    func createGame(
        type: GameType,
        teams: [Team],
        format: GameFormat,
        createdBy: String,
        accessUserIds: [String]? = nil
    ) async throws -> String {
        guard teams.count == 2 else {
            throw AppError.validation("Ein Spiel braucht genau 2 Teams.")
        }

        let expectedPlayersPerTeam = (type == .oneVsOne)
            ? AppConstants.GameDefaults.minPlayersPerTeam
            : AppConstants.GameDefaults.maxPlayersPerTeam

        guard teams.allSatisfy({ $0.playerIds.count == expectedPlayersPerTeam }) else {
            throw AppError.validation("Jedes Team braucht genau \(expectedPlayersPerTeam) Spieler.")
        }

        let game = Game(
            type: type,
            createdBy: createdBy,
            teams: teams,
            format: format,
            currentTurnTeamId: teams.first?.id,
            accessUserIds: accessUserIds
        )
        return try await gameService.createGame(game)
    }

    func startGame(gameId: String) async throws {
        try await gameService.updateGameStatus(gameId: gameId, status: .active, startedAt: Date())
    }

    func finishGame(gameId: String, winnerTeamId: String?, cupsRemaining: [String: Int]?) async throws {
        try await gameService.finishGame(
            gameId: gameId,
            winnerTeamId: winnerTeamId,
            cupsRemaining: cupsRemaining
        )
    }

    /// Abbruch statt Löschen: Der Wurf-Log der angefangenen Partie bleibt
    /// erhalten, das Spiel verschwindet aber aus der Fortsetzen-Anzeige und
    /// wird nirgends gewertet.
    func cancelGame(gameId: String) async throws {
        try await gameService.updateGameStatus(gameId: gameId, status: .cancelled, startedAt: nil)
    }

    func fetchFinishedGames(userId: String) async throws -> [Game] {
        let games = try await gameService.fetchFinishedGames(userId: userId)
        return games.sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
    }
}
