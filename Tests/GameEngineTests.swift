//
//  GameEngineTests.swift
//  BeerStatsTests
//
//  Prueft das Beerpong-Regelwerk ohne Firebase, ohne UI, ohne Geraet.
//
//  Jeder Test hier haette einen Fehler abgefangen, der es tatsaechlich aufs
//  Handy geschafft hat – die Bombe, die ein gleichzeitiges On Fire
//  verschluckt hat, und die laufenden Nummern, die Auswahl und Umstellen
//  nicht hochgezaehlt haben. Beides waren reine Zustandsfehler und in drei
//  Zeilen nachstellbar. Genau dafuer ist die Engine eine reine Funktion.
//

import XCTest
@testable import BeerStats

final class GameEngineTests: XCTestCase {

    private let format = GameFormat()

    /// Wendet mehrere Aktionen nacheinander an. Spart in jedem Test vier
    /// Zeilen Rauschen.
    private func play(_ actions: [GameAction], from state: LiveGameState) -> LiveGameState {
        actions.reduce(state) { GameEngine.apply($1, to: $0, format: format).state }
    }

    private func newGame(playersPerTeam: Int = 2) -> LiveGameState {
        GameEngine.makeInitialState(format: format, playersPerTeam: playersPerTeam)
    }

    // MARK: - Grundlagen

    func testInitialState() {
        let state = newGame()
        XCTAssertEqual(state.racks[0].remainingCount, format.cupCount)
        XCTAssertEqual(state.racks[1].remainingCount, format.cupCount)
        XCTAssertEqual(state.turnTeamIndex, 0)
        XCTAssertEqual(state.currentBallIndex, 0)
        XCTAssertEqual(state.ballsPerTurn, 2)
        XCTAssertNil(state.pendingChoice)
    }

    func testHitRemovesCupAndAdvancesBall() {
        let state = play([.hitCup(index: 0)], from: newGame())
        XCTAssertFalse(state.racks[1].isAlive(at: 0))
        XCTAssertEqual(state.currentBallIndex, 1)
        XCTAssertEqual(state.turnTeamIndex, 0)
    }

    func testTwoMissesEndTheTurn() {
        let state = play([.miss, .miss], from: newGame())
        XCTAssertEqual(state.turnTeamIndex, 1)
        XCTAssertEqual(state.currentBallIndex, 0)
    }

    /// Treffen beide Baelle eines Zuges, wirft dasselbe Team erneut.
    func testBothBallsHitGivesBallsBack() {
        let state = play([.hitCup(index: 0), .hitCup(index: 1)], from: newGame())
        XCTAssertEqual(state.turnTeamIndex, 0, "Balls Back muss den Zug beim Team lassen")
        XCTAssertEqual(state.currentBallIndex, 0)
    }

    /// Im 1 gegen 1 wirft dieselbe Person beide Baelle – die Sonderregeln
    /// muessen trotzdem greifen.
    func testSinglePlayerStillThrowsTwoBalls() {
        let state = newGame(playersPerTeam: 1)
        XCTAssertEqual(state.ballsPerTurn, 2)
        XCTAssertEqual(state.playerSlot(forBall: 1), 0)

        let after = play([.hitCup(index: 0), .hitCup(index: 1)], from: state)
        XCTAssertEqual(after.turnTeamIndex, 0, "Balls Back gilt auch im 1 gegen 1")
    }

    // MARK: - On Fire

    func testThirdHitInARowKeepsTheBall() {
        // Zweimal Balls Back, damit Spieler 0 dreimal drankommt.
        let state = play(
            [.hitCup(index: 0), .hitCup(index: 1),
             .hitCup(index: 2), .hitCup(index: 3),
             .hitCup(index: 4)],
            from: newGame()
        )
        XCTAssertTrue(state.onFire[0][0])
        XCTAssertEqual(state.pending, .onFireBonus)
        XCTAssertEqual(state.currentThrower, PlayerRef(teamIndex: 0, slot: 0))
    }

    // MARK: - Erzwungene Becher-Auswahl

    func testBounceLetsTheOtherTeamPickASecondCup() {
        let state = play([.toggleBounce, .hitCup(index: 0)], from: newGame())
        guard let choice = state.pendingChoice else {
            return XCTFail("nach einem Bounce muss eine Auswahl anstehen")
        }
        XCTAssertEqual(choice.rackTeamIndex, 1, "gewaehlt wird aus dem beschossenen Rack")
        XCTAssertEqual(choice.remaining, 1)
    }

