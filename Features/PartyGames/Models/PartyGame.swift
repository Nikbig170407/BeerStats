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
        case .timeline: return "Zeitstrahl"
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
        case .horseRace: return "Vier Asse, sechs Seitenkarten – setz auf eine Farbe"
        case .busRide: return "Vier Fragen, dann die Busfahrt – wer am meisten daneben lag, fährt"
        case .truthOrDare:
            let karten = TruthOrDareDeck.count(.truth) + TruthOrDareDeck.count(.dare)
            return "\(karten) Karten – verweigern kostet"
        case .neverHaveIEver:
            return "\(NeverHaveIEverDeck.statements.count) Fragen in \(NeverHaveIEverCategory.allCases.count) Kategorien, dazu Strafen"
        case .timeline:
            return "\(SongDeck.count) Lieder – in welches Jahr gehört das?"
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

    /// Wie es gespielt wird, in drei bis vier Saetzen.
    ///
    /// Bis Oktober 2026 hatte nur Beerpong einen Regel-Screen. Die
    /// Partyspiele erklaerten sich im Spiel selbst – wer neu am Tisch stand,
    /// musste fragen, und wer als Gastgeber die Regeln kannte, musste sie
    /// zwanzigmal erzaehlen.
    ///
    /// Steht hier im Katalog und nicht in den Spielen: Dort stuende sie in
    /// neunzehn verschiedenen Formen, und ein neues Spiel haette sie
    /// garantiert nicht.
    var howToPlay: String {
        switch self {
        case .ringOfFire:
            return "Die Karten liegen verdeckt und geschuppt im Kreis – jede ein Stück unter der nächsten. Wer dran ist, tippt „Karte ziehen“; die App lost aus, welche es wird, und sagt, was zu tun ist. Und wie am echten Tisch gilt: Reißt dein Zug den Ring, weil die Nachbarkarten sich danach nicht mehr berühren, trinkst du einen Shot – danach wird eingesammelt und neu gelegt. Drei Shots hat eine Runde; ab dem dritten bleibt der Ring liegen, wie er liegt, und Lücken sind egal. Dicht liegende Karten sind sicher, dünne Stellen nicht – man kann es sehen. Manche Karten gelten nur im Moment, andere bis zum Spielende; das steht auf jeder Karte."
        case .horseRace:
            return "Vier Asse laufen um die Wette. Jeder setzt vorher auf eine Farbe – tippt euch in der Liste auf euer Pferd, dann weiß die App später, wer trinkt. Aufgedeckte Karten schieben das passende Pferd vor; die Seitenkarten schicken es zurück, sobald alle daran vorbei sind."
        case .busRide:
            return "Zwei Hälften. Erst die Fragerunde: Rot oder Schwarz, höher oder tiefer, dazwischen oder draußen, welche Farbe. Jede richtige Antwort bringt dich eine Stufe weiter, jede falsche kostet – und zurück auf Anfang. Wer alle vier schafft, ist raus. Reihum, bis alle durch sind. Dann die Busfahrt: Wer am meisten daneben lag, fährt Bus und deckt fünf Karten auf. Jede Zahl ist gut, jede Bildkarte schickt ihn zurück an den Anfang – und je weiter er gekommen war, desto teurer."
        case .truthOrDare:
            return "Wahrheit oder Pflicht, wie immer – nur dass die App die Karten stellt. Wer verweigert, trinkt die Menge, die auf der Karte steht. Eigene Karten lassen sich im Hauptmenü dazumischen."
        case .neverHaveIEver:
            return "Die App liest vor, was du noch nie getan hast. Wer es doch getan hat, trinkt. Ihr wählt, wie hart es wird – von harmlos bis tabulos – und worum es geht: Peinliches, Partygeschichten, Verbotenes, Ehrliches mit Tiefgang oder Abenteuer. Gemischt wird alles, was angehakt ist."
        case .timeline:
            return "Jeder sammelt Lieder und legt sie nach Jahr nebeneinander. Wer dran ist, gibt das Handy dem Nachbarn – der sieht Titel und Interpret, sucht das Lied und spielt es über die Box an, ohne den Titel vorzulesen. Du hörst es und sagst, zwischen welche deiner Karten es gehört („nach 1991, vor 2003“). Der Nachbar tippt die Lücke an. Stimmt es, bleibt die Karte bei dir; sonst trinkst du. Das Jahr sieht übrigens niemand vorher – auch der Nachbar nicht. Wer zuerst genug Karten hat, gewinnt."
        case .schocken:
            return "Drei Würfel, bis zu drei Würfe pro Person. Wer in der Runde den schlechtesten Wurf hat, bekommt einen Deckel; wer alle Deckel hat, trinkt. Die App kennt die Rangfolge – Schock Aus schlägt alles."
        case .maexchen:
            return "Würfeln, ohne dass es jemand sieht, und ansagen. Du darfst lügen. Wer dir nicht glaubt, deckt auf: Hast du gelogen, trinkst du – hat er zu Unrecht gezweifelt, trinkt er. Die App hält den Würfel verdeckt und weiß als Einzige die Wahrheit."
        case .twoTruths:
            return "Drei Sätze über dich, einer davon erfunden. Die anderen raten, welcher. Wer danebenliegt, trinkt – errät es niemand, trinkst du."
        case .headsUp:
            return "Handy an die Stirn, ohne hinzusehen. Die anderen beschreiben den Begriff, du rätst. Gerät nach unten heißt richtig, nach oben heißt weiter. Jeder verpasste Begriff kostet am Ende."
        case .spy:
            return "Alle bekommen dasselbe Wort – einer nicht, und der weiß nicht einmal, dass er der Spion ist. Reihum sagt jeder einen Satz dazu, nicht zu genau. Danach wird abgestimmt: Trefft ihr den Spion, trinkt er. Trefft ihr daneben, trinkt ihr."
        case .countTo21:
            return "Reihum zählen, jeder sagt eine bis drei Zahlen. Wer 21 sagt, trinkt und darf eine Regel erfinden – zum Beispiel, dass die 7 ab jetzt „Prost“ heißt. Danach geht es von vorn los, mit allen Regeln."
        case .estimation:
            return "Eine Frage mit einer Zahl als Antwort. Jeder schätzt, die App deckt auf. Wer am weitesten daneben liegt, trinkt – wer genau trifft, verteilt."
        case .categories:
            return "Eine Kategorie, dann reihum ein Begriff daraus. Wer patzt, sich wiederholt oder zu lange braucht, trinkt. Die Bedenkzeit wird jede Runde kürzer."
        case .mostLikely:
            return "Die App stellt eine Frage – „wer von uns würde am ehesten …“. Auf drei zeigen alle gleichzeitig auf eine Person. Wer die meisten Finger abbekommt, trinkt."
        case .knowYourPeople:
            return "Die App nimmt zwei von euch und fragt, wer besser trifft, wer mehr Airballs geworfen hat oder öfter gewonnen hat. Wer dran ist, antwortet; danach steht das echte Ergebnis daneben. Falsch geraten kostet. Gefragt wird nur, wo die Zahlen eindeutig sind – bei fast gleichauf gäbe es keine richtige Antwort, und solche Fragen stellt die App gar nicht."
        case .spectrum:
            return "Zwischen zwei Begriffen („harmlos“ und „gefährlich“) liegt eine Skala. Einer sieht eine Stelle darauf, die sonst niemand sieht, und gibt einen Hinweis, der genau dorthin führt – ein Wort oder ein Beispiel, niemals eine Zahl. Die Runde schiebt dann gemeinsam einen Regler dahin, wo sie ihn vermutet. Volltreffer heißt verteilen, knapp daneben geht straffrei durch, weit daneben trinkt der Hinweisgeber. Die Strafe trifft mit Absicht ihn: Der Hinweis ist die Leistung des Spiels."
        case .charades:
            return "Einer spielt vor, ohne ein Wort und ohne Geräusch – die Runde ruft, was sie erkennt. Nur die vorspielende Person sieht die Begriffe, deshalb wandert das Handy vorher zu ihr. Neunzig Sekunden, so viele Begriffe wie möglich. Jeder erratene Begriff ist ein Schluck, den sie verteilen darf; jeder liegen gebliebene einer, den sie selbst trinkt. Auf Dinge im Raum zeigen gilt nicht."
        case .bombPass:
            return "Zünden und weiterreichen. Die App zählt, aber nicht sichtbar – irgendwann geht sie hoch. Wer sie dann in der Hand hält, trinkt."
        case .reactionDuel:
            return "Zwei Daumen auf dem Bildschirm, beide warten auf das Signal. Wer zuerst tippt, gewinnt – wer zu früh tippt, verliert sofort."
        case .herd:
            return "Die App stellt eine Frage, auf die es keine richtige Antwort gibt, sondern nur eine häufige – „Nenne eine Pizza“. Auf drei sagen alle gleichzeitig ihre Antwort laut. Wer dasselbe gesagt hat wie die Mehrheit, hat gewonnen; wer allein dasteht, trinkt. Danach tippt ihr an, wer allein war – mehr rechnet die App nicht, sie kann ja nicht hören, was gesagt wurde. Wer zweimal hintereinander allein steht, bekommt die Kuh und zahlt mehr."
        case .drinkRoulette:
            return "Rad drehen, Feld abwarten, machen was dasteht. Vorher wählt ihr das Rad: klassisch, zahm, hart – oder ein eigenes, in das ihr eure Felder schreibt. Die besten sind die, die nur eure Runde versteht („Der Gastgeber trinkt“). Die Menge wählt ihr dazu aus, damit sie der eingestellten Härte folgt."
        case .forbiddenWords:
            return "Jeder zieht ein Wort, das er den ganzen Abend nicht sagen darf, und merkt es sich. Wer sein Wort trotzdem sagt und dabei erwischt wird, trinkt. Das Handy wandert einmal rum, damit niemand die Wörter der anderen sieht."
        case .drinkBingo:
            return "Sechzehn Felder mit Dingen, die an so einem Abend von selbst passieren. Passiert eins, tippt es an. Wer eine Reihe voll hat, ruft Bingo und verteilt."
        case .eveningRule:
            return "Ihr zieht eine Regel, die ab sofort für alle gilt – nur mit der schwachen Hand trinken, niemanden beim Vornamen nennen, so etwas. Dann legt ihr das Handy weg und spielt weiter; wer die Regel bricht, trinkt. Wird es langweilig, zieht ihr die nächste, und die alten gelten weiter. Jede Regel lässt sich einzeln wieder aufheben, wenn sie niemand mehr befolgt."
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

    // MARK: - Wie lange und mit wie vielen

    /// Wie lange eine Runde dauert.
    ///
    /// Steht hier und nicht im Spiel, weil die Frage am Tisch VOR dem
    /// Antippen gestellt wird: "Haben wir noch zehn Minuten oder reicht es
    /// nur fuer eine schnelle?" Im Spiel selbst waere die Antwort zu spaet.
    enum Length: Hashable, CaseIterable {
        /// Zwei Minuten – eine Runde zwischendurch.
        case quick
        /// Eine Viertelstunde, grob.
        case round
        /// Laeuft, bis alle durch sind.
        case long
        /// Hat keine Dauer, sondern begleitet den Abend.
        case alongside

        var label: String {
            switch self {
            case .quick: return "2 Minuten"
            case .round: return "10 Minuten"
            case .long: return "eine Viertelstunde"
            case .alongside: return "läuft nebenher"
            }
        }

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

        /// Kurzform fuer die Auswahl – dort stehen vier nebeneinander.
        var shortLabel: String {
            switch self {
            case .quick: return "Kurz"
            case .round: return "Mittel"
            case .long: return "Lang"
            case .alongside: return "Nebenher"
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
    static func fitting(players count: Int, length: Length? = nil) -> [PartyGame] {
        allCases.filter { game in
            guard game.length != .alongside else { return false }
            guard game.players.contains(count) else { return false }
            guard let length else { return true }
            return game.length == length
        }
    }

    /// Lost ein Spiel aus.
    ///
    /// `excluding` ist das zuletzt gezogene: Wer noch einmal wuerfelt, will
    /// etwas anderes sehen. Bleibt dadurch nichts uebrig, zaehlt die Auswahl
    /// mehr als die Abwechslung.
    static func draw(players count: Int, length: Length? = nil, excluding last: PartyGame? = nil) -> PartyGame? {
        let passend = fitting(players: count, length: length)
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
        // Platz hat.
        case .ringOfFire, .neverHaveIEver, .schocken, .maexchen, .spy,
             .headsUp, .forbiddenWords, .eveningRule, .charades, .timeline,
             .herd, .drinkRoulette:
            return .inSetup

        // Alle anderen fangen sofort an. Pferderennen und Wahrheit oder
        // Pflicht stehen bewusst hier und nicht oben: Was dort zuerst
        // kommt, ist schon das Spiel (die Bahn, die Wahl) und kein
        // Einstellungs-Screen – und beide sprechen ihre Mengen bereits dort
        // aus, die Haerte muss also vorher stehen.
        case .busRide, .twoTruths, .countTo21, .estimation, .categories,
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

    private var screen: AnyView {
        switch self {
        case .ringOfFire: return AnyView(RingOfFireView())
        case .horseRace: return AnyView(HorseRaceView())
        case .busRide: return AnyView(BusRideView())
        case .truthOrDare: return AnyView(TruthOrDareView())
        case .neverHaveIEver: return AnyView(NeverHaveIEverView())
        case .timeline: return AnyView(TimelineView())
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
