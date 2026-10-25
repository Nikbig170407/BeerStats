//
//  RouletteWheelTests.swift
//  BeerStatsTests
//
//  Prueft die Raeder des Trink-Roulettes – Inhalt und die eine Rechnung,
//  die es gibt.
//
//  Der Inhalt braucht einen Test aus demselben Grund wie die Kartenstapel
//  (`DeckContentTests`): Er waechst und wird selten geprueft, und die Fehler
//  fallen beim Spielen NICHT auf. Zwei Felder mit derselben Kurzform sehen
//  auf dem Rad wie ein grosses Stueck aus, und ein zu langes Wort wird im
//  Tortenstueck abgeschnitten – beides sieht man nicht als Fehler, sondern
//  als schlechtes Rad.
//
//  Die Rechnung ist `resolved`: Wo die Menge im Satz landet. Sie darf nicht
//  verloren gehen, denn dann saehe das Feld aus wie "niemand trinkt".
//
//  Das eigene Rad kommt hier nicht vor: Es liegt in UserDefaults und ist im
//  Test leer. Geprueft wird, was ausgeliefert wird.
//

import XCTest
@testable import BeerStats

final class RouletteWheelTests: XCTestCase {

    /// Die fertigen Raeder. Das eigene haengt an UserDefaults.
    private let fertig: [RouletteWheel] = [.classic, .soft, .hard]

    // MARK: - Inhalt

    /// Ein Rad braucht genug Felder, um eines zu sein – und nicht mehr, als
    /// sich lesen laesst.
    func testEveryWheelHasAPlayableNumberOfFields() {
        for rad in fertig {
            XCTAssertGreaterThanOrEqual(rad.wedges.count, RouletteWedges.minimum, rad.title)
            XCTAssertLessThanOrEqual(rad.wedges.count, RouletteWedges.maximum, rad.title)
            XCTAssertTrue(rad.isPlayable, rad.title)
        }
    }

    /// Zwei Felder mit derselben Kurzform sehen auf dem Rad wie EIN Stueck
    /// aus. Am Tisch wundert sich dann niemand – man denkt, das Rad sei so.
    func testNoWheelRepeatsALabel() {
        for rad in fertig {
            let kurzformen = rad.wedges.map(\.label)
            XCTAssertEqual(
                Set(kurzformen).count, kurzformen.count,
                "\(rad.title) hat eine Kurzform doppelt"
            )
        }
    }

    /// Die Kurzform steht IM Tortenstueck. Lange Woerter werden dort
    /// abgeschnitten, und die Grenze faellt beim Schreiben neuer Felder
    /// sonst niemandem auf.
    func testLabelsAreShortEnoughForTheWheel() {
        for rad in fertig {
            for feld in rad.wedges {
                XCTAssertFalse(feld.label.isEmpty, "\(rad.title): Feld ohne Kurzform")
                XCTAssertLessThanOrEqual(
                    feld.label.count, 10,
                    "\(rad.title): „\(feld.label)“ ist zu lang fuers Rad"
                )
            }
        }
    }

    /// Kein Feld ohne Satz: Nach der Drehung steht genau dieser da.
    func testEveryFieldHasASentence() {
        for rad in fertig {
            for feld in rad.wedges {
                XCTAssertFalse(feld.text.isEmpty, "\(rad.title): \(feld.label) ohne Satz")
                XCTAssertFalse(feld.resolved.isEmpty, "\(rad.title): \(feld.label) ohne Anzeige")
            }
        }
    }

    /// Ausgeliefertes Feld mit Menge: Die Menge gehoert IN den Satz.
    ///
    /// Der Anhang ("Dein Nachbar trinkt – 3 Schluecke") ist fuer die eigenen
    /// Felder gedacht, damit niemand eine Schreibweise lernen muss. In den
    /// fertigen Raedern ist er Schlamperei.
    func testShippedFieldsNameTheAmountInTheSentence() {
        for rad in fertig {
            for feld in rad.wedges where feld.cost != .nothing {
                XCTAssertTrue(
                    feld.text.contains("{}"),
                    "\(rad.title): „\(feld.text)“ sagt die Menge nicht im Satz"
                )
            }
        }
    }

    /// Das zahme Rad darf keinen Shot enthalten – sonst ist es nicht zahm,
    /// und die Wahl im Vorspann waere eine Behauptung.
    func testTheSoftWheelHasNoShot() {
        XCTAssertFalse(RouletteWheel.soft.wedges.contains { $0.cost == .shot })
        XCTAssertTrue(RouletteWheel.hard.wedges.contains { $0.cost == .shot })
    }

    // MARK: - Die Menge im Satz

    func testThePlaceholderIsReplaced() {
        let feld = RouletteWedge(label: "Du", text: "Du trinkst {}", cost: .threeSips)
        XCTAssertEqual(feld.resolved, "Du trinkst \(DrinkAmount.sips(3).text)")
        XCTAssertFalse(feld.resolved.contains("{}"))
    }

    /// Ohne Platzhalter geht die Menge nicht verloren, sondern kommt hinten
    /// dran. Genau das erlaubt es, eigene Felder ohne Schreibweise anzulegen.
    func testWithoutAPlaceholderTheAmountIsAppended() {
        let feld = RouletteWedge(label: "Chef", text: "Der Gastgeber trinkt", cost: .shot)
        XCTAssertTrue(feld.resolved.hasPrefix("Der Gastgeber trinkt"))
        XCTAssertTrue(feld.resolved.contains(DrinkAmount.shot.text))
    }

    /// Kostet ein Feld nichts, steht auch nichts dran – kein "0 Schluecke"
    /// und kein leerer Gedankenstrich.
    func testAFreeFieldSaysNothingAboutAmounts() {
        let feld = RouletteWedge(label: "Glück", text: "Glück gehabt – niemand trinkt", cost: .nothing)
        XCTAssertEqual(feld.resolved, "Glück gehabt – niemand trinkt")
        XCTAssertNil(RouletteCost.nothing.amount)
    }

    func testEveryCostMapsToAnAmountExceptNothing() {
        for kosten in RouletteCost.allCases {
            if kosten == .nothing {
                XCTAssertNil(kosten.amount)
            } else {
                XCTAssertNotNil(kosten.amount, kosten.rawValue)
            }
            XCTAssertFalse(kosten.title.isEmpty, kosten.rawValue)
        }
    }

    // MARK: - Speichern

    /// Ein Feld muss beides haben. Ohne Kurzform stuende das Tortenstueck
    /// leer da, ohne Satz zeigte die Drehung nichts an.
    func testAFieldWithoutLabelOrSentenceIsRefused() {
        XCTAssertFalse(RouletteWedges.add(label: "   ", text: "Jemand trinkt", cost: .oneSip))
        XCTAssertFalse(RouletteWedges.add(label: "Chef", text: "  ", cost: .oneSip))
    }
}
