//
//  AppConstants.swift
//  BeerStats
//
//  Zentrale Ablage für Konstanten, die in mehreren Teilen der App verwendet
//  werden. Ziel: keine Magic Numbers/Strings verstreut im Code, jede
//  Konstante hat einen aussagekräftigen Namen und eine einzige Quelle.
//

import Foundation

enum AppConstants {

    /// Namen der Firestore-Root-Collections. Zentral gepflegt, damit ein
    /// Tippfehler nicht erst zur Laufzeit als "Dokument nicht gefunden" auffällt,
    /// sondern als Compile-Fehler bei falscher Verwendung.
    enum Firestore {
        static let users = "users"
        static let friendships = "friendships"
        static let games = "games"
        static let throwsSubcollection = "throws"
        /// Mitspieler ohne eigenes Konto, verwaltet vom Besitzer des
        /// übergeordneten User-Dokuments (siehe PlayerProfile).
        static let playersSubcollection = "players"
        static let statisticsSubcollection = "statistics"
        static let statsSummaryDocument = "summary"
        static let leaderboards = "leaderboards"
        static let usernames = "usernames"
    }

    /// Spiel-Standardwerte. Als benannte Konstanten statt Zahlen im Code.
    enum GameDefaults {
        static let standardCupCount = 10
        static let minPlayersPerTeam = 1
        static let maxPlayersPerTeam = 2
        /// Ab so vielen Würfen zählt die Trefferquote eines Profils für den
        /// Vorschlag zum Ausgleich. Darunter ist sie Zufall: Wer dreimal
        /// geworfen und zweimal getroffen hat, steht mit 67 Prozent da.
        static let minimumThrowsForHandicap = 30
        /// Anzahl Treffer in Folge (durchgangsübergreifend), ab der ein
        /// Spieler "on Fire" ist und bei jedem weiteren Treffer einen
        /// Bonus-Wurf erhält.
        static let onFireStreakThreshold = 3
    }

    /// UI-Timing-Werte für konsistente Animationen in der gesamten App.
    enum Animation {
        static let quickFeedback: Double = 0.15
        static let standardTransition: Double = 0.3
    }

    /// Grenzwerte für Eingabevalidierung.
    enum Validation {
        static let usernameMinLength = 3
        static let usernameMaxLength = 20
        /// Namen von Mitspieler-Profilen stehen auf engen Chips im
        /// Spielscreen – deshalb kürzer begrenzt als ein Benutzername.
        static let profileNameMaxLength = 14
    }
}
