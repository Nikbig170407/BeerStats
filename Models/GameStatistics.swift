//
//  GameStatistics.swift
//  BeerStats
//
//  Wird einmalig bei Spielende in `games/{gameId}/statistics/summary`
//  berechnet (siehe Architektur-Dokument 3.6) – im Gegensatz zu
//  UserStatistics NICHT laufend während des Spiels aktualisiert, da diese
//  Zusammenfassung erst nach Spielende überhaupt einen finalen Sinn ergibt.
//

import Foundation
import FirebaseFirestore

struct GameStatistics: Codable, Equatable {

    /// Statistiken je Spieler-ID für genau dieses eine Spiel.
    var playerStats: [String: PlayerGameStats]

    var mvpPlayerId: String?

    @ServerTimestamp var calculatedAt: Date?
}

struct PlayerGameStats: Codable, Equatable {
    var totalThrows: Int = 0
    var hits: Int = 0
    var misses: Int = 0
    var airballs: Int = 0
    var bounceShotsMade: Int = 0
    var trickshotsMade: Int = 0
    var longestOnFireStreak: Int = 0

    var hitRate: Double {
        totalThrows == 0 ? 0 : Double(hits) / Double(totalThrows)
    }
}
