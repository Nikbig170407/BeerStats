//
//  CoverArtQuick.swift
//  BeerStats
//
//  Die Cover der Gruppe "Schnell zwischendurch": Bombe, Reaktionsduell,
//  Trink-Roulette und Die Herde. Vom Nutzer am 19. November in der Vorschau
//  abgenommen; die Zahlen sind die der Vorschau.
//

import SwiftUI

extension CoverArt {

    private typealias P = PosterInk

    private static let red = SceneArt.rgb(216, 52, 42)

    /// Eine Gruppe, um einen Punkt gedreht – wie `rotate(grad x y)` im SVG.
    static func turned(_ g: GraphicsContext, around p: CGPoint, degrees: Double) -> GraphicsContext {
        var k = g
        k.translateBy(x: p.x, y: p.y)
        k.rotate(by: .degrees(degrees))
        k.translateBy(x: -p.x, y: -p.y)
        return k
    }

    // MARK: - Bombe

    /// Eine schwarze Bombe mit zischender Zuendschnur, auf ihrem Bauch ein
    /// Zifferblatt kurz vor zwoelf, ringsum Funken.
    static func drawTimeBomb(_ g: inout GraphicsContext) {
        P.ground(&g, inner: SceneArt.rgb(168, 50, 28), outer: SceneArt.rgb(42, 8, 6), center: CGPoint(x: 150, y: 208))

        let mitte = CGPoint(x: 150, y: 178)
        let koerper = P.ellipse(150, 178, 80, 78)
        g.fill(koerper.offsetBy(dx: 5, dy: 6), with: .color(Color.black.opacity(0.3)))
        P.inked(&g, koerper, SceneArt.rgb(43, 43, 53), line: 3.4)
        P.line(&g, P.path("M92 142 Q104 108 138 102"), Color.white, 7, opacity: 0.28)
        P.inked(&g, P.box(128, 86, 44, 26, corner: 6), SceneArt.rgb(74, 74, 88), line: 3)

        P.inked(&g, P.circle(mitte, 42), P.cream, line: 3.2)
        var ticks = Path()
        for k in 0..<12 {
            ticks.move(to: P.point(mitte, 29, Double(k) * 30))
            ticks.addLine(to: P.point(mitte, k % 3 == 0 ? 36 : 33, Double(k) * 30))
        }
        g.stroke(ticks, with: .color(P.ink), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        P.line(&g, P.path("M150 178 L150 150"), P.ink, 5)
        P.line(&g, P.path("M150 178 L168 164"), red, 4)
        P.inked(&g, P.circle(mitte, 5), red, line: 2)

        // Die Zuendschnur und der Funke an ihrem Ende
        let schnur = P.path("M150 88 C152 60 186 62 194 40")
        P.line(&g, schnur, P.ink, 9)
        g.stroke(schnur, with: .color(SceneArt.rgb(201, 165, 106)),
                 style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [9, 5]))
        P.inked(&g, P.star(CGPoint(x: 200, y: 34), outer: 22, inner: 9, points: 8), P.orange, line: 3)
        g.fill(P.star(CGPoint(x: 200, y: 34), outer: 11, inner: 4, points: 8), with: .color(SceneArt.rgb(255, 246, 216)))

        P.sparkle(&g, CGPoint(x: 250, y: 82), 6)
        P.sparkle(&g, CGPoint(x: 48, y: 70), 5, color: P.cream)
        P.sparkle(&g, CGPoint(x: 262, y: 240), 7, color: P.cream)
        P.sparkle(&g, CGPoint(x: 40, y: 236), 5)
    }

    // MARK: - Reaktionsduell

