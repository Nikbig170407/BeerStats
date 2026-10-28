//
//  NeonSignTests.swift
//  BeerStatsTests
//
//  Die Leuchtreklame von "Ich hab noch nie" wechselt seit dem 28. Oktober
//  von Karte zu Karte Farbe, Rahmen und Schrift. Ob das schoen aussieht,
//  sagt kein Test – aber dass zwei Karten hintereinander nie gleich
//  leuchten, dass Rot den Strafen gehoert und dass die Gluehbirnen auf dem
//  Rahmen sitzen, schon.
//

import XCTest
@testable import BeerStats

final class NeonSignTests: XCTestCase {

    /// Zwei Karten hintereinander leuchten nie gleich – auch nicht, wenn
    /// eine Strafe dazwischen lag und die Stelle um zwei weitergezaehlt hat.
    func testNoTwoCardsInARowLookAlike() {
        for stelle in 0..<300 {
            let jetzt = NeonSign.Look.forCard(at: stelle)
            for abstand in [1, 2] {
                let danach = NeonSign.Look.forCard(at: stelle + abstand)
                XCTAssertNotEqual(jetzt.tube, danach.tube, "Farbe an Stelle \(stelle) und \(stelle + abstand)")
                XCTAssertNotEqual(jetzt.frame, danach.frame, "Rahmen an Stelle \(stelle) und \(stelle + abstand)")
                XCTAssertNotEqual(jetzt.lettering, danach.lettering, "Schrift an Stelle \(stelle) und \(stelle + abstand)")
            }
        }
    }

    /// Rot gehoert den Strafen. Eine Aussage in Rot oder fast Rot saehe aus
    /// wie eine Strafe, und dann liest jemand eine Frage als Anweisung.
    func testRedBelongsToThePenalties() {
        XCTAssertEqual(NeonSign.Look.penalty.tube, NeonSign.red)

        let rot = farbton(NeonSign.red)
        for roehre in NeonSign.statementTubes {
            XCTAssertNotEqual(roehre, NeonSign.red)
            let abstand = min(abs(farbton(roehre) - rot), 360 - abs(farbton(roehre) - rot))
            let blass = saettigung(roehre) < 0.25
            XCTAssertTrue(abstand >= 25 || blass, "Zu nah an Rot: \(roehre)")
        }
    }

    /// Die Kopfzeile leuchtet nie in derselben Farbe wie der Satz – sonst
    /// verschwimmen beide zu einem Schild ohne Ueberschrift.
    func testTheHeaderNeverShinesLikeTheSentence() {
        for stelle in 0..<100 {
            let aussehen = NeonSign.Look.forCard(at: stelle)
            XCTAssertNotEqual(aussehen.headerTube, aussehen.tube, "Stelle \(stelle)")
        }
    }

    /// Jede Farbe, jeder Rahmen und jede Schrift kommt vor, und bis sich
    /// eine ganze Kombination wiederholt, vergeht ein langer Abend.
    func testEveryColorFrameAndLetteringComesUp() {
        let runde = (0..<35).map { NeonSign.Look.forCard(at: $0) }

        XCTAssertEqual(runde.map(\.frame).uniqueCount, NeonSign.Frame.allCases.count)
        XCTAssertEqual(runde.map(\.lettering).uniqueCount, NeonSign.Lettering.allCases.count)
        XCTAssertEqual(
            Set(runde.map { NeonSign.statementTubes.firstIndex(of: $0.tube) ?? -1 }).count,
            NeonSign.statementTubes.count
        )

        let kombinationen = (0..<100).map { stelle -> String in
            let a = NeonSign.Look.forCard(at: stelle)
            let farbe = NeonSign.statementTubes.firstIndex(of: a.tube) ?? -1
            return "\(farbe)-\(a.frame)-\(a.lettering)"
        }
        XCTAssertEqual(Set(kombinationen).count, kombinationen.count, "Eine Kombination kehrt zu frueh wieder")
    }

    /// Die Gluehbirnen sitzen auf dem Rahmen, gleichmaessig verteilt –
    /// rundum, auch in den Ecken.
    func testTheBulbsSitOnTheFrame() {
        let groesse = CGSize(width: 300, height: 420)
        let r = 30.0
        let abstand = 21.0
        let birnen = NeonSign.bulbPositions(in: groesse, radius: r, spacing: abstand)

        let umfang = 2 * (300 - 2 * r) + 2 * (420 - 2 * r) + 2 * Double.pi * r
        XCTAssertEqual(Double(birnen.count), (umfang / abstand).rounded(.down), accuracy: 1)

        for birne in birnen {
            XCTAssertLessThan(abstandZumRahmen(birne, 300, 420, r), 0.5, "Birne neben dem Rahmen: \(birne)")
        }
        // Rundum verteilt: in jeder Haelfte gleich viele, bis auf eine
        let links = birnen.filter { $0.x < 150 }.count
        XCTAssertLessThanOrEqual(abs(links - (birnen.count - links)), 2)
    }

    // MARK: - Hilfe

    private func farbton(_ t: NeonSign.Tube) -> Double {
        let r = t.r / 255, g = t.g / 255, b = t.b / 255
        let hoch = max(r, g, b), tief = min(r, g, b), d = hoch - tief
        guard d > 0 else { return 0 }
        let h: Double
        if hoch == r {
            h = (g - b) / d
        } else if hoch == g {
            h = (b - r) / d + 2
        } else {
            h = (r - g) / d + 4
        }
        return (h * 60 + 360).truncatingRemainder(dividingBy: 360)
    }

    private func saettigung(_ t: NeonSign.Tube) -> Double {
        let hoch = max(t.r, t.g, t.b), tief = min(t.r, t.g, t.b)
        return hoch == 0 ? 0 : (hoch - tief) / hoch
    }

    /// Wie weit ein Punkt vom Rand eines gerundeten Rechtecks liegt.
    private func abstandZumRahmen(_ p: SceneArt.Point, _ w: Double, _ h: Double, _ r: Double) -> Double {
        // In den Ecken zaehlt der Abstand zum Viertelkreis
        let cx = min(max(p.x, r), w - r)
        let cy = min(max(p.y, r), h - r)
        if p.x != cx && p.y != cy {
            return abs(((p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy)).squareRoot() - r)
        }
        // Sonst zur naechsten Kante
        return min(abs(p.x), abs(p.x - w), abs(p.y), abs(p.y - h))
    }
}

private extension Array where Element: Hashable {
    var uniqueCount: Int { Set(self).count }
}
