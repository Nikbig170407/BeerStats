//
//  TimeOfDayHitRateTests.swift
//  BeerStatsTests
//
//  Prueft die Trefferquote nach Tageszeit ohne Firebase.
//
//  Die Rechnung sieht harmlos aus und hat drei Stellen, an denen sie
//  lautlos falsch waere: zurueckgenommene Wuerfe, die trotzdem zaehlen;
//  Eintraege im Log, die gar keine Wuerfe sind; und ein Undo, das ueber die
//  Partiegrenze hinweg greift. Alle drei stehen hier.
//

import XCTest
@testable import BeerStats

final class TimeOfDayHitRateTests: XCTestCase {

    private let spieler = "p1"

    private func zeit(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 1
        components.hour = hour
        components.minute = 30
        return Calendar.current.date(from: components)!
    }

    private func wurf(
        _ action: GameAction,
        result: ThrowResult = .hit,
        player: String? = nil,
        hour: Int,
        sequence: Int
    ) -> Throw {
        var entry = Throw(
            playerId: player ?? spieler,
            teamId: "t0",
            targetTeamId: "t1",
            result: result,
            sequenceNumber: sequence,
            roundNumber: 1,
            action: action
        )
        entry.timestamp = zeit(hour: hour)
        return entry
    }

    private func undo(sequence: Int, hour: Int = 21) -> Throw {
        var entry = Throw(
            playerId: spieler,
            teamId: "t0",
            targetTeamId: "t1",
            result: .undo,
            sequenceNumber: sequence,
            roundNumber: 1
        )
        entry.timestamp = zeit(hour: hour)
        return entry
    }

    /// Genug Wuerfe, damit eine Quote ueberhaupt ausgewiesen wird.
    private func serie(hits: Int, misses: Int, hour: Int, from start: Int = 1) -> [Throw] {
        var entries: [Throw] = []
        var nummer = start
        for _ in 0..<hits {
            entries.append(wurf(.hitCup(index: 0), hour: hour, sequence: nummer))
            nummer += 1
        }
        for _ in 0..<misses {
            entries.append(wurf(.miss, result: .miss, hour: hour, sequence: nummer))
            nummer += 1
        }
        return entries
    }

    // MARK: - Einordnung

    func testThrowsLandInTheirFourHourSlot() {
        var auswertung = TimeOfDayHitRate()
        auswertung.add(gameLog: [
            wurf(.hitCup(index: 0), hour: 21, sequence: 1),
            wurf(.hitCup(index: 1), hour: 23, sequence: 2),
            wurf(.miss, result: .miss, hour: 1, sequence: 3)
        ], profileId: spieler)

        XCTAssertEqual(auswertung.slots.map(\.startHour), [0, 20])
        XCTAssertEqual(auswertung.slots.first { $0.startHour == 20 }?.attempts, 2)
        XCTAssertEqual(auswertung.slots.first { $0.startHour == 0 }?.attempts, 1)
    }

    func testSlotTitleNamesTheEndAsTwentyFour() {
        let slot = TimeSlotStats(startHour: 20, hits: 0, attempts: 0)
        XCTAssertEqual(slot.title, "20 – 24 Uhr")
    }

    // MARK: - Was zaehlt

    /// Becher auswaehlen und Umstellen stehen im Log, sind aber keine Wuerfe.
    func testOnlyThrowsCount() {
        var auswertung = TimeOfDayHitRate()
        auswertung.add(gameLog: [
            wurf(.hitCup(index: 0), hour: 21, sequence: 1),
            wurf(.chooseCup(index: 3), hour: 21, sequence: 2),
            wurf(.reRack(RackFormation(name: "Linie", rows: [3, 3])), hour: 21, sequence: 3)
        ], profileId: spieler)

        XCTAssertEqual(auswertung.totalAttempts, 1)
    }

