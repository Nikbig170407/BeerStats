//
//  DeckContentTests.swift
//  BeerStatsTests
//
//  Prueft die Kartenstapel selbst – nicht die Spiele, die sie benutzen.
//
//  Inhalt ist der Teil der App, der am haeufigsten waechst und am
//  seltensten geprueft wird. Beim Nachlegen passieren immer dieselben zwei
//  Dinge, und keines faellt beim Spielen sofort auf:
//
//  Eine Karte steht zweimal drin. Am Tisch denkt man "hatten wir die nicht
//  schon?" und spielt weiter – gemerkt hat es niemand, und der Stapel ist
//  stillschweigend kleiner als er aussieht. Das ist das Gegenteil von dem,
//  wozu man Karten nachlegt.
//
//  Oder eine Karte passt nicht in ihre Form: ein ganzer Satz, wo ein Begriff
//  stehen muss ("Wer bin ich?" ist mit einem Satz an der Stirn nicht
//  spielbar), ein Nachsatz, wo ein ganzer Satz stehen muss ("Ich hab noch
//  nie" braucht das Verb auf der Karte, siehe CLAUDE.md), zwei Woerter, wo
//  eines verboten werden soll.
//
//  Die Mindestzahlen stehen bewusst unter dem tatsaechlichen Stand: Sie
//  sollen ein versehentliches Loeschen merken, nicht jedes Nachlegen zu
//  einer Testaenderung machen.
//

import XCTest
@testable import BeerStats

final class DeckContentTests: XCTestCase {

    private var gesichert: [String: [String]?] = [:]

