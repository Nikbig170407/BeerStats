//
//  HitparadeTests.swift
//  BeerStatsTests
//
//  Die Regeln der Hitparade. Was hier schiefgeht, faellt am Tisch nicht als
//  Fehler auf, sondern als Schluck, den jemand zu Unrecht trinkt – zum
//  Beispiel, weil "drei Jahre daneben" bei genau drei Jahren nicht zaehlt.
//

import XCTest
@testable import BeerStats

final class HitparadeTests: XCTestCase {

    private func lied(_ jahr: Int, _ nummer: Int = 0) -> SongCard {
        SongCard(title: "Lied \(jahr)-\(nummer)", artist: "Jemand", year: jahr, appleId: jahr * 100 + nummer)
    }

    private func stapel(_ anzahl: Int = 60) -> [SongCard] {
        (0..<anzahl).map { lied(1960 + $0 % 60, $0) }
    }

    private func spiel(
        spieler: Int = 3,
        ziel: Int = 5,
        fragen: Set<HitQuestion> = Set(HitQuestion.allCases),
        lieder: [SongCard]? = nil,
        seed: UInt64 = 1
    ) -> HitparadeGame {
        var zufall = SeededGenerator(seed: seed)
        return HitparadeGame(playerCount: spieler, target: ziel, questions: fragen, songs: lieder ?? stapel(), using: &zufall)
    }

    /// Ein Spiel, in dem gerade genau diese Frage dran ist.
    private func spiel(mit frage: HitQuestion) -> HitparadeGame {
        spiel(fragen: [frage])
    }

    // MARK: - Der Anfang

    func testEveryoneStartsWithOneOpenCard() {
        let partie = spiel(spieler: 4)
        XCTAssertEqual(partie.timelines.map(\.count), [1, 1, 1, 1])
        XCTAssertEqual(partie.player, 0)
        XCTAssertNotNil(partie.current)
    }

    func testTheSongToGuessIsNotLyingInAnyTimeline() {
        let partie = spiel()
        let liegend = partie.timelines.flatMap { $0.cards.map(\.id) }
        XCTAssertFalse(liegend.contains(partie.current!.id))
    }

    func testWithoutAnyQuestionChosenItIsPlacement() {
        XCTAssertEqual(spiel(fragen: []).question, .placement)
    }

    // MARK: - Die Jahresfragen

    /// "Drei Jahre daneben zaehlen noch" – genau drei auch.
    func testThreeYearsOffStillCountsAndFourDoesNot() {
        let partie = spiel(mit: .yearWithinThree)
        let jahr = partie.current!.year
        XCTAssertTrue(partie.isCorrect(.year(jahr)))
        XCTAssertTrue(partie.isCorrect(.year(jahr + 3)))
        XCTAssertTrue(partie.isCorrect(.year(jahr - 3)))
        XCTAssertFalse(partie.isCorrect(.year(jahr + 4)))
        XCTAssertFalse(partie.isCorrect(.year(jahr - 4)))
    }

    func testOneYearOffStillCountsAndTwoDoesNot() {
        let partie = spiel(mit: .yearWithinOne)
        let jahr = partie.current!.year
        XCTAssertTrue(partie.isCorrect(.year(jahr + 1)))
        XCTAssertTrue(partie.isCorrect(.year(jahr - 1)))
        XCTAssertFalse(partie.isCorrect(.year(jahr + 2)))
        XCTAssertFalse(partie.isCorrect(.year(jahr - 2)))
    }

    // MARK: - Die anderen Fragen

    func testPlacementIsCheckedAgainstTheOwnTimeline() {
        let partie = spiel(mit: .placement)
        let richtig = (0..<partie.timeline.gapCount).filter { partie.timeline.isCorrect(partie.current!, at: $0) }
        let falsch = (0..<partie.timeline.gapCount).filter { !richtig.contains($0) }
        XCTAssertFalse(richtig.isEmpty)
        for luecke in richtig { XCTAssertTrue(partie.isCorrect(.gap(luecke))) }
        for luecke in falsch { XCTAssertFalse(partie.isCorrect(.gap(luecke))) }
    }

    func testTitleAndArtistAreWhatTheTableSays() {
        for frage in [HitQuestion.title, .artist] {
            let partie = spiel(mit: frage)
            XCTAssertTrue(partie.isCorrect(.judged(true)))
            XCTAssertFalse(partie.isCorrect(.judged(false)))
        }
    }

    /// Ein Jahr auf die Titelfrage ist keine Antwort – auch wenn es stimmt.
    func testAnAnswerOfTheWrongKindIsNeverRight() {
        let titel = spiel(mit: .title)
        XCTAssertFalse(titel.isCorrect(.year(titel.current!.year)))
        let jahr = spiel(mit: .yearWithinThree)
        XCTAssertFalse(jahr.isCorrect(.judged(true)))
        XCTAssertFalse(jahr.isCorrect(.gap(0)))
    }

    // MARK: - Karte behalten oder nicht

