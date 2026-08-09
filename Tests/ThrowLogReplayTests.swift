//
//  ThrowLogReplayTests.swift
//  BeerStatsTests
//
//  Prueft die Grundannahme, auf der die ganze Geraete-Synchronisation ruht:
//  Wer den Wurf-Log nachspielt, muss auf exakt denselben Spielstand kommen
//  wie das Geraet, das ihn geschrieben hat.
//
//  Diese Annahme war dreimal verletzt, und jedes Mal hat es Tage gekostet,
//  das zu finden – der Bounce, der beim Nachspielen zum normalen Treffer
//  wurde; die Bombe, die ein gleichzeitiges On Fire verschluckt hat; und die
//  laufenden Nummern, durch die sich eine Becher-Auswahl vor die Aktion
//  schieben konnte, die sie ueberhaupt erst erzeugt hat.
//
//  Deshalb wird hier nicht ein einzelner Fall geprueft, sondern gespielt:
//  achtzig zufaellige Partien, jede mit Bounce, Bombe, Umstellen, Rebound
//  und Airball. Der Zufall ist ausgesaet, damit ein Fehlschlag reproduzierbar
//  bleibt – die Seed-Nummer steht in der Fehlermeldung.
//

import XCTest
@testable import BeerStats

final class ThrowLogReplayTests: XCTestCase {

    private let format = GameFormat()
    private let teams = [
        Team(id: "t0", playerIds: ["p0", "p1"], playerNames: ["Anna", "Ben"], ballsInPlay: 2),
        Team(id: "t1", playerIds: ["p2", "p3"], playerNames: ["Cem", "Dana"], ballsInPlay: 2)
    ]

    func testReplayedLogMatchesTheLivePlay() async throws {
        for seed in 1...80 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let service = RecordingThrowService()
            let repository = ThrowRepository(throwService: service)

            var live = GameEngine.makeInitialState(format: format, playersPerTeam: 2)
            var steps = 0

            while !live.isFinished, steps < 160 {
                steps += 1
                guard let action = nextAction(for: live, using: &rng) else { break }

                let before = live
                let after = GameEngine.apply(action, to: before, format: format).state
                guard after != before else { continue }   // war nicht erlaubt
                live = after

                if action.isPersistable {
                    try await repository.record(
                        action: action,
                        by: before.currentThrower,
                        before: before,
                        after: after,
                        gameId: "spiel",
                        teams: teams
                    )
                }
            }

            let replayed = repository.replay(service.entries, format: format, playersPerTeam: 2)

            // Der Bounce-Schalter steht bewusst nicht im Log – er ist reine
            // Bedienung und wird beim Nachspielen vom laufenden Geraet
            // uebernommen. Fuer den Vergleich zaehlt er deshalb nicht.
            var expected = live
            expected.bounceArmed = false

            XCTAssertEqual(
                replayed, expected,
                "Seed \(seed): nachgespielter Stand weicht nach \(service.entries.count) Einträgen ab"
            )
        }
    }

    /// Ohne eindeutige Reihenfolge im Log ist Nachspielen Gluecksache.
    func testSequenceNumbersAreUniqueAndAscending() async throws {
        var rng = SeededGenerator(seed: 4711)
        let service = RecordingThrowService()
        let repository = ThrowRepository(throwService: service)

        var live = GameEngine.makeInitialState(format: format, playersPerTeam: 2)
        var steps = 0

        while !live.isFinished, steps < 160 {
            steps += 1
            guard let action = nextAction(for: live, using: &rng) else { break }
            let before = live
            let after = GameEngine.apply(action, to: before, format: format).state
            guard after != before else { continue }
            live = after
            if action.isPersistable {
                try await repository.record(
                    action: action, by: before.currentThrower,
                    before: before, after: after, gameId: "spiel", teams: teams
                )
            }
        }

        let numbers = service.entries.map(\.sequenceNumber)
        XCTAssertFalse(numbers.isEmpty, "der Testlauf hat gar nichts aufgezeichnet")
        XCTAssertEqual(numbers, numbers.sorted(), "die Nummern müssen aufsteigen")
        XCTAssertEqual(Set(numbers).count, numbers.count, "keine Nummer darf doppelt vorkommen")
    }

    // MARK: - Zufallszug

    /// Waehlt eine im aktuellen Zustand sinnvolle Aktion. Die Gewichte sind so
    /// gesetzt, dass die Sonderregeln haeufig genug vorkommen, um etwas zu
    /// pruefen – bei realistischen Wahrscheinlichkeiten kaeme in achtzig
    /// Partien kaum eine Bombe vor.
    private func nextAction(for state: LiveGameState, using rng: inout SeededGenerator) -> GameAction? {
        if let choice = state.pendingChoice {
            guard let cup = aliveCups(in: state, rack: choice.rackTeamIndex).randomElement(using: &rng) else {
                return nil
            }
            return .chooseCup(index: cup)
        }

        let roll = Int.random(in: 0..<100, using: &rng)

        if roll < 6, GameEngine.canReRack(in: state, format: format),
           let formation = GameEngine.availableFormations(in: state).randomElement(using: &rng) {
            return .reRack(formation)
        }
        if roll < 14, GameEngine.canDeclareBombe(in: state) { return .bombe }
        if roll < 26, !state.bounceArmed, GameEngine.canArmBounce(in: state, format: format) {
            return .toggleBounce
        }
        if roll < 34 { return .airball }
        if roll < 44, GameEngine.canRebound(in: state, format: format) { return .rebound }
        if roll < 62 { return .miss }

        guard let cup = aliveCups(in: state, rack: state.targetRackIndex).randomElement(using: &rng) else {
            return .miss
        }
        return .hitCup(index: cup)
    }

    private func aliveCups(in state: LiveGameState, rack: Int) -> [Int] {
        (0..<state.racks[rack].totalSlots).filter { state.racks[rack].isAlive(at: $0) }
    }
}

// MARK: - Hilfsmittel

/// Sammelt die Eintraege im Speicher, statt sie nach Firestore zu schreiben.
private final class RecordingThrowService: ThrowServiceProtocol {

    private(set) var entries: [Throw] = []

    func appendThrow(_ throwEvent: Throw, gameId: String) async throws {
        entries.append(throwEvent)
    }

    func observeThrows(gameId: String) -> AsyncStream<[Throw]> {
        AsyncStream { $0.finish() }
    }

    func fetchThrows(gameId: String) async throws -> [Throw] {
        entries
    }
}

/// Ausgesaeter Zufall, damit ein Fehlschlag wiederholbar ist. Mit
/// `SystemRandomNumberGenerator` waere ein seltener Fall einmal rot und beim
/// naechsten Lauf wieder gruen – und damit unauffindbar.
private struct SeededGenerator: RandomNumberGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
