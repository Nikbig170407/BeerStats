//
//  PlayerNamesTests.swift
//  BeerStatsTests
//
//  Prueft, aus welcher Quelle ein Partyspiel seine Namen nimmt.
//
//  Die Reihenfolge ist nicht beliebig: Laeuft ein Abend, gelten SEINE
//  Teilnehmer, weil die Trinkbilanz auf deren Positionen gebucht ist. Kaeme
//  der Name von woanders, hiesse Position 3 im Spiel jemand anderes als
//  Position 3 in der Bilanz - und die Bilanz waere falsch, ohne dass es
//  jemandem auffiele. Genau dieser Fall steht unten als Test.
//

import XCTest
@testable import BeerStats

final class PlayerNamesTests: XCTestCase {

    private var abendVorher: Data?
    private var tischVorher: Data?

    /// Die Tests schreiben in dieselben UserDefaults wie die App. Im
    /// Simulator ist das folgenlos, aber was sie hinterlassen, faende der
    /// naechste Lauf vor - deshalb sichern und zuruecklegen.
    override func setUp() {
        super.setUp()
        abendVorher = UserDefaults.standard.data(forKey: "evening.current")
        tischVorher = UserDefaults.standard.data(forKey: TableRoster.seatsStorageKey)
        UserDefaults.standard.removeObject(forKey: "evening.current")
        UserDefaults.standard.removeObject(forKey: TableRoster.seatsStorageKey)
    }

    override func tearDown() {
        restore(abendVorher, forKey: "evening.current")
        restore(tischVorher, forKey: TableRoster.seatsStorageKey)
        super.tearDown()
    }

    // MARK: - Reihum

    /// Der Zaehler der Spiele laeuft hoch und hoert nie auf; wer dran ist,
    /// ergibt sich daraus modulo der Leute. Ohne Leute gibt es keine
    /// Antwort – und dann gehoert die Zeile weggelassen, nicht mit
    /// "Spieler 1" gefuellt.
    func testTheTurnWrapsAroundTheTable() {
        TableRoster.remember([
            profil("Lena", "🔥", id: "p1"),
            profil("Jan", "🐢", id: "p2"),
            profil("Tim", "🐙", id: "p3")
        ])

        XCTAssertEqual(PlayerNames.nameForTurn(0), PlayerNames.name(for: 0))
        XCTAssertEqual(PlayerNames.nameForTurn(3), PlayerNames.name(for: 0))
        XCTAssertEqual(PlayerNames.nameForTurn(4), PlayerNames.name(for: 1))
        XCTAssertEqual(PlayerNames.nameForTurn(100), PlayerNames.name(for: 1))
    }

    func testWithoutAnybodyThereIsNoTurn() {
        XCTAssertNil(PlayerNames.nameForTurn(0))
        XCTAssertNil(PlayerNames.nameForTurn(7))
        XCTAssertFalse(PlayerNames.knowsNames)
    }

    /// Kommt jemand dazu, laeuft der Rest reihum weiter – ohne dass ein
    /// Spiel seinen Zaehler anfassen muesste.
    func testSomebodyJoiningShiftsTheRestAlong() {
        TableRoster.remember([
            profil("Lena", "🔥", id: "p1"),
            profil("Jan", "🐢", id: "p2")
        ])
        XCTAssertEqual(PlayerNames.nameForTurn(2), PlayerNames.name(for: 0))

        TableRoster.remember([
            profil("Lena", "🔥", id: "p1"),
            profil("Jan", "🐢", id: "p2"),
            profil("Tim", "🐙", id: "p3")
        ])
        XCTAssertEqual(PlayerNames.nameForTurn(2), PlayerNames.name(for: 2))
    }

