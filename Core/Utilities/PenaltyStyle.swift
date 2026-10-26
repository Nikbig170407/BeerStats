//
//  PenaltyStyle.swift
//  BeerStats
//
//  Womit bezahlt wird: Schluecke, Liegestuetze, Kasse oder Aufgaben.
//
//  Bis Oktober 2026 hiess jede Strafe trinken. Wer nicht trinkt – weil er
//  faehrt, weil er nicht mag, weil er nicht darf – spielte damit nicht mit,
//  sondern sass daneben. Das ist bei einer App, die der ganzen Runde
//  gehoeren soll, keine Kleinigkeit: Ein Spiel, an dem einer nur zuschaut,
//  spielt die Runde beim naechsten Mal nicht mehr.
//
//  Der Eingriff ist trotzdem winzig, und das liegt an einer Entscheidung,
//  die lange vorher getroffen wurde: Mengen stehen nirgends als Zahl im
//  Text, sondern laufen alle durch `DrinkAmount`. Es gibt also genau EINE
//  Stelle, an der eine Menge zu einem Satz wird – und genau dort haengt
//  sich diese Datei ein. Haetten die Karten "3 Schluecke" im Text stehen,
//  waere das hier eine Woche Arbeit in zweihundert Zeichenketten.
//
//  Die Umrechnung ist bewusst GROB und deterministisch:
//
//  - Grob, weil eine Strafe fuehlbar bleiben muss. Drei Schluecke und fuenf
//    sind am Tisch dasselbe Gefuehl; drei Liegestuetze und fuenfzehn nicht.
//    Deshalb drei Stufen statt einer Formel.
//  - Deterministisch, weil derselbe Betrag an zwei Stellen gleich heissen
//    muss. Wuerfelte die Aufgabe, stuende auf der Karte etwas anderes als
//    in der Bilanz – und am Tisch waere das ein Streit.
//

import Foundation

enum PenaltyStyle: String, CaseIterable, Identifiable {
    /// Wie es immer war.
    case drinks
    /// Koerperlich. Die beliebteste Alternative, weil sie keine
    /// Vorbereitung braucht.
    case sport
    /// Geld in die Kasse. Am Ende des Abends gehoert sie jemandem.
    case kitty
    /// Aufgaben, die peinlich sind statt anstrengend.
    case task

    var id: String { rawValue }

    var title: String {
        switch self {
        case .drinks: return "Trinken"
        case .sport: return "Sport"
        case .kitty: return "Kasse"
        case .task: return "Aufgaben"
        }
    }

    var emoji: String {
        switch self {
        case .drinks: return "🍺"
        case .sport: return "💪"
        case .kitty: return "💰"
        case .task: return "🙈"
        }
    }

    var detail: String {
        switch self {
        case .drinks: return "Schlücke und Shots, wie gehabt"
        case .sport: return "Liegestütze und Kniebeugen statt Schlücke"
        case .kitty: return "Jede Strafe kostet Geld – am Ende gehört es jemandem"
        case .task: return "Kleine Aufgaben, die niemand nüchtern machen will"
        }
    }

    /// Die Ueberschrift der Bilanz. "Trinkbilanz" waere bei Liegestuetzen
    /// schlicht falsch.
    var tallyTitle: String {
        self == .drinks ? "TRINKBILANZ" : "STRAFBILANZ"
    }

    // MARK: - Die Einstellung

    static let storageKey = "penalty.style"

    static var current: PenaltyStyle {
        get {
            guard let raw = UserDefaults.standard.string(forKey: storageKey) else { return .drinks }
            return PenaltyStyle(rawValue: raw) ?? .drinks
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: storageKey) }
    }

    // MARK: - Wie viel

    /// Drei Stufen, nach denen sich jede Strafe richtet.
    ///
    /// Die Grenzen stehen hier und nicht in den vier Faellen darunter:
    /// Sonst waere "klein" beim Sport etwas anderes als bei der Kasse, und
    /// eine Karte faende sich in zwei Fassungen verschieden hart.
    enum Size {
        case small
        case medium
        case large

        /// Ein Shot ist immer gross – er ist die haerteste Menge, die das
        /// Spiel kennt.
        static func of(_ amount: DrinkAmount) -> Size {
            switch amount {
            case .shot: return .large
            case .sips(let base):
                if base <= 2 { return .small }
                return base <= 4 ? .medium : .large
            }
        }
    }

    /// Wie eine Menge in dieser Waehrung heisst.
    ///
    /// `nil` beim Trinken: Dann formuliert `DrinkAmount` selbst, samt
    /// Haerte und Shot-Schalter. Diese Datei soll den gewachsenen Weg nicht
    /// nachbauen, nur ersetzen, wo er nicht gilt.
    func text(for amount: DrinkAmount) -> String? {
        guard self != .drinks else { return nil }

        switch (self, Size.of(amount)) {
        case (.sport, .small):  return "5 Liegestütze"
        case (.sport, .medium): return "10 Liegestütze"
        case (.sport, .large):  return "20 Kniebeugen"

        case (.kitty, .small):  return "50 Cent in die Kasse"
        case (.kitty, .medium): return "1 € in die Kasse"
        case (.kitty, .large):  return "2 € in die Kasse"

        case (.task, .small):   return "ein Kompliment an deinen linken Nachbarn"
        case (.task, .medium):  return "eine Runde im Bierkasten-Gang durchs Zimmer"
        case (.task, .large):   return "erzähl deine peinlichste Geschichte"

        case (.drinks, _):      return nil
        }
    }

    /// Wie ein ANGESAMMELTER Stand heisst – die Bilanz am Ende des Abends.
    ///
    /// Gerechnet wird weiter in Schlucken und Shots: Das ist die Waehrung,
    /// in der gebucht wurde, und ein alter Abend soll nicht nachtraeglich
    /// umgerechnet werden, nur weil heute anders gespielt wird (dieselbe
    /// Regel wie bei den Punkten im Abend-Eintrag). Umgerechnet wird erst
    /// beim Anzeigen.
    func tallyText(sips: Int, shots: Int, separator: String, whenEmpty: String) -> String {
        guard self != .drinks else {
            var teile: [String] = []
            if sips > 0 { teile.append(sips == 1 ? "1 Schluck" : "\(sips) Schlücke") }
            if shots > 0 { teile.append(shots == 1 ? "1 Shot" : "\(shots) Shots") }
            return teile.isEmpty ? whenEmpty : teile.joined(separator: separator)
        }

        // Ein Shot zaehlt wie fuenf Schluecke – dieselbe Umrechnung, die
        // `Evening.weight` und `DrinkAmount` benutzen.
        let einheiten = sips + shots * 5
        guard einheiten > 0 else { return whenEmpty }

        switch self {
        case .sport:  return "\(einheiten * 2) Liegestütze"
        case .kitty:  return kasse(einheiten)
        case .task:   return einheiten == 1 ? "1 Aufgabe" : "\(einheiten) Aufgaben"
        case .drinks: return whenEmpty
        }
    }

    /// Fuenfzig Cent je Einheit, als Betrag statt als Rechnung.
    private func kasse(_ einheiten: Int) -> String {
        let cent = einheiten * 50
        let euro = cent / 100
        let rest = cent % 100
        return rest == 0 ? "\(euro) €" : "\(euro),\(String(format: "%02d", rest)) €"
    }
}
