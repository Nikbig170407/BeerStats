//
//  RingLayoutTests.swift
//  BeerStatsTests
//
//  Prueft die Regel, die Ring of Fire seinen Namen gibt: Wer den Ring
//  reisst, trinkt.
//
//  Die Rechnung ist kurz und hat drei Stellen, an denen sie lautlos falsch
//  waere – und lautlos heisst hier: Jemand trinkt einen Shot, den er nicht
//  schuldet, und niemand kann nachsehen.
//
//  Erstens die Naht. Die Abstaende werden zufaellig gestreut und danach auf
//  360 Grad normiert. Fehlt das Normieren, klafft zwischen der letzten und
//  der ersten Karte eine Luecke, die nie jemand gezogen hat.
//
//  Zweitens der Rundlauf. Die Nachbarin von Karte 0 ist die letzte Karte.
//  Wer modulo vergisst, prueft an dieser einen Stelle gegen einen negativen
//  Bogen.
//
//  Drittens die schon offene Stelle. Zieht man neben einer Luecke, wird sie
//  nur groesser – gerissen hat sie jemand anderes.
//

import XCTest
@testable import BeerStats

final class RingLayoutTests: XCTestCase {

    /// Gleichmaessiger Ring mit bekanntem Abstand – damit die Erwartung
    /// nicht vom Zufall abhaengt.
    private func gleichmaessig(count: Int, span: Double) -> RingLayout {
        let abstand = 360.0 / Double(count)
        return RingLayout(
            angles: (0..<count).map { Double($0) * abstand },
            cardSpan: span
        )
    }

    private func alleDa(_ count: Int) -> [Bool] {
        Array(repeating: true, count: count)
    }

    // MARK: - Auslegen

    func testTheSpacingsAlwaysAddUpToAFullCircle() {
        for anzahl in [3, 7, 20, 32, 52] {
            let layout = RingLayout.random(count: anzahl)
            XCTAssertEqual(layout.angles.count, anzahl)

            // Der Bogen von der letzten Karte zurueck zur ersten gehoert
            // dazu: Genau dort fiele eine fehlende Normierung auf.
            let letzter = 360 - layout.angles[anzahl - 1]
            XCTAssertGreaterThan(letzter, 0, "Naht bei \(anzahl) Karten")

            let abstaende = (0..<anzahl).map { position -> Double in
                position == anzahl - 1
                    ? letzter
                    : layout.angles[position + 1] - layout.angles[position]
            }
            XCTAssertEqual(abstaende.reduce(0, +), 360, accuracy: 0.0001)
            for abstand in abstaende {
                XCTAssertGreaterThan(abstand, 0, "Zwei Karten liegen aufeinander")
            }
        }
    }

    func testTheAnglesRiseAndStartAtZero() {
        let layout = RingLayout.random(count: 32)
        XCTAssertEqual(layout.angles.first, 0)
        XCTAssertEqual(layout.angles, layout.angles.sorted())
        XCTAssertLessThan(layout.angles.last ?? 360, 360)
    }

    // MARK: - Reissen

    /// Liegen die Karten dicht, schliesst sich der Ring hinter der gezogenen
    /// von selbst.
    func testADenseRingDoesNotTear() {
        // Abstand 10 Grad, Karte 25 Grad breit: Die Nachbarinnen liegen nach
        // dem Zug 20 Grad auseinander und beruehren sich noch.
        let layout = gleichmaessig(count: 36, span: 25)
        for position in 0..<36 {
            XCTAssertFalse(
                layout.tearsRing(at: position, present: alleDa(36)),
                "Position \(position) reisst, obwohl es dicht liegt"
            )
        }
    }

    /// Und liegen sie duenn, reisst jeder Zug.
    func testAThinRingTearsEverywhere() {
        // Abstand 10 Grad, Karte 15 Grad breit: Nach dem Zug sind es 20 Grad
        // zwischen den Nachbarinnen – zu weit.
        let layout = gleichmaessig(count: 36, span: 15)
        for position in 0..<36 {
            XCTAssertTrue(
                layout.tearsRing(at: position, present: alleDa(36)),
                "Position \(position) reisst nicht, obwohl es duenn liegt"
            )
        }
    }

    /// Der Rundlauf: Karte 0 grenzt an die letzte. Diese eine Stelle muss
    /// genauso gerechnet werden wie jede andere.
    func testThePositionZeroIsTreatedLikeEveryOther() {
        let duenn = gleichmaessig(count: 12, span: 25)   // 30 Grad Abstand
        XCTAssertTrue(duenn.tearsRing(at: 0, present: alleDa(12)))

        let dicht = gleichmaessig(count: 12, span: 65)
        XCTAssertFalse(dicht.tearsRing(at: 0, present: alleDa(12)))
    }

    /// Neben einer Luecke zu ziehen kostet nichts: Offen war sie vorher.
    func testDrawingNextToAHoleCostsNothing() {
        let layout = gleichmaessig(count: 36, span: 15)   // reisst sonst immer

        var liegt = alleDa(36)
        liegt[5] = false

        XCTAssertFalse(layout.tearsRing(at: 4, present: liegt), "links der Luecke")
        XCTAssertFalse(layout.tearsRing(at: 6, present: liegt), "rechts der Luecke")
        // Zwei weiter ist der Ring noch zu – dort reisst es.
        XCTAssertTrue(layout.tearsRing(at: 8, present: liegt))
    }

