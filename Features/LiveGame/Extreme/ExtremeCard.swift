//
//  ExtremeCard.swift
//  BeerStats
//
//  Beerpong Extreme: Getroffene Becher sind Ereigniskarten.
//
//  Die wichtigste Entscheidung steht am Anfang und praegt alles Weitere:
//  Die Karten greifen NICHT ins Regelwerk ein. "Noch ein Ball" wird
//  angezeigt, nicht erzwungen. Die GameEngine bleibt unangetastet.
//
//  Das ist kein Sparen, sondern der bessere Handel. Die Engine ist das
//  getestete Herz der App, und ein Fehler dort betrifft auch das normale
//  Beerpong. Vor allem aber kann eine App "wirf mit geschlossenen Augen"
//  ohnehin nicht pruefen – waeren nur die technisch umsetzbaren Karten
//  erlaubt, fiele die Haelfte des Modus weg. So darf auf einer Karte alles
//  stehen, was am Tisch funktioniert.
//
//  Geladene Becher statt aller: Wie viele, entscheidet der Nutzer vor dem
//  Spiel (0 bis 10). Niemand weiss, welche es sind – dadurch steht bei
//  jedem Wurf etwas auf dem Spiel, statt dass die Karten zur Routine
//  werden. Bei 0 ist es normales Beerpong, bei 10 loest jeder Becher aus.
//
//  Trinkmengen laufen ueber `DrinkAmount`, deshalb wird das Deck bei jedem
//  Zug neu gebaut statt einmal als Konstante: Nur so greift die eingestellte
//  Haerte auch wirklich.
//

import SwiftUI

// MARK: - Kategorien

enum ExtremeCategory: String, CaseIterable {
    case penalty
    case challenge
    case boon
    case handicap
    case chaos

    var title: String {
        switch self {
        case .penalty: return "Strafe"
        case .challenge: return "Challenge"
        case .boon: return "Vorteil"
        case .handicap: return "Handicap"
        case .chaos: return "Chaos"
        }
    }

    var emoji: String {
        switch self {
        case .penalty: return "🥃"
        case .challenge: return "😈"
        case .boon: return "⚡️"
        case .handicap: return "🧊"
        case .chaos: return "🎲"
        }
    }

    /// Die Farbe ist die halbe Information: Am Aufblitzen sieht man schon,
    /// ob es gut oder schlecht wird, bevor man liest.
    var color: Color {
        switch self {
        case .penalty: return BeerStatsColor.error
        case .challenge: return ProfileColor.purple.color
        case .boon: return BeerStatsColor.success
        case .handicap: return ProfileColor.blue.color
        case .chaos: return BeerStatsColor.warning
        }
    }

    /// Wen es betrifft – steht klein ueber dem Text, damit am Tisch nicht
    /// diskutiert wird, wer jetzt gemeint ist.
    var target: String {
        switch self {
        case .penalty: return "Für dich"
        case .challenge: return "Für dich"
        case .boon: return "Für dein Team"
        case .handicap: return "Für den Gegner"
        case .chaos: return "Für alle"
        }
    }
}

// MARK: - Karte

struct ExtremeCard: Identifiable, Equatable {
    let id: String
    let category: ExtremeCategory
    let title: String
    let text: String
}

// MARK: - Einstellungen

enum ExtremeMode: String, CaseIterable {
    case normal
    case hard

    var title: String {
        switch self {
        case .normal: return "Normal"
        case .hard: return "Hard"
        }
    }

    var detail: String {
        switch self {
        case .normal: return "Trinken, Aufgaben, Vor- und Nachteile"
        // Nicht "zusätzlich": Die zahmen Karten fallen weg, statt sich nur
        // zu verdünnen. Das soll vorher klar sein.
        case .hard: return "Kleidung und derbe Aufgaben statt der zahmen Karten"
        }
    }
}

/// Wie viele Becher geladen sind und wie hart gespielt wird.
struct ExtremeSettings: Equatable {
    var loadedCups: Int
    var mode: ExtremeMode

    /// Ausgeschaltet – normales Beerpong ohne Karten.
    static let off = ExtremeSettings(loadedCups: 0, mode: .normal)

    var isEnabled: Bool { loadedCups > 0 }
}

// MARK: - Deck

enum ExtremeDeck {

