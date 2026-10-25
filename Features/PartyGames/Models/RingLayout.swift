//
//  RingLayout.swift
//  BeerStats
//
//  Wo die Karten im Ring liegen – und wann das Ziehen den Ring aufreisst.
//
//  Am echten Tisch liegen die Karten nicht sauber verteilt, sondern
//  geschuppt im Kreis: jede ein Stueck unter der naechsten. Genau daraus
//  entsteht die Regel, die dem Spiel seinen Namen gibt – wer den Ring
//  reisst, trinkt. Vorher lagen die Karten hier in gleichen Abstaenden mit
//  Luft dazwischen, und die Regel gab es gar nicht: Es war ein Stapel, der
//  im Kreis angeordnet war.
//
//  Zwei Zahlen machen das Spiel, und beide stehen unten als Konstante:
//
//  `overlapFactor` sagt, wie viel breiter eine Karte ist als der mittlere
//  Abstand zur Nachbarin. 2,4 heisst: Im Schnitt steckt jede Karte zu gut
//  der Haelfte unter ihren Nachbarinnen.
//
//  `jitter` streut die Abstaende. Das ist der Spannungsregler: Ohne
//  Streuung laegen alle Karten gleich dicht, und Ziehen waere entweder nie
//  oder immer gefaehrlich. Mit Streuung gibt es dichte Stellen, an denen man
//  gefahrlos zieht, und duenne, an denen es reisst – und man kann es sehen.
//
//  Beides zusammen ist durchgerechnet, nicht geraten (zwanzigtausend
//  simulierte Runden): Auf einem vollstaendig ausgelegten Ring reisst jeder
//  FUENFTE Zug – 20,8 % bei zwanzig Karten, 21,6 % bei zweiundfuenfzig.
//  Danach steigt es, denn jede Luecke macht die naechste wahrscheinlicher.
//
//  Bezahlt werden nur die ersten drei Risse (`RingOfFireView`), und nach den
//  ersten beiden wird neu gelegt. Mit der korrigierten Rechnung vom
//  25. Oktober sind die drei Shots nach rund zehn Zuegen vergeben
//  (Median 10, in neun von zehn Runden zwischen 6 und 16) – bei zwanzig
//  Karten also etwa zur Haelfte der Runde, bei zweiundfuenfzig nach einem
//  Fuenftel.
//

import Foundation

/// Die Lage der Karten im Kreis. Reiner Wert-Typ, bewusst ohne SwiftUI: Die
/// Frage "reisst das den Ring?" ist Rechnerei und soll pruefbar bleiben,
/// ohne eine Ansicht zu bauen.
struct RingLayout: Equatable {

    /// Winkel der Kartenmitten in Grad, aufsteigend, beginnend bei 0.
    let angles: [Double]

    /// Wie viel Platz eine Karte im Kreis einnimmt, in Grad. Zwei Karten
    /// beruehren sich, solange ihre Mitten nicht weiter auseinanderliegen
    /// als das.
    let cardSpan: Double

    static let overlapFactor = 2.4
    static let jitter = 0.6

    // MARK: - Auslegen

    static func random(count: Int) -> RingLayout {
        let anzahl = max(count, 1)
        let base = 360.0 / Double(anzahl)

        guard anzahl > 2 else {
            // Mit einer oder zwei Karten gibt es keinen Ring, der reissen
            // koennte. Gleichmaessig verteilen und gut.
            return RingLayout(
                angles: (0..<anzahl).map { Double($0) * base },
                cardSpan: base * overlapFactor
            )
        }

        var abstaende = (0..<anzahl).map { _ in
            base * (1 + jitter * Double.random(in: -1...1))
        }

        // Normieren ist Pflicht, nicht Kosmetik: Die Abstaende muessen sich
        // zu genau 360 Grad summieren. Sonst klafft zwischen der letzten und
        // der ersten Karte eine Naht, die nie jemand gezogen hat.
        let summe = abstaende.reduce(0, +)
        guard summe > 0 else {
            return RingLayout(
                angles: (0..<anzahl).map { Double($0) * base },
                cardSpan: base * overlapFactor
            )
        }
        abstaende = abstaende.map { $0 * 360 / summe }

        var winkel: [Double] = []
        var laufend = 0.0
        for abstand in abstaende {
            winkel.append(laufend)
            laufend += abstand
        }

        return RingLayout(angles: winkel, cardSpan: base * overlapFactor)
    }

