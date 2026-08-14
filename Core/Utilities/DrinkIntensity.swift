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
        // Ob Shots vorkommen, steht hier bewusst nicht mehr: Das entscheidet
        // seit der Trennung ein eigener Schalter, nicht die Härte.
        case .mild: return "Kleine Mengen"
        case .normal: return "Wie gedacht"
        case .hard: return "Deutlich mehr"
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

    static let storageKey = "partyGames.drinkIntensity"

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

/// Regeln, die fuer alle Trinkmengen gelten – unabhaengig von der Haerte.
enum DrinkRules {

    static let shotsStorageKey = "partyGames.shotsEnabled"

    /// Ist das aus, werden Shots in Schlucke umgerechnet. Fuer Runden, die
    /// schlicht nichts zum Shotten dastehen haben.
    static var shotsEnabled: Bool {
        get {
            // Ohne gesetzten Wert an: Shots sind der Normalfall, und ein
            // frisch installiertes Spiel soll nicht stillschweigend zahmer
            // sein als gedacht.
            guard UserDefaults.standard.object(forKey: shotsStorageKey) != nil else { return true }
            return UserDefaults.standard.bool(forKey: shotsStorageKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: shotsStorageKey) }
    }
}

/// Eine Trinkmenge, bevor die Haerte darauf angewendet wurde.
///
/// Als eigener Typ und nicht als fertiger Text, damit dieselbe Karte in
/// allen drei Stufen funktioniert.
enum DrinkAmount: Equatable {
    case sips(Int)
    case shot

    /// Wie viele Schlucke ein Shot ersetzt, wenn ohne Shots gespielt wird.
    /// Die Haerte wird darauf noch angewendet – aus fuenf werden mild drei
    /// und hart acht.
    private static let shotInSips = 5

    /// Der ausgeschriebene Text in der aktuell gewaehlten Haerte.
    var text: String {
        let intensity = DrinkIntensity.current

        switch self {
        case .sips(let base):
            let count = intensity.sips(base)
            return count == 1 ? "1 Schluck" : "\(count) Schlücke"

        case .shot:
            // Ob ueberhaupt Shots vorkommen, haengt nicht mehr an der Haerte,
            // sondern an einem eigenen Schalter. Die beiden Fragen sind
            // verschieden: "Wie viel wird getrunken" und "Habt ihr etwas zum
            // Shotten da". Frueher war das eins, und wer hart spielen wollte,
            // brauchte zwingend Kurze im Haus.
            guard DrinkRules.shotsEnabled else { return DrinkAmount.sips(Self.shotInSips).text }
            return "einen Shot"
        }
    }
}
