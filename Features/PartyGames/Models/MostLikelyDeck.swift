//
//  MostLikelyDeck.swift
//  BeerStats
//
//  Karteninhalt fuer "Wer von uns?".
//
//  Auf drei zaehlt die Runde und alle zeigen gleichzeitig auf jemanden.
//  Wer die meisten Finger auf sich hat, trinkt. Das Gleichzeitige ist der
//  ganze Reiz – nacheinander waere es eine Umfrage.
//
//  Wie bei "Ich hab noch nie" traegt jede Karte den vollstaendigen Satz.
//

import Foundation

struct MostLikelyCard: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

enum MostLikelyDeck {

    static func shuffled() -> [MostLikelyCard] { all.shuffled() }

    static var count: Int { all.count }

    static let all: [MostLikelyCard] = [
        "Wer von uns kommt am ehesten zu spät?",
        "Wer von uns würde am ehesten im Gefängnis landen?",
        "Wer von uns wird als Erstes heiraten?",
        "Wer von uns hat den schlimmsten Musikgeschmack?",
        "Wer von uns würde einen Zombie-Angriff überleben?",
        "Wer von uns redet am meisten?",
        "Wer von uns schläft auf jeder Party als Erstes ein?",
        "Wer von uns würde für Geld alles tun?",
        "Wer von uns hat den unaufgeräumtesten Kühlschrank?",
        "Wer von uns würde am ehesten auswandern?",
        "Wer von uns weint bei Filmen?",
        "Wer von uns würde eine Wette nie ausschlagen?",
        "Wer von uns hat die peinlichste Playlist?",
        "Wer von uns würde am ehesten berühmt werden?",
        "Wer von uns kann am schlechtesten kochen?",
        "Wer von uns verschläft den eigenen Geburtstag?",
        "Wer von uns würde ohne Karte durch eine fremde Stadt laufen?",
        "Wer von uns gibt zuerst auf?",
        "Wer von uns hat die verrücktesten Geschichten?",
        "Wer von uns würde am ehesten in einer Reality-Show mitmachen?",
        "Wer von uns antwortet am langsamsten auf Nachrichten?",
        "Wer von uns würde ein Tattoo aus einer Laune heraus stechen lassen?",
        "Wer von uns hat den höchsten Handy-Bildschirmzeit-Wert?",
        "Wer von uns würde bei einem Quiz alles wissen?",
        "Wer von uns lacht über die schlechtesten Witze?",
        "Wer von uns würde als Erstes die Nerven verlieren?",
        "Wer von uns hat am meisten Fotos auf dem Handy?",
        "Wer von uns wäre der beste Gastgeber?",
        "Wer von uns würde eine Diskussion niemals aufgeben?",
        "Wer von uns hat den größten Kleiderschrank?",
        "Wer von uns würde einen Marathon spontan mitlaufen?",
        "Wer von uns kann am besten lügen?",
        "Wer von uns würde als Erstes zurückschreiben, wenn der Ex sich meldet?",
        "Wer von uns hat den schlimmsten Orientierungssinn?",
        "Wer von uns würde einen Streit vom Zaun brechen?",
        "Wer von uns ist morgens am unausstehlichsten?",
        "Wer von uns würde ein Haustier heimlich mit ins Bett nehmen?",
        "Wer von uns gibt am meisten Geld für Unsinn aus?",
        "Wer von uns wäre der schlechteste Autofahrer?",
        "Wer von uns würde bei einer Mutprobe zuerst zusagen?",
        "Wer von uns kann am längsten schweigen?",
        "Wer von uns würde sich in einem Escape Room blamieren?",
        "Wer von uns hat die meisten ungelesenen Nachrichten?",
        "Wer von uns wäre der beste Anwalt?",
        "Wer von uns würde bei einem Karaoke-Abend das Mikro nicht abgeben?",
        "Wer von uns hat die längste To-do-Liste, die nie kürzer wird?",
        "Wer von uns würde auf eine offensichtliche Masche hereinfallen?",
        "Wer von uns steht als Letztes auf der Tanzfläche?",
        "Wer von uns würde bei einem Geheimnis als Erstes reden?",
        "Wer von uns kann am wenigsten vertragen?",
        "Wer von uns würde am ehesten die Bombe in der Hand behalten?",
        "Wer von uns hat den schlechtesten Beerpong-Wurf?",
        "Wer von uns wäre der beste Trainer?",
        "Wer von uns würde ein Konzert absagen, um zu Hause zu bleiben?",
        "Wer von uns hat die skurrilste Sammlung?",
        "Wer von uns würde einen Vortrag ohne Vorbereitung halten?",
        "Wer von uns ist am schwersten aus dem Bett zu bekommen?",
        "Wer von uns würde bei einem Umzug wirklich helfen?",
        "Wer von uns hat die meisten Apps auf dem Handy?",
        "Wer von uns würde als Erstes die Runde nach Hause schicken?"
    ].map { MostLikelyCard(text: $0) }
}