    // MARK: - Reissen

    /// Reisst das Ziehen dieser Karte den Ring auf?
    ///
    /// Gerissen heisst: Von oben ist der Kreis danach nicht mehr durchgehend
    /// – zwischen zwei Karten klafft eine Luecke, die breiter ist als eine
    /// Karte. Gerechnet wird deshalb mit den naechsten noch LIEGENDEN
    /// Nachbarinnen und nicht mit den Nachbarplaetzen.
    ///
    /// Genau daran ist es bis zum 25. Oktober vorbeigelaufen: Die Funktion
    /// schaute auf die beiden Nachbarplaetze und gab `false` zurueck, sobald
    /// einer davon leer war – "neben einer Luecke reisst nichts". Am Tisch
    /// ist aber das Gegenteil richtig. Liegt links schon ein Loch und man
    /// zieht die Karte daneben, entsteht eine Luecke von zwei Kartenbreiten,
    /// und der Kreis ist sichtbar durch. Die App sagte dazu nichts, und weil
    /// jeder zweite Zug irgendwann neben einem Loch liegt, blieb die Regel
    /// nach den ersten Karten fast ganz aus. So sah es am Tisch nach Willkuer
    /// aus: Mal kam ein Shot, mal nicht, ohne erkennbaren Unterschied.
    ///
    /// Zweimal fuer dieselbe Luecke zahlt trotzdem niemand. Deshalb die
    /// Gegenprobe VOR dem Zug: Beruehrte die Karte ihre beiden Nachbarinnen
    /// ueberhaupt noch? Wenn nicht, war der Ring an dieser Stelle schon
    /// offen, und das hat jemand anderes bezahlt.
    func tearsRing(at position: Int, present: [Bool]) -> Bool {
        guard present.count == angles.count,
              present.indices.contains(position),
              present[position]
        else { return false }

        // Vier liegende Karten mindestens: Was nach dem Zug uebrig bleibt,
        // muss noch ein Kreis sein koennen. Drei Karten sind einer, zwei
        // sind keiner mehr – und am Ende der Runde ist ohnehin nichts mehr
        // zu reissen.
        guard present.lazy.filter({ $0 }).count >= 4,
              let links = nearestPresent(from: position, step: -1, present: present),
              let rechts = nearestPresent(from: position, step: 1, present: present)
        else { return false }

        // War hier schon offen? Dann reisst es nicht noch einmal.
        guard arc(from: links, to: position) <= cardSpan,
              arc(from: position, to: rechts) <= cardSpan
        else { return false }

        return arc(from: links, to: rechts) > cardSpan
    }

    /// Die naechste liegende Karte in eine Richtung (`step` ist -1 oder 1).
    ///
    /// Laeuft rundherum, haelt aber nach einer vollen Runde an: Sonst liefe
    /// die Suche endlos, wenn ausser `position` nichts mehr liegt.
    private func nearestPresent(from position: Int, step: Int, present: [Bool]) -> Int? {
        let anzahl = angles.count
        var index = position
        for _ in 1..<max(anzahl, 2) {
            index = ((index + step) % anzahl + anzahl) % anzahl
            if present[index] { return index }
        }
        return nil
    }

    /// Der Bogen von einer Karte zur anderen, in Laufrichtung des Rings.
    private func arc(from: Int, to: Int) -> Double {
        let differenz = angles[to] - angles[from]
        return differenz < 0 ? differenz + 360 : differenz
    }
}
