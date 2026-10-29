//
//  SongTimelineTests.swift
//  BeerStatsTests
//
//  Prueft die Reihe der Hitparade: ob eine Luecke richtig ist, und ob der Stapel
//  taugt.
//
//  Beides sind Stellen, an denen ein Fehler am Tisch nicht auffaellt,
//  sondern nur zu einem Schluck fuehrt, den jemand zu Unrecht nimmt. Der
//  haeufigste Fall ist das gleiche Jahr: Zwei Hits aus 1997 duerfen in
//  beliebiger Reihenfolge liegen – waere das falsch, traenke jemand dafuer,
//  dass die Charts voll waren.
//

import XCTest
@testable import BeerStats

final class SongTimelineTests: XCTestCase {

    private func song(_ jahr: Int, _ titel: String = "Lied") -> SongCard {
        SongCard(title: "\(titel) \(jahr)", artist: "Jemand", year: jahr)
    }

    private func timeline(_ jahre: [Int]) -> SongTimeline {
        var reihe = SongTimeline()
        for jahr in jahre { reihe.insert(song(jahr)) }
        return reihe
    }

    // MARK: - Die Luecken

    func testAnEmptyTimelineHasExactlyOneGap() {
        XCTAssertEqual(SongTimeline().gapCount, 1)
        XCTAssertTrue(SongTimeline().isCorrect(song(1985), at: 0))
    }

    func testThereIsOneMoreGapThanCards() {
        XCTAssertEqual(timeline([1975, 1991, 2003]).gapCount, 4)
    }

    func testTheGapBeforeAndAfterWork() {
        let reihe = timeline([1975, 1991])
        XCTAssertTrue(reihe.isCorrect(song(1968), at: 0))
        XCTAssertTrue(reihe.isCorrect(song(2010), at: 2))
        XCTAssertFalse(reihe.isCorrect(song(2010), at: 0))
        XCTAssertFalse(reihe.isCorrect(song(1968), at: 2))
    }

    func testTheGapInBetweenIsOnlyRightForYearsInBetween() {
        let reihe = timeline([1975, 1991])
        XCTAssertTrue(reihe.isCorrect(song(1983), at: 1))
        XCTAssertFalse(reihe.isCorrect(song(1999), at: 1))
    }

    /// Der wichtigste Fall: Gleiches Jahr passt auf BEIDE Seiten.
    func testTheSameYearFitsOnEitherSide() {
        let reihe = timeline([1997])
        XCTAssertTrue(reihe.isCorrect(song(1997, "Zweites"), at: 0))
        XCTAssertTrue(reihe.isCorrect(song(1997, "Zweites"), at: 1))
    }

    func testAGapOutsideTheTimelineIsNeverRight() {
        XCTAssertFalse(timeline([1980]).isCorrect(song(1980), at: 5))
        XCTAssertFalse(timeline([1980]).isCorrect(song(1980), at: -1))
    }

    // MARK: - Einsortieren

    func testCardsStaySortedByYear() {
        let reihe = timeline([2003, 1975, 1991])
        XCTAssertEqual(reihe.cards.map(\.year), [1975, 1991, 2003])
    }

    func testARemovedCardIsGone() {
        var reihe = timeline([1975, 1991])
        let karte = reihe.cards[0]
        reihe.remove(karte)
        XCTAssertEqual(reihe.cards.map(\.year), [1991])
    }

    // MARK: - Die Beschriftung

    /// Sie ist das, was der Ratende ansagt – steht dort etwas anderes als
    /// gemeint ist, tippt der Nachbar die falsche Lücke an.
    func testTheGapLabelsSayWhatTheyMean() {
        let reihe = timeline([1975, 1991])
        XCTAssertEqual(reihe.label(forGap: 0), "vor 1975")
        XCTAssertEqual(reihe.label(forGap: 1), "1975 – 1991")
        XCTAssertEqual(reihe.label(forGap: 2), "nach 1991")
    }

    func testTwoCardsFromTheSameYearGetTheirOwnLabel() {
        XCTAssertEqual(timeline([1997, 1997]).label(forGap: 1), "auch 1997")
    }

    // MARK: - Der Stapel

    func testEverySongIsInTheDeckOnlyOnce() {
        let kennungen = SongDeck.all.map(\.id)
        let doppelt = Set(kennungen.filter { id in kennungen.filter { $0 == id }.count > 1 })
        XCTAssertTrue(doppelt.isEmpty, "Doppelte Lieder: \(doppelt.sorted())")
    }

    func testEverySongHasAPlausibleYear() {
        for lied in SongDeck.all {
            XCTAssertGreaterThanOrEqual(lied.year, 1950, lied.id)
            XCTAssertLessThanOrEqual(lied.year, 2026, lied.id)
            XCTAssertFalse(lied.title.isEmpty, lied.id)
            XCTAssertFalse(lied.artist.isEmpty, lied.id)
        }
    }

    /// Der Stapel muss ueber die Jahrzehnte verteilt sein. Laegen achtzig
    /// Prozent in den Neunzigern, waere jede Karte nach der dritten
    /// geraten – die Reihe haette dort keine Luecken mehr, die sich
    /// unterscheiden lassen.
    func testEveryDecadeIsRepresented() {
        let jahrzehnte = Dictionary(grouping: SongDeck.all) { ($0.year / 10) * 10 }
        for jahrzehnt in stride(from: 1970, through: 2010, by: 10) {
            XCTAssertGreaterThanOrEqual(
                jahrzehnte[jahrzehnt]?.count ?? 0, 10,
                "Zu wenige Lieder aus den \(jahrzehnt)ern"
            )
        }
        XCTAssertGreaterThanOrEqual(SongDeck.count, 150)
    }

    func testTheSubtitleNamesTheRealDeckSize() {
        XCTAssertTrue(
            PartyGame.timeline.subtitle.contains("\(SongDeck.count) Lieder"),
            PartyGame.timeline.subtitle
        )
    }
}
