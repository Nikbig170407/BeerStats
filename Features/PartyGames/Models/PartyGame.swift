//
//  PartyGame.swift
//  BeerStats
//
//  Der Katalog aller Partyspiele an einer Stelle.
//
//  Vorher stand jeder Eintrag von Hand im Hauptmenue: Emoji, Titel,
//  Untertitel, Farbe und Ziel-Ansicht, neunzehnmal untereinander. Das laesst
//  sich nicht sortieren, nicht filtern und nicht als "zuletzt gespielt"
//  wiederfinden – und bei jedem neuen Spiel vergisst man eine der fuenf
//  Angaben.
//
//  Als Aufzaehlung ist ein Spiel eine Kennung, die sich speichern laesst.
//  Genau das braucht die Merkliste der zuletzt gespielten Spiele.
//

import SwiftUI

enum PartyGame: String, CaseIterable, Identifiable {

    // Reihenfolge innerhalb der Gruppe = Reihenfolge im Menue.
    case ringOfFire
    case horseRace
    case busRide
    case truthOrDare
    case neverHaveIEver
    /// Heisst seit dem 29. Oktober "Hitparade". Der Fall bleibt `timeline`:
    /// Sein Rohwert steckt in den Einstellungen (Haerte), und ein neuer
    /// Name wuerfe sie stillschweigend weg.
    case timeline

    case schocken
    case maexchen
    case twoTruths
    case spy
    case headsUp
    case countTo21
    case estimation
    case categories
    case mostLikely
    case knowYourPeople
    case charades
    case spectrum

    case bombPass
    case reactionDuel
    case drinkRoulette
    case herd

    case forbiddenWords
    case drinkBingo
    case eveningRule

    var id: String { rawValue }

    // MARK: - Gruppen

    enum Group: String, CaseIterable, Identifiable {
        case cards
        case talking
        case quick
        case alongside

        var id: String { rawValue }

        /// Als Ueberschrift ueber einer Liste – deshalb in Grossbuchstaben.
        var title: String {
            switch self {
            case .cards: return "MIT KARTEN"
            case .talking: return "RATEN & REDEN"
            case .quick: return "SCHNELL ZWISCHENDURCH"
            case .alongside: return "LÄUFT NEBENHER"
            }
        }

        /// Als Beschriftung einer Kachel – dort liest sich Geschrei schlecht.
        var label: String {
            switch self {
            case .cards: return "Mit Karten"
            case .talking: return "Raten & reden"
            case .quick: return "Schnell zwischendurch"
            case .alongside: return "Läuft nebenher"
            }
        }

        /// Was man in der Gruppe tut, in einem halben Satz.
        var subtitle: String {
            switch self {
            case .cards: return "Ein Stapel in der Mitte, einer zieht"
            case .talking: return "Raten, lügen, schätzen – ohne Material"
            case .quick: return "Eine Runde in zwei Minuten"
            case .alongside: return "Läuft den ganzen Abend mit"
            }
        }

        var emoji: String {
            switch self {
            case .cards: return "🃏"
            case .talking: return "🗣️"
            case .quick: return "⚡️"
            case .alongside: return "🎯"
            }
        }

        var tint: Color {
            switch self {
            case .cards: return BeerStatsColor.error
            case .talking: return BeerStatsColor.accentSecondary
            case .quick: return BeerStatsColor.warning
            case .alongside: return BeerStatsColor.success
            }
        }

        /// Die Spiele dieser Gruppe, in der Reihenfolge des Katalogs.
        var games: [PartyGame] {
            PartyGame.allCases.filter { $0.group == self }
        }
    }

    var group: Group {
        switch self {
        case .ringOfFire, .horseRace, .busRide, .truthOrDare, .neverHaveIEver,
             .timeline:
            return .cards
        case .schocken, .maexchen, .twoTruths, .spy, .headsUp,
             .countTo21, .estimation, .categories, .mostLikely, .knowYourPeople,
             .charades, .spectrum:
            return .talking
        case .bombPass, .reactionDuel, .drinkRoulette, .herd:
            return .quick
        case .forbiddenWords, .drinkBingo, .eveningRule:
            return .alongside
        }
    }

