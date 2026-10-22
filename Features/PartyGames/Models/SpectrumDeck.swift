//
//  SpectrumDeck.swift
//  BeerStats
//
//  Gegensatzpaare fuer "Die Skala".
//
//  Eine gute Skala hat eine **Mitte, ueber die man streiten kann**. "Tot –
//  lebendig" ist keine: Dazwischen liegt nichts, und jeder Hinweis waere
//  entweder ganz links oder ganz rechts. "Harmlos – gefaehrlich" ist eine:
//  Zwischen einer Biene und einem Hai liegt ein ganzer Abend.
//
//  Zweite Bedingung: Beide Enden muessen ohne Erklaerung verstanden werden.
//  Wer erst fragen muss, was mit einem Pol gemeint ist, hat den Hinweis
//  schon halb gehoert.
//
//  Die Reihenfolge der Pole ist Absicht und nicht egal: Links steht der
//  Pol, der sich "weniger" anfuehlt. Die Runde liest die Skala von links
//  nach rechts wie eine Lautstaerke.
//

import Foundation

struct SpectrumCard: Equatable, Identifiable {
    let left: String
    let right: String

    var id: String { "\(left)|\(right)" }
}

enum SpectrumDeck {

    static var count: Int { all.count }

    static func shuffled() -> [SpectrumCard] { all.shuffled() }

    private static func card(_ left: String, _ right: String) -> SpectrumCard {
        SpectrumCard(left: left, right: right)
    }

    static let all: [SpectrumCard] = [
        card("kalt", "heiß"),
        card("harmlos", "gefährlich"),
        card("unterbewertet", "überbewertet"),
        card("billig", "teuer"),
        card("langweilig", "aufregend"),
        card("leise", "laut"),
        card("klein", "riesig"),
        card("ungesund", "gesund"),
        card("hässlich", "schön"),
        card("alt", "modern"),
        card("einfach", "kompliziert"),
        card("peinlich", "cool"),
        card("Fast Food", "Sternerestaurant"),
        card("schlechter Film", "Meisterwerk"),
        card("Alltagskleidung", "Verkleidung"),
        card("Haustier", "Wildtier"),
        card("Kindergeburtstag", "Clubnacht"),
        card("Wasser", "Hochprozentiges"),
        card("Frühstück", "Nachtisch"),
        card("Hobby", "Beruf"),
        card("nervig", "entspannend"),
        card("spießig", "rebellisch"),
        card("vergesslich", "nachtragend"),
        card("schüchtern", "aufdringlich"),
        card("sparsam", "verschwenderisch"),
        card("pünktlich", "immer zu spät"),
        card("ordentlich", "chaotisch"),
        card("sanft", "brutal"),
        card("kitschig", "stilvoll"),
        card("süß", "sauer"),
        card("mild", "scharf"),
        card("Pausenbrot", "Festessen"),
        card("verboten", "erlaubt"),
        card("Zufall", "geplant"),
        card("Geheimnis", "öffentlich"),
        card("Anfänger", "Profi"),
        card("nutzlos", "unverzichtbar"),
        card("schwach", "stark"),
        card("langsam", "schnell"),
        card("leicht", "schwer"),
        card("hell", "dunkel"),
        card("trocken", "nass"),
        card("Stadt", "Land"),
        card("Sommer", "Winter"),
        card("Montagmorgen", "Freitagabend"),
        card("Pflicht", "Vergnügen"),
        card("Kopf", "Bauch"),
        card("Regel", "Ausnahme"),
        card("Freundschaft", "Liebe"),
        card("Scherz", "ernst gemeint"),
        card("höflich", "unverschämt"),
        card("Kleinigkeit", "Katastrophe"),
        card("Gerücht", "Tatsache"),
        card("gewöhnlich", "einzigartig"),
        card("Massenware", "Handarbeit"),
        card("altmodisch", "futuristisch"),
        card("kindisch", "erwachsen"),
        card("faul", "fleißig"),
        card("Pech", "Glück"),
        card("Fehler", "Absicht"),
        card("still", "gesprächig"),
        card("vorsichtig", "waghalsig"),
        card("Discounter", "Delikatesse"),
        card("Camping", "Luxushotel"),
        card("Fahrrad", "Sportwagen"),
        card("Hausschuh", "Stöckelschuh"),
        card("Kaffee", "Energydrink"),
        card("Spaziergang", "Marathon"),
        card("Flüstern", "Schreien"),
        card("Zettel", "Tattoo"),
        card("Witz", "Beleidigung"),
        card("Kompliment", "Anmache"),
        card("Trend", "Klassiker"),
        card("Snack", "Mahlzeit"),
        card("warm anziehen", "kalt duschen"),
        card("harmloser Streich", "Straftat"),
        card("Notlüge", "Betrug"),
        card("sympathisch", "anstrengend"),
        card("ruhiger Abend", "Eskalation"),
        card("gesunder Schlaf", "Durchmachen"),
        card("Smalltalk", "tiefes Gespräch"),
        card("Playlist", "Livekonzert"),
        card("Serienabend", "Festival"),
        card("Kuscheltier", "Statussymbol"),
        card("günstig gebraucht", "nagelneu"),
        card("Geschenk", "Gefälligkeit"),
        card("Nachbar", "bester Freund"),
        card("Bekanntschaft", "Verwandtschaft"),
        card("Hausmittel", "Medikament"),
        card("Mythos", "Wissenschaft"),
        card("Sportart", "Zeitvertreib"),
        card("Brettspiel", "Extremsport"),
        card("Sandkasten", "Baustelle"),
        card("Wasserpistole", "Feuerwerk"),
        card("Gartenzwerg", "Kunstwerk"),
        card("Kaugummi", "Dessert"),
        card("Plastikbecher", "Kristallglas"),
        card("Zeltplatz", "Penthouse"),
        card("Warteschlange", "Vorverkauf"),
        card("Hausaufgabe", "Abenteuer"),
        card("Regenschirm", "Sonnenbrille"),
        card("Flohmarkt", "Auktion"),
        card("Mitbringsel", "Erbstück"),
        card("Nickerchen", "Tiefschlaf"),
        card("Katzenjammer", "Vollrausch"),
        card("Aberglaube", "Überzeugung"),
        card("Spitzname", "Beleidigung"),
        card("Lagerfeuer", "Hausbrand"),
        card("Hustenbonbon", "Schnaps"),
        card("Arbeitsessen", "Date"),
        card("Zufallsbekanntschaft", "Seelenverwandte"),
        card("Spaßbad", "Therme"),
        card("Gruppenchat", "Anruf"),
        card("Sprachnachricht", "Brief"),
        card("Bauchgefühl", "Beweis"),
        card("Hobbykoch", "Küchenchef"),
        card("Mitläufer", "Anführer"),
        card("Zuschauer", "Hauptrolle"),
        card("Grillabend", "Staatsbankett"),
        card("Schuluniform", "Abendgarderobe"),
        card("Ausrede", "Begründung"),
        card("Fehlgriff", "Fehlentscheidung"),
        card("Wohnzimmer", "Tanzfläche")
    ]
}