    private func restore(_ data: Data?, forKey key: String) {
        if let data {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func profil(_ name: String, _ emoji: String, id: String) -> PlayerProfile {
        PlayerProfile(id: id, name: name, emoji: emoji, color: .amber)
    }

    // MARK: - Ohne alles

    func testWithoutAnythingThePositionIsTheName() {
        XCTAssertEqual(PlayerNames.name(for: 2), "Spieler 3")
        XCTAssertEqual(PlayerNames.plainName(for: 0), "Spieler 1")
        XCTAssertNil(PlayerNames.suggestedCount())
    }

    // MARK: - Tisch

    func testTheTableSuppliesNames() {
        TableRoster.remember([
            profil("Lena", "🔥", id: "p1"),
            profil("Jan", "🐢", id: "p2")
        ])

        XCTAssertEqual(PlayerNames.name(for: 0), "🔥 Lena")
        XCTAssertEqual(PlayerNames.plainName(for: 1), "Jan")
        XCTAssertEqual(PlayerNames.suggestedCount(), 2)
    }

    /// Mehr Spieler als Leute am Tisch: Die ueberzaehligen behalten ihre
    /// Nummer, statt dass die Liste von vorne anfaengt.
    func testPositionsBeyondTheTableKeepTheirNumber() {
        TableRoster.remember([profil("Lena", "🔥", id: "p1")])

        XCTAssertEqual(PlayerNames.name(for: 0), "🔥 Lena")
        XCTAssertEqual(PlayerNames.name(for: 3), "Spieler 4")
    }

    /// Der Spion braucht drei Leute. Sind nur zwei da, darf er die
    /// Spielerzahl nicht uebernehmen - sonst startete er unterhalb seines
    /// eigenen Mindestwerts.
    func testSuggestedCountRespectsTheMinimum() {
        TableRoster.remember([
            profil("Lena", "🔥", id: "p1"),
            profil("Jan", "🐢", id: "p2")
        ])

        XCTAssertEqual(PlayerNames.suggestedCount(atLeast: 2), 2)
        XCTAssertNil(PlayerNames.suggestedCount(atLeast: 3))
    }

    // MARK: - Abend schlaegt Tisch

    /// Der wichtigste Test der Datei: Laeuft ein Abend, zaehlen seine
    /// Positionen - sonst bucht die Trinkbilanz auf die falschen Leute.
    func testTheRunningEveningWins() {
        // Unterschiedlich viele Leute, damit die Zahl allein schon verraet,
        // aus welcher Quelle sie kommt.
        TableRoster.remember([
            profil("Lena", "🔥", id: "p1"),
            profil("Jan", "🐢", id: "p2")
        ])
        EveningLog.start(with: [
            profil("Marcel", "🦊", id: "p9"),
            profil("Sarah", "🦉", id: "p8"),
            profil("Tim", "🐙", id: "p7")
        ])

        defer { EveningLog.current = nil }

        XCTAssertEqual(PlayerNames.name(for: 0), "🦊 Marcel")
        XCTAssertEqual(PlayerNames.plainName(for: 2), "Tim")
        XCTAssertEqual(PlayerNames.suggestedCount(), 3, "die Teilnehmerzahl kommt vom Abend")
    }

    /// Ist der Abend vorbei, uebernimmt wieder der Tisch.
    func testAFinishedEveningFallsBackToTheTable() {
        TableRoster.remember([profil("Lena", "🔥", id: "p1")])
        EveningLog.start(with: [profil("Marcel", "🦊", id: "p9")])
        EveningLog.current = nil

        XCTAssertEqual(PlayerNames.name(for: 0), "🔥 Lena")
    }

    // MARK: - Abend und Tisch sind eine Liste (3. November)

    private func teilnehmer(_ id: String) -> EveningParticipant? {
        EveningLog.current?.participants.first { $0.id == id }
    }

    /// Wer waehrend des Abends an den Tisch kommt, ist im Abend – mit null –
    /// und wird in den Spielen aufgerufen.
    func testSomeoneNewAtTheTableJoinsTheRunningEvening() {
        EveningLog.start(with: [profil("Lena", "🔥", id: "p1"), profil("Jan", "🐢", id: "p2")])
        defer { EveningLog.current = nil }

        TableRoster.remember([
            profil("Lena", "🔥", id: "p1"),
            profil("Jan", "🐢", id: "p2"),
            profil("Tim", "🐙", id: "p3")
        ])

        XCTAssertEqual(teilnehmer("p3")?.weight, 0)
        XCTAssertEqual(PlayerNames.knownCount, 3)
        XCTAssertEqual(PlayerNames.plainName(for: 2), "Tim")
    }

    /// Wer geht, behaelt seine Bilanz, wird aber nicht mehr aufgerufen – und
    /// die Plaetze danach ruecken auf, fuer Name UND Buchung gleich.
    func testSomeoneWhoLeavesKeepsTheTallyButIsNoLongerCalled() {
        EveningLog.start(with: [
            profil("Lena", "🔥", id: "p1"),
            profil("Jan", "🐢", id: "p2"),
            profil("Tim", "🐙", id: "p3")
        ])
        defer { EveningLog.current = nil }

        EveningLog.record(.sips(3), forPlayer: 1)
        let janVorher = teilnehmer("p2")?.weight ?? 0
        XCTAssertGreaterThan(janVorher, 0)

        TableRoster.remember([profil("Lena", "🔥", id: "p1"), profil("Tim", "🐙", id: "p3")])

        XCTAssertEqual(teilnehmer("p2")?.weight, janVorher, "Die Bilanz bleibt")
        XCTAssertEqual(teilnehmer("p2")?.isPresent, false)
        XCTAssertEqual(PlayerNames.knownCount, 2)
        XCTAssertEqual(PlayerNames.plainName(for: 1), "Tim")

        // Platz 1 heisst jetzt Tim – und dorthin geht auch die Buchung
        EveningLog.record(.sips(2), forPlayer: 1)
        XCTAssertGreaterThan(teilnehmer("p3")?.weight ?? 0, 0)
        XCTAssertEqual(teilnehmer("p2")?.weight, janVorher)
    }

    /// Wer zurueckkommt, steht wieder auf seinem alten Platz.
    func testSomeoneWhoComesBackTakesTheOldSeat() {
        EveningLog.start(with: [
            profil("Lena", "🔥", id: "p1"),
            profil("Jan", "🐢", id: "p2"),
            profil("Tim", "🐙", id: "p3")
        ])
        defer { EveningLog.current = nil }

        TableRoster.remember([profil("Lena", "🔥", id: "p1"), profil("Tim", "🐙", id: "p3")])
        TableRoster.remember([
            profil("Lena", "🔥", id: "p1"),
            profil("Jan", "🐢", id: "p2"),
            profil("Tim", "🐙", id: "p3")
        ])

        XCTAssertEqual(teilnehmer("p2")?.isPresent, true)
        XCTAssertEqual(PlayerNames.plainName(for: 1), "Jan")
        XCTAssertEqual(EveningLog.current?.participants.count, 3, "Kein zweiter Jan")
    }

    /// Ein leerer Tisch heisst "Profile laden noch" oder "ohne Konto" – der
    /// Abend darf davon nicht leerlaufen.
    func testAnEmptyTableLeavesTheEveningAlone() {
        EveningLog.start(with: [profil("Lena", "🔥", id: "p1")])
        defer { EveningLog.current = nil }

        TableRoster.remember([])

        XCTAssertEqual(teilnehmer("p1")?.isPresent, true)
        XCTAssertEqual(PlayerNames.knownCount, 1)
    }

    /// Eine Umbenennung unter "Mitspieler" kommt im Abend an.
    func testARenameReachesTheEvening() {
        EveningLog.start(with: [profil("Lena", "🔥", id: "p1")])
        defer { EveningLog.current = nil }

        TableRoster.remember([profil("Helena", "🌸", id: "p1")])

        XCTAssertEqual(PlayerNames.name(for: 0), "🌸 Helena")
    }
}
