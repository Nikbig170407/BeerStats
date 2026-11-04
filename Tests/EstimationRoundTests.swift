//
//  EstimationRoundTests.swift
//  BeerStatsTests
//
//  Schaetzmeister mit Aufschreiben: Wer trinkt, entscheidet hier die App
//  und nicht mehr die Runde. Eine falsche Auswertung faellt am Tisch nicht
//  auf – sie sieht aus wie eine bestaetigte, und genau deshalb steht sie
//  unter Test.
//

import XCTest
@testable import BeerStats

final class EstimationRoundTests: XCTestCase {

    // MARK: - Auswertung

    func testFarthestDrinksAndNearestDistributes() {
        let urteil = EstimationVerdict(answer: 206, guesses: [
            EstimationGuess(player: 0, tenths: 1500),
            EstimationGuess(player: 1, tenths: 3000),
            EstimationGuess(player: 2, tenths: 2100)
        ])

        XCTAssertEqual(urteil.farthest, [1])
        XCTAssertEqual(urteil.nearest, [2])
        // Aufgedeckt wird von ganz daneben bis am naechsten dran
        XCTAssertEqual(urteil.rows.map(\.player), [1, 0, 2])
        XCTAssertEqual(urteil.rows.map(\.distance), [940, 560, 40])
    }

    /// Gleich weit daneben heisst gleich weit daneben: beide trinken. Und
    /// das in Zehnteln – in Double laege 7,4 um einen Rundungsfehler weiter
    /// weg als 7,2.
    func testTiesShareThePlaceEvenAroundADecimalAnswer() {
        let urteil = EstimationVerdict(answer: 7.3, guesses: [
            EstimationGuess(player: 0, tenths: 72),
            EstimationGuess(player: 1, tenths: 74),
            EstimationGuess(player: 2, tenths: 90),
            EstimationGuess(player: 3, tenths: 56)
        ])

        XCTAssertEqual(urteil.nearest, [0, 1])
        XCTAssertEqual(urteil.farthest, [2, 3])
    }

    func testEveryoneEquallyFarIsADrawWithoutPenalty() {
        let urteil = EstimationVerdict(answer: 10, guesses: [
            EstimationGuess(player: 0, tenths: 80),
            EstimationGuess(player: 1, tenths: 120)
        ])

        XCTAssertTrue(urteil.isDraw)
        XCTAssertTrue(urteil.farthest.isEmpty)
        XCTAssertTrue(urteil.nearest.isEmpty)
    }

    // MARK: - Reihenfolge

    /// Jeder kommt genau einmal dran, und der Anfang wandert mit der Frage.
    func testTheOrderRotatesAndCoversEveryone() {
        XCTAssertEqual(EstimationRound.order(playerCount: 4, question: 0), [0, 1, 2, 3])
        XCTAssertEqual(EstimationRound.order(playerCount: 4, question: 1), [1, 2, 3, 0])
        XCTAssertEqual(EstimationRound.order(playerCount: 4, question: 5), [1, 2, 3, 0])
        for frage in 0..<10 {
            XCTAssertEqual(Set(EstimationRound.order(playerCount: 5, question: frage)), Set(0..<5))
        }
    }

    // MARK: - Eingabe

    func testTypingBuildsTheNumber() {
        var eingabe = EstimationEntry(allowsDecimals: false)
        XCTAssertNil(eingabe.tenths)
        for ziffer in [0, 8, 6, 4, 0, 0] { eingabe.type(ziffer) }

        XCTAssertEqual(eingabe.tenths, 864_000)
        XCTAssertEqual(eingabe.display, "86.400")
    }

    /// Bei "Wie viele Sitze hat der Bundestag?" gibt es kein Komma.
    func testNoCommaWhereItWouldBeAnUnfairEdge() {
        var eingabe = EstimationEntry(allowsDecimals: false)
        eingabe.type(6)
        eingabe.typeComma()
        eingabe.type(5)

        XCTAssertEqual(eingabe.tenths, 650)
        XCTAssertEqual(eingabe.display, "65")
    }

    func testOneDecimalPlaceAndDeleting() {
        var eingabe = EstimationEntry(allowsDecimals: true)
        eingabe.typeComma()
        eingabe.type(5)
        eingabe.type(9)
        XCTAssertEqual(eingabe.display, "0,5")
        XCTAssertEqual(eingabe.tenths, 5)

        eingabe.delete()
        XCTAssertEqual(eingabe.display, "0,")
        eingabe.delete()
        eingabe.delete()
        XCTAssertTrue(eingabe.isEmpty)
        XCTAssertNil(eingabe.tenths)
    }

    func testFormattingDropsAnEmptyDecimal() {
        XCTAssertEqual(EstimationEntry.format(tenths: 2060), "206")
        XCTAssertEqual(EstimationEntry.format(tenths: 73), "7,3")
        XCTAssertEqual(EstimationEntry.format(tenths: 88_490), "8.849")
    }

    // MARK: - Komma je Frage

    /// Eine Antwort mit Nachkommastelle muss ein Komma bekommen, sonst
    /// laesst sie sich nicht treffen. Und was man zaehlt – alles ohne
    /// Einheit –, bekommt nie eins.
    func testTheCommaFollowsTheUnit() {
        for frage in EstimationDeck.all {
            if EstimationEntry.tenths(of: frage.answer) % 10 != 0 {
                XCTAssertTrue(frage.allowsDecimals, frage.text)
            }
            if frage.unit.isEmpty {
                XCTAssertFalse(frage.allowsDecimals, frage.text)
            }
        }
    }
}
