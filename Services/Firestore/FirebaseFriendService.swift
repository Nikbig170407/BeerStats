//
//  FirebaseFriendService.swift
//  BeerStats
//
//  Konkrete Firestore-Implementierung. Der Echtzeit-Listener wird beim
//  Beenden des AsyncStreams (z. B. wenn die View verschwindet und der
//  konsumierende Task abgebrochen wird) automatisch über onTermination
//  entfernt – wichtig gegen unnötige Lesekosten und Memory Leaks.
//

import Foundation
import FirebaseFirestore

final class FirebaseFriendService: FriendServiceProtocol {

    private let db = Firestore.firestore()

    func observeFriendships(participantId: String) -> AsyncStream<[Friendship]> {
        AsyncStream { continuation in
            let listener = db.collection(AppConstants.Firestore.friendships)
                .whereField("participantIds", arrayContains: participantId)
                .addSnapshotListener { snapshot, error in
                    guard let snapshot else {
                        AppLogger.firestore.error(
                            "Friendships-Listener-Fehler: \(error?.localizedDescription ?? "unbekannt")"
                        )
                        return
                    }
                    let friendships = snapshot.documents.compactMap { try? $0.data(as: Friendship.self) }
                    continuation.yield(friendships)
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func fetchFriendships(participantId: String) async throws -> [Friendship] {
        let snapshot = try await db.collection(AppConstants.Firestore.friendships)
            .whereField("participantIds", arrayContains: participantId)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Friendship.self) }
    }

    func createFriendship(_ friendship: Friendship) async throws {
        let ref = db.collection(AppConstants.Firestore.friendships).document()
        let data = try Firestore.Encoder().encode(friendship)
        try await ref.setData(data)
    }

    func updateStatus(friendshipId: String, status: FriendshipStatus) async throws {
        try await db.collection(AppConstants.Firestore.friendships).document(friendshipId).updateData([
            "status": status.rawValue,
            "respondedAt": FieldValue.serverTimestamp()
        ])
    }

    func deleteFriendship(friendshipId: String) async throws {
        try await db.collection(AppConstants.Firestore.friendships).document(friendshipId).delete()
    }
}
