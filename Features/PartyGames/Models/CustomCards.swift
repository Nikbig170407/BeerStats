//
//  CustomCards.swift
//  BeerStats
//
//  Eigene Karten fuer die Kartenspiele.
//
//  Zweihundert fremde Karten sind gut, fuenf eigene machen es persoenlich.
//  Jede Runde hat ihre Geschichten, und die stehen in keinem Katalog, den
//  irgendwer vorher schreiben koennte.
//
//  Gespeichert wird lokal in UserDefaults, wie die Trinkhaerte und der Abend
//  auch. Das ist kein Sparen an Firestore, sondern das richtige Modell: Die
//  Karten gehoeren einer Runde, nicht einem Konto, und sie sollen ohne Netz
//  funktionieren.
//
//  Eigene Karten stehen NICHT vorne im Stapel, sondern werden untergemischt.
//  Kaemen sie zuerst, waeren sie nach fuenf Zuegen durch und der Abend liefe
//  danach wie vorher. Untergemischt taucht die eigene Karte irgendwann
//  zwischen den anderen auf – und genau dann wirkt sie.
//

import Foundation

/// Stapel, zu denen sich eigene Karten hinzufuegen lassen.
enum CustomCardDeck: String, CaseIterable, Identifiable {
    case neverHaveIEver
    case truthOrDare
    case extremeChallenge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .neverHaveIEver: return "Ich hab noch nie"
        case .truthOrDare: return "Wahrheit oder Pflicht"
        case .extremeChallenge: return "Beerpong Extreme"
        }
    }

    var emoji: String {
        switch self {
        case .neverHaveIEver: return "🙈"
        case .truthOrDare: return "😈"
        case .extremeChallenge: return "🍺"
        }
    }

    /// Was auf der Karte stehen soll – als Beispiel im Eingabefeld. Ohne das
    /// tippt der erste Nutzer einen Nachsatz statt eines ganzen Satzes, und
    /// die Karte passt dann grammatisch nicht zum Rest.
    var placeholder: String {
        switch self {
        case .neverHaveIEver: return "Ich hab noch nie ein Auto gefahren."
        case .truthOrDare: return "Ruf deine Mutter an und sing ihr etwas vor."
        case .extremeChallenge: return "Tausche für eine Runde den Platz."
        }
    }

    var hint: String {
        switch self {
        case .neverHaveIEver:
            // Der Fehler ist hier schon einmal passiert und hat den ganzen
            // Stapel unbrauchbar gemacht: Ein fester Vorspann kann nicht
            // aufgehen, weil es auch "Ich bin noch nie" und "Ich hatte noch
            // nie" gibt.
            return "Schreib den ganzen Satz, nicht nur den Nachsatz."
        case .truthOrDare:
            return "Eine Aufgabe oder eine Frage – beides landet im selben Stapel."
        case .extremeChallenge:
            return "Kommt als Challenge-Karte, wenn ein geladener Becher fällt."
        }
    }
}

enum CustomCards {

    private static func key(_ deck: CustomCardDeck) -> String {
        "customCards.\(deck.rawValue)"
    }

    static func cards(for deck: CustomCardDeck) -> [String] {
        UserDefaults.standard.stringArray(forKey: key(deck)) ?? []
    }

    static func add(_ text: String, to deck: CustomCardDeck) {
        let sauber = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sauber.isEmpty else { return }

        var vorhanden = cards(for: deck)
        // Doppelte still schlucken: Wer zweimal dasselbe eintippt, will keine
        // zwei Karten, sondern hat den ersten Versuch vergessen.
        guard !vorhanden.contains(sauber) else { return }

        vorhanden.append(sauber)
        UserDefaults.standard.set(vorhanden, forKey: key(deck))
    }

    static func remove(_ text: String, from deck: CustomCardDeck) {
        UserDefaults.standard.set(cards(for: deck).filter { $0 != text }, forKey: key(deck))
    }

    static func count(for deck: CustomCardDeck) -> Int {
        cards(for: deck).count
    }
}
