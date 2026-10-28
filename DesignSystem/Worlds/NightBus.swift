//
//  NightBus.swift
//  BeerStats
//
//  Die Welt des Bussfahrers: der Nachtbus. Vorne die orange
//  Fahrtziel-Anzeige, an den Raendern der Sitzbezug, unten die Haltestellen.
//
//  Die Anzeige ist eine echte Punktmatrix – fuenf mal sieben Punkte je
//  Zeichen, wie vorne an jedem Bus. Sie laeuft NICHT als Lauftext: Der
//  Nutzer hat in der Vorschau bemaengelt, dass sie zu lange brauchte, um
//  dazustehen. Jetzt wischt neuer Text in einer Fuenftelsekunde herein und
//  steht dann still.
//

import SwiftUI

enum NightBus {

    static let amber = SceneArt.rgb(255, 150, 30)
    static let amberCore = SceneArt.rgb(255, 196, 120)
    static let housing = SceneArt.rgb(70, 72, 78)
    static let glass = SceneArt.rgb(6, 6, 5)
    static let busYellow = SceneArt.rgb(250, 205, 60)
    static let busWindow = SceneArt.rgb(40, 60, 90)
    static let night = SceneArt.rgb(16, 22, 42)

    /// Zeichen je Zeile, die auf die Anzeige passen. Mehr wird nicht
    /// gezeigt – die Texte des Spiels sind darauf zugeschnitten.
    static let columns = 84

    /// Die Punktschrift: je Zeichen sieben Zeilen zu fuenf Punkten.
    static let glyphs: [Character: String] = [
        "A": "01110100011000111111100011000110001", "B": "11110100011000111110100011000111110",
        "C": "01110100011000010000100001000101110", "D": "11100100101000110001100011001011100",
        "E": "11111100001000011110100001000011111", "F": "11111100001000011110100001000010000",
        "G": "01110100011000010111100011000101111", "H": "10001100011000111111100011000110001",
        "I": "01110001000010000100001000010001110", "J": "00111000100001000010000101001001100",
        "K": "10001100101010011000101001001010001", "L": "10000100001000010000100001000011111",
        "M": "10001110111010110101100011000110001", "N": "10001100011100110101100111000110001",
        "O": "01110100011000110001100011000101110", "P": "11110100011000111110100001000010000",
        "Q": "01110100011000110001101011001001101", "R": "11110100011000111110101001001010001",
        "S": "01111100001000001110000010000111110", "T": "11111001000010000100001000010000100",
        "U": "10001100011000110001100011000101110", "V": "10001100011000110001100010101000100",
        "W": "10001100011000110101101011010101010", "X": "10001100010101000100010101000110001",
        "Y": "10001100011000101010001000010000100", "Z": "11111000010001000100010001000011111",
        "0": "01110100011001110101110011000101110", "1": "00100011000010000100001000010001110",
        "2": "01110100010000100010001000100011111", "3": "11111000100010000010000011000101110",
        "4": "00010001100101010010111110001000010", "5": "11111100001111000001000011000101110",
        "6": "00110010001000011110100011000101110", "7": "11111000010001000100010000100001000",
        "8": "01110100011000101110100011000101110", "9": "01110100011000101111000010001001100",
        "!": "00100001000010000100001000000000100", "?": "01110100010000100010001000000000100",
        ":": "00000011000110000000011000110000000", ".": "00000000000000000000000000110001100",
        "-": "00000000000000011111000000000000000",
        "Ä": "01010000000111010001111111000110001", "Ö": "01010000000111010001100011000101110",
        "Ü": "01010000001000110001100011000101110",
    ]
}

// MARK: - Fahrtziel-Anzeige

/// Zwei Zeilen Punktschrift in Orange. Neuer Text wischt von links herein.
struct DestinationBoard: View {

    let top: String
    let bottom: String

    /// So lange wischt neuer Text herein – danach steht er.
    static let wipe: Double = 0.2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownAt = Date()
    @State private var wiping = false