    // MARK: - Darstellung

    var title: String {
        switch self {
        case .ringOfFire: return "Ring of Fire"
        case .horseRace: return "Pferderennen"
        case .busRide: return "Bussfahrer"
        case .truthOrDare: return "Wahrheit oder Pflicht"
        case .neverHaveIEver: return "Ich hab noch nie"
        case .timeline: return "Hitparade"
        case .schocken: return "Schocken"
        case .maexchen: return "Mäxchen"
        case .twoTruths: return "Zwei Wahrheiten"
        case .spy: return "Der Spion"
        case .headsUp: return "Wer bin ich?"
        case .countTo21: return "21"
        case .estimation: return "Schätzmeister"
        case .categories: return "Kategorien"
        case .mostLikely: return "Wer würde eher?"
        case .knowYourPeople: return "Kennst du deine Leute?"
        case .charades: return "Pantomime"
        case .spectrum: return "Die Skala"
        case .bombPass: return "Bombe weitergeben"
        case .reactionDuel: return "Reaktionsduell"
        case .drinkRoulette: return "Trink-Roulette"
        case .herd: return "Die Herde"
        case .forbiddenWords: return "Verbotene Wörter"
        case .drinkBingo: return "Trinkbingo"
        case .eveningRule: return "Regel des Abends"
        }
    }

    var emoji: String {
        switch self {
        case .ringOfFire: return "🔥"
        case .horseRace: return "🐎"
        case .busRide: return "🚌"
        case .truthOrDare: return "🎭"
        case .neverHaveIEver: return "🍻"
        case .timeline: return "🎵"
        case .schocken: return "🎲"
        case .maexchen: return "🎲"
        case .twoTruths: return "🎭"
        case .spy: return "🕵️"
        case .headsUp: return "🙈"
        case .countTo21: return "🔢"
        case .estimation: return "🤔"
        case .categories: return "⏱️"
        case .mostLikely: return "👉"
        case .knowYourPeople: return "🧠"
        case .charades: return "🤸"
        case .spectrum: return "🎚️"
        case .bombPass: return "💣"
        case .reactionDuel: return "⚡️"
        case .drinkRoulette: return "🎯"
        case .herd: return "🐄"
        case .forbiddenWords: return "🤐"
        case .drinkBingo: return "🎉"
        case .eveningRule: return "📜"
        }
    }

    var subtitle: String {
        switch self {
        case .ringOfFire: return "Karten geschuppt im Kreis – die ersten drei Risse kosten einen Shot"
        case .horseRace: return "Vier Asse, \(HorseRaceTrack.sideCount) Seitenkarten – setz auf eine Farbe"
        case .busRide: return "Vier Fragen, dann die Busfahrt – wer am meisten daneben lag, fährt"
        case .truthOrDare:
            let karten = TruthOrDareDeck.count(.truth) + TruthOrDareDeck.count(.dare)
            return "\(karten) Karten – verweigern kostet"
        case .neverHaveIEver:
            return "\(NeverHaveIEverDeck.statements.count) Fragen in \(NeverHaveIEverCategory.allCases.count) Kategorien, dazu Strafen"
        case .timeline:
            return "\(SongDeck.count) Lieder – Titel, Interpret, Jahr oder wohin in deine Reihe?"
        case .schocken: return "Drei Würfel, drei Würfe – der schlechteste Wurf trinkt"
        case .maexchen: return "Verdeckt würfeln und lügen – die App weiß, wer geflunkert hat"
        case .twoTruths: return "Drei Sätze, einer erfunden – wer danebenliegt, trinkt"
        case .spy: return "Alle kennen das Wort – einer nicht, und der muss es überspielen"
        case .headsUp: return "Handy an die Stirn – jeder verpasste Begriff kostet einen Schluck"
        case .countTo21: return "Reihum zählen – wer 21 sagt, macht eine neue Regel"
        case .estimation:
            return "\(EstimationDeck.count) Fragen mit einer Zahl – wer am weitesten daneben liegt, trinkt"
        case .categories: return "Reihum ein Begriff – die Bedenkzeit wird jede Runde knapper"
        case .mostLikely: return "Alle zeigen gleichzeitig – die meisten Finger trinken"
        case .knowYourPeople: return "Fragen aus euren echten Beerpong-Zahlen – wer danebenliegt, trinkt"
        case .charades: return "Vorspielen ohne ein Wort – 90 Sekunden gegen die Runde"
        case .spectrum:
            return "\(SpectrumDeck.count) Gegensätze – wie weit links liegt dein Hinweis?"
        case .bombPass: return "Zünden, herumreichen, nicht drauf sitzen bleiben"
        case .reactionDuel: return "Zwei Daumen, ein Signal – wer zu früh tippt, verliert"
        case .drinkRoulette: return "Vier Räder, ein Zeiger – eins davon baust du selbst"
        case .herd:
            return "\(HerdDeck.count) Fragen – wer nicht wie die Mehrheit denkt, trinkt"
        case .forbiddenWords: return "Jeder zieht ein Wort, das er den Abend über nicht sagen darf"
        case .drinkBingo: return "Sechzehn Felder, die von selbst passieren"
        case .eveningRule:
            return "\(EveningRuleDeck.count) Regeln – eine gilt ab jetzt für alle"
        }
    }

