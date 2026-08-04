//
//  KingsCupRules.swift
//  BeerStats
//
//  Das Regelwerk des Koenigsbechers: Jeder Rang bedeutet etwas anderes.
//
//  Als eigene Datei, weil genau hier jede Runde eigene Hausregeln hat. Wer
//  "Bube" lieber als Daumenmeister spielt, aendert eine Zeile und nichts
//  sonst.
//
//  Zwei Regeln sind bewusst milder gehalten, als man sie oft spielt: Es
//  bleibt bei Schluecken statt Glaesern, und der Wasserfall hat ein
//  definiertes Ende. Ein Spiel, das reihenweise Glaeser leert, ist nach
//  zwanzig Minuten vorbei.
//

import Foundation

struct KingsCupRule: Equatable {
    let title: String
    let text: String
    let emoji: String
    /// Koenige sind der einzige Rang, der den Becher in der Mitte fuellt –
    /// die Ansicht muss sie deshalb gesondert behandeln.
    var isKing: Bool = false
}

enum KingsCupRules {

    static func rule(for rank: Int) -> KingsCupRule {
        switch rank {
        case 2:
            return KingsCupRule(
                title: "Du",
                text: "Bestimme jemanden. Diese Person trinkt 2 Schlücke.",
                emoji: "👉"
            )
        case 3:
            return KingsCupRule(
                title: "Ich",
                text: "Pech gehabt: Du trinkst 3 Schlücke.",
                emoji: "🙋"
            )
        case 4:
            return KingsCupRule(
                title: "Boden",
                text: "Alle fassen den Boden an. Wer als Letzter unten ist, trinkt 3 Schlücke.",
                emoji: "⬇️"
            )
        case 5:
            return KingsCupRule(
                title: "Himmel",
                text: "Alle Hände hoch. Wer als Letzter oben ist, trinkt 3 Schlücke.",
                emoji: "☝️"
            )
        case 6:
            return KingsCupRule(
                title: "Deine Linke",
                text: "Dein linker Nachbar trinkt 3 Schlücke.",
                emoji: "⬅️"
            )
        case 7:
            return KingsCupRule(
                title: "Deine Rechte",
                text: "Dein rechter Nachbar trinkt 3 Schlücke.",
                emoji: "➡️"
            )
        case 8:
            return KingsCupRule(
                title: "Partner",
                text: "Such dir einen Trinkpartner. Ab jetzt trinkt er jedes Mal mit, wenn du trinken musst.",
                emoji: "🤝"
            )
        case 9:
            return KingsCupRule(
                title: "Reim",
                text: "Sag ein Wort. Reihum wird darauf gereimt. Wer nichts mehr findet, trinkt 3 Schlücke.",
                emoji: "🎤"
            )
        case 10:
            return KingsCupRule(
                title: "Kategorie",
                text: "Nenne eine Kategorie. Reihum nennt jeder einen Begriff. Wer patzt, trinkt 3 Schlücke.",
                emoji: "📚"
            )
        case 11:
            return KingsCupRule(
                title: "Regel",
                text: "Erfinde eine Regel für den Rest des Spiels. Wer sie bricht, trinkt 2 Schlücke.",
                emoji: "📜"
            )
        case 12:
            return KingsCupRule(
                title: "Fragenmeister",
                text: "Bis die nächste Dame kommt, trinkt jeder 2 Schlücke, der dir auf eine Frage antwortet.",
                emoji: "❓"
            )
        case 13:
            return KingsCupRule(
                title: "Königsbecher",
                text: "Gieß einen Schluck in den Becher in der Mitte.",
                emoji: "👑",
                isKing: true
            )
        default:
            return KingsCupRule(
                title: "Wasserfall",
                text: "Alle fangen gleichzeitig an. Absetzen darf erst, wessen linker Nachbar abgesetzt hat – du fängst an.",
                emoji: "🌊"
            )
        }
    }
}
