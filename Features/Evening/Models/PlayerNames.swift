//
//  PlayerNames.swift
//  BeerStats
//
//  Die Bruecke zwischen den Partyspielen und dem Abend.
//
//  Zwoelf Spiele zaehlen mit Nummern – "Spieler 3 trinkt" –, weil die App
//  bis zum Abend keine Mitspielerliste hatte. Jetzt hat sie eine, und
//  dieselbe Zeile kann "🔥 Lena trinkt" heissen.
//
//  Der Nutzen ist groesser, als er klingt. "Spieler 3" zwingt jeden am Tisch,
//  im Kopf mitzuzaehlen, wer nochmal die Drei ist – und nach dem dritten
//  Bier zaehlt niemand mehr richtig. Ein Name braucht kein Mitzaehlen.
//
//  Entscheidend ist der Rueckfall, und seit Oktober 2026 ist er zweistufig:
//
//  1. Laeuft ein Abend, gelten SEINE Teilnehmer. Das ist keine Vorliebe,
//     sondern Pflicht: Die Trinkbilanz ist auf die Positionen des Abends
//     gebucht. Kaeme der Name von woanders, hiesse Position 3 im Spiel
//     jemand anderes als Position 3 in der Bilanz – und die Bilanz ist
//     falsch, ohne dass es jemandem auffiele.
//  2. Sonst gilt, wer am Tisch steht (`TableRoster`). Das ist der Fall fuer
//     die schnelle Runde zwischendurch, fuer die niemand einen Abend
//     anlegen will.
//  3. Steht niemand fest, kommt weiter die Nummer. Kein Spiel darf einen
//     Abend oder eine Aufstellung VORAUSSETZEN, sonst waere aus einer
//     Bequemlichkeit eine Pflicht geworden.
//

import Foundation

enum PlayerNames {

    /// Anzeigename fuer den Spieler an Position `index` (bei null beginnend).
    static func name(for index: Int) -> String {
        guard let teilnehmer = participant(at: index) else {
            return "Spieler \(index + 1)"
        }
        return "\(teilnehmer.emoji) \(teilnehmer.name)"
    }

    /// Name ohne Emoji – fuer Stellen, an denen schon ein Symbol steht.
    static func plainName(for index: Int) -> String {
        participant(at: index)?.name ?? "Spieler \(index + 1)"
    }

    /// Wie viele Leute der laufende Abend kennt. Spiele koennen ihre
    /// Spielerzahl damit vorbelegen, statt sie jedes Mal neu einstellen zu
    /// lassen.
    ///
    /// `minimum` ist kein Beiwerk: Nicht jedes Spiel geht ab zwei Leuten. Der
    /// Spion braucht drei, sonst gibt es keine Gruppe, die der Spion
    /// taeuschen koennte. Ohne diesen Boden startete er bei einem Abend zu
    /// zweit mit einer Spielerzahl unterhalb seines eigenen Mindestwerts -
    /// der Zaehler zeigt sie an, weil er nur seine eigenen Knoepfe begrenzt,
    /// nicht den Wert, der hereingereicht wird.
    static func suggestedCount(atLeast minimum: Int = 2) -> Int? {
        let anzahl: Int
        if let abend = EveningLog.current, abend.isRunning {
            anzahl = abend.participants.count
        } else {
            anzahl = TableRoster.seats.count
        }
        return anzahl >= minimum ? anzahl : nil
    }

    /// Name und Emoji der Position `index`, aus der jeweils gueltigen
    /// Quelle. Die Reihenfolge der Stufen steht im Dateikopf und ist nicht
    /// beliebig.
    private static func participant(at index: Int) -> (name: String, emoji: String)? {
        if let abend = EveningLog.current, abend.isRunning {
            guard abend.participants.indices.contains(index) else { return nil }
            let teilnehmer = abend.participants[index]
            return (teilnehmer.name, teilnehmer.emoji)
        }

        let tisch = TableRoster.seats
        guard tisch.indices.contains(index) else { return nil }
        return (tisch[index].name, tisch[index].emoji)
    }
}

extension EveningLog {

    /// Schreibt eine angesagte Menge der Bilanz gut.
    ///
    /// Tut nichts, wenn kein Abend laeuft oder die Position niemandem
    /// zugeordnet ist. Dadurch darf der Aufruf ueberall dort stehen, wo ein
    /// Spiel ohnehin schon ausrechnet, wer trinken muss – keine Aufrufstelle
    /// muss den Zustand des Abends kennen.
    static func record(_ amount: DrinkAmount, forPlayer index: Int) {
        guard let abend = current, abend.isRunning,
              abend.participants.indices.contains(index)
        else { return }

        let id = abend.participants[index].id
        let (sips, shots) = amount.tally

        if sips > 0 { addSips(sips, to: id) }
        for _ in 0..<shots { addShot(to: id) }
    }

    /// Dieselbe Menge fuer mehrere Positionen auf einmal – etwa "alle ausser
    /// dem Spion trinken".
    static func record(_ amount: DrinkAmount, forPlayers indices: [Int]) {
        for index in indices { record(amount, forPlayer: index) }
    }
}

extension EveningLog {

    /// Schreibt eine Menge der Bilanz gut, adressiert ueber die Profil-ID.
    ///
    /// Der Weg ueber die Position (`forPlayer:`) gilt fuer die Partyspiele,
    /// die ihre Leute nur als "Spieler 3" kennen. Spiele, die mit echten
    /// Profilen arbeiten, haben die ID zur Hand – und sollen sie benutzen:
    /// Die Reihenfolge der Aufstellung und die des Abends muessen nicht
    /// uebereinstimmen, und eine Position aus der falschen Liste bucht
    /// lautlos auf die falsche Person.
    ///
    /// Tut nichts, wenn kein Abend laeuft oder diese Person nicht dabei ist.
    static func record(_ amount: DrinkAmount, forProfileId id: String) {
        guard let abend = current, abend.isRunning,
              abend.participants.contains(where: { $0.id == id })
        else { return }

        let (sips, shots) = amount.tally

        if sips > 0 { addSips(sips, to: id) }
        for _ in 0..<shots { addShot(to: id) }
    }
}
