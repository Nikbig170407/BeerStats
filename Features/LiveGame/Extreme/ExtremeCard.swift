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
        case .hard: return "Zusätzlich Kleidung und deutlich derbere Aufgaben"
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

    static func cards(for mode: ExtremeMode) -> [ExtremeCard] {
        var deck = normalCards
        if mode == .hard { deck += hardCards }
        return deck
    }

    // MARK: Normal

    private static var normalCards: [ExtremeCard] {
        let small = DrinkAmount.sips(2)
        let medium = DrinkAmount.sips(4)
        let shot = DrinkAmount.shot

        return [
            // Strafe
            card(.penalty, "Ex", "Der getroffene Becher wird sofort ausgetrunken."),
            card(.penalty, "Verteiler", "Du bestimmst, wer \(medium.text) trinkt."),
            card(.penalty, "Reihum", "Das ganze gegnerische Team trinkt \(small.text)."),
            card(.penalty, "Doppelt", "Dieser Becher zählt doppelt – \(medium.text) obendrauf."),
            card(.penalty, "Zuletzt gelacht", "Wer als Letztes gelacht hat, trinkt \(medium.text)."),
            card(.penalty, "Kurzer Prozess", "Trink \(shot.text) – ohne Diskussion."),
            // "Links und rechts wird X getrunken" bricht bei einem einzelnen
            // Schluck grammatisch weg. Der Satz muss mit jeder Menge aufgehen,
            // die DrinkAmount einsetzen kann – deshalb der Umbau auf ein
            // Subjekt im Plural.
            card(.penalty, "Nachbarschaft", "Deine beiden Nachbarn trinken \(small.text)."),
            card(.penalty, "Handysperre", "Wer als Letztes am Handy war, trinkt \(medium.text)."),

            // Challenge
            card(.challenge, "Falsett", "Bis zum nächsten Treffer redest du nur mit hoher Stimme."),
            card(.challenge, "Fünf Liegestütze", "Fünf Stück – oder \(shot.text)."),
            card(.challenge, "Nachgemacht", "Der ganze Tisch macht deine Siegerpose nach."),
            card(.challenge, "Neuer Name", "Bis zum Ende der Runde hörst du nur auf einen Spitznamen, den der Gegner aussucht."),
            card(.challenge, "Stumm", "Bis zu deinem nächsten Wurf sagst du kein Wort."),
            card(.challenge, "Standbild", "Halte bis zum nächsten Treffer die Pose, die du gerade hast."),
            card(.challenge, "Komplimentzwang", "Sag jedem Gegner etwas Nettes. Zögern kostet \(small.text)."),
            card(.challenge, "Akzent", "Bis zum nächsten Treffer sprichst du mit Akzent. Welchem, sagt der Gegner."),

            // Vorteil
            card(.boon, "Nachschlag", "Du wirfst sofort noch einen Ball."),
            card(.boon, "Doppelwert", "Dein nächster Treffer nimmt zwei Becher."),
            card(.boon, "Griff", "Ein Becher deiner Wahl kommt zusätzlich weg."),
            card(.boon, "Freies Umstellen", "Ihr dürft sofort umstellen – zählt nicht gegen euer Kontingent."),
            card(.boon, "Geschenkt", "Balls Back, auch ohne beide getroffen zu haben."),
            card(.boon, "Immunität", "Die nächste Karte, die euch trifft, dürft ihr weitergeben."),
            card(.boon, "Ansage", "Du bestimmst, aus welcher Entfernung der Gegner als Nächstes wirft."),

            // Handicap
            card(.handicap, "Blind", "Der Gegner wirft die nächsten zwei Bälle mit geschlossenen Augen."),
            card(.handicap, "Schwache Hand", "Nächster Wurf des Gegners mit der anderen Hand."),
            card(.handicap, "Einbeinig", "Der Gegner wirft den nächsten Ball auf einem Bein."),
            card(.handicap, "Kreisel", "Der Gegner dreht sich vor jedem Wurf einmal um sich selbst."),
            card(.handicap, "Schweigen", "Kein Wort im nächsten Zug des Gegners. Wer redet, trinkt \(small.text)."),
            card(.handicap, "Rückhand", "Der Gegner wirft den nächsten Ball über die Schulter, mit dem Rücken zum Tisch."),
            card(.handicap, "Publikum", "Alle anderen dürfen den Gegner beim nächsten Wurf ablenken – ohne ihn zu berühren."),

            // Chaos
            card(.chaos, "Rückkehr", "Der Becher bleibt stehen. Nichts passiert."),
            card(.chaos, "Platztausch", "Alle rücken einen Platz weiter."),
            card(.chaos, "Beutetausch", "Ihr tauscht einen vollen Becher mit dem Gegner."),
            card(.chaos, "Alle", "Der ganze Tisch trinkt \(small.text)."),
            card(.chaos, "Fremdbestimmt", "Der Gegner zieht deine nächste Karte – und liest sie vor."),
            card(.chaos, "Rollentausch", "Ihr tauscht für einen Zug die Teams.")
        ]
    }

    // MARK: Hard

    /// Kommen nur im Hard-Modus dazu. Bewusst als eigene Liste und nicht als
    /// Markierung an der Karte: So sieht man beim Lesen des Codes sofort,
    /// was der Schalter tatsaechlich freischaltet.
    private static var hardCards: [ExtremeCard] {
        let shot = DrinkAmount.shot
        let medium = DrinkAmount.sips(4)

        return [
            card(.challenge, "Ein Stück weniger", "Zieh ein Kleidungsstück aus. Socken zählen einzeln."),
            card(.challenge, "Tausch", "Tausche ein Kleidungsstück mit einem Gegner."),
            card(.challenge, "Barfuß", "Schuhe und Socken aus – bis zum Ende der Partie."),
            card(.challenge, "Oberteil", "Oberteil aus oder \(shot.text). Du entscheidest."),
            card(.challenge, "Fremdbestimmt angezogen", "Der Gegner sucht aus, welches Kleidungsstück du ausziehst."),
            card(.challenge, "Peinlich", "Erzähl die peinlichste Geschichte, die dir gerade einfällt – oder \(shot.text)."),
            card(.challenge, "Letzte Nachricht", "Lies deine letzte verschickte Nachricht laut vor."),
            card(.challenge, "Ehrliche Antwort", "Der Gegner stellt eine Frage. Antworte ehrlich oder trink \(shot.text)."),
            card(.penalty, "Doppelter Kurzer", "Zwei Shots. Such dir aus, wer den zweiten übernimmt."),
            card(.penalty, "Kettenreaktion", "Du trinkst \(medium.text) – und darfst dasselbe zweimal weitergeben.")
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
