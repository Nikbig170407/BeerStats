//
//  ShowOfHands.swift
//  BeerStats
//
//  Die Welt von "Wer wuerde eher?": die Abstimmung. Drei, zwei, eins fallen
//  mit Wumms herein – bei null schnappen Zeigefinger von allen Raendern zur
//  Mitte. Genau das, was die Runde im selben Moment tut.
//

import SwiftUI

enum ShowOfHands {
    static let violet = SceneArt.rgb(180, 90, 255)
    static let yellow = SceneArt.rgb(255, 214, 60)
    static let skin = SceneArt.rgb(255, 214, 170)
    static let knuckle = SceneArt.rgb(220, 170, 130)
    static let sleeve = SceneArt.rgb(200, 60, 90)
}

/// Eine Zahl des Countdowns: faellt gross herein und federt ein. Jede neue
/// Zahl ist eine eigene Ansicht (`id`), deshalb faellt jede neu.
struct CountdownDigit: View {

    let value: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    var body: some View {
        let liegt = landed || reduceMotion

        Text("\(value)")
            .font(.scaled(120, weight: .black, design: .default, width: .compressed, maximumScale: 1.2))
            .foregroundStyle(Color.white)
            .shadow(color: ShowOfHands.violet.opacity(0.9), radius: 18)
            .scaleEffect(liegt ? 1 : 2.4)
            .opacity(liegt ? 1 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) { landed = true }
            }
            .accessibilityLabel("\(value)")
    }
}

/// Acht Zeigefinger, die von den Raendern zur Mitte schnappen.
struct PointingFingers: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var snapped = false

    var body: some View {
        FingerRing(progress: snapped || reduceMotion ? 1 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { snapped = true }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Die Finger auf ihrem Kreis; `progress` holt sie vom Rand herein.
/// Animierbar, damit SwiftUI die Zwischenstellungen rechnet.
private struct FingerRing: View, Animatable {

    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let w = Double(size.width), h = Double(size.height)
            let cx = w / 2, cy = h / 2
            let fern = max(w, h) * 0.75
            let nah = min(w, h) * 0.46
            let r = fern + (nah - fern) * progress
            for i in 0..<8 {
                let winkel = Double(i) / 8 * 2 * .pi + 0.2
                Self.finger(&context, cx + cos(winkel) * r, cy + sin(winkel) * r, pointing: winkel + .pi)
            }
        }
    }

    /// Ein Zeigefinger mit Faust und Aermel, der in Richtung `pointing` zeigt.
    private static func finger(_ g: inout GraphicsContext, _ x: Double, _ y: Double, pointing: Double) {
        var c = g
        c.translateBy(x: x, y: y)
        c.rotate(by: .radians(pointing))
        c.scaleBy(x: 0.9, y: 0.9)
        c.fill(Path(roundedRect: CGRect(x: -2, y: -8, width: 52, height: 16), cornerRadius: 8), with: .color(ShowOfHands.skin))
        c.fill(Path(roundedRect: CGRect(x: -40, y: -18, width: 46, height: 40), cornerRadius: 14), with: .color(ShowOfHands.skin))
        let a1: SceneArt.Point = (-34, -6)
        let a2: SceneArt.Point = (0, -6)
        let b1: SceneArt.Point = (-34, 6)
        let b2: SceneArt.Point = (0, 6)
        SceneArt.lines(&c, [(a1, a2), (b1, b2)], ShowOfHands.knuckle, 0.8, 1.5)
        c.fill(Path(roundedRect: CGRect(x: -48, y: -14, width: 14, height: 32), cornerRadius: 6), with: .color(ShowOfHands.sleeve))
    }
}