    /// Eine Ampel springt auf Gruen, links und rechts darunter je ein
    /// Buzzer, ein Blitz schlaegt dazwischen.
    static func drawBuzzerLight(_ g: inout GraphicsContext) {
        P.ground(&g, inner: SceneArt.rgb(29, 122, 99), outer: SceneArt.rgb(4, 32, 28), center: CGPoint(x: 150, y: 168))

        P.inked(&g, P.box(114, 28, 72, 176, corner: 14), SceneArt.rgb(26, 29, 34), line: 3.4)
        P.inked(&g, P.box(144, 204, 12, 26, corner: 3), SceneArt.rgb(58, 63, 71), line: 2.6)
        let aus = SceneArt.rgb(42, 46, 52)
        P.inked(&g, P.circle(CGPoint(x: 150, y: 62), 17), aus, line: 2.6)
        P.inked(&g, P.circle(CGPoint(x: 150, y: 116), 17), aus, line: 2.6)
        let gruen = SceneArt.rgb(52, 210, 122)
        g.fill(P.circle(CGPoint(x: 150, y: 170), 26), with: .color(gruen.opacity(0.28)))
        P.inked(&g, P.circle(CGPoint(x: 150, y: 170), 17), gruen, line: 2.6)
        P.line(&g, P.path("M141 163 Q145 159 150 159"), Color.white, 3, opacity: 0.7)

        buzzer(&g, x: 52, color: red)
        buzzer(&g, x: 248, color: SceneArt.rgb(58, 111, 224))

        P.inked(&g, P.path("M150 226 L134 256 L148 256 L140 286 L168 246 L153 246 L164 226 Z"), P.yellow, line: 2.6)

        P.sparkle(&g, CGPoint(x: 240, y: 60), 7)
        P.sparkle(&g, CGPoint(x: 52, y: 80), 5, color: P.cream)
        P.sparkle(&g, CGPoint(x: 262, y: 150), 5, color: P.cream)
        P.sparkle(&g, CGPoint(x: 30, y: 150), 4)
    }

    private static func buzzer(_ g: inout GraphicsContext, x: CGFloat, color: Color) {
        g.fill(P.ellipse(x, 272, 46, 12), with: .color(Color.black.opacity(0.3)))
        P.inked(&g, P.box(x - 44, 246, 88, 28, corner: 8), SceneArt.rgb(45, 49, 56), line: 3)
        P.inked(&g, P.path("M\(x - 36) 248 C\(x - 36) 214 \(x + 36) 214 \(x + 36) 248 Z"), color, line: 3.2)
        P.line(&g, P.path("M\(x - 22) 236 Q\(x - 18) 222 \(x - 4) 220"), Color.white, 5, opacity: 0.5)
    }

    // MARK: - Trink-Roulette

