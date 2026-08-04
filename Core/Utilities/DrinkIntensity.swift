//
//  DrinkIntensity.swift
//  BeerStats
//
//  Wie hart die Trinkregeln ausfallen – eine Einstellung fuer alle
//  Partyspiele.
//
//  Bewusst zentral und nicht je Spiel: Wer eine milde Runde will, will sie
//  fuer den ganzen Abend und nicht in jedem Spiel neu einstellen. Die Wahl
//  ueberlebt einen Neustart, weil sie zur Runde gehoert und nicht zum
//  einzelnen Spiel.
//
//  Die Mengen sind Vielfache einer Grundzahl, nicht drei getrennte
//  Kartensaetze. Sonst muesste jede neue Karte dreimal geschrieben werden,
//  und die drei Fassungen liefen mit der Zeit auseinander.
//

import Foundation

enum DrinkIntensity: String, CaseIterable, Identifiable {
    case mild
    case normal
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mild: return "Mild"
        case .normal: return "Normal"
        case .hard: return "Hart"
        }
    }

    var emoji: String {
        switch self {
        case .mild: return "🌱"
        case .normal: return "🍺"
        case .hard: return "🔥"
        }
    }

    var subtitle: String {
        switch self {
        case .mild: return "Kleine Mengen, Shots werden zu Schlücken"
        case .normal: return "Wie gedacht"
        case .hard: return "Deutlich mehr, Shots öfter"
        }
    }

    // MARK: - Umrechnung

    private var factor: Double {
        switch self {
        case .mild: return 0.6
        case .normal: return 1.0
        case .hard: return 1.6
        }
    }

    /// Rechnet eine Grundmenge auf die gewaehlte Haerte um. Mindestens ein
    /// Schluck – eine Strafe von null waere keine.
    func sips(_ base: Int) -> Int {
        max(1, Int((Double(base) * factor).rounded()))
    }

    // MARK: - Persistenz

    private static let storageKey = "partyGames.drinkIntensity"

    static var current: DrinkIntensity {
        get {
            guard let raw = UserDefaults.standard.string(forKey: storageKey),
                  let value = DrinkIntensity(rawValue: raw)
            else { return .normal }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }
}

/// Eine Trinkmenge, bevor die Haerte darauf angewendet wurde.
///
/// Als eigener Typ und nicht als fertiger Text, damit dieselbe Karte in
/// allen drei Stufen funktioniert.
enum DrinkAmount: Equatable {
    case sips(Int)
    case shot

    /// Der ausgeschriebene Text in der aktuell gewaehlten Haerte.
    var text: String {
        let intensity = DrinkIntensity.current

        switch self {
        case .sips(let base):
            let count = intensity.sips(base)
            return count == 1 ? "1 Schluck" : "\(count) Schlücke"

        case .shot:
            // In der milden Stufe gibt es keine Shots. Das ist der ganze
            // Unterschied zwischen "weniger trinken" und "anders trinken".
            guard intensity != .mild else { return "5 Schlücke" }
            return "einen Shot"
        }
    }
}