    func testARightAnswerPutsTheCardIntoTheTimelineInOrder() {
        var partie = spiel(mit: .yearWithinThree)
        let karte = partie.current!
        XCTAssertTrue(partie.answer(.year(karte.year)))
        XCTAssertTrue(partie.timeline.cards.contains(karte))
        XCTAssertEqual(partie.timeline.cards.map(\.year), partie.timeline.cards.map(\.year).sorted())
    }

    func testAWrongAnswerLeavesTheTimelineAsItWas() {
        var partie = spiel(mit: .title)
        let vorher = partie.timeline
        XCTAssertFalse(partie.answer(.judged(false)))
        XCTAssertEqual(partie.timeline, vorher)
    }

    /// "Jahr stimmt nicht": Die Karte geht wieder raus, als waere sie nie da
    /// gewesen.
    func testADiscardedCardLeavesTheTimelineAgain() {
        var partie = spiel(mit: .title)
        let vorher = partie.timeline
        partie.answer(.judged(true))
        partie.discardCurrent()
        XCTAssertEqual(partie.timeline, vorher)
    }

    // MARK: - Reihum und Sieg

    func testTurnsGoAroundTheTable() {
        var partie = spiel(spieler: 3)
        var zufall = SeededGenerator(seed: 9)
        var reihe: [Int] = []
        for _ in 0..<6 {
            reihe.append(partie.player)
            partie.advance(using: &zufall)
        }
        XCTAssertEqual(reihe, [0, 1, 2, 0, 1, 2])
    }

    func testWhoeverReachesTheTargetWins() {
        var partie = spiel(spieler: 2, ziel: 2, fragen: [.title])
        XCTAssertNil(partie.winner)
        partie.answer(.judged(true))
        XCTAssertEqual(partie.winner, 0)
    }

    // MARK: - Der Stapel

    /// Ist der Stapel durch, wird neu gemischt – aber nie eine Karte, die
    /// schon in einer Reihe liegt. Sonst laege dasselbe Lied zweimal da.
    func testAReshuffledDeckNeverDealsACardFromATimeline() {
        var partie = spiel(spieler: 2, ziel: 100, fragen: [.title], lieder: stapel(8))
        var zufall = SeededGenerator(seed: 4)
        for _ in 0..<40 {
            partie.answer(.judged(true))
            partie.advance(using: &zufall)
            guard let karte = partie.current else { continue }
            let liegend = partie.timelines.flatMap { $0.cards.map(\.id) }
            XCTAssertFalse(liegend.contains(karte.id), karte.id)
        }
    }

    // MARK: - Das Losen

    func testOnlyChosenQuestionsComeUp() {
        var partie = spiel(fragen: [.title, .yearWithinOne])
        var zufall = SeededGenerator(seed: 2)
        for _ in 0..<200 {
            XCTAssertTrue([HitQuestion.title, .yearWithinOne].contains(partie.question))
            partie.advance(using: &zufall)
        }
    }

    /// Dieselbe Frage zweimal hintereinander kommt vor, aber deutlich
    /// seltener als beim reinen Zufall (dort jede fuenfte).
    func testTheSameQuestionRarelyComesTwiceInARow() {
        var partie = spiel()
        var zufall = SeededGenerator(seed: 3)
        var wiederholt = 0
        let runden = 4000
        for _ in 0..<runden {
            let vorher = partie.question
            partie.advance(using: &zufall)
            if partie.question == vorher { wiederholt += 1 }
        }
        XCTAssertLessThan(Double(wiederholt) / Double(runden), 0.1)
        XCTAssertGreaterThan(wiederholt, 0, "Die Frage von eben ist gedaempft, nicht verboten")
    }

    // MARK: - Das Zahnrad

    /// Mitten in der Partie andere Fragen: Die Frage, die gerade dasteht,
    /// bleibt – erst ab dem naechsten Zug wird aus den neuen gelost.
    func testChangedQuestionsApplyFromTheNextTurn() {
        var partie = spiel(fragen: [.yearWithinThree])
        var zufall = SeededGenerator(seed: 5)
        partie.choose([.title])
        XCTAssertEqual(partie.question, .yearWithinThree)
        for _ in 0..<20 {
            partie.advance(using: &zufall)
            XCTAssertEqual(partie.question, .title)
        }
    }

    func testChoosingNoQuestionsFallsBackToPlacement() {
        var partie = spiel()
        var zufall = SeededGenerator(seed: 6)
        partie.choose([])
        partie.advance(using: &zufall)
        XCTAssertEqual(partie.questions, [.placement])
        XCTAssertEqual(partie.question, .placement)
    }

    // MARK: - Der echte Stapel

    /// Jedes Lied braucht seine Hoerprobe – ohne Nummer bei Apple liefe es
    /// am Tisch stumm. Und keine Nummer zweimal: Sonst spielte das falsche
    /// Lied, und die Runde raete auf eine Karte, die nicht laeuft.
    func testEverySongHasItsOwnAppleNumber() {
        for lied in SongDeck.all {
            XCTAssertGreaterThan(lied.appleId, 0, lied.id)
        }
        let nummern = SongDeck.all.map(\.appleId)
        XCTAssertEqual(Set(nummern).count, nummern.count, "Eine Apple-Nummer steht doppelt im Stapel")
    }
}
