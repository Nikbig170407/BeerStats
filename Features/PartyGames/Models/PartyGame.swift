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

    case schocken
    case maexchen
    case twoTruths
    case spy
    case headsUp
    case countTo21
    case estimation
    case categories
    case mostLikely

    case bombPass
    case reactionDuel
    case drinkRoulette

    case forbiddenWords
    case drinkBingo

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
        case .ringOfFire, .horseRace, .busRide, .truthOrDare, .neverHaveIEver:
            return .cards
        case .schocken, .maexchen, .twoTruths, .spy, .headsUp,
             .countTo21, .estimation, .categories, .mostLikely:
            return .talking
        case .bombPass, .reactionDuel, .drinkRoulette:
            return .quick
        case .forbiddenWords, .drinkBingo:
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
        case .schocken: return "Schocken"
        case .maexchen: return "Mäxchen"
        case .twoTruths: return "Zwei Wahrheiten"
        case .spy: return "Der Spion"
        case .headsUp: return "Wer bin ich?"
        case .countTo21: return "21"
        case .estimation: return "Schätzmeister"
        case .categories: return "Kategorien"
        case .mostLikely: return "Wer von uns?"
        case .bombPass: return "Bombe weitergeben"
        case .reactionDuel: return "Reaktionsduell"
        case .drinkRoulette: return "Trink-Roulette"
        case .forbiddenWords: return "Verbotene Wörter"
        case .drinkBingo: return "Trinkbingo"
        }
    }

    var emoji: String {
        switch self {
        case .ringOfFire: return "🔥"
        case .horseRace: return "🐎"
        case .busRide: return "🚌"
        case .truthOrDare: return "🎭"
        case .neverHaveIEver: return "🍻"
        case .schocken: return "🎲"
        case .maexchen: return "🎲"
        case .twoTruths: return "🎭"
        case .spy: return "🕵️"
        case .headsUp: return "🙈"
        case .countTo21: return "🔢"
        case .estimation: return "🤔"
        case .categories: return "⏱️"
        case .mostLikely: return "👉"
        case .bombPass: return "💣"
        case .reactionDuel: return "⚡️"
        case .drinkRoulette: return "🎯"
        case .forbiddenWords: return "🤐"
        case .drinkBingo: return "🎉"
        }
    }

    var subtitle: String {
        switch self {
        case .ringOfFire: return "52 Karten im Kreis um die Flasche – jede bedeutet etwas anderes"
        case .horseRace: return "Vier Asse, sechs Seitenkarten – setz auf eine Farbe"
        case .busRide: return "Vier Fragen, jede teurer – ein Fehler und zurück auf Anfang"
        case .truthOrDare: return "90 Karten – verweigern kostet"
        case .neverHaveIEver: return "150 Fragen in drei Stufen, dazu Strafen"
        case .schocken: return "Drei Würfel, drei Würfe – der schlechteste Wurf trinkt"
        case .maexchen: return "Verdeckt würfeln und lügen – die App weiß, wer geflunkert hat"
        case .twoTruths: return "Drei Sätze, einer erfunden – wer danebenliegt, trinkt"
        case .spy: return "Alle kennen das Wort – einer nicht, und der muss es überspielen"
        case .headsUp: return "Handy an die Stirn – jeder verpasste Begriff kostet einen Schluck"
        case .countTo21: return "Reihum zählen – wer 21 sagt, macht eine neue Regel"
        case .estimation: return "50 Fragen mit einer Zahl – wer am weitesten daneben liegt, trinkt"
        case .categories: return "Reihum ein Begriff – die Bedenkzeit wird jede Runde knapper"
        case .mostLikely: return "Alle zeigen gleichzeitig – die meisten Finger trinken"
        case .bombPass: return "Zünden, herumreichen, nicht drauf sitzen bleiben"
        case .reactionDuel: return "Zwei Daumen, ein Signal – wer zu früh tippt, verliert"
        case .drinkRoulette: return "Acht Felder, ein Zeiger – keine Einrichtung nötig"
        case .forbiddenWords: return "Jeder zieht ein Wort, das er den Abend über nicht sagen darf"
        case .drinkBingo: return "Sechzehn Felder, die von selbst passieren"
        }
    }

    /// Wie es gespielt wird, in drei bis vier Saetzen.
    ///
    /// Bis Oktober 2026 hatte nur Beerpong einen Regel-Screen. Die
    /// Partyspiele erklaerten sich im Spiel selbst – wer neu am Tisch stand,
    /// musste fragen, und wer als Gastgeber die Regeln kannte, musste sie
    /// neunzehnmal erzaehlen.
    ///
    /// Steht hier im Katalog und nicht in den Spielen: Dort stuende sie in
    /// neunzehn verschiedenen Formen, und ein neues Spiel haette sie
    /// garantiert nicht.
    var howToPlay: String {
        switch self {
        case .ringOfFire:
            return "Die Karten liegen verdeckt im Kreis. Wer dran ist, tippt „Karte ziehen“ – die App lost aus, welche es wird, und sagt, was zu tun ist. Manche Karten gelten nur im Moment, andere bis zum Spielende; das steht auf jeder Karte. Vorher stellt ihr ein, mit wie vielen Karten ihr spielt."
        case .horseRace:
            return "Vier Asse laufen um die Wette. Jeder setzt vorher auf eine Farbe – tippt euch in der Liste auf euer Pferd, dann weiß die App später, wer trinkt. Aufgedeckte Karten schieben das passende Pferd vor; die Seitenkarten schicken es zurück, sobald alle daran vorbei sind."
        case .busRide:
            return "Vier Fragen nacheinander: Rot oder Schwarz, höher oder tiefer, dazwischen oder draußen, welche Farbe. Jede richtige Antwort bringt dich eine Stufe weiter, jede falsche kostet – und zurück auf Anfang. Wer durchkommt, ist raus."
        case .truthOrDare:
            return "Wahrheit oder Pflicht, wie immer – nur dass die App die Karten stellt. Wer verweigert, trinkt die Menge, die auf der Karte steht. Eigene Karten lassen sich im Hauptmenü dazumischen."
        case .neverHaveIEver:
            return "Die App liest vor, was du noch nie getan hast. Wer es doch getan hat, trinkt. Drei Härtestufen – harmlos, deftig, und was man danach besser vergisst."
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
        case .bombPass:
            return "Zünden und weiterreichen. Die App zählt, aber nicht sichtbar – irgendwann geht sie hoch. Wer sie dann in der Hand hält, trinkt."
        case .reactionDuel:
            return "Zwei Daumen auf dem Bildschirm, beide warten auf das Signal. Wer zuerst tippt, gewinnt – wer zu früh tippt, verliert sofort."
        case .drinkRoulette:
            return "Rad drehen, Feld abwarten, machen was dasteht. Keine Einrichtung, keine Erklärung – das Spiel für zwischendurch."
        case .forbiddenWords:
            return "Jeder zieht ein Wort, das er den ganzen Abend nicht sagen darf, und merkt es sich. Wer sein Wort trotzdem sagt und dabei erwischt wird, trinkt. Das Handy wandert einmal rum, damit niemand die Wörter der anderen sieht."
        case .drinkBingo:
            return "Sechzehn Felder mit Dingen, die an so einem Abend von selbst passieren. Passiert eins, tippt es an. Wer eine Reihe voll hat, ruft Bingo und verteilt."
        }
    }

    var tint: Color {
        switch self {
        case .ringOfFire, .drinkRoulette, .countTo21:
            return BeerStatsColor.error
        case .horseRace, .neverHaveIEver, .estimation, .drinkBingo:
            return BeerStatsColor.success
        case .busRide, .maexchen, .spy, .bombPass:
            return BeerStatsColor.accentSecondary
        case .schocken, .categories, .forbiddenWords:
            return BeerStatsColor.warning
        case .truthOrDare, .twoTruths, .headsUp, .mostLikely, .reactionDuel:
            return BeerStatsColor.accent
        }
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
             .estimation, .categories, .bombPass, .reactionDuel:
            return true
        case .ringOfFire, .horseRace, .truthOrDare, .neverHaveIEver,
             .twoTruths, .spy, .mostLikely, .drinkRoulette,
             .forbiddenWords, .drinkBingo:
            return false
        }
    }

    // MARK: - Ziel

    /// Bewusst `AnyView` statt `@ViewBuilder`.
    ///
    /// Ein ViewBuilder-`switch` ueber neunzehn verschiedene View-Typen baut
    /// einen tief verschachtelten `_ConditionalContent`-Typ auf. Das laesst
    /// sich zwar uebersetzen, treibt die Uebersetzungszeit aber steil hoch –
    /// und hier gibt es nichts zu gewinnen: Das Ziel wird genau einmal
    /// erzeugt, wenn jemand die Karte antippt.
    var destination: AnyView {
        switch self {
        case .ringOfFire: return AnyView(RingOfFireView())
        case .horseRace: return AnyView(HorseRaceView())
        case .busRide: return AnyView(BusRideView())
        case .truthOrDare: return AnyView(TruthOrDareView())
        case .neverHaveIEver: return AnyView(NeverHaveIEverView())
        case .schocken: return AnyView(SchockenView())
        case .maexchen: return AnyView(MaexchenView())
        case .twoTruths: return AnyView(TwoTruthsView())
        case .spy: return AnyView(SpyView())
        case .headsUp: return AnyView(HeadsUpView())
        case .countTo21: return AnyView(CountTo21View())
        case .estimation: return AnyView(EstimationView())
        case .categories: return AnyView(CategoriesView())
        case .mostLikely: return AnyView(MostLikelyView())
        case .bombPass: return AnyView(BombPassView())
        case .reactionDuel: return AnyView(ReactionDuelView())
        case .drinkRoulette: return AnyView(DrinkRouletteView())
        case .forbiddenWords: return AnyView(ForbiddenWordsView())
        case .drinkBingo: return AnyView(DrinkBingoView())
        }
    }
}

/// Merkt sich die zuletzt geöffneten Spiele.
///
/// Ein Abend spielt zwei bis drei Spiele und scrollt sonst an neunzehn
/// vorbei. Die drei stehen deshalb oben.
///
/// Gespeichert werden nur die Kennungen. Faellt ein Spiel irgendwann weg,
/// verschwindet es dadurch von selbst aus der Liste, statt beim Antippen
/// ins Leere zu fuehren.
enum RecentPartyGames {

    private static let storageKey = "partyGames.recent"
    private static let limit = 3

    static var games: [PartyGame] {
        let ids = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        return ids.compactMap(PartyGame.init(rawValue:))
    }

    static func record(_ game: PartyGame) {
        var ids = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        ids.removeAll { $0 == game.rawValue }
        ids.insert(game.rawValue, at: 0)
        UserDefaults.standard.set(Array(ids.prefix(limit)), forKey: storageKey)
    }
}
