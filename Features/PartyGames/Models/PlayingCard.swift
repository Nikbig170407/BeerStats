//
//  PlayingCard.swift
//  BeerStats
//
//  Ein gewoehnliches Skatblatt mit 52 Karten.
//
//  Liegt bewusst bei den Modellen und nicht in einem einzelnen Spiel: Der
//  Koenigsbecher und der Bussfahrer brauchen beide ein echtes Blatt, und
//  zwei getrennte Kartenstapel waeren zwei Stellen, an denen dieselbe
//  Reihenfolge falsch sein kann.
//
//  Der Rang ist eine Zahl von 2 bis 14. Damit ist "hoeher oder tiefer" ein
//  Vergleich statt einer Sonderfallkette – das Ass zaehlt durchgaengig als
//  hoechste Karte.
//

import Foundation
import SwiftUI

struct PlayingCard: Identifiable, Equatable {

    enum Suit: String, CaseIterable, Identifiable {
        case hearts, diamonds, spades, clubs

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .hearts: return "♥"
            case .diamonds: return "♦"
            case .spades: return "♠"
            case .clubs: return "♣"
            }
        }

        var name: String {
            switch self {
            case .hearts: return "Herz"
            case .diamonds: return "Karo"
            case .spades: return "Pik"
            case .clubs: return "Kreuz"
            }
        }

        var isRed: Bool { self == .hearts || self == .diamonds }

        /// Die Farbe auf dem Blatt. Fest, nicht aus dem App-Thema – siehe
        /// `BeerStatsColor.cardInk`.
        var color: Color {
            isRed ? BeerStatsColor.cardInkRed : BeerStatsColor.cardInk
        }
    }

    let id = UUID()
    /// 2 bis 10, dann 11 Bube, 12 Dame, 13 Koenig, 14 Ass.
    let rank: Int
    let suit: Suit

    /// Kurzform fuer die Ecken der Karte.
    var label: String {
        switch rank {
        case 11: return "B"
        case 12: return "D"
        case 13: return "K"
        case 14: return "A"
        default: return "\(rank)"
        }
    }

    var rankName: String {
        switch rank {
        case 11: return "Bube"
        case 12: return "Dame"
        case 13: return "König"
        case 14: return "Ass"
        default: return "\(rank)"
        }
    }

    var isRed: Bool { suit.isRed }
}

enum PlayingCardDeck {

    static let ranks = Array(2...14)

    /// Ein vollstaendiges, gemischtes Blatt.
    /// Wie viele Karten ein vollstaendiger Stapel hat.
    static var fullSize: Int { ranks.count * PlayingCard.Suit.allCases.count }

    /// Ein gemischter Stapel mit `count` Karten – und IMMER vier von jedem
    /// Rang, der darin vorkommt.
    ///
    /// Vorher wurde der gemischte Stapel einfach abgeschnitten. Das sah
    /// harmlos aus und war der Grund, warum ein kurzer Ring sich falsch
    /// anfuehlte: Bei zwanzig Karten lagen dann drei Buben und ein Koenig
    /// darin, mal zwei Asse, mal keins. Regeln, die vom Zaehlen leben,
    /// gehen daran kaputt – ein Daumenmeister, den es nur einmal gibt, ist
    /// keine Rolle, sondern ein Zufall.
    ///
    /// Jetzt werden ganze RAENGE ausgelost: fuenf bei zwanzig Karten, acht
    /// bei zweiunddreissig, alle dreizehn beim vollen Blatt. Was fehlt,
    /// fehlt ganz – und was dabei ist, ist vollstaendig. Welche Raenge es
    /// werden, bleibt wie vorher eine Ueberraschung.
    ///
    /// Geht `count` nicht glatt durch vier, wird abgerundet: Lieber ein
    /// Rang weniger als ein unvollstaendiger.
    static func shuffled(count: Int) -> [PlayingCard] {
        let farben = PlayingCard.Suit.allCases
        let gewuenscht = max(farben.count, min(count, fullSize))
        let anzahlRaenge = max(1, gewuenscht / farben.count)

        return ranks.shuffled()
            .prefix(anzahlRaenge)
            .flatMap { rang in farben.map { PlayingCard(rank: rang, suit: $0) } }
            .shuffled()
    }

    static func shuffled() -> [PlayingCard] {
        PlayingCard.Suit.allCases
            .flatMap { suit in ranks.map { PlayingCard(rank: $0, suit: suit) } }
            .shuffled()
    }
}
