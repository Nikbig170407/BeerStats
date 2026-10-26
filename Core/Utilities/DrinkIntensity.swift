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

    /// Der Schluessel der Vorgabe. Heisst weiter so, wie er hiess: Darunter
    /// liegt die Haerte, die der Nutzer schon gewaehlt hat, und die soll
    /// seine Vorgabe bleiben statt beim Update auf "Normal" zu springen.
    static let storageKey = "partyGames.drinkIntensity"

    /// Die Vorgabe fuer Spiele, bei denen noch nie etwas eingestellt wurde.
    ///
    /// Stand bis Oktober 2026 ueber den Partyspielen im Hauptmenue und galt
    /// fuer alle. Das war der Fehler: Mäxchen wird anders getrunken als
    /// Trink-Roulette, und wer das umstellen wollte, musste raus aus dem
    /// Spiel, eine Ebene hoch und wieder rein. Jetzt steht die Haerte im
    /// Vorspann des Spiels – hier steht nur noch, womit ein Spiel anfaengt,
    /// das man noch nie eingestellt hat.
    static var standard: DrinkIntensity {
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

    private static func key(for game: PartyGame) -> String {
        "\(storageKey).\(game.rawValue)"
    }

    /// Die Haerte EINES Spiels. Faellt auf die Vorgabe zurueck, solange
    /// dieses Spiel nie eingestellt wurde.
    static func stored(for game: PartyGame) -> DrinkIntensity {
        guard let raw = UserDefaults.standard.string(forKey: key(for: game)),
              let value = DrinkIntensity(rawValue: raw)
        else { return standard }
        return value
    }

    static func store(_ value: DrinkIntensity, for game: PartyGame) {
        UserDefaults.standard.set(value.rawValue, forKey: key(for: game))
    }

    // MARK: - Was gerade gilt

    /// Die Haerte des gerade geoeffneten Spiels – nur im Speicher, nicht in
    /// UserDefaults.
    ///
    /// Bewusst fluechtig: Sie gehoert zum offenen Screen, nicht zum Geraet.
    /// Bliebe sie gespeichert, liefe Beerpong Extreme nach einer harten
    /// Runde Schocken ploetzlich auch hart – ohne dass das irgendwo stuende.
    private static var active: DrinkIntensity?

    /// Die Haerte, in der eine Menge gerade ausformuliert wird.
    ///
    /// Ohne geoeffnetes Partyspiel ist das die Vorgabe. Genau das braucht
    /// Beerpong Extreme, das seine Haerte im Neues-Spiel-Screen stellt.
    static var current: DrinkIntensity {
        get { active ?? standard }
        set { active = newValue }
    }

    /// Beim Betreten eines Spiels: ab jetzt gilt dessen Haerte.
    static func activate(for game: PartyGame) {
        active = stored(for: game)
    }

    /// Beim Verlassen: zurueck zur Vorgabe. Muss sein, sonst faerbt das
    /// letzte Partyspiel auf alles ab, was danach Mengen ausformuliert.
    static func clearActive() {
        active = nil
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
    ///
    /// Wird nicht getrunken, formuliert `PenaltyStyle` – das ist der ganze
    /// Eingriff fuer "Strafen, die kein Trinken sind". Moeglich nur, weil
    /// Mengen nirgends als Zahl im Text stehen, sondern alle hier
    /// durchlaufen.
    var text: String {
        if let andere = PenaltyStyle.current.text(for: self) { return andere }

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

    /// Dieselbe Menge in Zaehleinheiten fuer die Trinkbilanz.
    ///
    /// Bewusst hier und nicht in der Bilanz: `text` und `tally` muessen
    /// dasselbe aussagen. Waere die Umrechnung an zwei Stellen gepflegt,
    /// koennte auf der Karte "einen Shot" stehen, waehrend die Bilanz
    /// Schluecke mitschreibt – und niemand wuesste, welche der beiden Zahlen
    /// stimmt.
    var tally: (sips: Int, shots: Int) {
        switch self {
        case .sips(let base):
            return (DrinkIntensity.current.sips(base), 0)
        case .shot:
            guard DrinkRules.shotsEnabled else {
                return (DrinkIntensity.current.sips(Self.shotInSips), 0)
            }
            return (0, 1)
        }
    }
}
