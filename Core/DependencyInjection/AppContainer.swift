//
//  AppContainer.swift
//  BeerStats
//
//  Zentraler Dependency-Injection-Container (siehe Architektur-Dokument,
//  9.1). Statt Services als `.shared`-Singletons zu implementieren, wird
//  hier genau einmal beim App-Start eine konkrete Instanz jedes Services
//  erzeugt und über die SwiftUI-Environment an ViewModels weitergereicht.
//

import SwiftUI
import Combine

struct AppContainer {

    let authService: AuthServiceProtocol
    let userService: UserServiceProtocol
    let authRepository: AuthRepositoryProtocol
    let friendRepository: FriendRepositoryProtocol
    let gameRepository: GameRepositoryProtocol
    let throwRepository: ThrowRepositoryProtocol

    /// Produktive Konfiguration mit echten Firebase-Implementierungen.
    static func live() -> AppContainer {
        let authService = FirebaseAuthService()
        let userService = FirebaseUserService()
        let friendService = FirebaseFriendService()
        let gameService = FirebaseGameService()
        let throwService = FirebaseThrowService()

        let authRepository = AuthRepository(authService: authService, userService: userService)
        let friendRepository = FriendRepository(friendService: friendService, userService: userService)
        let gameRepository = GameRepository(gameService: gameService)
        let throwRepository = ThrowRepository(throwService: throwService)

        return AppContainer(
            authService: authService,
            userService: userService,
            authRepository: authRepository,
            friendRepository: friendRepository,
            gameRepository: gameRepository,
            throwRepository: throwRepository
        )
    }

    /// Konfiguration für SwiftUI-Previews und Unit-Tests mit Mock-Implementierungen.
    static func preview() -> AppContainer {
        let authService = PreviewAuthService()
        let userService = PreviewUserService()
        let friendService = PreviewFriendService()
        let gameService = PreviewGameService()
        let throwService = PreviewThrowService()

        let authRepository = AuthRepository(authService: authService, userService: userService)
        let friendRepository = FriendRepository(friendService: friendService, userService: userService)
        let gameRepository = GameRepository(gameService: gameService)
        let throwRepository = ThrowRepository(throwService: throwService)

        return AppContainer(
            authService: authService,
            userService: userService,
            authRepository: authRepository,
            friendRepository: friendRepository,
            gameRepository: gameRepository,
            throwRepository: throwRepository
        )
    }
}

// MARK: - Environment-Integration

private struct AppContainerKey: EnvironmentKey {
    static let defaultValue = AppContainer.preview()
}

extension EnvironmentValues {
    var appContainer: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}

// MARK: - Preview-Mocks

private final class PreviewAuthService: AuthServiceProtocol {
    var authStatePublisher: AnyPublisher<String?, Never> { Just(nil).eraseToAnyPublisher() }
    var currentUserId: String? { nil }
    func signUp(email: String, password: String) async throws -> String { "preview-uid" }
    func signIn(email: String, password: String) async throws -> String { "preview-uid" }
    func signOut() throws {}
    func deleteAccount() async throws {}
}

private final class PreviewUserService: UserServiceProtocol {
    func createUserProfile(uid: String, username: String, displayName: String) async throws {}
    func fetchUser(uid: String) async throws -> User {
        User(id: uid, username: "previewuser", displayName: "Preview User")
    }
    func fetchUsers(uids: [String]) async throws -> [User] { [] }
    func searchUsers(usernamePrefix: String) async throws -> [User] { [] }
}

private final class PreviewFriendService: FriendServiceProtocol {
    func observeFriendships(participantId: String) -> AsyncStream<[Friendship]> {
        AsyncStream { continuation in
            continuation.yield([])
        }
    }
    func fetchFriendships(participantId: String) async throws -> [Friendship] { [] }
    func createFriendship(_ friendship: Friendship) async throws {}
    func updateStatus(friendshipId: String, status: FriendshipStatus) async throws {}
    func deleteFriendship(friendshipId: String) async throws {}
}

private final class PreviewGameService: GameServiceProtocol {
    func createGame(_ game: Game) async throws -> String { "preview-game-id" }
    func observeGame(gameId: String) -> AsyncStream<Game?> {
        AsyncStream { continuation in continuation.yield(nil) }
    }
    func observeUserGames(userId: String) -> AsyncStream<[Game]> {
        AsyncStream { continuation in continuation.yield([]) }
    }
    func updateGameStatus(gameId: String, status: GameStatus, startedAt: Date?) async throws {}
}

private final class PreviewThrowService: ThrowServiceProtocol {
    func appendThrow(_ throwEvent: Throw, gameId: String) async throws {}
    func observeThrows(gameId: String) -> AsyncStream<[Throw]> {
        AsyncStream { continuation in continuation.yield([]) }
    }
}