    var body: some View {
        Group {
            if wiping, !reduceMotion {
                SwiftUI.TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        Self.draw(&context, size, top, bottom, reveal: SceneArt.clamp(timeline.date.timeIntervalSince(shownAt) / Self.wipe))
                    }
                }
            } else {
                Canvas { context, size in Self.draw(&context, size, top, bottom, reveal: 1) }
            }
        }
        // Sechzehn Punktzeilen hoch, so breit wie die Spalten
        .aspectRatio(CGFloat(NightBus.columns) / 16, contentMode: .fit)
        .padding(8)
        .background(NightBus.glass, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .padding(6)
        .background(NightBus.housing, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .task(id: top + "|" + bottom) {
            shownAt = Date()
            wiping = true
            try? await Task.sleep(nanoseconds: UInt64(Self.wipe * 1_000_000_000) + 40_000_000)
            guard !Task.isCancelled else { return }
            wiping = false
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(top) \(bottom)")
    }

    private static func draw(_ g: inout GraphicsContext, _ size: CGSize, _ top: String, _ bottom: String, reveal: Double) {
        let w = Double(size.width), h = Double(size.height)
        let spalten = NightBus.columns
        let p = min(w / Double(spalten), h / 16)
        let x0 = (w - Double(spalten) * p) / 2
        let y0 = (h - 16 * p) / 2
        let bis = x0 + Double(spalten) * p * reveal

        // Die dunklen Punkte der ganzen Tafel – sie machen sie zur Tafel
        var aus = Path()
        let ra = p * 0.3
        for zeile in 0..<16 where zeile != 7 && zeile != 8 {
            for spalte in 0..<spalten {
                let cx = x0 + (Double(spalte) + 0.5) * p, cy = y0 + (Double(zeile) + 0.5) * p
                aus.addEllipse(in: CGRect(x: cx - ra, y: cy - ra, width: 2 * ra, height: 2 * ra))
            }
        }
        g.fill(aus, with: .color(NightBus.amber.opacity(0.08)))

        var an = Path()
        let rp = p * 0.42
        for (text, dy) in [(top, 0.0), (bottom, 9.0)] {
            let zeichen = Array(text.uppercased())
            let breite = zeichen.count * 6 - 1
            let start = max(0, (spalten - breite) / 2)
            for (i, c) in zeichen.enumerated() {
                let muster = Array(NightBus.glyphs[c] ?? "")
                guard muster.count == 35 else { continue }
                for r in 0..<7 {
                    for s in 0..<5 where muster[r * 5 + s] == "1" {
                        let spalte = start + i * 6 + s
                        guard spalte < spalten else { continue }
                        let cx = x0 + (Double(spalte) + 0.5) * p
                        guard cx <= bis else { continue }
                        let cy = y0 + (dy + Double(r) + 0.5) * p
                        an.addEllipse(in: CGRect(x: cx - rp, y: cy - rp, width: 2 * rp, height: 2 * rp))
                    }
                }
            }
        }
        // Erst der Schein, dann die Punkte selbst – ein Pfad, ein Filter
        g.drawLayer { schein in
            schein.addFilter(.blur(radius: p * 0.9))
            schein.fill(an, with: .color(NightBus.amber.opacity(0.85)))
        }
        g.fill(an, with: .color(NightBus.amberCore))
    }
}

// MARK: - Haltestellen

/// Die Fragen als Haltestellen, der Bus faehrt mit. Der Bus gleitet, weil
/// seine Stelle animierbar ist – SwiftUI rechnet die Zwischenwerte, die
/// Leinwand zeichnet sie.
struct BusStops: View, Animatable {

    let labels: [String]
    /// Wie viele Halte geschafft sind – die sind gefuellt.
    let reached: Int
    /// Wo der Bus steht, als Index der Haltestelle.
    var position: Double

    var animatableData: Double {
        get { position }
        set { position = newValue }
    }

    var body: some View {
        Canvas { context, size in
            Self.draw(&context, size, labels: labels, reached: reached, position: position)
        }
        .frame(height: 66)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Halt \(min(reached + 1, labels.count)) von \(labels.count)")
    }

    private static func draw(_ g: inout GraphicsContext, _ size: CGSize, labels: [String], reached: Int, position: Double) {
        guard labels.count > 1 else { return }
        let w = Double(size.width)
        let rand = 26.0, y = 32.0
        let abstand = (w - 2 * rand) / Double(labels.count - 1)
        let links: SceneArt.Point = (rand, y)
        let rechts: SceneArt.Point = (w - rand, y)
        SceneArt.lines(&g, [(links, rechts)], NightBus.amber, 0.5, 4)

        for (i, name) in labels.enumerated() {
            let x = rand + Double(i) * abstand
            let erreicht = i < reached
            SceneArt.circle(&g, x, y, 9, erreicht ? NightBus.amber : NightBus.night, 1)
            g.stroke(Path(ellipseIn: CGRect(x: x - 9, y: y - 9, width: 18, height: 18)),
                     with: .color(NightBus.amber.opacity(0.9)), lineWidth: 3)
            g.draw(Text(name).font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(erreicht ? 0.9 : 0.5)),
                   at: CGPoint(x: x, y: y + 24), anchor: .center)
        }

        // Der Bus: gelb, ein Fensterband, zwei Raeder
        let bx = rand + min(max(position, 0), Double(labels.count - 1)) * abstand
        g.fill(Path(roundedRect: CGRect(x: bx - 18, y: y - 36, width: 36, height: 20), cornerRadius: 5), with: .color(NightBus.busYellow))
        g.fill(Path(roundedRect: CGRect(x: bx - 14, y: y - 32, width: 28, height: 7), cornerRadius: 2), with: .color(NightBus.busWindow))
        SceneArt.circle(&g, bx - 9, y - 15, 3.5, .black, 0.85)
        SceneArt.circle(&g, bx + 9, y - 15, 3.5, .black, 0.85)
    }
}

// MARK: - Aufdecken

/// Eine Karte, die sich beim Aufdecken um ihre Laengsachse dreht.
///
/// Gedreht wird nur beim Aufdecken – wenn aus "keine Karte" eine Karte wird
/// –, nicht beim Wegraeumen. Ein Stapel, der sich beim Mischen
/// zurueckdreht, saehe aus wie ein Fehler.
struct FlipOnReveal<Value: Equatable>: ViewModifier {

    let value: Value?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .onChange(of: value) { neu in
                guard neu != nil, !reduceMotion else { return }
                angle = 90
                // Erst hochkant zeigen, dann aufklappen – im selben Durchlauf
                // gesetzt, saehe SwiftUI nur den Endwert.
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.28)) { angle = 0 }
                }
            }
    }
}
