//
//  SpyDeck.swift
//  BeerStats
//
//  Begriffe fuer "Der Spion".
//
//  Ausgewaehlt nach einem einzigen Kriterium: Jeder muss den Begriff in
//  einem Satz umschreiben koennen, ohne ihn zu verraten. Zu spezielle
//  Begriffe entlarven den Spion sofort, weil die anderen ins Stocken
//  geraten – zu allgemeine machen ihn unsichtbar, weil jeder Satz passt.
//  Orte und Situationen treffen das am besten.
//

import Foundation

enum SpyDeck {

    static var count: Int { all.count }

    static func randomWord() -> String { all.randomElement() ?? "Strand" }

    static let all: [String] = [
        "Strand", "Kino", "Krankenhaus", "Flughafen", "Schwimmbad",
        "Supermarkt", "Zahnarzt", "Fitnessstudio", "Bahnhof", "Zoo",
        "Bibliothek", "Friseursalon", "Tankstelle", "Hotelzimmer", "Casino",
        "Festival", "Hochzeit", "Beerdigung", "Klassenzimmer", "Büro",
        "Baustelle", "Polizeirevier", "Gefängnis", "Kirche", "Museum",
        "Restaurant", "Nachtclub", "Campingplatz", "Skilift", "U-Boot",
        "Raumstation", "Zirkus", "Bauernhof", "Weinkeller", "Dachterrasse",
        "Waschsalon", "Spielplatz", "Fußballstadion", "Konzert", "Theater",
        "Flugzeug", "Kreuzfahrtschiff", "Achterbahn", "Sauna", "Eisdiele",
        "Bäckerei", "Metzgerei", "Autowerkstatt", "Apotheke", "Postfiliale",
        "Fahrschule", "Wartezimmer", "Aufzug", "Keller", "Dachboden",
        "Garage", "Balkon", "Küche", "Badezimmer", "Schlafzimmer",
        "Wüste", "Dschungel", "Berggipfel", "Höhle", "Leuchtturm",
        "Windmühle", "Schloss", "Ruine", "Friedhof", "Jahrmarkt",
        "Tätowierstudio", "Plattenladen", "Buchhandlung", "Möbelhaus", "Baumarkt",
        "Elektromarkt", "Wochenmarkt", "Imbiss", "Bierzelt", "Kegelbahn"
    ]
}
