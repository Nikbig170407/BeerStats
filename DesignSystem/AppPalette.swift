//
//  AppPalette.swift
//  BeerStats
//
//  Das Farbschema der App – waehlbar, statt fest verdrahtet.
//
//  Verstellt werden die Akzentfarben UND der Grund, auf dem alles liegt –
//  Hintergrund, abgesetzter Hintergrund, Kartenflaeche. Nur so faerbt sich
//  die App wirklich um; mit bloss getauschtem Akzent bleibt es dieselbe
//  schwarze App mit anderen Knoepfen.
//
//  Die Schrift bleibt dagegen in jedem Schema dieselbe, und daran haengt
//  eine Bedingung, die kein Schema brechen darf: **Alle Gruende sind
//  dunkel.** Das warme Off-White ist fuer dunklen Grund gerechnet, und
//  ebenso jede Deckkraft in dieser App – `opacity(0.6)` auf hellem Grau
//  sieht anders aus als auf Schwarz. Ein helles Schema ist deshalb kein
//  weiterer Fall hier, sondern der Hell-Modus, und der ist eine eigene
//  Baustelle.
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

    // MARK: - Der Grund
    //
    // Drei Stufen, die aufeinander aufbauen: der Hintergrund des Screens,
    // der abgesetzte Hintergrund und die Flaeche einer Karte. Je Schema in
    // Richtung des Akzents getoent, aber immer dunkel – der hellste Wert
    // liegt bei 17 von 100. Darueber wird das Off-White der Schrift
    // schwammig, und saemtliche Deckkraefte der App stimmen nicht mehr.

    var backgroundPrimary: Color {
        switch self {
        case .amber: return Color(red: 0.059, green: 0.051, blue: 0.043)
        case .mint:  return Color(red: 0.039, green: 0.063, blue: 0.059)
        case .berry: return Color(red: 0.059, green: 0.043, blue: 0.063)
        case .ice:   return Color(red: 0.039, green: 0.051, blue: 0.071)
        }
    }

    var backgroundSecondary: Color {
        switch self {
        case .amber: return Color(red: 0.102, green: 0.086, blue: 0.075)
        case .mint:  return Color(red: 0.067, green: 0.106, blue: 0.098)
        case .berry: return Color(red: 0.102, green: 0.075, blue: 0.106)
        case .ice:   return Color(red: 0.067, green: 0.090, blue: 0.122)
        }
    }

    var surfaceElevated: Color {
        switch self {
        case .amber: return Color(red: 0.141, green: 0.122, blue: 0.102)
        case .mint:  return Color(red: 0.098, green: 0.149, blue: 0.137)
        case .berry: return Color(red: 0.141, green: 0.102, blue: 0.149)
        case .ice:   return Color(red: 0.098, green: 0.129, blue: 0.173)
        }
    }
}