    /// Eigene und ausgeblendete Karten wuerden die Stapel veraendern –
    /// fuer diese Tests muessen die rohen Listen gelten.
    override func setUp() {
        super.setUp()
        for deck in CustomCardDeck.allCases {
            for key in [CustomCards.storageKey(for: deck), HiddenCards.storageKey(for: deck)] {
                gesichert[key] = UserDefaults.standard.stringArray(forKey: key)
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
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
        super.tearDown()
    }

    // MARK: - Helfer

    private func pruefe(_ name: String, _ eintraege: [String], mindestens: Int) {
        XCTAssertGreaterThanOrEqual(
            eintraege.count, mindestens,
            "\(name) hat nur \(eintraege.count) Einträge – wurde etwas gelöscht?"
        )

        let doppelt = Set(eintraege.filter { eintrag in eintraege.filter { $0 == eintrag }.count > 1 })
        XCTAssertTrue(doppelt.isEmpty, "\(name) enthält doppelte Karten: \(doppelt.sorted())")

        for eintrag in eintraege {
            XCTAssertFalse(eintrag.isEmpty, "\(name) enthält eine leere Karte")
            XCTAssertEqual(
                eintrag, eintrag.trimmingCharacters(in: .whitespacesAndNewlines),
                "\(name): „\(eintrag)“ hat Leerzeichen am Rand"
            )
            XCTAssertFalse(eintrag.contains("  "), "\(name): „\(eintrag)“ hat doppelte Leerzeichen")
        }
    }

    // MARK: - Die Stapel

    func testEveryDeckIsFullAndFreeOfDuplicates() {
        pruefe("Wer würde eher?", MostLikelyDeck.all.map(\.text), mindestens: 90)
        pruefe("Zwei Wahrheiten", TwoTruthsDeck.all, mindestens: 55)
        pruefe("Trinkbingo", BingoDeck.all, mindestens: 60)
        pruefe("Verbotene Wörter", ForbiddenWordDeck.all, mindestens: 70)
        pruefe("Der Spion", SpyDeck.all, mindestens: 110)
        pruefe("Kategorien", CategoryDeck.all, mindestens: 85)
        pruefe("Schätzmeister", EstimationDeck.all.map(\.text), mindestens: 75)
        pruefe("Ich hab noch nie", NeverHaveIEverDeck.statements.map(\.text), mindestens: 480)

        pruefe("Regel des Abends", EveningRuleDeck.all, mindestens: 38)

        for kategorie in HeadsUpCategory.allCases {
            pruefe("Wer bin ich? – \(kategorie.title)", HeadsUpDeck.shuffled(kategorie), mindestens: 60)
        }

        for art in TruthOrDareKind.allCases {
            // Die Kennung ist der Text VOR dem Einsetzen der Trinkmenge –
            // zwei Karten, die sich nur in der Menge unterscheiden, sind
            // trotzdem zwei verschiedene.
            pruefe("Wahrheit oder Pflicht – \(art.title)", TruthOrDareDeck.shuffled(art).map(\.key), mindestens: 60)
        }
    }

    // MARK: - Die Form

    /// Jede Aussage traegt den ganzen Satz, nicht nur den Nachsatz. Ein
    /// fester Vorspann kann grammatisch nicht aufgehen: Es gibt „Ich hab",
    /// „Ich bin", „Ich hatte" und „Ich war".
    func testEveryStatementCarriesItsOwnVerb() {
        for karte in NeverHaveIEverDeck.statements {
            XCTAssertTrue(
                karte.text.hasPrefix("Ich "),
                "Fängt nicht mit „Ich“ an: \(karte.text)"
            )
            XCTAssertTrue(
                karte.text.contains(" noch nie") || karte.text.contains(" nie "),
                "Sagt nicht, dass es nie passiert ist: \(karte.text)"
            )
        }
    }

    /// Jede Kategorie traegt eine Runde fuer sich: Wer nur „Abenteuer“
    /// ankreuzt, soll nicht nach zwanzig Karten durch sein. Und eine
    /// Kategorie ohne Fragen waere ein Haken, der nichts tut.
    func testEveryNeverHaveIEverCategoryCarriesARoundOfItsOwn() {
        for kategorie in NeverHaveIEverCategory.allCases {
            XCTAssertGreaterThanOrEqual(
                NeverHaveIEverDeck.questionCount(for: kategorie), 40,
                "\(kategorie.title) ist zu dünn für eine eigene Runde"
            )
        }
    }

    /// Titel, Zeichen und Untertitel unterscheiden die Kategorien im
    /// Vorspann – zwei gleiche wären zwei Haken, zwischen denen niemand
    /// wählen kann. Und beide Richtungen müssen vorkommen, sonst ist eine
    /// der Überschriften leer.
    func testNeverHaveIEverCategoriesCanBeToldApart() {
        let alle = NeverHaveIEverCategory.allCases

        XCTAssertEqual(Set(alle.map(\.title)).count, alle.count)
        XCTAssertEqual(Set(alle.map(\.emoji)).count, alle.count)
        XCTAssertEqual(Set(alle.map(\.subtitle)).count, alle.count)
        for richtung in NeverHaveIEverCategory.Direction.allCases {
            XCTAssertGreaterThanOrEqual(alle.filter { $0.direction == richtung }.count, 2, "\(richtung.title)")
        }
    }

    /// Ein verbotenes Wort ist ein Wort. Zwei Wörter wären eine Wendung, und
    /// am Tisch gäbe es Streit darüber, ob sie gefallen ist.
    func testForbiddenWordsAreSingleWords() {
        for wort in ForbiddenWordDeck.all {
            XCTAssertFalse(wort.contains(" "), "Kein einzelnes Wort: \(wort)")
        }
    }

    /// Begriffe für „Wer bin ich?" müssen an die Stirn passen: kurz, ohne
    /// Satzzeichen am Ende. Ein ganzer Satz lässt sich nicht erraten.
    func testHeadsUpTermsAreShort() {
        for kategorie in HeadsUpCategory.allCases {
            for begriff in HeadsUpDeck.shuffled(kategorie) {
                XCTAssertLessThanOrEqual(
                    begriff.count, 24,
                    "Zu lang für die Stirn: \(begriff)"
                )
                // Der Punkt am Ende trennt Satz von Begriff – ausser bei
                // Abkuerzungen wie "E.T.", und die haben kein Leerzeichen.
                if begriff.contains(" ") {
                    XCTAssertFalse(
                        [".", "!", "?"].contains(begriff.suffix(1)),
                        "Ist ein Satz, kein Begriff: \(begriff)"
                    )
                }
            }
        }
    }

    /// Die Schätzfragen sind eine Frage mit einer Zahl als Antwort – und die
    /// Antwort muss positiv sein, sonst ist „am weitesten daneben" nicht
    /// mehr zu rechnen.
    func testEstimationQuestionsAskForANumber() {
        for frage in EstimationDeck.all {
            XCTAssertTrue(frage.text.hasSuffix("?"), "Keine Frage: \(frage.text)")
            XCTAssertGreaterThan(frage.answer, 0, "Antwort ist nicht positiv: \(frage.text)")
            XCTAssertFalse(frage.answerText.isEmpty, "Antwort ohne Text: \(frage.text)")
        }
    }

    /// Eine Regel des Abends muss am Tisch nachweisbar sein – und dafuer
    /// ueberhaupt erst ein Satz, keine Stimmung. Geprueft wird die Form:
    /// kein Punkt am Ende (sie steht als Karte da, nicht als Fliesstext)
    /// und mehr als ein Wort. „Leise" ist keine Regel, „Alle reden im
    /// Fluesterton" ist eine.
    func testEveryRuleIsASentence() {
        for regel in EveningRuleDeck.all {
            XCTAssertFalse(
                [".", "!"].contains(regel.suffix(1)),
                "Regel endet wie Fließtext: \(regel)"
            )
            XCTAssertGreaterThanOrEqual(
                regel.split(separator: " ").count, 3,
                "Zu kurz für eine Regel: \(regel)"
            )
        }
    }

    /// Gezogen wird nur, was noch nicht gilt – sonst steht dieselbe Regel
    /// zweimal am Tisch und die Runde haelt es fuer einen Fehler.
    func testDrawingSkipsRulesThatAlreadyApply() {
        let bereitsAktiv = Array(EveningRuleDeck.all.dropLast())
        let gezogen = EveningRuleDeck.draw(excluding: bereitsAktiv)
        XCTAssertEqual(gezogen, EveningRuleDeck.all.last)
    }

    /// Die Zahl im Untertitel wird gerechnet, nicht getippt. Dieser Test
    /// hält fest, dass das so bleibt: Stünde dort wieder eine feste Zahl,
    /// wäre sie beim nächsten Kartensatz falsch.
    func testTheSubtitlesNameTheRealDeckSize() {
        let karten = TruthOrDareDeck.count(.truth) + TruthOrDareDeck.count(.dare)
        XCTAssertTrue(
            PartyGame.truthOrDare.subtitle.contains("\(karten) Karten"),
            PartyGame.truthOrDare.subtitle
        )
        XCTAssertTrue(
            PartyGame.neverHaveIEver.subtitle.contains("\(NeverHaveIEverDeck.statements.count) Fragen"),
            PartyGame.neverHaveIEver.subtitle
        )
        XCTAssertTrue(
            PartyGame.estimation.subtitle.contains("\(EstimationDeck.count) Fragen"),
            PartyGame.estimation.subtitle
        )
        XCTAssertTrue(
            PartyGame.eveningRule.subtitle.contains("\(EveningRuleDeck.count) Regeln"),
            PartyGame.eveningRule.subtitle
        )
    }
}
