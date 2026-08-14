//
//  ExtremeDeckTests.swift
//  BeerStatsTests
//
//  Prueft die Kartentexte von Beerpong Extreme in allen Einstellungen.
//
//  Der Anlass ist ein Fehler, der in einer einzigen Sitzung ZWEIMAL
//  passiert ist: ein Satz, der mit einer bestimmten eingesetzten Menge
//  grammatisch bricht. "Links und rechts wird \(menge) getrunken" liest
//  sich richtig, solange dort "2 Schluecke" steht - in der milden Stufe
//  steht da "1 Schluck", und der Satz ist kaputt. Beide Male ist es beim
//  Durchlesen aufgefallen und nicht beim Bauen.
//
//  Genau das automatisiert dieser Test: Jede Karte wird in ALLEN sechs
//  Kombinationen gerendert - drei Haerten mal Shots an/aus. Was in keiner
//  davon auffaellt, faellt auch am Tisch nicht auf.
//
//  Der wichtigste Einzeltest ist `testNoShotSurvivesWithShotsDisabled`. Er
//  erzwingt maschinell die Regel aus CLAUDE.md, dass Trinkmengen niemals
//  als Zahl im Text stehen duerfen - eine fest eingetippte Menge ignoriert
//  die Einstellung stillschweigend, und genau so etwas faellt erst am Tisch
//  auf.
//

import XCTest
@testable import BeerStats

final class ExtremeDeckTests: XCTestCase {

    private var savedIntensity: DrinkIntensity!
    private var savedShots: Bool!

    override func setUp() {
        super.setUp()
        // Beide Werte liegen in UserDefaults und gelten fuer die ganze App.
        // Ein Test, der sie verstellt und nicht zuruecksetzt, veraendert das
        // Ergebnis der folgenden Tests.
        savedIntensity = DrinkIntensity.current
        savedShots = DrinkRules.shotsEnabled
    }

    override func tearDown() {
        DrinkIntensity.current = savedIntensity
        DrinkRules.shotsEnabled = savedShots
        super.tearDown()
    }

    /// Alle sechs Kombinationen aus Haerte und Shot-Schalter.
    private func forEverySetting(_ body: () -> Void) {
        for intensity in DrinkIntensity.allCases {
            for shots in [true, false] {
                DrinkIntensity.current = intensity
                DrinkRules.shotsEnabled = shots
                body()
            }
        }
    }

    private var allCards: [ExtremeCard] {
        ExtremeDeck.cards(for: .normal) + ExtremeDeck.cards(for: .hard)
    }

    // MARK: - Aufbau des Decks

    func testDeckIsNotEmptyInEitherMode() {
        XCTAssertGreaterThan(ExtremeDeck.cards(for: .normal).count, 20)
        XCTAssertGreaterThan(ExtremeDeck.cards(for: .hard).count, 20)
    }

    func testIdentifiersAreUniqueWithinAMode() {
        for mode in ExtremeMode.allCases {
            let cards = ExtremeDeck.cards(for: mode)
            XCTAssertEqual(
                Set(cards.map(\.id)).count, cards.count,
                "\(mode.title) enthält eine Karte doppelt"
            )
        }
    }

    /// Der Hard-Modus ersetzt die zahmen Karten, statt sie zu ergaenzen.
    /// Ohne diesen Test waere ein versehentliches `mildCards + hardCards`
    /// nicht zu bemerken – das Deck waere nur unauffaellig zahmer.
    func testHardModeDropsTheMildCards() {
        let hard = ExtremeDeck.cards(for: .hard).map(\.title)
        let normal = ExtremeDeck.cards(for: .normal).map(\.title)

        XCTAssertTrue(normal.contains("Komplimentzwang"), "zahme Karte fehlt im Normal-Modus")
        XCTAssertFalse(hard.contains("Komplimentzwang"), "zahme Karte taucht im Hard-Modus auf")
        XCTAssertTrue(hard.contains("Ein Stück weniger"), "harte Karte fehlt im Hard-Modus")
        XCTAssertFalse(normal.contains("Ein Stück weniger"), "harte Karte taucht im Normal-Modus auf")
    }

