//
//  HouseRulesTests.swift
//  BeerStatsTests
//
//  Prueft, dass die abschaltbaren Regeln tatsaechlich abgeschaltet sind.
//
//  Die Schalter standen seit dem ersten Tag im `GameFormat`, waren aber
//  nirgends einstellbar – also hat auch nie jemand nachgesehen, ob sie
//  wirken. Beim Durchgehen fiel genau einer auf, der es nicht tat: Die
//  Redemption lief auch mit `redemptionAllowed == false`. Ein Schalter, der
//  nichts tut, ist schlimmer als ein fehlender, weil man ihn umlegt und
//  glaubt, es gelte jetzt etwas anderes.
//
//  Deshalb hat hier jeder Schalter seinen eigenen Test. Sie sind billig, und
//  sie sind das Einzige, was diese Frage ohne Geraet beantworten kann.
//

import XCTest
@testable import BeerStats

final class HouseRulesTests: XCTestCase {

    private func play(_ actions: [GameAction], from state: LiveGameState, format: GameFormat) -> LiveGameState {
        actions.reduce(state) { GameEngine.apply($1, to: $0, format: format).state }
    }

    private func newGame(_ format: GameFormat, playersPerTeam: Int = 2) -> LiveGameState {
        GameEngine.makeInitialState(format: format, playersPerTeam: playersPerTeam)
    }

    /// Raeumt das Rack von Team 1 komplett ab. Team 0 bleibt durch Balls Back
    /// und On Fire durchgehend am Zug.
    private func clearOpponentRack(format: GameFormat) -> LiveGameState {
        var state = newGame(format)
        for cup in 0..<format.cupCount {
            state = play([.hitCup(index: cup)], from: state, format: format)
        }
        return state
    }

    // MARK: - Redemption

    func testRedemptionRunsWhenAllowed() {
        let state = clearOpponentRack(format: GameFormat())
        XCTAssertEqual(state.phase, .redemption)
    }

    /// Rueckfall-Test: `handleRackCleared` hat den Schalter nie gelesen.
    func testDisabledRedemptionEndsTheGameAtOnce() {
        var format = GameFormat()
        format.redemptionAllowed = false

        let state = clearOpponentRack(format: format)

        XCTAssertEqual(state.phase, .finished, "ohne Redemption ist der letzte Becher das Spielende")
        XCTAssertEqual(state.winnerTeamIndex, 0)
    }

    // MARK: - On Fire

    func testDisabledOnFireHandsTheBallOn() {
        var format = GameFormat()
        format.onFireEnabled = false

        // Derselbe Aufbau wie in GameEngineTests: Zweimal Balls Back, damit
        // Spieler 0 auf drei eigene Treffer in Folge kommt. Mit der Regel
        // haette er jetzt den Ball behalten.
        let state = play(
            [.hitCup(index: 0), .hitCup(index: 1),
             .hitCup(index: 2), .hitCup(index: 3),
             .hitCup(index: 4)],
            from: newGame(format),
            format: format
        )

        XCTAssertFalse(state.onFire[0][0])
        XCTAssertEqual(state.pending, .normal, "ohne On Fire gibt es keinen Bonuswurf")
        XCTAssertEqual(state.currentBallIndex, 1, "der Zug laeuft normal weiter")
        XCTAssertEqual(state.streaks[0][0], 3, "die Serie wird trotzdem weiter gezaehlt")
    }

    /// Im 1 gegen 1 wirft dieselbe Person jeden Ball – nur so laesst sich eine
    /// Serie von vier Treffern ueberhaupt aufbauen.
    func testRaisedThresholdDelaysOnFire() {
        var format = GameFormat()
        format.onFireStreakThreshold = 4

        let start = newGame(format, playersPerTeam: 1)
        let afterThree = play(
            [.hitCup(index: 0), .hitCup(index: 1), .hitCup(index: 2)],
            from: start,
            format: format
        )
        XCTAssertFalse(afterThree.onFire[0][0], "bei Schwelle 4 reichen drei Treffer nicht")

        let afterFour = play([.hitCup(index: 3)], from: afterThree, format: format)
        XCTAssertTrue(afterFour.onFire[0][0])
        XCTAssertEqual(afterFour.pending, .onFireBonus)
    }

    // MARK: - Wurfarten

    func testDisabledBounceIsNotOffered() {
        var format = GameFormat()
        format.bounceShotsAllowed = false

        let state = newGame(format)
        XCTAssertFalse(GameEngine.canArmBounce(in: state, format: format))

        // Auch die Aktion selbst muss folgenlos bleiben – die View ist nicht
        // die einzige Stelle, von der eine Aktion kommen kann.
        let after = play([.toggleBounce], from: state, format: format)
        XCTAssertFalse(after.bounceArmed)
    }

    func testDisabledTrickshotIsNotOffered() {
        var format = GameFormat()
        format.trickshotsAllowed = false

        let state = newGame(format)
        XCTAssertFalse(GameEngine.canRebound(in: state, format: format))

        let after = play([.rebound], from: state, format: format)
        XCTAssertEqual(after, state, "ohne Trickshot darf der Rebound nichts veraendern")
    }

