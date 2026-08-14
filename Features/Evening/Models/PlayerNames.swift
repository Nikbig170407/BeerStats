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
//  Entscheidend ist der Rueckfall: Laeuft kein Abend, kommt weiter die
//  Nummer. Kein Spiel darf einen laufenden Abend VORAUSSETZEN, sonst waere
//  aus einer Bequemlichkeit eine Pflicht geworden – und wer schnell eine
//  Runde Schocken spielen will, muesste erst einen Abend anlegen.
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
    static var suggestedCount: Int? {
        guard let abend = EveningLog.current, abend.isRunning else { return nil }
        let anzahl = abend.participants.count
        return anzahl >= 2 ? anzahl : nil
    }

    private static func participant(at index: Int) -> EveningParticipant? {
        guard let abend = EveningLog.current, abend.isRunning,
              abend.participants.indices.contains(index)
        else { return nil }
        return abend.participants[index]
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
