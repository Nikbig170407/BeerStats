//
//  TableRoster.swift
//  BeerStats
//
//  Wer heute am Tisch steht.
//
//  Bisher musste jedes Spiel seine Leute selbst erfragen: Beerpong ueber die
//  Aufstellung, die Partyspiele ueber eine blosse Anzahl ("wie viele seid
//  ihr?"), der Abend ueber seine Teilnehmerliste. Dreimal dieselbe Frage an
//  einem Abend, und die Partyspiele kannten die Namen trotzdem nicht - sie
//  zaehlten Spieler 1 bis 5.
//
//  Diese Aufstellung ist deshalb eine eigene, aber bewusst KEINE zweite
//  Wahrheit neben `PlayerProfile.isActive`:
//
//  - `isActive` gehoert zum Profil und heisst "gehoert noch zur Truppe".
//    Wer ausgemustert ist, soll nie wieder versehentlich in einer
//    Aufstellung landen. Das ist eine Entscheidung fuer Monate.
//  - Diese Liste hier heisst "ist heute da" und aendert sich jeden Abend.
//    Sie liegt deshalb in UserDefaults und nicht in Firestore: Sie gilt
//    fuer dieses Geraet und diesen Abend, kostet kein Kontingent, und ein
//    versehentlicher Haken hat keine Folgen ueber heute hinaus.
//
//  Leere Auswahl heisst absichtlich "alle Aktiven", nicht "niemand". So
//  funktioniert jedes Spiel sofort, auch wenn hier nie jemand etwas
//  angetippt hat - und wer nichts auswaehlt, bekommt genau das, was vorher
//  auch passiert waere.
//

import Foundation
import SwiftUI

enum TableRoster {

    static let storageKey = "table.roster"

    /// Die angetippten Profil-IDs. Leer heisst: alle aktiven Profile.
    static var selectedIds: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? []) }
        set {
            guard !newValue.isEmpty else {
                UserDefaults.standard.removeObject(forKey: storageKey)
                return
            }
            UserDefaults.standard.set(Array(newValue), forKey: storageKey)
        }
    }

    /// Wer aus den uebergebenen Profilen heute mitspielt.
    ///
    /// Immer gegen die aktiven Profile gefiltert: Ein Profil, das seit der
    /// letzten Auswahl ausgemustert wurde, steht sonst weiter am Tisch, weil
    /// seine ID noch gespeichert ist.
    static func players(from profiles: [PlayerProfile]) -> [PlayerProfile] {
        let aktive = profiles.filter(\.isActive)
        let gewaehlt = selectedIds
        guard !gewaehlt.isEmpty else { return aktive }

        let amTisch = aktive.filter { profile in
            guard let id = profile.id else { return false }
            return gewaehlt.contains(id)
        }
        // Fallen alle Gewaehlten weg, ist die gespeicherte Auswahl wertlos -
        // dann lieber alle zeigen als einen leeren Tisch.
        return amTisch.isEmpty ? aktive : amTisch
    }

    static func isAtTable(_ profile: PlayerProfile, in profiles: [PlayerProfile]) -> Bool {
        guard let id = profile.id else { return false }
        return players(from: profiles).contains { $0.id == id }
    }

    /// Schaltet ein Profil um.
    ///
    /// Der erste Griff an eine leere Auswahl macht aus dem stillen "alle
    /// sind da" eine ausdrueckliche Liste - sonst wuerde das erste Abwaehlen
    /// nichts bewirken, weil leer weiter "alle" hiesse.
    static func toggle(_ profile: PlayerProfile, in profiles: [PlayerProfile]) {
        guard let id = profile.id else { return }

        var auswahl = selectedIds
        if auswahl.isEmpty {
            auswahl = Set(profiles.filter(\.isActive).compactMap(\.id))
        }

        if auswahl.contains(id) {
            auswahl.remove(id)
        } else {
            auswahl.insert(id)
        }
        selectedIds = auswahl
    }

    /// Setzt auf "alle Aktiven" zurueck.
    static func reset() {
        selectedIds = []
    }
}

// MARK: - Was die Spiele davon brauchen

/// Ein Platz am Tisch, so wie ihn ein Partyspiel braucht: Name und Emoji,
/// ohne Firestore und ohne Ladezeit.
struct TableSeat: Codable, Equatable {
    let id: String
    let name: String
    let emoji: String
}

extension TableRoster {

    static let seatsStorageKey = "table.seats"

    /// Die Leute am Tisch als Schnappschuss, in ihrer Reihenfolge.
    ///
    /// Warum nicht einfach die Profile nachladen: Ein Partyspiel kennt kein
    /// Repository. Es laeuft ohne Konto, ohne Netz und oft ohne dass je ein
    /// Profil geladen wurde – `SpyView` bekommt kein Firestore in die Hand,
    /// und das soll auch so bleiben. Was es braucht, sind drei Zeichenketten.
    ///
    /// Der Preis ist, dass eine Umbenennung hier erst ankommt, wenn jemand
    /// die Mitspieler oder das Hauptmenue oeffnet – dort wird der
    /// Schnappschuss aufgefrischt. Fuer einen Namen am Tisch ist das nah
    /// genug an der Wahrheit.
    static var seats: [TableSeat] {
        get {
            guard let data = UserDefaults.standard.data(forKey: seatsStorageKey),
                  let gespeichert = try? JSONDecoder().decode([TableSeat].self, from: data)
            else { return [] }
            return gespeichert
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: seatsStorageKey)
        }
    }

    /// Frischt den Schnappschuss auf. Aufzurufen, wo die Profile bekannt
    /// sind – also dort, wo die Aufstellung ohnehin berechnet wird.
    static func remember(_ players: [PlayerProfile]) {
        seats = players.compactMap { profile in
            guard let id = profile.id else { return nil }
            return TableSeat(id: id, name: profile.name, emoji: profile.emoji)
        }
    }
}

// MARK: - Environment-Integration

private struct TablePlayersKey: EnvironmentKey {
    static let defaultValue: [PlayerProfile] = []
}

extension EnvironmentValues {

    /// Wer heute am Tisch steht – fuer jedes Spiel, das Namen statt Zahlen
    /// zeigen will.
    ///
    /// Ueber die Umgebung und nicht als Parameter an `PartyGame.destination`:
    /// Sonst muessten alle neunzehn Spiele die Liste annehmen, auch die
    /// siebzehn, die sie nicht brauchen – und jedes neue Spiel muesste daran
    /// denken. So nimmt sie sich, wer sie braucht.
    ///
    /// Leer ist ein gueltiger Zustand: Wer noch keine Profile angelegt hat,
    /// spielt weiter wie bisher, nur ohne Namen. Jedes Spiel, das diesen Wert
    /// liest, muss diesen Fall koennen.
    var tablePlayers: [PlayerProfile] {
        get { self[TablePlayersKey.self] }
        set { self[TablePlayersKey.self] = newValue }
    }
}
