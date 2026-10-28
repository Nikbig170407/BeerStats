//
//  Pasture.swift
//  BeerStats
//
//  Die Welt der Herde: eine Weide in der Abenddaemmerung, ein Zaun, und
//  eine gezeichnete Herde. Bei der Frage rueckt sie zusammen; wer allein
//  stand, trottet an den Rand. Wer zweimal allein steht, wird zur Kuh –
//  mit Glocke.
//
//  Ein Schaf je Mitspieler. So sieht man auf einen Blick, wie viele allein
//  standen und wie viele in der Herde.
//

import SwiftUI

enum PastureArt {
    static let wool = SceneArt.rgb(238, 232, 220)
    static let cowHide = SceneArt.rgb(240, 240, 236)
    static let face = SceneArt.rgb(52, 44, 40)
    static let cowFace = SceneArt.rgb(60, 50, 46)
    static let ink = SceneArt.rgb(28, 26, 26)
    static let bell = SceneArt.rgb(230, 190, 70)
    static let bellRim = SceneArt.rgb(150, 110, 30)
}

/// Die Herde. `alone` stehen am Rand, `cows` tragen Flecken und Glocke.
/// Beim Erscheinen rueckt sie zusammen; wer allein ist, trottet danach raus.
struct HerdField: View {

    let count: Int
    let alone: Set<Int>
    let cows: Set<Int>
    /// Namen der Allein-Stehenden, unter ihnen geschrieben.
    var names: [Int: String] = [:]
    /// Im Ergebnis steht die Herde schon beisammen – sie stand es bei der
    /// Frage. Noch einmal zusammenzuruecken hiesse fast eine Sekunde warten,
    /// bevor die Namen unter den Schafen stehen.
    var startsGathered = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var gathered = false
    @State private var split = false

    var body: some View {
        Flock(count: count, alone: alone, cows: cows, names: names,
              gather: gathered || startsGathered || reduceMotion ? 1 : 0,
              split: split || reduceMotion ? 1 : 0)
            .frame(height: 170)
            .onAppear {
                guard !reduceMotion else { return }
                if !startsGathered {
                    withAnimation(.easeInOut(duration: 0.9)) { gathered = true }
                }
                if !alone.isEmpty {
                    // Die Namen erscheinen, wenn die Schafe am Rand stehen –
                    // im Ergebnis nach gut einer halben Sekunde
                    withAnimation(.easeInOut(duration: 0.6).delay(startsGathered ? 0.05 : 0.9)) { split = true }
                }
            }
            .accessibilityHidden(true)
    }
}

/// Die Zeichnung. Animierbar ueber das Zusammenruecken und das Rausgehen.
private struct Flock: View, Animatable {

    let count: Int
    let alone: Set<Int>
    let cows: Set<Int>
    let names: [Int: String]
    var gather: Double
    var split: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(gather, split) }
        set { gather = newValue.first; split = newValue.second }
    }

    var body: some View {
        Canvas { context, size in
            let w = Double(size.width), h = Double(size.height)
            let reihen = max(1, Int((Double(count) / 4).rounded(.up)))
            for i in 0..<count {
                // Verstreut auf der Weide …
                let sx = 30 + SceneArt.unit(i, 3) * (w - 60)
                let sy = 40 + SceneArt.unit(i, 4) * (h - 70)
                // … zusammengerueckt in der Mitte …
                let spalte = Double(i % 4) - 1.5
                let reihe = Double(i / 4) - Double(reihen - 1) / 2
                let zx = w / 2 + spalte * 44 + SceneArt.noise(i, 5) * 8
                let zy = h / 2 + reihe * 32
                var x = sx + (zx - sx) * gather
                var y = sy + (zy - sy) * gather
                // … und wer allein stand, trottet an den Rand
                let allein = alone.contains(i)
                if allein {
                    let rand = i % 2 == 0 ? 34.0 : w - 34
                    x += (rand - x) * split
                    y += (h * 0.4 - y) * split
                }
                let laeuft = (gather > 0 && gather < 1) || (allein && split > 0 && split < 1)
                let schritt = laeuft ? (gather + split) * 14 + Double(i) : 0
                Self.sheep(&context, x, y - abs(sin(schritt)) * 4, isCow: cows.contains(i))
                if allein, split > 0.95, let name = names[i] {
                    context.draw(Text(name).font(.scaled(13, weight: .heavy, design: .rounded)).foregroundColor(.white),
                                 at: CGPoint(x: x, y: y - 34), anchor: .center)
                }
            }
        }
    }

    /// Ein Schaf aus Wolle – oder eine Kuh mit Flecken und Glocke.
    private static func sheep(_ g: inout GraphicsContext, _ x: Double, _ y: Double, isCow: Bool) {
        var c = g
        c.translateBy(x: x, y: y)
        c.scaleBy(x: 0.9, y: 0.9)
        SceneArt.glow(&c, 0, 22, 34, .black, 0.35)
        let fell = isCow ? PastureArt.cowHide : PastureArt.wool
        var wolle = Path()
        for i in 0..<7 {
            let w = Double(i) / 7 * 2 * .pi
            let px = cos(w) * 16, py = sin(w) * 9
            wolle.addEllipse(in: CGRect(x: px - 12, y: py - 12, width: 24, height: 24))
        }
        wolle.addEllipse(in: CGRect(x: -16, y: -16, width: 32, height: 32))
        c.fill(wolle, with: .color(fell))
        if isCow {
            SceneArt.circle(&c, -8, -3, 7, PastureArt.ink, 1)
            SceneArt.circle(&c, 9, 4, 6, PastureArt.ink, 1)
        }
        c.fill(Path(roundedRect: CGRect(x: 18, y: -10, width: 15, height: 18), cornerRadius: 7),
               with: .color(isCow ? PastureArt.cowFace : PastureArt.face))
        if isCow {
            SceneArt.circle(&c, 14, 12, 5, PastureArt.bell, 1)
            c.stroke(Path(ellipseIn: CGRect(x: 9, y: 7, width: 10, height: 10)), with: .color(PastureArt.bellRim), lineWidth: 1.2)
        }
        let beinA1: SceneArt.Point = (-10, 12)
        let beinA2: SceneArt.Point = (-10, 24)
        let beinB1: SceneArt.Point = (10, 12)
        let beinB2: SceneArt.Point = (10, 24)
        SceneArt.lines(&c, [(beinA1, beinA2), (beinB1, beinB2)], PastureArt.ink, 1, 3)
    }
}
