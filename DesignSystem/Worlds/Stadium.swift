//
//  Stadium.swift
//  BeerStats
//
//  Der Ort des Turniers: ein Stadion bei Flutlicht. Eine Anzeigetafel
//  zaehlt die Runden in Sieben-Segment-Ziffern, und die Strafe steigt als
//  Treppe – mit jeder Runde waechst eine Stufe. Genau das ist der Trick des
//  Formats: Ein Rueckstand ist nie endgueltig.
//

import SwiftUI

enum StadiumArt {
    static let red = SceneArt.rgb(255, 70, 50)
    static let amber = SceneArt.rgb(255, 190, 40)
    static let amberDark = SceneArt.rgb(120, 90, 40)
    static let board = SceneArt.rgb(14, 14, 16)
    static let rim = SceneArt.rgb(70, 70, 76)
    static let idle = SceneArt.rgb(36, 36, 44)

    /// Welche Segmente eine Ziffer zeigt (a oben, dann im Uhrzeigersinn,
    /// g in der Mitte).
    static let segments: [Int: String] = [
        0: "abcdef", 1: "bc", 2: "abged", 3: "abgcd", 4: "fgbc",
        5: "afgcd", 6: "afgedc", 7: "abc", 8: "abcdefg", 9: "abcdfg",
    ]
}

/// Eine Zahl in Sieben-Segment-Ziffern, wie auf einer Anzeigetafel. Die
/// dunklen Segmente bleiben schwach sichtbar – das macht die Tafel aus.
struct SevenSegmentNumber: View {

    let value: Int
    var color: Color = StadiumArt.red
    var height: CGFloat = 44

    var body: some View {
        let ziffern = String(max(0, value)).compactMap(\.wholeNumberValue)

        Canvas { context, size in
            let h = Double(size.height)
            let breite = h * 0.55
            for (i, ziffer) in ziffern.enumerated() {
                Self.digit(&context, Double(i) * (breite + h * 0.18), 0, h, ziffer, color)
            }
        }
        .frame(width: height * (CGFloat(ziffern.count) * 0.55 + CGFloat(max(0, ziffern.count - 1)) * 0.18), height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value)")
    }

    private static func digit(_ g: inout GraphicsContext, _ x: Double, _ y: Double, _ h: Double, _ ziffer: Int, _ farbe: Color) {
        let w = h * 0.55, d = h * 0.11
        let l = w - d * 1.2, hv = (h - d * 3) / 2

        func waagerecht(_ cx: Double, _ cy: Double) -> [SceneArt.Point] {
            let links: SceneArt.Point = (cx - l / 2, cy)
            let a: SceneArt.Point = (cx - l / 2 + d / 2, cy - d / 2)
            let b: SceneArt.Point = (cx + l / 2 - d / 2, cy - d / 2)
            let rechts: SceneArt.Point = (cx + l / 2, cy)
            let c: SceneArt.Point = (cx + l / 2 - d / 2, cy + d / 2)
            let e: SceneArt.Point = (cx - l / 2 + d / 2, cy + d / 2)
            return [links, a, b, rechts, c, e]
        }
        func senkrecht(_ cx: Double, _ cy: Double) -> [SceneArt.Point] {
            let oben: SceneArt.Point = (cx, cy - hv / 2)
            let a: SceneArt.Point = (cx + d / 2, cy - hv / 2 + d / 2)
            let b: SceneArt.Point = (cx + d / 2, cy + hv / 2 - d / 2)
            let unten: SceneArt.Point = (cx, cy + hv / 2)
            let c: SceneArt.Point = (cx - d / 2, cy + hv / 2 - d / 2)
            let e: SceneArt.Point = (cx - d / 2, cy - hv / 2 + d / 2)
            return [oben, a, b, unten, c, e]
        }

        let teile: [(Character, [SceneArt.Point])] = [
            ("a", waagerecht(x + w / 2, y + d / 2)),
            ("g", waagerecht(x + w / 2, y + h / 2)),
            ("d", waagerecht(x + w / 2, y + h - d / 2)),
            ("f", senkrecht(x + d / 2, y + d + hv / 2)),
            ("b", senkrecht(x + w - d / 2, y + d + hv / 2)),
            ("e", senkrecht(x + d / 2, y + h - d - hv / 2)),
            ("c", senkrecht(x + w - d / 2, y + h - d - hv / 2)),
        ]
        let an = StadiumArt.segments[ziffer] ?? ""
        for (name, punkte) in teile {
            SceneArt.fill(&g, punkte, farbe, an.contains(name) ? 1 : 0.07)
        }
    }
}

/// Die Strafe als Treppe: eine Stufe je Runde, die gespielten leuchten,
/// die aktuelle in Gelb. Die neue Stufe waechst beim Erscheinen.
struct PenaltyStairs: View {

    let rounds: Int
    /// Die Runde, die gerade ansteht, bei null beginnend.
    let current: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            ForEach(0..<max(rounds, 1), id: \.self) { stufe in
                let erreicht = stufe <= current
                let anteil = Double(stufe + 1) / Double(max(rounds, 1))
                // Die aktuelle Stufe waechst beim Erscheinen aus dem Boden
                let wachstum: Double = stufe == current && !(grown || reduceMotion) ? 0.2 : 1
                let hoehe = CGFloat(20 + 90 * anteil * wachstum)
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(stufe == current ? StadiumArt.amber : (erreicht ? StadiumArt.amberDark : StadiumArt.idle))
                        .frame(height: hoehe)
                    Text("\(stufe + 1)")
                        .font(GameWorld.stadium.font(12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(erreicht ? 0.9 : 0.4))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 130, alignment: .bottom)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7).delay(0.1)) { grown = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Runde \(current + 1) von \(rounds) – die Strafe steigt jede Runde")
    }
}
