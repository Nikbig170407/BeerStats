//
//  RingSpotlightPlanTests.swift
//  BeerStatsTests
//
//  Der Tisch von Ring of Fire: wann das Licht wo steht, und wie die Karten
//  zwischen Stapel und Platz unterwegs sind. Beides lesen zwei Stellen –
//  die Karten und die Funken darueber –, also muss es stimmen, bevor es
//  jemand sieht.
//

import XCTest
@testable import BeerStats

final class RingSpotlightPlanTests: XCTestCase {

    /// Das Licht haelt dort, wo die Karte herkommt – bei jeder Ringgroesse
    /// und jedem Ziel. Sonst saehe es nach Auslosung aus und waere keine.
    func testTheLightStopsOnTheDrawnCard() {
        for anzahl in 1...52 {
            let liegende = Array(0..<anzahl).map { $0 * 2 }
            for ziel in liegende {
                guard let plan = RingSpotlightPlan(target: ziel, over: liegende) else {
                    return XCTFail("Kein Plan fuer \(ziel) von \(anzahl)")
                }
                XCTAssertEqual(plan.stops.last, ziel)
                XCTAssertGreaterThan(plan.stops.count, RingSpotlightPlan.minimumSteps)
            }
        }
    }

    /// Liegt das Ziel gar nicht im Ring, gibt es keinen Plan statt eines
    /// Lichts, das irgendwo haelt.
    func testNoPlanForACardThatIsNotThere() {
        XCTAssertNil(RingSpotlightPlan(target: 5, over: [0, 1, 2]))
    }

    /// Erst gleichmaessig schnell, dann immer langsamer, und der letzte
    /// Schritt ist der laengste – das ist der Trick am Gluecksrad.
    func testItRunsFastThenSlowsDown() throws {
        let plan = try XCTUnwrap(RingSpotlightPlan(target: 7, over: Array(0..<20)))
        var dauern: [Double] = []
        for schritt in plan.times.indices {
            let naechster = schritt + 1 < plan.times.count ? plan.times[schritt + 1] : plan.halt
            dauern.append(naechster - plan.times[schritt])
        }

        XCTAssertEqual(plan.times.first, 0)
        for (vorher, nachher) in zip(dauern, dauern.dropFirst()) {
            XCTAssertGreaterThanOrEqual(nachher, vorher - 1e-9)
        }
        XCTAssertEqual(dauern.last ?? 0, RingSpotlightPlan.slowLast, accuracy: 1e-9)

        // Gezaehlt wird nur in der schnellen Phase anders – genau die
        // letzten Schritte bremsen
        let langsame = plan.stops.indices.filter { !plan.isFast($0) }
        XCTAssertEqual(langsame.count, RingSpotlightPlan.slowSteps + 1)
        XCTAssertEqual(langsame.last, plan.stops.count - 1)
    }

    /// Etwa drei Sekunden: kurz genug zum Warten, lang genug, dass man das
    /// Abbremsen sieht. Am laengsten dauert es mit vollem Ring und Ziel
    /// kurz vor dem Anfang – fast zwei Runden.
    func testItTakesAboutThreeSeconds() throws {
        for anzahl in [4, 20, 52] {
            for ziel in [0, anzahl - 1] {
                let plan = try XCTUnwrap(RingSpotlightPlan(target: ziel, over: Array(0..<anzahl)))
                XCTAssertGreaterThan(plan.halt, 2.5)
                XCTAssertLessThan(plan.halt, 4)
            }
        }
    }

    /// Die Karte landet genau auf ihrem Platz, in ihrer Lage und Groesse –
    /// das Austeilen endet ohne Ruck.
    func testADealtCardLandsExactlyOnItsPlace() {
        for winkel in stride(from: 0.0, to: 360, by: 7.5) {
            let lage = RingTableArt.dealPose(1, angle: winkel, radius: 120)
            let platz = RingTearArt.point(0, 0, 120, winkel)
            XCTAssertEqual(lage.x, platz.x, accuracy: 1e-9)
            XCTAssertEqual(lage.y, platz.y, accuracy: 1e-9)
            XCTAssertEqual(lage.scale, 1, accuracy: 1e-9)
            XCTAssertEqual(rest(lage.turn - winkel), 0, accuracy: 1e-9)
        }
    }

    /// Im Stapel liegen alle Karten gleich, egal wo ihr Platz ist – nur so
    /// sieht niemand, dass darunter neu gelegt wird.
    func testThePileDoesNotKnowThePlaces() {
        for winkel in stride(from: 0.0, to: 360, by: 7.5) {
            let lage = RingTableArt.dealPose(0, angle: winkel, radius: 120)
            XCTAssertEqual(lage.x, 0, accuracy: 1e-9)
            XCTAssertEqual(lage.y, 0, accuracy: 1e-9)
            XCTAssertEqual(lage.scale, Double(RingMotion.pileScale), accuracy: 1e-9)
            XCTAssertEqual(rest(lage.turn + RingMotion.pileTwist), 0, accuracy: 1e-9)
        }
    }

    /// Die gehobene Karte beginnt genau auf ihrem Platz, und der Ruck beim
    /// Halt ist vorher und nachher null – sonst stuende der Ring in Ruhe
    /// eine Spur zu gross da.
    func testLiftAndNodStartAndEndAtRest() {
        let anfang = RingTableArt.liftPose(0, angle: 250)
        XCTAssertEqual(anfang.reach, 1, accuracy: 1e-9)
        XCTAssertEqual(anfang.scale, 1, accuracy: 1e-9)
        XCTAssertEqual(anfang.turn, 0, accuracy: 1e-9)
        XCTAssertEqual(anfang.opacity, 1, accuracy: 1e-9)
        XCTAssertEqual(RingTableArt.liftPose(1, angle: 250).opacity, 0, accuracy: 1e-9)

        XCTAssertEqual(RingTableArt.nod(0), 0)
        XCTAssertEqual(RingTableArt.nod(RingMotion.nod), 0)
        XCTAssertGreaterThan(RingTableArt.nod(0.05), 0.5)
    }

    /// Winkelrest auf (-180, 180].
    private func rest(_ grad: Double) -> Double {
        var w = grad.truncatingRemainder(dividingBy: 360)
        if w > 180 { w -= 360 }
        if w <= -180 { w += 360 }
        return w
    }
}
