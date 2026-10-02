//
//  TeamChemistryTests.swift
//  BeerStatsTests
//
//  Prueft "mit wem gewinne ich, gegen wen verliere ich".
//
//  Die Rechnung ist kurz und hat trotzdem vier Stellen, an denen sie
//  lautlos falsch waere: abgebrochene Partien, Unentschieden, Paarungen aus
//  einer einzigen Partie und das 1 gegen 1, in dem es gar keinen Partner
//  gibt. Alle vier stehen hier.
//

import XCTest
@testable import BeerStats

final class TeamChemistryTests: XCTestCase {

    private let ich = "ich"

    private func partie(
        meinTeam: [String],
        gegner: [String],
        gewonnen: Bool?,
        status: GameStatus = .finished
    ) -> Game {
        let teams = [
            Team(id: "t0", playerIds: meinTeam, playerNames: meinTeam, ballsInPlay: meinTeam.count),
            Team(id: "t1", playerIds: gegner, playerNames: gegner, ballsInPlay: gegner.count)
        ]
        var game = Game(
            type: meinTeam.count == 1 ? .oneVsOne : .twoVsTwo,
            status: status,
            createdBy: "konto",
            teams: teams
        )
        // nil bleibt Unentschieden.
        if let gewonnen {
            game.winnerTeamId = gewonnen ? "t0" : "t1"
        }
        return game
    }

    /// Dieselbe Paarung so oft, dass sie die Mindestzahl erreicht.
    private func serie(
        partner: String,
        gegner: [String],
        siege: Int,
        niederlagen: Int
    ) -> [Game] {
        let gewonnen = (0..<siege).map { _ in partie(meinTeam: [ich, partner], gegner: gegner, gewonnen: true) }
        let verloren = (0..<niederlagen).map { _ in partie(meinTeam: [ich, partner], gegner: gegner, gewonnen: false) }
        return gewonnen + verloren
    }

    // MARK: - Partner

    func testTheBestPartnerIsTheOneWithTheBestRate() {
        var partien = serie(partner: "lena", gegner: ["jan", "tim"], siege: 3, niederlagen: 1)
        partien += serie(partner: "marcel", gegner: ["jan", "tim"], siege: 1, niederlagen: 3)

        let chemie = TeamChemistry(profileId: ich, games: partien)

        XCTAssertEqual(chemie.bestPartner?.profileId, "lena")
        XCTAssertEqual(chemie.bestPartner?.games, 4)
        XCTAssertEqual(chemie.bestPartner?.wins, 3)
    }

    /// Eine einzelne gewonnene Partie macht niemanden zum besten Partner.
    func testASingleGameIsNoRate() {
        let partien = [partie(meinTeam: [ich, "zufall"], gegner: ["jan", "tim"], gewonnen: true)]

        let chemie = TeamChemistry(profileId: ich, games: partien)

        XCTAssertEqual(chemie.partners.first?.games, 1, "die Paarung steht trotzdem in der Liste")
        XCTAssertNil(chemie.partners.first?.winRate)
        XCTAssertNil(chemie.bestPartner, "ohne belastbare Quote gibt es keinen besten Partner")
    }

    /// Im 1 gegen 1 gibt es keinen Partner – und erst recht nicht sich
    /// selbst.
    func testSinglesHaveNoPartner() {
        let partien = (0..<4).map { _ in partie(meinTeam: [ich], gegner: ["jan"], gewonnen: true) }

        let chemie = TeamChemistry(profileId: ich, games: partien)

        XCTAssertTrue(chemie.partners.isEmpty)
        XCTAssertEqual(chemie.opponents.first?.profileId, "jan")
    }

    // MARK: - Gegner

    func testTheWorstOpponentIsTheOneYouLoseAgainst() {
        var partien = serie(partner: "lena", gegner: ["jan", "tim"], siege: 0, niederlagen: 4)
        partien += serie(partner: "lena", gegner: ["pia", "sam"], siege: 4, niederlagen: 0)

        let chemie = TeamChemistry(profileId: ich, games: partien)

        XCTAssertEqual(chemie.worstOpponent?.winRate, 0)
        XCTAssertTrue(
            ["jan", "tim"].contains(chemie.worstOpponent?.profileId ?? ""),
            "gegen Jan und Tim wurde nie gewonnen"
        )
        XCTAssertEqual(chemie.opponents.last?.winRate, 1, "gegen Pia und Sam laeuft es am besten")
    }

    // MARK: - Was nicht zaehlt

    /// Eine abgebrochene Partie hat keinen Sieger. Sie als Niederlage zu
    /// werten waere erfunden.
    func testCancelledGamesAreIgnored() {
        var partien = serie(partner: "lena", gegner: ["jan", "tim"], siege: 3, niederlagen: 0)
        partien.append(partie(meinTeam: [ich, "lena"], gegner: ["jan", "tim"], gewonnen: nil, status: .cancelled))

        let chemie = TeamChemistry(profileId: ich, games: partien)

        XCTAssertEqual(chemie.bestPartner?.games, 3)
        XCTAssertEqual(chemie.bestPartner?.winRate, 1)
    }

    /// Ein Unentschieden ist eine gespielte Partie, aber kein Sieg.
    func testADrawCountsAsAGameButNotAsAWin() {
        var partien = serie(partner: "lena", gegner: ["jan", "tim"], siege: 2, niederlagen: 0)
        partien.append(partie(meinTeam: [ich, "lena"], gegner: ["jan", "tim"], gewonnen: nil))

        let chemie = TeamChemistry(profileId: ich, games: partien)

        XCTAssertEqual(chemie.bestPartner?.games, 3)
        XCTAssertEqual(chemie.bestPartner?.wins, 2)
    }

    /// Partien ohne den betrachteten Spieler gehen ihn nichts an.
    func testGamesWithoutThePlayerAreIgnored() {
        let partien = [partie(meinTeam: ["lena", "marcel"], gegner: ["jan", "tim"], gewonnen: true)]

        let chemie = TeamChemistry(profileId: ich, games: partien)

        XCTAssertTrue(chemie.partners.isEmpty)
        XCTAssertTrue(chemie.opponents.isEmpty)
    }
}
