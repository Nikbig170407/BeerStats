//
//  KnowYourPeopleTests.swift
//  BeerStatsTests
//
//  Prueft, welche Fragen das Spiel ueberhaupt stellt.
//
//  Ein Quiz aus echten Zahlen hat genau zwei Arten, unfair zu werden, und
//  beide sind von aussen nicht zu erkennen: eine Frage ueber eine Quote aus
//  fuenf Wuerfen, und eine Frage, deren beide Antworten praktisch gleich
//  sind. In beiden Faellen ist die "richtige" Antwort Zufall - und wer
//  trinkt, trinkt zu Unrecht. Deshalb stehen beide Grenzen hier als Test
//  und nicht nur als Kommentar in der Rechnung.
//

import XCTest
@testable import BeerStats

final class KnowYourPeopleTests: XCTestCase {

    private var genug: Int { AppConstants.GameDefaults.minimumThrowsForHandicap }

    private func profil(
        _ id: String,
        throws wuerfe: Int = 0,
        hits treffer: Int = 0,
        airballs: Int = 0,
        played partien: Int = 0,
        won siege: Int = 0
    ) -> PlayerProfile {
        var werte = UserStatistics()
        werte.totalThrows = wuerfe
        werte.totalHits = treffer
        werte.totalAirballs = airballs
        werte.gamesPlayed = partien
        werte.gamesWon = siege
        return PlayerProfile(id: id, name: id, statistics: werte)
    }

    private func fragen(_ profile: [PlayerProfile], kind: PeopleQuestion.Kind) -> [PeopleQuestion] {
        KnowYourPeople.questions(for: profile).filter { $0.kind == kind }
    }

    // MARK: - Datenlage

    /// Zwei Leute mit je drei Wuerfen haben keine Trefferquote, sondern ein
    /// Ergebnis. Danach darf nicht gefragt werden.
    func testHitRateNeedsEnoughThrowsOnBothSides() {
        let wenig = [
            profil("a", throws: 3, hits: 3),
            profil("b", throws: 3, hits: 0)
        ]
        XCTAssertTrue(fragen(wenig, kind: .hitRate).isEmpty)
    }

    /// Auch einseitig nicht: Wer viel geworfen hat, laesst sich nicht mit
    /// jemandem vergleichen, der dreimal geworfen hat.
    func testHitRateNeedsEnoughThrowsOnTheOtherSideToo() {
        let schief = [
            profil("a", throws: genug * 2, hits: genug),
            profil("b", throws: 3, hits: 3)
        ]
        XCTAssertTrue(fragen(schief, kind: .hitRate).isEmpty)
    }

    func testHitRateIsAskedWhenBothHaveThrownEnough() {
        let belastbar = [
            profil("a", throws: genug * 2, hits: genug),          // 50 %
            profil("b", throws: genug * 2, hits: genug * 2 / 5)   // 20 %
        ]
        let gestellt = fragen(belastbar, kind: .hitRate)
        XCTAssertEqual(gestellt.count, 1)
        XCTAssertEqual(gestellt.first?.correctId, "a")
    }

    // MARK: - Abstand

    /// 50 gegen 48 Prozent: Es gibt keine richtige Antwort, nur eine, die
    /// zufaellig stimmt.
    func testNearlyEqualHitRatesAreNotAsked() {
        let knapp = [
            profil("a", throws: 100, hits: 50),
            profil("b", throws: 100, hits: 48)
        ]
        XCTAssertTrue(fragen(knapp, kind: .hitRate).isEmpty)
    }

    /// Bei Zaehlwerten gilt dasselbe: Ein Airball Unterschied ist am
    /// naechsten Abend eingeholt.
    func testCountsOneApartAreNotAsked() {
        let knapp = [profil("a", airballs: 7), profil("b", airballs: 6)]
        XCTAssertTrue(fragen(knapp, kind: .airballs).isEmpty)
    }

    func testCountsTwoApartAreAsked() {
        let deutlich = [profil("a", airballs: 7), profil("b", airballs: 5)]
        let gestellt = fragen(deutlich, kind: .airballs)
        XCTAssertEqual(gestellt.count, 1)
        XCTAssertEqual(gestellt.first?.correctId, "a")
    }

    /// Niemand hat Airballs geworfen: Abstand null, also keine Frage. Sonst
    /// stuende "Wer hat mehr Airballs geworfen?" ueber zwei Nullen.
    func testUntouchedCountersProduceNoQuestions() {
        let frisch = [profil("a"), profil("b")]
        XCTAssertTrue(KnowYourPeople.questions(for: frisch).isEmpty)
    }

    // MARK: - Aufstellung

    func testASinglePersonCannotBeCompared() {
        XCTAssertTrue(KnowYourPeople.questions(for: [profil("a", played: 9)]).isEmpty)
    }

    /// Jede Paarung und jede Sorte hoechstens einmal - sonst stehen dieselben
    /// zwei Leute dreimal hintereinander auf dem Schirm.
    func testEveryPairAndKindAppearsOnlyOnce() {
        let drei = [
            profil("a", played: 20, won: 15),
            profil("b", played: 14, won: 9),
            profil("c", played: 8, won: 3)
        ]
        let gestellt = KnowYourPeople.questions(for: drei)
        XCTAssertEqual(Set(gestellt.map(\.id)).count, gestellt.count)
        // Drei Paarungen, zwei brauchbare Sorten (Partien, Siege).
        XCTAssertEqual(gestellt.count, 6)
    }

    /// Profile ohne ID kommen aus Firestore nicht vor, aus einer
    /// Wiederherstellung schon. Sie duerfen das Spiel nicht zum Absturz
    /// bringen - und auch keine Antwort sein, die sich nicht merken laesst.
    func testProfilesWithoutIdAreIgnored() {
        var ohneId = profil("x", airballs: 20)
        ohneId.id = nil
        let gemischt = [ohneId, profil("b", airballs: 2)]
        XCTAssertTrue(KnowYourPeople.questions(for: gemischt).isEmpty)
    }
}
