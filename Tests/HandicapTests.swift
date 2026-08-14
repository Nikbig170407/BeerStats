//
//  HandicapTests.swift
//  BeerStatsTests
//
//  Prueft den fairen Anwurf.
//
//  Der wichtigste Test hier ist `testReplayReachesTheSameStart`. Der
//  Vorsprung steht im GameFormat und nirgendwo sonst, weil der
//  nachgespielte Anfangszustand allein daraus entsteht. Laege er woanders,
//  startete die nachgespielte Partie mit vollen Racks - und Live-Stand und
//  Historie liefen auseinander, ohne dass es jemandem auffiele. Genau diese
//  Sorte Fehler hat in diesem Projekt schon einmal wochenlang unbemerkt
//  ueberlebt.
//
//  Der zweite Schwerpunkt ist die Absicherung nach unten: Ein Vorsprung von
//  der vollen Rackgroesse wuerde ein Team mit null Bechern starten lassen,
//  also mit einer bereits verlorenen Partie.
//

import XCTest
@testable import BeerStats

final class HandicapTests: XCTestCase {

    private func format(_ handicap: [Int]?, cups: Int = 10) -> GameFormat {
        GameFormat(cupCount: cups, handicapByTeam: handicap)
    }

    // MARK: - Das Format

    func testWithoutAHandicapBothTeamsStartFull() {
        let state = GameEngine.makeInitialState(format: format(nil), playersPerTeam: 2)
        XCTAssertEqual(state.racks[0].remainingCount, 10)
        XCTAssertEqual(state.racks[1].remainingCount, 10)
    }

    func testHandicapRemovesCupsFromTheRightTeam() {
        let state = GameEngine.makeInitialState(format: format([2, 0]), playersPerTeam: 2)
        XCTAssertEqual(state.racks[0].remainingCount, 8, "das stärkere Team gibt ab")
        XCTAssertEqual(state.racks[1].remainingCount, 10, "das andere bleibt vollständig")
    }

    /// Der Aufbau bleibt ein Dreieck mit Luecken – es wird kein kleineres
    /// Rack gebaut. Sonst saehe eine Neun wie ein Klotz aus.
    func testTheRackKeepsItsShape() {
        let state = GameEngine.makeInitialState(format: format([3, 0]), playersPerTeam: 2)
        XCTAssertEqual(state.racks[0].totalSlots, 10, "die Plätze bleiben, nur die Becher fehlen")
        XCTAssertEqual(state.racks[0].remainingCount, 7)
    }

    // MARK: - Absicherung

    func testATeamNeverStartsWithoutCups() {
        // Zehn von zehn waere eine verlorene Partie vor dem ersten Ball.
        let state = GameEngine.makeInitialState(format: format([10, 0]), playersPerTeam: 2)
        XCTAssertGreaterThanOrEqual(state.racks[0].remainingCount, 1)
        XCTAssertFalse(state.isFinished, "die Partie darf nicht schon vorbei sein")
    }

    func testNegativeAndOversizedValuesAreIgnored() {
        XCTAssertEqual(format([-5, 0]).startingHandicap(for: 0), 0)
        XCTAssertEqual(format([99, 0]).startingHandicap(for: 0), 9)
        XCTAssertEqual(format([1]).startingHandicap(for: 1), 0, "fehlender Eintrag heißt kein Vorsprung")
        XCTAssertEqual(format(nil).startingHandicap(for: 0), 0)
    }

    // MARK: - Nachspielen

    /// Der Kern: Aus demselben Format muss derselbe Anfangszustand entstehen,
    /// egal ob live oder aus dem Wurf-Log nachgespielt.
    func testReplayReachesTheSameStart() {
        let genutzt = format([2, 0])
        let repository = ThrowRepository(throwService: NullThrowService())

        let live = GameEngine.makeInitialState(format: genutzt, playersPerTeam: 2)
        let nachgespielt = repository.replay([], format: genutzt, playersPerTeam: 2)

        XCTAssertEqual(live.racks[0].remainingCount, nachgespielt.racks[0].remainingCount)
        XCTAssertEqual(live.racks[1].remainingCount, nachgespielt.racks[1].remainingCount)
        XCTAssertEqual(live, nachgespielt, "Live-Stand und nachgespielter Stand müssen gleich sein")
    }

    // MARK: - Der Vorschlag

    func testNoSuggestionWithoutEnoughThrows() {
        // Ein Profil mit drei Wuerfen hat keine belastbare Quote.
        var schwach = UserStatistics()
        schwach.totalThrows = 3
        schwach.totalHits = 2
        XCTAssertLessThan(schwach.totalThrows, AppConstants.GameDefaults.minimumThrowsForHandicap)
    }

    func testHandicapIsCappedAtThreeCups() {
        // Selbst bei extremem Unterschied bleibt es bei hoechstens drei.
        let extrem = format([3, 0])
        XCTAssertEqual(extrem.startingHandicap(for: 0), 3)
    }
}

/// Wurf-Dienst ohne Firestore. Der Replay-Pfad braucht ein Repository, holt
/// hier aber nie etwas ab – geprueft wird der Anfangszustand.
private final class NullThrowService: ThrowServiceProtocol {
    func appendThrow(_ throwEvent: Throw, gameId: String) async throws {}
    func observeThrows(gameId: String) -> AsyncStream<[Throw]> {
        AsyncStream { $0.yield([]) }
    }
    func fetchThrows(gameId: String) async throws -> [Throw] { [] }
}
