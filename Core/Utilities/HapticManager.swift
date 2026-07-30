//
//  HapticManager.swift
//  BeerStats
//
//  Zentrale Stelle für haptisches Feedback. Wird v. a. während des Live-
//  Spiels wichtig (Becher-Treffer soll sich taktil bestätigt anfühlen,
//  ohne hinsehen zu müssen) – hier zentral definiert, damit die Intensität
//  app-weit konsistent bleibt statt an jeder Stelle neu entschieden zu werden.
//

import UIKit

enum HapticManager {

    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// Für kleine, häufige Interaktionen: Button-Taps, Auswahl-Änderungen.
    static func lightImpact() {
        lightGenerator.prepare()
        lightGenerator.impactOccurred()
    }

    /// Für bedeutsamere Aktionen: ein Becher-Treffer während des Spiels.
    static func mediumImpact() {
        mediumGenerator.prepare()
        mediumGenerator.impactOccurred()
    }

    /// Für positiven Abschluss: Spiel gewonnen.
    static func success() {
        notificationGenerator.notificationOccurred(.success)
    }

    /// Für Fehlerzustände: z. B. Aktion fehlgeschlagen.
    static func error() {
        notificationGenerator.notificationOccurred(.error)
    }
}
