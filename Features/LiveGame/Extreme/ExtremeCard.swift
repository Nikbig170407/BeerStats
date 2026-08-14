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
        // Eigene Karten gelten in beiden Modi. Sie nach zahm und hart zu
        // sortieren waere eine Frage, die beim Eintippen niemand beantworten
        // will - und wer sie selbst geschrieben hat, weiss ohnehin, was
        // drinsteht.
        let eigene = CustomCards.cards(for: .extremeChallenge).enumerated().map { index, text in
            ExtremeCard(
                id: "custom-\(index)",
                category: .challenge,
                title: "Eure Karte",
                text: text
            )
        }

        let stapel: [ExtremeCard]
        switch mode {
        case .normal: stapel = mildCards + coreCards + eigene
        case .hard: stapel = coreCards + hardCards + eigene
        }

        // Was der Tisch weggedaumt hat, kommt nicht wieder. Ueber die Kennung
        // und nicht ueber den Text: Der traegt bei vielen Karten eine
        // Trinkmenge, die sich mit der Haerte aendert.
        let versteckt = HiddenCards.keys(for: .extremeChallenge)
        guard !versteckt.isEmpty else { return stapel }

        let uebrig = stapel.filter { !versteckt.contains($0.id) }
        // Ein leerer Stapel waere schlimmer als eine unbeliebte Karte: Der
        // Modus liefe dann stumm ohne Ereignisse weiter.
        return uebrig.isEmpty ? stapel : uebrig
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
            card(.chaos, "Rückkehr", "Der Becher bleibt stehen. Nichts passiert."),
            card(.chaos, "Anstoßen", "Alle stoßen an, bevor weitergeworfen wird."),
            card(.challenge, "Kurze Ansage", "Halt eine Rede über den Becher, den du gerade getroffen hast. Zehn Sekunden.")
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
            card(.penalty, "Solidarität", "Dein ganzes Team trinkt \(small.text) – gleichzeitig."),
            card(.penalty, "Der Wirt", "Such dir zwei Leute aus. Beide trinken \(small.text)."),
            // Setzt die Trinkbilanz des Abends voraus, funktioniert aber auch
            // ohne: Dann einigt ihr euch, wer bisher am wenigsten abbekommen
            // hat. Streit darüber ist Teil des Spiels.
            card(.penalty, "Ausgleich", "Wer heute am wenigsten getrunken hat, trinkt \(medium.text)."),
            card(.penalty, "Letzter Treffer", "Wer den letzten Becher getroffen hat, trinkt \(small.text)."),

            // Vorteil
            card(.boon, "Nachschlag", "Du wirfst sofort noch einen Ball."),
            card(.boon, "Doppelwert", "Dein nächster Treffer nimmt zwei Becher."),
            card(.boon, "Griff", "Ein Becher deiner Wahl kommt zusätzlich weg."),
            card(.boon, "Freies Umstellen", "Ihr dürft sofort umstellen – zählt nicht gegen euer Kontingent."),
            card(.boon, "Geschenkt", "Balls Back, auch ohne beide getroffen zu haben."),
            card(.boon, "Ansage", "Der Gegner wirft den nächsten Ball aus doppelter Entfernung."),
            card(.boon, "Zweite Chance", "Verfehlst du den nächsten Ball, darfst du ihn nochmal werfen."),
            card(.boon, "Kantengold", "Bei deinem nächsten Wurf zählt auch ein Treffer auf den Rand."),
            card(.boon, "Aufräumen", "Stellt eure Becher um, wie ihr wollt – ohne feste Formation."),
            card(.boon, "Freispruch", "Die nächste Strafe, die dich trifft, entfällt."),

            // Handicap
            card(.handicap, "Blind", "Der Gegner wirft die nächsten zwei Bälle mit geschlossenen Augen."),
            card(.handicap, "Schwache Hand", "Nächster Wurf des Gegners mit der anderen Hand."),
            card(.handicap, "Einbeinig", "Der Gegner wirft den nächsten Ball auf einem Bein."),
            card(.handicap, "Schweigen", "Kein Wort im nächsten Zug des Gegners. Wer redet, trinkt \(small.text)."),
            card(.handicap, "Rückhand", "Der Gegner wirft den nächsten Ball über die Schulter, mit dem Rücken zum Tisch."),
            card(.handicap, "Im Sitzen", "Der Gegner wirft den nächsten Ball im Sitzen."),
            card(.handicap, "Zeitdruck", "Der Gegner hat drei Sekunden für den nächsten Wurf. Danach zählt er als daneben."),
            card(.handicap, "Faust", "Der Gegner wirft den nächsten Ball aus der Faust, nicht aus den Fingerspitzen."),
            card(.handicap, "Augenkontakt", "Der Gegner sieht dich an, während er wirft – nicht den Becher."),
            card(.handicap, "Vollbepackt", "Der Gegner hält beim nächsten Wurf sein Getränk in der anderen Hand."),

            // Chaos als laufende Regel statt als Platztausch: wirkt über
            // mehrere Züge und zwingt niemanden, aufzustehen.
            card(.chaos, "Handwechsel", "Bis der nächste Becher fällt, werfen alle mit der schwachen Hand."),
            card(.chaos, "Gedächtnislücke", "Ab jetzt heißt jeder Becher „Kelch“. Wer „Becher“ sagt, trinkt \(small.text)."),
            card(.chaos, "Stille Post", "Bis zum nächsten Treffer darf niemand den Namen eines anderen sagen."),
            card(.chaos, "Doppeltes Tempo", "Die nächste Runde wird ohne Pause geworfen – Ball holen und sofort weiter."),
            card(.chaos, "Namenlos", "Ab jetzt heißt jeder „Chef“. Wer einen echten Namen sagt, trinkt \(small.text)."),
            card(.chaos, "Applaus", "Bis der nächste Becher fällt, klatschen alle nach jedem Treffer. Wer vergisst, trinkt \(small.text)."),
            card(.chaos, "Fluch", "Der Gegner sucht ein Wort aus. Wer es bis zum nächsten Treffer sagt, trinkt \(small.text)."),
            card(.chaos, "Schwache Hand am Glas", "Bis der nächste Becher fällt, hält jeder sein Getränk in der schwachen Hand.")
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
            card(.penalty, "Doppelter Kurzer", "Trink \(shot.text). Dann such dir jemanden, der dasselbe tut."),
            card(.penalty, "Kettenreaktion", "Du trinkst \(medium.text) – und darfst dasselbe zweimal weitergeben."),
            card(.penalty, "Kopf an Kopf", "Du und ein Gegner deiner Wahl: beide \(shot.text), gleichzeitig."),

            // Chaos
            card(.chaos, "Doppelter Einsatz", "Bis du das nächste Mal triffst, zählt jede Strafe für dich doppelt."),
            card(.chaos, "Blindes Vertrauen", "Ein Gegner mischt deinen nächsten Becher aus dem, was auf dem Tisch steht."),

            // Handy – dieselbe Sorte wie "Letztes Foto", weil die am Tisch am
            // besten funktioniert hat: Es kostet Überwindung, aber niemand
            // muss aufstehen oder sich etwas merken.
            card(.challenge, "Suchverlauf", "Zeig den letzten Eintrag in deinem Suchverlauf."),
            card(.challenge, "Bildschirmzeit", "Zeig dem Tisch deine Bildschirmzeit von gestern."),
            card(.challenge, "Kontakt", "Der Gegner sucht einen Kontakt aus. Erzähl, wer das ist."),

            // Reden
            card(.challenge, "Rangliste", "Sag ehrlich, wen am Tisch du zuletzt kennengelernt hast – und was du zuerst gedacht hast."),
            card(.challenge, "Beichte", "Erzähl etwas, das hier noch niemand von dir weiß – oder trink \(shot.text)."),
            card(.challenge, "Letzte Ausrede", "Wofür hast du dich zuletzt herausgeredet? Erzähl es, oder trink \(shot.text)."),

            // Kleidung
            card(.challenge, "Alles zurück", "Zieh ein Kleidungsstück wieder an – wenn keins ausliegt, trink \(medium.text).")
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