    func testBombeCountsAsAHit() {
        var auswertung = TimeOfDayHitRate()
        auswertung.add(gameLog: [
            wurf(.bombe, hour: 21, sequence: 1),
            wurf(.miss, result: .miss, hour: 21, sequence: 2)
        ], profileId: spieler)

        XCTAssertEqual(auswertung.slots.first?.hits, 1)
        XCTAssertEqual(auswertung.slots.first?.attempts, 2)
    }

    func testOtherPlayersAreIgnored() {
        var auswertung = TimeOfDayHitRate()
        auswertung.add(gameLog: [
            wurf(.hitCup(index: 0), hour: 21, sequence: 1),
            wurf(.hitCup(index: 1), player: "jemand-anders", hour: 21, sequence: 2)
        ], profileId: spieler)

        XCTAssertEqual(auswertung.totalAttempts, 1)
    }

    /// Ohne Zeitstempel laesst sich ein Wurf keiner Uhrzeit zuordnen. Er
    /// faellt heraus, statt bei Mitternacht zu landen.
    func testThrowsWithoutATimestampAreSkipped() {
        var ohneZeit = Throw(
            playerId: spieler,
            teamId: "t0",
            targetTeamId: "t1",
            result: .hit,
            sequenceNumber: 1,
            roundNumber: 1,
            action: .hitCup(index: 0)
        )
        ohneZeit.timestamp = nil

        var auswertung = TimeOfDayHitRate()
        auswertung.add(gameLog: [ohneZeit], profileId: spieler)

        XCTAssertEqual(auswertung.totalAttempts, 0)
    }

    // MARK: - Ruecknahmen

    /// Ein Undo streicht den letzten Wurf – sonst stuenden Wuerfe in der
    /// Statistik, die am Tisch nie stattgefunden haben.
    func testUndoRemovesTheLastThrow() {
        var auswertung = TimeOfDayHitRate()
        auswertung.add(gameLog: [
            wurf(.hitCup(index: 0), hour: 21, sequence: 1),
            wurf(.hitCup(index: 1), hour: 21, sequence: 2),
            undo(sequence: 3)
        ], profileId: spieler)

        XCTAssertEqual(auswertung.totalAttempts, 1)
        XCTAssertEqual(auswertung.slots.first?.hits, 1)
    }

    /// Rueckfall-Test: Wuerden alle Logs aneinandergehaengt, koennte ein Undo
    /// am Anfang der zweiten Partie den letzten Wurf der ersten streichen.
    func testAnUndoCannotReachIntoThePreviousGame() {
        var auswertung = TimeOfDayHitRate()
        auswertung.add(gameLog: [wurf(.hitCup(index: 0), hour: 21, sequence: 1)], profileId: spieler)
        auswertung.add(gameLog: [undo(sequence: 1)], profileId: spieler)

        XCTAssertEqual(auswertung.totalAttempts, 1, "der Wurf der ersten Partie muss stehen bleiben")
    }

    // MARK: - Schwelle

    func testNoRateBelowTheThreshold() {
        var auswertung = TimeOfDayHitRate()
        auswertung.add(gameLog: serie(hits: 2, misses: 1, hour: 21), profileId: spieler)

        let slot = auswertung.slots.first
        XCTAssertEqual(slot?.attempts, 3)
        XCTAssertNil(slot?.hitRate, "drei Wuerfe sind keine Quote")
    }

    func testRateAppearsOnceThereAreEnoughThrows() {
        let genug = AppConstants.GameDefaults.minimumThrowsPerTimeSlot
        var auswertung = TimeOfDayHitRate()
        auswertung.add(gameLog: serie(hits: genug / 2, misses: genug - genug / 2, hour: 21), profileId: spieler)

        XCTAssertEqual(auswertung.slots.first?.hitRate, 0.5)
    }

    /// Leere Fenster tauchen nicht auf – ein Balken mit null Wuerfen sagt
    /// nichts ueber den Spieler.
    func testEmptySlotsAreNotListed() {
        var auswertung = TimeOfDayHitRate()
        auswertung.add(gameLog: [wurf(.hitCup(index: 0), hour: 21, sequence: 1)], profileId: spieler)

        XCTAssertEqual(auswertung.slots.count, 1)
    }
}
