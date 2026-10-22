//
//  HerdDeckTests.swift
//  BeerStatsTests
//
//  Prueft die Fragen der Herde auf das, was sie spielbar macht.
//
//  Das Ziel ist das Gegenteil von Quizfragen: Es gibt keine richtige
//  Antwort, nur eine haeufige. Eine Frage, die man mit Wissen beantwortet
//  ("Wie heisst die Hauptstadt von Frankreich?"), zerstoert das Spiel
//  lautlos – alle sagen dasselbe, niemand trinkt, und nach fuenf Runden
//  legt die Runde das Handy weg, ohne zu wissen, warum es langweilig war.
//

import XCTest
@testable import BeerStats

final class HerdDeckTests: XCTestCase {

    func testEveryQuestionIsThereOnlyOnce() {
        let doppelt = Set(HerdDeck.all.filter { frage in
            HerdDeck.all.filter { $0 == frage }.count > 1
        })
        XCTAssertTrue(doppelt.isEmpty, "Doppelte Fragen: \(doppelt.sorted())")
    }

    /// Jede Frage ist eine Aufforderung, keine Wissensfrage. Die Form
    /// haelt das fest: „Nenne …" laesst sich nicht falsch beantworten.
    func testEveryQuestionAsksForSomethingToName() {
        for frage in HerdDeck.all {
            XCTAssertTrue(frage.hasPrefix("Nenne "), "Keine Nenn-Aufgabe: \(frage)")
            XCTAssertFalse(frage.hasSuffix("?"), "Klingt nach Quizfrage: \(frage)")
            XCTAssertEqual(frage, frage.trimmingCharacters(in: .whitespacesAndNewlines), frage)
        }
    }

    func testTheDeckIsBigEnoughForAnEvening() {
        XCTAssertGreaterThanOrEqual(HerdDeck.count, 110)
    }

    func testTheSubtitleNamesTheRealDeckSize() {
        XCTAssertTrue(
            PartyGame.herd.subtitle.contains("\(HerdDeck.count) Fragen"),
            PartyGame.herd.subtitle
        )
    }

    /// Die Herde ist ein Spiel fuer eine Gruppe: Zu zweit ist immer jeder
    /// entweder in der Mehrheit oder allein, und beides gleichzeitig.
    func testTheHerdNeedsAGroup() {
        XCTAssertEqual(PartyGame.herd.players.lowerBound, 3)
        XCTAssertFalse(PartyGame.fitting(players: 2).contains(.herd))
    }
}