    /// Eine schon gezogene Karte kann nichts mehr reissen. Ohne diese Sperre
    /// wuerde ein doppelter Tipp zweimal zahlen.
    func testAnAlreadyDrawnCardTearsNothing() {
        let layout = gleichmaessig(count: 36, span: 15)
        var liegt = alleDa(36)
        liegt[9] = false
        XCTAssertFalse(layout.tearsRing(at: 9, present: liegt))
    }

    /// Mit zwei Karten gibt es keinen Ring – und damit nichts zu reissen.
    func testTwoCardsAreNoRing() {
        let layout = RingLayout.random(count: 2)
        XCTAssertFalse(layout.tearsRing(at: 0, present: alleDa(2)))
        XCTAssertFalse(layout.tearsRing(at: 1, present: alleDa(2)))
    }

    /// Unsinnige Eingaben dürfen nicht in einen Absturz laufen: Die Liste
    /// der liegenden Karten kommt aus der Ansicht und kann nach einem
    /// Neustart kurz nicht zum Ring passen.
    func testMismatchedInputIsHarmless() {
        let layout = gleichmaessig(count: 10, span: 15)
        XCTAssertFalse(layout.tearsRing(at: 3, present: alleDa(4)))
        XCTAssertFalse(layout.tearsRing(at: 99, present: alleDa(10)))
        XCTAssertFalse(layout.tearsRing(at: -1, present: alleDa(10)))
    }

    // MARK: - Die Spannungskurve

    /// Die beiden Konstanten entscheiden, wie oft es reisst. Dieser Test
    /// haelt die Groessenordnung fest: ueber eine ganze Runde drei bis vier
    /// Risse auf 52 Karten, also grob jeder vierzehnte Zug. Am Anfang ist es
    /// haeufiger, gegen Ende seltener – wo schon Luecken sind, ist nichts
    /// mehr zu reissen.
    ///
    /// Die Toleranz ist weit genug, dass kein Zufall sie sprengt. Es geht
    /// darum, dass niemand `overlapFactor` oder `jitter` unbemerkt so
    /// verstellt, dass jede zweite Karte einen Shot kostet.
    func testTheRingTearsAFewTimesPerRound() {
        var gezogen = 0
        var gerissen = 0

        for _ in 0..<200 {
            let layout = RingLayout.random(count: 52)
            var liegt = alleDa(52)

            // Eine ganze Runde durchspielen, in zufaelliger Reihenfolge.
            for position in Array(0..<52).shuffled() {
                if layout.tearsRing(at: position, present: liegt) { gerissen += 1 }
                liegt[position] = false
                gezogen += 1
            }
        }

        let anteil = Double(gerissen) / Double(gezogen)
        XCTAssertGreaterThan(anteil, 0.02, "Es reisst praktisch nie – die Regel wäre unsichtbar")
        XCTAssertLessThan(anteil, 0.25, "Es reisst zu oft – die Runde ist nach zehn Karten blau")
    }

    // MARK: - Der Stapel

    /// Die Regel, die der Nutzer am 23. Oktober verlangt hat: Von jedem
    /// Rang, der im Ring liegt, liegen ALLE VIER Karten darin.
    ///
    /// Vorher wurde der gemischte Stapel abgeschnitten, und bei zwanzig
    /// Karten lagen dann drei Buben und ein Koenig im Ring. Regeln, die vom
    /// Zaehlen leben, gehen daran kaputt: Ein Daumenmeister, den es nur
    /// einmal gibt, ist keine Rolle, sondern ein Zufall.
    func testEveryRankInTheRingIsComplete() {
        for anzahl in [20, 32, PlayingCardDeck.fullSize] {
            let stapel = PlayingCardDeck.shuffled(count: anzahl)
            XCTAssertEqual(stapel.count, anzahl, "Bei \(anzahl) Karten kamen \(stapel.count) heraus.")

            let proRang = Dictionary(grouping: stapel, by: \.rank)
            for (rang, karten) in proRang {
                XCTAssertEqual(karten.count, 4, "Rang \(rang) liegt \(karten.count)× im Ring.")
                XCTAssertEqual(
                    Set(karten.map(\.suit)).count, 4,
                    "Rang \(rang) hat nicht alle vier Farben."
                )
            }
            XCTAssertEqual(proRang.count, anzahl / 4)
        }
    }

    /// Das volle Blatt ist das volle Blatt – alle dreizehn Raenge.
    func testTheFullDeckKeepsEveryRank() {
        let stapel = PlayingCardDeck.shuffled(count: PlayingCardDeck.fullSize)
        XCTAssertEqual(Set(stapel.map(\.rank)), Set(PlayingCardDeck.ranks))
    }

    /// Mehr als ein volles Blatt gibt es nicht.
    func testMoreThanAFullDeckIsStillAFullDeck() {
        XCTAssertEqual(PlayingCardDeck.shuffled(count: 99).count, PlayingCardDeck.fullSize)
    }

}
