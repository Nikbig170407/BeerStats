//
//  NeverHaveIEverDeck.swift
//  BeerStats
//
//  Karteninhalt für „Ich hab noch nie".
//
//  Bewusst als eigene Datei getrennt von der Ansicht: Der Inhalt ist das,
//  was sich am häufigsten ändert. Neue Karten hinzuzufügen soll heißen,
//  eine Zeile in eine Liste zu schreiben – nicht eine View anzufassen.
//
//  Die Stufen sind absichtlich harmlos gehalten. Es ist ein Spiel für den
//  Abend unter Freunden, kein Beichtstuhl; Karten, die jemanden blossstellen
//  oder zu Unvernunft anstacheln, gehören hier nicht rein.
//

import Foundation

enum NeverHaveIEverLevel: String, CaseIterable, Identifiable, Codable {
    case harmless
    case medium
    case spicy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .harmless: return "Harmlos"
        case .medium: return "Mittel"
        case .spicy: return "Frech"
        }
    }

    var emoji: String {
        switch self {
        case .harmless: return "🙂"
        case .medium: return "😏"
        case .spicy: return "🔥"
        }
    }
}

struct NeverHaveIEverCard: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let level: NeverHaveIEverLevel
}

enum NeverHaveIEverDeck {

    /// Liefert einen gemischten Stapel für die gewählten Stufen.
    static func shuffled(levels: Set<NeverHaveIEverLevel>) -> [NeverHaveIEverCard] {
        all.filter { levels.contains($0.level) }.shuffled()
    }

    static let all: [NeverHaveIEverCard] = harmless + medium + spicy

    // MARK: - Harmlos

    private static let harmless: [NeverHaveIEverCard] = [
        "einen ganzen Tag im Schlafanzug verbracht",
        "beim Karaoke gesungen",
        "eine Serie an einem Tag durchgeschaut",
        "mich beim Kochen so verschnitten, dass ich aufgeben musste",
        "auf einer Beerdigung gelacht",
        "meinen eigenen Namen gegoogelt",
        "einen Tanz vor dem Spiegel geübt",
        "ein Buch gekauft und nie gelesen",
        "im Supermarkt aus Versehen jemanden geduzt, den ich nicht kannte",
        "eine Woche lang dieselbe Hose getragen",
        "beim Wandern die Karte falsch gelesen und mich verlaufen",
        "meinem Haustier eine ganze Geschichte erzählt",
        "einen Film geschaut, nur weil das Plakat gut aussah",
        "an einem Feiertag gearbeitet, obwohl ich frei hatte",
        "eine Pflanze zu Tode gepflegt",
        "die Fernbedienung im Kühlschrank gefunden",
        "beim Puzzeln ein Teil versteckt, um es zuletzt zu legen",
        "so getan, als hätte ich einen Podcast gehört",
        "im Zug in der falschen Richtung gesessen",
        "einen Wecker gestellt und trotzdem verschlafen"
    ].map { NeverHaveIEverCard(text: $0, level: .harmless) }

    // MARK: - Mittel

    private static let medium: [NeverHaveIEverCard] = [
        "so getan, als würde ich telefonieren, um jemandem auszuweichen",
        "eine Verabredung in letzter Minute erfunden abgesagt",
        "heimlich die Bewertungen von jemandem gelesen, den ich kenne",
        "beim Wichteln mein eigenes Geschenk zurückbekommen und mich gefreut",
        "jemandem gesagt, sein Essen sei gut, und es heimlich stehen lassen",
        "eine ganze Nacht durchgemacht und danach gearbeitet",
        "mich für ein Foto irgendwo hingestellt, wo ich nicht hindurfte",
        "einen Streit angefangen, obwohl ich wusste, dass ich unrecht habe",
        "die Playlist auf einer Party heimlich übernommen",
        "jemandem eine Nachricht geschickt, die für jemand anderen war",
        "in der Umkleide etwas anprobiert und ohne Kauf wieder aufgehängt",
        "beim Brettspiel geschummelt und gewonnen",
        "im Urlaub etwas gegessen, ohne zu wissen, was es war",
        "eine Rede gehalten, ohne mich vorbereitet zu haben",
        "auf der Autobahn die Ausfahrt verpasst, weil ich mitgesungen habe",
        "einen ganzen Abend lang so getan, als kenne ich eine Band",
        "mich in einem Restaurant über den falschen Tisch beschwert",
        "meine Wohnung nur für Besuch aufgeräumt",
        "beim Sport aufgegeben und behauptet, ich hätte Krämpfe",
        "jemandem zum Geburtstag gratuliert, weil das Handy mich erinnert hat"
    ].map { NeverHaveIEverCard(text: $0, level: .medium) }

    // MARK: - Frech

    private static let spicy: [NeverHaveIEverCard] = [
        "jemanden im Raum schon mal heimlich beneidet",
        "über einen Anwesenden gelästert, bevor ich ihn kannte",
        "bei einem Date so getan, als hätte ich Zeitdruck",
        "eine Nachricht gelesen und absichtlich nicht geantwortet",
        "die Rechnung geteilt, obwohl ich deutlich mehr bestellt hatte",
        "jemanden angeschrieben, nur weil mir langweilig war",
        "so getan, als hätte ich ein Geschenk selbst gemacht",
        "einen Fehler bei der Arbeit jemand anderem überlassen",
        "mich aus einer Runde geschlichen, ohne mich zu verabschieden",
        "das letzte Stück genommen und behauptet, es sei noch da",
        "einen Namen vergessen und ihn den ganzen Abend umschifft",
        "auf einer Party in einem Zimmer geschlafen, das nicht meines war",
        "jemandem gesagt, ich sei schon unterwegs, während ich noch duschte",
        "eine Geschichte erzählt, die eigentlich jemand anderem passiert ist",
        "beim Fotografieren jemanden absichtlich schlecht getroffen",
        "so getan, als wäre mir ein Geschenk zu schade zum Benutzen",
        "einen Wettkampf verloren und behauptet, ich hätte nicht ernst gespielt",
        "mich in eine Diskussion eingemischt, von der ich nichts verstand",
        "jemandem zugestimmt, nur damit das Gespräch endet",
        "an diesem Abend schon jemanden angeflunkert"
    ].map { NeverHaveIEverCard(text: $0, level: .spicy) }
}