    func testDisabledAirballPenaltyStillCountsTheThrow() {
        var format = GameFormat()
        format.airballPenaltyEnabled = false

        let result = GameEngine.apply(.airball, to: newGame(format), format: format)

        XCTAssertEqual(result.events, [.airball(thrower: PlayerRef(teamIndex: 0, slot: 0), penalised: false)])
        XCTAssertEqual(result.state.stats[0][0].airballs, 0, "ohne Strafe wird auch nichts gezaehlt")
        XCTAssertEqual(result.state.stats[0][0].attempts, 1, "ein Wurf war es trotzdem")
    }

    func testDisabledReRackIsNotOffered() {
        var format = GameFormat()
        format.reRacksAllowed = false

        var state = play([.hitCup(index: 0), .miss], from: newGame(format), format: format)
        state = play([.miss, .miss], from: state, format: format)   // zurueck zu Team 0

        XCTAssertFalse(GameEngine.canReRack(in: state, format: format))

        guard let formation = GameEngine.availableFormations(in: state).first else {
            return XCTFail("für dieses Rack gibt es keine Formation")
        }
        XCTAssertEqual(
            play([.reRack(formation)], from: state, format: format), state,
            "ohne Umstellen darf die Aktion nichts veraendern"
        )
    }

    // MARK: - Zusammenfassung im Neues-Spiel-Screen

    func testStandardRulesetHasNoDeviations() {
        XCTAssertTrue(GameFormat().isStandardRuleset)
        XCTAssertTrue(GameFormat().ruleDeviations.isEmpty)
    }

    /// Die Becherzahl ist eine kuerzere Partie, keine andere Regel.
    func testCupCountIsNotARuleDeviation() {
        XCTAssertTrue(GameFormat(cupCount: 6).isStandardRuleset)
    }

    func testDeviationsNameEverySwitchedOffRule() {
        var format = GameFormat()
        format.redemptionAllowed = false
        format.bounceShotsAllowed = false

        XCTAssertFalse(format.isStandardRuleset)
        XCTAssertEqual(Set(format.ruleDeviations), ["Ohne Redemption", "Ohne Bounce"])
    }

    func testThresholdIsOnlyMentionedWhileOnFireApplies() {
        var format = GameFormat()
        format.onFireStreakThreshold = 5
        XCTAssertEqual(format.ruleDeviations, ["On Fire ab 5"])

        format.onFireEnabled = false
        XCTAssertEqual(
            format.ruleDeviations, ["Ohne On Fire"],
            "eine Schwelle fuer eine abgeschaltete Regel gehoert nicht in die Zusammenfassung"
        )
    }

    // MARK: - Speicher

    func testHouseRulesSurviveButTheHandicapDoesNot() {
        let vorher = UserDefaults.standard.data(forKey: GameFormat.houseRulesStorageKey)
        defer {
            // Der Test laeuft im Simulator gegen die echten UserDefaults der
            // App – was er dort hinterlaesst, faende die naechste Sitzung vor.
            if let vorher {
                UserDefaults.standard.set(vorher, forKey: GameFormat.houseRulesStorageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: GameFormat.houseRulesStorageKey)
            }
        }

        var format = GameFormat(cupCount: 6)
        format.trickshotsAllowed = false
        format.handicapByTeam = [2, 0]

        GameFormat.houseRules = format

        let geladen = GameFormat.houseRules
        XCTAssertEqual(geladen.cupCount, 6)
        XCTAssertFalse(geladen.trickshotsAllowed)
        XCTAssertNil(geladen.handicapByTeam, "der Vorsprung gehoert zur Aufstellung, nicht an den Tisch")
    }

    // MARK: - Sicherung

    func testBackupCarriesTheRules() throws {
        var format = GameFormat(cupCount: 6)
        format.redemptionAllowed = false
        format.onFireStreakThreshold = 4
        format.handicapByTeam = [0, 3]

        let spiel = ExportedGame(
            id: "g1",
            type: GameType.twoVsTwo.rawValue,
            status: GameStatus.finished.rawValue,
            createdBy: "u1",
            createdAt: nil,
            startedAt: nil,
            endedAt: nil,
            winnerTeamId: nil,
            teams: [],
            cupCount: format.cupCount,
            rules: ExportedRules(format: format),
            throwLog: []
        )

        let data = try JSONEncoder().encode(spiel)
        let zurueck = try JSONDecoder().decode(ExportedGame.self, from: data)

        XCTAssertEqual(zurueck.gameFormat, format, "der Log wird sonst unter anderen Regeln nachgespielt")
    }

    /// Sicherungen aus der Zeit vor den Hausregeln haben den Abschnitt nicht –
    /// sie muessen sich trotzdem einlesen lassen.
    func testOlderBackupWithoutRulesStillLoads() throws {
        let json = """
        {
          "id": "g1",
          "type": "twoVsTwo",
          "status": "finished",
          "createdBy": "u1",
          "teams": [],
          "cupCount": 6,
          "throwLog": []
        }
        """

        let spiel = try JSONDecoder().decode(ExportedGame.self, from: Data(json.utf8))

        XCTAssertNil(spiel.rules)
        XCTAssertEqual(spiel.gameFormat, GameFormat(cupCount: 6), "ohne Abschnitt gilt der Standard")
    }
}
