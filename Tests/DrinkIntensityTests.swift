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

    /// Dass jedes Spiel sagt, WO seine Haerte eingestellt wird, erzwingt
    /// seit dem 13. Oktober der Compiler: `intensityStep` ist ein
    /// vollstaendiges `switch` ohne `default`, und beide Faelle fuehren zu
    /// einer Auswahl. Ein neuer Fall in der Aufzaehlung uebersetzt sich
    /// also erst, wenn er eingeordnet ist.
    ///
    /// Was der Compiler nicht sieht: ob die Haerten der Spiele getrennt
    /// bleiben. Jedes Spiel schreibt unter seinen eigenen Schluessel – ein
    /// Tippfehler darin wuerde zwei Spiele zusammenlegen, und am Tisch
    /// faellt das erst auf, wenn eine Runde ploetzlich anders getrunken
    /// wird als eingestellt.
    func testEveryGameKeepsItsOwnIntensity() {
        let haerten = DrinkIntensity.allCases
        let erwartet = Dictionary(
            uniqueKeysWithValues: PartyGame.allCases.enumerated().map { index, game in
                (game, haerten[index % haerten.count])
            }
        )

        for (game, haerte) in erwartet {
            DrinkIntensity.store(haerte, for: game)
        }

        for (game, haerte) in erwartet {
            XCTAssertEqual(
                DrinkIntensity.stored(for: game), haerte,
                "\(game.title) liest die Härte eines anderen Spiels."
            )
        }
    }
}
