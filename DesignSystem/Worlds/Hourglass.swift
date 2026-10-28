//
//  Hourglass.swift
//  BeerStats
//
//  Die Welt der Kategorien: eine Sanduhr. Wer dran war und etwas gesagt
//  hat, tippt – die Sanduhr dreht sich um, und der Sand rieselt neu. Und
//  weil die Bedenkzeit jede Runde knapper wird, wird auch die Sanduhr
//  jede Runde kleiner: Die schrumpfende Zeit, um die es im Spiel geht,
//  sieht man.
//

import SwiftUI

enum HourglassArt {
    static let sand = SceneArt.rgb(226, 186, 120)
    static let glass = SceneArt.rgb(200, 225, 235)
    static let wood = SceneArt.rgb(118, 74, 40)
}

/// Die Sanduhr. `fill` ist der Anteil Sand, der noch oben ist; `scale` macht
/// sie kleiner, `flipping` zeigt sie waehrend des Umdrehens leer.
struct HourglassView: View {

    let fill: Double
    let scale: Double
    let running: Bool
    /// Wie oft umgedreht wurde – jede Erhoehung dreht sie einmal.
    let flips: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = 0
    @State private var turning = false

    var body: some View {
        Group {
            if running, !reduceMotion {
                SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                    Canvas { context, size in
                        Self.draw(&context, size, fill: turning ? 0 : fill, scale: scale,
                                  trickle: turning ? nil : timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            } else {
                Canvas { context, size in
                    Self.draw(&context, size, fill: turning ? 0 : fill, scale: scale, trickle: nil)
                }
            }
        }
        .rotationEffect(.degrees(angle))
        .animation(.easeInOut(duration: 0.35), value: scale)
        .onChange(of: flips) { _ in
            guard !reduceMotion else { return }
            // Umgedreht wird die volle untere Haelfte nach oben. Danach
            // springt der Winkel ungesehen zurueck – oben ist dann wieder
            // oben, und der Sand liegt, wo er hingehoert.
            turning = true
            withAnimation(.easeOut(duration: 0.3)) { angle = 180 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                angle = 0
                turning = false
            }
        }
        .accessibilityHidden(true)
    }

    private static func draw(_ g: inout GraphicsContext, _ size: CGSize, fill: Double, scale: Double, trickle: Double?) {
        let k = Double(min(size.width, size.height)) / 360 * scale
        var c = g
        c.translateBy(x: Double(size.width) / 2, y: Double(size.height) / 2)
        c.scaleBy(x: k, y: k)

        // Der Umriss: zwei Kolben, oben und unten gleich
        var rechts: [SceneArt.Point] = []
        for i in 0...20 {
            let u = Double(i) / 20
            let bauch: Double = pow(sin((1 - u) * Double.pi / 2), 0.8)
            let punkt: SceneArt.Point = (4 + 54 * bauch, -150 + u * 150)
            rechts.append(punkt)
        }
        let unten = rechts.dropLast().reversed().map { p -> SceneArt.Point in (p.x, -p.y) }
        let seite = rechts + unten
        let gespiegelt = seite.reversed().map { p -> SceneArt.Point in (-p.x, p.y) }
        let umriss = seite + gespiegelt

        var glas = Path()
        glas.move(to: CGPoint(x: umriss[0].x, y: umriss[0].y))
        for p in umriss.dropFirst() { glas.addLine(to: CGPoint(x: p.x, y: p.y)) }
        glas.closeSubpath()

        // Sand oben sinkt, unten waechst ein Haufen
        var sand = c
        sand.clip(to: glas)
        let rest = SceneArt.clamp(fill)
        let pegel = -150 + 150 * (1 - rest * 0.92)
        SceneArt.box(&sand, -80, pegel, 160, -pegel, HourglassArt.sand, 1)
        let haufen = 150 * (1 - rest) * 0.8
        let links: SceneArt.Point = (-70, 150)
        let rechtsUnten: SceneArt.Point = (70, 150)
        let spitzeRechts: SceneArt.Point = (24, 150 - haufen)
        let spitzeLinks: SceneArt.Point = (-24, 150 - haufen)
        SceneArt.fill(&sand, [links, rechtsUnten, spitzeRechts, spitzeLinks], HourglassArt.sand, 1)
        if let trickle, rest > 0 {
            let strahlOben: SceneArt.Point = (0, 0)
            let strahlUnten: SceneArt.Point = (0, 150 - haufen)
            SceneArt.lines(&sand, [(strahlOben, strahlUnten)], HourglassArt.sand, 0.9, 2.5)
            for i in 0..<8 {
                let y = SceneArt.fract(trickle * 2 + Double(i) / 8) * (150 - haufen)
                SceneArt.circle(&sand, SceneArt.noise(i, 2) * 2, y, 1.6, HourglassArt.sand, 0.9)
            }
        }

        c.fill(glas, with: .color(HourglassArt.glass.opacity(0.06)))
        c.stroke(glas, with: .color(HourglassArt.glass.opacity(0.55)), lineWidth: 2.5)
        SceneArt.circle(&c, -20, -100, 10, .white, 0.08)

        // Rahmen aus Holz: Deckel oben und unten, zwei Stangen
        for s in [-1.0, 1.0] {
            c.fill(Path(roundedRect: CGRect(x: -78, y: s * 160 - 10, width: 156, height: 20), cornerRadius: 6),
                   with: .color(HourglassArt.wood))
            let oben: SceneArt.Point = (-70 * s, -150)
            let unten: SceneArt.Point = (-70 * s, 150)
            SceneArt.lines(&c, [(oben, unten)], HourglassArt.wood, 1, 5)
        }
    }
}
