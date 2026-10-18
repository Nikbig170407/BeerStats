//
//  EveningRuleDeck.swift
//  BeerStats
//
//  Regeln, die ab dem Ziehen fuer den ganzen Tisch gelten.
//
//  Das Spiel hat keinen Ablauf – es legt sich ueber alle anderen. Deshalb
//  gilt fuer jede Regel hier dieselbe Pflicht: **Sie muss am Tisch
//  nachweisbar sein.** "Alle sind gut gelaunt" ist keine Regel, weil
//  niemand sagen kann, wann sie gebrochen wurde. Was zaehlt, ist ein
//  Verstoss, auf den jemand zeigen kann.
//
//  Zweite Pflicht: Sie muss von selbst passieren. Genau wie bei den
//  verbotenen Woertern waere "niemand darf einen Regenschirm erwaehnen" ein
//  stiller Abend. Deshalb Dinge, die ohnehin dauernd vorkommen – trinken,
//  fragen, aufs Handy schauen, jemanden beim Namen nennen.
//
//  Keine Regel verlangt etwas von einer einzelnen Person im Voraus
//  ("trink jetzt drei"): Das waere eine Strafkarte. Eine Regel aendert, wie
//  der Abend laeuft, nicht wie viel in der naechsten Minute getrunken wird.
//

import Foundation

enum EveningRuleDeck {

    static var count: Int { all.count }

    /// Zieht eine Regel, die noch nicht gilt.
    ///
    /// Das Ausschliessen ist kein Luxus: Eine Regel, die schon gilt, noch
    /// einmal zu ziehen, sieht am Tisch wie ein Fehler der App aus – und
    /// die Runde haette eine Runde lang nichts Neues.
    static func draw(excluding active: [String]) -> String? {
        let offen = all.filter { !active.contains($0) }
        return (offen.isEmpty ? all : offen).randomElement()
    }

    // MARK: - Was gesagt wird

    private static let speech: [String] = [
        "Niemand darf „nein“ sagen",
        "Niemand darf „Prost“ sagen – sucht euch ein neues Wort",
        "Niemand darf jemanden beim Vornamen nennen",
        "Jede Frage muss mit einer Gegenfrage beantwortet werden",
        "Niemand darf eine Zahl aussprechen",
        "Alle reden im Flüsterton",
        "Alle sprechen von sich selbst in der dritten Person",
        "Niemand darf fluchen",
        "Niemand darf das Wort „Bier“ sagen",
        "Jeder Satz fängt mit „ehrlich gesagt“ an",
        "Ab jetzt wird gesiezt",
        "Niemand darf einen Satz mit „und“ anfangen",
        "Wer eine Abkürzung benutzt, muss sie sofort ausschreiben",
        "Niemand darf eine Frage stellen"
    ]

    // MARK: - Wie getrunken wird

    private static let drinking: [String] = [
        "Getrunken wird nur mit der schwachen Hand",
        "Vor jedem Schluck wird mit mindestens einer Person angestoßen",
        "Wer trinkt, steht dabei auf",
        "Das Glas darf den Tisch nicht berühren",
        "Beim Trinken werden die Augen geschlossen",
        "Wer sein Glas leert, hält es hoch und sagt es an",
        "Niemand darf zwei Schlucke hintereinander nehmen, ohne etwas zu sagen",
        "Das Glas steht immer links von dir"
    ]

    // MARK: - Was der Körper macht

    private static let body: [String] = [
        "Niemand darf die Arme verschränken",
        "Niemand darf sich ins Gesicht fassen",
        "Wer aufs Handy schaut, hat die Regel gebrochen",
        "Wer gähnt, hat die Regel gebrochen",
        "Wer aufs Klo geht, nimmt jemanden mit",
        "Beide Füße bleiben auf dem Boden",
        "Niemand darf mit dem Finger auf jemanden zeigen",
        "Wer sich hinsetzt, klopft vorher einmal auf den Tisch",
        "Niemand darf aufstehen, ohne es vorher anzusagen"
    ]

    // MARK: - Wer welche Rolle hat

    private static let roles: [String] = [
        "Einer ist Daumenkönig: Legt er den Daumen auf den Tisch, machen es alle nach – der Letzte hat die Regel gebrochen",
        "Einer ist Mundschenk – nur er darf nachschenken",
        "Die Person links von dir ist dein Schatten: Trinkt sie, trinkst du mit",
        "Einer ist Richter und entscheidet jeden Streit – sein Wort gilt",
        "Nur eine Person darf die Musik aussuchen",
        "Einer ist Protokollant und sagt jeden Regelbruch laut an",
        "Einer ist Türsteher: Wer dazukommt, meldet sich bei ihm"
    ]

    // MARK: - Wer aufpasst

    private static let attention: [String] = [
        "Wer als Letzter merkt, dass alle die Hand heben, hat die Regel gebrochen",
        "Wer als Letzter merkt, dass alle still sind, hat die Regel gebrochen",
        "Wer als Letzter merkt, dass alle aufstehen, hat die Regel gebrochen",
        "Wer neu dazukommt, wird mit Applaus begrüßt",
        "Jedes volle Glas wird einmal hochgehalten, bevor daraus getrunken wird",
        "Wer eine Regel erklärt, muss sie vorher selbst befolgt haben",
        "Wer zweimal hintereinander dasselbe sagt, hat die Regel gebrochen"
    ]

    static let all: [String] = speech + drinking + body + roles + attention
}

/// Welche Regeln gerade gelten.
///
/// Liegt in UserDefaults und nicht im View-Zustand, weil das Spiel
/// NEBENHER laeuft: Wer eine Regel zieht und danach Ring of Fire spielt,
/// kaeme sonst in ein leeres Spiel zurueck – und die Regel gilt am Tisch ja
/// weiter. Dasselbe Argument wie bei der Aufstellung und der Trinkbilanz.
///
/// Gespeichert wird der **Text**, nicht ein Platz im Stapel. Ein Stapel
/// waechst und wird umsortiert; eine Nummer zeigte danach auf eine andere
/// Regel, ohne dass es jemandem auffiele.
enum ActiveEveningRules {

    static let storageKey = "evening.rules.active"

    /// Neueste zuerst – die zuletzt gezogene ist die, ueber die alle reden.
    static var all: [String] {
        get { UserDefaults.standard.stringArray(forKey: storageKey) ?? [] }
        set {
            guard !newValue.isEmpty else {
                UserDefaults.standard.removeObject(forKey: storageKey)
                return
            }
            UserDefaults.standard.set(newValue, forKey: storageKey)
        }
    }

    static func add(_ rule: String) {
        var liste = all
        liste.removeAll { $0 == rule }
        liste.insert(rule, at: 0)
        all = liste
    }

    static func remove(_ rule: String) {
        all = all.filter { $0 != rule }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
