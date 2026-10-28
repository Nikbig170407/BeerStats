//
//  RegularsTable.swift
//  BeerStats
//
//  Die Welt von Schocken: der Stammtisch. Ein Wuerfelbrett mit Holzrand und
//  Filz, Wuerfel aus Elfenbein, und wer verliert, bekommt einen Bierdeckel.
//
//  Die Wuerfel sind gezeichnet und nicht mehr die Zeichen ⚀ bis ⚅. Die
//  stehen in jeder Schrift anders, sind auf dem Handy winzig und koennen
//  nicht kullern – und Kullern ist der Moment, auf den beim Wuerfeln alle
//  schauen.
//

import SwiftUI

enum RegularsTable {

    static let felt = SceneArt.rgb(17, 74, 45)
    static let feltLight = SceneArt.rgb(70, 140, 95)
    static let rim = SceneArt.rgb(96, 60, 31)
    static let rimLight = SceneArt.rgb(128, 84, 46)
    static let ivoryTop = SceneArt.rgb(255, 253, 248)
    static let ivoryBottom = SceneArt.rgb(222, 216, 204)
    static let dieEdge = SceneArt.rgb(190, 184, 172)
    static let pip = SceneArt.rgb(30, 28, 28)
    static let lamp = SceneArt.rgb(255, 196, 128)
    static let mat = SceneArt.rgb(238, 228, 206)
    static let matRed = SceneArt.rgb(176, 38, 38)
}

// MARK: - Zeichnen

extension SceneArt {

    /// Die Augen eines Wuerfels als Lage im Raster -1...1, Index = Augenzahl.
    static let diePips: [[Point]] = [
        [],
        [(0, 0)],
        [(-1, -1), (1, 1)],
        [(-1, -1), (0, 0), (1, 1)],
        [(-1, -1), (1, -1), (-1, 1), (1, 1)],
        [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
        [(-1, -1), (-1, 0), (-1, 1), (1, -1), (1, 0), (1, 1)],
    ]

    /// Ein Wuerfel aus Elfenbein. `lift` hebt ihn vom Tisch – der Schatten
    /// bleibt am Boden und wird blasser, der Wuerfel ein wenig groesser.
    static func die(_ g: inout GraphicsContext, _ x: Double, _ y: Double, _ s: Double, value: Int, angle: Double, lift: Double) {
        glow(&g, x + 4 + lift * 0.3, y + s * 0.14 + lift * 0.6, s * 0.75, .black, max(0.1, 0.5 - lift * 0.006))

        var c = g
        c.translateBy(x: x, y: y - lift)
        c.rotate(by: .radians(angle))
        let k = 1 + lift * 0.004
        c.scaleBy(x: k, y: k)

        let rahmen = CGRect(x: -s / 2, y: -s / 2, width: s, height: s)
        let koerper = Path(roundedRect: rahmen, cornerRadius: s * 0.2)
        c.fill(koerper, with: .linearGradient(
            Gradient(colors: [RegularsTable.ivoryTop, RegularsTable.ivoryBottom]),
            startPoint: CGPoint(x: -s / 2, y: -s / 2), endPoint: CGPoint(x: s / 2, y: s / 2)))
        c.stroke(koerper, with: .color(RegularsTable.dieEdge.opacity(0.7)), lineWidth: 1.2)

        guard diePips.indices.contains(value) else { return }
        var augen = Path()
        var glanz = Path()
        let r = s * 0.085, rg = s * 0.025
        for auge in diePips[value] {
            let px = auge.x * s * 0.26, py = auge.y * s * 0.26
            augen.addEllipse(in: CGRect(x: px - r, y: py - r, width: 2 * r, height: 2 * r))
            glanz.addEllipse(in: CGRect(x: px - s * 0.02 - rg, y: py - s * 0.02 - rg, width: 2 * rg, height: 2 * rg))
        }
        c.fill(augen, with: .color(RegularsTable.pip))
        c.fill(glanz, with: .color(.white.opacity(0.25)))
    }

    /// Ein Bierdeckel: Pappe, roter Ring, ein Gruss in der Mitte.
    static func beerMat(_ g: inout GraphicsContext, _ x: Double, _ y: Double, _ r: Double, angle: Double) {
        glow(&g, x + 2, y + 4, r * 1.25, .black, 0.35)
        var c = g
        c.translateBy(x: x, y: y)
        c.rotate(by: .radians(angle))
        circle(&c, 0, 0, r, RegularsTable.mat, 1)
        c.stroke(Path(ellipseIn: CGRect(x: -r * 0.8, y: -r * 0.8, width: r * 1.6, height: r * 1.6)),
                 with: .color(RegularsTable.matRed.opacity(0.9)), lineWidth: max(1.5, r * 0.09))
        c.draw(Text("PROST").font(.system(size: r * 0.34, weight: .heavy, design: .serif)).foregroundColor(RegularsTable.matRed),
               at: .zero, anchor: .center)
    }
}

// MARK: - Ein Wuerfel, der kullert

/// Ein Wuerfel im Brett. Wird er neu geworfen (`roll` zaehlt hoch), springt
/// er, dreht sich und zeigt dabei wechselnde Augen, bis er liegt.
struct SchockenDie: View {

    let value: Int
    let kept: Bool
    /// Zaehlt hoch, wenn dieser Wuerfel neu geworfen wird.
    let roll: Int
    let slot: Int

    /// Danach liegt er – und die Zeitleiste ist wieder abgebaut.
    static let duration: Double = 0.5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rolledAt: Date?

