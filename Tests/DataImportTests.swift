//
//  DataImportTests.swift
//  BeerStatsTests
//
//  Prueft die Uebersetzung der Profil-Kennungen beim Wiederherstellen.
//
//  Das ist die eine Stelle, an der ein Fehler nicht nur falsch anzeigt,
//  sondern Daten kostet: Wiederherstellen schreibt, und es ist nicht
//  umkehrbar. Bricht es mitten im Lauf ab, bleibt ein halb beschriebenes
//  Konto zurueck – und genau das passierte, solange die Uebersetzung
//  `compactMap` benutzte.
//
//  Der Fall ist nicht gesucht, sondern der Normalfall nach einem Jahr:
//  Jemand wird aus der Truppe geloescht, seine alten Partien bleiben. Die
//  Sicherung enthaelt dann die Partie, aber nicht das Profil – und das
//  verkuerzte Team wurde von `GameRepository.createGame` abgelehnt.
//

import XCTest
@testable import BeerStats

final class DataImportTests: XCTestCase {

    private func team(_ ids: [String], _ namen: [String]) -> ExportedTeam {
        ExportedTeam(id: "t1", playerIds: ids, playerNames: namen, score: 3)
    }

    /// Der eigentliche Fall: Ein Spieler wurde vor der Sicherung geloescht.
    /// Das Team muss trotzdem zwei Plaetze haben, sonst laesst sich die
    /// Partie nicht anlegen.
    func testAMissingProfileKeepsItsSeat() {
        let uebersetzt = DataImportService.remapped(
            team(["alt1", "geloescht"], ["Lena", "Jan"]),
            with: ["alt1": "neu1"]
        )

        XCTAssertEqual(uebersetzt.playerIds.count, 2, "Das Team hat einen Platz verloren")
        XCTAssertEqual(uebersetzt.playerIds, ["neu1", "geloescht"])
        XCTAssertEqual(uebersetzt.playerNames, ["Lena", "Jan"])
    }

    /// Die Reihenfolge ist keine Kosmetik: Der Platz in `playerIds` ist der
    /// Platz im Team, und `ThrowRepository` leitet daraus den Slot ab. Ein
    /// verschobener Platz bucht die Wuerfe auf die falsche Person.
    func testTheOrderSurvivesTheTranslation() {
        let uebersetzt = DataImportService.remapped(
            team(["a", "b", "c"], ["Erste", "Zweite", "Dritte"]),
            with: ["c": "neu_c", "a": "neu_a", "b": "neu_b"]
        )

        XCTAssertEqual(uebersetzt.playerIds, ["neu_a", "neu_b", "neu_c"])
    }

    /// Kennungen und Namen muessen gleich lang bleiben: Beide werden ueber
    /// denselben Platz gelesen.
    func testIdsAndNamesStayTheSameLength() {
        let uebersetzt = DataImportService.remapped(
            team(["x", "y"], ["Lena", "Jan"]),
            with: [:]
        )

        XCTAssertEqual(uebersetzt.playerIds.count, uebersetzt.playerNames.count)
    }

    /// Ohne Uebersetzungstabelle bleibt alles, wie es war – eine Partie ohne
    /// mitgesicherte Profile ist immer noch eine Partie.
    func testAnEmptyTableChangesNothing() {
        let original = team(["a", "b"], ["Lena", "Jan"])
        let uebersetzt = DataImportService.remapped(original, with: [:])

        XCTAssertEqual(uebersetzt.playerIds, original.playerIds)
        XCTAssertEqual(uebersetzt.id, original.id)
        XCTAssertEqual(uebersetzt.score, original.score)
        XCTAssertEqual(uebersetzt.ballsInPlay, original.playerIds.count)
    }

    // MARK: - Die Trinkbilanz als Satz

    /// Der Satz stand zweimal im Projekt und lief auseinander. Jetzt steht er
    /// einmal – und beide Aufrufstellen bekommen dieselben Zahlen, nur mit
    /// ihrem eigenen Trennzeichen.
    func testTheTallyReadsTheSameEverywhere() {
        var person = EveningParticipant(id: "p1", name: "Lena", emoji: "🔥")
        person.sips = 1
        person.shots = 2

        XCTAssertEqual(person.tallyText(separator: " · ", whenEmpty: "noch nichts"), "1 Schluck · 2 Shots")
        XCTAssertEqual(person.tallyText(separator: ", ", whenEmpty: "nichts"), "1 Schluck, 2 Shots")
    }

    func testSomebodyWhoDrankNothingSaysSo() {
        let person = EveningParticipant(id: "p1", name: "Lena", emoji: "🔥")

        XCTAssertEqual(person.tallyText(separator: " · ", whenEmpty: "noch nichts"), "noch nichts")
        XCTAssertEqual(person.tallyText(separator: ", ", whenEmpty: "nichts"), "nichts")
    }

    /// Ein einzelner Schluck ist kein „1 Schlücke".
    func testTheSingularIsRight() {
        var person = EveningParticipant(id: "p1", name: "Lena", emoji: "🔥")
        person.sips = 1
        XCTAssertEqual(person.tallyText(separator: ", ", whenEmpty: "nichts"), "1 Schluck")

        person.sips = 0
        person.shots = 1
        XCTAssertEqual(person.tallyText(separator: ", ", whenEmpty: "nichts"), "1 Shot")
    }
}