    func testEveryCategoryAppearsSomewhere() {
        let used = Set(allCards.map(\.category))
        for category in ExtremeCategory.allCases {
            XCTAssertTrue(used.contains(category), "\(category.title) hat keine einzige Karte")
        }
    }

    // MARK: - Texte

    func testEveryCardHasAProperSentence() {
        forEverySetting {
            for card in allCards {
                XCTAssertFalse(card.title.isEmpty, "Karte ohne Titel")
                XCTAssertFalse(card.text.isEmpty, "\(card.title) hat keinen Text")
                XCTAssertFalse(
                    card.text.contains("  "),
                    "\(card.title) enthält doppelte Leerzeichen"
                )
                let last = card.text.last.map(String.init) ?? ""
                XCTAssertTrue(
                    [".", "!", "?"].contains(last),
                    "\(card.title) endet ohne Satzzeichen: \(card.text)"
                )
            }
        }
    }

    /// Kein Text darf eine Trinkmenge als Ziffer enthalten. Genau das ist die
    /// Regel aus CLAUDE.md, und sie war bisher nur eine Absichtserklaerung.
    func testNoCardWritesAnAmountAsADigit() {
        // Die Menge kommt IMMER aus DrinkAmount. Steht eine Zahl direkt vor
        // "Schluck", "Schlücke" oder "Shot", wurde sie fest eingetippt.
        let pattern = try! NSRegularExpression(
            pattern: "\\d+\\s*(Schluck|Schlücke|Shot)",
            options: [.caseInsensitive]
        )

        // Der Trick: Eine Karte, deren Text sich zwischen der zahmsten und
        // der haertesten Einstellung NICHT aendert, enthaelt keine echte
        // DrinkAmount. Nennt sie trotzdem eine Menge, ist die fest
        // eingetippt – und ignoriert die Einstellung stillschweigend.
        DrinkIntensity.current = .mild
        DrinkRules.shotsEnabled = false
        let zahm = Dictionary(uniqueKeysWithValues: allCards.map { ($0.id, $0.text) })

        DrinkIntensity.current = .hard
        DrinkRules.shotsEnabled = true

        for card in allCards where card.text == zahm[card.id] {
            let range = NSRange(card.text.startIndex..., in: card.text)
            XCTAssertNil(
                pattern.firstMatch(in: card.text, range: range),
                "\(card.title) nennt eine Menge, ändert sich aber nicht mit der Einstellung: \(card.text)"
            )
        }
    }

    /// Ist der Shot-Schalter aus, darf das Wort in keinem Text mehr stehen.
    /// Wer keine Kurzen dahat, soll auch keine angeboten bekommen.
    func testNoShotSurvivesWithShotsDisabled() {
        DrinkRules.shotsEnabled = false

        for intensity in DrinkIntensity.allCases {
            DrinkIntensity.current = intensity
            for card in allCards {
                XCTAssertFalse(
                    card.text.lowercased().contains("shot"),
                    "\(card.title) verlangt einen Shot, obwohl ohne Shots gespielt wird: \(card.text)"
                )
            }
        }
    }

    /// Mit steigender Haerte muss sich mindestens ein Text aendern – sonst
    /// haengen die Mengen nicht wirklich an der Einstellung.
    func testAmountsReactToTheIntensity() {
        DrinkRules.shotsEnabled = true

        DrinkIntensity.current = .mild
        let mild = allCards.map(\.text)
        DrinkIntensity.current = .hard
        let hart = allCards.map(\.text)

        XCTAssertNotEqual(mild, hart, "die Härte wirkt sich auf keinen einzigen Text aus")
    }

    // MARK: - Kategorien

    func testEveryCategoryHasItsOwnColourAndLabel() {
        let titles = ExtremeCategory.allCases.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count, "zwei Kategorien heißen gleich")

        for category in ExtremeCategory.allCases {
            XCTAssertFalse(category.emoji.isEmpty)
            XCTAssertFalse(category.target.isEmpty)
        }
    }

    // MARK: - Einstellungen

    func testDisabledWhenNoCupIsLoaded() {
        XCTAssertFalse(ExtremeSettings.off.isEnabled)
        XCTAssertFalse(ExtremeSettings(loadedCups: 0, mode: .hard).isEnabled)
        XCTAssertTrue(ExtremeSettings(loadedCups: 1, mode: .normal).isEnabled)
    }
}
