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

    /// Der Kranz am Ende der Runde ist eine eigene Szene und nicht die
    /// Bewegung eines Rangs mit anderem Anlass – fuer ihn gilt dieselbe
    /// Satz-Regel.
    func testFinaleHasItsOwnSentence() {
        XCTAssertFalse(RingScene.allCases.map(\.motion).contains(RingFinaleArt.motion))
        XCTAssertFalse(RingFinaleArt.motion.unicodeScalars.contains { $0.properties.isEmojiPresentation })
    }

    /// Die Szene waechst mit der Karte (3. November): Auf die Bezugsbreite
    /// abgestimmt, wird sie mit einer breiteren Karte im selben Verhaeltnis
    /// groesser – und mit einer schmaleren nie kleiner als abgestimmt.
    func testTheSceneGrowsWithTheCard() {
        let bezug = RingCardEntrance.referenceWidth

        XCTAssertEqual(RingScene.scale(forCardWidth: bezug), 1, accuracy: 0.0001)
        XCTAssertEqual(RingScene.scale(forCardWidth: bezug * 1.4), 1.4, accuracy: 0.0001)
        XCTAssertEqual(RingScene.scale(forCardWidth: bezug * 0.8), 1, accuracy: 0.0001)
    }

    /// Die Szene kennt die Lage von Karte und Text in IHREN Punkten: Der
    /// Kartenscreen misst in Punkten der Ansicht, die Szene zeichnet auf
    /// einer um `scale` kleineren Leinwand. Im Textband bleibt sie blass –
    /// mit weichen Kanten, darueber und darunter voll.
    func testTheStageKnowsWhereCardAndTextAre() {
        let gemessen = RingCardLayout(
            card: CGRect(x: 85, y: 40, width: 220, height: 319),
            text: CGRect(x: 30, y: 375, width: 330, height: 170)
        )
        let k = 220 / Double(RingCardEntrance.referenceWidth)
        let buehne = RingStage(size: CGSize(width: 390 / k, height: 671 / k), hit: 0.5, layout: gemessen, scale: k)

        XCTAssertEqual(Double(buehne.card.width), 150, accuracy: 0.01)
        XCTAssertEqual(buehne.cardMidY, (40 + 319 / 2) / k, accuracy: 0.01)
        let mitteText = (buehne.textTop + buehne.textBottom) / 2
        XCTAssertEqual(buehne.faint(mitteText, rest: 0.2), 0.2, accuracy: 0.0001)
        XCTAssertEqual(buehne.faint(buehne.textTop - 40), 1, accuracy: 0.0001)
        XCTAssertEqual(buehne.faint(buehne.textBottom + 40), 1, accuracy: 0.0001)

        // Noch nicht gemessen: Karte und Text liegen wie auf einem iPhone 13
        let geschaetzt = RingStage(size: CGSize(width: 266, height: 457), hit: 0.5, layout: RingCardLayout(), scale: 1)
        XCTAssertLessThan(Double(geschaetzt.card.maxY), geschaetzt.textTop)
        XCTAssertLessThan(geschaetzt.textBottom, 457)
    }

    /// Jede Szene hat ihren Schlag dort, wo ihre Karte landet – Szene und
    /// Auftritt gehoeren zum selben Rang.
    func testEverySceneHitsWhenItsCardLands() {
        for szene in RingScene.allCases {
            XCTAssertEqual(RingScene(rank: szene.rank), szene)
            XCTAssertEqual(szene.hitTime, RingCardEntrance(rank: szene.rank).hitTime, accuracy: 0.0001)
            XCTAssertLessThan(szene.hitTime, EffectCanvas(draw: { _, _, _ in }).stillAt, "\(szene): Das stille Bild laege vor dem Schlag")
        }
    }

    /// Gebebt wird nur, wo etwas einschlaegt – Blitz, Stempel, Shot. Ein
    /// Screen, der bei jeder Karte wackelt, wackelt bald fuer niemanden
    /// mehr. Und was bebt, rueckt auch heran: Ein Beben ohne Gewicht wirkt
    /// wie ein Fehler.
    func testOnlyTheBigHitsShakeTheScreen() {
        let beben = RingScene.allCases.filter { $0.quake > 0 }
        XCTAssertEqual(Set(beben), [.guys, .rule, .ace])
        for szene in beben {
            XCTAssertTrue(szene.zoomsOnHit, "\(szene)")
            XCTAssertLessThanOrEqual(szene.quake, 8, "\(szene) bebt so stark, dass der Text verschwimmt")
        }
    }

    /// Klang und Ruetteln gehoeren zum Schlag: Der Rangklang kommt genau
    /// einmal, nichts beginnt vor der Szene oder lange nach ihr, und der
    /// staerkste Stoss liegt auf der Landung.
    func testSoundAndTapsBelongToTheHit() {
        for szene in RingScene.allCases {
            let rang = GameSound.ringRank(szene.rank)
            XCTAssertEqual(szene.hitSounds.filter { $0.sound == rang }.count, 1, "\(szene)")
            for zeit in szene.hitSounds.map(\.at) + szene.hitTaps.map(\.time) {
                XCTAssertGreaterThanOrEqual(zeit, -szene.hitTime, "\(szene): beginnt vor der Szene")
                XCTAssertLessThanOrEqual(zeit, 1, "\(szene): kommt lange nach dem Schlag")
            }
            let staerkster = szene.hitTaps.max { $0.intensity < $1.intensity }
            XCTAssertEqual(staerkster?.time, 0, "\(szene): Der staerkste Stoss liegt nicht auf dem Schlag")
        }
    }
}
