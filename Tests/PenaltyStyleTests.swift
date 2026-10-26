//
//  PenaltyStyleTests.swift
//  BeerStatsTests
//
//  Prueft, dass eine Runde ohne Alkohol wirklich spielbar ist.
//
//  Die Falle dabei ist nicht das Formulieren, sondern die GROESSE: Wenn
//  drei Schlücke und ein Shot dieselbe Aufgabe ergeben, ist die Abstufung
//  weg, die die Spiele ueberhaupt erst aufgebaut haben – ein Ass soll mehr
//  wehtun als eine Drei. Und wenn dieselbe Menge an zwei Stellen
//  verschieden heisst, ist es am Tisch ein Streit.
//
//  Die Haerte (`DrinkIntensity`) gilt hier bewusst NICHT: Sie rechnet
//  Schlücke um, und Liegestuetze sind keine. Deshalb darf sich der Text
//  nicht aendern, wenn jemand sie verstellt.
//

import XCTest
@testable import BeerStats

final class PenaltyStyleTests: XCTestCase {

    private var stilVorher: String?
    private var haerteVorher: String?

    override func setUp() {
        super.setUp()
        stilVorher = UserDefaults.standard.string(forKey: PenaltyStyle.storageKey)
        haerteVorher = UserDefaults.standard.string(forKey: DrinkIntensity.storageKey)
        UserDefaults.standard.removeObject(forKey: PenaltyStyle.storageKey)
        // Sonst haengt das Ergebnis davon ab, welcher Test vorher lief:
        // `DrinkIntensity.current` ist `active ?? standard`, und `active`
        // ueberlebt im Speicher.
        DrinkIntensity.clearActive()
    }

    override func tearDown() {
        setzeZurueck(stilVorher, forKey: PenaltyStyle.storageKey)
        setzeZurueck(haerteVorher, forKey: DrinkIntensity.storageKey)
        DrinkIntensity.clearActive()
        super.tearDown()
    }

    private func setzeZurueck(_ wert: String?, forKey key: String) {
        if let wert {
            UserDefaults.standard.set(wert, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Die Vorgabe

    /// Ohne Zutun bleibt alles, wie es war.
    func testTheDefaultIsStillDrinking() {
        XCTAssertEqual(PenaltyStyle.current, .drinks)
        XCTAssertTrue(DrinkAmount.sips(3).text.contains("Schlücke"))
    }

    // MARK: - Ohne Alkohol

    /// Jede Stufe sagt etwas anderes – sonst ist die Abstufung weg, die die
    /// Spiele aufgebaut haben.
    func testEveryStyleKeepsTheThreeSizes() {
        for stil in PenaltyStyle.allCases where stil != .drinks {
            PenaltyStyle.current = stil

            let klein = DrinkAmount.sips(1).text
            let mittel = DrinkAmount.sips(3).text
            let gross = DrinkAmount.shot.text

            XCTAssertNotEqual(klein, mittel, "\(stil.title): klein und mittel sind gleich")
            XCTAssertNotEqual(mittel, gross, "\(stil.title): mittel und gross sind gleich")
            XCTAssertFalse(klein.isEmpty, stil.title)
        }
    }

    /// Kein Wort vom Trinken, wenn nicht getrunken wird. Das ist der ganze
    /// Zweck: Wer faehrt, soll nicht dauernd lesen, dass er trinken soll.
    func testNothingTalksAboutDrinkingAnymore() {
        for stil in PenaltyStyle.allCases where stil != .drinks {
            PenaltyStyle.current = stil

            for menge in [DrinkAmount.sips(1), .sips(3), .sips(5), .shot] {
                let text = menge.text.lowercased()
                XCTAssertFalse(text.contains("schluck"), "\(stil.title): \(text)")
                XCTAssertFalse(text.contains("shot"), "\(stil.title): \(text)")
            }
        }
    }

    /// Ein Ass muss mehr wehtun als eine Drei – auch beim Sport.
    func testAShotStaysTheHardest() {
        PenaltyStyle.current = .sport
        XCTAssertNotEqual(DrinkAmount.shot.text, DrinkAmount.sips(1).text)

        PenaltyStyle.current = .kitty
        XCTAssertNotEqual(DrinkAmount.shot.text, DrinkAmount.sips(1).text)
    }

    /// Die Haerte rechnet Schlücke um. Liegestuetze sind keine – sie darf
    /// den Text also nicht veraendern, sonst haette eine Einstellung zwei
    /// Bedeutungen.
    func testTheIntensityDoesNotLeakIntoOtherCurrencies() {
        PenaltyStyle.current = .sport

        DrinkIntensity.standard = .mild
        let mild = DrinkAmount.sips(3).text
        DrinkIntensity.standard = .hard
        let hart = DrinkAmount.sips(3).text

        XCTAssertEqual(mild, hart)
    }

    // MARK: - Die Bilanz

    /// Gebucht wird in Schlucken, angezeigt in der gewaehlten Waehrung –
    /// und ein leerer Stand bleibt leer.
    func testTheTallySpeaksTheSameCurrency() {
        var person = EveningParticipant(id: "p1", name: "Lena", emoji: "🔥")
        person.sips = 4

        PenaltyStyle.current = .drinks
        XCTAssertTrue(person.tallyText(separator: ", ", whenEmpty: "nichts").contains("Schlücke"))

        PenaltyStyle.current = .sport
        let sport = person.tallyText(separator: ", ", whenEmpty: "nichts")
        XCTAssertTrue(sport.contains("Liegestütze"), sport)
        XCTAssertFalse(sport.contains("Schlücke"), sport)

        PenaltyStyle.current = .kitty
        XCTAssertTrue(person.tallyText(separator: ", ", whenEmpty: "nichts").contains("€"))
    }

    func testAnEmptyTallyStaysEmptyInEveryCurrency() {
        let person = EveningParticipant(id: "p1", name: "Lena", emoji: "🔥")

        for stil in PenaltyStyle.allCases {
            PenaltyStyle.current = stil
            XCTAssertEqual(
                person.tallyText(separator: ", ", whenEmpty: "noch nichts"),
                "noch nichts",
                stil.title
            )
        }
    }

    /// Ein Shot zaehlt wie fuenf Schluecke – dieselbe Umrechnung wie in
    /// `Evening.weight`. Sonst waere der Abend in einer Waehrung anders
    /// sortiert als in der anderen.
    func testAShotCountsAsFiveInTheTally() {
        PenaltyStyle.current = .sport

        var mitShot = EveningParticipant(id: "p1", name: "Lena", emoji: "🔥")
        mitShot.shots = 1

        var mitSchlucken = EveningParticipant(id: "p2", name: "Jan", emoji: "🐢")
        mitSchlucken.sips = 5

        XCTAssertEqual(
            mitShot.tallyText(separator: ", ", whenEmpty: "nichts"),
            mitSchlucken.tallyText(separator: ", ", whenEmpty: "nichts")
        )
    }

    /// Die Ueberschrift darf nicht "Trinkbilanz" sagen, wenn niemand
    /// trinkt.
    func testTheTallyTitleFollowsTheStyle() {
        PenaltyStyle.current = .drinks
        XCTAssertEqual(PenaltyStyle.current.tallyTitle, "TRINKBILANZ")

        PenaltyStyle.current = .task
        XCTAssertNotEqual(PenaltyStyle.current.tallyTitle, "TRINKBILANZ")
    }
}
