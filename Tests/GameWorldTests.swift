//
//  GameWorldTests.swift
//  BeerStatsTests
//
//  Haelt fest, was der Nutzer am 28. Oktober bemaengelt hat: dass jedes
//  Spiel gleich aussah. Ob eine Welt schoen ist, kann kein Test sagen – aber
//  dass keine zwei Spiele sich eine teilen und jede sich in einem eigenen
//  Satz beschreiben laesst, schon.
//

import XCTest
@testable import BeerStats

final class GameWorldTests: XCTestCase {

    /// Fuenfundzwanzig Spiele, fuenfundzwanzig Welten. Teilen sich zwei eine,
    /// sehen sie wieder gleich aus – genau das war der Fehler.
    func testEveryGameHasItsOwnWorld() {
        let welten = PartyGame.allCases.map(\.world)

        XCTAssertEqual(Set(welten).count, PartyGame.allCases.count, "Zwei Spiele teilen sich eine Welt")
    }

    /// Die Satz-Regel: Jede Welt laesst sich in einem Satz sagen, und kein
    /// Satz kommt zweimal vor.
    func testNoTwoWorldsShareASentence() {
        let saetze = GameWorld.allCases.map(\.look.sentence)

        XCTAssertEqual(Set(saetze).count, saetze.count)
        XCTAssertFalse(saetze.contains { $0.isEmpty })
    }

    /// ... und zwar ohne Emoji. Eine Welt, die sich nur ueber ihr Zeichen
    /// beschreiben laesst, unterscheidet sich auch nur durch ihr Zeichen.
    func testNoSentenceLeansOnAnEmoji() {
        for welt in GameWorld.allCases {
            XCTAssertFalse(
                welt.look.sentence.unicodeScalars.contains { $0.properties.isEmojiPresentation },
                "\(welt): \(welt.look.sentence)"
            )
        }
    }

    /// Abfahrtstafel und Stadion gehoeren zum Rahmen (Auslosen, Turnier),
    /// nicht zu einem Spiel – und jede andere Welt gehoert zu genau einem.
    func testEveryOtherWorldBelongsToExactlyOneGame() {
        let vonSpielen = Set(PartyGame.allCases.map(\.world))

        XCTAssertFalse(vonSpielen.contains(.departureBoard))
        XCTAssertFalse(vonSpielen.contains(.stadium))
        XCTAssertEqual(vonSpielen.count + 2, GameWorld.allCases.count, "Eine Welt haengt an keinem Spiel")
    }

    /// Gruen und Rot behalten in jeder Welt ihre Bedeutung – gut und
    /// schlecht, Treffer und Strafe. Nur die blosse Farbe des Spiels weicht
    /// der Welt.
    func testGoodAndBadKeepTheirColorInEveryWorld() {
        for welt in GameWorld.allCases {
            XCTAssertEqual(welt.edgeColor(for: BeerStatsColor.success), BeerStatsColor.success, "\(welt)")
            XCTAssertEqual(welt.edgeColor(for: BeerStatsColor.error), BeerStatsColor.error, "\(welt)")
            XCTAssertEqual(welt.edgeColor(for: BeerStatsColor.warning), welt.look.edge, "\(welt)")
        }
    }

    // MARK: - Hitparade: Farbe heisst Jahrzehnt

    /// Jedes Jahrzehnt im Stapel hat seine eigene Farbe. Zwei gleiche, und
    /// die Reihe im Regal sagte nicht mehr, was sie sagen soll.
    func testEveryDecadeInTheSongDeckHasItsOwnColor() {
        let jahrzehnte = Set(SongDeck.shuffled().map { $0.year / 10 * 10 }).sorted()
        XCTAssertGreaterThan(jahrzehnte.count, 1)

        for (i, a) in jahrzehnte.enumerated() {
            for b in jahrzehnte.dropFirst(i + 1) {
                XCTAssertNotEqual(RecordShelf.color(forYear: a), RecordShelf.color(forYear: b), "\(a) und \(b)")
            }
        }
    }

    /// Solange geraten wird, ist die Huelle schwarz – und schwarz darf kein
    /// Jahrzehnt sein, sonst verriete die neutrale Huelle doch etwas.
    func testTheBlankSleeveGivesNoDecadeAway() {
        for jahr in SongDeck.shuffled().map(\.year) {
            XCTAssertNotEqual(RecordShelf.color(forYear: jahr), RecordShelf.blankSleeve, "\(jahr)")
        }
    }

    /// Die Abfahrtstafel des Wuerfels bricht an Wortgrenzen – aber nur, wenn
    /// jedes Wort in eine Zeile passt. Sonst steht "REAKTIONSDUE" ueber
    /// "LL". Und mehr Zeilen, als die Tafel hat, liessen die Karte beim
    /// Wuerfeln huepfen.
    func testEveryTitleFitsTheDepartureBoard() {
        for game in PartyGame.allCases {
            let zeilen = DepartureBoard.lines(game.title, width: DepartureBoard.columns)
            let woerter = game.title.uppercased().split(separator: " ").joined(separator: " ")

            XCTAssertEqual(zeilen.joined(separator: " "), woerter, "\(game.title) bricht mitten im Wort")
            XCTAssertLessThanOrEqual(zeilen.count, DepartureBoard.rows, game.title)
        }
    }

    /// Der Umbruch selbst: an Wortgrenzen, und ein Wort, das allein zu lang
    /// ist, wird geteilt statt abgeschnitten.
    func testTheBoardBreaksAtWordsAndSplitsOnlyWhatCannotFit() {
        XCTAssertEqual(DepartureBoard.lines("Ich hab noch nie", width: 14), ["ICH HAB NOCH", "NIE"])
        XCTAssertEqual(DepartureBoard.lines("Reaktionsduell", width: 10), ["REAKTIONSD", "UELL"])
        XCTAssertEqual(DepartureBoard.lines("", width: 14), [""])
    }
}
