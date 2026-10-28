//
//  HighNoon.swift
//  BeerStats
//
//  Die Welt des Reaktionsduells: Wueste in der Daemmerung, zwei Haelften
//  wie zwei Duellanten. Solange gewartet wird, atmen beide im Herzschlag.
//  Wer zu frueh zieht, hat danach ein Einschussloch in seiner Haelfte.
//
//  Die Bedeutung der Farben bleibt: Rot heisst warten, Gruen heisst jetzt.
//  Sie liegt als Licht ueber der Wueste, nicht statt ihrer.
//

import SwiftUI

enum HighNoon {
    static let skyTop = SceneArt.rgb(58, 26, 70)
    static let skyGlow = SceneArt.rgb(236, 120, 60)
    static let skyLow = SceneArt.rgb(80, 40, 30)
    static let sun = SceneArt.rgb(255, 214, 140)
    static let sunGlow = SceneArt.rgb(255, 210, 120)
    static let ridge = SceneArt.rgb(52, 24, 22)
    static let cactus = SceneArt.rgb(26, 12, 12)
    static let ground = SceneArt.rgb(34, 16, 14)
    static let sand = SceneArt.rgb(250, 230, 190)
}

/// Eine Haelfte der Wueste. `breathing` laesst sie im Herzschlag atmen,
/// `bulletHole` setzt das Einschussloch.
struct DesertHalf: View {

    let breathing: Bool
    let bulletHole: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if breathing, !reduceMotion {
                SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
                    Canvas { context, size in Self.draw(&context, size, hole: bulletHole) }
                        .scaleEffect(1 + 0.018 * pow(max(0, sin(t * 7)), 8))
                }
            } else {
                Canvas { context, size in Self.draw(&context, size, hole: bulletHole) }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private static func draw(_ g: inout GraphicsContext, _ size: CGSize, hole: Bool) {
        let w = Double(size.width), h = Double(size.height)
        SceneArt.wash(&g, size, from: (0, 0), to: (0, h),
                      [(0, HighNoon.skyTop, 1), (0.62, HighNoon.skyGlow, 1), (1, HighNoon.skyLow, 1)])
        SceneArt.glow(&g, w * 0.68, h * 0.62, 90, HighNoon.sunGlow, 0.6)
        SceneArt.circle(&g, w * 0.68, h * 0.62, 34, HighNoon.sun, 0.95)

        // Der Bergkamm, als Anteile von Breite und Hoehe
        let kammX: [Double] = [-0.03, 0.15, 0.3, 0.38, 0.54, 0.62, 1.03, 1.03, -0.03]
        let kammY: [Double] = [0.66, 0.6, 0.62, 0.52, 0.52, 0.63, 0.6, 1.03, 1.03]
        var kamm: [SceneArt.Point] = []
        for (ax, ay) in zip(kammX, kammY) {
            let punkt: SceneArt.Point = (ax * w, ay * h)
            kamm.append(punkt)
        }
        SceneArt.fill(&g, kamm, HighNoon.ridge, 1)

        // Kakteen als Schattenriss
        for (x, s) in [(w * 0.16, 1.0), (w * 0.8, 0.7)] {
            let fuss = h * 0.78
            let farbe = HighNoon.cactus
            SceneArt.roundBox(&g, x - 7 * s, fuss - 70 * s, 14 * s, 70 * s, 7 * s, farbe, 1)
            SceneArt.roundBox(&g, x - 26 * s, fuss - 52 * s, 10 * s, 26 * s, 5 * s, farbe, 1)
            SceneArt.roundBox(&g, x - 26 * s, fuss - 34 * s, 22 * s, 9 * s, 4 * s, farbe, 1)
            SceneArt.roundBox(&g, x + 16 * s, fuss - 60 * s, 10 * s, 30 * s, 5 * s, farbe, 1)
            SceneArt.roundBox(&g, x + 6 * s, fuss - 38 * s, 20 * s, 9 * s, 4 * s, farbe, 1)
        }
        let boden: [SceneArt.Point] = [(-10, h * 0.78), (w + 10, h * 0.76), (w + 10, h + 10), (-10, h + 10)]
        SceneArt.fill(&g, boden, HighNoon.ground, 1)

        guard hole else { return }
        // Das Einschussloch: Risse nach allen Seiten, ein dunkles Loch
        let lx = w * 0.4, ly = h * 0.62
        for i in 0..<9 {
            let winkel = Double(i) / 9 * 2 * .pi + SceneArt.noise(i, 4) * 0.3
            let laenge = 30 + 40 * SceneArt.unit(i, 5)
            let mitte: SceneArt.Point = (lx + cos(winkel) * laenge * 0.5 + SceneArt.noise(i, 6) * 6, ly + sin(winkel) * laenge * 0.5)
            let spitze: SceneArt.Point = (lx + cos(winkel) * laenge, ly + sin(winkel) * laenge)
            let start: SceneArt.Point = (lx, ly)
            SceneArt.stroke(&g, [start, mitte, spitze], .white, 0.55, 1.2)
        }
        SceneArt.circle(&g, lx, ly, 9, SceneArt.rgb(10, 6, 6), 1)
        g.stroke(Path(ellipseIn: CGRect(x: lx - 11, y: ly - 11, width: 22, height: 22)),
                 with: .color(SceneArt.rgb(200, 190, 180).opacity(0.6)), lineWidth: 2)
    }
}
