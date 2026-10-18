//
//  LiveGameNaming.swift
//  BeerStats
//
//  Wie Leute und Teams in diesem Spiel heissen.
//
//  Stand verstreut im ViewModel: vier fast gleiche Funktionen, jede mit
//  ihrer eigenen `guard teams.indices.contains(...)`-Zeile, und benutzt
//  wurden sie von allem – dem Protokoll, den Einblendungen, dem
//  Sperrbildschirm, der Zugzeile. Als eigener Wert ist es eine Sache, die
//  man weiterreichen kann, statt einer Faehigkeit des ViewModels.
//
//  Gerechnet wird hier nichts: Die Zeichenarbeit samt Grammatik liegt in
//  `Team` und ist dort getestet. Das hier sind die Fallschirme fuer den
//  Fall, dass ein Index ins Leere zeigt.
//

import Foundation

struct LiveGameNaming {

    let teams: [Team]

    func player(_ player: PlayerRef) -> String {
        guard teams.indices.contains(player.teamIndex) else {
            return "Spieler \(player.slot + 1)"
        }
        let names = teams[player.teamIndex].playerNames
        guard names.indices.contains(player.slot) else { return "Spieler \(player.slot + 1)" }
        return names[player.slot]
    }

    /// Nach den Leuten, nicht "Team 1".
    func team(_ index: Int) -> String {
        guard teams.indices.contains(index) else { return "Team \(index + 1)" }
        return teams[index].displayName(fallbackIndex: index)
    }

    /// Kurzform fuer enge Stellen – Team-Leiste und Sperrbildschirm.
    func shortTeam(_ index: Int) -> String {
        guard teams.indices.contains(index) else { return "Team \(index + 1)" }
        return teams[index].shortDisplayName(fallbackIndex: index)
    }

    /// Das Verb zur Teamgroesse: "wirft" oder "werfen".
    func verb(_ index: Int, _ singular: String, _ plural: String) -> String {
        guard teams.indices.contains(index) else { return singular }
        return teams[index].verb(singular, plural)
    }
}
