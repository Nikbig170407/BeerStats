//
//  NewGameViewModel.swift
//  BeerStats
//
//  Steuert Modus-Auswahl (1v1/2v2) und Mitspieler-Auswahl aus der
//  Freundesliste. Baut daraus die beiden Teams und legt das Spiel über
//  GameRepository an.
//

import Foundation

@MainActor
final class NewGameViewModel: ObservableObject {

    @Published var gameType: GameType = .oneVsOne {
        didSet { resetSelection() }
    }
    @Published var teammateId: String?
    @Published private(set) var opponentIds: Set<String> = []

    @Published private(set) var friends: [User] = []
    @Published private(set) var isLoadingFriends = false
    @Published private(set) var isCreating = false
    @Published var errorMessage: String?
    @Published private(set) var createdGameId: String?

    private let gameRepository: GameRepositoryProtocol
    private let friendRepository: FriendRepositoryProtocol
    private let userService: UserServiceProtocol
    let currentUserId: String

    init(
        gameRepository: GameRepositoryProtocol,
        friendRepository: FriendRepositoryProtocol,
        userService: UserServiceProtocol,
        currentUserId: String
    ) {
        self.gameRepository = gameRepository
        self.friendRepository = friendRepository
        self.userService = userService
        self.currentUserId = currentUserId
    }

    var requiredOpponentCount: Int {
        gameType == .oneVsOne ? 1 : 2
    }

    /// Freunde, die als Gegner wählbar sind (der bereits gewählte Partner
    /// scheidet aus, damit niemand doppelt im selben Spiel landet).
    var availableOpponents: [User] {
        friends.filter { $0.id != teammateId }
    }

    var canCreateGame: Bool {
        let teammateSatisfied = (gameType == .oneVsOne) || teammateId != nil
        return teammateSatisfied && opponentIds.count == requiredOpponentCount
    }

    func loadFriends() async {
        isLoadingFriends = true
        defer { isLoadingFriends = false }
        do {
            friends = try await friendRepository.fetchAcceptedFriends(currentUserId: currentUserId)
        } catch {
            errorMessage = AppError.from(error).errorDescription
        }
    }

    func toggleOpponent(_ userId: String) {
        if opponentIds.contains(userId) {
            opponentIds.remove(userId)
        } else if opponentIds.count < requiredOpponentCount {
            opponentIds.insert(userId)
        }
    }

    func clearCreatedGame() {
        createdGameId = nil
    }

    private func resetSelection() {
        teammateId = nil
        opponentIds.removeAll()
    }

    func createGame() async {
        guard canCreateGame else {
            errorMessage = "Bitte wähle alle Mitspieler aus."
            return
        }

        isCreating = true
        defer { isCreating = false }

        do {
            let me = try await userService.fetchUser(uid: currentUserId)

            var ownPlayerIds = [currentUserId]
            var ownPlayerNames = [me.displayName]
            if let teammateId, let teammate = friends.first(where: { $0.id == teammateId }) {
                ownPlayerIds.append(teammateId)
                ownPlayerNames.append(teammate.displayName)
            }

            let opponents = friends.filter { opponentIds.contains($0.id ?? "") }
            let opponentPlayerIds = opponents.compactMap(\.id)
            let opponentPlayerNames = opponents.map(\.displayName)

            let ownTeam = Team(
                id: UUID().uuidString,
                playerIds: ownPlayerIds,
                playerNames: ownPlayerNames,
                ballsInPlay: ownPlayerIds.count
            )
            let opponentTeam = Team(
                id: UUID().uuidString,
                playerIds: opponentPlayerIds,
                playerNames: opponentPlayerNames,
                ballsInPlay: opponentPlayerIds.count
            )

            createdGameId = try await gameRepository.createGame(
                type: gameType,
                teams: [ownTeam, opponentTeam],
                format: GameFormat(),
                createdBy: currentUserId
            )
            HapticManager.success()
        } catch {
            HapticManager.error()
            errorMessage = AppError.from(error).errorDescription
        }
    }
}
