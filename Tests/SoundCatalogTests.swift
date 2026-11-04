//
//  SoundCatalogTests.swift
//  BeerStatsTests
//
//  Ein Klang ohne Datei faellt nicht auf: `SoundManager` bleibt dann
//  absichtlich still, und am Tisch fehlt nur ein Geraeusch, das niemand
//  vermisst, weil niemand weiss, dass es eines geben sollte. `check.py` sieht
//  die Dateien im Ordner; dieser Test sieht, was wirklich in der App landet –
//  auch jede Fassung eines Klangs.
//

import XCTest
@testable import BeerStats

final class SoundCatalogTests: XCTestCase {

    /// Das Bundle, in dem die App ihre Klaenge sucht.
    private let bundle = Bundle(for: AppState.self)

    func testEverySoundAndEveryVariantIsInTheApp() {
        for sound in GameSound.allCases {
            for name in sound.fileNames {
                let gefunden = GameSound.supportedExtensions.contains {
                    bundle.url(forResource: name, withExtension: $0) != nil
                }
                XCTAssertTrue(gefunden, "\(name) fehlt in der App – \(sound) bliebe still")
            }
        }
    }

    /// Reihum, nicht gewuerfelt: Die erste Fassung heisst wie der Fall, die
    /// weiteren tragen eine Nummer, und nach der letzten kommt wieder die
    /// erste.
    func testVariantsTakeTurns() {
        XCTAssertEqual(GameSound.cardFlip.fileName(forRepetition: 0), "cardFlip")
        XCTAssertEqual(GameSound.cardFlip.fileName(forRepetition: 1), "cardFlip2")
        XCTAssertEqual(GameSound.cardFlip.fileName(forRepetition: GameSound.cardFlip.variants), "cardFlip")
        XCTAssertEqual(GameSound.tap.fileNames, ["tap"])
    }
}
