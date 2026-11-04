//
//  RingSpotlightPlan.swift
//  BeerStats
//
//  Wann das Lauflicht in Ring of Fire auf welcher Karte steht.
//
//  Vorher stand der Ablauf nur in der Schleife, die das Licht bewegt: Sie
//  schlief nach jedem Schritt eine Weile, und wo das Licht gerade war, wusste
//  nur sie. Seit das Licht einen Funkenschweif hinter sich herzieht, muss es
//  ein Zweiter wissen – die Leinwand, die die Funken zeichnet. Zwei
//  Rechnungen liefen auseinander; deshalb ist der Plan jetzt ein Wert, den
//  beide lesen. Und die Schleife wartet auf den geplanten ZEITPUNKT statt
//  eine Dauer lang: Jedes Einschlafen kommt ein paar Millisekunden zu spaet
//  zurueck, und ueber dreissig Schritte haette der Schweif dem Licht
//  sichtbar hinterhergehangen.
//

import Foundation

struct RingSpotlightPlan: Equatable {

    /// Wo das Licht bei jedem Schritt steht – Plaetze im Ring.
    let stops: [Int]
    /// Wann es dorthin springt, in Sekunden nach dem Druck auf den Knopf.
    let times: [Double]
    /// Wann es endgueltig steht. Ab da hebt sich die Karte heraus.
    let halt: Double

    /// So schnell laeuft das Licht in der schnellen Phase.
    static let fastStep = 0.012
    /// So viele Schritte vor dem Ende beginnt das Abbremsen.
    static let slowSteps = 14
    /// Der erste und der letzte Schritt des Abbremsens.
    static let slowFirst = 0.05
    static let slowLast = 0.3
    /// Kuerzer laeuft das Licht nicht – bei wenigen Karten waere eine
    /// Runde sonst ein Zucken statt einer Drehung.
    static let minimumSteps = 16

    /// Der Plan fuer ein Licht, das ueber `positions` laeuft und auf
    /// `target` stehen bleibt – `nil`, wenn das Ziel dort nicht liegt.
    ///
    /// Eine volle Runde plus der Weg zum Ziel, bei wenigen Karten so viele
    /// Runden dazu, bis es nach etwas aussieht. Vielfache der Rundenlaenge
    /// erhalten dabei, dass der letzte Schritt auf dem Ziel landet: Das
    /// Licht haelt dort an, wo die Karte tatsaechlich herkommt. Es sieht
    /// nicht nur nach Auslosung aus, es ist die Auslosung.
    init?(target: Int, over positions: [Int]) {
        guard let zielIndex = positions.firstIndex(of: target) else { return nil }

        var schritte = positions.count + zielIndex
        while schritte < Self.minimumSteps { schritte += positions.count }

        var stops: [Int] = []
        var times: [Double] = []
        var zeit = 0.0
        for schritt in 0...schritte {
            stops.append(positions[schritt % positions.count])
            times.append(zeit)
            zeit += Self.duration(remaining: schritte - schritt)
        }
        self.stops = stops
        self.times = times
        self.halt = zeit
    }

    /// Wie lange das Licht auf einem Schritt bleibt, bei so vielen
    /// verbleibenden Schritten. Die letzten bremsen spuerbar ab – das ist
    /// der ganze Trick am Gluecksrad. Davor laeuft es gleichmaessig schnell.
    private static func duration(remaining: Int) -> Double {
        guard remaining <= slowSteps else { return fastStep }
        let anteil = Double(slowSteps - remaining) / Double(slowSteps)
        return slowFirst + (slowLast - slowFirst) * anteil
    }

    /// Gehoert der Schritt noch zur schnellen Phase? Dort tickt nur jeder
    /// vierte, und die Hand spuert nichts – bei zwoelf Millisekunden waere
    /// beides ein Rauschen.
    func isFast(_ step: Int) -> Bool {
        stops.count - 1 - step > Self.slowSteps
    }
}