    func testChoiceResolvesAndTurnContinues() {
        let state = play([.toggleBounce, .hitCup(index: 0), .chooseCup(index: 5)], from: newGame())
        XCTAssertNil(state.pendingChoice)
        XCTAssertFalse(state.racks[1].isAlive(at: 5))
        XCTAssertEqual(state.currentBallIndex, 1, "nach der Auswahl geht der Zug weiter")
    }

    func testBombeAsksForTwoMoreCups() {
        let state = play([.hitCup(index: 0), .bombe], from: newGame())
        XCTAssertEqual(state.pendingChoice?.remaining, 2)
        XCTAssertEqual(state.pendingChoice?.rackTeamIndex, 1)
    }

    /// Rueckfall-Test: Loeste ausgerechnet der Bomben-Treffer die On-Fire-Serie
    /// aus, behielt der Werfer den Ball und der Zugabschluss wurde
    /// uebersprungen – damit fiel die ganze Bombe aus, samt Auswahl.
    func testBombeSurvivesSimultaneousOnFire() {
        // Zwei volle Durchgaenge bringen beide Spieler auf Serie 2 …
        var state = play(
            [.hitCup(index: 0), .hitCup(index: 1),
             .hitCup(index: 2), .hitCup(index: 3)],
            from: newGame()
        )
        // … der naechste Treffer und die Bombe sind dann jeweils der dritte.
        state = play([.hitCup(index: 4), .bombe], from: state)

        XCTAssertNotNil(state.pendingChoice, "die Bombe darf nicht von On Fire verschluckt werden")
        XCTAssertEqual(state.pendingChoice?.remaining, 2)
    }

    func testBombeNeedsAHitFromTheFirstBall() {
        let missedFirst = play([.miss], from: newGame())
        XCTAssertFalse(GameEngine.canDeclareBombe(in: missedFirst))

        let hitFirst = play([.hitCup(index: 0)], from: newGame())
        XCTAssertTrue(GameEngine.canDeclareBombe(in: hitFirst))
    }

    // MARK: - Umstellen

    func testReRackOnlyOncePerTeam() {
        var state = play([.hitCup(index: 0), .miss], from: newGame())   // Team 1 ist dran
        state = play([.miss, .miss], from: state)                        // zurueck zu Team 0

        guard let formation = GameEngine.availableFormations(in: state).first else {
            return XCTFail("für dieses Rack gibt es keine Formation")
        }

        state = play([.reRack(formation)], from: state)
        XCTAssertTrue(state.reRackUsed[state.turnTeamIndex])
        XCTAssertFalse(GameEngine.canReRack(in: state, format: format))
    }

    // MARK: - Laufende Nummern

    /// Rueckfall-Test: Auswahl und Umstellen haben die laufende Nummer nicht
    /// hochgezaehlt. Weil `sorted(by:)` in Swift nicht stabil ist, konnte eine
    /// `chooseCup` beim Nachspielen vor die Aktion rutschen, die sie erzeugt
    /// hat – und das Spiel blieb in einer Auswahl haengen, die nie fertig wurde.
    func testEveryLoggedActionIncrementsTheSequenceNumber() {
        var state = newGame()

        let actions: [GameAction] = [
            .toggleBounce,               // wird bewusst NICHT gezaehlt
            .hitCup(index: 0),
            .chooseCup(index: 1),
            .miss,
            .airball,
            .hitCup(index: 2),
            .bombe,
            .chooseCup(index: 3),
            .chooseCup(index: 4)
        ]

        for action in actions {
            let before = state.sequenceNumber
            state = GameEngine.apply(action, to: state, format: format).state

            if action.isPersistable {
                XCTAssertEqual(
                    state.sequenceNumber, before + 1,
                    "\(action) landet im Log und braucht eine eigene Nummer"
                )
            } else {
                XCTAssertEqual(state.sequenceNumber, before, "\(action) gehört nicht in den Log")
            }
        }
    }

    // MARK: - Spielende

    func testClearingTheRackStartsRedemption() {
        var state = newGame()
        // Team 0 raeumt das gegnerische Rack ab. Nach jedem zweiten Treffer
        // greift Balls Back, das Team bleibt also am Zug.
        for cup in 0..<format.cupCount {
            state = play([.hitCup(index: cup)], from: state)
        }
        XCTAssertEqual(state.phase, .redemption)
        XCTAssertEqual(state.turnTeamIndex, 1, "das unterlegene Team wirft nach")
    }
}
