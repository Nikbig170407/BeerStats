//
//  DrinkIntensityTests.swift
//  BeerStatsTests
//
//  Prueft, dass jedes Spiel seine eigene Haerte hat – und dass sie wieder
//  verschwindet, wenn das Spiel zu ist.
//
//  Die Haerte galt bis Oktober 2026 fuer alle Partyspiele zusammen. Jetzt
//  gehoert sie zur Runde, und das hat genau zwei Stellen, an denen es
//  lautlos falsch werden kann:
//
//  Erstens die Vorgabe. Ein Spiel, das noch nie eingestellt wurde, darf
//  nicht auf "Normal" zurueckfallen, sondern auf das, was der Nutzer als
//  Vorgabe stehen hat – sonst wird seine alte Einstellung beim Update
//  stillschweigend zurueckgesetzt.
//
//  Zweitens das Aufraeumen. Die geltende Haerte liegt im Speicher, nicht in
//  UserDefaults. Wird sie beim Verlassen nicht zurueckgenommen, laeuft
//  Beerpong Extreme nach einer harten Runde Schocken auch hart – und nichts
//  auf dem Bildschirm sagt, warum.
//

import XCTest
@testable import BeerStats

final class DrinkIntensityTests: XCTestCase {

    private var gesichert: [String: String?] = [:]

    private var betroffen: [String] {
        [DrinkIntensity.storageKey]
            + PartyGame.allCases.map { "\(DrinkIntensity.storageKey).\($0.rawValue)" }
    }

    override func setUp() {
        super.setUp()
        for key in betroffen {
            gesichert[key] = UserDefaults.standard.string(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
        DrinkIntensity.clearActive()
    }

    override func tearDown() {
        for (key, wert) in gesichert {
            if let wert {
                UserDefaults.standard.set(wert, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        gesichert = [:]
        DrinkIntensity.clearActive()
        super.tearDown()
    }

    // MARK: - Vorgabe

    /// Ohne gesetzte Vorgabe gilt "Normal" – ein frisch installiertes Spiel
    /// soll nicht zahmer oder haerter sein als gedacht.
    func testTheStandardIsNormalUntilSomebodyChangesIt() {
        XCTAssertEqual(DrinkIntensity.standard, .normal)
    }

    func testAGameWithoutItsOwnSettingFollowsTheStandard() {
        DrinkIntensity.standard = .hard

        for game in PartyGame.allCases {
            XCTAssertEqual(
                DrinkIntensity.stored(for: game), .hard,
                "\(game.title) faellt nicht auf die Vorgabe zurueck."
            )
        }
    }

    /// Die Vorgabe gilt nur, solange nichts anderes dasteht – danach nicht
    /// mehr. Sonst waere die Einstellung im Spiel wirkungslos, sobald jemand
    /// oben etwas umstellt.
    func testAnOwnSettingBeatsTheStandard() {
        DrinkIntensity.standard = .mild
        DrinkIntensity.store(.hard, for: .schocken)

        XCTAssertEqual(DrinkIntensity.stored(for: .schocken), .hard)
        XCTAssertEqual(DrinkIntensity.stored(for: .maexchen), .mild)
    }

    // MARK: - Was gerade gilt

    func testOpeningAGameMakesItsIntensityTheCurrentOne() {
        DrinkIntensity.standard = .normal
        DrinkIntensity.store(.hard, for: .schocken)

        DrinkIntensity.activate(for: .schocken)
        XCTAssertEqual(DrinkIntensity.current, .hard)

        DrinkIntensity.clearActive()
        XCTAssertEqual(DrinkIntensity.current, .normal)
    }

    /// Der Fall, um den es eigentlich geht: Nach dem Verlassen muss eine
    /// Menge wieder in der Vorgabe dastehen. Beerpong Extreme liest
    /// dieselbe Rechnung.
    func testTheIntensityDoesNotLeakOutOfAGame() {
        DrinkIntensity.standard = .mild
        DrinkIntensity.store(.hard, for: .drinkRoulette)

        DrinkIntensity.activate(for: .drinkRoulette)
        let imSpiel = DrinkAmount.sips(5).text

        DrinkIntensity.clearActive()
        let danach = DrinkAmount.sips(5).text

        XCTAssertEqual(imSpiel, "8 Schlücke")   // 5 × 1,6
        XCTAssertEqual(danach, "3 Schlücke")    // 5 × 0,6
    }

    /// Nicht nur der Text, auch die Trinkbilanz haengt an der geltenden
    /// Haerte – beide muessen dasselbe sagen.
    func testTheTallyFollowsTheSameIntensityAsTheText() {
        DrinkIntensity.store(.hard, for: .schocken)
        DrinkIntensity.activate(for: .schocken)

        XCTAssertEqual(DrinkAmount.sips(3).text, "5 Schlücke")
        XCTAssertEqual(DrinkAmount.sips(3).tally.sips, 5)
    }

    // MARK: - Katalog

    /// Jedes Spiel, das eine Haerte braucht, muss auch sagen, wo sie
    /// eingestellt wird – sonst gibt es sie nirgends. Umgekehrt darf ein
    /// Spiel ohne Mengen keinen Vorspann dafuer bekommen.
    func testEveryGameSaysWhereItsIntensityIsSet() {
        let ohneMengen: Set<PartyGame> = [.bombPass, .reactionDuel, .mostLikely]

        for game in PartyGame.allCases {
            if ohneMengen.contains(game) {
                XCTAssertEqual(game.intensityStep, .notNeeded, "\(game.title)")
            } else {
                XCTAssertNotEqual(
                    game.intensityStep, .notNeeded,
                    "\(game.title) spricht Mengen aus, fragt aber nicht nach der Härte."
                )
            }
        }
    }
}
