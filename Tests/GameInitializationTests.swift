//
//  GameInitializationTests.swift
//  BeerStatsTests
//
//  Der Initialisierer von `Game` baut zwei Woerterbuecher aus den Teams –
//  verbleibende Becher je Team, Trefferserie je Spieler. Mit
//  `Dictionary(uniqueKeysWithValues:)` war das ein Laufzeitabbruch, sobald
//  ein Schluessel doppelt vorkam, und die Spieler-IDs kommen aus beiden
//  Teams zusammen.
//
//  Ueber die Auswahl-Oberflaeche ist das nicht ausloesbar, die filtert
//  bereits vergebene Profile heraus. Genau darin lag das Problem: Die
//  Absicherung stand in der Oberflaeche und nicht dort, wo der Absturz
//  passiert. Jeder weitere Weg, eine Partie zu erzeugen – Gluecksrad,
//  Turnier, Wiederherstellen aus einer Sicherung, spaeter die Lobby –
//  haette dieselbe Regel von sich aus einhalten muessen.
//
//  Dieser Test baut deshalb bewusst kaputte Aufstellungen. Er prueft nicht,
//  dass sie sinnvoll sind – er prueft, dass sie die App nicht mitnehmen.
//

import XCTest
@testable import BeerStats

final class GameInitializationTests: XCTestCase {

    /// Derselbe Spieler in beiden Teams. Frueher ein Absturz beim Anlegen.
    func testDuplicatePlayerAcrossTeamsDoesNotCrash() {
        let teams = [
            Team(id: "t0", playerIds: ["p0", "p1"], playerNames: ["Anna", "Ben"], ballsInPlay: 2),
            Team(id: "t1", playerIds: ["p0", "p2"], playerNames: ["Anna", "Cem"], ballsInPlay: 2)
        ]

        let game = Game(type: .twoVsTwo, createdBy: "konto", teams: teams)

        // Die doppelte ID darf genau einmal im Serien-Zaehler stehen, sonst
        // haetten wir statt des Absturzes einen stillen Datenfehler.
        XCTAssertEqual(Set(game.playerStreaks.keys), ["p0", "p1", "p2"])
        XCTAssertEqual(game.playerStreaks["p0"], 0)
        XCTAssertTrue(game.playerStreaks.values.allSatisfy { $0 == 0 })
    }

    /// Dasselbe Argument fuer die Team-IDs: bauartbedingt eindeutig, aber der
    /// Initialisierer darf sich nicht darauf verlassen.
    func testDuplicateTeamIdDoesNotCrash() {
        let format = GameFormat()
        let teams = [
            Team(id: "t0", playerIds: ["p0"], playerNames: ["Anna"], ballsInPlay: 2),
            Team(id: "t0", playerIds: ["p1"], playerNames: ["Ben"], ballsInPlay: 2)
        ]

        let game = Game(type: .oneVsOne, createdBy: "konto", teams: teams, format: format)

        XCTAssertEqual(game.cupsRemaining, ["t0": format.cupCount])
    }

    /// Der Normalfall muss sich durch die Umstellung nicht geaendert haben.
    func testRegularLineupIsUnchanged() {
        let format = GameFormat()
        let teams = [
            Team(id: "t0", playerIds: ["p0", "p1"], playerNames: ["Anna", "Ben"], ballsInPlay: 2),
            Team(id: "t1", playerIds: ["p2", "p3"], playerNames: ["Cem", "Dana"], ballsInPlay: 2)
        ]

        let game = Game(type: .twoVsTwo, createdBy: "konto", teams: teams)

        XCTAssertEqual(game.cupsRemaining, ["t0": format.cupCount, "t1": format.cupCount])
        XCTAssertEqual(game.playerStreaks, ["p0": 0, "p1": 0, "p2": 0, "p3": 0])
        XCTAssertEqual(game.allPlayerIds, ["p0", "p1", "p2", "p3"])
    }
}
