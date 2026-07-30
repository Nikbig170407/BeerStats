//
//  FriendRepository.swift
//  BeerStats
//
//  Verbindet FriendService (reine Firestore-Kommunikation) mit UserService
//  (für Profil-Anzeige und Suche) zu den fachlichen Vorgängen, die das
//  ViewModel tatsächlich braucht.
//

import Foundation

protocol FriendRepositoryProtocol {
    func observeFriendships(currentUserId: String) -> AsyncStream<[Friendship]>
    func searchUsers(query: String, excluding currentUserId: String) async throws -> [User]
    func sendFriendRequest(from currentUserId: String, to targetUserId: String) async throws
    func respond(to friendship: Friendship, accept: Bool) async throws
    func removeFriendship(_ friendship: Friendship) async throws
    func fetchProfiles(for userIds: [String]) async throws -> [User]

    /// Einmaliger Abruf aller akzeptierten Freunde als Profile – z. B. für
    /// die Mitspieler-Auswahl beim Erstellen eines neuen Spiels, wo kein
    /// Echtzeit-Update nötig ist.
    func fetchAcceptedFriends(currentUserId: String) async throws -> [User]
}

final class FriendRepository: FriendRepositoryProtocol {

    private let friendService: FriendServiceProtocol
    private let userService: UserServiceProtocol

    init(friendService: FriendServiceProtocol, userService: UserServiceProtocol) {
        self.friendService = friendService
        self.userService = userService
    }

    func observeFriendships(currentUserId: String) -> AsyncStream<[Friendship]> {
        friendService.observeFriendships(participantId: currentUserId)
    }

    func searchUsers(query: String, excluding currentUserId: String) async throws -> [User] {
        try await userService.searchUsers(usernamePrefix: query)
            .filter { $0.id != currentUserId }
    }

    func sendFriendRequest(from currentUserId: String, to targetUserId: String) async throws {
        guard currentUserId != targetUserId else {
            throw AppError.validation("Du kannst dich nicht selbst als Freund hinzufügen.")
        }

        let existing = try await friendService.fetchFriendships(participantId: currentUserId)
        guard !existing.contains(where: { $0.participantIds.contains(targetUserId) }) else {
            throw AppError.validation("Es besteht bereits eine Freundschaft oder offene Anfrage.")
        }

        let friendship = Friendship(
            participantIds: [currentUserId, targetUserId].sorted(),
            requestedBy: currentUserId
        )
        try await friendService.createFriendship(friendship)
    }

    func respond(to friendship: Friendship, accept: Bool) async throws {
        guard let id = friendship.id else { throw AppError.notFound("Freundschaftsanfrage") }
        try await friendService.updateStatus(friendshipId: id, status: accept ? .accepted : .declined)
    }

    func removeFriendship(_ friendship: Friendship) async throws {
        guard let id = friendship.id else { throw AppError.notFound("Freundschaft") }
        try await friendService.deleteFriendship(friendshipId: id)
    }

    func fetchProfiles(for userIds: [String]) async throws -> [User] {
        try await userService.fetchUsers(uids: userIds)
    }

    func fetchAcceptedFriends(currentUserId: String) async throws -> [User] {
        let acceptedOtherIds = try await friendService.fetchFriendships(participantId: currentUserId)
            .filter { $0.status == .accepted }
            .compactMap { $0.participantIds.first { $0 != currentUserId } }
        return try await userService.fetchUsers(uids: acceptedOtherIds)
    }
}
