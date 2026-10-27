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
//  DREI Zahlen machen das Spiel, und alle drei stehen unten als Konstante.
//  Sie haengen voneinander ab – wer eine anfasst, muss die Simulation in
//  `RingLayoutTests` noch einmal lesen.
//
//  `overlapFactor` sagt, wie viel breiter eine Karte ist als der mittlere
//  Abstand zur Nachbarin. Ueber 1 heisst: Jede Karte steckt ein Stueck
//  unter ihren Nachbarinnen.
//
//  `jitter` streut die Abstaende. Das ist der Spannungsregler: Ohne
//  Streuung laegen alle Karten gleich dicht, und Ziehen waere entweder nie
//  oder immer gefaehrlich. Mit Streuung gibt es dichte Stellen, an denen man
//  gefahrlos zieht, und duenne, an denen es reisst – und man kann es sehen.
//
//  `visibleGap` ist die Mindestbreite einer Luecke, die zaehlt. Ohne sie
//  feuerte der Riss genau in dem Moment, in dem die Luecke NULL war – die
//  Regel kostete einen Shot fuer etwas, das es noch nicht zu sehen gab
//  (26. Oktober). Seitdem ist sie der Waechter, und erst mit ihr ist mehr
//  Ueberlappung unbedenklich: Wie dicht die Karten auch liegen, an der
//  Schwelle klafft immer mindestens eine Viertelkarte.
//
//  Die Werte sind eine Entscheidung des Nutzers vom 27. Oktober, nach dem
//  Test am Tisch: "Reisst ein bisschen schnell – Karten groesser, mehr
//  Ueberlappung, damit es laenger dauert." Mehr Ueberlappung allein haette
//  den frischen Ring fast unzerreissbar gemacht (zwei Abstaende muessten
//  zusammen ueber das Doppelte eines mittleren reichen). Deshalb stieg die
//  Streuung mit: Es gibt jetzt mehr ganz dichte Stellen und einzelne
//  duenne, und an denen reisst es – sichtbar.
//
//  Durchgerechnet, nicht geraten (zehntausende simulierte Runden): Auf
//  einem frisch gelegten Ring reisst etwa jeder ACHTE Zug, die drei Shots
//  halten rund fuenfzehn Zuege. Die genauen Grenzen haelt
//  `RingLayoutTests` fest – dort und nicht hier stehen die Zahlen, an
//  denen etwas haengt.
//
//  Bezahlt werden nur die ersten drei Risse (`RingOfFireView`), und nach
//  den ersten beiden wird neu gelegt.
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

    static let overlapFactor = 2.35

    /// Unter 1 bleiben: Bei 1 koennte ein Abstand null werden, und zwei
    /// Karten laegen deckungsgleich – im Bild fehlte dann eine.
    static let jitter = 0.95

    /// Wie viel Luft zwischen zwei Nachbarinnen liegen muss, damit die
    /// Stelle als offen gilt – als Anteil einer Kartenbreite.
    ///
    /// Das ist die Lehre vom 26. Oktober. Vorher galt der Ring als
    /// gerissen, sobald sich die Nachbarinnen nicht mehr beruehren – also
    /// bei einer Luecke von GENAU NULL. Die Schwelle war damit
    /// bauartbedingt unsichtbar: Der Shot kam in dem Moment, in dem es
    /// noch nichts zu sehen gab, und die Luecke wuchs erst mit den
    /// naechsten Zuegen. Am Tisch hiess das: Es kostet, und niemand
    /// erkennt, warum.
    ///
    /// Jetzt zahlt nur, was man sieht – ein Viertel Karte ist der
    /// Unterschied zwischen "liegt knapp an" und "da ist ein Loch".
    static let visibleGap = 0.25

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

    // MARK: - Offene Stellen

    /// Eine Stelle, an der der Ring offen ist.
    ///
    /// Sie wird GEZEICHNET, und zwar aus denselben Zahlen, mit denen
    /// gerechnet wird. Das ist der Kern der Korrektur: Vorher war der Riss
    /// eine Rechnung ohne Bild – man sah den freien Platz der gezogenen
    /// Karte nicht (richtig so) und die Luecke zwischen den Nachbarinnen
    /// auch nicht (falsch). Damit war die Regel am Tisch nicht
    /// nachvollziehbar.
    struct Opening: Equatable {

        /// Die liegende Karte vor der Luecke.
        let from: Int

        /// Die liegende Karte dahinter.
        let to: Int

        /// Mitte der Luecke in Grad – wohin die Markierung gehoert.
        let centerAngle: Double

        /// Breite der Luecke in Grad, also die freie Strecke zwischen den
        /// beiden Kartenkanten.
        let width: Double
    }

    /// So viel Luft muss zwischen zwei Kartenkanten liegen, damit die
    /// Stelle offen ist – in Grad.
    var openingThreshold: Double { cardSpan * Self.visibleGap }

    /// Alle offenen Stellen im Ring, in Laufrichtung.
    ///
    /// Gezeichnet wird daraus jede einzelne, nicht nur die letzte: Eine
    /// Luecke bleibt liegen, und wer nach dem Aktionsscreen zurueckkommt,
    /// soll sehen, wie der Ring gerade steht.
    func openings(present: [Bool]) -> [Opening] {
        guard present.count == angles.count else { return [] }
        let liegende = present.indices.filter { present[$0] }
        // Mit zwei Karten gibt es keinen Ring, also auch keine Luecke in
        // ihm – sonst zaehlte dieselbe Strecke zweimal, einmal pro
        // Richtung.
        guard liegende.count >= 3 else { return [] }

        return liegende.indices.compactMap { stelle in
            let von = liegende[stelle]
            let nach = liegende[(stelle + 1) % liegende.count]
            let frei = freeSpan(from: von, to: nach)
            guard frei >= openingThreshold else { return nil }
            return Opening(
                from: von,
                to: nach,
                centerAngle: angles[von] + arc(from: von, to: nach) / 2,
                width: frei
            )
        }
    }

    // MARK: - Reissen

    /// Reisst das Ziehen dieser Karte den Ring auf?
    ///
    /// Gerissen heisst: Danach klafft zwischen den beiden naechsten noch
    /// LIEGENDEN Nachbarinnen eine sichtbare Luecke – nicht blosses
    /// Nicht-mehr-Beruehren, siehe `visibleGap`. Gerechnet wird mit den
    /// liegenden Nachbarinnen und nicht mit den Nachbarplaetzen: Liegt
    /// links schon ein Loch und man zieht die Karte daneben, entsteht eine
    /// Luecke von zwei Kartenbreiten, und der Kreis ist sichtbar durch.
    ///
    /// Zweimal fuer dieselbe Luecke zahlt trotzdem niemand. Deshalb die
    /// Gegenprobe VOR dem Zug: War der Ring an einer der beiden Seiten
    /// schon offen? Dann hat das jemand anderes bezahlt.
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
        guard !isOpen(from: links, to: position),
              !isOpen(from: position, to: rechts)
        else { return false }

        return isOpen(from: links, to: rechts)
    }

    /// Klafft zwischen diesen beiden Karten eine sichtbare Luecke?
    func isOpen(from: Int, to: Int) -> Bool {
        freeSpan(from: from, to: to) >= openingThreshold
    }

    // MARK: - Rechnerei

    /// Die freie Strecke zwischen zwei Kartenkanten, in Grad. Negativ
    /// heisst: Die beiden ueberlappen sich noch.
    private func freeSpan(from: Int, to: Int) -> Double {
        arc(from: from, to: to) - cardSpan
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
