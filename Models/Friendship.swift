//
//  Friendship.swift
//  BeerStats
//
//  Zentrale Top-Level-Collection statt Subcollection unter jedem User
//  (siehe Architektur-Dokument 3.2) – verhindert inkonsistente
//  Doppelschreibungen bei Freundschaftsanfragen.
//

import Foundation
import FirebaseFirestore

enum FriendshipStatus: String, Codable {
    case pending
    case accepted
    case declined
}

struct Friendship: Codable, Identifiable, Equatable {

    @DocumentID var id: String?

    /// Immer genau 2 User-IDs, sortiert abgelegt (siehe Repository), damit
    /// `array-contains`-Queries zuverlässig funktionieren und sich
    /// Duplikate leicht erkennen lassen.
    var participantIds: [String]

    var status: FriendshipStatus
    var requestedBy: String

    @ServerTimestamp var createdAt: Date?
    var respondedAt: Date?

    init(
        id: String? = nil,
        participantIds: [String],
        status: FriendshipStatus = .pending,
        requestedBy: String,
        respondedAt: Date? = nil
    ) {
        self.id = id
        self.participantIds = participantIds
        self.status = status
        self.requestedBy = requestedBy
        self.respondedAt = respondedAt
    }
}
