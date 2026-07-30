//
//  FriendsViewModel.swift
//  BeerStats
//
//  Konsumiert den Echtzeit-Stream aus FriendRepository über einen Task und
//  spiegelt ihn in @Published-Properties – die View bekommt nie den
//  AsyncStream direkt zu Gesicht (siehe Architektur-Dokument 9.2).
//

import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {

    @Published private(set) var friendships: [Friendship] = []
    @Published private(set) var friendProfiles: [String: User] = [:]

    @Published var searchQuery = ""
    @Published private(set) var searchResults: [User] = []
    @Published private(set) var isSearching = false

    @Published var errorMessage: String?

    private let friendRepository: FriendRepositoryProtocol
    private let currentUserId: String
    private var observationTask: Task<Void, Never>?

    init(friendRepository: FriendRepositoryProtocol, currentUserId: String) {
        self.friendRepository = friendRepository
        self.currentUserId = currentUserId
        startObserving()
    }

    deinit {
        observationTask?.cancel()
    }

    var acceptedFriends: [Friendship] {
        friendships.filter { $0.status == .accepted }
    }

    var incomingRequests: [Friendship] {
        friendships.filter { $0.status == .pending && $0.requestedBy != currentUserId }
    }

    var outgoingRequests: [Friendship] {
        friendships.filter { $0.status == .pending && $0.requestedBy == currentUserId }
    }

    /// Anzeigename des jeweils ANDEREN Teilnehmers einer Freundschaft.
    /// Friendship enthält bewusst nur IDs (siehe Architektur-Dokument
    /// 3.2) – die Namen werden hier aus dem lokalen Profil-Cache ergänzt.
    func displayName(for friendship: Friendship) -> String {
        guard let otherId = friendship.participantIds.first(where: { $0 != currentUserId }) else {
            return "Unbekannt"
        }
        return friendProfiles[otherId]?.displayName ?? "…"
    }

    private func startObserving() {
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await friendships in friendRepository.observeFriendships(currentUserId: currentUserId) {
                self.friendships = friendships
                await self.loadMissingProfiles()
            }
        }
    }

    private func loadMissingProfiles() async {
        let neededIds = Set(friendships.flatMap(\.participantIds))
            .subtracting([currentUserId])
            .subtracting(friendProfiles.keys)
        guard !neededIds.isEmpty else { return }

        do {
            let users = try await friendRepository.fetchProfiles(for: Array(neededIds))
            for user in users {
                if let id = user.id {
                    friendProfiles[id] = user
                }
            }
        } catch {
            AppLogger.firestore.error("Profil-Nachladen fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func search() async {
        errorMessage = nil
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            searchResults = try await friendRepository.searchUsers(query: searchQuery, excluding: currentUserId)
        } catch {
            errorMessage = AppError.from(error).errorDescription
        }
    }

    func sendRequest(to user: User) async {
        guard let targetId = user.id else { return }
        do {
            try await friendRepository.sendFriendRequest(from: currentUserId, to: targetId)
            HapticManager.lightImpact()
            searchResults.removeAll { $0.id == targetId }
        } catch {
            HapticManager.error()
            errorMessage = AppError.from(error).errorDescription
        }
    }

    func respond(to friendship: Friendship, accept: Bool) async {
        do {
            try await friendRepository.respond(to: friendship, accept: accept)
            HapticManager.lightImpact()
        } catch {
            errorMessage = AppError.from(error).errorDescription
        }
    }

    func removeFriend(_ friendship: Friendship) async {
        do {
            try await friendRepository.removeFriendship(friendship)
        } catch {
            errorMessage = AppError.from(error).errorDescription
        }
    }
}
