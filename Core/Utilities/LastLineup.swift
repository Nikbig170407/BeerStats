//
//  LastLineup.swift
//  BeerStats
//
//  Die zuletzt gespielte Aufstellung.
//
//  „Revanche" gibt es bisher nur INNERHALB einer beendeten Partie. Wer die
//  App zwischendurch zumacht – und das tut man, zwischen zwei Runden liegt
//  ein Bier –, stellt dieselben vier Leute von Hand wieder zusammen.
//
//  Gemerkt wird lokal und nicht aus Firestore gelesen. Der Grund ist nicht
//  Geschwindigkeit, sondern Kosten: Die letzte Aufstellung aus den Partien
//  zu holen hiesse, bei jedem Oeffnen des Beerpong-Menues die Spieleliste
//  abzufragen – fuer eine Zeile, die meistens niemand antippt.
//
//  Gespeichert werden nur Profil-IDs. Namen koennten sich aendern, und ein
//  Knopf, der eine Aufstellung mit veralteten Namen anbietet, waere
//  schlimmer als keiner. Beim Anzeigen werden die IDs gegen die aktuellen
//  Profile aufgeloest; fehlt eines, verschwindet der Knopf.
//

import Foundation

struct StoredLineup: Codable, Equatable {
    /// `GameType.rawValue` – die Aufstellung weiss selbst, ob sie 1v1 war.
    let type: String
    /// Profil-IDs je Team, in Spielreihenfolge.
    let teams: [[String]]
}

enum LastLineup {

    static let storageKey = "beerpong.lastLineup"

    static var current: StoredLineup? {
        get {
            guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
            return try? JSONDecoder().decode(StoredLineup.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                UserDefaults.standard.removeObject(forKey: storageKey)
                return
            }
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    static func remember(type: GameType, teams: [Team]) {
        current = StoredLineup(
            type: type.rawValue,
            teams: teams.map(\.playerIds)
        )
    }

    /// Loest die gemerkte Aufstellung gegen die vorhandenen Profile auf.
    ///
    /// `nil`, sobald auch nur eine Person fehlt – ausgemustert, geloescht
    /// oder auf einem anderen Konto. Eine Aufstellung mit einer Luecke ist
    /// keine Aufstellung, und sie halb anzubieten waere ein Knopf, der im
    /// Spielscreen scheitert.
    static func resolved(against profiles: [PlayerProfile]) -> (type: GameType, teams: [[PlayerProfile]])? {
        guard let gespeichert = current,
              let type = GameType(rawValue: gespeichert.type),
              !gespeichert.teams.isEmpty
        else { return nil }

        var aufgeloest: [[PlayerProfile]] = []
        for team in gespeichert.teams {
            var leute: [PlayerProfile] = []
            for id in team {
                guard let profil = profiles.first(where: { $0.id == id && $0.isActive }) else { return nil }
                leute.append(profil)
            }
            guard !leute.isEmpty else { return nil }
            aufgeloest.append(leute)
        }

        return (type, aufgeloest)
    }
}
