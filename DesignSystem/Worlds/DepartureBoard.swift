//
//  DepartureBoard.swift
//  BeerStats
//
//  Der Ort von "Was spielen wir?": eine Abfahrtstafel. Fallblaetter
//  klappern durch die Zeichen und bleiben beim Ergebnis stehen – von links
//  nach rechts, wie am Bahnhof.
//
//  Schnell: Das letzte Blatt liegt vor einer halben Sekunde. Das Losen
//  soll man sehen, warten will darauf niemand.
//

import SwiftUI

enum DepartureBoard {

    static let yellow = SceneArt.rgb(245, 197, 24)
    static let flap = SceneArt.rgb(38, 38, 40)
    static let housing = SceneArt.rgb(24, 24, 26)
    static let rim = SceneArt.rgb(80, 80, 86)

    /// So breit ist die Tafel – breit genug, dass kein Spieltitel mitten im
    /// Wort bricht ("REAKTIONSDUE / LL" liest am Tisch niemand). Ein Test
    /// haelt das fuer jeden Titel fest.
    static let columns = 14
    /// So hoch ist sie, auch fuer einen einzeiligen Titel: Beim Wuerfeln
    /// wechseln die Titel, und eine Tafel, die dabei die Hoehe wechselt,
    /// laesst die ganze Karte huepfen. Am Bahnhof bleibt eine leere Zeile
    /// auch stehen.
    static let rows = 2

    /// Die Zeichen auf der Rolle eines Fallblatts, in ihrer Reihenfolge.
    static let alphabet: [Character] = Array(" ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÜ0123456789?!-")

    /// Bricht einen Text in Zeilen von hoechstens `width` Zeichen, an
    /// Wortgrenzen; ein zu langes Wort wird geteilt.
    static func lines(_ text: String, width: Int) -> [String] {
        var zeilen: [String] = []
        var aktuell = ""
        for wort in text.uppercased().split(separator: " ").map(String.init) {
            var rest = wort
            while rest.count > width {
                if !aktuell.isEmpty { zeilen.append(aktuell); aktuell = "" }
                zeilen.append(String(rest.prefix(width)))
                rest = String(rest.dropFirst(width))
            }
            if aktuell.isEmpty {
                aktuell = rest
            } else if aktuell.count + 1 + rest.count <= width {
                aktuell += " " + rest
            } else {
                zeilen.append(aktuell)
                aktuell = rest
            }
        }
        if !aktuell.isEmpty { zeilen.append(aktuell) }
        return zeilen.isEmpty ? [""] : zeilen
    }
}

/// Ein Text auf Fallblaettern. Jeder neue Text klappert neu.
struct SplitFlapText: View {

    let text: String
    var columns = DepartureBoard.columns
    var minimumRows = DepartureBoard.rows

    /// Blaetter je Sekunde beim Durchklappern.
    private static let rate: Double = 18

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var flipping = true

    private var rows: [String] {
        let zeilen = DepartureBoard.lines(text, width: columns)
        return zeilen + Array(repeating: "", count: max(0, minimumRows - zeilen.count))
    }

