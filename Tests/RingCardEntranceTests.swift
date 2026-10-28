//
//  RingCardEntranceTests.swift
//  BeerStatsTests
//
//  Ob ein Auftritt gut aussieht, kann kein Test sagen. Was er sagen kann:
//  dass jede Karte am Ende genau auf ihrem Platz steht, ohne dorthin zu
//  springen, dass keine zwei Raenge gleich auftreten – daran ist es bei den
//  Szenen zweimal gescheitert – und dass die Karte nach gut einer halben
//  Sekunde lesbar dasteht.
//

import XCTest
@testable import BeerStats

final class RingCardEntranceTests: XCTestCase {

    /// Dreizehn Raenge, dreizehn Auftritte – dieselbe Pruefung wie bei den
    /// Szenen.
    func testEveryRankHasItsOwnEntrance() {
        let auftritte = PlayingCardDeck.ranks.map { RingCardEntrance(rank: $0) }

        XCTAssertEqual(Set(auftritte).count, PlayingCardDeck.ranks.count)
        XCTAssertEqual(Set(auftritte), Set(RingCardEntrance.allCases), "Ein Auftritt haengt an keinem Rang")
    }

    /// Die Satz-Regel: Jeder Auftritt laesst sich in einem Satz sagen, und
    /// kein Satz kommt zweimal vor ...
    func testNoTwoEntrancesShareASentence() {
        let saetze = RingCardEntrance.allCases.map(\.motion)

        XCTAssertEqual(Set(saetze).count, saetze.count)
    }

    /// ... und zwar ohne Emoji.
    func testNoSentenceLeansOnAnEmoji() {
        for auftritt in RingCardEntrance.allCases {
            XCTAssertFalse(
                auftritt.motion.unicodeScalars.contains { $0.properties.isEmojiPresentation },
                "\(auftritt): \(auftritt.motion)"
            )
        }
    }

    /// Am Ende steht jede Karte genau auf ihrem Platz – und kurz davor ist
    /// sie schon fast dort. Sonst rueckte sie im letzten Bild sichtbar
    /// zurecht.
    func testEveryEntranceEndsAtRestWithoutAJump() {
        for auftritt in RingCardEntrance.allCases {
            XCTAssertEqual(auftritt.pose(at: 1), .rest, "\(auftritt)")
            XCTAssertLessThan(abstand(auftritt.pose(at: 0.995), .rest), 0.03, "\(auftritt) springt am Ende")
        }
    }

    /// Am Anfang ist die Karte noch nicht da: unsichtbar oder weit
    /// draussen. Waehrenddessen faehrt der Screen herein, und eine Karte,
    /// die schon steht, haette keinen Auftritt mehr.
    func testNoEntranceStartsWhereItEnds() {
        for auftritt in RingCardEntrance.allCases {
            let start = auftritt.pose(at: 0)
            let verborgen = start.opacity < 0.05 || start.reveal < 0.05
                || abs(start.x) >= 300 || abs(start.y) >= 300
            XCTAssertTrue(verborgen, "\(auftritt) steht schon da, bevor er beginnt")
        }
    }

    /// Kein Auftritt bewegt sich wie ein anderer. Verglichen wird ueber den
    /// ganzen Verlauf; irgendwo muessen zwei deutlich auseinanderliegen.
    func testNoTwoEntrancesMoveAlike() {
        let proben = (1...8).map { Double($0) / 10 }
        let alle = RingCardEntrance.allCases

        for (i, a) in alle.enumerated() {
            for b in alle[(i + 1)...] {
                let groesster = proben.map { abstand(a.pose(at: $0), b.pose(at: $0)) }.max() ?? 0
                XCTAssertGreaterThan(groesster, 0.3, "\(a) und \(b) bewegen sich zu aehnlich")
            }
        }
    }

    /// Nach 0,6 Sekunden steht die Karte so, dass man sie lesen kann:
    /// Vorderseite vorn, sichtbar, nah an ihrem Platz. Was danach kommt,
    /// ist Nachschwingen – niemand wartet aufs Lesen.
    func testTheCardIsReadableAfterSixTenthsOfASecond() {
        for auftritt in RingCardEntrance.allCases {
            let pose = auftritt.pose(at: min(1, 0.6 / auftritt.duration))

            XCTAssertFalse(pose.showsBack, "\(auftritt) zeigt noch den Ruecken")
            XCTAssertGreaterThan(pose.opacity, 0.9, "\(auftritt)")
            XCTAssertGreaterThan(pose.reveal, 0.95, "\(auftritt)")
            XCTAssertLessThan(abs(pose.x), 60, "\(auftritt)")
            XCTAssertLessThan(abs(pose.y), 60, "\(auftritt)")
            XCTAssertLessThan(abs(pose.rotation), 15, "\(auftritt)")
            XCTAssertLessThan(abs(pose.flipX), 20, "\(auftritt)")
            XCTAssertLessThan(abs(pose.flipY), 20, "\(auftritt)")
            XCTAssertEqual(pose.scaleX, 1, accuracy: 0.25, "\(auftritt)")
            XCTAssertEqual(pose.scaleY, 1, accuracy: 0.25, "\(auftritt)")
        }
    }