    /// Wie es gespielt wird – in kurzen Schritten.
    ///
    /// Steht hier im Katalog und nicht in den Spielen: Dort stuende sie in
    /// fuenfundzwanzig verschiedenen Formen, und ein neues Spiel haette sie
    /// garantiert nicht. Gezeigt wird sie hinter dem Fragezeichen
    /// (`HowToPlaySheet`), auf der Seite des Spiels und im Spiel.
    ///
    /// Stichpunkte statt Absatz (6. November: "viel zu viel Text"): Ein
    /// Schritt ist eine Zeile, die man am Tisch vorliest. Was nur erklaert,
    /// WARUM eine Regel so ist, gehoert in den Code, nicht hierher.
    var howToPlay: [String] {
        switch self {
        case .ringOfFire:
            return [
                "Wer dran ist, tippt „Karte ziehen“ und macht, was die Karte sagt.",
                "Reißt dein Zug den Ring, trinkst du einen Shot – dann wird neu gelegt.",
                "Gerissen ist er, wenn der Glutfaden unter den Karten reißt.",
                "Drei Risse pro Runde, danach sind Lücken egal."
            ]
        case .horseRace:
            return [
                "Vier Asse laufen um die Wette.",
                "Vorher setzt jeder auf eine Farbe.",
                "Jede aufgedeckte Karte schiebt ihr Pferd vor.",
                "Erreicht das letzte Pferd eine Spalte, dreht sich die Karte darüber um und schickt ihr Pferd zurück."
            ]
        case .busRide:
            return [
                "Fragerunde: Rot oder Schwarz, höher oder tiefer, dazwischen oder draußen, welche Farbe.",
                "Richtig bringt dich weiter, falsch kostet und schickt dich zurück.",
                "Wer am meisten daneben lag, fährt Bus: fünf Karten, jedes Bild zurück an den Anfang."
            ]
        case .truthOrDare:
            return [
                "Wahrheit oder Pflicht – die App stellt die Karten.",
                "Wer verweigert, trinkt die Menge auf der Karte.",
                "Eigene Karten mischst du im Hauptmenü dazu."
            ]
        case .neverHaveIEver:
            return [
                "Die App liest vor, was du noch nie getan hast.",
                "Wer es doch getan hat, trinkt.",
                "Vorher wählt ihr, wie hart es wird und worum es geht."
            ]
        case .timeline:
            return [
                "Jeder sammelt Lieder in seiner Reihe, sortiert nach Jahr.",
                "Die App spielt 30 Sekunden – ohne Titel oder Cover.",
                "Gefragt wird: einsortieren, Titel, Interpret oder Jahr.",
                "Richtig: Die Karte kommt in deine Reihe. Falsch: trinken.",
                "Wer zuerst genug Karten hat, gewinnt."
            ]
        case .schocken:
            return [
                "Drei Würfel, bis zu drei Würfe pro Person.",
                "Der schlechteste Wurf der Runde bekommt einen Deckel.",
                "Wer alle Deckel hat, trinkt."
            ]
        case .maexchen:
            return [
                "Verdeckt würfeln und ansagen – lügen ist erlaubt.",
                "Wer zweifelt, deckt auf.",
                "Gelogen: Du trinkst. Zu Unrecht gezweifelt: Er trinkt."
            ]
        case .twoTruths:
            return [
                "Drei Sätze über dich, einer davon erfunden.",
                "Wer die Lüge nicht errät, trinkt.",
                "Errät sie niemand, trinkst du."
            ]
        case .headsUp:
            return [
                "Handy an die Stirn, die anderen beschreiben.",
                "Nach unten: richtig. Nach oben: weiter.",
                "Jeder verpasste Begriff kostet am Ende."
            ]
        case .spy:
            return [
                "Alle bekommen dasselbe Wort – der Spion nicht.",
                "Reihum sagt jeder einen Satz dazu.",
                "Dann abstimmen: Spion erwischt, er trinkt. Daneben, ihr trinkt."
            ]
        case .countTo21:
            return [
                "Reihum zählen, jeder sagt eine bis drei Zahlen.",
                "Wer 21 sagt, trinkt und erfindet eine Regel – etwa: Die 7 heißt jetzt „Prost“.",
                "Dann von vorn, mit allen Regeln."
            ]
        case .estimation:
            return [
                "Eine Frage, eine Zahl als Antwort.",
                "Jeder schätzt – laut oder geheim im Handy.",
                "Am weitesten daneben trinkt, am nächsten dran verteilt."
            ]
        case .categories:
            return [
                "Eine Kategorie, reihum ein Begriff daraus.",
                "Wer patzt, wiederholt oder zu lange braucht, trinkt.",
                "Die Bedenkzeit wird jede Runde kürzer."
            ]
        case .mostLikely:
            return [
                "„Wer von uns würde am ehesten …?“",
                "Auf drei zeigen alle gleichzeitig auf jemanden.",
                "Wer die meisten Finger abbekommt, trinkt."
            ]
        case .knowYourPeople:
            return [
                "Die App stellt zwei von euch gegenüber: Wer trifft besser, wer gewinnt öfter?",
                "Die Fragen kommen aus euren echten Beerpong-Zahlen.",
                "Falsch geraten kostet."
            ]
        case .spectrum:
            return [
                "Zwischen zwei Begriffen liegt eine Skala.",
                "Einer sieht eine Stelle und gibt einen Hinweis – keine Zahl.",
                "Die Runde schiebt die Nadel dorthin.",
                "Treffer: verteilen. Weit daneben: Der Hinweisgeber trinkt."
            ]
        case .charades:
            return [
                "Einer spielt vor – ohne Wort, ohne Laut.",
                "90 Sekunden, so viele Begriffe wie möglich.",
                "Erraten: verteilen. Liegen geblieben: selbst trinken."
            ]
        case .bombPass:
            return [
                "Zünden und weiterreichen.",
                "Wann sie hochgeht, sieht niemand.",
                "Wer sie dann hält, trinkt."
            ]
        case .reactionDuel:
            return [
                "Zwei Daumen, ein Signal.",
                "Wer zuerst tippt, gewinnt.",
                "Wer zu früh tippt, verliert sofort."
            ]
        case .herd:
            return [
                "Eine Frage ohne richtige Antwort – „Nenne eine Pizza“.",
                "Auf drei antworten alle gleichzeitig.",
                "Wer allein dasteht, trinkt.",
                "Zweimal hintereinander allein: Die Kuh, und es wird teurer."
            ]
        case .drinkRoulette:
            return [
                "Rad wählen, drehen, machen, was dasteht.",
                "Klassisch, zahm, hart – oder euer eigenes Rad."
            ]
        case .forbiddenWords:
            return [
                "Jeder zieht geheim ein Wort, das er nicht sagen darf.",
                "Wer es trotzdem sagt und erwischt wird, trinkt."
            ]
        case .drinkBingo:
            return [
                "Sechzehn Felder, die von selbst passieren.",
                "Passiert eins, tippt es an.",
                "Reihe voll: Bingo – verteilen."
            ]
        case .eveningRule:
            return [
                "Zieht eine Regel, die ab jetzt für alle gilt.",
                "Wer sie bricht, trinkt.",
                "Langweilig? Die nächste ziehen – die alten gelten weiter."
            ]
        }
    }

