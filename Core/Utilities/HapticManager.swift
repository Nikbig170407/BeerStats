//
//  HapticManager.swift
//  BeerStats
//
//  Zentrale Stelle für haptisches Feedback. Wird v. a. während des Live-
//  Spiels wichtig (Becher-Treffer soll sich taktil bestätigt anfühlen,
//  ohne hinsehen zu müssen) – hier zentral definiert, damit die Intensität
//  app-weit konsistent bleibt statt an jeder Stelle neu entschieden zu werden.
//

import CoreHaptics
import UIKit

enum HapticManager {

    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
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

    /// Für den lautesten Moment eines Spiels: der Riss in Ring of Fire.
    /// Ein harter Stoß, den man in der Hand spürt, nicht nur ein Tippen.
    static func heavyImpact() {
        heavyGenerator.prepare()
        heavyGenerator.impactOccurred()
    }

    /// Für positiven Abschluss: Spiel gewonnen.
    static func success() {
        notificationGenerator.notificationOccurred(.success)
    }

    /// Für Fehlerzustände: z. B. Aktion fehlgeschlagen.
    static func error() {
        notificationGenerator.notificationOccurred(.error)
    }

    // MARK: - Muster

    /// Ein Stoss in einem Muster: wann (Sekunden ab Start), wie stark und wie
    /// hart (0 dumpf bis 1 scharf), beides von 0 bis 1.
    struct Tap: Equatable {
        let time: Double
        let intensity: Double
        let sharpness: Double
    }

    /// Spielt mehrere Stoesse als ein Muster – etwa den Schlag einer Karte
    /// in Ring of Fire, der mit dem Klang und der Szene zusammenfallen soll.
    ///
    /// Mit Core Haptics, wo das iPhone es kann: Ein Muster laeuft auf die
    /// Millisekunde und kennt Staerke und Haerte. Sonst als einzelne Stoesse
    /// mit den drei Generatoren oben – groeber, aber im selben Takt.
    static func play(_ taps: [Tap]) {
        guard !taps.isEmpty else { return }
        if playWithCoreHaptics(taps) { return }
        for tap in taps {
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, tap.time)) {
                if tap.intensity > 0.75 {
                    heavyImpact()
                } else if tap.intensity > 0.45 {
                    mediumImpact()
                } else {
                    lightImpact()
                }
            }
        }
    }

    /// Die Maschine fuer Muster. Einmal angelegt, schaltet sie sich im
    /// Leerlauf selbst ab und beim naechsten Muster wieder an.
    private static var engine: CHHapticEngine?

    private static func playWithCoreHaptics(_ taps: [Tap]) -> Bool {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return false }
        do {
            let maschine: CHHapticEngine
            if let vorhanden = engine {
                maschine = vorhanden
            } else {
                maschine = try CHHapticEngine()
                maschine.isAutoShutdownEnabled = true
                // Nach einer Unterbrechung (Anruf, Hintergrund) neu starten
                maschine.resetHandler = { [weak maschine] in try? maschine?.start() }
                engine = maschine
            }
            try maschine.start()
            let ereignisse = taps.map { tap in
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(min(1, max(0, tap.intensity)))),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(min(1, max(0, tap.sharpness))))
                    ],
                    relativeTime: max(0, tap.time)
                )
            }
            let muster = try CHHapticPattern(events: ereignisse, parameters: [])
            try maschine.makePlayer(with: muster).start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
    }
}
