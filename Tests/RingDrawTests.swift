//
//  RingDrawTests.swift
//  BeerStatsTests
//
//  Die Auslosung im Ring, seit sie Wiederholungen vermeidet (28. Oktober:
//  "die Chancen verringern, dass man zweimal eine gleiche Karte zieht").
//  Gerechnet wird mit festem Startwert, damit ein Fehlschlag wiederholbar
//  ist.
//

import XCTest
@testable import BeerStats

final class RingDrawTests: XCTestCase {

    /// Der Rang von eben kommt nicht direkt wieder, solange etwas anderes
    /// liegt.
    func testTheRankFromJustNowDoesNotComeStraightBack() {
        var zufall = SeededGenerator(seed: 28)
        let ring = PlayingCardDeck.highestRanks(count: 20).map { Optional($0) }

        for _ in 0..<500 {
            guard let stelle = RingDraw.pick(ring: ring, recentRanks: [13], using: &zufall) else {
                return XCTFail("Es liegt doch noch etwas")
            }
            XCTAssertNotEqual(ring[stelle]?.rank, 13)
        }
    }

    /// Liegt nur noch dieser Rang, kommt er eben doch – ein Ring, aus dem
    /// sich nichts mehr ziehen laesst, waere schlimmer als eine
    /// Wiederholung.
    func testWhenOnlyThatRankIsLeftItStillComes() {
        var zufall = SeededGenerator(seed: 7)
        let ring: [PlayingCard?] = [nil, PlayingCard(rank: 14, suit: .hearts), nil, PlayingCard(rank: 14, suit: .spades)]

        let stelle = RingDraw.pick(ring: ring, recentRanks: [14, 13, 12], using: &zufall)

        XCTAssertNotNil(stelle)
        XCTAssertNotNil(stelle.flatMap { ring[$0] })
    }

    func testAnEmptyRingDrawsNothing() {
        var zufall = SeededGenerator(seed: 1)

        XCTAssertNil(RingDraw.pick(ring: [nil, nil, nil], recentRanks: [], using: &zufall))
        XCTAssertNil(RingDraw.pick(ring: [], recentRanks: [5], using: &zufall))
    }

    /// Eine ganze Runde zieht jede Karte genau einmal – die Gewichte
    /// aendern die Reihenfolge, nicht den Stapel.
    func testARoundStillDrawsEveryCardOnce() {
        var zufall = SeededGenerator(seed: 52)
        var ring = PlayingCardDeck.highestRanks(count: 52).map { Optional($0) }
        var gezogen: [PlayingCard] = []
        var letzte: [Int] = []

        while let stelle = RingDraw.pick(ring: ring, recentRanks: letzte, using: &zufall) {
            guard let karte = ring[stelle] else { return XCTFail("Leere Stelle gelost") }
            gezogen.append(karte)
            letzte.append(karte.rank)
            ring[stelle] = nil
        }

        XCTAssertEqual(gezogen.count, 52)
        XCTAssertEqual(Set(gezogen.map(\.id)).count, 52)
    }

    /// Worum es ging: Bei reinem Zufall kommt derselbe Rang im Schnitt
    /// dreimal je Runde direkt hintereinander und noch einmal so oft mit
    /// einer Karte dazwischen. Jetzt direkt praktisch nie, mit einer Karte
    /// dazwischen hoechstens gut halb so oft.
    func testRepeatsHaveBecomeRare() {
        for anzahl in [20, 32, 52] {
            var zufall = SeededGenerator(seed: UInt64(anzahl))
            var direkt = 0, eineDazwischen = 0
            let runden = 400

            for _ in 0..<runden {
                var ring = PlayingCardDeck.highestRanks(count: anzahl).map { Optional($0) }
                var letzte: [Int] = []
                while let stelle = RingDraw.pick(ring: ring, recentRanks: letzte, using: &zufall),
                      let karte = ring[stelle] {
                    if letzte.last == karte.rank { direkt += 1 }
                    if letzte.count > 1, letzte[letzte.count - 2] == karte.rank { eineDazwischen += 1 }
                    letzte.append(karte.rank)
                    ring[stelle] = nil
                }
            }

            let jeRundeDirekt = Double(direkt) / Double(runden)
            let jeRundeEineDazwischen = Double(eineDazwischen) / Double(runden)
            XCTAssertLessThan(jeRundeDirekt, 0.15, "\(anzahl) Karten: \(jeRundeDirekt) direkte Wiederholungen je Runde")
            XCTAssertLessThan(jeRundeEineDazwischen, 1.7, "\(anzahl) Karten: \(jeRundeEineDazwischen) mit einer dazwischen")
        }
    }
}