    var tint: Color {
        switch self {
        case .ringOfFire, .drinkRoulette, .countTo21:
            return BeerStatsColor.error
        case .horseRace, .neverHaveIEver, .estimation, .drinkBingo, .charades,
             .herd:
            return BeerStatsColor.success
        case .busRide, .maexchen, .spy, .bombPass, .knowYourPeople, .eveningRule,
             .timeline:
            return BeerStatsColor.accentSecondary
        case .schocken, .categories, .forbiddenWords:
            return BeerStatsColor.warning
        case .truthOrDare, .twoTruths, .headsUp, .mostLikely, .reactionDuel,
             .spectrum:
            return BeerStatsColor.accent
        }
    }

    /// Die Welt des Spiels: Grund, Flaeche, Kante, Schrift (`GameWorld`).
    ///
    /// Ein vollstaendiges `switch` ohne `default` – ein neues Spiel
    /// uebersetzt nicht, bevor es eine eigene Welt hat. Und keine zwei
    /// Spiele teilen sich eine (`GameWorldTests`): Genau das hat sie vorher
    /// alle gleich aussehen lassen.
    var world: GameWorld {
        switch self {
        case .ringOfFire: return .campfire
        case .horseRace: return .racetrack
        case .busRide: return .nightBus
        case .truthOrDare: return .twoPiles
        case .neverHaveIEver: return .neonSign
        case .timeline: return .recordShelf
        case .schocken: return .regularsTable
        case .maexchen: return .underTheCup
        case .twoTruths: return .lieDetector
        case .spy: return .secretFile
        case .headsUp: return .foreheadCard
        case .countTo21: return .boardGame
        case .estimation: return .quizShow
        case .categories: return .hourglass
        case .mostLikely: return .showOfHands
        case .knowYourPeople: return .trumpCards
        case .charades: return .silentFilm
        case .spectrum: return .wavelength
        case .bombPass: return .bunker
        case .reactionDuel: return .highNoon
        case .drinkRoulette: return .casino
        case .herd: return .pasture
        case .forbiddenWords: return .gafferTape
        case .drinkBingo: return .bingoHall
        case .eveningRule: return .decree
        }
    }

