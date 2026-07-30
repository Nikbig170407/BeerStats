//
//  FriendServiceProtocol.swift
//  BeerStats
//
//  Kapselt alle Firestore-Zugriffe auf die `friendships`-Collection.
//

import Foundation

protocol FriendServiceProtocol {

    /// Echtzeit-Stream aller Freundschaften (jeder Status), an denen der
    /// übergebene Nutzer beteiligt ist. Wird als AsyncStream gekapselt
    /// (siehe Architektur-Dokument 9.2), damit die View nie direkt mit
    /// einem Firestore-Listener in Berührung kommt.
    func observeFriendships(participantId: String) -> AsyncStream<[Friendship]>

    /// Einmaliger Abruf, u. a. um vor dem Erstellen einer neuen Anfrage zu
    /// prüfen, ob bereits eine Freundschaft/Anfrage zwischen zwei Nutzern
    /// existiert.
    func fetchFriendships(participantId: String) async throws -> [Friendship]

    func createFriendship(_ friendship: Friendship) async throws
    func updateStatus(friendshipId: String, status: FriendshipStatus) async throws
    func deleteFriendship(friendshipId: String) async throws
}
