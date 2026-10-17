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
//  Beides zusammen ist durchgerechnet, nicht geraten: Solange der Ring noch
//  geschlossen daliegt, reisst etwa jeder sechste Zug – und ueber eine ganze
//  Runde mit 52 Karten sind es drei bis vier Risse. Dass es gegen Ende
//  seltener wird, ist richtig so: Wo schon Luecken sind, ist nichts mehr zu
//  reissen. Oefter waere die Runde nach zehn Karten blau, seltener wuerde
//  niemand mehr hinsehen.
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
    /// Zwei Bedingungen, und die zweite ist die, auf die es ankommt:
    ///
    /// Beide Nachbarinnen muessen noch liegen. Ist dort schon eine Luecke,
    /// wird sie durch diesen Zug nur groesser – gerissen hat sie jemand
    /// anderes, und zweimal zahlt niemand fuer dieselbe Luecke.
    ///
    /// Und die beiden Nachbarinnen duerfen sich nach dem Zug nicht mehr
    /// beruehren. Lagen sie dicht genug, schliesst sich der Ring hinter der
    /// gezogenen Karte von selbst – dann ist nichts passiert.
    func tearsRing(at position: Int, present: [Bool]) -> Bool {
        let anzahl = angles.count
        guard anzahl >= 3,
              present.count == anzahl,
              present.indices.contains(position),
              present[position]
        else { return false }

        let links = (position - 1 + anzahl) % anzahl
        let rechts = (position + 1) % anzahl
        guard present[links], present[rechts] else { return false }

        return arc(from: links, to: rechts) > cardSpan
    }

    /// Der Bogen von einer Karte zur anderen, in Laufrichtung des Rings.
    private func arc(from: Int, to: Int) -> Double {
        let differenz = angles[to] - angles[from]
        return differenz < 0 ? differenz + 360 : differenz
    }

    /// Nur fuer die Anzeige: Liegt der Ring noch ohne offene Stelle da?
    ///
    /// Gezaehlt wird, wo zwei benachbarte liegende Karten sich nicht mehr
    /// beruehren – und jede fehlende Karte ist ohnehin eine offene Stelle.
    func isClosed(present: [Bool]) -> Bool {
        guard present.count == angles.count, !present.contains(false) else { return false }
        return (0..<angles.count).allSatisfy { position in
            arc(from: position, to: (position + 1) % angles.count) <= cardSpan
        }
    }
}
