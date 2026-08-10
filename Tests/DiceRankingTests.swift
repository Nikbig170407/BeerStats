//
//  DiceRankingTests.swift
//  BeerStatsTests
//
//  Prueft die Rangfolgen von Maexchen und Schocken.
//
//  Beide habe ich aus dem Gedaechtnis geschrieben, und beide sind reine
//  Funktionen ueber einer Handvoll Wuerfeln. Eine falsche Rangfolge sieht
//  plausibel aus und faellt monatelang niemandem auf – bis irgendwann jemand
//  am Tisch behauptet, ein Pasch schlage kein Maexchen, und keiner mehr
//  weiss, was stimmt.
//
//  Die wichtigsten Tests sind deshalb die Vollstaendigkeitstests: Sie gehen
//  ALLE moeglichen Wuerfe durch – 21 bei zwei Wuerfeln, 216 bei drei – statt
//  einzelne Beispiele zu pruefen. Eine vergessene Zeile in der Rangliste
//  faellt nur so auf.
//

import XCTest
@testable import BeerStats

final class MaexchenRankingTests: XCTestCase {

    /// Alle Wuerfe, die mit zwei Wuerfeln moeglich sind.
    private var allRolls: [MaexchenRoll] {
        (1...6).flatMap { first in
            (1...6).map { second in
                MaexchenRoll(high: max(first, second), low: min(first, second))
            }
        }
    }

    func testRankingIsCompleteAndFreeOfDuplicates() {
        XCTAssertEqual(MaexchenRanking.ordered.count, 21, "es gibt 21 verschiedene Würfe")
        XCTAssertEqual(
            Set(MaexchenRanking.ordered).count,
            MaexchenRanking.ordered.count,
            "kein Wert darf doppelt in der Rangfolge stehen"
        )
    }

    /// Der wichtigste Test: Jeder tatsaechlich wuerfelbare Wert muss in der
    /// Rangfolge vorkommen. Fehlt einer, liefert `rank(of:)` minus eins und
    /// der Wurf waere schwaecher als alles andere.
    func testEveryPossibleRollHasARank() {
        for roll in allRolls {
            XCTAssertTrue(
                MaexchenRanking.ordered.contains(roll.value),
                "\(roll.label) fehlt in der Rangfolge"
            )
            XCTAssertGreaterThanOrEqual(
                MaexchenRanking.rank(of: roll.value), 0,
                "\(roll.label) hat keinen Rang"
            )
        }
    }

    func testHigherDigitAlwaysComesFirst() {
        for roll in allRolls {
            XCTAssertGreaterThanOrEqual(roll.high, roll.low)
            XCTAssertEqual(roll.value, roll.high * 10 + roll.low)
        }
    }

    /// Die Eigenheit des Spiels: 21 schlaegt alles, Paesche schlagen jede
    /// normale Zahl, und 66 ist trotzdem schwaecher als 21.
    func testMiaBeatsEverythingAndPaschesBeatNumbers() {
        let mia = 21
        let highestPasch = 66
        let highestNumber = 65

        XCTAssertEqual(MaexchenRanking.ordered.last, mia, "21 muss ganz oben stehen")
        XCTAssertTrue(MaexchenRanking.beats(highestPasch, mia), "21 schlägt 66")
        XCTAssertTrue(MaexchenRanking.beats(highestNumber, highestPasch), "66 schlägt 65")
        XCTAssertFalse(MaexchenRanking.beats(highestPasch, highestNumber), "65 schlägt 66 nicht")

        // Der schwaechste Pasch schlaegt die staerkste normale Zahl.
        XCTAssertTrue(MaexchenRanking.beats(65, 11), "11 schlägt 65")
    }

    func testValuesAboveAreStrictlyHigher() {
        for value in MaexchenRanking.ordered {
            let higher = MaexchenRanking.values(above: value)
            for candidate in higher {
                XCTAssertGreaterThan(
                    MaexchenRanking.rank(of: candidate),
                    MaexchenRanking.rank(of: value),
                    "\(candidate) wurde als höher angeboten, ist es aber nicht"
                )
            }
        }
    }

    func testNothingIsAboveMia() {
        XCTAssertTrue(MaexchenRanking.values(above: 21).isEmpty, "über 21 geht nichts")
    }

    func testWithoutAClaimEverythingIsAllowed() {
        XCTAssertEqual(MaexchenRanking.values(above: nil).count, MaexchenRanking.ordered.count)
    }

    func testRandomRollIsAlwaysValid() {
        for _ in 0..<500 {
            let roll = MaexchenRoll.random()
            XCTAssertGreaterThanOrEqual(roll.high, roll.low)
            XCTAssertTrue((1...6).contains(roll.high))
            XCTAssertTrue((1...6).contains(roll.low))
            XCTAssertTrue(MaexchenRanking.ordered.contains(roll.value))
        }
    }
}

final class SchockenRankingTests: XCTestCase {

    /// Alle 216 Kombinationen aus drei Wuerfeln.
    private var allThrows: [[Int]] {
        (1...6).flatMap { a in (1...6).flatMap { b in (1...6).map { c in [a, b, c] } } }
    }

    // MARK: - Einordnung

