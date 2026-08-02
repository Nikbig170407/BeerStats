//
//  NeverHaveIEverDeck.swift
//  BeerStats
//
//  Karteninhalt fuer Ich hab noch nie.
//
//  Bewusst als eigene Datei getrennt von der Ansicht: Der Inhalt ist das,
//  was sich am haeufigsten aendert. Eine Karte zu ergaenzen soll heissen,
//  eine Zeile in eine Liste zu schreiben – nicht eine View anzufassen.
//
//  Strafen sind keine dritte Stufe, sondern Zwischenkarten. Als eigener
//  Block waeren sie berechenbar; alle fuenf bis sechs Fragen eingestreut
//  unterbrechen sie den Rhythmus genau dann, wenn er sich einspielt.
//

import Foundation

/// Stufe einer Frage. Strafen tauchen hier bewusst nicht auf – sie sind
/// keine Frage und werden nicht gewaehlt, sondern eingestreut.
enum NeverHaveIEverLevel: String, CaseIterable, Identifiable, Codable {
    case kids
    case spicy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kids: return "Kinder"
        case .spicy: return "Spicy"
        }
    }

    var subtitle: String {
        switch self {
        case .kids: return "Jugendfrei, geht mit jedem"
        case .spicy: return "Fuer spaeter am Abend"
        }
    }

    var emoji: String {
        switch self {
        case .kids: return "🧒"
        case .spicy: return "🔥"
        }
    }
}

struct NeverHaveIEverCard: Identifiable, Equatable {

    enum Kind: Equatable {
        case statement(NeverHaveIEverLevel)
        case penalty
    }

    let id = UUID()
    let text: String
    let kind: Kind

    var isPenalty: Bool {
        if case .penalty = kind { return true }
        return false
    }

    var level: NeverHaveIEverLevel? {
        if case .statement(let level) = kind { return level }
        return nil
    }
}

enum NeverHaveIEverDeck {

    /// Abstand zwischen zwei Strafen, in Fragen gemessen. Als Spanne und
    /// nicht als feste Zahl – sonst zaehlt die Runde nach zwei Strafen mit
    /// und weiss, wann die naechste kommt.
    private static let penaltyGap = 5...6

    static let statements: [NeverHaveIEverCard] = kids + spicy

    /// Baut den Stapel fuer eine Runde: Fragen der gewaehlten Stufen,
    /// gemischt, mit eingestreuten Strafen.
    static func shuffled(
        levels: Set<NeverHaveIEverLevel>,
        includePenalties: Bool
    ) -> [NeverHaveIEverCard] {

        let questions = statements
            .filter { card in card.level.map { levels.contains($0) } ?? false }
            .shuffled()

        guard includePenalties, !penalties.isEmpty else { return questions }

        // Aus einem gemischten Vorrat ziehen statt jedes Mal frei zu greifen:
        // So kommt keine Strafe ein zweites Mal, bevor die anderen dran
        // waren. Ist der Vorrat leer, wird neu gemischt.
        var pool = penalties.shuffled()
        var deck: [NeverHaveIEverCard] = []
        var untilNextPenalty = Int.random(in: penaltyGap)

        for question in questions {
            deck.append(question)
            untilNextPenalty -= 1
            guard untilNextPenalty <= 0 else { continue }

            if pool.isEmpty { pool = penalties.shuffled() }
            deck.append(pool.removeLast())
            untilNextPenalty = Int.random(in: penaltyGap)
        }

        return deck
    }

    static func questionCount(for level: NeverHaveIEverLevel) -> Int {
        statements.filter { $0.level == level }.count
    }

    // MARK: - Kinder

