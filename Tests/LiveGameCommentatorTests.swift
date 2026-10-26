//
//  LiveGameCommentatorTests.swift
//  BeerStatsTests
//
//  Prueft den Unterschied zwischen Reporter und Nervensaege.
//
//  Der Kommentator ist eine reine Rechnung – Ereignis und Nummer hinein,
//  Satz heraus –, und genau zwei Eigenschaften entscheiden, ob man ihn nach
//  fuenf Minuten abschaltet:
//
//  Er darf nicht zu jedem Ereignis reden. Treffer und Fehlwurf passieren im
//  Minutentakt; wer die alle kommentiert, redet durchgehend.
//
//  Und er darf sich nicht wiederholen. Derselbe Satz beim dritten Mal ist
//  schlimmer als keiner – deshalb mehrere Fassungen, gewaehlt von der
//  laufenden Nummer statt gewuerfelt. Gewuerfelt saehe ein Test nie
//  dasselbe zweimal, und derselbe Zug klaenge beim Nachspielen eines Logs
//  anders als beim Spielen.
//

import XCTest
@testable import BeerStats

final class LiveGameCommentatorTests: XCTestCase {

    private func kommentator(_ namen: [String], _ gegner: [String]) -> LiveGameCommentator {
        LiveGameCommentator(
            naming: LiveGameNaming(teams: [
                Team(id: "t0", playerIds: [], playerNames: namen, ballsInPlay: namen.count),
                Team(id: "t1", playerIds: [], playerNames: gegner, ballsInPlay: gegner.count)
            ])
        )
    }

    private var standard: LiveGameCommentator {
        kommentator(["Lena", "Jan"], ["Tim", "Mia"])
    }

    private let werfer = PlayerRef(teamIndex: 0, slot: 0)

    // MARK: - Nicht alles wird kommentiert

    /// Ein normaler Treffer passiert dauernd. Wird er jedes Mal
    /// kommentiert, redet die App durchgehend.
    func testAPlainHitIsMostlySilent() {
        let gesagt = (0..<12).compactMap {
            standard.line(for: .hit(thrower: werfer, bounce: false, trickshot: false, cupIndex: 0), turn: $0)
        }

        XCTAssertFalse(gesagt.isEmpty, "Es wird nie etwas gesagt")
        XCTAssertLessThan(gesagt.count, 6, "Zu gespraechig: \(gesagt.count) von 12")
    }

    func testAMissIsEvenRarer() {
        let treffer = (0..<12).compactMap {
            standard.line(for: .hit(thrower: werfer, bounce: false, trickshot: false, cupIndex: 0), turn: $0)
        }
        let daneben = (0..<12).compactMap { standard.line(for: .missed(thrower: werfer), turn: $0) }

        XCTAssertLessThanOrEqual(daneben.count, treffer.count)
    }

    /// Verwaltung bleibt still: Dass ein Becher weggestellt wird, sieht die
    /// Runde ohnehin.
    func testHousekeepingStaysQuiet() {
        XCTAssertNil(standard.line(for: .cupChosen(byTeamIndex: 0, cupIndex: 3), turn: 0))
        XCTAssertNil(standard.line(for: .rebound(thrower: werfer), turn: 0))
        XCTAssertNil(
            standard.line(
                for: .reRacked(teamIndex: 0, formation: RackFormation(name: "Linie", rows: [3, 3])),
                turn: 0
            )
        )
    }

    /// Ein Airball ohne Folgen kostet nichts – dann gibt es auch nichts
    /// anzusagen. Dieselbe Entscheidung wie beim Klang.
    func testAHarmlessAirballStaysQuiet() {
        XCTAssertNil(standard.line(for: .airball(thrower: werfer, penalised: false), turn: 0))
        XCTAssertNotNil(standard.line(for: .airball(thrower: werfer, penalised: true), turn: 0))
    }

    // MARK: - Was immer gesagt wird

