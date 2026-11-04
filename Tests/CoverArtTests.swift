//
//  CoverArtTests.swift
//  BeerStatsTests
//
//  Die Satz-Regel der Szenen, eine Ebene hoeher: Jedes Cover laesst sich in
//  einem Satz sagen, ohne ein Emoji zu nennen, und kein Satz kommt doppelt
//  vor. Ob ein Cover gut aussieht, kann kein Test sagen – aber dass zwei
//  Spiele nicht dasselbe Bild tragen, schon.
//

import XCTest
@testable import BeerStats

final class CoverArtTests: XCTestCase {

    func testEveryCoverHasASentence() {
        for cover in CoverArt.allCases {
            XCTAssertFalse(cover.sentence.trimmingCharacters(in: .whitespaces).isEmpty, "\(cover)")
        }
    }

    func testNoTwoCoversShareASentence() {
        let saetze = CoverArt.allCases.map(\.sentence)
        XCTAssertEqual(Set(saetze).count, saetze.count)
    }

    /// Ein Cover, das sich nur ueber ein Zeichen beschreiben laesst, ist das
    /// Emoji auf dem Farbverlauf, das es ersetzen soll.
    func testNoSentenceLeansOnAnEmoji() {
        for cover in CoverArt.allCases {
            XCTAssertFalse(
                cover.sentence.unicodeScalars.contains { $0.properties.isEmojiPresentation },
                "\(cover): \(cover.sentence)"
            )
        }
    }

    /// Kein Bild auf zwei Spielen, und keins, das an keinem haengt.
    func testEveryCoverBelongsToExactlyOneGame() {
        let vergeben = PartyGame.allCases.compactMap(\.coverArt)
        XCTAssertEqual(Set(vergeben).count, vergeben.count, "Ein Cover haengt an zwei Spielen")
        XCTAssertEqual(Set(vergeben), Set(CoverArt.allCases), "Ein Cover haengt an keinem Spiel")
    }
}