    private static let kids: [NeverHaveIEverCard] = [
        "einen ganzen Tag im Schlafanzug verbracht",
        "beim Karaoke gesungen",
        "eine Serie an einem Tag durchgeschaut",
        "auf einer Beerdigung gelacht",
        "meinen eigenen Namen gegoogelt",
        "einen Tanz vor dem Spiegel geübt",
        "ein Buch gekauft und nie gelesen",
        "eine Woche lang dieselbe Hose getragen",
        "meinem Haustier eine ganze Geschichte erzählt",
        "einen Film geschaut, nur weil das Plakat gut aussah",
        "eine Pflanze zu Tode gepflegt",
        "die Fernbedienung im Kühlschrank gefunden",
        "im Zug in der falschen Richtung gesessen",
        "einen Wecker gestellt und trotzdem verschlafen",
        "beim Puzzeln ein Teil versteckt, um es zuletzt zu legen",
        "mich beim Kochen so verschnitten, dass ich aufgeben musste",
        "im Supermarkt jemanden gegrüßt, den ich gar nicht kannte",
        "beim Wandern die Karte falsch gelesen und mich verlaufen",
        "so getan, als hätte ich einen Podcast gehört",
        "an einem Feiertag gearbeitet, obwohl ich frei hatte",
        "eine Achterbahn mit geschlossenen Augen gefahren",
        "mich vor einem Gewitter unter der Decke versteckt",
        "beim Monopoly heimlich Geld aus der Bank genommen",
        "ein Lied mitgesungen, obwohl ich den Text nicht kann",
        "einen Schneemann gebaut und ihm einen Namen gegeben",
        "mich im eigenen Zuhause ausgesperrt",
        "ein Selfie mehr als zehnmal wiederholt",
        "beim Zahnarzt so getan, als würde es nicht wehtun",
        "einen Regenschirm irgendwo liegen lassen",
        "mit vollem Mund geredet und dabei etwas verschüttet",
        "eine Türklingel gedrückt und bin weggerannt",
        "Hausaufgaben in der Pause abgeschrieben",
        "behauptet, ich hätte das Buch gelesen, obwohl ich nur den Film kenne",
        "mich beim Fangenspielen absichtlich fangen lassen",
        "auf einer Rolltreppe gegen die Laufrichtung gelaufen"
    ].map { NeverHaveIEverCard(text: $0, kind: .statement(.kids)) }

    // MARK: - Spicy

    private static let spicy: [NeverHaveIEverCard] = [
        "jemanden geküsst, den ich am selben Abend erst kennengelernt habe",
        "in einem fremden Bett aufgewacht",
        "mit jemandem aus dieser Runde geflirtet",
        "ein Date mit nach Hause genommen",
        "geküsst, während jemand anderes zugeschaut hat",
        "an einem sehr öffentlichen Ort rumgemacht",
        "im Auto rumgemacht",
        "jemanden geküsst, der vergeben war",
        "mit jemandem geschlafen und danach nie wieder geschrieben",
        "jemanden aus dieser Runde attraktiv gefunden",
        "mit zwei Leuten gleichzeitig geschrieben",
        "behauptet, ich sei vergeben, um jemanden loszuwerden",
        "ein Foto verschickt, das ich am nächsten Tag bereut habe",
        "mit jemandem geflirtet, um etwas zu bekommen",
        "ein Dating-Profil geschönt",
        "jemanden geküsst, dessen Namen ich nicht wusste",
        "jemandem einen Korb gegeben und es später bereut",
        "beim ersten Date schon geküsst",
        "mit jemandem aus dem Freundeskreis etwas gehabt",
        "eine Affäre für mich behalten",
        "morgens heimlich gegangen, bevor der andere wach war",
        "jemanden nach einer Nacht wieder heimgeschickt",
        "beim Sex lachen müssen",
        "so getan, als wäre es gut gewesen",
        "etwas im Nachttisch, das ich niemandem zeigen würde",
        "jemanden geküsst und danach so getan, als wäre nichts",
        "beim Rummachen den falschen Namen gesagt",
        "ein Date abgebrochen, weil es zu peinlich wurde",
        "jemandem hinterhergeschaut, während mein Date sprach",
        "mich in jemanden aus dieser Runde mal verguckt",
        "fast erwischt worden",
        "jemanden zurückgeschrieben, den ich eigentlich gelöscht hatte"
    ].map { NeverHaveIEverCard(text: $0, kind: .statement(.spicy)) }

    // MARK: - Strafen

    private static let penalties: [NeverHaveIEverCard] = [
        "Trink einen Shot",
        "Trink 5 Schlücke",
        "Trink 3 Schlücke",
        "Verteile 5 Schlücke",
        "Alle trinken 2 Schlücke",
        "Bestimme jemanden, der einen Shot trinkt",
        "Dein linker Nachbar trinkt 3 Schlücke",
        "Dein rechter Nachbar trinkt einen Shot",
        "Trink so viele Schlücke, wie du Geschwister hast",
        "Der Jüngste in der Runde trinkt 3 Schlücke",
        "Der Älteste in der Runde trinkt 3 Schlücke",
        "Wer zuletzt gelacht hat, trinkt 2 Schlücke",
        "Wer als Letztes die Hand hebt, trinkt einen Shot",
        "Trink 4 Schlücke und verteile 4",
        "Wer heute am weitesten angereist ist, trinkt 3 Schlücke",
        "Der Gastgeber trinkt 2 Schlücke",
        "Alle, die gerade stehen, trinken 3 Schlücke",
        "Reihum ein Schluck, bis jemand lacht"
    ].map { NeverHaveIEverCard(text: $0, kind: .penalty) }
}