    /// Zieht eine Karte. Das Deck wird bei jedem Zug neu gebaut, damit die
    /// eingestellte Trinkhaerte in den Texten steckt.
    static func draw(mode: ExtremeMode) -> ExtremeCard? {
        cards(for: mode).randomElement()
    }

    /// Drei Toepfe statt zwei.
    ///
    /// Naheliegend waere "normal + zusaetzliche harte Karten". Dann bliebe im
    /// Hard-Modus aber alles Zahme drin, und zwischen zwei derben Karten
    /// stuende weiter "sag jedem etwas Nettes". Das nimmt dem Modus genau
    /// das, wofuer man ihn einschaltet. Die harmlosen Karten verschwinden
    /// deshalb, statt sich nur zu verduennen.
    static func cards(for mode: ExtremeMode) -> [ExtremeCard] {
        switch mode {
        case .normal: return mildCards + coreCards
        case .hard: return coreCards + hardCards
        }
    }

    // MARK: Zahm – nur im Normal-Modus

    /// Karten, die im Hard-Modus bewusst NICHT mehr auftauchen.
    private static var mildCards: [ExtremeCard] {
        let small = DrinkAmount.sips(2)

        return [
            card(.penalty, "Nachbarschaft", "Deine beiden Nachbarn trinken \(small.text)."),
            card(.challenge, "Neuer Name", "Bis zum Ende der Runde hörst du nur auf einen Spitznamen, den der Gegner aussucht."),
            card(.challenge, "Stumm", "Bis zu deinem nächsten Wurf sagst du kein Wort."),
            card(.challenge, "Standbild", "Halte bis zum nächsten Treffer die Pose, die du gerade hast."),
            card(.challenge, "Komplimentzwang", "Sag jedem Gegner etwas Nettes. Zögern kostet \(small.text)."),
            card(.chaos, "Alle", "Der ganze Tisch trinkt \(small.text)."),
            // Die einzige Karte, die nichts tut – und deshalb wertvoll: Ohne
            // sie wäre jeder geladene Becher garantiert ein Ereignis.
            card(.chaos, "Rückkehr", "Der Becher bleibt stehen. Nichts passiert.")
        ]
    }

    // MARK: Kern – in beiden Modi

    private static var coreCards: [ExtremeCard] {
        let small = DrinkAmount.sips(2)
        let medium = DrinkAmount.sips(4)
        let shot = DrinkAmount.shot

        return [
            // Strafe
            card(.penalty, "Ex", "Der getroffene Becher wird sofort ausgetrunken."),
            card(.penalty, "Verteiler", "Du bestimmst, wer \(medium.text) trinkt."),
            card(.penalty, "Reihum", "Das ganze gegnerische Team trinkt \(small.text)."),
            card(.penalty, "Doppelt", "Dieser Becher zählt doppelt – \(medium.text) obendrauf."),
            card(.penalty, "Kurzer Prozess", "Trink \(shot.text) – ohne Diskussion."),
            card(.penalty, "Handysperre", "Wer als Letztes am Handy war, trinkt \(medium.text)."),

            // Vorteil
            card(.boon, "Nachschlag", "Du wirfst sofort noch einen Ball."),
            card(.boon, "Doppelwert", "Dein nächster Treffer nimmt zwei Becher."),
            card(.boon, "Griff", "Ein Becher deiner Wahl kommt zusätzlich weg."),
            card(.boon, "Freies Umstellen", "Ihr dürft sofort umstellen – zählt nicht gegen euer Kontingent."),
            card(.boon, "Geschenkt", "Balls Back, auch ohne beide getroffen zu haben."),
            card(.boon, "Ansage", "Der Gegner wirft den nächsten Ball aus doppelter Entfernung."),

            // Handicap
            card(.handicap, "Blind", "Der Gegner wirft die nächsten zwei Bälle mit geschlossenen Augen."),
            card(.handicap, "Schwache Hand", "Nächster Wurf des Gegners mit der anderen Hand."),
            card(.handicap, "Einbeinig", "Der Gegner wirft den nächsten Ball auf einem Bein."),
            card(.handicap, "Schweigen", "Kein Wort im nächsten Zug des Gegners. Wer redet, trinkt \(small.text)."),
            card(.handicap, "Rückhand", "Der Gegner wirft den nächsten Ball über die Schulter, mit dem Rücken zum Tisch."),

            // Chaos als laufende Regel statt als Platztausch: wirkt über
            // mehrere Züge und zwingt niemanden, aufzustehen.
            card(.chaos, "Handwechsel", "Bis der nächste Becher fällt, werfen alle mit der schwachen Hand."),
            card(.chaos, "Gedächtnislücke", "Ab jetzt heißt jeder Becher „Kelch“. Wer „Becher“ sagt, trinkt \(small.text)."),
            card(.chaos, "Stille Post", "Bis zum nächsten Treffer darf niemand den Namen eines anderen sagen."),
            card(.chaos, "Doppeltes Tempo", "Die nächste Runde wird ohne Pause geworfen – Ball holen und sofort weiter.")
        ]
    }