    /// Das gezeichnete Cover in der Spielauswahl (`CoverArt`) – `nil`, solange
    /// ein Spiel noch keines hat; dann traegt es den stillen Grund seiner
    /// Welt mit seinem Zeichen.
    ///
    /// Vollstaendig und ohne `default`, wie `world`: Ein neues Spiel muss hier
    /// eingeordnet werden, auch wenn die Antwort vorerst `nil` ist.
    var coverArt: CoverArt? {
        switch self {
        case .ringOfFire: return .bottleCap
        case .horseRace: return .raceAce
        case .busRide: return .nightBus
        case .truthOrDare: return .splitBolt
        case .neverHaveIEver: return .neonHand
        case .timeline: return .vinyl
        case .schocken, .maexchen, .twoTruths, .spy, .headsUp, .countTo21,
             .estimation, .categories, .mostLikely, .knowYourPeople, .charades,
             .spectrum, .bombPass, .reactionDuel, .drinkRoulette, .herd,
             .forbiddenWords, .drinkBingo, .eveningRule:
            return nil
        }
    }

    // MARK: - Wie lange und mit wie vielen

    /// Wie lange eine Runde dauert – fuer die Rechnung, nicht zum Anzeigen.
    ///
    /// Angezeigt wird die Dauer nirgends mehr (6. November: "schreib nicht
    /// dazu, wie lange die Spiele dauern"). Gebraucht wird sie trotzdem:
    /// Sie gewichtet einen Sieg im Pokal (`points`), und was nebenher
    /// laeuft, kommt im Wuerfel nicht vor.
    enum Length: Hashable, CaseIterable {
        /// Zwei Minuten – eine Runde zwischendurch.
        case quick
        /// Eine Viertelstunde, grob.
        case round
        /// Laeuft, bis alle durch sind.
        case long
        /// Hat keine Dauer, sondern begleitet den Abend.
        case alongside

