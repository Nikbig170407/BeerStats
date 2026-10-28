//
//  HiddenCardsTests.swift
//  BeerStatsTests
//
//  Prueft, dass eine weggedaumte Karte wirklich wegbleibt.
//
//  Der Daumen nach unten ist die einzige Stelle, an der die App etwas
//  dauerhaft wegnimmt – und die einzige, deren Wirkung man erst eine Runde
//  spaeter sieht. Bleibt sie aus, merkt es niemand sofort: Die Karte kommt
//  einfach irgendwann wieder, und am Tisch heisst das "der Knopf tut
//  nichts".
//
//  Der wichtigste Fall steht unten als eigener Test: Bei "Wahrheit oder
//  Pflicht" traegt die Karte eine Trinkmenge, die erst beim Anzeigen
//  ausformuliert wird. Ausgeblendet wird deshalb der ROHE Text. Wuerde nach
//  dem angezeigten Text ausgeblendet, kaeme die Karte zurueck, sobald
//  jemand die Haerte umstellt - mit einer Erklaerung, die niemand findet.
//

import XCTest
@testable import BeerStats

final class HiddenCardsTests: XCTestCase {

    /// Die Tests schreiben in dieselben UserDefaults wie die App. Was sie
    /// hinterlassen, faende der naechste Lauf vor – deshalb sichern und
    /// zuruecklegen (dieselbe Vorsichtsmassnahme wie in `PlayerNamesTests`).
    private var gesichert: [String: [String]?] = [:]

    private var betroffen: [String] {
        CustomCardDeck.allCases.flatMap {
            [HiddenCards.storageKey(for: $0), CustomCards.storageKey(for: $0)]
        }
    }

    override func setUp() {
        super.setUp()
        for key in betroffen {
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

    // MARK: - Wer würde eher?

    func testAHiddenMostLikelyCardStaysAway() {
        let weg = MostLikelyDeck.all[0].text
        HiddenCards.hide(weg, in: .mostLikely)

        let stapel = MostLikelyDeck.shuffled()
        XCTAssertFalse(stapel.contains { $0.text == weg })
        XCTAssertEqual(stapel.count, MostLikelyDeck.all.count - 1)
    }

    func testOwnMostLikelyCardsJoinTheDeck() {
        CustomCards.add("Wer von uns würde am ehesten im Keller übernachten?", to: .mostLikely)

        let stapel = MostLikelyDeck.shuffled()
        XCTAssertEqual(stapel.count, MostLikelyDeck.all.count + 1)
        // Eigene Karten tragen keinen Daumen nach unten – sie werden unter
        // "Eigene Karten" geloescht. Die Ansicht entscheidet das an diesem
        // Merkmal, also muss es stehen.
        XCTAssertEqual(stapel.filter(\.isCustom).count, 1)
    }

    /// Der Weg zurueck. Ohne ihn waere der Daumen endgueltig, und eine
    /// unumkehrbare Entscheidung tippt man am Tisch nicht gern.
    func testShowAllBringsEverythingBack() {
        for card in MostLikelyDeck.all.prefix(3) {
            HiddenCards.hide(card.text, in: .mostLikely)
        }
        XCTAssertEqual(HiddenCards.count(for: .mostLikely), 3)

        HiddenCards.showAll(in: .mostLikely)

        XCTAssertEqual(HiddenCards.count(for: .mostLikely), 0)
        XCTAssertEqual(MostLikelyDeck.shuffled().count, MostLikelyDeck.all.count)
    }

    // MARK: - Ich hab noch nie

    func testAHiddenStatementStaysAway() {
        let alleKategorien = Set(NeverHaveIEverCategory.allCases)
        let weg = NeverHaveIEverDeck.statements[0].text
        HiddenCards.hide(weg, in: .neverHaveIEver)

        let stapel = NeverHaveIEverDeck.shuffled(categories: alleKategorien, includePenalties: false)
        XCTAssertFalse(stapel.contains { $0.text == weg })
        XCTAssertFalse(stapel.isEmpty)
    }

    // MARK: - Wahrheit oder Pflicht

    /// Die Kennung ist der Text VOR dem Einsetzen der Menge. Dieser Test
    /// haelt genau das fest: Dieselbe Karte bleibt in jeder Haerte
    /// ausgeblendet, obwohl ihr angezeigter Text sich aendert.
    func testAHiddenTruthStaysAwayInEveryIntensity() {
        let vorher = DrinkIntensity.current
        defer { DrinkIntensity.current = vorher }

        DrinkIntensity.current = .normal
        // Eine Karte MIT Platzhalter, denn nur bei der aendert sich der
        // angezeigte Text mit der Haerte - und nur dort kann der Fehler
        // ueberhaupt auftreten.
        guard let karte = TruthOrDareDeck.shuffled(.dare).first(where: { $0.key.contains("{") }) else {
            return XCTFail("Keine Pflicht-Karte mit Trinkmenge im Stapel.")
        }
        XCTAssertNotEqual(karte.text, karte.key, "Die Menge wurde nicht eingesetzt.")
        HiddenCards.hide(karte.key, in: .truthOrDare)

        for haerte in DrinkIntensity.allCases {
            DrinkIntensity.current = haerte
            let stapel = TruthOrDareDeck.shuffled(.dare)
            XCTAssertFalse(
                stapel.contains { $0.key == karte.key },
                "In der Härte \(haerte.rawValue) ist die Karte zurück."
            )
        }
    }

    /// Ausgeblendet wird pro Stapel, nicht fuer die ganze App. Ein Text, der
    /// in zwei Spielen vorkommt, soll nicht in beiden verschwinden.
    func testHidingIsPerDeck() {
        let weg = MostLikelyDeck.all[0].text
        HiddenCards.hide(weg, in: .mostLikely)

        XCTAssertTrue(HiddenCards.isHidden(weg, in: .mostLikely))
        XCTAssertFalse(HiddenCards.isHidden(weg, in: .neverHaveIEver))
        XCTAssertEqual(HiddenCards.count(for: .neverHaveIEver), 0)
    }
}
