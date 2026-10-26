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
//  Viertens, und das ist die Lehre vom 26. Oktober: Eine Luecke, die
//  niemand sieht, ist am Tisch keine. Die Regel darf nicht in dem Moment
//  feuern, in dem der Spalt gerade null ist, sondern erst, wenn man ihn
//  erkennt. `testEveryTearLeavesAGapYouCanSee` ist dafuer der Waechter.
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
        // Abstand 15 Grad, Karte 25 Grad breit: Nach dem Zug liegen die
        // Nachbarinnen 30 Grad auseinander, es bleiben also 5 Grad frei –
        // unter der Viertelkarte (6,25 Grad), die zaehlt.
        let layout = gleichmaessig(count: 24, span: 25)
        for position in 0..<24 {
            XCTAssertFalse(
                layout.tearsRing(at: position, present: alleDa(24)),
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

    /// Liegt der Ring von Anfang an sichtbar offen, kann ihn niemand
    /// reissen – er ist ja nirgends geschlossen. Im Spiel kommt das nicht
    /// vor (`cardSpan` ist knapp das Doppelte des mittleren Abstands), aber
    /// die Rechnung muss es aushalten.
    func testARingThatNeverTouchesCannotTear() {
        // 40 Grad Abstand, Karte 25 Grad: zwischen je zwei Karten klaffen
        // 15 Grad, also mehr als eine Viertelkarte.
        let offen = gleichmaessig(count: 9, span: 25)
        for position in 0..<9 {
            XCTAssertFalse(offen.tearsRing(at: position, present: alleDa(9)))
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
        // Abstand 15 Grad, Karte 25 Grad breit: Ein einzelnes Loch laesst
        // 5 Grad frei und zaehlt noch nicht; zwei nebeneinander lassen
        // 20 Grad frei, und das ist weit ueber der Viertelkarte.
        let layout = gleichmaessig(count: 24, span: 25)

        var liegt = alleDa(24)
        XCTAssertFalse(layout.tearsRing(at: 5, present: liegt), "ein Loch schliesst sich")
        liegt[5] = false

        XCTAssertTrue(layout.tearsRing(at: 4, present: liegt), "links der Luecke")
        XCTAssertTrue(layout.tearsRing(at: 6, present: liegt), "rechts der Luecke")
        // Weit weg vom Loch liegt der Ring unberuehrt dicht.
        XCTAssertFalse(layout.tearsRing(at: 15, present: liegt))
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

    // MARK: - Die Luecke muss man sehen

    /// Der Fehler, den der Nutzer am 26. Oktober am Tisch gesehen hat:
    /// "Es reisst, aber ich sehe keine Luecke."
    ///
    /// Die Ursache war die Schwelle selbst. "Gerissen" hiess bis dahin
    /// "die Nachbarinnen beruehren sich nicht mehr" – und das ist der
    /// Moment, in dem die Luecke GENAU NULL ist. Nachgerechnet lag die
    /// Haelfte aller Risse unter einem Sechstel Kartenbreite, viele bei
    /// wenigen Pixeln. Der Shot kam fuer etwas, das es noch nicht zu sehen
    /// gab, und am Tisch war das von Willkuer nicht zu unterscheiden.
    ///
    /// Dieser Test ist die Gegenprobe: Wenn es reisst, ist die Luecke
    /// mindestens eine Viertelkarte breit. Faellt er, ist die Regel wieder
    /// unsichtbar – egal wie richtig sie rechnet.
    func testEveryTearLeavesAGapYouCanSee() {
        var kleinste = Double.infinity
        var summe = 0.0
        var risse = 0

        for _ in 0..<2000 {
            let layout = RingLayout.random(count: 52)
            var liegt = alleDa(52)
            let position = Int.random(in: 0..<52)
            guard layout.tearsRing(at: position, present: liegt) else { continue }

            liegt[position] = false
            // Genau die Stelle, an der gezogen wurde, muss jetzt als offen
            // gezeichnet werden – sonst rechnet die Regel mit einer Luecke,
            // die das Bild nicht zeigt.
            guard let luecke = layout.openings(present: liegt)
                .first(where: { $0.from == (position + 51) % 52 && $0.to == (position + 1) % 52 })
            else {
                XCTFail("Riss an \(position), aber dort ist keine Luecke zu sehen")
                continue
            }

            let anteil = luecke.width / layout.cardSpan
            kleinste = min(kleinste, anteil)
            summe += anteil
            risse += 1
        }

        XCTAssertGreaterThan(risse, 100, "Zu wenige Risse für eine Aussage")
        XCTAssertGreaterThanOrEqual(
            kleinste, RingLayout.visibleGap - 0.0001,
            "Eine Luecke war schmaler als eine Viertelkarte"
        )
        // Nicht nur knapp ueber der Schwelle: Nachgerechnet liegt der
        // Mittelwert bei gut einer halben Karte. Deutlich darunter heisst,
        // dass die Risse wieder an der unsichtbaren Kante kleben.
        XCTAssertGreaterThan(
            summe / Double(risse), 0.3,
            "Die Luecken sind im Mittel zu schmal, um sie zu sehen"
        )
    }

    /// Auf einem vollstaendig ausgelegten Ring ist nichts offen – sonst
    /// stuenden Markierungen auf dem Schirm, bevor jemand gezogen hat.
    func testAFullRingShowsNoGaps() {
        for _ in 0..<200 {
            let layout = RingLayout.random(count: 20)
            XCTAssertTrue(layout.openings(present: alleDa(20)).isEmpty)
        }
    }

    /// Dieselbe Luecke wird einmal gemeldet, nicht einmal pro Richtung.
    /// Zweimal gezeichnet waere nur haesslich – zweimal gezaehlt waere
    /// falsch.
    func testAGapIsReportedOnce() {
        let layout = gleichmaessig(count: 24, span: 25)
        var liegt = alleDa(24)
        liegt[5] = false
        liegt[6] = false

        let offen = layout.openings(present: liegt)
        XCTAssertEqual(offen.count, 1, "\(offen)")
        XCTAssertEqual(offen.first?.from, 4)
        XCTAssertEqual(offen.first?.to, 7)
    }

    /// Die Markierung liegt in der MITTE der Luecke und ist so breit wie
    /// die Luecke. Beides kommt aus derselben Rechnung wie die Regel – wer
    /// das trennt, zeichnet ein Bild, das luegt.
    func testTheGapIsDrawnWhereItIs() {
        let layout = gleichmaessig(count: 24, span: 25)   // 15 Grad Abstand
        var liegt = alleDa(24)
        liegt[5] = false
        liegt[6] = false

        guard let luecke = layout.openings(present: liegt).first else {
            return XCTFail("keine Luecke")
        }
        // Karte 4 liegt bei 60 Grad, Karte 7 bei 105 – Mitte also 82,5.
        XCTAssertEqual(luecke.centerAngle, 82.5, accuracy: 0.0001)
        // 45 Grad Abstand minus 25 Grad Karte = 20 Grad frei.
        XCTAssertEqual(luecke.width, 20, accuracy: 0.0001)
    }

    /// Mit zwei liegenden Karten gibt es keinen Ring und damit keine Luecke
    /// IN ihm: Dieselbe Strecke waere sonst zweimal offen, einmal pro
    /// Richtung.
    func testTwoCardsHaveNoGapBetweenThem() {
        let layout = gleichmaessig(count: 24, span: 25)
        var liegt = Array(repeating: false, count: 24)
        liegt[0] = true
        liegt[12] = true
        XCTAssertTrue(layout.openings(present: liegt).isEmpty)
    }

    // MARK: - Die Spannungskurve

    /// Die drei Konstanten entscheiden, wie oft es reisst, und sie haengen
    /// voneinander ab: Mehr `visibleGap` macht es seltener, mehr `jitter`
    /// oefter, und `overlapFactor` wirkt in beide Richtungen. Dieser Test
    /// haelt die Groessenordnung fest, damit niemand eine davon unbemerkt
    /// so verstellt, dass jede zweite Karte einen Shot kostet – oder gar
    /// keine mehr.
    ///
    /// Erste Zahl: Auf einem frisch gelegten Ring reisst jeder fuenfte Zug
    /// (nachgerechnet rund 19 bis 20 %, je nach Kartenzahl). Die Grenzen
    /// sind bewusst weit: Sie sollen ein Verstellen merken, nicht jede
    /// Stelle hinter dem Komma.
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
