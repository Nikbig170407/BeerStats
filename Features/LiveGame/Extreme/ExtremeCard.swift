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

    /// Wie lange die Karte gilt – „Bis zum nächsten Treffer", „Zehn
    /// Sekunden". `nil` heißt: sofort erledigt, danach ist es vorbei.
    ///
    /// Als eigenes Feld und nicht im Text: Es stand mal drin, mal nicht, und
    /// am Tisch wurde dann darüber diskutiert statt geworfen. Jetzt steht die
    /// Antwort auf jeder Karte an derselben Stelle – auch die Antwort
    /// „sofort".
    let duration: String?

    /// Was es kostet, die Aufgabe nicht zu machen oder die Regel zu brechen.
    ///
    /// `nil` heißt: Es gibt nichts zu brechen. Eine reine Trinkstrafe ist
    /// mit dem Trinken erledigt, ein Vorteil erst recht. Eine erfundene
    /// Strafe stünde dort nur, damit das Feld gefüllt ist.
    let penalty: String?
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
                text: text,
                // Wie lange eine selbst geschriebene Aufgabe gilt, weiss nur,
                // wer sie geschrieben hat. Die Strafe fuers Verweigern ist
                // dagegen dieselbe wie ueberall.
                duration: nil,
                penalty: DrinkAmount.sips(4).text
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
            card(.challenge, "Neuer Name", "Der Gegner sucht dir einen Spitznamen aus. Du hörst nur noch darauf.",
                 duration: "Bis zum Ende der Runde", penalty: small.text),
            card(.challenge, "Stumm", "Du sagst kein Wort.",
                 duration: "Bis zu deinem nächsten Wurf", penalty: small.text),
            card(.challenge, "Standbild", "Halte die Pose, die du gerade hast.",
                 duration: "Bis zum nächsten Treffer", penalty: small.text),
            card(.challenge, "Komplimentzwang", "Sag jedem Gegner etwas Nettes.",
                 duration: "Reihum, sofort", penalty: small.text),
            card(.chaos, "Alle", "Der ganze Tisch trinkt \(small.text)."),
            // Die einzige Karte, die nichts tut – und deshalb wertvoll: Ohne
            // sie wäre jeder geladene Becher garantiert ein Ereignis.
            card(.chaos, "Rückkehr", "Der Becher bleibt stehen. Nichts passiert."),
            card(.chaos, "Anstoßen", "Alle stoßen an, bevor weitergeworfen wird."),
            card(.challenge, "Kurze Ansage", "Halt eine Rede über den Becher, den du gerade getroffen hast.",
                 duration: "Zehn Sekunden", penalty: small.text)
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
            card(.boon, "Doppelwert", "Dein nächster Treffer nimmt zwei Becher.",
                 duration: "Bis zu deinem nächsten Treffer"),
            card(.boon, "Griff", "Ein Becher deiner Wahl kommt zusätzlich weg."),
            card(.boon, "Freies Umstellen", "Ihr dürft sofort umstellen – zählt nicht gegen euer Kontingent."),
            card(.boon, "Geschenkt", "Balls Back, auch ohne beide getroffen zu haben."),
            card(.boon, "Ansage", "Der Gegner wirft den nächsten Ball aus doppelter Entfernung."),
            card(.boon, "Zweite Chance", "Verfehlst du den nächsten Ball, darfst du ihn nochmal werfen.",
                 duration: "Ein Wurf"),
            card(.boon, "Kantengold", "Auch ein Treffer auf den Rand zählt.",
                 duration: "Dein nächster Wurf"),
            card(.boon, "Aufräumen", "Stellt eure Becher um, wie ihr wollt – ohne feste Formation."),
            card(.boon, "Freispruch", "Die nächste Strafe, die dich trifft, entfällt.",
                 duration: "Bis sie greift"),

            // Handicap
            card(.handicap, "Blind", "Der Gegner wirft mit geschlossenen Augen.",
                 duration: "Zwei Bälle", penalty: medium.text),
            card(.handicap, "Schwache Hand", "Der Gegner wirft mit der anderen Hand.",
                 duration: "Ein Wurf", penalty: medium.text),
            card(.handicap, "Einbeinig", "Der Gegner wirft auf einem Bein.",
                 duration: "Ein Wurf", penalty: medium.text),
            card(.handicap, "Schweigen", "Kein Wort im gegnerischen Team.",
                 duration: "Der nächste Zug des Gegners", penalty: small.text),
            card(.handicap, "Rückhand", "Der Gegner wirft über die Schulter, mit dem Rücken zum Tisch.",
                 duration: "Ein Wurf", penalty: medium.text),
            card(.handicap, "Im Sitzen", "Der Gegner wirft im Sitzen.",
                 duration: "Ein Wurf", penalty: medium.text),
            card(.handicap, "Zeitdruck", "Der Gegner hat drei Sekunden. Danach zählt der Wurf als daneben.",
                 duration: "Ein Wurf"),
            card(.handicap, "Faust", "Der Gegner wirft aus der Faust, nicht aus den Fingerspitzen.",
                 duration: "Ein Wurf", penalty: medium.text),
            card(.handicap, "Augenkontakt", "Der Gegner sieht dich an, während er wirft – nicht den Becher.",
                 duration: "Ein Wurf", penalty: medium.text),
            card(.handicap, "Vollbepackt", "Der Gegner hält sein Getränk in der anderen Hand.",
                 duration: "Ein Wurf", penalty: medium.text),

            // Chaos als laufende Regel statt als Platztausch: wirkt über
            // mehrere Züge und zwingt niemanden, aufzustehen.
            card(.chaos, "Handwechsel", "Alle werfen mit der schwachen Hand.",
                 duration: "Bis der nächste Becher fällt", penalty: small.text),
            card(.chaos, "Gedächtnislücke", "Jeder Becher heißt ab jetzt „Kelch“.",
                 duration: "Bis zum Ende der Partie", penalty: small.text),
            card(.chaos, "Stille Post", "Niemand darf den Namen eines anderen sagen.",
                 duration: "Bis zum nächsten Treffer", penalty: small.text),
            card(.chaos, "Doppeltes Tempo", "Ohne Pause werfen – Ball holen und sofort weiter.",
                 duration: "Die nächste Runde", penalty: small.text),
            card(.chaos, "Namenlos", "Ab jetzt heißt jeder „Chef“.",
                 duration: "Bis zum Ende der Partie", penalty: small.text),
            card(.chaos, "Applaus", "Alle klatschen nach jedem Treffer.",
                 duration: "Bis der nächste Becher fällt", penalty: small.text),
            card(.chaos, "Fluch", "Der Gegner sucht ein Wort aus. Sagt es niemand mehr.",
                 duration: "Bis zum nächsten Treffer", penalty: small.text),
            card(.chaos, "Schwache Hand am Glas", "Jeder hält sein Getränk in der schwachen Hand.",
                 duration: "Bis der nächste Becher fällt", penalty: small.text)
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
            card(.challenge, "Ein Stück weniger", "Zieh ein Kleidungsstück aus. Socken zählen einzeln.",
                 penalty: shot.text),
            card(.challenge, "Zwei Stücke", "Zieh zwei Kleidungsstücke aus. Socken zählen einzeln.",
                 penalty: shot.text),
            card(.challenge, "Tausch", "Tausche ein Kleidungsstück mit einem Gegner.",
                 penalty: shot.text),
            card(.challenge, "Barfuß", "Schuhe und Socken aus.",
                 duration: "Bis zum Ende der Partie", penalty: shot.text),
            card(.challenge, "Wahrheit oder Stoff", "Der Tisch stellt eine Frage. Antworte ehrlich.",
                 penalty: "Ein Kleidungsstück"),

            // Handy
            card(.challenge, "Letzte Nachricht", "Lies deine letzte verschickte Nachricht laut vor.",
                 penalty: shot.text),
            card(.challenge, "Letztes Foto", "Zeig dem Tisch das letzte Foto in deiner Galerie.",
                 penalty: shot.text),
            card(.challenge, "Chatverlauf", "Der Gegner sucht einen Chat aus. Lies die letzte Nachricht daraus vor.",
                 penalty: shot.text),
            card(.challenge, "Playlist", "Der Gegner sucht ein Lied auf deinem Handy aus. Es läuft.",
                 duration: "Bis zum Ende der Runde", penalty: shot.text),

            // Reden
            card(.challenge, "Peinlich", "Erzähl die peinlichste Geschichte, die dir gerade einfällt.",
                 penalty: shot.text),
            card(.challenge, "Ehrliche Antwort", "Der Gegner stellt eine Frage. Antworte ehrlich.",
                 penalty: shot.text),
            card(.challenge, "Ex-Geschichte", "Erzähl, warum deine letzte Beziehung zu Ende ging.",
                 penalty: "Ein Kleidungsstück"),

            // Körper
            card(.challenge, "Stehplatz", "Du darfst dich nicht mehr hinsetzen.",
                 duration: "Bis zum Ende der Partie", penalty: shot.text),

            // Strafe
            card(.penalty, "Doppelter Kurzer", "Trink \(shot.text). Dann such dir jemanden, der dasselbe tut."),
            card(.penalty, "Kettenreaktion", "Du trinkst \(medium.text) – und darfst dasselbe zweimal weitergeben."),
            card(.penalty, "Kopf an Kopf", "Du und ein Gegner deiner Wahl: beide \(shot.text), gleichzeitig."),

            // Chaos
            card(.chaos, "Doppelter Einsatz", "Jede Strafe zählt für dich doppelt.",
                 duration: "Bis du das nächste Mal triffst"),
            card(.chaos, "Blindes Vertrauen", "Ein Gegner mischt deinen nächsten Becher aus dem, was auf dem Tisch steht."),

            // Handy – dieselbe Sorte wie "Letztes Foto", weil die am Tisch am
            // besten funktioniert hat: Es kostet Überwindung, aber niemand
            // muss aufstehen oder sich etwas merken.
            card(.challenge, "Suchverlauf", "Zeig den letzten Eintrag in deinem Suchverlauf.",
                 penalty: shot.text),
            card(.challenge, "Bildschirmzeit", "Zeig dem Tisch deine Bildschirmzeit von gestern.",
                 penalty: shot.text),
            card(.challenge, "Kontakt", "Der Gegner sucht einen Kontakt aus. Erzähl, wer das ist.",
                 penalty: shot.text),

            // Reden
            card(.challenge, "Rangliste", "Sag ehrlich, wen am Tisch du zuletzt kennengelernt hast – und was du zuerst gedacht hast.",
                 penalty: shot.text),
            card(.challenge, "Beichte", "Erzähl etwas, das hier noch niemand von dir weiß.",
                 penalty: shot.text),
            card(.challenge, "Letzte Ausrede", "Wofür hast du dich zuletzt herausgeredet? Erzähl es.",
                 penalty: shot.text),

            // Kleidung
            card(.challenge, "Alles zurück", "Zieh ein Kleidungsstück wieder an.",
                 penalty: medium.text)
        ]
    }

    // MARK: Hilfen

    /// Die Kennung entsteht aus Kategorie und Titel. Das reicht, weil kein
    /// Titel doppelt vorkommt, und erspart eine Liste von Hand vergebener
    /// Nummern, die beim Einfuegen einer Karte auseinanderlaeuft.
    private static func card(
        _ category: ExtremeCategory,
        _ title: String,
        _ text: String,
        duration: String? = nil,
        penalty: String? = nil
    ) -> ExtremeCard {
        ExtremeCard(
            id: "\(category.rawValue)-\(title)",
            category: category,
            title: title,
            text: text,
            duration: duration,
            penalty: penalty
        )
    }
}
