//
//  ExtremeCardDealerTests.swift
//  BeerStatsTests
//
//  Prueft die eine scharfe Regel von Beerpong Extreme: Ein geladener
//  Becher loest GENAU EINMAL aus.
//
//  Die Regel stand im ViewModel und war damit nicht pruefbar. Sie ist aber
//  diejenige, deren Bruch am Tisch nach einem Fehler der App aussieht:
//  Nach einem Umstellen oder in der Redemption wandern Becher-Indizes
//  durcheinander, und eine Position, die ein zweites Mal feuert, waere
//  schlicht nicht zu erklaeren.
//

import XCTest
@testable import BeerStats

final class ExtremeCardDealerTests: XCTestCase {

    private let settings = ExtremeSettings(loadedCups: 2, mode: .normal)

    /// Team 1 wirft, getroffen wird das Rack von Team 2 – dort liegt der
    /// geladene Becher.
    private var treffer: GameEvent {
        .hit(thrower: PlayerRef(teamIndex: 0, slot: 0), bounce: false, trickshot: false, cupIndex: 4)
    }

    func testALoadedCupDrawsACard() {
        var dealer = ExtremeCardDealer(settings: settings, loadedCups: [[], [4]])
        XCTAssertNotNil(dealer.card(for: treffer))
    }

    func testTheSameCupNeverFiresTwice() {
        var dealer = ExtremeCardDealer(settings: settings, loadedCups: [[], [4]])
        XCTAssertNotNil(dealer.card(for: treffer))
        XCTAssertNil(dealer.card(for: treffer), "Derselbe Becher hat ein zweites Mal ausgelöst.")
    }

    func testAnEmptyCupDrawsNothing() {
        var dealer = ExtremeCardDealer(settings: settings, loadedCups: [[], [7]])
        XCTAssertNil(dealer.card(for: treffer))
    }

    /// Getroffen wird das Rack des GEGNERS. Stuende der geladene Becher im
    /// eigenen Rack, duerfte nichts passieren – sonst traefe die Karte das
    /// falsche Team.
    func testTheOpponentsRackCounts() {
        var dealer = ExtremeCardDealer(settings: settings, loadedCups: [[4], []])
        XCTAssertNil(dealer.card(for: treffer))
    }

    /// Bombe und Bounce: Die Zusatzbecher waehlt das betroffene Team selbst
    /// – hier ist der Waehlende also der Getroffene.
    func testAChosenCupBelongsToTheChoosingTeam() {
        var dealer = ExtremeCardDealer(settings: settings, loadedCups: [[], [2]])
        XCTAssertNotNil(dealer.card(for: .cupChosen(byTeamIndex: 1, cupIndex: 2)))
    }

    func testWithoutTheModeNothingIsLoaded() {
        var dealer = ExtremeCardDealer(settings: .off, loadedCups: [[], [4]])
        XCTAssertFalse(dealer.isEnabled)
        XCTAssertNil(dealer.card(for: treffer))
    }

    /// Ausgelost wird nur aus LEBENDEN Bechern: Beim fairen Anwurf fehlen
    /// einem Team schon zu Beginn welche, und eine geladene Position an
    /// einer leeren Stelle koennte nie ausloesen – das schwaechere Team
    /// haette ausgerechnet weniger Karten.
    func testOnlyAliveCupsAreLoaded() {
        let format = GameFormat(cupCount: 10)
        var state = GameEngine.makeInitialState(format: format, playersPerTeam: 1)
        state.racks[1].removeCup(at: 0)
        state.racks[1].removeCup(at: 1)

        var dealer = ExtremeCardDealer(settings: settings)
        dealer.reload(from: state, format: format)

        let lebende = Set(state.racks[1].aliveCupIndices)
        XCTAssertTrue(dealer.loadedCups[1].isSubset(of: lebende), "Geladen: \(dealer.loadedCups[1])")
        XCTAssertEqual(dealer.loadedCups[1].count, 2)
    }
}
