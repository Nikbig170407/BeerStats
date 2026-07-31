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
    func finishGame(gameId: String, winnerTeamId: String?) async throws
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

    func finishGame(gameId: String, winnerTeamId: String?) async throws {
        try await gameService.finishGame(gameId: gameId, winnerTeamId: winnerTeamId)
    }
}
