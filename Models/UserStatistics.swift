//
//  UserStatistics.swift
//  BeerStats
//
//  Lifetime-Kennzahlen eines Spielers.
//
//  ACHTUNG, der Ort hat sich geändert: Ursprünglich war ein Dokument unter
//  `users/{userId}/stats/summary` geplant, das eine Cloud Function bei jedem
//  Wurf fortschreibt. Cloud Functions brauchen den Blaze-Tarif und fallen
//  damit aus – dorthin schreibt niemand, und das Dokument existiert nicht.
//
//  Tatsächlich hängen die Werte am `PlayerProfile` und werden vom iPhone
//  geschrieben, wenn im Sieger-Screen „Ergebnis übernehmen" gedrückt wird
//  (siehe PlayerProfileRepository.applyFinishedGame). Zeitraum-Werte
//  entstehen davon unabhängig durch Nachspielen der Wurf-Logs.
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
