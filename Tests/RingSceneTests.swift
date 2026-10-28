//
//  RingSceneTests.swift
//  BeerStatsTests
//
//  Haelt fest, was der Nutzer zweimal am Tisch gesehen hat: Die Szenen
//  hinter den Ring-of-Fire-Karten sahen alle gleich aus, nur mit anderem
//  Emoji. Ob eine Bewegung gut aussieht, kann kein Test sagen – aber dass
//  kein Rang seine Bewegung mit einem anderen teilt, schon. Und genau das
//  war der Fehler.
//

import XCTest
@testable import BeerStats

final class RingSceneTests: XCTestCase {

    /// Dreizehn Raenge, dreizehn Szenen. Zeigen zwei Raenge auf dieselbe,
    /// bewegen sich am Tisch zwei Karten gleich – und daran ist es
    /// zweimal gescheitert.
    func testEveryRankHasItsOwnScene() {
        let szenen = PlayingCardDeck.ranks.map { RingScene(rank: $0) }

        XCTAssertEqual(Set(szenen).count, PlayingCardDeck.ranks.count)
        XCTAssertEqual(Set(szenen), Set(RingScene.allCases), "Eine Szene haengt an keinem Rang")
    }

    /// Die Pruefung aus der Entscheidung vom 27. Oktober: Jede Bewegung
    /// laesst sich in einem Satz sagen, und kein Satz kommt zweimal vor.
    func testNoTwoScenesShareASentence() {
        let saetze = RingScene.allCases.map(\.motion)

        XCTAssertEqual(Set(saetze).count, saetze.count)
    }

    /// ... und zwar ohne ein Emoji. Eine Szene, die sich nur ueber ihr
    /// Zeichen beschreiben laesst, unterscheidet sich auch nur durch ihr
    /// Zeichen.
    func testNoSentenceLeansOnAnEmoji() {
        for szene in RingScene.allCases {
            XCTAssertFalse(
                szene.motion.unicodeScalars.contains { $0.properties.isEmojiPresentation },
                "\(szene): \(szene.motion)"
            )
        }
    }
}
