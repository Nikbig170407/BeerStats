//
//  User.swift
//  BeerStats
//
//  Repräsentiert das Konto, mit dem man sich anmeldet – nicht den Spieler.
//  Wer am Tisch mitspielt, steht als `PlayerProfile` unter
//  `users/{uid}/players`, und dort hängen auch die Statistiken.
//
//  Das `stats`-Feld hier ist ein Überbleibsel aus der ursprünglichen
//  Planung mit einer Subcollection `users/{id}/stats/summary`, die eine
//  Cloud Function fortschreiben sollte. Ohne Blaze-Tarif gibt es diese
//  Function nicht, und beschrieben wird das Feld nirgends.
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