        /// Was ein Sieg in einem Spiel dieser Laenge im Pokal wert ist.
        ///
        /// Die Gewichtung ist der Kern der Siegerwertung: Ohne sie gewinnt
        /// den Abend, wer am meisten Reaktionsduell gespielt hat – eine
        /// Runde dauert zwei Minuten, eine Partie Beerpong eine
        /// Viertelstunde. Was nebenher laeuft, kennt keinen Sieger und
        /// bringt deshalb nichts.
        var points: Int {
            switch self {
            case .quick: return 1
            case .round: return 2
            case .long: return 3
            case .alongside: return 0
            }
        }
    }

    var length: Length {
        switch self {
        case .bombPass, .reactionDuel, .drinkRoulette, .twoTruths, .herd:
            return .quick
        case .schocken, .maexchen, .countTo21, .estimation, .categories,
             .mostLikely, .knowYourPeople, .headsUp, .charades, .truthOrDare,
             .spy, .spectrum:
            return .round
        case .ringOfFire, .horseRace, .busRide, .neverHaveIEver, .timeline:
            return .long
        case .forbiddenWords, .drinkBingo, .eveningRule:
            return .alongside
        }
    }

    /// Ab so vielen ist mehr nicht mehr unbedingt besser.
    static let manyPlayers = 12

    /// Mit wie vielen das Spiel funktioniert.
    ///
    /// Die Untergrenze ist die interessante Zahl, und sie ist keine
    /// Geschmacksfrage: "Wer würde eher?" braucht jemanden, auf den man
    /// zeigen kann, und der Spion braucht ausser ihm noch zwei, die sich
    /// einig werden koennen. Mit zu wenigen Leuten ist das Spiel nicht
    /// schwaecher, sondern kaputt – deshalb taucht es in der Auslosung
    /// erst gar nicht auf.
    var players: ClosedRange<Int> {
        switch self {
        // Zu zweit spielbar.
        case .ringOfFire, .horseRace, .busRide, .truthOrDare, .neverHaveIEver,
             .maexchen, .countTo21, .estimation, .knowYourPeople,
             .reactionDuel, .drinkRoulette, .forbiddenWords, .drinkBingo,
             .eveningRule, .timeline:
            return 2...Self.manyPlayers

        // Schocken wird mit Deckeln gespielt; ab zehn dauert eine Runde
        // laenger als die Aufmerksamkeit reicht.
        case .schocken:
            return 2...10

        // Brauchen eine Runde, nicht ein Gegenueber: jemanden zum
        // Draufzeigen, zum Beschreiben, zum Ueberstimmen.
        case .twoTruths, .spy, .headsUp, .categories, .mostLikely,
             .bombPass, .charades, .spectrum, .herd:
            return 3...Self.manyPlayers
        }
    }

    /// "ab 3" oder "2–10" – was davon stimmt.
    var playersLabel: String {
        players.upperBound >= Self.manyPlayers
            ? "ab \(players.lowerBound)"
            : "\(players.lowerBound)–\(players.upperBound)"
    }

    // MARK: - Auslosen

    /// Die Spiele, die zu dieser Runde passen.
    ///
    /// Was **nebenher** laeuft, ist nie dabei. Die Frage lautet "was
    /// spielen wir jetzt", und darauf ist "Trinkbingo" keine Antwort – das
    /// laeuft mit, waehrend etwas anderes gespielt wird.
    static func fitting(players count: Int) -> [PartyGame] {
        allCases.filter { game in
            game.length != .alongside && game.players.contains(count)
        }
    }

