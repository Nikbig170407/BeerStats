//
//  RouletteWheel.swift
//  BeerStats
//
//  Die Raeder des Trink-Roulettes – drei fertige und ein eigenes.
//
//  Das Spiel hatte genau ein Rad mit acht festen Feldern. Das ist beim
//  zweiten Abend dasselbe Rad, und ab dem dritten weiss jeder, was
//  draufsteht. Jetzt waehlt man vorher aus, und wer will, baut sich ein
//  eigenes: Die besten Felder sind die, die nur diese Runde versteht.
//
//  Die Felder liegen hier im Katalog und nicht in der Ansicht – dieselbe
//  Entscheidung wie bei `PartyGame`. Ein viertes Rad ist dann ein neuer Fall
//  in der Aufzaehlung und sonst nichts.
//
//  Zwei Dinge, die beim Nachbauen wichtig sind:
//
//  Erstens traegt ein Feld seine Menge als `RouletteCost` und NICHT als Zahl
//  im Text. Eine eingetippte "3 Schluecke" ignoriert die eingestellte Haerte
//  stillschweigend; die Menge wird erst beim Anzeigen ausformuliert.
//  `RouletteCost` ist dabei ein eigener, speicherbarer Typ: `DrinkAmount`
//  traegt einen zugeordneten Wert und ist deshalb nicht `Codable` – und ein
//  gespeichertes Format soll ohnehin nicht am Anzeigetyp haengen (siehe die
//  Sicherungsdatei).
//
//  Zweitens steht die Menge im Satz dort, wo `{}` steht. Fehlt das
//  Platzhalter-Zeichen, kommt sie als eigene Zeile darunter. Das ist der
//  Grund, warum die eigenen Felder ohne Platzhalter auskommen: Niemand soll
//  eine Schreibweise lernen muessen, um ein Feld anzulegen.
//

import Foundation

/// Was ein Feld kostet.
///
/// Eine feste Auswahl und kein freies Zahlenfeld: Die Mengen muessen durch
/// `DrinkAmount` laufen, damit die Haerte gilt.
enum RouletteCost: String, Codable, CaseIterable, Identifiable {
    case nothing
    case oneSip
    case twoSips
    case threeSips
    case fourSips
    case shot

    var id: String { rawValue }

    var amount: DrinkAmount? {
        switch self {
        case .nothing: return nil
        case .oneSip: return .sips(1)
        case .twoSips: return .sips(2)
        case .threeSips: return .sips(3)
        case .fourSips: return .sips(4)
        case .shot: return .shot
        }
    }

    /// Wie die Menge in der Auswahl steht – in der geltenden Haerte, damit
    /// dort dieselbe Zahl steht wie spaeter auf dem Rad.
    var title: String {
        amount?.text ?? "Niemand trinkt"
    }
}

/// Ein Feld auf dem Rad.
struct RouletteWedge: Identifiable, Codable, Equatable {
    var id = UUID()
    /// Kurzform auf dem Rad. Bei acht Feldern ist alles Laengere nicht mehr
    /// lesbar – deshalb getrennt vom Satz.
    var label: String
    /// Der ganze Satz fuer die Anzeige nach der Drehung. Ein `{}` darin wird
    /// durch die Menge ersetzt.
    var text: String
    var cost: RouletteCost = .threeSips

    /// Der fertige Satz in der geltenden Haerte.
    var resolved: String {
        guard let amount = cost.amount else { return text }
        guard text.contains("{}") else { return "\(text) – \(amount.text)" }
        return text.replacingOccurrences(of: "{}", with: amount.text)
    }
}

