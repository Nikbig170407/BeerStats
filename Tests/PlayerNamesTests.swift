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
        TableRoster.remember([
            profil("Lena", "🔥", id: "p1"),
            profil("Jan", "🐢", id: "p2")
        ])
        EveningLog.start(with: [profil("Marcel", "🦊", id: "p9")])

        defer { EveningLog.current = nil }

        XCTAssertEqual(PlayerNames.name(for: 0), "🦊 Marcel")
        XCTAssertEqual(PlayerNames.suggestedCount(), 1, "die Teilnehmerzahl kommt vom Abend")
    }

    /// Ist der Abend vorbei, uebernimmt wieder der Tisch.
    func testAFinishedEveningFallsBackToTheTable() {
        TableRoster.remember([profil("Lena", "🔥", id: "p1")])
        EveningLog.start(with: [profil("Marcel", "🦊", id: "p9")])
        EveningLog.current = nil

        XCTAssertEqual(PlayerNames.name(for: 0), "🔥 Lena")
    }
}
