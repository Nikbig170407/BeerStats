//
//  AppLogger.swift
//  BeerStats
//
//  Zentraler Logging-Wrapper um os.Logger. Ziel: konsistentes, kategorisiertes
//  Logging statt verstreuter print()-Aufrufe, filterbar in der Console.app
//  und ohne Performance-Kosten in Release-Builds für .debug-Level.
//
//  Verwendung: AppLogger.firestore.info("Spiel \(gameId) geladen")
//

import Foundation
import os

enum AppLogger {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.beerstats.app"

    /// Allgemeine App-Lifecycle-Ereignisse (Start, Firebase-Init, Push-Setup).
    static let app = Logger(subsystem: subsystem, category: "app")

    /// Authentifizierung (Login, Logout, Session-Änderungen).
    static let auth = Logger(subsystem: subsystem, category: "auth")

    /// Firestore-Lese-/Schreibzugriffe, Listener-Lifecycle.
    static let firestore = Logger(subsystem: subsystem, category: "firestore")

    /// Spiellogik: Wurf-Erfassung, Spielstatus-Wechsel, Undo.
    static let game = Logger(subsystem: subsystem, category: "game")

    /// Statistik-Berechnungen und -Abgleich.
    static let statistics = Logger(subsystem: subsystem, category: "statistics")

    /// UI-nahe Ereignisse, z. B. Navigation, die beim Debugging relevant sind.
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
