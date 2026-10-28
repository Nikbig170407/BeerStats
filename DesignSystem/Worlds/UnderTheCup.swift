//
//  UnderTheCup.swift
//  BeerStats
//
//  Die Welt von Maexchen: ein Hinterzimmer, eine Lampe, ein Lederbecher.
//  Der Becher knallt auf den Tisch, staucht sich, federt nach – und wird
//  angehoben, damit man darunter schauen kann.
//
//  Die Wuerfel darunter sind dieselben wie beim Schocken (`SceneArt.die`):
//  Elfenbein bleibt Elfenbein, egal an welchem Tisch.
//

import SwiftUI

enum UnderTheCup {
    static let leather = SceneArt.rgb(96, 54, 30)
    static let leatherLight = SceneArt.rgb(128, 76, 44)
    static let leatherDark = SceneArt.rgb(52, 28, 16)
    static let rim = SceneArt.rgb(70, 38, 22)
    static let stitch = SceneArt.rgb(200, 160, 110)
    static let dust = SceneArt.rgb(200, 180, 150)

    /// So lange faellt der Becher.
    static let fall: Double = 0.2
    /// Dann wird er angehoben – fertig, bevor eine halbe Sekunde um ist.
    static let liftStart: Double = 0.28
    static let liftEnd: Double = 0.46
}

extension SceneArt {

    /// Ein Lederbecher, Oeffnung nach unten, mit Naehten und Raendern.
    static func diceCup(_ g: inout GraphicsContext, _ x: Double, _ y: Double, scale: Double, squash: Double, tilt: Double) {
        var c = g
        c.translateBy(x: x, y: y)
        c.rotate(by: .radians(tilt))
        c.scaleBy(x: scale * (1 + 0.1 * squash), y: scale * (1 - 0.14 * squash))

        glow(&c, 0, 4, 110, .black, 0.5)
        let koerper: [Point] = [(-52, -150), (52, -150), (74, 0), (-74, 0)]
        fill(&c, koerper, from: (-74, 0), to: (74, 0),
             [(0, UnderTheCup.leatherLight, 1), (0.45, UnderTheCup.leather, 1), (1, UnderTheCup.leatherDark, 1)])
        c.fill(Path(roundedRect: CGRect(x: -78, y: -16, width: 156, height: 18), cornerRadius: 8), with: .color(UnderTheCup.rim))
        c.fill(Path(roundedRect: CGRect(x: -52, y: -158, width: 104, height: 12), cornerRadius: 6), with: .color(UnderTheCup.rim))

        var naht = Path()
        naht.move(to: CGPoint(x: -70, y: -24))
        naht.addLine(to: CGPoint(x: 70, y: -24))
        naht.move(to: CGPoint(x: -46, y: -140))
        naht.addLine(to: CGPoint(x: -63, y: -28))
        c.stroke(naht, with: .color(UnderTheCup.stitch.opacity(0.5)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
    }
}

/// Der Becher knallt auf, federt nach und wird angehoben – darunter liegen
/// die beiden Wuerfel. Jeder neue Wurf (`rollID`) knallt neu.
struct CupReveal: View {

    let high: Int
    let low: Int
    let rollID: Int
    var height: CGFloat = 250

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var settled = false

    var body: some View {
        Group {
            if settled || reduceMotion {
                Canvas { context, size in Self.draw(&context, size, t: 9, high: high, low: low) }
            } else {
                SwiftUI.TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        Self.draw(&context, size, t: timeline.date.timeIntervalSince(start), high: high, low: low)
                    }
                }
            }
        }
        .frame(height: height)
        .task(id: rollID) {
            start = Date()
            settled = false
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            settled = true
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Unter dem Becher: \(high) und \(low)")
    }

    private static func draw(_ g: inout GraphicsContext, _ size: CGSize, t: Double, high: Int, low: Int) {
        let w = Double(size.width), h = Double(size.height)
        let cx = w / 2, boden = h - 22
        let s = h / 270

        let heben = smooth((t - UnderTheCup.liftStart) / (UnderTheCup.liftEnd - UnderTheCup.liftStart))
        if heben > 0 {
            SceneArt.die(&g, cx - 34, boden - 30, 54, value: high, angle: -0.15, lift: 0)
            SceneArt.die(&g, cx + 34, boden - 26, 54, value: low, angle: 0.2, lift: 0)
        }

        let fall = SceneArt.easeIn(t / UnderTheCup.fall)
        let nach = t - UnderTheCup.fall
        let feder = nach > 0 ? exp(-10 * nach) * cos(nach * 26) : 0

        // Staub, der beim Aufprall flach auseinanderlaeuft
        if nach > 0, nach < 0.5 {
            let u = nach / 0.5
            var staub = g
            staub.translateBy(x: cx, y: boden)
            staub.scaleBy(x: 1, y: 0.28)
            let r = 80 + 120 * u
            staub.stroke(Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)),
                         with: .color(UnderTheCup.dust.opacity(0.35 * (1 - u))), lineWidth: 6)
        }

        let y = boden - (1 - fall) * h - heben * 105 * s
        SceneArt.diceCup(&g, cx, y, scale: s, squash: heben > 0 ? 0 : feder, tilt: -heben * 0.22)
    }

    private static func smooth(_ x: Double) -> Double {
        let u = SceneArt.clamp(x)
        return u * u * (3 - 2 * u)
    }
}
