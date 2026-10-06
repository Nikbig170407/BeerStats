//
//  AppPalette.swift
//  BeerStats
//
//  Das Farbschema der App – waehlbar, statt fest verdrahtet.
//
//  Verstellt werden die beiden Akzentfarben, nicht Hintergrund und Text.
//  Das ist Absicht:
//
//  Der Akzent ist ohnehin ueberall – Kanten, Knoepfe, Zahlen, Diagramme.
//  Ihn zu tauschen faerbt die App sichtbar um. Hintergrund und Schrift
//  dagegen sind aufeinander abgestimmt (warmes Schwarz, warmes Off-White);
//  wer sie je Schema mitdreht, baut vier Paletten, die alle einzeln auf
//  Lesbarkeit geprueft werden muessen. Dafuer gibt es den Hell-Modus, und
//  der ist eine eigene Baustelle.
//
//  Die Becherfarben bleiben in jedem Schema gleich. Ein Red Solo Cup ist
//  rot, auch wenn die App gerade gruen ist – das ist die Farbe eines
//  realen Gegenstands und kein Designwert.
//
//  Die Werte stehen hier als Zahlen und nicht im Asset-Katalog: Dort hat
//  jede Farbe genau einen Wert, und vier Schemata waeren vier mal sechzehn
//  Eintraege, die niemand nebeneinander sieht.
//

import SwiftUI

enum AppPalette: String, CaseIterable, Identifiable {

    /// Bier-Bernstein und Cup-Rot – womit die App gebaut wurde.
    case amber
    case mint
    case berry
    case ice

    var id: String { rawValue }

    static let storageKey = "appearance.palette"

    static var current: AppPalette {
        get {
            guard let raw = UserDefaults.standard.string(forKey: storageKey),
                  let palette = AppPalette(rawValue: raw)
            else { return .amber }
            return palette
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: storageKey) }
    }

    var title: String {
        switch self {
        case .amber: return "Bernstein"
        case .mint: return "Minze"
        case .berry: return "Beere"
        case .ice: return "Eis"
        }
    }

    /// Die primaere Akzentfarbe. Muss hell genug bleiben, dass der dunkle
    /// Text auf ihr lesbar ist – auf Knoepfen steht `textOnAccent` darauf.
    var accent: Color {
        switch self {
        case .amber: return Color(red: 0.91, green: 0.64, blue: 0.24)
        case .mint:  return Color(red: 0.31, green: 0.76, blue: 0.63)
        case .berry: return Color(red: 0.72, green: 0.42, blue: 0.85)
        case .ice:   return Color(red: 0.36, green: 0.65, blue: 0.97)
        }
    }

    /// Der zweite Akzent – steht neben dem ersten, nie darauf.
    var accentSecondary: Color {
        switch self {
        case .amber: return Color(red: 0.84, green: 0.27, blue: 0.27)
        case .mint:  return Color(red: 0.23, green: 0.56, blue: 0.65)
        case .berry: return Color(red: 0.88, green: 0.33, blue: 0.50)
        case .ice:   return Color(red: 0.49, green: 0.55, blue: 0.96)
        }
    }
}