    var body: some View {
        Group {
            if let rolledAt, !reduceMotion {
                SwiftUI.TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        draw(&context, size, elapsed: timeline.date.timeIntervalSince(rolledAt))
                    }
                }
            } else {
                Canvas { context, size in draw(&context, size, elapsed: Self.duration) }
            }
        }
        .task(id: roll) {
            rolledAt = Date()
            try? await Task.sleep(nanoseconds: UInt64(Self.duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            rolledAt = nil
        }
    }

    private func draw(_ g: inout GraphicsContext, _ size: CGSize, elapsed: Double) {
        let w = Double(size.width), h = Double(size.height)
        let s = min(w, h * 0.8) * 0.72
        let x = w / 2, y = h - s * 0.66
        let u = SceneArt.clamp(elapsed / Self.duration)
        let richtung: Double = slot % 2 == 0 ? 1 : -1

        // Jeder Wurf bleibt etwas anders schief liegen – gerechnet, damit
        // ein Neuzeichnen ihn nicht verdreht.
        let ruhe = SceneArt.noise(slot * 13 + roll, 21) * 0.22
        let drall = (1 - SceneArt.easeOut(u)) * (9 + 2 * Double(slot)) * richtung
        let sprung = s * 0.5 * pow(1 - u, 1.4) * abs(sin(u * .pi * 3.2))
        let augen = u < 0.8
            ? 1 + Int(SceneArt.unit(Int(elapsed * 13) + slot * 7, 5) * 6) % 6
            : value

        if kept {
            // Liegen gelassen: Die Lampe faellt auf ihn
            SceneArt.glow(&g, x, y + s * 0.1, s * 0.95, RegularsTable.lamp, 0.4)
        }
        SceneArt.die(&g, x, y, s, value: augen, angle: ruhe + drall, lift: sprung)
        if kept {
            var c = g
            c.translateBy(x: x, y: y)
            c.rotate(by: .radians(ruhe))
            let rand = CGRect(x: -s / 2 - 4, y: -s / 2 - 4, width: s + 8, height: s + 8)
            c.stroke(Path(roundedRect: rand, cornerRadius: s * 0.24), with: .color(RegularsTable.lamp.opacity(0.9)), lineWidth: 2.5)
        }
    }
}

// MARK: - Das Brett

/// Holzrand, Filz, Schatten unter der oberen Kante – das Brett, in dem
/// gewuerfelt wird.
struct DiceBoard<Content: View>: View {

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.vertical, 14)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background { Felt() }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [RegularsTable.rimLight, RegularsTable.rim], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.55), radius: 14, y: 8)
            }
    }
}

private struct Felt: View {

    var body: some View {
        Canvas { context, size in
            let rahmen = CGRect(origin: .zero, size: size)
            context.clip(to: Path(roundedRect: rahmen, cornerRadius: 18))
            context.fill(Path(rahmen), with: .color(RegularsTable.felt))
            let flaeche = Int(Double(size.width * size.height) / 40)
            SceneArt.grain(&context, flaeche, .black, 0.22, seed: 11, rahmen, dot: 1.4)
            SceneArt.grain(&context, flaeche / 2, RegularsTable.feltLight, 0.16, seed: 31, rahmen, dot: 1.2)
            // Die obere Kante wirft ihren Schatten auf den Filz
            let schatten = CGRect(x: 0, y: 0, width: size.width, height: 30)
            context.fill(Path(schatten), with: .linearGradient(
                Gradient(colors: [Color.black.opacity(0.45), Color.black.opacity(0)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: 30)))
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

// MARK: - Kleine Wuerfel und Bierdeckel

/// Drei kleine Wuerfel in einer Reihe – fuer den Zwischenstand.
struct DiceRow: View {

    let values: [Int]
    /// Gezeichnet in der Groesse, in der er steht – hochskaliert waere er
    /// unscharf.
    var dieSize: CGFloat = 22

    var body: some View {
        Canvas { context, size in
            let h = Double(size.height)
            let s = h * 0.8
            let luft = h * 0.18
            for (i, wert) in values.enumerated() {
                let x = s / 2 + luft / 2 + Double(i) * (s + luft)
                SceneArt.die(&context, x, h / 2, s, value: wert, angle: SceneArt.noise(i + wert * 3, 8) * 0.12, lift: 0)
            }
        }
        .frame(width: CGFloat(values.count) * dieSize, height: dieSize)
        .accessibilityHidden(true)
    }
}

/// Ein Bierdeckel, der aus der Luft auf den Tisch faellt – fuer den, der die
/// Runde verloren hat.
struct FallingBeerMat: View {

    var size: CGFloat = 40
    /// Wie viele Deckel aufeinander liegen.
    var count: Int = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    var body: some View {
        let liegt = landed || reduceMotion

        Canvas { context, canvas in
            let r = Double(size) / 2 - 3
            for k in 0..<count {
                let versatz = Double(k)
                SceneArt.beerMat(&context, Double(canvas.width) / 2 - versatz * 2, Double(canvas.height) / 2 - versatz * 4,
                                 r, angle: SceneArt.noise(k, 3) * 0.3)
            }
        }
        .frame(width: size + 6, height: size + CGFloat(count) * 4 + 6)
        .rotationEffect(.degrees(liegt ? 0 : 200))
        .scaleEffect(liegt ? 1 : 1.9)
        .offset(y: liegt ? 0 : -50)
        .opacity(liegt ? 1 : 0)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.68).delay(0.15)) { landed = true }
        }
    }
}
