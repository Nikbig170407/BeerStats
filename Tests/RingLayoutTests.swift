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
        // 30 Grad Abstand. Bei 45 Grad Kartenbreite beruehren sich die
        // Nachbarinnen (30 ≤ 45), nach dem Zug liegen 60 Grad frei – das
        // reisst. Die Breite muss UEBER dem Abstand liegen, sonst ist der
        // Ring nirgends geschlossen und es kann auch nichts reissen.
        let duenn = gleichmaessig(count: 12, span: 45)
        XCTAssertTrue(duenn.tearsRing(at: 0, present: alleDa(12)))

        let dicht = gleichmaessig(count: 12, span: 65)
        XCTAssertFalse(dicht.tearsRing(at: 0, present: alleDa(12)))
    }

    /// Liegt der Ring so weit auseinander, dass sich nirgends zwei Karten
    /// beruehren, ist er nie geschlossen – und dann kann ihn auch niemand
    /// reissen. Im Spiel kommt das nicht vor (`cardSpan` ist das 2,4-fache
    /// des mittleren Abstands), aber die Rechnung muss es aushalten.
    func testARingThatNeverTouchesCannotTear() {
        let offen = gleichmaessig(count: 12, span: 25)   // 30 Grad Abstand
        for position in 0..<12 {
            XCTAssertFalse(offen.tearsRing(at: position, present: alleDa(12)))
        }
    }

    /// Der Fehler, den der Nutzer am 25. Oktober am Tisch gesehen hat.
    ///
    /// Hier stand vorher das Gegenteil: "Neben einer Luecke reisst nichts."
    /// Das war falsch. Liegt links ein Loch, dessen Nachbarinnen sich noch
    /// beruehrten, und man zieht die Karte daneben, dann liegen danach zwei
    /// Kartenbreiten frei – von oben ist der Kreis durch. Und weil
    /// irgendwann jeder zweite Zug neben einem Loch liegt, blieb die Regel
    /// nach den ersten Karten fast ganz aus.
    func testDrawingNextToAHoleTearsTheRing() {
        // Abstand 10 Grad, Karte 25 Grad breit: Ein einzelnes Loch schliesst
        // sich noch (20 Grad), zwei nebeneinander nicht mehr (30 Grad).
        let layout = gleichmaessig(count: 36, span: 25)

        var liegt = alleDa(36)
        XCTAssertFalse(layout.tearsRing(at: 5, present: liegt), "ein Loch schliesst sich")
        liegt[5] = false

        XCTAssertTrue(layout.tearsRing(at: 4, present: liegt), "links der Luecke")
        XCTAssertTrue(layout.tearsRing(at: 6, present: liegt), "rechts der Luecke")
        // Weit weg vom Loch liegt der Ring unberuehrt dicht.
        XCTAssertFalse(layout.tearsRing(at: 20, present: liegt))
    }

    /// Fuer dieselbe Luecke zahlt aber niemand zweimal: War der Ring an
    /// dieser Stelle schon offen, reisst er dort nicht noch einmal.
    func testAnAlreadyOpenSpotDoesNotTearTwice() {
        // Karte 15 Grad breit bei 10 Grad Abstand: Hier reisst der erste Zug
        // ueberall, die Stelle ist danach also offen.
        let layout = gleichmaessig(count: 36, span: 15)

        var liegt = alleDa(36)
        XCTAssertTrue(layout.tearsRing(at: 5, present: liegt))
        liegt[5] = false

        XCTAssertFalse(layout.tearsRing(at: 4, present: liegt), "zahlt zweimal")
        XCTAssertFalse(layout.tearsRing(at: 6, present: liegt), "zahlt zweimal")
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
    /// haelt die Groessenordnung fest, damit niemand `overlapFactor` oder
    /// `jitter` unbemerkt so verstellt, dass jede zweite Karte einen Shot
    /// kostet – oder gar keine mehr.
    ///
    /// Erste Zahl: Auf einem vollstaendig ausgelegten Ring reisst jeder
    /// fuenfte Zug (nachgerechnet 20,8 bis 21,6 %, je nach Kartenzahl).
    func testEveryFifthDrawTearsAFreshRing() {
        var gerissen = 0
        let runden = 3000

        for _ in 0..<runden {
            let layout = RingLayout.random(count: 52)
            let position = Int.random(in: 0..<52)
            if layout.tearsRing(at: position, present: alleDa(52)) { gerissen += 1 }
        }

        let anteil = Double(gerissen) / Double(runden)
        XCTAssertGreaterThan(anteil, 0.15, "Es reisst praktisch nie – die Regel wäre unsichtbar")
        XCTAssertLessThan(anteil, 0.29, "Es reisst zu oft – der erste Zug kostet fast immer")
    }

    /// Zweite Zahl: wie lange die drei Shots einer Runde halten. Gespielt
    /// wird wie in `RingOfFireView` – nach den ersten beiden Rissen wird
    /// neu gelegt, nach dem dritten ist die Regel durch.
    ///
    /// Nachgerechnet kommt der dritte Riss nach rund zehn Zuegen. Das ist
    /// die Zahl, an der das Spielgefuehl haengt: Deutlich weniger, und die
    /// Regel ist vorbei, bevor jemand sie bemerkt hat.
    func testTheThreeShotsLastAboutTenDraws() {
        var summe = 0
        let runden = 300

        for _ in 0..<runden {
            var anzahl = 52
            var layout = RingLayout.random(count: anzahl)
            var liegt = alleDa(anzahl)
            var risse = 0

            while anzahl > 0, risse < 3 {
                let liegende = liegt.indices.filter { liegt[$0] }
                guard let position = liegende.randomElement() else { break }

                let reisst = layout.tearsRing(at: position, present: liegt)
                liegt[position] = false
                anzahl -= 1
                summe += 1

                guard reisst else { continue }
                risse += 1
                if risse < 3, anzahl > 0 {
                    // Einsammeln und neu legen, genau wie im Spiel.
                    layout = RingLayout.random(count: anzahl)
                    liegt = alleDa(anzahl)
                }
            }
        }

        let zuege = Double(summe) / Double(runden)
        XCTAssertGreaterThan(zuege, 6, "Die drei Shots sind weg, bevor es jemand merkt")
        XCTAssertLessThan(zuege, 17, "Es reisst zu selten – die Regel kommt kaum vor")
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
            let stapel = PlayingCardDeck.highestRanks(count: anzahl)
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

    /// Kurz gespielt heisst: die HOECHSTEN Raenge, nicht irgendwelche.
    ///
    /// Unten im Blatt stehen die Karten, die nur eine Menge ansagen; oben
    /// die, die etwas mit dem Tisch machen. Eine kurze Runde soll die
    /// dichte sein, nicht die zahme – und planbar: Was im Ring liegt, weiss
    /// man vorher.
    func testAShortRingTakesTheHighestRanks() {
        XCTAssertEqual(
            Set(PlayingCardDeck.highestRanks(count: 20).map(\.rank)),
            [10, 11, 12, 13, 14]
        )
        XCTAssertEqual(
            Set(PlayingCardDeck.highestRanks(count: 32).map(\.rank)),
            [7, 8, 9, 10, 11, 12, 13, 14]
        )
    }

    /// Dieselbe Einstellung ergibt denselben Satz Raenge – nur die
    /// Reihenfolge ist gemischt. Ohne das waere "die fuenf hoechsten" eine
    /// Behauptung, die mal stimmt.
    func testTheRanksAreTheSameEveryTime() {
        let a = Set(PlayingCardDeck.highestRanks(count: 20).map(\.rank))
        let b = Set(PlayingCardDeck.highestRanks(count: 20).map(\.rank))
        XCTAssertEqual(a, b)
    }

    /// Das volle Blatt ist das volle Blatt – alle dreizehn Raenge.
    func testTheFullDeckKeepsEveryRank() {
        let stapel = PlayingCardDeck.highestRanks(count: PlayingCardDeck.fullSize)
        XCTAssertEqual(Set(stapel.map(\.rank)), Set(PlayingCardDeck.ranks))
    }

    /// Mehr als ein volles Blatt gibt es nicht.
    func testMoreThanAFullDeckIsStillAFullDeck() {
        XCTAssertEqual(PlayingCardDeck.highestRanks(count: 99).count, PlayingCardDeck.fullSize)
    }

}
