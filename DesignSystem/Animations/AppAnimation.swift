//
//  AppAnimation.swift
//  BeerStats
//
//  Zentrale Animationskurven statt verstreuter .animation(.easeInOut(...))-
//  Aufrufe mit leicht unterschiedlichen Werten in jeder View. Sorgt dafür,
//  dass sich die gesamte App konsistent "smooth" anfühlt, statt dass jede
//  View ihr eigenes, leicht abweichendes Timing hat.
//

import SwiftUI

enum AppAnimation {

    /// Kurzes, knackiges Feedback bei Tap-Interaktionen (Buttons, Becher-Treffer).
    /// Federbasiert statt linear – wirkt organischer als ein reines easeInOut.
    static let tap = Animation.spring(response: 0.28, dampingFraction: 0.6)

    /// Standard-Übergang für größere UI-Zustandswechsel (z. B. Screen-Wechsel,
    /// Ein-/Ausblenden von Elementen).
    static let standard = Animation.spring(response: 0.4, dampingFraction: 0.82)

    /// Sanfte, längere Überblendung für nicht-interaktive Zustandswechsel
    /// (z. B. Laden-Indikator ein-/ausblenden).
    static let smoothFade = Animation.easeInOut(duration: AppConstants.Animation.standardTransition)

    /// Betont langsame, ruhige Bewegung für Ambient-Animationen (z. B. das
    /// Füllen des Becher-Loaders) – bewusst kein hektisches Timing.
    static let ambient = Animation.easeInOut(duration: 1.4)
}
