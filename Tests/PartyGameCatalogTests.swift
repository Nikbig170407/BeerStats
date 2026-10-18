//
//  PartyGameCatalogTests.swift
//  BeerStatsTests
//
//  Prueft den Katalog als Ganzes – die Angaben, aus denen der Wuerfel
//  ("Was spielen wir?") seine Auswahl baut.
//
//  Der Wuerfel ist genau so gut wie diese Angaben. Steht bei einem Spiel
//  eine falsche Untergrenze, lost er "Der Spion" fuer zwei Leute aus – und
//  das ist kein Vorschlag, sondern ein Fehler, den die Runde erst merkt,
//  wenn sie schon im Spiel steht.
//
//  Der wichtigste Test hier ist der letzte: Fuer jede Spielerzahl muss
//  etwas uebrig bleiben. Ein Wuerfel, der "nichts gefunden" sagt, ist
//  schlimmer als keiner.
//

import XCTest
@testable import BeerStats

final class PartyGameCatalogTests: XCTestCase {

    // MARK: - Die Angaben

    func testEveryGameHasASensibleRange() {
        for game in PartyGame.allCases {
            XCTAssertGreaterThanOrEqual(game.players.lowerBound, 2, game.title)
            XCTAssertGreaterThanOrEqual(game.players.upperBound, game.players.lowerBound, game.title)
        }
    }

    /// „ab 3" oder „2–10" – aber nie beides und nie eine Obergrenze, die
    /// es gar nicht gibt.
    func testThePlayerLabelMatchesTheRange() {
        XCTAssertEqual(PartyGame.spy.playersLabel, "ab 3")
        XCTAssertEqual(PartyGame.schocken.playersLabel, "2–10")
    }

    // MARK: - Die Auswahl

    /// Was nebenher laeuft, ist keine Antwort auf „was spielen wir jetzt".
    func testTheDiceNeverSuggestsSomethingThatRunsAlongside() {
        for anzahl in 2...PartyGame.manyPlayers {
            let passend = PartyGame.fitting(players: anzahl)
            XCTAssertFalse(
                passend.contains { $0.length == .alongside },
                "Bei \(anzahl) Leuten steht etwas Nebenherlaufendes im Topf."
            )
        }
    }

    /// Zu zweit darf kein Spiel vorgeschlagen werden, das eine Runde
    /// braucht – niemanden zum Draufzeigen, keinen Spion zum Ueberstimmen.
    func testGamesThatNeedAGroupStayOutOfADuo() {
        let zuZweit = PartyGame.fitting(players: 2)
        for game in [PartyGame.spy, .mostLikely, .charades, .headsUp, .categories, .bombPass, .twoTruths] {
            XCTAssertFalse(zuZweit.contains(game), "\(game.title) wurde für zwei Leute vorgeschlagen.")
        }
    }

    /// Wer nochmal wuerfelt, will etwas anderes sehen.
    func testRollingAgainAvoidsTheLastResult() {
        let vorher = PartyGame.fitting(players: 6, length: .quick)
        XCTAssertGreaterThan(vorher.count, 1, "Testvoraussetzung: mehr als ein kurzes Spiel")

        for _ in 0..<30 {
            let gezogen = PartyGame.draw(players: 6, length: .quick, excluding: vorher[0])
            XCTAssertNotEqual(gezogen, vorher[0])
        }
    }

    /// Der wichtigste: Fuer jede Spielerzahl muss etwas da sein, sonst sagt
    /// der Wuerfel „nichts gefunden" – und dafuer braucht niemand einen
    /// Wuerfel.
    func testEveryGroupSizeFindsSomething() {
        for anzahl in 2...PartyGame.manyPlayers {
            XCTAssertFalse(
                PartyGame.fitting(players: anzahl).isEmpty,
                "Für \(anzahl) Leute bleibt nichts übrig."
            )
            XCTAssertNotNil(PartyGame.draw(players: anzahl), "\(anzahl) Leute gehen leer aus.")
        }
    }
}
