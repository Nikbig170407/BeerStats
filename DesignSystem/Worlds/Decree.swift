//
//  Decree.swift
//  BeerStats
//
//  Die Welt der Regel des Abends: ein Erlass. Jede neue Regel entrollt sich
//  als Pergament auf rotem Samt und wird versiegelt – wie die Zehn in Ring
//  of Fire, die auch eine Regel stempelt.
//
//  Pergament ist ein Gegenstand und darf hell sein, mit eigener brauner
//  Tinte. Entrollt ist es nach einer knappen halben Sekunde; das Siegel
//  kommt danach.
//

import SwiftUI

enum Decree {
    static let parchment = SceneArt.rgb(233, 216, 176)
    static let parchmentEdge = SceneArt.rgb(196, 172, 124)
    static let ink = SceneArt.rgb(60, 38, 18)
    static let inkSoft = SceneArt.rgb(90, 60, 30)
    static let red = SceneArt.rgb(130, 30, 30)
    static let seal = SceneArt.rgb(168, 24, 32)
    static let sealDark = SceneArt.rgb(110, 10, 16)
    static let rollerLight = SceneArt.rgb(210, 186, 140)
    static let rollerMid = SceneArt.rgb(176, 148, 100)
    static let rollerDark = SceneArt.rgb(120, 96, 60)

    /// So lange entrollt sich eine neue Regel.
    static let unroll: Double = 0.4
}

/// Ein Pergament mit Walzen oben und unten, das sich beim Erscheinen nach
/// unten entrollt.
struct Parchment<Content: View>: View {

    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var open = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let offen = open || reduceMotion

        VStack(spacing: 12) { content }
            .foregroundStyle(Decree.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 26)
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(stops: [
                    .init(color: Decree.parchmentEdge, location: 0),
                    .init(color: Decree.parchment, location: 0.08),
                    .init(color: Decree.parchment, location: 0.92),
                    .init(color: Decree.parchmentEdge, location: 1),
                ], startPoint: .leading, endPoint: .trailing)
            )
            .padding(.horizontal, 8)
            // Entrollen: Das Papier gibt von oben nach unten frei
            .mask(alignment: .top) {
                Rectangle().scaleEffect(x: 1, y: offen ? 1 : 0.001, anchor: .top)
            }
            .overlay(alignment: .top) { roller.offset(y: -9) }
            .overlay {
                // Die untere Walze faehrt mit dem Rand des Papiers
                GeometryReader { geometry in
                    roller.offset(y: (offen ? geometry.size.height : 0) - 9)
                }
            }
            .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: Decree.unroll)) { open = true }
            }
    }

    private var roller: some View {
        Capsule()
            .fill(LinearGradient(colors: [Decree.rollerLight, Decree.rollerMid, Decree.rollerDark],
                                 startPoint: .top, endPoint: .bottom))
            .frame(height: 18)
            .accessibilityHidden(true)
    }
}

/// Ein Wachssiegel, das aufgedrueckt wird – nach dem Entrollen.
struct WaxSeal: View {

    var letter = "R"
    var size: CGFloat = 60

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    var body: some View {
        let sitzt = pressed || reduceMotion

        Canvas { context, canvas in
            let cx = Double(canvas.width) / 2, cy = Double(canvas.height) / 2
            let r = Double(size) / 2
            var rand: [SceneArt.Point] = []
            for i in 0..<22 {
                let w = Double(i) / 22 * 2 * .pi
                let rr = r * (0.9 + 0.16 * SceneArt.unit(i, 141))
                let punkt: SceneArt.Point = (cx + cos(w) * rr, cy + sin(w) * rr)
                rand.append(punkt)
            }
            SceneArt.fill(&context, rand, Decree.seal, 1)
            let ring = r * 0.66
            context.stroke(Path(ellipseIn: CGRect(x: cx - ring, y: cy - ring, width: 2 * ring, height: 2 * ring)),
                           with: .color(Decree.sealDark.opacity(0.9)), lineWidth: 2.5)
            context.draw(Text(letter).font(.system(size: r * 0.8, weight: .heavy, design: .serif))
                            .foregroundColor(SceneArt.rgb(210, 70, 70)),
                         at: CGPoint(x: cx, y: cy), anchor: .center)
        }
        .frame(width: size * 1.2, height: size * 1.2)
        .shadow(color: .black.opacity(0.4), radius: 4, y: 3)
        .scaleEffect(sitzt ? 1 : 1.9)
        .opacity(sitzt ? 1 : 0)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55).delay(Decree.unroll)) { pressed = true }
        }
        .accessibilityHidden(true)
    }
}
