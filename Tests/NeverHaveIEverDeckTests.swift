//
//  NeverHaveIEverDeckTests.swift
//  BeerStatsTests
//
//  Das Mischen von "Ich hab noch nie", seit die Einstellungen sich mitten
//  in der Runde aendern lassen (Zahnrad, 28. Oktober). Was dabei schiefgehen
//  kann, faellt am Tisch nicht als Fehler auf, sondern als "die hatten wir
//  doch schon" oder als zwei Strafen hintereinander.
//

import XCTest
@testable import BeerStats

final class NeverHaveIEverDeckTests: XCTestCase {

    private var gesichert: [String: [String]?] = [:]

    /// Eigene und ausgeblendete Karten veraendern den Stapel – hier sollen
    /// die rohen Listen gelten.
    override func setUp() {
        super.setUp()
        for key in [CustomCards.storageKey(for: .neverHaveIEver), HiddenCards.storageKey(for: .neverHaveIEver)] {
            gesichert[key] = UserDefaults.standard.stringArray(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for (key, wert) in gesichert {
            if let wert {
                UserDefaults.standard.set(wert, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        gesichert = [:]
        super.tearDown()
    }

    /// Wer mitten in der Runde umstellt, bekommt die Fragen, die schon dran
    /// waren, nicht noch einmal.
    func testPlayedQuestionsDontComeBack() {
        let alle = Set(NeverHaveIEverCategory.allCases)
        let gespielt = Set(NeverHaveIEverDeck.statements.prefix(60).map(\.text))

        let rest = NeverHaveIEverDeck.shuffled(categories: alle, includePenalties: true, excluding: gespielt)

        XCTAssertFalse(rest.contains { !$0.isPenalty && gespielt.contains($0.text) })
        XCTAssertEqual(
            rest.filter { !$0.isPenalty }.count,
            NeverHaveIEverDeck.statements.count - gespielt.count
        )
    }

    /// Auch nach dem Herausnehmen liegen nie zwei Strafen hintereinander,
    /// und der Stapel endet mit einer Frage.
    func testPenaltiesStillNeverFollowEachOther() {
        let auswahl: Set<NeverHaveIEverCategory> = [.kids, .party]
        let gespielt = Set(NeverHaveIEverDeck.statements.filter { $0.category == .kids }.prefix(30).map(\.text))

        for _ in 0..<25 {
            let stapel = NeverHaveIEverDeck.shuffled(categories: auswahl, includePenalties: true, excluding: gespielt)
            for (a, b) in zip(stapel, stapel.dropFirst()) {
                XCTAssertFalse(a.isPenalty && b.isPenalty, "Zwei Strafen hintereinander")
            }
            XCTAssertEqual(stapel.last?.isPenalty, false)
        }
    }

    /// Ist alles schon gespielt, bleibt nichts – und es kommt auch keine
    /// Strafe allein daher.
    func testNothingLeftMeansNoCards() {
        let gespielt = Set(NeverHaveIEverDeck.statements.filter { $0.category == .deep }.map(\.text))

        let rest = NeverHaveIEverDeck.shuffled(categories: [.deep], includePenalties: true, excluding: gespielt)

        XCTAssertTrue(rest.isEmpty)
    }
}
