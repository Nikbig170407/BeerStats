//
//  Colors.swift
//  BeerStats
//
//  Semantische Farbnamen statt fest codierter Color(...)-Werte in Views.
//  So laesst sich das Farbschema zentral aendern, ohne eine einzige View
//  anzufassen – und genau das passiert seit Oktober 2026 auch wirklich.
//
//  **Zwei Quellen, und der Unterschied ist wichtig:**
//
//  Akzente und Hintergruende kommen aus `AppPalette` – sie sind in den
//  Einstellungen waehlbar und werden beim Zeichnen berechnet. Sie stehen
//  deshalb als `static var` hier, nicht als `let`.
//
//  Schrift, Statusfarben und die Becher kommen weiter aus Assets.xcassets.
//  Sie gelten in jedem Schema: Die Schrift ist auf dunklen Grund gerechnet
//  (und alle Schemata sind dunkel), Gruen heisst Treffer und Rot heisst
//  Fehler unabhaengig vom Anstrich, und ein Red Solo Cup ist die Farbe
//  eines realen Gegenstands.
//
//  Design-Konzept "Taproom bei Nacht": ein warmer, naher Schwarzton statt
//  kaltem Grau, mit Bier-Bernstein und Cup-Rot als Akzente – bewusst aus dem
//  Beerpong-Thema abgeleitet statt eines generischen Dark-Mode-Schemas. Das
//  ist bis heute das Schema „Bernstein" und die Voreinstellung.
//
//  Fest im Asset-Katalog (siehe dort für die Color-Set-Definitionen):
//    TextPrimary        #F5F1EA  warmes Off-White
//    TextSecondary      #A69C8D  gedämpfter Text
//    TextOnAccent       #1A1310  dunkler Text auf hellem Akzent-Hintergrund
//    StatusSuccess      #6FBE44  Foam-Grün – z. B. Treffer
//    StatusWarning      #E0902E  Warnung
//    StatusError        #E5484D  Fehler, verlorenes Spiel
//
//  Die Farbsaetze AccentColor, AccentSecondary, BackgroundPrimary,
//  BackgroundSecondary und SurfaceElevated liegen weiterhin im Katalog –
//  gelesen werden sie von hier aus nicht mehr. AccentColor braucht iOS
//  weiterhin fuer die Systemfarbe der App.
//

import SwiftUI

enum BeerStatsColor {

    // Marken- und Akzentfarben.
    //
    // Als einzige Farben kommen sie nicht aus dem Asset-Katalog, sondern aus
    // `AppPalette` – sie sind in den Einstellungen waehlbar. Berechnet statt
    // gespeichert, damit ein Wechsel sofort gilt; die App baut dazu ihre
    // Ansichten neu auf (siehe BeerStatsApp).
    static var accent: Color { AppPalette.current.accent }
    static var accentSecondary: Color { AppPalette.current.accentSecondary }


    // Hintergründe – ebenfalls aus der Palette, damit ein Schemawechsel
    // nicht nur die Knöpfe umfärbt, sondern den Grund darunter. Alle vier
    // Schemata bleiben dunkel; die Schrift unten ist dafür gerechnet.
    static var backgroundPrimary: Color { AppPalette.current.backgroundPrimary }
    static var backgroundSecondary: Color { AppPalette.current.backgroundSecondary }
    static var surfaceElevated: Color { AppPalette.current.surfaceElevated }

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
