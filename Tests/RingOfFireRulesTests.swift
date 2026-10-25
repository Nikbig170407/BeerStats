//
//  RingOfFireRulesTests.swift
//  BeerStatsTests
//
//  Prueft die zwei Stellen in Ring of Fire, an denen die App eine Aussage
//  ueber MENSCHEN macht – und beide waeren lautlos falsch.
//
//  Erstens die Buchung in die Trinkbilanz. Nur die Drei und das Ass sagen
//  dem Zieher selbst eine Menge an; alles andere trifft andere, eine Gruppe
//  oder den Verlierer einer Runde, und wen, weiss nur der Tisch. Buchte die
//  App eine davon mit, stuende in der Bilanz eine Zahl, die niemand
//  getrunken hat – und sie sieht genauso aus wie eine richtige. Dazu muss
//  die gebuchte Menge dieselbe sein, die auf der Karte steht: Stuende dort
//  eine zweite Zahl, trinkt der Tisch etwas anderes als die Bilanz
//  mitschreibt.
//
//  Zweitens die Merkliste. "Daumenmeister · Lena" ist eine Auskunft,
//  "Daumenmeister · Spieler 2" ist keine – wer nicht weiss, wer die Zwei
//  ist, liest eine Nummer. Deshalb gibt es Namen nur, wenn ALLE Halter
//  einen haben.
//

import XCTest
@testable import BeerStats

final class RingOfFireRulesTests: XCTestCase {

    // MARK: - Was die App buchen darf

    /// Genau zwei Raenge kosten den Zieher selbst etwas. Diese Liste ist der
    /// Grund, warum die App ueberhaupt buchen darf – sie darf nicht wachsen,
    /// ohne dass jemand darueber nachgedacht hat.
    func testOnlyTheThreeAndTheAceChargeTheDrawer() {
        let buchbar = PlayingCard.ranks.filter {
            RingOfFireRules.rule(for: $0).drawerDrinks != nil
        }

        XCTAssertEqual(buchbar, [3, 14])
    }

    /// Die gebuchte Menge muss auf der Karte stehen. Sonst trinkt der Tisch
    /// das eine und die Bilanz zaehlt das andere.
    func testTheBookedAmountIsTheOneOnTheCard() {
        for rank in PlayingCard.ranks {
            let regel = RingOfFireRules.rule(for: rank)
            guard let menge = regel.drawerDrinks else { continue }

            XCTAssertTrue(
                regel.text.contains(menge.text),
                "Rang \(rank): \"\(regel.text)\" nennt nicht \"\(menge.text)\""
            )
        }
    }

    /// Eine Karte, die eine Menge ansagt, hat nichts zu verlieren – dieselbe
    /// Entscheidung wie bei den Extreme-Karten. Eine Strafe daneben waere
    /// eine zweite Menge, die niemand trinkt.
    func testACardThatChargesTheDrawerHasNoPenalty() {
        for rank in PlayingCard.ranks {
            let regel = RingOfFireRules.rule(for: rank)
            guard regel.drawerDrinks != nil else { continue }

            XCTAssertNil(regel.penalty, "Rang \(rank) hat Menge UND Strafe")
        }
    }

    /// Umgekehrt: Karten, die eine Runde laufen lassen, duerfen nicht
    /// gebucht werden. Der Verlierer steht erst am Tisch fest.
    func testCardsWithAPenaltyAreNeverBooked() {
        for rank in PlayingCard.ranks {
            let regel = RingOfFireRules.rule(for: rank)
            guard regel.penalty != nil else { continue }

            XCTAssertNil(regel.drawerDrinks, "Rang \(rank) wuerde geraten buchen")
        }
    }

    // MARK: - Die Merkliste

    func testOneHolderWithANameIsNamed() {
        XCTAssertEqual(
            RingOfFireRoleBoard.label(for: .thumbMaster, holders: ["Lena"]),
            "Daumenmeister · Lena"
        )
    }

    func testTwoHoldersAreBothNamed() {
        XCTAssertEqual(
            RingOfFireRoleBoard.label(for: .drinkingMate, holders: ["Lena", "Jan"]),
            "Trink-Duo · Lena, Jan"
        )
    }

    /// Kennt die App niemanden, bleibt es bei der Rolle – und bei der Zahl,
    /// die immerhin sagt, dass sie zweimal im Spiel ist.
    func testWithoutNamesOnlyTheCountIsShown() {
        XCTAssertEqual(
            RingOfFireRoleBoard.label(for: .questionQueen, holders: [nil]),
            "Question Queen"
        )
        XCTAssertEqual(
            RingOfFireRoleBoard.label(for: .questionQueen, holders: [nil, nil]),
            "Question Queen ×2"
        )
    }

    /// Der Fall, auf den es ankommt: Steht nur die Haelfte fest, gibt es
    /// KEINE halbe Zeile. "Lena und noch jemand" liest sich wie eine
    /// Auskunft und ist keine.
    func testAHalfKnownRoleFallsBackToTheCount() {
        XCTAssertEqual(
            RingOfFireRoleBoard.label(for: .thumbMaster, holders: ["Lena", nil]),
            "Daumenmeister ×2"
        )
    }

    func testAnEmptyRoleIsJustItsTitle() {
        XCTAssertEqual(
            RingOfFireRoleBoard.label(for: .houseRule, holders: []),
            "Regeln"
        )
    }
}
