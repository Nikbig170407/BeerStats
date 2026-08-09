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
        // Der Fall ist enger, als er aussieht: Der ZWEITE Werfer muss die
        // Serie haben, nicht der erste. Wäre der erste auf zwei Treffern,
        // ginge er beim dritten selbst On Fire, behielte den Ball – und es
        // käme nie zu einem zweiten Ball, auf dem eine Bombe möglich wäre.
        let state = play(
            [
                .hitCup(index: 0),      // Spieler 1 trifft
                .hitCup(index: 1),      // Spieler 2 trifft → Balls Back, beide Serie 1
                .miss,                  // Spieler 1 daneben, seine Serie fällt auf 0
                .hitCup(index: 2),      // Spieler 2 trifft → Serie 2, Zug endet
                .miss, .miss,           // Team 2 verfehlt zweimal
                .hitCup(index: 3)       // Spieler 1 trifft, jetzt ist Ball 2 dran
            ],
            from: newGame()
        )
        XCTAssertTrue(GameEngine.canDeclareBombe(in: state), "Aufbau stimmt nicht")

        // Dieser Wurf ist gleichzeitig Bombe UND dritter Treffer in Folge.
        let after = play([.bombe], from: state)

        XCTAssertNotNil(after.pendingChoice, "die Bombe darf nicht von On Fire verschluckt werden")
        XCTAssertEqual(after.pendingChoice?.remaining, 2)
        XCTAssertTrue(after.onFire[0][1], "die Serie zählt trotzdem weiter")
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

        // Die Reihenfolge ist kein Zufall: Nach zwei Fehlwürfen wechselt der
        // Zug, und eine Bombe wäre dann gar nicht erlaubt – sie bliebe
        // wirkungslos, und die Nummer dürfte zu Recht nicht steigen.
        let actions: [GameAction] = [
            .toggleBounce,          // reine Bedienung, gehört nicht in den Log
            .hitCup(index: 0),      // Bounce-Treffer, Auswahl steht an
            .chooseCup(index: 1),
            .miss,                  // Zug endet, Team 2 ist dran
            .airball,
            .miss,                  // Zug endet, Team 1 ist wieder dran
            .hitCup(index: 2),      // erster Ball trifft
            .bombe,                 // zweiter Ball, jetzt erlaubt
            .chooseCup(index: 3),
            .chooseCup(index: 4)
        ]

        for action in actions {
            let before = state.sequenceNumber
            let next = GameEngine.apply(action, to: state, format: format).state

            // Eine Aktion, die nichts bewirkt, darf auch nichts hochzählen –
            // sonst prüft der Test nur, dass irgendetwas passiert ist.
            XCTAssertNotEqual(next, state, "\(action) war im Aufbau nicht erlaubt")
            state = next

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
