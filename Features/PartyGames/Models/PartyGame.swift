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

        var title: String {
            switch self {
            case .cards: return "MIT KARTEN"
            case .talking: return "RATEN & REDEN"
            case .quick: return "SCHNELL ZWISCHENDURCH"
            case .alongside: return "LÄUFT NEBENHER"
            }
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
