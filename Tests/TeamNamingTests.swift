//
//  TeamNamingTests.swift
//  BeerStatsTests
//
//  Prueft, wie ein Team genannt wird – und wie das Verb dazu lautet.
//
//  Beerpong sagte an acht Stellen "Team 1" und "Team 2", obwohl die Namen
//  im Spiel stehen. Beim Umstellen kommt ein Problem dazu, das es mit der
//  Nummer nicht gab: die Grammatik. "Team 2 wirft nochmal" war immer
//  richtig; "Lena & Jan wirft nochmal" ist es nicht.
//
//  Deshalb steht die Benennung in `Team` und nicht in der Ansicht: Dort ist
//  sie pruefbar, und zwar genau an den Stellen, an denen sie schiefgeht –
//  ein Spieler, zwei Spieler, ein Spiel ohne Namen.
//

import XCTest
@testable import BeerStats

final class TeamNamingTests: XCTestCase {

    private func team(_ namen: [String]) -> Team {
        Team(id: "t", playerIds: namen, playerNames: namen, ballsInPlay: namen.count)
    }

    // MARK: - Der Name

    func testOnePlayerIsNamedAlone() {
        XCTAssertEqual(team(["Lena"]).displayName(fallbackIndex: 0), "Lena")
    }

    func testTwoPlayersAreJoinedWithAnAmpersand() {
        XCTAssertEqual(team(["Lena", "Jan"]).displayName(fallbackIndex: 0), "Lena & Jan")
    }

    /// Drei kommen heute nicht vor (zwei pro Team), aber die Regel steht da:
    /// Komma bis zum Letzten, davor das Und.
    func testThreePlayersReadLikeASentence() {
        XCTAssertEqual(
            team(["Lena", "Jan", "Tim"]).displayName(fallbackIndex: 0),
            "Lena, Jan & Tim"
        )
    }

    /// Ohne Namen bleibt die Nummer. Das ist kein Schoenheitsfehler, sondern
    /// der Fall "Spiel aus einer Sicherung, in der keine Namen stehen".
    func testWithoutNamesTheNumberRemains() {
        XCTAssertEqual(team([]).displayName(fallbackIndex: 1), "Team 2")
        XCTAssertEqual(team(["", "  "]).displayName(fallbackIndex: 0), "Team 1")
    }

    // MARK: - Die Kurzform

    func testShortNamesStayAsTheyAre() {
        XCTAssertEqual(team(["Lena", "Jan"]).shortDisplayName(fallbackIndex: 0), "Lena & Jan")
    }

    /// Am Sperrbildschirm stehen beide Teams neben dem Stand in einer Zeile.
    func testLongNamesAreShortened() {
        let kurz = team(["Maximilian", "Konstantin"]).shortDisplayName(fallbackIndex: 0)
        XCTAssertEqual(kurz, "Maximilian & K.")
        XCTAssertLessThanOrEqual(kurz.count, Team.shortNameLimit)
    }

    /// Ein einzelner, sehr langer Name laesst sich nicht abkuerzen – er wird
    /// gekappt, statt die Zeile zu sprengen.
    func testASingleLongNameIsCut() {
        let kurz = team(["Bartholomäus-Friedrich"]).shortDisplayName(fallbackIndex: 0)
        XCTAssertEqual(kurz.count, Team.shortNameLimit)
    }

    // MARK: - Die Grammatik

    func testTheVerbFollowsTheNumberOfPeople() {
        XCTAssertEqual(team(["Lena"]).verb("wirft", "werfen"), "wirft")
        XCTAssertEqual(team(["Lena", "Jan"]).verb("wirft", "werfen"), "werfen")
    }

    /// Ein Team ohne Namen heisst "Team 1" – also Singular, wie vorher.
    func testATeamWithoutNamesStaysSingular() {
        XCTAssertFalse(team([]).isPlural)
        XCTAssertEqual(team([]).verb("gewinnt", "gewinnen"), "gewinnt")
    }

    /// Leere Eintraege zaehlen nicht mit. Sonst waere ein Team mit einem
    /// Spieler und einem leeren Platz ploetzlich Plural.
    func testEmptyNamesDoNotCount() {
        XCTAssertFalse(team(["Lena", ""]).isPlural)
        XCTAssertEqual(team(["Lena", ""]).displayName(fallbackIndex: 0), "Lena")
    }
}
