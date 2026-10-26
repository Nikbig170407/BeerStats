//
//  EveningUndoTests.swift
//  BeerStatsTests
//
//  Zwei Dinge, die am Tisch entscheiden, ob die Trinkbilanz geglaubt wird.
//
//  Erstens das Zuruecknehmen. Vertippt wird sich auf zwei Arten – falsche
//  Menge und falsche PERSON –, und bis Oktober 2026 half dagegen nur die
//  Minus-Taste am Teilnehmer: ein Schluck pro Druck, und die falsche Person
//  gar nicht. Drei Schluecke auf den Falschen hiessen dreimal Minus beim
//  einen und dreimal Plus beim anderen.
//
//  Zweitens der Abend, der sich selbst startet. Vorher musste man ihn
//  suchen und antippen, BEVOR irgendetwas gezaehlt wurde – und wer um halb
//  elf merkt, dass die Bilanz leer ist, faengt nicht mehr an.
//
//  Beides schreibt in dieselben UserDefaults wie die App. Im Simulator ist
//  das folgenlos, aber was die Tests hinterlassen, faende der naechste Lauf
//  vor – deshalb sichern und zuruecklegen.
//

import XCTest
@testable import BeerStats

final class EveningUndoTests: XCTestCase {

    private var abendVorher: Data?
    private var tischVorher: Data?

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

    private func startEvening() {
        EveningLog.start(with: [
            profil("Lena", "🔥", id: "p1"),
            profil("Jan", "🐢", id: "p2")
        ])
    }

    private func stand(_ id: String) -> (sips: Int, shots: Int) {
        let person = EveningLog.current?.participants.first { $0.id == id }
        return (person?.sips ?? 0, person?.shots ?? 0)
    }

    // MARK: - Zuruecknehmen

    /// Die ganze Buchung, nicht ein Schluck davon.
    func testTheWholeBookingComesBack() {
        startEvening()
        EveningLog.record(.sips(3), forPlayer: 0)
        XCTAssertGreaterThan(stand("p1").sips, 0)

        XCTAssertTrue(EveningLog.undoLastBooking())
        XCTAssertEqual(stand("p1").sips, 0, "Es blieben Schlücke stehen")
    }

    /// Der Fall, der vorher gar nicht zu heilen war: auf die falsche Person
    /// gebucht.
    func testABookingOnTheWrongPersonComesBack() {
        startEvening()
        EveningLog.record(.sips(2), forPlayer: 1)
        XCTAssertGreaterThan(stand("p2").sips, 0)

        XCTAssertTrue(EveningLog.undoLastBooking())
        XCTAssertEqual(stand("p2").sips, 0)
        XCTAssertEqual(stand("p1").sips, 0, "Beim Falschen ist etwas gelandet")
    }

    /// Nur die LETZTE Buchung, und nur einmal. Sonst raeumt ein zweiter
    /// Druck still den ganzen Abend ab.
    func testOnlyTheLastBookingAndOnlyOnce() {
        startEvening()
        EveningLog.record(.sips(2), forPlayer: 0)
        EveningLog.record(.sips(3), forPlayer: 1)

        let lenaVorher = stand("p1").sips
        XCTAssertTrue(EveningLog.undoLastBooking())
        XCTAssertEqual(stand("p2").sips, 0, "Die letzte Buchung steht noch")
        XCTAssertEqual(stand("p1").sips, lenaVorher, "Die vorletzte wurde mitgenommen")

        XCTAssertFalse(EveningLog.undoLastBooking(), "Zweimal zurueck genommen")
        XCTAssertEqual(stand("p1").sips, lenaVorher)
    }

    /// Wer zwischendurch von Hand korrigiert hat, darf nicht ins Minus
    /// rutschen.
    func testTheTallyNeverGoesNegative() {
        startEvening()
        EveningLog.record(.sips(3), forPlayer: 0)
        EveningLog.undoLastDrink(for: "p1")
        EveningLog.undoLastDrink(for: "p1")

        XCTAssertTrue(EveningLog.undoLastBooking())
        XCTAssertEqual(stand("p1").sips, 0)
        XCTAssertGreaterThanOrEqual(stand("p1").shots, 0)
    }

    /// Ohne Abend passiert nichts – und vor allem stuerzt nichts ab.
    func testWithoutAnEveningNothingHappens() {
        XCTAssertFalse(EveningLog.undoLastBooking())
    }

    // MARK: - Der Abend startet sich selbst

    /// Das erste Spiel startet den Abend, wenn jemand am Tisch steht.
    func testOpeningAGameStartsTheEvening() {
        TableRoster.remember([
            profil("Lena", "🔥", id: "p1"),
            profil("Jan", "🐢", id: "p2")
        ])
        XCTAssertNil(EveningLog.current)

        EveningLog.record(partyGame: .ringOfFire)

        XCTAssertTrue(EveningLog.isRunning)
        XCTAssertEqual(EveningLog.current?.participants.count, 2)
        XCTAssertEqual(EveningLog.current?.entries.count, 1, "Das Spiel selbst fehlt im Abend")
    }

    /// Ohne Aufstellung nicht: Ein Abend ohne Teilnehmer kann nichts buchen
    /// und waere eine Liste gespielter Spiele ohne Leute.
    func testWithoutATableNoEveningStarts() {
        EveningLog.record(partyGame: .ringOfFire)
        XCTAssertNil(EveningLog.current)
    }

    /// Ein laufender Abend wird nicht ueberschrieben – sonst waere nach dem
    /// zweiten Spiel die halbe Bilanz weg.
    func testARunningEveningIsNeverRestarted() {
        startEvening()
        EveningLog.record(.sips(3), forPlayer: 0)
        let gestartet = EveningLog.current?.startedAt

        TableRoster.remember([profil("Tim", "🐙", id: "p9")])
        EveningLog.record(partyGame: .ringOfFire)

        XCTAssertEqual(EveningLog.current?.startedAt, gestartet)
        XCTAssertEqual(EveningLog.current?.participants.count, 2, "Die Teilnehmer wurden ersetzt")
        XCTAssertGreaterThan(stand("p1").sips, 0, "Die Bilanz wurde zurueckgesetzt")
    }
}
