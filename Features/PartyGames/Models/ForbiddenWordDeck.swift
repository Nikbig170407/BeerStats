//
//  ForbiddenWordDeck.swift
//  BeerStats
//
//  Woerter, die man den Abend ueber nicht sagen darf.
//
//  Alle so gewaehlt, dass sie im Gespraech von selbst vorkommen – sonst
//  passiert den ganzen Abend nichts. "Ich", "warum", "Bier" rutschen jedem
//  binnen Minuten raus; ein Wort wie "Regenschirm" waere ein stiller Abend.
//
//  Deshalb auch keine Fremdwoerter und keine Fachbegriffe: Das Spiel lebt
//  davon, dass das Wort unvermeidlich ist.
//

import Foundation

enum ForbiddenWordDeck {

    static var count: Int { all.count }

    /// Zieht so viele verschiedene Woerter, wie Spieler da sind.
    ///
    /// Ohne Wiederholung: Haetten zwei dasselbe Wort, wuerde ein Verstoss
    /// beide gleichzeitig treffen und niemand wuesste, wer gemeint ist.
    static func draw(_ count: Int) -> [String] {
        Array(all.shuffled().prefix(count))
    }

    static let all: [String] = [
        "ich", "du", "wir", "ja", "nein",
        "warum", "vielleicht", "eigentlich", "wirklich", "echt",
        "Bier", "trinken", "Schluck", "Prost", "Runde",
        "Handy", "Spiel", "Karte", "Wort", "Frage",
        "gut", "schlecht", "geil", "krass", "lustig",
        "heute", "morgen", "gestern", "immer", "nie",
        "Leute", "Freund", "Mann", "Frau", "Kind",
        "Zeit", "Geld", "Arbeit", "Schule", "Wochenende",
        "Musik", "Film", "Essen", "Hunger", "Durst",
        "kalt", "warm", "müde", "wach", "verrückt"
    ]
}
