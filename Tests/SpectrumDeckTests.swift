//
//  SpectrumDeckTests.swift
//  BeerStatsTests
//
//  Prueft die Gegensatzpaare – und die eine Zahl, an der das Spiel haengt.
//
//  Die Trefferzone ist der Unterschied zwischen einem Spiel und einer
//  Lotterie. Ist sie zu schmal, trifft auch ein guter Hinweis nicht; ist
//  sie zu breit, gewinnt jeder Hinweis. Beides faellt am Tisch nicht als
//  Fehler auf, sondern nur als "das Spiel ist langweilig" – deshalb steht
//  die Rechnung hier.
//

import XCTest
@testable import BeerStats

final class SpectrumDeckTests: XCTestCase {

    func testEveryPairIsThereOnlyOnce() {
        let kennungen = SpectrumDeck.all.map(\.id)
        let doppelt = Set(kennungen.filter { id in kennungen.filter { $0 == id }.count > 1 })
        XCTAssertTrue(doppelt.isEmpty, "Doppelte Skalen: \(doppelt.sorted())")
    }

    /// Beide Pole muessen dastehen und verschieden sein. Eine Skala mit
    /// zwei gleichen Enden hat keine Richtung.
    func testEveryPairHasTwoDifferentPoles() {
        for karte in SpectrumDeck.all {
            XCTAssertFalse(karte.left.isEmpty, karte.id)
            XCTAssertFalse(karte.right.isEmpty, karte.id)
            XCTAssertNotEqual(karte.left, karte.right, karte.id)
        }
    }

    /// Die Pole sind kurz genug, um nebeneinander in eine Zeile zu passen.
    /// Ein ganzer Satz am Rand der Skala waere nicht mehr zu lesen,
    /// waehrend man gleichzeitig den Regler schiebt.
    func testThePolesAreShortEnoughToReadAtAGlance() {
        for karte in SpectrumDeck.all {
            XCTAssertLessThanOrEqual(karte.left.count, 24, karte.id)
            XCTAssertLessThanOrEqual(karte.right.count, 24, karte.id)
        }
    }

    func testTheDeckIsBigEnoughForAnEvening() {
        XCTAssertGreaterThanOrEqual(SpectrumDeck.count, 100)
    }

    func testTheSubtitleNamesTheRealDeckSize() {
        XCTAssertTrue(
            PartyGame.spectrum.subtitle.contains("\(SpectrumDeck.count) Gegensätze"),
            PartyGame.spectrum.subtitle
        )
    }
}
