//
//  RingDraw.swift
//  BeerStats
//
//  Welche Karte beim Ziehen aus dem Ring kommt.
//
//  Gelost wird nicht mehr ganz gleich verteilt. Wunsch des Nutzers vom
//  28. Oktober: "die Chancen verringern, dass man zweimal eine gleiche Karte
//  zieht". Mit vier Karten je Rang kommt bei reinem Zufall im Schnitt
//  DREIMAL je Runde derselbe Rang direkt hintereinander – egal wie viele
//  Karten im Ring liegen –, und noch einmal so oft mit nur einer Karte
//  dazwischen. Bei zwanzig Karten trifft es jeden sechsten Zug.
//
//  Jetzt gilt: Der Rang von eben kommt nicht direkt wieder, solange etwas
//  anderes liegt, und die beiden davor sind gedaempft. Dazu kommen Raenge,
//  von denen noch mehr liegen, etwas eher dran – sonst bliebe am Ende ein
//  Haeufchen desselben Rangs uebrig, und die Wiederholungen kaemen alle zum
//  Schluss. Nachgerechnet (`RingDrawTests`): direkt hintereinander
//  praktisch nie mehr, mit einer Karte dazwischen etwa halb so oft.
//
//  Der Zufall bleibt Zufall: Welche Karte eines Rangs, und welcher von den
//  Raengen, die nicht gerade dran waren, entscheidet weiter das Los. Und das
//  Licht haelt weiter genau dort an, wo die Karte herkommt – gelost wird
//  vorher, das Licht laeuft nur hin.
//

import Foundation

enum RingDraw {

    /// Wie stark ein Rang zaehlt, der gerade dran war: der von eben gar
    /// nicht, der davor knapp ein Drittel, der davor gut die Haelfte.
    ///
    /// Durchgerechnet mit Runden zu 20, 32 und 52 Karten. Weicher – ein
    /// Zwanzigstel statt null fuer den letzten – kam noch in etwa jeder
    /// siebten Runde derselbe Rang direkt hintereinander, ohne dass es
    /// dafuer einen Grund gab.
    static let recentDamping: [Double] = [0, 0.3, 0.6]

    /// Das Gewicht jeder Stelle, an der noch eine Karte liegt.
    ///
    /// Grundgewicht ist, wie viele Karten des Rangs noch liegen – ein Rang
    /// mit vier offenen Karten kommt damit eher dran als einer mit einer.
    /// Bleibt nach dem Daempfen nichts uebrig (es liegt nur noch der Rang
    /// von eben), gilt das Grundgewicht: Dann kommt er eben doch.
    static func weights(ring: [PlayingCard?], recentRanks: [Int]) -> [(position: Int, weight: Double)] {
        var proRang: [Int: Int] = [:]
        for karte in ring.compactMap({ $0 }) {
            proRang[karte.rank, default: 0] += 1
        }

        var gedaempft: [(position: Int, weight: Double)] = []
        var roh: [(position: Int, weight: Double)] = []
        for (position, karte) in ring.enumerated() {
            guard let karte else { continue }
            let grund = Double(proRang[karte.rank] ?? 0)
            roh.append((position: position, weight: grund))
            gedaempft.append((position: position, weight: grund * damping(for: karte.rank, recentRanks: recentRanks)))
        }

        let summe = gedaempft.reduce(0) { $0 + $1.weight }
        return summe > 0 ? gedaempft : roh
    }

    /// Lost die Stelle aus, an der gezogen wird – `nil`, wenn nichts mehr
    /// liegt.
    static func pick<G: RandomNumberGenerator>(
        ring: [PlayingCard?],
        recentRanks: [Int],
        using generator: inout G
    ) -> Int? {
        let gewichte = weights(ring: ring, recentRanks: recentRanks)
        let summe = gewichte.reduce(0) { $0 + $1.weight }
        guard summe > 0 else { return nil }

        var wurf = Double.random(in: 0..<summe, using: &generator)
        for eintrag in gewichte {
            if wurf < eintrag.weight { return eintrag.position }
            wurf -= eintrag.weight
        }
        // Nur bei Rundungsresten am Ende der Summe
        return gewichte.last { $0.weight > 0 }?.position
    }

    static func pick(ring: [PlayingCard?], recentRanks: [Int]) -> Int? {
        var zufall = SystemRandomNumberGenerator()
        return pick(ring: ring, recentRanks: recentRanks, using: &zufall)
    }

    /// Der Faktor fuer einen Rang: das Produkt aller Daempfungen, an deren
    /// Stelle er zuletzt gezogen wurde.
    private static func damping(for rank: Int, recentRanks: [Int]) -> Double {
        var faktor = 1.0
        for (abstand, daempfung) in recentDamping.enumerated() {
            let stelle = recentRanks.count - 1 - abstand
            guard stelle >= 0 else { break }
            if recentRanks[stelle] == rank { faktor *= daempfung }
        }
        return faktor
    }
}