    /// Ein Roulette-Rad aus roten und schwarzen Tortenstuecken mit goldener
    /// Nabe, oben zeigt ein Zeiger auf das gruene Feld, eine Kugel liegt im Rad.
    static func drawRouletteWheel(_ g: inout GraphicsContext) {
        P.ground(&g, inner: SceneArt.rgb(31, 122, 67), outer: SceneArt.rgb(4, 24, 12), center: CGPoint(x: 150, y: 184))

        let mitte = CGPoint(x: 150, y: 156)
        let radius: CGFloat = 112
        g.fill(P.circle(CGPoint(x: 155, y: 163), radius + 6), with: .color(Color.black.opacity(0.3)))

        let schwarz = SceneArt.rgb(29, 29, 34)
        for k in 0..<12 {
            let farbe = k == 0 ? SceneArt.rgb(47, 163, 90) : (k % 2 == 0 ? red : schwarz)
            let stueck = P.wedge(mitte, radius, from: Double(k) * 30, to: Double(k + 1) * 30)
            g.fill(stueck, with: .color(farbe))
            g.stroke(stueck, with: .color(P.ink), lineWidth: 2)
        }
        g.stroke(P.circle(mitte, radius), with: .color(SceneArt.rgb(107, 61, 18)), lineWidth: 12)
        g.stroke(P.circle(mitte, radius + 6), with: .color(P.ink), lineWidth: 3)
        g.stroke(P.circle(mitte, radius - 6), with: .color(P.ink), lineWidth: 2)

        var speichen = Path()
        for a in [0.0, 90, 180, 270] {
            speichen.move(to: mitte)
            speichen.addLine(to: P.point(mitte, 40, a + 45))
        }
        g.stroke(speichen, with: .color(P.ink), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        P.inked(&g, P.circle(mitte, 58), P.orange, line: 3)
        P.inked(&g, P.circle(mitte, 40), SceneArt.rgb(138, 90, 20), line: 2.6)
        P.inked(&g, P.circle(mitte, 15), P.yellow, line: 2.6)
        P.inked(&g, P.circle(P.point(mitte, 82, 118), 9), SceneArt.rgb(255, 246, 228), line: 2.4)

        P.inked(&g, P.path("M150 18 L138 52 L162 52 Z"), P.yellow, line: 3)

        P.sparkle(&g, CGPoint(x: 38, y: 52), 6)
        P.sparkle(&g, CGPoint(x: 264, y: 262), 7, color: P.cream)
        P.sparkle(&g, CGPoint(x: 36, y: 270), 5)
    }

    // MARK: - Die Herde

    /// Eine Herde weisser Schafe draengt sich auf einer Wiese unter dem Mond,
    /// ein schwarzes Schaf steht allein links davor.
    static func drawBlackSheep(_ g: inout GraphicsContext) {
        P.ground(&g, inner: SceneArt.rgb(42, 74, 154), outer: SceneArt.rgb(7, 13, 38), center: CGPoint(x: 150, y: 120))

        P.inked(&g, P.circle(CGPoint(x: 236, y: 66), 30), SceneArt.rgb(255, 243, 207), line: 3)

        let huegel = P.path("M0 246 Q70 206 150 222 Q230 238 300 206 L300 400 L0 400 Z")
        P.inked(&g, huegel, SceneArt.rgb(47, 143, 76), line: 3)
        P.line(&g, P.path("M0 246 Q70 206 150 222 Q230 238 300 206"), SceneArt.rgb(127, 208, 138), 3, opacity: 0.7)

        let gesicht = SceneArt.rgb(74, 58, 52)
        let herde: [(CGFloat, CGFloat, CGFloat)] = [(142, 150, 1.0), (226, 158, 1.0), (182, 196, 0.95), (256, 218, 0.8), (118, 224, 0.8)]
        for (x, y, s) in herde {
            sheep(&g, at: CGPoint(x: x, y: y), scale: s, wool: P.cream, face: gesicht)
        }
        sheep(&g, at: CGPoint(x: 72, y: 172), scale: 1.05, wool: SceneArt.rgb(42, 42, 50), face: SceneArt.rgb(75, 67, 80))

        P.sparkle(&g, CGPoint(x: 150, y: 42), 7)
        P.sparkle(&g, CGPoint(x: 40, y: 52), 5, color: P.cream)
        P.sparkle(&g, CGPoint(x: 266, y: 120), 5, color: P.cream)
    }

    /// Ein Schaf, das nach links schaut: Fuesse, Wolle aus Kreisen, Kopf.
    private static func sheep(_ g: inout GraphicsContext, at ort: CGPoint, scale: CGFloat, wool: Color, face: Color) {
        var s = g
        s.translateBy(x: ort.x, y: ort.y)
        s.scaleBy(x: scale, y: scale)

        s.fill(P.ellipse(2, 40, 42, 7), with: .color(Color.black.opacity(0.25)))
        P.line(&s, P.path("M-18 24 L-18 40 M-4 26 L-4 40 M14 26 L14 40 M28 24 L28 40"), P.ink, 7)
        P.line(&s, P.path("M-18 24 L-18 38 M-4 26 L-4 38 M14 26 L14 38 M28 24 L28 38"), face, 3.4)

        let kreise: [(CGFloat, CGFloat, CGFloat)] = [(-24, 6, 17), (-8, -8, 19), (12, -8, 19), (28, 6, 17), (-14, 20, 17), (10, 22, 18), (2, 6, 20)]
        for (x, y, r) in kreise {
            P.inked(&s, P.circle(CGPoint(x: x, y: y), r), wool, line: 3)
        }
        // Die Kontur der inneren Kreise ueberdecken: Die Wolle ist eine Masse
        for (x, y, r) in kreise {
            s.fill(P.circle(CGPoint(x: x, y: y), r - 3), with: .color(wool))
        }

        P.inked(&s, P.ellipse(-36, 10, 14, 12), face, line: 3)
        s.fill(P.circle(CGPoint(x: -40, y: 7), 2.6), with: .color(Color.white))
        s.fill(P.circle(CGPoint(x: -40, y: 7), 1.2), with: .color(P.ink))
        P.inked(&s, P.path("M-30 -2 Q-24 -12 -18 -2"), face, line: 2.4)
    }
}
