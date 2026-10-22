//
//  EveningTrophyTests.swift
//  BeerStatsTests
//
//  Prueft die Siegerwertung des Abends.
//
//  Zwei Dinge gehen hier lautlos schief, und beide merkt am Tisch
//  niemand – man liest die Tabelle und glaubt ihr:
//
//  Ein Sieg im 2-gegen-2 zaehlt fuer EINE Person statt fuer zwei. Genau
//  das war der Zustand vor dem 22. Oktober: Der Sieger stand als Text
//  („Lena & Jan") in der Wertung, also gewann ein Name, den es nicht gibt.
//
//  Und die Gewichtung: Ohne sie gewinnt den Abend, wer am meisten
//  Reaktionsduell gespielt hat.
//

import XCTest
@testable import BeerStats

final class EveningTrophyTests: XCTestCase {

    private var abendVorher: Data?

    /// Die Tests schreiben in dieselben UserDefaults wie die App – sichern
    /// und zuruecklegen, sonst faende der naechste Lauf sie vor.
    override func setUp() {
        super.setUp()
        abendVorher = UserDefaults.standard.data(forKey: "evening.current")
        UserDefaults.standard.removeObject(forKey: "evening.current")
    }

    override func tearDown() {
        if let abendVorher {
            UserDefaults.standard.set(abendVorher, forKey: "evening.current")
        } else {
            UserDefaults.standard.removeObject(forKey: "evening.current")
        }
        super.tearDown()
    }

    private func person(_ id: String) -> EveningParticipant {
        EveningParticipant(id: id, name: id.capitalized, emoji: "🍺")
    }

    private func abend(_ ids: [String], _ eintraege: [EveningEntry]) -> Evening {
        Evening(
            startedAt: Date(),
            endedAt: nil,
            participants: ids.map(person),
            entries: eintraege
        )
    }

    private func sieg(_ gewinner: [String], punkte: Int, spiel: String = "spiel") -> EveningEntry {
        EveningEntry(
            id: UUID().uuidString,
            title: spiel,
            emoji: "🎲",
            at: Date(),
            winner: gewinner.joined(separator: " & "),
            gameId: spiel,
            winnerIds: gewinner,
            points: punkte
        )
    }

    // MARK: - Punkte

    func testAWinInALongGameIsWorthMoreThanAQuickOne() {
        XCTAssertEqual(PartyGame.Length.quick.points, 1)
        XCTAssertEqual(PartyGame.Length.round.points, 2)
        XCTAssertEqual(PartyGame.Length.long.points, 3)
    }

    /// Was nebenher laeuft, kennt keinen Sieger – und bringt deshalb nichts.
    func testWhatRunsAlongsideScoresNothing() {
        XCTAssertEqual(PartyGame.Length.alongside.points, 0)
    }

    /// Drei kurze Siege sind weniger wert als zwei lange.
    func testManyQuickWinsDoNotBeatTwoLongOnes() {
        let a = abend(["lena", "jan"], [
            sieg(["lena"], punkte: 1), sieg(["lena"], punkte: 1), sieg(["lena"], punkte: 1),
            sieg(["jan"], punkte: 3), sieg(["jan"], punkte: 3)
        ])
        XCTAssertEqual(a.trophyWinner?.participant.id, "jan")
        XCTAssertEqual(a.trophyBoard.first?.points, 6)
    }

    // MARK: - Teams

    /// Der Kern: Ein Sieg im 2-gegen-2 zaehlt fuer BEIDE.
    func testATeamWinCountsForEveryoneInIt() {
        let a = abend(["lena", "jan", "tim"], [sieg(["lena", "jan"], punkte: 3)])
        let wertung = Dictionary(uniqueKeysWithValues: a.trophyBoard.map { ($0.participant.id, $0.points) })

        XCTAssertEqual(wertung["lena"], 3)
        XCTAssertEqual(wertung["jan"], 3)
        XCTAssertEqual(wertung["tim"], 0)
    }

    // MARK: - Die Tabelle

    /// Wer nichts gewonnen hat, steht trotzdem drin – nur hinten.
    func testEverybodyStaysOnTheBoard() {
        let a = abend(["lena", "jan", "tim"], [sieg(["lena"], punkte: 2)])
        XCTAssertEqual(a.trophyBoard.count, 3)
        XCTAssertEqual(a.trophyBoard.first?.participant.id, "lena")
        XCTAssertEqual(a.trophyBoard.last?.points, 0)
    }

    /// Bei Punktgleichstand steht vorn, wer weniger Spiele dafuer brauchte.
    func testFewerGamesForTheSamePointsRanksHigher() {
        let a = abend(["lena", "jan"], [
            sieg(["lena"], punkte: 3),
            sieg(["jan"], punkte: 1), sieg(["jan"], punkte: 1), sieg(["jan"], punkte: 1)
        ])
        XCTAssertEqual(a.trophyBoard.first?.participant.id, "lena")
    }

