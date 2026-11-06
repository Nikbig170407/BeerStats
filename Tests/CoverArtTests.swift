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

    /// Das Beerpong-Plakat folgt derselben Satz-Regel – und darf keinem
    /// Cover gleichen.
    func testTheBeerpongPosterHasItsOwnSentence() {
        let satz = BeerpongPoster.sentence
        XCTAssertFalse(satz.unicodeScalars.contains { $0.properties.isEmojiPresentation })
        XCTAssertFalse(CoverArt.allCases.map(\.sentence).contains(satz))
    }

    /// Die Pfade kommen woertlich aus der Vorschau. Liest der Parser sie
    /// falsch, sieht das Plakat anders aus als das abgenommene – ohne
    /// dass ein Compiler etwas merkt.
    func testPosterPathsReadLikeTheirPreview() {
        let dreieck = PosterInk.path("M0 0 L10 0 L10 20 Z").boundingRect
        XCTAssertEqual(dreieck, CGRect(x: 0, y: 0, width: 10, height: 20))

        // Negative Zahlen ohne Leerzeichen davor, Komma als Trenner
        let quer = PosterInk.path("M-5-5 L5,5").boundingRect
        XCTAssertEqual(quer, CGRect(x: -5, y: -5, width: 10, height: 10))

        // Kurven: Der Rahmen umschliesst Anfang und Ende
        let bogen = PosterInk.path("M0 0 Q10 10 20 0 C25 0 30 5 30 10").boundingRect
        XCTAssertEqual(bogen.minX, 0, accuracy: 0.001)
        XCTAssertEqual(bogen.maxX, 30, accuracy: 0.001)
        XCTAssertEqual(bogen.maxY, 10, accuracy: 0.001)
    }
}
