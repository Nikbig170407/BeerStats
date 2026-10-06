//
//  AppAppearance.swift
//  BeerStats
//
//  Wie die App aussehen soll – der Teil, den der Nutzer bestimmt.
//
//  Der Hintergrund und die leuchtenden Kanten machen zusammen den Look aus,
//  den der Nutzer „zu sehr nach Softwareentwickler" genannt hat. Beides ist
//  Geschmack, und Geschmack gehoert nicht in den Quelltext fest verdrahtet.
//
//  Gespeichert in UserDefaults und nicht am Konto: Es ist eine Eigenschaft
//  dieses Geraets, keine der Daten. Wer die App auf einem zweiten Geraet
//  installiert, stellt sie dort neu ein – und das ist richtig so, denn
//  vielleicht ist es ein anderer Bildschirm.
//
//  Gelesen wird ueber `@AppStorage` direkt in den Bausteinen. Dadurch
//  springt die ganze App sofort um, wenn jemand den Schalter umlegt, ohne
//  dass eine einzige Ansicht davon wissen muss.
//

import SwiftUI

/// Wie viel im Hintergrund los ist.
enum BackdropStyle: String, CaseIterable, Identifiable {

    /// Blasen und zwei Lichtquellen – der Stand von Ende September.
    case bubbles
    /// Nur die Lichtquellen, keine Blasen.
    case calm
    /// Einfarbig mit einem Hauch Verlauf. Fuer die, denen alles andere zu
    /// viel ist – und fuer alte Geraete, die jede gesparte Zeichenflaeche
    /// merken.
    case plain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bubbles: return "Blasen"
        case .calm: return "Ruhig"
        case .plain: return "Schlicht"
        }
    }

    var detail: String {
        switch self {
        case .bubbles: return "Licht und Blasen"
        case .calm: return "nur Licht"
        case .plain: return "fast einfarbig"
        }
    }

    var showsBubbles: Bool { self == .bubbles }
    var showsGlow: Bool { self != .plain }
}

enum AppAppearance {

    static let backdropKey = "appearance.backdrop"
    static let neonEdgesKey = "appearance.neonEdges"

    static var backdrop: BackdropStyle {
        get {
            guard let raw = UserDefaults.standard.string(forKey: backdropKey),
                  let style = BackdropStyle(rawValue: raw)
            else { return .bubbles }
            return style
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: backdropKey) }
    }

    /// Ob die Karten leuchtende Kanten tragen.
    ///
    /// Ohne gesetzten Wert an: Das ist der Zustand, den es immer gab, und
    /// eine Einstellung soll nichts veraendern, solange niemand sie anfasst.
    static var neonEdgesOn: Bool {
        get {
            guard UserDefaults.standard.object(forKey: neonEdgesKey) != nil else { return true }
            return UserDefaults.standard.bool(forKey: neonEdgesKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: neonEdgesKey) }
    }
}