    /// Gleichstand an der Spitze ist kein Sieg: Zwei Namen unter einem
    /// Pokal waeren am Tisch der Anfang einer Diskussion.
    func testADrawCrownsNobody() {
        let a = abend(["lena", "jan"], [sieg(["lena"], punkte: 2), sieg(["jan"], punkte: 2)])
        XCTAssertNil(a.trophyWinner)
        XCTAssertEqual(a.trophyBoard.count, 2)
    }

    func testWithoutAnyWinThereIsNoWinner() {
        XCTAssertNil(abend(["lena", "jan"], []).trophyWinner)
    }

    /// Abende von vorher haben keine Punkte. Sie duerfen die Wertung nicht
    /// verfaelschen – dieselbe Regel wie beim Sicherungsformat: Was ein
    /// altes Feld nicht hat, zaehlt als nicht vorhanden.
    func testOldEntriesWithoutPointsScoreNothing() {
        let alt = EveningEntry(
            id: "a", title: "Beerpong", emoji: "🍺", at: Date(), winner: "Lena"
        )
        let a = abend(["lena"], [alt])
        XCTAssertEqual(a.trophyBoard.first?.points, 0)
        XCTAssertNil(a.trophyWinner)
    }

    /// Der Sieger wird an den Eintrag gehaengt, der beim Betreten entstanden
    /// ist – kein zweiter Eintrag fuer dasselbe Spiel.
    func testTheWinnerIsAddedToTheExistingEntry() {
        EveningLog.current = abend(["p1", "p2"], [])

        EveningLog.record(partyGame: .timeline)
        EveningLog.recordWinner(positions: [1], for: .timeline)

        let gespielt = EveningLog.current
        XCTAssertEqual(gespielt?.entries.count, 1, "Es darf kein zweiter Eintrag entstehen.")
        XCTAssertEqual(gespielt?.entries.first?.winnerIds, ["p2"])
        XCTAssertEqual(gespielt?.entries.first?.points, PartyGame.Length.long.points)
        XCTAssertEqual(gespielt?.trophyWinner?.participant.id, "p2")
    }

    /// Ohne laufenden Abend tut das Nachtragen nichts – der Aufruf steht in
    /// den Spielen ohne Abfrage, also muss er folgenlos sein.
    func testWithoutAnEveningNothingIsRecorded() {
        EveningLog.current = nil
        EveningLog.recordWinner(positions: [0], for: .timeline)
        XCTAssertNil(EveningLog.current)
    }

    // MARK: - Von Hand eingetragen

    /// Der Weg fuer die Verlierer-Spiele: Schocken rechnet aus, wer alle
    /// Deckel hat – wer gewonnen hat, weiss nur der Tisch.
    func testAWinnerCanBeSetByHand() {
        EveningLog.current = abend(["p1", "p2"], [])
        EveningLog.record(partyGame: .schocken)
        let eintrag = EveningLog.current!.entries[0]

        EveningLog.setWinner(["p1"], forEntry: eintrag.id)

        let gespielt = EveningLog.current
        XCTAssertEqual(gespielt?.entries.first?.winnerIds, ["p1"])
        // Schocken ist ein mittleres Spiel – zwei Punkte.
        XCTAssertEqual(gespielt?.entries.first?.points, PartyGame.Length.round.points)
        XCTAssertEqual(gespielt?.trophyWinner?.participant.id, "p1")
    }

    func testTwoPeopleCanWinTogether() {
        EveningLog.current = abend(["p1", "p2", "p3"], [])
        EveningLog.record(partyGame: .categories)
        EveningLog.setWinner(["p1", "p2"], forEntry: EveningLog.current!.entries[0].id)

        let wertung = EveningLog.current!.trophyBoard
        XCTAssertEqual(wertung.first(where: { $0.participant.id == "p1" })?.points, 2)
        XCTAssertEqual(wertung.first(where: { $0.participant.id == "p2" })?.points, 2)
        XCTAssertEqual(wertung.first(where: { $0.participant.id == "p3" })?.points, 0)
    }

    /// Vertippt ist am Tisch die Regel, nicht die Ausnahme – der Sieger muss
    /// sich genauso einfach zuruecknehmen lassen wie eintragen.
    func testAWinnerCanBeTakenBack() {
        EveningLog.current = abend(["p1"], [])
        EveningLog.record(partyGame: .schocken)
        let id = EveningLog.current!.entries[0].id

        EveningLog.setWinner(["p1"], forEntry: id)
        EveningLog.setWinner([], forEntry: id)

        XCTAssertNil(EveningLog.current?.entries.first?.winnerIds)
        XCTAssertNil(EveningLog.current?.entries.first?.points)
        XCTAssertNil(EveningLog.current?.trophyWinner)
    }

    /// Eine Position, die es am Tisch nicht gibt, darf nichts buchen.
    func testAPositionOutsideTheTableIsIgnored() {
        EveningLog.current = abend(["p1"], [])
        EveningLog.record(partyGame: .timeline)
        EveningLog.recordWinner(positions: [7], for: .timeline)

        XCTAssertNil(EveningLog.current?.entries.first?.winnerIds)
    }
}