    /// Lost ein Spiel aus.
    ///
    /// `excluding` ist das zuletzt gezogene: Wer noch einmal wuerfelt, will
    /// etwas anderes sehen. Bleibt dadurch nichts uebrig, zaehlt die Auswahl
    /// mehr als die Abwechslung.
    static func draw(players count: Int, excluding last: PartyGame? = nil) -> PartyGame? {
        let passend = fitting(players: count)
        let offen = passend.filter { $0 != last }
        return (offen.isEmpty ? passend : offen).randomElement()
    }

    // MARK: - Turnier

    /// Taugt dieses Spiel fuer eine Turnierrunde?
    ///
    /// Voraussetzung ist genau eine Sache: Am Ende muss feststehen, wer
    /// verloren hat. Ring of Fire, Ich hab noch nie oder Trinkbingo haben
    /// keinen Verlierer – sie verteilen Schluecke, kueren aber niemanden.
    /// Trink-Roulette faellt aus einem anderen Grund raus: Dort entscheidet
    /// nur der Zufall, und ein Turnier, in dem Koennen nichts zaehlt, ist
    /// kein Turnier.
    var isTournamentReady: Bool {
        switch self {
        case .busRide, .schocken, .maexchen, .headsUp, .countTo21,
             .estimation, .categories, .bombPass, .reactionDuel, .charades,
             .timeline:
            return true
        case .ringOfFire, .horseRace, .truthOrDare, .neverHaveIEver,
             .twoTruths, .spy, .mostLikely, .drinkRoulette,
             .forbiddenWords, .drinkBingo, .knowYourPeople, .eveningRule,
             .spectrum, .herd:
            return false
        }
    }

    // MARK: - Haerte

    /// Wo die Trinkhaerte dieses Spiels eingestellt wird.
    ///
    /// Sie stand lange EINMAL ueber den Partyspielen und galt fuer alle. Am
    /// Tisch ist sie aber eine Eigenschaft der Runde: Mäxchen wird anders
    /// getrunken als Trink-Roulette. Seit Oktober 2026 steht sie deshalb im
    /// Vorspann des Spiels – und welches Spiel schon einen hat, weiss nur
    /// der Katalog.
    ///
    /// Jedes Partyspiel nennt inzwischen eine Menge, deshalb hat auch jedes
    /// eine Haerte – es gibt nur zwei Antworten, wo sie steht. Bombe und
    /// Reaktionsduell sagten bis zum 13. Oktober blosses "du trinkst"; was
    /// die Runde dann aushandelte, hatte mit der eingestellten Haerte
    /// nichts zu tun.
    enum IntensityStep {
        /// Das Spiel fragt vorher ohnehin etwas; die Haerte steht dort mit
        /// drin. Ein eigener Screen davor waeren zwei fast gleiche
        /// Vorspaenne hintereinander.
        case inSetup
        /// Das Spiel fing sofort an und bekommt einen Vorspann nur fuer die
        /// Haerte (`IntensityGate`).
        case ownScreen
    }

    var intensityStep: IntensityStep {
        switch self {
        // Diese sieben fragen vorher schon etwas – Spielerzahl, Kartenzahl,
        // Stufen, Kategorie. Die Haerte steht in demselben Vorspann.
        // Trink-Roulette steht seit dem 25. Oktober hier: Es fragt jetzt
        // nach dem Rad und hat damit einen Vorspann, in dem die Haerte mit
        // Platz hat. Der Schaetzmeister seit dem 4. November: Er fragt, ob
        // reingerufen oder aufgeschrieben wird.
        case .ringOfFire, .neverHaveIEver, .schocken, .maexchen, .spy,
             .headsUp, .forbiddenWords, .eveningRule, .charades, .timeline,
             .herd, .drinkRoulette, .estimation:
            return .inSetup

        // Alle anderen fangen sofort an. Pferderennen und Wahrheit oder
        // Pflicht stehen bewusst hier und nicht oben: Was dort zuerst
        // kommt, ist schon das Spiel (die Bahn, die Wahl) und kein
        // Einstellungs-Screen – und beide sprechen ihre Mengen bereits dort
        // aus, die Haerte muss also vorher stehen.
        case .busRide, .twoTruths, .countTo21, .categories,
             .drinkBingo, .knowYourPeople, .horseRace,
             .truthOrDare, .mostLikely, .bombPass, .reactionDuel, .spectrum:
            return .ownScreen
        }
    }

