//
//  HorseRaceTrackTests.swift
//  BeerStatsTests
//
//  Die Bahn des Pferderennens und ihr Raster.
//

import XCTest
@testable import BeerStats

final class HorseRaceTrackTests: XCTestCase {

    /// Jede Seitenkarte steht ueber einer Spalte, und jede Spalte zwischen
    /// Start und Ziel hat eine Karte – sonst haengt im Raster eine Karte in
    /// der Luft oder ein Feld bleibt leer.
    func testEveryColumnBetweenStartAndFinishHasASideCard() {
        let spalten = Array(1..<HorseRaceTrack.finishLine)
        XCTAssertEqual(spalten.count, HorseRaceTrack.sideCount)
        XCTAssertGreaterThan(HorseRaceTrack.sideCount, 0)
    }

    /// Nach den Seitenkarten bleibt genug im Stapel, dass ein Rennen ohne den
    /// Notfall-Neustapel auskommt: Alle vier Pferde muessten sonst im Schnitt
    /// weiter laufen, als die Karten reichen.
    func testTheDeckLastsForARace() {
        let ohneAsse = PlayingCardDeck.shuffled().filter { $0.rank != 14 }
        let uebrig = ohneAsse.count - HorseRaceTrack.sideCount
        XCTAssertGreaterThan(uebrig, 4 * HorseRaceTrack.finishLine)
    }

    /// Der Untertitel nennt die wirkliche Zahl und nicht eine getippte.
    func testTheSubtitleNamesTheRealNumber() {
        XCTAssertTrue(PartyGame.horseRace.subtitle.contains("\(HorseRaceTrack.sideCount) Seitenkarten"))
    }
}
