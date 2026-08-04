//
//  RingOfFireRules.swift
//  BeerStats
//
//  Das Regelwerk von Ring of Fire: Jeder Rang bedeutet etwas anderes.
//
//  Vier Raenge wirken ueber den Moment hinaus – Bube, Dame, Acht und Zehn.
//  Am echten Tisch legt man diese Karte vor sich hin, und genau das ist ihr
//  Sinn: Sie erinnert alle daran, dass die Rolle noch laeuft. Die App fuehrt
//  sie deshalb in einer Merkliste, sonst waere die Rolle mit dem naechsten
//  Kartenwechsel vergessen.
//
//  Ersetzt den frueheren Koenigsbecher. Zwei fast gleiche Kartenspiele im
//  Menue haben mehr verwirrt, als sie gebracht haben.
//

import Foundation

/// Eine Rolle, die nach dem Ziehen weiterlaeuft.
enum RingOfFireRole: String, Identifiable, CaseIterable {
    case thumbMaster
    case questionQueen
    case drinkingMate
    case houseRule

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thumbMaster: return "Daumenmeister"
        case .questionQueen: return "Question Queen"
        case .drinkingMate: return "Trink-Duo"
        case .houseRule: return "Regeln"
        }
    }

    var emoji: String {
        switch self {
        case .thumbMaster: return "👍"
        case .questionQueen: return "👑"
        case .drinkingMate: return "🤝"
        case .houseRule: return "📜"
        }
    }
}

struct RingOfFireRule: Equatable {
    /// Deutscher Name, gross auf der Karte.
    let title: String
    /// Der gelaeufige Name aus dem Spiel – steht klein darueber.
    let nickname: String
    let text: String
    let emoji: String
    var role: RingOfFireRole?
}

enum RingOfFireRules {

    static func rule(for rank: Int) -> RingOfFireRule {
        switch rank {
        case 2:
            return RingOfFireRule(
                title: "Du bestimmst",
                nickname: "TWO FOR YOU",
                text: "Bestimme jemanden. Diese Person trinkt \(DrinkAmount.sips(2).text).",
                emoji: "👉"
            )
        case 3:
            return RingOfFireRule(
                title: "Du selbst",
                nickname: "THREE FOR ME",
                text: "Pech gehabt: Du trinkst \(DrinkAmount.sips(3).text).",
                emoji: "🙋"
            )
        case 4:
            return RingOfFireRule(
                title: "Wasserfall",
                nickname: "FOUR – WATERFALL",
                text: "Alle fangen gleichzeitig an. Absetzen darf erst, wessen linker Nachbar abgesetzt hat – du fängst an.",
                emoji: "🌊"
            )
        case 5:
            return RingOfFireRule(
                title: "Deine Linke",
                nickname: "FIVE – LEFT",
                text: "Dein linker Nachbar trinkt \(DrinkAmount.sips(3).text).",
                emoji: "⬅️"
            )
        case 6:
            return RingOfFireRule(
                title: "Deine Rechte",
                nickname: "SIX – RIGHT",
                text: "Dein rechter Nachbar trinkt \(DrinkAmount.sips(3).text).",
                emoji: "➡️"
            )
        case 7:
            return RingOfFireRule(
                title: "Hände hoch",
                nickname: "SEVEN TO HEAVEN",
                text: "Alle Hände sofort nach oben! Wer als Letzter oben ist, trinkt \(DrinkAmount.sips(3).text).",
                emoji: "☝️"
            )
        case 8:
            return RingOfFireRule(
                title: "Trink-Duo",
                nickname: "EIGHT – MATE",
                text: "Such dir einen Trinkpartner. Ab jetzt trinkt ihr immer zusammen: Muss einer trinken, trinkt der andere dieselbe Menge mit.",
                emoji: "🤝",
                role: .drinkingMate
            )
        case 9:
            return RingOfFireRule(
                title: "Reimen",
                nickname: "NINE – RHYME",
                text: "Sag ein Wort. Reihum wird darauf gereimt. Wer nichts findet oder sich wiederholt, trinkt \(DrinkAmount.sips(3).text).",
                emoji: "🎤"
            )
        case 10:
            return RingOfFireRule(
                title: "Zehn Gebote",
                nickname: "TEN – RULE",
                text: "Stell eine Regel auf, die ab sofort für alle gilt. Wer sie missachtet, trinkt \(DrinkAmount.sips(2).text).",
                emoji: "📜",
                role: .houseRule
            )
        case 11:
            return RingOfFireRule(
                title: "Daumenmeister",
                nickname: "JACK – DUMB BUMB",
                text: "Leg die Karte vor dich. Wann immer du den Daumen auf den Tisch legst, müssen alle nachziehen. Wer als Letzter unten ist, trinkt \(DrinkAmount.sips(3).text). Gilt bis zum Spielende.",
                emoji: "👍",
                role: .thumbMaster
            )
        case 12:
            return RingOfFireRule(
                title: "Question Queen",
                nickname: "QUEEN – QUESTION",
                text: "Leg die Karte vor dich. Wer dir ab jetzt auf eine Frage antwortet, trinkt \(DrinkAmount.sips(2).text). Gilt bis zum Spielende.",
                emoji: "👑",
                role: .questionQueen
            )
        case 13:
            return RingOfFireRule(
                title: "Kategorie",
                nickname: "KING – CATEGORY",
                text: "Nenne eine Kategorie. Reihum nennt jeder einen Begriff. Wer patzt oder sich wiederholt, trinkt \(DrinkAmount.sips(3).text).",
                emoji: "📚"
            )
        default:
            return RingOfFireRule(
                title: "Ass",
                nickname: "ACE – SHOT",
                text: "Du trinkst \(DrinkAmount.shot.text).",
                emoji: "🥃"
            )
        }
    }
}