    /// Kurz genug, dass niemand wartet; lang genug, dass man es sieht.
    func testEveryEntranceTakesBetweenHalfASecondAndOne() {
        for auftritt in RingCardEntrance.allCases {
            XCTAssertTrue((0.5...0.95).contains(auftritt.duration), "\(auftritt): \(auftritt.duration) s")
        }
    }

    /// Nur das Trink-Duo kommt zu zweit. Die beiden kommen von
    /// verschiedenen Seiten, und am Ende ist die zweite in der ersten
    /// aufgegangen.
    func testOnlyThePairBringsASecondCard() {
        for auftritt in RingCardEntrance.allCases where auftritt != .pair {
            XCTAssertNil(auftritt.ghostPose(at: 0.3), "\(auftritt)")
        }

        let frueh = RingCardEntrance.pair.ghostPose(at: 0.2)
        let karte = RingCardEntrance.pair.pose(at: 0.2)
        XCTAssertLessThan((frueh?.x ?? 0) * karte.x, 0, "Die beiden kommen von derselben Seite")
        XCTAssertEqual(RingCardEntrance.pair.ghostPose(at: 0.9)?.opacity, 0)
        XCTAssertEqual(RingCardEntrance.pair.ghostPose(at: 1)?.opacity, 0)
    }

    /// Wer sich ueberschlaegt, zeigt zwischendurch den Ruecken – sonst
    /// stuende die Karte zur Haelfte spiegelverkehrt da.
    func testAFlippedCardShowsItsBack() {
        var pose = CardPose()
        pose.flipX = 180
        XCTAssertTrue(pose.showsBack)
        pose.flipX = 360
        XCTAssertFalse(pose.showsBack)
        pose.flipX = 0
        pose.flipY = 900
        XCTAssertTrue(pose.showsBack)

        for auftritt in [RingCardEntrance.flick, .coin] {
            let zeigtRuecken = (0..<100).contains { auftritt.pose(at: Double($0) / 100).showsBack }
            XCTAssertTrue(zeigtRuecken, "\(auftritt) dreht sich, ohne den Ruecken zu zeigen")
        }
    }

    /// Beim Wasserfall laeuft die Karte hinter einer Welle ins Bild. Am
    /// Anfang verdeckt die Welle alles, am Ende gibt sie die Karte frei –
    /// samt Schatten darunter, sonst fehlte er nur bei diesem Rang.
    func testTheWaterfallCurtainHidesAllFirstAndFreesTheShadowLast() {
        let hoehe = 217.5
        let schatten = 24.0
        let welle = RingCardCurtain.wave

        XCTAssertLessThan(RingCardCurtain.level(reveal: 0, height: hoehe) + welle, 0)
        XCTAssertGreaterThan(RingCardCurtain.level(reveal: 1, height: hoehe) - welle, hoehe + schatten)
        XCTAssertEqual(RingCardCurtain.foamOpacity(reveal: 0), 0)
        XCTAssertEqual(RingCardCurtain.foamOpacity(reveal: 1), 0)
        XCTAssertGreaterThan(RingCardCurtain.foamOpacity(reveal: 0.5), 0.5)
    }

    // MARK: - Hilfe

    /// Wie weit zwei Posen auseinanderliegen: der groesste Unterschied,
    /// jeweils auf eine Groesse gebracht, bei der 1 deutlich sichtbar ist –
    /// 100 Punkte, 45 Grad, die ganze Deckkraft.
    private func abstand(_ a: CardPose, _ b: CardPose) -> Double {
        let teile: [Double] = [
            abs(a.x - b.x) / 100,
            abs(a.y - b.y) / 100,
            abs(a.scaleX - b.scaleX),
            abs(a.scaleY - b.scaleY),
            abs(a.rotation - b.rotation) / 45,
            abs(a.flipX - b.flipX) / 45,
            abs(a.flipY - b.flipY) / 45,
            abs(a.opacity - b.opacity),
            abs(a.reveal - b.reveal)
        ]
        return teile.max() ?? 0
    }
}
