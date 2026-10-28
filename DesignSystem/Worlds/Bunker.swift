//
//  Bunker.swift
//  BeerStats
//
//  Die Welt der Bombe: Beton, Warnstreifen, eine gezeichnete Bombe mit
//  Zuendschnur, aus der Funken spruehen. Sie ruckt in unregelmaessigen
//  Stoessen – gerechnet, nicht gewuerfelt.
//
//  Die Zuendschnur wird nie kuerzer. Das ist die wichtigste Entscheidung
//  des Spiels (die Restzeit bleibt unsichtbar), und eine abbrennende Schnur
//  waere nichts anderes als eine Uhr.
//

import SwiftUI

enum BunkerArt {
    static let shell = SceneArt.rgb(84, 84, 92)
    static let shellDark = SceneArt.rgb(10, 10, 12)
    static let cap = SceneArt.rgb(150, 150, 158)
    static let capLight = SceneArt.rgb(210, 210, 218)
    static let fuse = SceneArt.rgb(110, 84, 56)
    static let spark = SceneArt.rgb(255, 230, 120)
    static let sparkHot = SceneArt.rgb(255, 120, 40)
    static let flame = SceneArt.rgb(255, 190, 80)
}

/// Die Bombe. Ist sie gezuendet (`lit`), spruehen Funken und sie ruckt.
struct DrawnBomb: View {

    let lit: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if lit, !reduceMotion {
                SwiftUI.TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        Self.draw(&context, size, t: timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600), lit: true)
                    }
                }
            } else {
                Canvas { context, size in Self.draw(&context, size, t: 0, lit: lit) }
            }
        }
        .accessibilityHidden(true)
    }

    private static func draw(_ g: inout GraphicsContext, _ size: CGSize, t: Double, lit: Bool) {
        let w = Double(size.width), h = Double(size.height)
        let r = min(w, h) * 0.33
        let cx = w / 2 - r * 0.1, cy = h / 2 + r * 0.15

        // Stoesse in unregelmaessigem Abstand: zwei Schwingungen, die sich
        // nur manchmal ueberlagern
        let stoss = lit ? pow(max(0, sin(t * 2.3) * sin(t * 3.7)), 3) : 0
        let dreh = 0.09 * stoss * sin(t * 38)

        var c = g
        c.translateBy(x: cx, y: cy)
        c.rotate(by: .radians(dreh))
        c.scaleBy(x: 1 + 0.03 * stoss, y: 1 + 0.03 * stoss)

        SceneArt.glow(&c, 6, r * 0.95, r * 1.1, .black, 0.6)
        c.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)), with: .radialGradient(
            Gradient(colors: [BunkerArt.shell, BunkerArt.shellDark]),
            center: CGPoint(x: -r * 0.35, y: -r * 0.35), startRadius: r * 0.1, endRadius: r))
        SceneArt.circle(&c, -r * 0.38, -r * 0.42, r * 0.16, .white, 0.18)

        // Der Metallkopf, schraeg aufgesetzt
        var kopf = c
        kopf.translateBy(x: r * 0.62, y: -r * 0.62)
        kopf.rotate(by: .radians(.pi / 4))
        let kappe = CGRect(x: -r * 0.18, y: -r * 0.16, width: r * 0.36, height: r * 0.22)
        kopf.fill(Path(roundedRect: kappe, cornerRadius: 4), with: .linearGradient(
            Gradient(colors: [BunkerArt.cap, BunkerArt.capLight, BunkerArt.cap]),
            startPoint: CGPoint(x: kappe.minX, y: 0), endPoint: CGPoint(x: kappe.maxX, y: 0)))

        // Die Zuendschnur – immer gleich lang
        let ende = CGPoint(x: r * 1.05, y: -r * 1.25)
        var schnur = Path()
        schnur.move(to: CGPoint(x: r * 0.72, y: -r * 0.74))
        schnur.addCurve(to: ende, control1: CGPoint(x: r * 0.9, y: -r * 1.1), control2: CGPoint(x: r * 1.2, y: -r * 0.95))
        c.stroke(schnur, with: .color(BunkerArt.fuse), style: StrokeStyle(lineWidth: 5, lineCap: .round))

        guard lit else { return }
        let ex = Double(ende.x), ey = Double(ende.y)
        SceneArt.glow(&c, ex, ey, 34, BunkerArt.flame, 0.8)
        SceneArt.circle(&c, ex, ey, 5, SceneArt.rgb(255, 246, 210), 1)

        // Funken: sechzehn je Sekunde, jeder fliegt seinen Bogen und
        // verglueht
        let jetzt = Int((t * 16).rounded(.down))
        for i in 0..<16 {
            let geburt = jetzt - i
            let alter = (t * 16 - Double(geburt)) / 16 * 2.2
            guard alter < 2.2 else { continue }
            let winkel = SceneArt.unit(geburt, 7) * 2 * .pi
            let tempo = 40 + 70 * SceneArt.unit(geburt, 8)
            let px = ex + cos(winkel) * tempo * alter
            let py = ey + sin(winkel) * tempo * alter + 90 * alter * alter
            let rest = 1 - alter / 2.2
            SceneArt.circle(&c, px, py, 2.2 * rest, rest > 0.5 ? BunkerArt.spark : BunkerArt.sparkHot, rest)
        }
    }
}
