//
//  GafferTape.swift
//  BeerStats
//
//  Die Welt der verbotenen Woerter: eine Karteikarte auf Kork, das Wort
//  unter Gewebeband. Zum Aufdecken wird das Band abgezogen, vor dem
//  Weitergeben wieder aufgeklebt. Oben haengt ein rotes Verbotsschild.
//
//  Die Karte ist ein Gegenstand und darf hell sein – mit eigener Tinte.
//

import SwiftUI

enum GafferTape {
    static let card = SceneArt.rgb(246, 244, 236)
    static let ink = SceneArt.rgb(28, 26, 26)
    static let redLine = SceneArt.rgb(210, 60, 60)
    static let blueLine = SceneArt.rgb(120, 160, 210)
    static let tape = SceneArt.rgb(168, 170, 176)
    static let sign = SceneArt.rgb(210, 30, 30)
}

/// Die Karteikarte beim Weitergeben. Zu: Band ueber der Mitte. Offen: Das
/// Band ist abgezogen, darunter steht das Geheimnis.
///
/// Wie bei der Akte steht das Geheimnis nur im Baum, solange die Karte offen
/// ist – nicht bloss verdeckt.
struct TapedCard<Secret: View>: View {

    let isOpen: Bool
    let secret: Secret

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static var minHeight: CGFloat { 270 }

    var body: some View {
        VStack(spacing: 12) {
            if isOpen {
                secret.transition(.identity)
            } else {
                Text("Handy übernehmen, dann aufdecken.")
                    .font(.scaled(14, weight: .semibold, design: .default, width: .condensed))
                    .opacity(0.6)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.identity)
            }
        }
        .foregroundStyle(GafferTape.ink)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 56)
        .padding(.bottom, 26)
        .frame(minHeight: Self.minHeight)
        .background { IndexCardPaper() }
        .overlay { tape }
        .overlay(alignment: .top) {
            // Die Pinnnadel
            Circle()
                .fill(GafferTape.sign)
                .frame(width: 22, height: 22)
                .overlay(Circle().fill(Color.white.opacity(0.5)).frame(width: 8, height: 8).offset(x: -3, y: -3))
                .offset(y: -11)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topTrailing) {
            // Das Verbotsschild
            Circle()
                .fill(GafferTape.sign)
                .frame(width: 52, height: 52)
                .overlay(RoundedRectangle(cornerRadius: 3).fill(Color.white).frame(width: 32, height: 10))
                .offset(x: 10, y: -14)
                .accessibilityHidden(true)
        }
        .rotationEffect(.degrees(-1.5))
        .shadow(color: .black.opacity(0.5), radius: 14, y: 7)
    }

    /// Das Band: abgezogen nach rechts oben, beim Zukleben zurueck.
    private var tape: some View {
        TapeStrip()
            .frame(height: 70)
            .padding(.horizontal, -18)
            .rotationEffect(.degrees(isOpen ? -24 : -6))
            .offset(x: isOpen ? 360 : 0, y: isOpen ? -90 : 6)
            .opacity(isOpen ? 0 : 1)
            .animation(reduceMotion ? nil : .easeIn(duration: 0.35), value: isOpen)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Karton mit roter Kopflinie und blauen Linien.
private struct IndexCardPaper: View {
    var body: some View {
        Canvas { context, size in
            let w = Double(size.width), h = Double(size.height)
            context.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 4), with: .color(GafferTape.card))
            let kopfLinks: SceneArt.Point = (0, 46)
            let kopfRechts: SceneArt.Point = (w, 46)
            SceneArt.lines(&context, [(kopfLinks, kopfRechts)], GafferTape.redLine, 0.7, 2)
            var linien: [(SceneArt.Point, SceneArt.Point)] = []
            for y in stride(from: 80.0, to: h - 10, by: 34) {
                let links: SceneArt.Point = (0, y)
                let rechts: SceneArt.Point = (w, y)
                linien.append((links, rechts))
            }
            SceneArt.lines(&context, linien, GafferTape.blueLine, 0.3, 1)
        }
    }
}

/// Ein Stueck Gewebeband mit gerissenen Enden und Webmuster.
private struct TapeStrip: View {
    var body: some View {
        Canvas { context, size in
            let w = Double(size.width), h = Double(size.height)
            var umriss = Path()
            umriss.move(to: CGPoint(x: 0, y: 0))
            // Gerissene Enden: kleine Zacken links und rechts
            for i in 0...6 {
                let y = h * Double(i) / 6
                umriss.addLine(to: CGPoint(x: 4 + SceneArt.noise(i, 3) * 4, y: y))
            }
            for i in stride(from: 6, through: 0, by: -1) {
                let y = h * Double(i) / 6
                umriss.addLine(to: CGPoint(x: w - 4 + SceneArt.noise(i, 9) * 4, y: y))
            }
            umriss.closeSubpath()
            context.fill(umriss, with: .color(GafferTape.tape))
            var gewebe = context
            gewebe.clip(to: umriss)
            var hell: [(SceneArt.Point, SceneArt.Point)] = []
            var dunkel: [(SceneArt.Point, SceneArt.Point)] = []
            for i in -20..<Int(w / 6 + 20) {
                let x = Double(i) * 6
                let a: SceneArt.Point = (x, 0)
                let b: SceneArt.Point = (x + h, h)
                let c: SceneArt.Point = (x + h, 0)
                let d: SceneArt.Point = (x, h)
                hell.append((a, b))
                dunkel.append((c, d))
            }
            SceneArt.lines(&gewebe, hell, .white, 0.08, 1)
            SceneArt.lines(&gewebe, dunkel, .black, 0.07, 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 4, y: 3)
    }
}
