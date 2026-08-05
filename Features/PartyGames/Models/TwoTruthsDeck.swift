//
//  TwoTruthsDeck.swift
//  BeerStats
//
//  Themen fuer "Zwei Wahrheiten, eine Luege".
//
//  Die App gibt ein Thema vor, statt die Runde frei erfinden zu lassen. Ohne
//  Vorgabe erzaehlt jeder dieselben drei Geschichten, die er immer erzaehlt –
//  und wer sie kennt, gewinnt jedes Mal. Ein enges Thema zwingt zu neuem
//  Material.
//
//  Alle Themen so gewaehlt, dass jeder etwas dazu hat. "Deine Zeit beim
//  Militaer" waere ein Thema fuer drei Leute am Tisch.
//

import Foundation

enum TwoTruthsDeck {

    static var count: Int { all.count }

    static func shuffled() -> [String] { all.shuffled() }

    static let all: [String] = [
        "Deine Schulzeit",
        "Dein peinlichster Moment",
        "Dein letzter Urlaub",
        "Deine Familie",
        "Dein erstes Date",
        "Deine schlimmste Verletzung",
        "Dein seltsamster Job",
        "Deine Kindheit",
        "Dein größter Fehlkauf",
        "Deine Nachbarn",
        "Dein schlimmster Kater",
        "Deine versteckten Talente",
        "Dein letzter Streit",
        "Dein Führerschein",
        "Deine erste Wohnung",
        "Dein schlimmstes Essen",
        "Dein größter Fan-Moment",
        "Deine Haustiere",
        "Dein dümmster Unfall",
        "Deine schlechteste Idee",
        "Dein letztes Konzert",
        "Deine erste Liebe",
        "Dein Verhältnis zu Sport",
        "Deine Angewohnheiten",
        "Dein letzter Arztbesuch",
        "Deine Erfahrungen mit Technik",
        "Dein größter Glücksmoment",
        "Deine Zeit im Ausland",
        "Dein Verhältnis zu Geld",
        "Deine Erfahrungen mit Behörden",
        "Dein schlimmster Auftritt vor Leuten",
        "Deine Geschwister",
        "Dein letzter Umzug",
        "Deine Erfahrungen im Straßenverkehr",
        "Dein merkwürdigster Traum",
        "Deine schlimmste Note",
        "Dein größtes Missverständnis",
        "Deine Erfahrungen mit Tieren",
        "Dein letztes Geschenk",
        "Deine schlimmste Lüge"
    ]
}
