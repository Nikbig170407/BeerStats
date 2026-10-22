//
//  SongTimeline.swift
//  BeerStats
//
//  Die Reihe, in die ein Lied einsortiert wird – und die Frage, ob das
//  stimmt.
//
//  Eigener Wert und keine Rechnung in der Ansicht, weil hier genau das
//  passiert, was man nicht sehen kann: Eine Luecke ist richtig, wenn das
//  Jahr zwischen den Nachbarn liegt – und bei **gleichen Jahren auf beiden
//  Seiten**. Zwei Lieder aus 1997 duerfen in beliebiger Reihenfolge liegen;
//  waere das falsch, traenke jemand dafuer, dass zwei Hits im selben Jahr
//  erschienen sind.
//
//  Die Luecken sind um eins zahlreicher als die Karten: vor der ersten,
//  zwischen allen, nach der letzten.
//

import Foundation

struct SongTimeline: Equatable {

    private(set) var cards: [SongCard] = []

    var count: Int { cards.count }

    /// Vor der ersten Karte, zwischen allen, nach der letzten.
    var gapCount: Int { cards.count + 1 }

    /// Liegt das Jahr in dieser Luecke?
    func isCorrect(_ card: SongCard, at gap: Int) -> Bool {
        guard (0...cards.count).contains(gap) else { return false }

        let links = gap > 0 ? cards[gap - 1].year : Int.min
        let rechts = gap < cards.count ? cards[gap].year : Int.max
        return links <= card.year && card.year <= rechts
    }

    /// Einsortieren nach Jahr. Die Luecke wird nicht gebraucht: Richtig
    /// geraten heisst, dass genau diese Stelle gemeint war.
    mutating func insert(_ card: SongCard) {
        let stelle = cards.firstIndex { $0.year > card.year } ?? cards.count
        cards.insert(card, at: stelle)
    }

    /// Nimmt eine Karte wieder heraus – fuer den Fall, dass die Runde das
    /// Jahr fuer falsch haelt.
    mutating func remove(_ card: SongCard) {
        cards.removeAll { $0.id == card.id }
    }

    /// Wie die Luecke angesagt wird: „vor 1975", „1975 – 1991", „nach 1991".
    func label(forGap gap: Int) -> String {
        let links = gap > 0 ? cards[gap - 1].year : nil
        let rechts = gap < cards.count ? cards[gap].year : nil

        switch (links, rechts) {
        case let (nil, .some(r)): return "vor \(r)"
        case let (.some(l), nil): return "nach \(l)"
        case let (.some(l), .some(r)): return l == r ? "auch \(l)" : "\(l) – \(r)"
        case (nil, nil): return "irgendwo"
        }
    }
}
