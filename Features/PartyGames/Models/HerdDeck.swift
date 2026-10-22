//
//  HerdDeck.swift
//  BeerStats
//
//  Fragen fuer "Die Herde".
//
//  Das Ziel ist das Gegenteil von dem, was Quizfragen wollen: Es gibt
//  keine richtige Antwort, nur eine **haeufige**. Gewonnen hat, wer denkt
//  wie alle anderen.
//
//  Daraus folgt die Bedingung an jede Frage: Sie muss eine naheliegende
//  Antwort haben – und mindestens eine zweite, die auch jemand sagen
//  wuerde. "Nenne eine Farbe" ist zu offen (zehn Antworten, keine
//  Mehrheit), "Nenne die Hauptstadt von Frankreich" ist zu geschlossen
//  (alle sagen Paris, niemand trinkt). Dazwischen liegt das Spiel.
//
//  Keine Fragen nach Wissen und keine nach Geschmack allein: Beides
//  zerfaellt am Tisch in Diskussionen darueber, ob eine Antwort gilt.
//  Gefragt wird nach dem Naheliegenden.
//

import Foundation

enum HerdDeck {

    static var count: Int { all.count }

    static func shuffled() -> [String] { all.shuffled() }

    static let all: [String] = [
        "Nenne eine Pizza",
        "Nenne ein gelbes Lebensmittel",
        "Nenne ein Tier mit Hörnern",
        "Nenne eine Eissorte",
        "Nenne eine Automarke",
        "Nenne ein Werkzeug",
        "Nenne eine Biersorte",
        "Nenne ein Partyspiel",
        "Nenne einen Wochentag, an dem man ausgeht",
        "Nenne eine Farbe, die zu einer Hochzeit passt",
        "Nenne ein Tier, das man im Zoo sehen will",
        "Nenne eine Sportart, die man im Fernsehen schaut",
        "Nenne etwas, das man auf eine Insel mitnimmt",
        "Nenne etwas, das in jeder Küche steht",
        "Nenne ein Getränk zum Frühstück",
        "Nenne einen Nachtisch",
        "Nenne eine Chipssorte",
        "Nenne einen Supermarkt",
        "Nenne eine Stadt in Deutschland",
        "Nenne ein Land, in dem man Urlaub macht",
        "Nenne eine Jahreszeit, in der man feiert",
        "Nenne ein Kleidungsstück, das jeder besitzt",
        "Nenne etwas, das man ständig verliert",
        "Nenne eine Ausrede fürs Zuspätkommen",
        "Nenne etwas, das man am Montag hasst",
        "Nenne ein Tier, vor dem sich viele fürchten",
        "Nenne einen Beruf aus Kindheitsträumen",
        "Nenne ein Instrument",
        "Nenne eine Musikrichtung",
        "Nenne einen Film, den jeder kennt",
        "Nenne eine Serie, die alle geschaut haben",
        "Nenne einen Superhelden",
        "Nenne ein Brettspiel",
        "Nenne ein Kartenspiel",
        "Nenne eine Süßigkeit aus der Kindheit",
        "Nenne etwas, das man grillt",
        "Nenne eine Beilage",
        "Nenne eine Soße zu Pommes",
        "Nenne ein Frühstücksbrötchen-Belag",
        "Nenne einen Käse",
        "Nenne eine Obstsorte",
        "Nenne ein Gemüse, das Kinder nicht mögen",
        "Nenne ein Fast-Food-Restaurant",
        "Nenne einen Cocktail",
        "Nenne einen Schnaps",
        "Nenne einen Kater-Killer am nächsten Morgen",
        "Nenne etwas, das man nach vier Bier sagt",
        "Nenne etwas, das auf keiner Party fehlen darf",
        "Nenne eine Uhrzeit, zu der man nach Hause geht",
        "Nenne einen Grund, früher zu gehen",
        "Nenne ein Lied, das jeder mitsingt",
        "Nenne einen Weihnachtssong",
        "Nenne eine Band, die alle kennen",
        "Nenne ein Tier, das man als Haustier hält",
        "Nenne einen Hundenamen",
        "Nenne etwas, das in jedem Badezimmer liegt",
        "Nenne etwas, das man nie wegwirft",
        "Nenne etwas aus einer Schublade voller Kram",
        "Nenne ein Möbelstück aus dem Möbelhaus",
        "Nenne ein Elektrogerät",
        "Nenne etwas, das immer kaputtgeht",
        "Nenne eine App auf dem Handy",
        "Nenne etwas, das den Akku leer macht",
        "Nenne ein Passwort, das viele benutzen",
        "Nenne einen Klassiker im Kühlschrank",
        "Nenne eine Pflanze, die in Wohnungen steht",
        "Nenne einen Vornamen, den viele tragen",
        "Nenne einen Namen für ein Kuscheltier",
        "Nenne eine Schulfach-Qual",
        "Nenne ein Lieblingsfach aus der Schule",
        "Nenne einen Streich aus der Schulzeit",
        "Nenne etwas, das man im Urlaub vergisst",
        "Nenne einen Gegenstand im Handgepäck",
        "Nenne ein Souvenir",
        "Nenne ein Verkehrsmittel",
        "Nenne einen Grund für Stau",
        "Nenne etwas, das im Auto herumliegt",
        "Nenne eine Automarke, die als teuer gilt",
        "Nenne ein Tier, das fliegt",
        "Nenne ein Tier im Wald",
        "Nenne ein Meerestier",
        "Nenne ein Insekt",
        "Nenne etwas, das piept",
        "Nenne etwas, das stinkt",
        "Nenne etwas, das klebt",
        "Nenne etwas Rundes",
        "Nenne etwas Kaltes",
        "Nenne etwas, das weh tut",
        "Nenne eine Verletzung beim Sport",
        "Nenne eine Sportart, die gefährlich ist",
        "Nenne eine Fußballmannschaft",
        "Nenne einen Sportler, den jeder kennt",
        "Nenne eine Olympia-Disziplin",
        "Nenne etwas, das man an Silvester macht",
        "Nenne einen guten Vorsatz fürs neue Jahr",
        "Nenne ein Geschenk, über das sich niemand freut",
        "Nenne ein Geschenk, das immer passt",
        "Nenne etwas, das man zum Geburtstag sagt",
        "Nenne eine Farbe, die zu Herbst passt",
        "Nenne ein Wetter, bei dem man drinnen bleibt",
        "Nenne etwas, das man bei Regen macht",
        "Nenne eine Beschäftigung für langweilige Abende",
        "Nenne etwas, das man aufschiebt",
        "Nenne eine Hausarbeit, die keiner machen will",
        "Nenne etwas, das in der WG für Streit sorgt",
        "Nenne einen Gegenstand, den man sich ausleiht",
        "Nenne etwas, das man nie zurückbekommt",
        "Nenne ein typisches deutsches Gericht",
        "Nenne ein Gericht aus Italien",
        "Nenne ein Gewürz",
        "Nenne eine Suppe",
        "Nenne ein Brot",
        "Nenne einen Kuchen",
        "Nenne ein Getränk auf dem Volksfest",
        "Nenne etwas, das man auf dem Jahrmarkt isst",
        "Nenne eine Fahrgeschäft-Art",
        "Nenne einen Zirkusberuf",
        "Nenne ein Märchen",
        "Nenne eine Märchenfigur",
        "Nenne ein Fabelwesen",
        "Nenne einen Zauberspruch",
        "Nenne einen Planeten",
        "Nenne etwas im Weltall",
        "Nenne einen Dinosaurier",
        "Nenne ein Land mit guter Küche",
        "Nenne eine Sprache, die viele lernen",
        "Nenne eine Hauptstadt, die man besucht hat",
        "Nenne ein Wahrzeichen",
        "Nenne einen Fluss",
        "Nenne ein Gebirge",
        "Nenne etwas, das man im Meer nicht sehen will",
        "Nenne einen Grund für Streit in Beziehungen",
        "Nenne eine rote Flagge beim ersten Date",
        "Nenne einen guten Ort für ein erstes Date",
        "Nenne etwas, das man nie zugeben würde"
    ]
}