    // MARK: Hart – nur im Hard-Modus

    /// Bewusst eine eigene Liste und keine Markierung an der Karte: So sieht
    /// man beim Lesen des Codes sofort, was der Schalter freischaltet.
    private static var hardCards: [ExtremeCard] {
        let shot = DrinkAmount.shot
        let medium = DrinkAmount.sips(4)

        return [
            // Kleidung
            card(.challenge, "Ein Stück weniger", "Zieh ein Kleidungsstück aus. Socken zählen einzeln."),
            card(.challenge, "Zwei Stücke", "Zieh zwei Kleidungsstücke aus. Socken zählen einzeln."),
            card(.challenge, "Tausch", "Tausche ein Kleidungsstück mit einem Gegner."),
            card(.challenge, "Barfuß", "Schuhe und Socken aus – bis zum Ende der Partie."),
            card(.challenge, "Wahrheit oder Stoff", "Der Tisch stellt eine Frage. Keine Antwort kostet ein Kleidungsstück."),

            // Handy
            card(.challenge, "Letzte Nachricht", "Lies deine letzte verschickte Nachricht laut vor."),
            card(.challenge, "Letztes Foto", "Zeig dem Tisch das letzte Foto in deiner Galerie."),
            card(.challenge, "Chatverlauf", "Der Gegner sucht einen Chat aus. Lies die letzte Nachricht daraus vor."),
            card(.challenge, "Playlist", "Der Gegner sucht ein Lied auf deinem Handy aus. Es läuft bis zum Ende der Runde."),

            // Reden
            card(.challenge, "Peinlich", "Erzähl die peinlichste Geschichte, die dir gerade einfällt – oder trink \(shot.text)."),
            card(.challenge, "Ehrliche Antwort", "Der Gegner stellt eine Frage. Antworte ehrlich oder trink \(shot.text)."),
            card(.challenge, "Ex-Geschichte", "Erzähl, warum deine letzte Beziehung zu Ende ging – oder zieh ein Kleidungsstück aus."),

            // Körper
            card(.challenge, "Stehplatz", "Bis zum Ende der Partie darfst du dich nicht mehr hinsetzen."),

            // Strafe
            card(.penalty, "Doppelter Kurzer", "Zwei Shots. Such dir aus, wer den zweiten übernimmt."),
            card(.penalty, "Kettenreaktion", "Du trinkst \(medium.text) – und darfst dasselbe zweimal weitergeben."),
            card(.penalty, "Kopf an Kopf", "Du und ein Gegner deiner Wahl: beide \(shot.text), gleichzeitig."),

            // Chaos
            card(.chaos, "Doppelter Einsatz", "Bis du das nächste Mal triffst, zählt jede Strafe für dich doppelt."),
            card(.chaos, "Blindes Vertrauen", "Ein Gegner mischt deinen nächsten Becher aus dem, was auf dem Tisch steht.")
        ]
    }

    // MARK: Hilfen

    /// Die Kennung entsteht aus Kategorie und Titel. Das reicht, weil kein
    /// Titel doppelt vorkommt, und erspart eine Liste von Hand vergebener
    /// Nummern, die beim Einfuegen einer Karte auseinanderlaeuft.
    private static func card(
        _ category: ExtremeCategory,
        _ title: String,
        _ text: String
    ) -> ExtremeCard {
        ExtremeCard(
            id: "\(category.rawValue)-\(title)",
            category: category,
            title: title,
            text: text
        )
    }
}
