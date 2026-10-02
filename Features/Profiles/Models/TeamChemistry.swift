//
//  TeamChemistry.swift
//  BeerStats
//
//  Mit wem man gewinnt, gegen wen man verliert.
//
//  Die Aufstellungen stehen seit jeher in jeder Partie, und bis hierher hat
//  sie niemand quer gelesen. Dabei ist das die Frage, die am Tisch beim
//  Teams-Auslosen tatsaechlich gestellt wird – "mit dir gewinne ich nie".
//
//  Die Rechnung braucht **keinen einzigen Wurf-Log**: Teams und Sieger
//  stehen im Spiel-Dokument selbst. Damit ist sie um Groessenordnungen
//  billiger als die Zeitraum-Statistik und darf beim Oeffnen eines Profils
//  einfach mitlaufen.
//
//  Reine Funktion ueber fertige Partien, ohne Firebase – dadurch pruefbar.
//

import Foundation

/// Die gemeinsame Bilanz mit einer anderen Person.
struct Pairing: Identifiable, Equatable {

    let profileId: String
    /// Gemeinsame Partien (als Partner) bzw. Partien gegeneinander.
    let games: Int
    /// Siege aus Sicht des betrachteten Spielers.
    let wins: Int

    var id: String { profileId }

    /// Die eigene Siegquote in dieser Paarung.
    ///
    /// `nil` unterhalb der Mindestzahl. Ein Partner, mit dem man genau
    /// einmal gespielt und gewonnen hat, stuende sonst mit hundert Prozent
    /// ganz oben – und waere der „beste Partner", obwohl nichts daran
    /// belastbar ist.
    ///
    /// Unentschieden zaehlen als Partie, aber nicht als Sieg. Sie sind
    /// selten (beide Racks leer) und sollen die Quote nicht aufhuebschen.
    var winRate: Double? {
        guard games >= AppConstants.GameDefaults.minimumGamesForChemistry else { return nil }
        return Double(wins) / Double(games)
    }
}

struct TeamChemistry: Equatable {

    /// Partner, beste gemeinsame Quote zuerst.
    let partners: [Pairing]
    /// Gegner, eigene Quote aufsteigend – der schlimmste steht oben.
    let opponents: [Pairing]

    /// Mit wem es am besten laeuft. Nur Paarungen mit belastbarer Quote.
    var bestPartner: Pairing? {
        partners.first { $0.winRate != nil }
    }

    /// Gegen wen es am schlechtesten laeuft.
    var worstOpponent: Pairing? {
        opponents.first { $0.winRate != nil }
    }

    init(profileId: String, games: [Game]) {
        var partnerTally: [String: (games: Int, wins: Int)] = [:]
        var opponentTally: [String: (games: Int, wins: Int)] = [:]

        for game in games {
            // Nur abgeschlossene Partien. Eine abgebrochene hat keinen
            // Sieger, und eine laufende waere eine Wertung ueber ein
            // Ergebnis, das noch gar nicht feststeht.
            guard game.status == .finished else { continue }
            guard game.teams.count == 2 else { continue }

            guard let eigenes = game.teams.firstIndex(where: { $0.playerIds.contains(profileId) })
            else { continue }

            let gegnerisches = 1 - eigenes
            // Unentschieden: `winnerTeamId` ist leer, die Partie zaehlt
            // trotzdem.
            let gewonnen = game.winnerTeamId != nil && game.winnerTeamId == game.teams[eigenes].id

            for partnerId in game.teams[eigenes].playerIds where partnerId != profileId {
                var werte = partnerTally[partnerId] ?? (0, 0)
                werte.games += 1
                if gewonnen { werte.wins += 1 }
                partnerTally[partnerId] = werte
            }

            for gegnerId in game.teams[gegnerisches].playerIds {
                var werte = opponentTally[gegnerId] ?? (0, 0)
                werte.games += 1
                if gewonnen { werte.wins += 1 }
                opponentTally[gegnerId] = werte
            }
        }

        partners = Self.sorted(partnerTally, ascending: false)
        opponents = Self.sorted(opponentTally, ascending: true)
    }

    /// Sortiert nach Quote. Paarungen ohne belastbare Quote stehen immer
    /// hinten – egal in welche Richtung sortiert wird, sie gehoeren nicht an
    /// die Spitze einer Rangliste.
    private static func sorted(
        _ tally: [String: (games: Int, wins: Int)],
        ascending: Bool
    ) -> [Pairing] {
        tally
            .map { Pairing(profileId: $0.key, games: $0.value.games, wins: $0.value.wins) }
            .sorted { left, right in
                switch (left.winRate, right.winRate) {
                case let (links?, rechts?):
                    if links != rechts { return ascending ? links < rechts : links > rechts }
                    // Gleiche Quote: Die haeufigere Paarung wiegt schwerer.
                    return left.games > right.games
                case (nil, _?): return false
                case (_?, nil): return true
                case (nil, nil): return left.games > right.games
                }
            }
    }
}
