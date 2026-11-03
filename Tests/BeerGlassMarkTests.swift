//
//  BeerGlassMarkTests.swift
//  BeerStatsTests
//
//  Das Bierglas im Hauptmenue und im Login trug seine Schaumkrone bis zum
//  3. November ueber dem Glas statt auf dem Bier. Ob ein Zeichen gut
//  aussieht, sagt kein Test – aber wo der Schaum liegt, ist eine Rechnung,
//  und die laesst sich pruefen.
//

import XCTest
@testable import BeerStats

final class BeerGlassMarkTests: XCTestCase {

    /// Die Groessen, in denen das Zeichen tatsaechlich steht, und Fuellhoehen
    /// von halbleer bis randvoll.
    private let groessen: [CGFloat] = [44, 56, 58, 88]
    private let fuellhoehen: [CGFloat] = [0.3, 0.5, 0.72, 0.95, 1]

    private func hoehe(_ size: CGFloat) -> CGFloat { size * BeerGlassMark.heightRatio }

    /// Der Fehler vom 3. November: Der Schaum ragte ueber den Rand.
    func testTheFoamStaysInsideTheGlass() {
        for size in groessen {
            for fuellung in fuellhoehen {
                let schaum = BeerGlassMark.foamFrame(size: size, fillLevel: fuellung)
                XCTAssertGreaterThanOrEqual(schaum.minY, 0, "Schaum über dem Rand bei \(size) pt, \(fuellung)")
                XCTAssertLessThanOrEqual(schaum.maxY, hoehe(size))
            }
        }
    }

    /// Er sitzt AUF dem Bier: Die Oberflaeche liegt innerhalb des Schaums,
    /// sonst stuende zwischen beiden ein Streifen leeres Glas.
    func testTheFoamSitsOnTheBeer() {
        for size in groessen {
            for fuellung in fuellhoehen where fuellung < 1 {
                let schaum = BeerGlassMark.foamFrame(size: size, fillLevel: fuellung)
                let oberflaeche = hoehe(size) * (1 - fuellung)
                XCTAssertLessThanOrEqual(schaum.minY, oberflaeche, "Schaum unter der Oberfläche bei \(size) pt, \(fuellung)")
                XCTAssertGreaterThan(schaum.maxY, oberflaeche, "Schaum schwebt über dem Bier bei \(size) pt, \(fuellung)")
            }
        }
    }

    /// Nirgends breiter als das Glas innen an derselben Stelle – geprueft
    /// ueber die ganze Hoehe der Ellipse, nicht nur in ihrer Mitte.
    func testTheFoamIsNeverWiderThanTheGlass() {
        for size in groessen {
            for fuellung in fuellhoehen {
                let schaum = BeerGlassMark.foamFrame(size: size, fillLevel: fuellung)
                for schritt in 0...20 {
                    let y = schaum.minY + schaum.height * CGFloat(schritt) / 20
                    let abstand = (y - schaum.midY) / (schaum.height / 2)
                    let ellipse = schaum.width * sqrt(max(0, 1 - abstand * abstand))
                    let glas = CupShape.width(size, atDepth: y / hoehe(size)) - BeerGlassMark.rimWidth
                    XCTAssertLessThanOrEqual(ellipse, glas + 0.0001, "Schaum breiter als das Glas bei \(size) pt, \(fuellung)")
                }
                XCTAssertEqual(schaum.midX, size / 2, accuracy: 0.0001, "Schaum nicht mittig")
            }
        }
    }

    /// Die Breite des Bechers kommt aus seiner Form: oben weiter als unten,
    /// und an beiden Enden genau die Einzuege, mit denen er gezeichnet wird.
    func testTheCupWidthFollowsItsShape() {
        XCTAssertEqual(CupShape.width(100, atDepth: 0), 100 * (1 - 2 * CupShape.topInsetFraction), accuracy: 0.0001)
        XCTAssertEqual(CupShape.width(100, atDepth: 1), 100 * (1 - 2 * CupShape.bottomInsetFraction), accuracy: 0.0001)
        XCTAssertGreaterThan(CupShape.width(100, atDepth: 0.2), CupShape.width(100, atDepth: 0.8))
    }
}