enum RouletteWheel: String, CaseIterable, Identifiable, Codable {
    case classic
    case soft
    case hard
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Klassisch"
        case .soft: return "Zahm"
        case .hard: return "Hart"
        case .custom: return "Eigenes Rad"
        }
    }

    var emoji: String {
        switch self {
        case .classic: return "🎯"
        case .soft: return "🌱"
        case .hard: return "🔥"
        case .custom: return "✏️"
        }
    }

    /// Was die Wahl bedeutet, nicht was sie heisst.
    var detail: String {
        switch self {
        case .classic: return "Acht Felder, gemischt – Nachbarn, Verteilen, ein Shot"
        case .soft: return "Kleine Mengen, kein Shot, zwei Freilose"
        case .hard: return "Drei Shots im Rad und nichts umsonst"
        case .custom:
            let anzahl = RouletteWedges.stored().count
            guard anzahl > 0 else { return "Noch keine Felder – selbst anlegen" }
            return anzahl == 1 ? "1 eigenes Feld" : "\(anzahl) eigene Felder"
        }
    }

    /// Die Felder dieses Rades.
    var wedges: [RouletteWedge] {
        switch self {
        case .classic:
            return [
                RouletteWedge(label: "Du", text: "Du trinkst {}", cost: .threeSips),
                RouletteWedge(label: "Alle", text: "Alle trinken {}", cost: .twoSips),
                RouletteWedge(label: "Verteilen", text: "Verteile {}", cost: .fourSips),
                RouletteWedge(label: "Shot", text: "Du trinkst {}", cost: .shot),
                RouletteWedge(label: "Links", text: "Dein linker Nachbar trinkt {}", cost: .threeSips),
                RouletteWedge(label: "Glück", text: "Glück gehabt – niemand trinkt", cost: .nothing),
                RouletteWedge(label: "Rechts", text: "Dein rechter Nachbar trinkt {}", cost: .threeSips),
                RouletteWedge(label: "Zuletzt", text: "Wer zuletzt gelacht hat, trinkt {}", cost: .threeSips)
            ]

        case .soft:
            return [
                RouletteWedge(label: "Du", text: "Du trinkst {}", cost: .oneSip),
                RouletteWedge(label: "Alle", text: "Alle trinken {}", cost: .oneSip),
                RouletteWedge(label: "Glück", text: "Glück gehabt – niemand trinkt", cost: .nothing),
                RouletteWedge(label: "Links", text: "Dein linker Nachbar trinkt {}", cost: .twoSips),
                RouletteWedge(label: "Prost", text: "Stoß mit jemandem an – ihr beide {}", cost: .oneSip),
                RouletteWedge(label: "Frei", text: "Freilos – gib es weiter, wer es hat, darf einmal aussetzen", cost: .nothing),
                RouletteWedge(label: "Rechts", text: "Dein rechter Nachbar trinkt {}", cost: .twoSips),
                RouletteWedge(label: "Jüngster", text: "Der Jüngste am Tisch trinkt {}", cost: .twoSips)
            ]

        case .hard:
            return [
                RouletteWedge(label: "Shot", text: "Du trinkst {}", cost: .shot),
                RouletteWedge(label: "Alle", text: "Alle trinken {}", cost: .fourSips),
                RouletteWedge(label: "Duell", text: "Wähle jemanden – ihr beide {}", cost: .shot),
                RouletteWedge(label: "Verteilen", text: "Verteile {}", cost: .fourSips),
                RouletteWedge(label: "Links", text: "Dein linker Nachbar trinkt {}", cost: .fourSips),
                RouletteWedge(label: "Ex", text: "Trink dein Glas leer – oder nimm {}", cost: .shot),
                RouletteWedge(label: "Rechts", text: "Dein rechter Nachbar trinkt {}", cost: .fourSips),
                RouletteWedge(label: "Du", text: "Du trinkst {}", cost: .fourSips)
            ]

        case .custom:
            return RouletteWedges.stored()
        }
    }

    /// Kann mit diesem Rad gespielt werden?
    ///
    /// Die fertigen immer; das eigene erst ab drei Feldern. Mit zwei ist es
    /// eine Muenze und kein Rad – und ein Rad, das jeder zweite Zug trifft,
    /// ist nach drei Drehungen erzaehlt.
    var isPlayable: Bool {
        self == .custom ? wedges.count >= RouletteWedges.minimum : true
    }
}

/// Die eigenen Felder. Liegen lokal in UserDefaults, wie die eigenen Karten
/// und der Abend auch: Sie gehoeren einer Runde und nicht einem Konto.
enum RouletteWedges {

    /// Ab drei Feldern ist es ein Rad.
    static let minimum = 3
    /// Mehr als zehn sind auf dem Rad nicht mehr zu lesen – die Beschriftung
    /// steht im Tortenstueck und waechst nicht mit.
    static let maximum = 10

    static let storageKey = "drinkRoulette.customWedges"

    static func stored() -> [RouletteWedge] {
        guard let daten = UserDefaults.standard.data(forKey: storageKey),
              let felder = try? JSONDecoder().decode([RouletteWedge].self, from: daten)
        else { return [] }
        return felder
    }

    static func save(_ wedges: [RouletteWedge]) {
        guard let daten = try? JSONEncoder().encode(wedges) else { return }
        UserDefaults.standard.set(daten, forKey: storageKey)
    }

    /// Legt ein Feld an. Gibt `false` zurueck, wenn nichts passiert ist –
    /// die Ansicht soll dann nicht so tun, als haette sie gespeichert.
    @discardableResult
    static func add(label: String, text: String, cost: RouletteCost) -> Bool {
        let kurz = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let satz = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kurz.isEmpty, !satz.isEmpty else { return false }

        var felder = stored()
        guard felder.count < maximum else { return false }

        felder.append(RouletteWedge(label: kurz, text: satz, cost: cost))
        save(felder)
        return true
    }

    static func remove(id: UUID) {
        save(stored().filter { $0.id != id })
    }
}