    /// Die grossen Momente dürfen nie verschluckt werden – egal bei welcher
    /// Nummer sie passieren. Genau das waere mit einem "nur jedes dritte
    /// Mal" an der falschen Stelle passiert.
    func testTheBigMomentsAlwaysSpeak() {
        for turn in 0..<12 {
            XCTAssertNotNil(standard.line(for: .caughtFire(player: werfer), turn: turn), "On Fire bei \(turn)")
            XCTAssertNotNil(standard.line(for: .ballsBack(teamIndex: 0), turn: turn), "Balls Back bei \(turn)")
            XCTAssertNotNil(standard.line(for: .bombe(choosingTeamIndex: 1), turn: turn), "Bombe bei \(turn)")
            XCTAssertNotNil(standard.line(for: .finished(winnerTeamIndex: 0), turn: turn), "Ende bei \(turn)")
        }
    }

    func testADrawIsAnnouncedToo() {
        let satz = standard.line(for: .finished(winnerTeamIndex: nil), turn: 0)
        XCTAssertNotNil(satz)
        XCTAssertFalse(satz?.contains("gewinn") ?? true, satz ?? "")
    }

    // MARK: - Abwechslung

    /// Mehrere Fassungen je Ereignis – sonst ist es beim dritten Mal eine
    /// Tonbandansage.
    func testTheSameEventSoundsDifferentOverTime() {
        let saetze = Set((0..<6).compactMap { standard.line(for: .caughtFire(player: werfer), turn: $0) })
        XCTAssertGreaterThan(saetze.count, 1, "Immer derselbe Satz")
    }

    /// Dieselbe Nummer sagt denselben Satz. Ohne das klaenge ein
    /// nachgespielter Log anders als die Partie.
    func testTheSameTurnAlwaysSaysTheSameThing() {
        for turn in 0..<8 {
            XCTAssertEqual(
                standard.line(for: .caughtFire(player: werfer), turn: turn),
                standard.line(for: .caughtFire(player: werfer), turn: turn)
            )
        }
    }

    // MARK: - Die Grammatik kommt mit

    /// "Lena wirft nochmal", aber "Lena & Jan WERFEN nochmal" – dieselbe
    /// Regel wie im Protokoll, nur gesprochen.
    func testTheGrammarFollowsTheTeamSize() {
        let allein = kommentator(["Lena"], ["Tim"])
        let zuZweit = kommentator(["Lena", "Jan"], ["Tim", "Mia"])

        let einer = (0..<3).compactMap { allein.line(for: .ballsBack(teamIndex: 0), turn: $0) }
        let zwei = (0..<3).compactMap { zuZweit.line(for: .ballsBack(teamIndex: 0), turn: $0) }

        XCTAssertTrue(einer.contains { $0.contains("wirft") }, "\(einer)")
        XCTAssertTrue(zwei.contains { $0.contains("werfen") }, "\(zwei)")
    }

    /// Kein Satz darf leer sein – gesprochen waere das eine Pause ohne
    /// Grund.
    func testNoLineIsEmpty() {
        let ereignisse: [GameEvent] = [
            .hit(thrower: werfer, bounce: true, trickshot: false, cupIndex: 0),
            .hit(thrower: werfer, bounce: false, trickshot: true, cupIndex: 0),
            .airball(thrower: werfer, penalised: true),
            .caughtFire(player: werfer),
            .ballsBack(teamIndex: 0),
            .bombe(choosingTeamIndex: 0),
            .redemptionStarted(teamIndex: 1),
            .finished(winnerTeamIndex: 1)
        ]

        for ereignis in ereignisse {
            for turn in 0..<6 {
                if let satz = standard.line(for: ereignis, turn: turn) {
                    XCTAssertFalse(satz.trimmingCharacters(in: .whitespaces).isEmpty, "\(ereignis)")
                }
            }
        }
    }
}
