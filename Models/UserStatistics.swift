//
//  UserStatistics.swift
//  BeerStats
//
//  Kanonische Lifetime-Statistik eines Nutzers, abgelegt unter
//  `users/{userId}/stats/summary` (siehe Architektur-Dokument 3.7).
//  Wird NIE komplett neu berechnet, sondern von einer Cloud Function bei
//  jedem relevanten Throw-Ereignis inkrementell fortgeschrieben
//  (FieldValue.increment). Ein Auszug dieser Werte wird zusätzlich in
//  User.stats gespiegelt, damit Profil-Vorschauen ohne Zusatz-Query
//  auskommen.
//

import Foundation
import FirebaseFirestore

struct UserStatistics: Codable, Equatable {

    var gamesPlayed: Int = 0
    var gamesWon: Int = 0

    var totalThrows: Int = 0
    var totalHits: Int = 0
    var totalAirballs: Int = 0
    var totalBounceShotsMade: Int = 0
    var totalTrickshotsMade: Int = 0

    var currentWinStreak: Int = 0
    var longestWinStreak: Int = 0
    var longestOnFireStreak: Int = 0

    /// Platzhalter-Feld für das spätere Elo-System (siehe Roadmap-
    /// Erweiterungen) – von Anfang an im Modell, um eine spätere
    /// Migration zu vermeiden.
    var eloRating: Int = 1000

    @ServerTimestamp var lastUpdated: Date?

    var hitRate: Double {
        totalThrows == 0 ? 0 : Double(totalHits) / Double(totalThrows)
    }
}