    // MARK: - Ziel

    /// Bewusst `AnyView` statt `@ViewBuilder`.
    ///
    /// Ein ViewBuilder-`switch` ueber zwanzig verschiedene View-Typen baut
    /// einen tief verschachtelten `_ConditionalContent`-Typ auf. Das laesst
    /// sich zwar uebersetzen, treibt die Uebersetzungszeit aber steil hoch –
    /// und hier gibt es nichts zu gewinnen: Das Ziel wird genau einmal
    /// erzeugt, wenn jemand die Karte antippt.
    /// Der Weg ins Spiel – samt Haerte.
    ///
    /// Das Setzen der geltenden Haerte haengt hier und nicht an der
    /// Spielkachel, weil es zwei Wege ins Spiel gibt: die Kachel und das
    /// Turnier. An der Kachel allein waere ein ueber das Turnier
    /// gestartetes Spiel in der Vorgabe gelaufen, obwohl im Vorspann die
    /// eigene Haerte dasteht – ein Screen, der etwas anderes behauptet als
    /// das Spiel tut.
    var destination: AnyView {
        // `screen` statt `destination` im Inneren: Sonst ruft sich das Tor
        // selbst auf.
        let ziel: AnyView = intensityStep == .ownScreen
            ? AnyView(IntensityGate(game: self) { screen })
            : screen

        return AnyView(
            ziel
                // Die Welt gilt fuer alles, was zum Spiel gehoert – auch fuer
                // den Vorspann davor. Ueber die Umgebung, damit die geteilten
                // Bausteine sie lesen koennen, ohne dass ein Spiel sie
                // durchreichen muss.
                .environment(\.gameWorld, world)
                .onAppear { DrinkIntensity.activate(for: self) }
                // Zurueck zur Vorgabe. Ohne das liefe Beerpong Extreme nach
                // einer harten Runde Schocken auch hart.
                .onDisappear { DrinkIntensity.clearActive() }
        )
    }

    /// Der Weg ins Spiel aus der Spielauswahl: das Spiel samt Vermerk im
    /// Abend. An EINER Stelle, damit es keinen zweiten Weg gibt, der das
    /// Vermerken vergisst. Vermerkt wird beim Erscheinen, nicht beim
    /// Antippen: Wer sich vertippt und sofort zurueckgeht, hat nicht
    /// gespielt. Ohne laufenden Abend tut der Vermerk nichts.
    var playScreen: AnyView {
        AnyView(destination.onAppear { EveningLog.record(partyGame: self) })
    }

    private var screen: AnyView {
        switch self {
        case .ringOfFire: return AnyView(RingOfFireView())
        case .horseRace: return AnyView(HorseRaceView())
        case .busRide: return AnyView(BusRideView())
        case .truthOrDare: return AnyView(TruthOrDareView())
        case .neverHaveIEver: return AnyView(NeverHaveIEverView())
        case .timeline: return AnyView(HitparadeView())
        case .schocken: return AnyView(SchockenView())
        case .maexchen: return AnyView(MaexchenView())
        case .twoTruths: return AnyView(TwoTruthsView())
        case .spy: return AnyView(SpyView())
        case .headsUp: return AnyView(HeadsUpView())
        case .countTo21: return AnyView(CountTo21View())
        case .estimation: return AnyView(EstimationView())
        case .categories: return AnyView(CategoriesView())
        case .mostLikely: return AnyView(MostLikelyView())
        case .knowYourPeople: return AnyView(KnowYourPeopleView())
        case .charades: return AnyView(CharadesView())
        case .spectrum: return AnyView(SpectrumView())
        case .bombPass: return AnyView(BombPassView())
        case .reactionDuel: return AnyView(ReactionDuelView())
        case .drinkRoulette: return AnyView(DrinkRouletteView())
        case .herd: return AnyView(HerdView())
        case .forbiddenWords: return AnyView(ForbiddenWordsView())
        case .drinkBingo: return AnyView(DrinkBingoView())
        case .eveningRule: return AnyView(EveningRuleView())
        }
    }
}
