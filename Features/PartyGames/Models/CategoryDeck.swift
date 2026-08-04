//
//  CategoryDeck.swift
//  BeerStats
//
//  Kategorien fuer das Spiel im Kreis.
//
//  Ausgewaehlt nach einem Kriterium: Jeder in der Runde muss mindestens
//  fuenf Begriffe beisteuern koennen. Eine Kategorie, bei der nach dem
//  dritten Spieler Schluss ist, bestraft nicht die Langsamen, sondern die,
//  die zufaellig spaeter dran sind.
//

import Foundation

enum CategoryDeck {

    static var count: Int { all.count }

    /// Liefert eine neue Kategorie, die nicht die aktuelle ist.
    static func next(after current: String?) -> String {
        guard all.count > 1 else { return all.first ?? "" }
        var pick = all.randomElement() ?? ""
        while pick == current {
            pick = all.randomElement() ?? ""
        }
        return pick
    }

    static let all: [String] = [
        "Biersorten",
        "Automarken",
        "Länder in Europa",
        "Hauptstädte",
        "Dinge im Kühlschrank",
        "Fußballvereine",
        "Cocktails",
        "Tiere mit vier Beinen",
        "Dinge, die man im Bad findet",
        "Filme mit einem Wort im Titel",
        "Serien",
        "Musikinstrumente",
        "Pizzabeläge",
        "Sportarten",
        "Berufe",
        "Süßigkeiten",
        "Dinge in einer Küche",
        "Städte in Deutschland",
        "Vornamen mit A",
        "Vornamen mit M",
        "Comic- und Zeichentrickfiguren",
        "Dinge, die fliegen können",
        "Kleidungsstücke",
        "Brettspiele",
        "Handymarken",
        "Dinge, die rot sind",
        "Obstsorten",
        "Gemüsesorten",
        "Dinge in einem Supermarkt",
        "Superhelden",
        "Musikrichtungen",
        "Dinge, die man mit ins Freibad nimmt",
        "Alkoholische Getränke",
        "Dinge, die man an einer Tankstelle kauft",
        "Wintersportarten",
        "Möbelstücke",
        "Deutsche Bands oder Musiker",
        "Dinge in einem Auto",
        "Meerestiere",
        "Werkzeuge",
        "Dinge, die weh tun",
        "Käsesorten",
        "Getränke ohne Alkohol",
        "Videospiele",
        "Dinge in einem Rucksack",
        "Berühmte Schauspieler",
        "Blumen und Pflanzen",
        "Dinge, die man teilen kann",
        "Fast-Food-Ketten",
        "Dinge auf einem Schreibtisch",
        "Länder außerhalb Europas",
        "Dinge, die Geräusche machen",
        "Sprachen",
        "Dinge im Wohnzimmer",
        "Verkehrsmittel",
        "Brotsorten",
        "Dinge, die man verlieren kann",
        "Streamingdienste und Apps",
        "Dinge, die kalt sind",
        "Gründe, zu spät zu kommen"
    ]
}
