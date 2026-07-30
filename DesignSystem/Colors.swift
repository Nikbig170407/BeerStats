//
//  Colors.swift
//  BeerStats
//
//  Semantische Farbnamen statt fest codierter Color(...)-Werte in Views.
//  Die konkreten Werte liegen als Color Sets in Assets.xcassets, hier stehen
//  nur die semantischen Zugriffspunkte. So kann das komplette Farbschema
//  später zentral angepasst werden, ohne eine einzige View anzufassen.
//
//  Design-Konzept "Taproom bei Nacht": ein warmer, naher Schwarzton statt
//  kaltem Grau, mit Bier-Bernstein und Cup-Rot als Akzente – bewusst aus dem
//  Beerpong-Thema abgeleitet statt eines generischen Dark-Mode-Schemas.
//
//  Palette (siehe Assets.xcassets für die Color-Set-Definitionen):
//    AccentColor        #E8A33D  Bier-Bernstein – primäre Akzentfarbe
//    AccentSecondary    #D64545  Cup-Rot – zweiter Akzent, z. B. Warnhinweise
//    BackgroundPrimary  #0F0D0B  Haupt-Hintergrund
//    BackgroundSecondary#1A1613  abgesetzter Hintergrund (z. B. Sections)
//    SurfaceElevated    #241F1A  Karten, erhöhte Flächen
//    TextPrimary        #F5F1EA  warmes Off-White
//    TextSecondary      #A69C8D  gedämpfter Text
//    TextOnAccent       #1A1310  dunkler Text auf hellem Akzent-Hintergrund
//    StatusSuccess      #6FBE44  Foam-Grün – z. B. Treffer
//    StatusWarning      #E0902E  Warnung
//    StatusError        #E5484D  Fehler, verlorenes Spiel
//

import SwiftUI

enum BeerStatsColor {

    // Marken- und Akzentfarben
    static let accent = Color("AccentColor")
    static let accentSecondary = Color("AccentSecondary")

    // Hintergründe
    static let backgroundPrimary = Color("BackgroundPrimary")
    static let backgroundSecondary = Color("BackgroundSecondary")
    static let surfaceElevated = Color("SurfaceElevated")

    // Text
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let textOnAccent = Color("TextOnAccent")

    // Semantische Status-Farben
    static let success = Color("StatusSuccess")
    static let warning = Color("StatusWarning")
    static let error = Color("StatusError")

    // Becher-Farben für das Live-Tracking. Anders als die Farben oben sind
    // das keine Theme-Werte, sondern die Farbe eines realen Gegenstands
    // (Red Solo Cup) – sie bleiben deshalb in jedem Erscheinungsbild gleich.
    // Die fünf Abstufungen bilden zusammen die Wölbung des Bechers ab.
    static let cupHighlight = Color("CupHighlight")
    static let cupBase = Color("CupBase")
    static let cupMid = Color("CupMid")
    static let cupShadow = Color("CupShadow")
    static let cupRimEdge = Color("CupRimEdge")
}

// MARK: - Profilfarben

/// Bildet die im Modell gespeicherten Farbnamen auf konkrete Farben ab.
///
/// Die Zuordnung liegt bewusst hier und nicht im Modell: `ProfileColor`
/// bleibt dadurch frei von SwiftUI, und die Palette lässt sich anpassen,
/// ohne bestehende Profile zu migrieren.
extension ProfileColor {

    var color: Color {
        switch self {
        case .amber: return BeerStatsColor.accent
        case .red: return BeerStatsColor.accentSecondary
        case .green: return BeerStatsColor.success
        case .blue: return Color(red: 0.29, green: 0.56, blue: 0.89)
        case .purple: return Color(red: 0.61, green: 0.45, blue: 0.87)
        case .teal: return Color(red: 0.24, green: 0.71, blue: 0.678)
        }
    }
}
