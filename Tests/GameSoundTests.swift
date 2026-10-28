//
//  GameSoundTests.swift
//  BeerStatsTests
//
//  Ein Klang ohne Datei faellt nicht als Fehler auf: `SoundManager` bleibt
//  dann einfach still, und am Tisch heisst das nur "da kam nichts". Genau
//  deshalb haelt ein Test fest, was das Ohr nicht meldet.
//

import XCTest
@testable import BeerStats

final class GameSoundTests: XCTestCase {

    /// Jeder Fall braucht seine Datei unter `Resources/Sounds`.
    ///
    /// Gesucht wird im Quellordner und nicht im Bundle: So faellt eine
    /// fehlende Datei auch dann auf, wenn das Testziel ohne die App laeuft.
    func testEverySoundHasAFile() {
        let ordner = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Sounds")

        for klang in GameSound.allCases {
            let vorhanden = GameSound.supportedExtensions.contains { endung in
                FileManager.default.fileExists(
                    atPath: ordner.appendingPathComponent("\(klang.rawValue).\(endung)").path
                )
            }
            XCTAssertTrue(vorhanden, "\(klang.rawValue) hat keine Datei in Resources/Sounds")
        }
    }

    /// Dreizehn Raenge, dreizehn Klaenge. Vorher teilten sich neun Raenge
    /// denselben Kartenklang, und am Tisch hoerte man nicht, welche Karte kam.
    func testEveryRankHasItsOwnSound() {
        let klaenge = (2...14).map(GameSound.ringRank)

        XCTAssertEqual(Set(klaenge).count, 13)
    }

    /// Alles ausserhalb von 2 bis 13 ist das Ass – dieselbe Zuordnung wie
    /// bei den Regeln, sonst klaenge eine Karte nach einer anderen.
    func testAnythingElseSoundsLikeTheAce() {
        XCTAssertEqual(GameSound.ringRank(14), .ringRank14)
        XCTAssertEqual(GameSound.ringRank(1), .ringRank14)
        XCTAssertEqual(GameSound.ringRank(99), .ringRank14)
    }
}