    var body: some View {
        let zeilen = rows

        Group {
            if flipping, !reduceMotion {
                SwiftUI.TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        Self.draw(&context, size, zeilen, columns: columns, t: timeline.date.timeIntervalSince(start))
                    }
                }
            } else {
                Canvas { context, size in Self.draw(&context, size, zeilen, columns: columns, t: 9) }
            }
        }
        .aspectRatio(CGFloat(columns) / (CGFloat(zeilen.count) * 1.62), contentMode: .fit)
        .task(id: text) {
            start = Date()
            flipping = true
            // Danach liegt jedes Blatt; die Zeitleiste wird abgebaut
            try? await Task.sleep(nanoseconds: 550_000_000)
            guard !Task.isCancelled else { return }
            flipping = false
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    /// Wann das Blatt an Stelle `index` zur Ruhe kommt. Die letzte Stelle
    /// einer vollen Tafel (Spalte 13 in Zeile 2, also 15) liegt nach 0,45
    /// Sekunden.
    private static func landing(_ index: Int) -> Double { 0.12 + 0.022 * Double(index) }

    private static func draw(_ g: inout GraphicsContext, _ size: CGSize, _ zeilen: [String], columns: Int, t: Double) {
        let w = Double(size.width), h = Double(size.height)
        let luecke = 3.0
        let breite = (w - luecke * Double(columns - 1)) / Double(columns)
        let hoehe = (h - luecke * Double(zeilen.count - 1)) / Double(zeilen.count)
        let schrift = Font.system(size: breite * 1.05, weight: .heavy, design: .monospaced)
        let alphabet = DepartureBoard.alphabet

        for (reihe, zeile) in zeilen.enumerated() {
            // Mittig in der Zeile, wie auf der Tafel
            let zeichen = Array(zeile)
            let einzug = (columns - zeichen.count) / 2
            for spalte in 0..<columns {
                let x = Double(spalte) * (breite + luecke)
                let y = Double(reihe) * (hoehe + luecke)
                let stelle = spalte - einzug
                let ziel: Character = zeichen.indices.contains(stelle) ? zeichen[stelle] : " "

                var jetzt = ziel, vorher = ziel, fall = 1.0
                if let zielIndex = alphabet.firstIndex(of: ziel) {
                    let rest = max(0, landing(spalte + reihe * 2) - t) * rate
                    let schritte = Int(rest.rounded(.up))
                    if schritte > 0 {
                        let n = alphabet.count
                        jetzt = alphabet[((zielIndex - schritte) % n + n) % n]
                        vorher = alphabet[((zielIndex - schritte - 1) % n + n) % n]
                        fall = 1 - (Double(schritte) - rest)
                    }
                }
                tile(&g, x, y, breite, hoehe, alt: vorher, neu: jetzt, fall: fall, schrift: schrift)
            }
        }
    }

    /// Ein Fallblatt: oben das neue Zeichen, unten das alte, dazwischen
    /// faellt das Blatt.
    private static func tile(_ g: inout GraphicsContext, _ x: Double, _ y: Double, _ w: Double, _ h: Double,
                             alt: Character, neu: Character, fall: Double, schrift: Font) {
        let rahmen = CGRect(x: x, y: y, width: w, height: h)
        let mitte = CGPoint(x: x + w / 2, y: y + h / 2)
        let oben = CGRect(x: x, y: y, width: w, height: h / 2)
        let unten = CGRect(x: x, y: y + h / 2, width: w, height: h / 2)

        func haelfte(_ c: Character, _ bereich: CGRect, dunkler: Double = 0) {
            var k = g
            k.clip(to: Path(bereich))
            k.fill(Path(roundedRect: rahmen, cornerRadius: 4), with: .color(DepartureBoard.flap))
            if dunkler > 0 { k.fill(Path(rahmen), with: .color(.black.opacity(dunkler))) }
            k.draw(Text(String(c)).font(schrift).foregroundColor(DepartureBoard.yellow), at: mitte, anchor: .center)
        }

        haelfte(neu, oben)
        haelfte(fall < 1 ? alt : neu, unten)

        if fall > 0, fall < 1 {
            // Das fallende Blatt: erst die obere Haelfte des alten Zeichens,
            // dann – umgeklappt – die untere des neuen
            let s = cos(fall * .pi)
            var blatt = g
            blatt.translateBy(x: 0, y: Double(mitte.y))
            blatt.scaleBy(x: 1, y: max(0.02, abs(s)))
            blatt.translateBy(x: 0, y: -Double(mitte.y))
            blatt.clip(to: Path(s > 0 ? oben : unten))
            blatt.fill(Path(roundedRect: rahmen, cornerRadius: 4), with: .color(DepartureBoard.flap))
            blatt.fill(Path(rahmen), with: .color(.black.opacity(0.25 * (1 - abs(s)))))
            blatt.draw(Text(String(s > 0 ? alt : neu)).font(schrift).foregroundColor(DepartureBoard.yellow), at: mitte, anchor: .center)
        }

        let links: SceneArt.Point = (x, y + h / 2)
        let rechts: SceneArt.Point = (x + w, y + h / 2)
        SceneArt.lines(&g, [(links, rechts)], .black, 1, 1.5)
    }
}
