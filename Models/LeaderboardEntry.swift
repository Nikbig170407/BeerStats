//
//  LeaderboardEntry.swift
//  BeerStats
//
//  Ein einzelner Ranglisten-Eintrag unter
//  `leaderboards/{scope}/entries/{userId}` (siehe Architektur-Dokument
//  Abschnitt 4). Wird periodisch bzw. eventbasiert durch eine Cloud
//  Function neu geschrieben – niemals bei jedem Client-Read live berechnet.
//  `scope` steht bewusst nicht im Dokument selbst, sondern ergibt sich aus
//  dem Collection-Pfad (z. B. "global", "friends_<userId>", "season_2026_q3").
//

import Foundation
import FirebaseFirestore

struct LeaderboardEntry: Codable, Identifiable, Equatable {

    /// Entspricht der User-ID.
    @DocumentID var id: String?

    var username: String
    var displayName: String
    var profileImageURL: String?

    var rank: Int
    var gamesPlayed: Int
    var winRate: Double
    var eloRating: Int

    @ServerTimestamp var updatedAt: Date?
}
