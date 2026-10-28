//
//  BingoHall.swift
//  BeerStats
//
//  Die Welt des Trinkbingos: eine Bingohalle. Das Blatt ist Papier, jeder
//  Tipp drueckt einen Stempelklecks aufs Feld, und eine volle Reihe wird
//  mit Filzstift durchgestrichen. Die Kleckse bleiben – man sieht dem
//  Blatt den Abend an.
//

import SwiftUI

enum BingoHall {
    static let paper = SceneArt.rgb(244, 238, 224)
    static let ink = SceneArt.rgb(28, 26, 26)
    static let red = SceneArt.rgb(210, 40, 50)
    static let dauber = SceneArt.rgb(226, 40, 130)
}

/// Ein Stempelklecks: nie ganz rund, und jeder Klecks anders – gerechnet
/// aus seinem Feld, damit er beim Neuzeichnen derselbe bleibt.
struct BingoDaub: View {

    let seed: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    var body: some View {
        let sitzt = pressed || reduceMotion

        Canvas { context, size in
            let cx = Double(size.width) / 2, cy = Double(size.height) / 2
            let r = min(cx, cy) * 0.82
            var punkte: [SceneArt.Point] = []
            for i in 0..<18 {
                let w = Double(i) / 18 * 2 * .pi
                let rr = r * (0.82 + 0.3 * SceneArt.unit(i + seed * 7, 131))
                let punkt: SceneArt.Point = (cx + cos(w) * rr, cy + sin(w) * rr)
                punkte.append(punkt)
            }
            SceneArt.fill(&context, punkte, BingoHall.dauber, 0.55)
            SceneArt.circle(&context, cx - r * 0.2, cy - r * 0.25, r * 0.3, .white, 0.08)
        }
        .scaleEffect(sitzt ? 1 : 1.6)
        .opacity(sitzt ? 1 : 0)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { pressed = true }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Ein Filzstiftstrich quer durch eine volle Reihe. Er wird gezogen, nicht
/// eingeblendet.
struct MarkerStrike: View {

    let from: CGPoint
    let to: CGPoint

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false

    var body: some View {
        StrikePath(from: from, to: to)
            .trim(from: 0, to: drawn || reduceMotion ? 1 : 0)
            .stroke(BingoHall.red.opacity(0.85), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.45)) { drawn = true }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Die Linie des Strichs – leicht wellig, wie mit der Hand gezogen.
private struct StrikePath: Shape {

    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let schritte = 20
        let dx = Double(to.x - from.x), dy = Double(to.y - from.y)
        let laenge = max(1, (dx * dx + dy * dy).squareRoot())
        let nx = -dy / laenge, ny = dx / laenge
        for k in 0...schritte {
            let u = Double(k) / Double(schritte)
            let welle = 3 * sin(Double(k) * 1.3)
            let x = Double(from.x) + dx * u + nx * welle
            let y = Double(from.y) + dy * u + ny * welle
            if k == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        return p
    }
}

/// "BINGO!" als schiefer roter Knopf, der aufspringt.
struct BingoBadge: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popped = false

    var body: some View {
        let da = popped || reduceMotion

        Text("BINGO!")
            .font(.scaled(40, weight: .black, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
            .background(Capsule().fill(BingoHall.red))
            .rotationEffect(.degrees(-5))
            .scaleEffect(da ? 1 : 2)
            .opacity(da ? 1 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { popped = true }
            }
    }
}
