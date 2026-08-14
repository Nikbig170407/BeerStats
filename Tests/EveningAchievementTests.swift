//
//  EveningAchievementTests.swift
//  BeerStatsTests
//
//  Prueft die Auszeichnungen fuer einen Abend.
//
//  Reine Funktionen ueber einem Wert-Typ – genau die Sorte Code, die
//  monatelang leise falsch sein kann. Eine Plakette, die nie erscheint,
//  faellt niemandem auf; eine, die immer erscheint, wird nach dem zweiten
//  Abend ignoriert. Beides sieht von aussen gleich aus.
//
//  Der Schwerpunkt liegt deshalb auf den GRENZEN: knapp darunter darf sie
//  nicht kommen, knapp darueber muss sie.
//

import XCTest
@testable import BeerStats

final class EveningAchievementTests: XCTestCase {

    private func person(_ name: String, sips: Int = 0, shots: Int = 0) -> EveningParticipant {
        EveningParticipant(id: name, name: name, emoji: "🍺", sips: sips, shots: shots)
    }

    private func evening(
        _ teilnehmer: [EveningParticipant],
        spiele: [String] = [],
        stunden: Double = 1
    ) -> Evening {
        let start = Date().addingTimeInterval(-stunden * 3600)
        return Evening(
            startedAt: start,
            endedAt: Date(),
            participants: teilnehmer,
            entries: spiele.map {
                EveningEntry(id: UUID().uuidString, title: $0, emoji: "🎲", at: start, winner: nil)
            }
        )
    }

    private func titles(_ achievements: [Achievement]) -> Set<String> {
        Set(achievements.map(\.id))
    }

    // MARK: - Nichts getrunken

    func testAbstinenceNeedsAnEveningLongEnoughToCount() {
        let nüchtern = person("Nik")

        let kurz = evening([nüchtern, person("Lena", sips: 4)], spiele: ["Schocken", "Bombe"])
        XCTAssertFalse(
            titles(EveningAchievements.forParticipant(nüchtern, in: kurz)).contains("dry"),
            "nach zwei Spielen ist nichts getrunken keine Leistung"
        )

        let lang = evening([nüchtern, person("Lena", sips: 4)], spiele: ["Schocken", "Bombe", "Mäxchen"])
        XCTAssertTrue(
            titles(EveningAchievements.forParticipant(nüchtern, in: lang)).contains("dry")
        )
    }

    // MARK: - Alleinunterhalter

    func testSoloActNeedsMoreThanAllOthersTogether() {
        let viel = person("Nik", sips: 10)
        let abend = evening([viel, person("Lena", sips: 6), person("Tom", sips: 5)])
        XCTAssertFalse(
            titles(EveningAchievements.forParticipant(viel, in: abend)).contains("soloAct"),
            "zehn gegen elf reicht nicht"
        )

        let deutlich = person("Nik", sips: 12)
        let abend2 = evening([deutlich, person("Lena", sips: 6), person("Tom", sips: 5)])
        XCTAssertTrue(
            titles(EveningAchievements.forParticipant(deutlich, in: abend2)).contains("soloAct")
        )
    }

    /// Sitzt jemand allein da, hat er zwangslaeufig mehr getrunken als "alle
    /// anderen zusammen" – naemlich als niemand. Das ist keine Leistung.
    func testSoloActNeedsSomebodyElseToHaveDrunk() {
        let allein = person("Nik", sips: 8)
        let abend = evening([allein, person("Lena")])
        XCTAssertFalse(
            titles(EveningAchievements.forParticipant(allein, in: abend)).contains("soloAct")
        )
    }

    // MARK: - Schwellen

    func testShotAndSipThresholds() {
        let knappDrunter = person("Nik", sips: 19, shots: 2)
        let knappDrueber = person("Lena", sips: 20, shots: 3)
        let abend = evening([knappDrunter, knappDrueber])

        let a = titles(EveningAchievements.forParticipant(knappDrunter, in: abend))
        XCTAssertFalse(a.contains("shots"))
        XCTAssertFalse(a.contains("marathon"))

        let b = titles(EveningAchievements.forParticipant(knappDrueber, in: abend))
        XCTAssertTrue(b.contains("shots"))
        XCTAssertTrue(b.contains("marathon"))
    }

    /// Hat niemand getrunken, darf auch niemand "durstigste Person" sein.
    func testNobodyIsThirstiestInADryEvening() {
        let abend = evening([person("Nik"), person("Lena")], spiele: ["Bombe"])
        for teilnehmer in abend.participants {
            XCTAssertFalse(
                titles(EveningAchievements.forParticipant(teilnehmer, in: abend)).contains("thirsty")
            )
        }
    }

    // MARK: - Der Abend selbst

    func testEveningAwardsFollowTheirThresholds() {
        let kurz = evening([person("Nik", sips: 3)], spiele: ["A", "B"], stunden: 3.9)
        let k = titles(EveningAchievements.forEvening(kurz))
        XCTAssertFalse(k.contains("longNight"))
        XCTAssertFalse(k.contains("variety"))
        XCTAssertFalse(k.contains("marathonNight"))

        let lang = evening(
            [person("Nik", sips: 3)],
            spiele: ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"],
            stunden: 4.1
        )
        let l = titles(EveningAchievements.forEvening(lang))
        XCTAssertTrue(l.contains("longNight"))
        XCTAssertTrue(l.contains("variety"))
        XCTAssertTrue(l.contains("marathonNight"))
    }

    /// Zehnmal dasselbe Spiel ist kein bunter Abend.
    func testVarietyCountsDistinctGames() {
        let einfoermig = evening([person("Nik", sips: 2)], spiele: Array(repeating: "Schocken", count: 10))
        let a = titles(EveningAchievements.forEvening(einfoermig))
        XCTAssertTrue(a.contains("marathonNight"), "zehn Runden bleiben zehn Runden")
        XCTAssertFalse(a.contains("variety"), "aber bunt war es nicht")
    }

    func testBalancedOnlyWhenSomebodyDrank() {
        let trocken = evening([person("Nik"), person("Lena")], spiele: ["A"])
        XCTAssertFalse(
            titles(EveningAchievements.forEvening(trocken)).contains("balanced"),
            "null zu null ist nicht gerecht verteilt, sondern leer"
        )

        let eng = evening([person("Nik", sips: 8), person("Lena", sips: 5)], spiele: ["A"])
        XCTAssertTrue(titles(EveningAchievements.forEvening(eng)).contains("balanced"))

        let weit = evening([person("Nik", sips: 20), person("Lena", sips: 2)], spiele: ["A"])
        XCTAssertFalse(titles(EveningAchievements.forEvening(weit)).contains("balanced"))
    }

    // MARK: - Grundsaetzliches

    func testIdentifiersAreUniqueWithinAResult() {
        let abend = evening(
            [person("Nik", sips: 25, shots: 4)],
            spiele: ["A", "B", "C", "D", "E"],
            stunden: 5
        )
        let plaketten = EveningAchievements.forParticipant(abend.participants[0], in: abend)
        XCTAssertEqual(Set(plaketten.map(\.id)).count, plaketten.count)

        for plakette in plaketten + EveningAchievements.forEvening(abend) {
            XCTAssertFalse(plakette.title.isEmpty)
            XCTAssertFalse(plakette.detail.isEmpty)
            XCTAssertFalse(plakette.emoji.isEmpty)
        }
    }
}