    func testThreeOnesAreSchockAus() {
        XCTAssertEqual(SchockenThrow.evaluate([1, 1, 1]).kind, .schockAus)
    }

    func testTwoOnesAreSchockWithTheThirdDieAsRank() {
        for third in 2...6 {
            let result = SchockenThrow.evaluate([1, third, 1])
            XCTAssertEqual(result.kind, .schock, "1-1-\(third) muss Schock sein")
            XCTAssertEqual(result.score, third, "der dritte Würfel entscheidet")
        }
    }

    func testThreeOfAKindIsGeneral() {
        for face in 2...6 {
            let result = SchockenThrow.evaluate([face, face, face])
            XCTAssertEqual(result.kind, .general)
            XCTAssertEqual(result.score, face)
        }
    }

    func testConsecutiveIsStrasse() {
        for lowest in 1...4 {
            let dice = [lowest, lowest + 1, lowest + 2]
            let result = SchockenThrow.evaluate(dice.shuffled())
            XCTAssertEqual(result.kind, .strasse, "\(dice) muss Straße sein")
            XCTAssertEqual(result.score, lowest + 2, "die höchste Augenzahl entscheidet")
        }
    }

    /// 1-2-3 enthaelt eine Eins und waere als Zahl 150 wert – es ist aber
    /// eine Strasse und schlaegt damit jede Zahl.
    func testOneTwoThreeIsAStrasseNotANumber() {
        XCTAssertEqual(SchockenThrow.evaluate([3, 1, 2]).kind, .strasse)
    }

    // MARK: - Zahlenwert

    func testNumberCountsOnesAsHundred() {
        XCTAssertEqual(SchockenThrow.evaluate([1, 6, 5]).score, 210)
        XCTAssertEqual(SchockenThrow.evaluate([6, 6, 5]).score, 170)
        XCTAssertEqual(SchockenThrow.evaluate([3, 2, 2]).score, 70)
    }

    /// Genau deshalb gibt es die Sonderregel: Eine Eins macht eine Zahl
    /// stark, obwohl sie die kleinste Augenzahl ist.
    func testANumberWithAOneBeatsThreeSixesMinusOne() {
        let withOne = SchockenThrow.evaluate([1, 6, 5])
        let withoutOne = SchockenThrow.evaluate([6, 6, 5])
        XCTAssertTrue(SchockenThrow.isWorse(withoutOne, than: withOne))
    }

    // MARK: - Rangfolge zwischen den Arten

    func testKindOrder() {
        let zahl = SchockenThrow.evaluate([1, 6, 5])        // 210, die stärkste Zahl
        let strasse = SchockenThrow.evaluate([1, 2, 3])     // die schwächste Straße
        let general = SchockenThrow.evaluate([2, 2, 2])     // der schwächste General
        let schock = SchockenThrow.evaluate([1, 1, 2])      // der schwächste Schock
        let schockAus = SchockenThrow.evaluate([1, 1, 1])

        XCTAssertTrue(SchockenThrow.isWorse(zahl, than: strasse), "jede Straße schlägt jede Zahl")
        XCTAssertTrue(SchockenThrow.isWorse(strasse, than: general), "jeder General schlägt jede Straße")
        XCTAssertTrue(SchockenThrow.isWorse(general, than: schock), "jeder Schock schlägt jeden General")
        XCTAssertTrue(SchockenThrow.isWorse(schock, than: schockAus), "Schock aus ist unschlagbar")
    }

    func testNothingBeatsSchockAus() {
        let best = SchockenThrow.evaluate([1, 1, 1])
        for dice in allThrows {
            let other = SchockenThrow.evaluate(dice)
            XCTAssertFalse(
                SchockenThrow.isWorse(best, than: other),
                "\(dice) darf Schock aus nicht schlagen"
            )
        }
    }

    // MARK: - Vollständigkeit

    /// Jeder der 216 moeglichen Wuerfe muss genau eine Art bekommen, sortiert
    /// zurueckgegeben werden und einen Text haben. Ohne diesen Test faellt
    /// eine Luecke in `evaluate` erst am Tisch auf.
    func testEveryThrowIsClassified() {
        for dice in allThrows {
            let result = SchockenThrow.evaluate(dice)

            XCTAssertEqual(result.dice.sorted(by: >), result.dice, "Würfel müssen absteigend liegen")
            XCTAssertEqual(result.dice.sorted(), dice.sorted(), "es dürfen keine Augen verlorengehen")
            XCTAssertFalse(result.label.isEmpty, "\(dice) hat keinen Text")

            if result.kind == .zahl {
                XCTAssertGreaterThan(result.score, 0, "\(dice) hat keinen Zahlenwert")
            }
        }
    }

    /// Die Vergleichsfunktion muss eine strenge Ordnung ergeben: Wenn A
    /// schlechter als B ist, darf B nicht schlechter als A sein.
    func testComparisonIsConsistent() {
        let samples = allThrows.map(SchockenThrow.evaluate)
        for left in samples.prefix(60) {
            for right in samples.prefix(60) {
                if SchockenThrow.isWorse(left, than: right) {
                    XCTAssertFalse(
                        SchockenThrow.isWorse(right, than: left),
                        "\(left.label) und \(right.label) sind gegenseitig schlechter"
                    )
                }
            }
        }
    }
}
