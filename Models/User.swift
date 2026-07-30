//
//  User.swift
//  BeerStats
//
//  Repräsentiert einen Nutzer. `stats` enthält bewusst nur eine schlanke,
//  denormalisierte Momentaufnahme der wichtigsten Kennzahlen (siehe
//  Architektur-Dokument 3.1) – die vollständige, laufend fortgeschriebene
//  Statistik liegt in der Subcollection `users/{id}/stats/summary`
//  (siehe UserStatistics.swift). So können Profil-Vorschauen und Ranglisten
//  ohne zusätzliche Query direkt aus dem User-Dokument lesen.
//

import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable, Equatable {

    @DocumentID var id: String?

    var username: String
    var displayName: String
    var profileImageURL: String?

    @ServerTimestamp var createdAt: Date?
    var lastActiveAt: Date?
    var fcmToken: String?

    var privacySettings: PrivacySettings
    var stats: UserStatsSnapshot

    init(
        id: String? = nil,
        username: String,
        displayName: String,
        profileImageURL: String? = nil,
        fcmToken: String? = nil,
        privacySettings: PrivacySettings = PrivacySettings(),
        stats: UserStatsSnapshot = UserStatsSnapshot()
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.profileImageURL = profileImageURL
        self.fcmToken = fcmToken
        self.privacySettings = privacySettings
        self.stats = stats
    }
}

/// Sichtbarkeitseinstellung für die eigenen Statistiken.
enum StatsVisibility: String, Codable {
    case everyone
    case friendsOnly
}

struct PrivacySettings: Codable, Equatable {
    var statsVisibility: StatsVisibility = .friendsOnly
}

/// Schlanke, denormalisierte Momentaufnahme der wichtigsten Kennzahlen –
/// wird von einer Cloud Function bei jeder Statistik-Aktualisierung
/// zusätzlich in dieses Feld gespiegelt (siehe UserStatistics für die
/// vollständigen, kanonischen Werte).
struct UserStatsSnapshot: Codable, Equatable {
    var gamesPlayed: Int = 0
    var gamesWon: Int = 0
    var hitRate: Double = 0
    var eloRating: Int = 1000 // Startwert, Feature selbst folgt später (siehe Roadmap)
}
