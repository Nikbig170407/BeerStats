//
//  CoverArtTalk.swift
//  BeerStats
//
//  Die Cover der Gruppe "Raten & reden", erste Haelfte. Vom Nutzer am
//  6. November in der Vorschau abgenommen ("die cover sind gut") – bis
//  auf "Wer bin ich?", das neu gezeichnet wird. Die Zahlen sind die der
//  Vorschau.
//

import SwiftUI

extension CoverArt {

    private typealias P = PosterInk

    // MARK: - Werkzeug

    /// Ein Wuerfel schraeg von vorn: Vorderseite mit Augen, Deckel, rechte
    /// Seite. `pips` sind 1, 2 oder 3 Augen, gedreht um die Mitte.
    private static func die(_ g: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat, pips: Int, rotation: Double) {
        let a = 44 * s, d = 10 * s
        var w = g
        w.translateBy(x: x + a / 2, y: y + a / 2)
        w.rotate(by: .degrees(rotation))
        w.translateBy(x: -(x + a / 2), y: -(y + a / 2))

        var deckel = Path()
        deckel.move(to: CGPoint(x: x, y: y))
        deckel.addLine(to: CGPoint(x: x + d, y: y - d))
        deckel.addLine(to: CGPoint(x: x + a + d, y: y - d))
        deckel.addLine(to: CGPoint(x: x + a, y: y))
        deckel.closeSubpath()
        P.inked(&w, deckel, .white)

        var seite = Path()
        seite.move(to: CGPoint(x: x + a, y: y))
        seite.addLine(to: CGPoint(x: x + a + d, y: y - d))
        seite.addLine(to: CGPoint(x: x + a + d, y: y + a - d))
        seite.addLine(to: CGPoint(x: x + a, y: y + a))
        seite.closeSubpath()
        P.inked(&w, seite, SceneArt.rgb(217, 207, 189))

        P.inked(&w, P.box(x, y, a, a, corner: 6 * s), P.cream, line: 2.6)

        let lagen: [(CGFloat, CGFloat)]
        switch pips {
        case 1: lagen = [(0.5, 0.5)]
        case 2: lagen = [(0.27, 0.27), (0.73, 0.73)]
        default: lagen = [(0.25, 0.25), (0.5, 0.5), (0.75, 0.75)]
        }
        var augen = Path()
        for (u, v) in lagen { augen.addPath(P.circle(CGPoint(x: x + u * a, y: y + v * a), 5.2 * s)) }
        w.fill(augen, with: .color(SceneArt.rgb(198, 56, 28)))
    }

    /// Um einen Punkt gedreht zeichnen – wie `rotate(r x y)` in der Vorschau.
    private static func turned(_ g: GraphicsContext, _ grad: Double, around mitte: CGPoint) -> GraphicsContext {
        var k = g
        k.translateBy(x: mitte.x, y: mitte.y)
        k.rotate(by: .degrees(grad))
        k.translateBy(x: -mitte.x, y: -mitte.y)
        return k
    }

    // MARK: - Schocken

    /// Ein Lederbecher hebt sich von drei Einsen, daneben ein Stapel
    /// Bierdeckel im Lampenlicht.
    static func drawDiceCup(_ g: inout GraphicsContext) {
        P.ground(&g, inner: SceneArt.rgb(122, 82, 48), outer: SceneArt.rgb(31, 18, 9), center: CGPoint(x: 150, y: 32))

        var maserung = Path()
        for k in 0..<9 {
            let y = CGFloat(k * 30)
            maserung.move(to: CGPoint(x: 0, y: 40 + y))
            maserung.addCurve(to: CGPoint(x: 300, y: 38 + y),
                              control1: CGPoint(x: 80, y: 30 + y), control2: CGPoint(x: 200, y: 52 + y))
        }
        g.stroke(maserung, with: .color(Color.black.opacity(0.18)), lineWidth: 2)

        // Das Licht der Lampe von oben
        g.fill(P.box(0, 0, width, height - 74), with: .radialGradient(
            Gradient(colors: [P.yellow.opacity(0.45), P.yellow.opacity(0)]),
            center: CGPoint(x: 150, y: 0), startRadius: 0, endRadius: 240))

        // Ein Stapel Bierdeckel
        for k in 0..<5 {
            let y = CGFloat(232 - k * 7), x = CGFloat(74 + (k % 2 == 1 ? 3 : -2))
            P.inked(&g, P.ellipse(x, y + 4, 48, 17), SceneArt.rgb(138, 28, 20), line: 2)
            P.inked(&g, P.ellipse(x, y, 48, 17), P.cream, line: 2.2)
            g.stroke(P.ellipse(x, y, 36, 12), with: .color(SceneArt.rgb(198, 56, 28)), lineWidth: 3)
        }

        // Der Becher hebt sich
        var becher = turned(g, -24, around: CGPoint(x: 196, y: 74))
        let form = P.path("M156 30 L236 30 L226 112 L166 112 Z")
        becher.fill(form.offsetBy(dx: 6, dy: 8), with: .color(Color.black.opacity(0.3)))
        P.inked(&becher, form, SceneArt.rgb(107, 52, 24), line: 3)
        becher.stroke(P.path("M162 46 L230 46 M164 96 L228 96"), with: .color(SceneArt.rgb(63, 28, 11)), lineWidth: 5)
        P.line(&becher, P.path("M172 50 L178 92"), SceneArt.rgb(166, 90, 44), 5, opacity: 0.9)
        P.inked(&becher, P.ellipse(196, 112, 30, 7), SceneArt.rgb(42, 18, 8))

        P.line(&g, P.path("M170 138 L178 128 M196 142 L198 130 M222 138 L216 128"), P.cream, 2.6, opacity: 0.7)

        // Drei Einsen
        g.fill(P.ellipse(200, 232, 86, 14), with: .color(Color.black.opacity(0.3)))
        die(&g, 132, 178, 1, pips: 1, rotation: -8)
        die(&g, 186, 186, 1, pips: 1, rotation: 6)
        die(&g, 236, 172, 0.9, pips: 1, rotation: -4)

        P.sparkle(&g, CGPoint(x: 46, y: 60), 8)
        P.sparkle(&g, CGPoint(x: 268, y: 120), 5)
        P.sparkle(&g, CGPoint(x: 150, y: 272), 5, color: P.cream)
    }

    // MARK: - Maexchen

    /// Zwei Wuerfel zeigen Zwei und Eins, darueber schlaegt die Nadel eines
    /// Luegendetektors auf Millimeterpapier aus.
    static func drawLiarsDice(_ g: inout GraphicsContext) {
        let rot = SceneArt.rgb(255, 90, 60)
        P.ground(&g, inner: SceneArt.rgb(39, 96, 106), outer: SceneArt.rgb(8, 29, 34), center: CGPoint(x: 150, y: 200))

        // Millimeterpapier, jede fuenfte Linie kraeftiger
        var fein = Path(), grob = Path()
        for k in 0...20 {
            let x = CGFloat(k * 15)
            if k % 5 == 0 { grob.move(to: CGPoint(x: x, y: 0)); grob.addLine(to: CGPoint(x: x, y: 296)) }
            else { fein.move(to: CGPoint(x: x, y: 0)); fein.addLine(to: CGPoint(x: x, y: 296)) }
        }
        for k in 0...19 {
            let y = CGFloat(k * 15)
            if k % 5 == 0 { grob.move(to: CGPoint(x: 0, y: y)); grob.addLine(to: CGPoint(x: 300, y: y)) }
            else { fein.move(to: CGPoint(x: 0, y: y)); fein.addLine(to: CGPoint(x: 300, y: y)) }
        }
        let papier = SceneArt.rgb(159, 240, 232).opacity(0.18)
        g.stroke(fein, with: .color(papier), lineWidth: 0.6)
        g.stroke(grob, with: .color(papier), lineWidth: 1.4)

        // Die Nadel schlaegt aus
        let kurve = P.path("M0 96 L30 92 L52 100 L70 88 L88 104 L100 58 L112 140 L124 36 L138 150 L150 70 L162 112 L176 92 L196 98 L220 90 L244 100 L262 92")
        g.stroke(kurve.offsetBy(dx: 3, dy: 4), with: .color(Color.black.opacity(0.25)),
                 style: StrokeStyle(lineWidth: 5, lineJoin: .round))
        P.line(&g, kurve, rot, 3.6)
        let arm = P.path("M262 92 L292 20")
        P.line(&g, arm, P.ink, 5)
        P.line(&g, arm, SceneArt.rgb(207, 214, 216), 2.4)
        P.inked(&g, P.circle(CGPoint(x: 262, y: 92), 5), rot, line: 2)

        g.fill(P.ellipse(150, 262, 96, 13), with: .color(Color.black.opacity(0.3)))
        die(&g, 70, 176, 1.55, pips: 2, rotation: -10)
        die(&g, 160, 182, 1.55, pips: 1, rotation: 9)

        P.sparkle(&g, CGPoint(x: 40, y: 150), 6)
        P.sparkle(&g, CGPoint(x: 272, y: 160), 7)
        P.sparkle(&g, CGPoint(x: 150, y: 20), 5, color: P.cream)
    }

    // MARK: - Zwei Wahrheiten

    /// An einer Leine haengen drei Zettel, zwei mit gruenem Haken, der
    /// mittlere mit rotem Kreuz und Fingerabdruck.
    static func drawClothesline(_ g: inout GraphicsContext) {
        P.ground(&g, inner: SceneArt.rgb(106, 58, 154), outer: SceneArt.rgb(27, 11, 48), center: CGPoint(x: 150, y: 160))
        P.line(&g, P.path("M-10 66 Q150 100 310 58"), P.cream, 2.6)
        slip(&g, 58, 76, -6, isTrue: true)
        slip(&g, 150, 86, 3, isTrue: false)
        slip(&g, 242, 74, 7, isTrue: true)
        P.sparkle(&g, CGPoint(x: 40, y: 30), 7)
        P.sparkle(&g, CGPoint(x: 262, y: 250), 6)
        P.sparkle(&g, CGPoint(x: 150, y: 256), 5, color: P.cream)
        P.sparkle(&g, CGPoint(x: 110, y: 30), 4, color: P.cream)
    }

    private static func slip(_ g: inout GraphicsContext, _ cx: CGFloat, _ top: CGFloat, _ grad: Double, isTrue: Bool) {
        var z = turned(g, grad, around: CGPoint(x: cx, y: top))
        z.fill(P.box(cx - 29, top + 6, 68, 124, corner: 4), with: .color(Color.black.opacity(0.3)))
        P.inked(&z, P.box(cx - 34, top, 68, 124, corner: 4), P.cream, line: 2.6)

        var zeilen = Path()
        for k in 0..<4 {
            let y = top + 22 + CGFloat(k * 13)
            zeilen.move(to: CGPoint(x: cx - 24, y: y))
            zeilen.addLine(to: CGPoint(x: cx + (k == 3 ? 6 : 24), y: y))
        }
        P.line(&z, zeilen, SceneArt.rgb(139, 127, 108), 3, opacity: 0.6)

        if isTrue {
            var haken = Path()
            haken.move(to: CGPoint(x: cx - 18, y: top + 92))
            haken.addLine(to: CGPoint(x: cx - 4, y: top + 106))
            haken.addLine(to: CGPoint(x: cx + 22, y: top + 76))
            P.line(&z, haken, SceneArt.rgb(47, 158, 87), 7)
        } else {
            var kreuz = Path()
            kreuz.move(to: CGPoint(x: cx - 18, y: top + 74)); kreuz.addLine(to: CGPoint(x: cx + 18, y: top + 110))
            kreuz.move(to: CGPoint(x: cx + 18, y: top + 74)); kreuz.addLine(to: CGPoint(x: cx - 18, y: top + 110))
            P.line(&z, kreuz, SceneArt.rgb(216, 52, 42), 7)
            var abdruck = Path()
            for r: CGFloat in [11, 7, 3] { abdruck.addPath(P.circle(CGPoint(x: cx + 20, y: top + 30), r)) }
            P.line(&z, abdruck, SceneArt.rgb(201, 160, 160), 1.5, opacity: 0.8)
        }

        // Die Klammer
        P.inked(&z, P.box(cx - 5, top - 14, 10, 26, corner: 2), SceneArt.rgb(201, 138, 74), line: 2)
    }

    // MARK: - Der Spion

    /// Ueber eine Akte mit rotem Stempel spaeht ein Hut mit zwei Augen,
    /// eine Lupe zeigt einen Fingerabdruck.
    static func drawDossier(_ g: inout GraphicsContext) {
        P.ground(&g, inner: SceneArt.rgb(106, 74, 44), outer: SceneArt.rgb(30, 19, 10), center: CGPoint(x: 150, y: 220))

        // Die Akte
        var akte = turned(g, -8, around: CGPoint(x: 140, y: 196))
        let mappe = P.path("M40 120 L100 120 L110 108 L170 108 L176 120 L240 120 L240 280 L40 280 Z")
        akte.fill(mappe.offsetBy(dx: 6, dy: 7), with: .color(Color.black.opacity(0.3)))
        P.inked(&akte, mappe, SceneArt.rgb(217, 178, 106), line: 3)
        akte.fill(P.box(54, 132, 172, 134), with: .color(P.cream.opacity(0.95)))
        akte.stroke(P.box(54, 132, 172, 134), with: .color(P.ink), lineWidth: 1.6)
        var zeilen = Path()
        for k in 0..<5 {
            let y = CGFloat(152 + k * 18)
            zeilen.move(to: CGPoint(x: 68, y: y))
            zeilen.addLine(to: CGPoint(x: k == 4 ? 150 : 212, y: y))
        }
        P.line(&akte, zeilen, SceneArt.rgb(139, 127, 108), 3, opacity: 0.55)
        var stempel = turned(akte, -14, around: CGPoint(x: 170, y: 236))
        let stempelRot = SceneArt.rgb(198, 56, 28)
        stempel.stroke(P.box(118, 218, 104, 34, corner: 4), with: .color(stempelRot), lineWidth: 4)
        P.letter(&stempel, "GEHEIM", at: CGPoint(x: 170, y: 236), size: 21, color: stempelRot)

        // Hut und zwei Augen ueber dem Rand
        P.inked(&g, P.path("M150 70 C150 40 170 30 196 30 C222 30 242 40 242 70 Z"), SceneArt.rgb(26, 20, 16), line: 2.6)
        P.inked(&g, P.path("M126 72 Q196 58 268 72 Q196 86 126 72 Z"), SceneArt.rgb(36, 28, 22), line: 2.6)
        g.stroke(P.path("M152 62 Q196 54 240 62"), with: .color(SceneArt.rgb(138, 28, 20)), lineWidth: 5)
        g.fill(P.path("M150 74 L242 74 L232 104 L160 104 Z"), with: .color(SceneArt.rgb(42, 32, 24)))
        g.fill(P.ellipse(178, 90, 9, 6), with: .color(P.cream))
        g.fill(P.ellipse(214, 90, 9, 6), with: .color(P.cream))
        g.fill(P.circle(CGPoint(x: 181, y: 91), 3.4), with: .color(P.ink))
        g.fill(P.circle(CGPoint(x: 217, y: 91), 3.4), with: .color(P.ink))

        // Die Lupe, der Griff nach links unten
        let griff = P.path("M62 224 L32 264")
        g.stroke(griff.offsetBy(dx: 5, dy: 6), with: .color(Color.black.opacity(0.3)),
                 style: StrokeStyle(lineWidth: 14, lineCap: .round))
        P.line(&g, griff, P.ink, 15)
        P.line(&g, P.path("M60 226 L34 262"), SceneArt.rgb(122, 62, 28), 9)
        let glas = P.circle(CGPoint(x: 88, y: 196), 38)
        g.fill(glas, with: .color(SceneArt.rgb(191, 227, 234).opacity(0.75)))
        g.stroke(glas, with: .color(P.ink), lineWidth: 5)

        // Fingerabdruck: halbe Ellipsen, oben geschlossen
        var abdruck = Path()
        for r in stride(from: CGFloat(6), to: 30, by: 5) {
            var bogen = Path()
            bogen.addArc(center: .zero, radius: 1, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            abdruck.addPath(bogen.applying(CGAffineTransform(translationX: 88, y: 196).scaledBy(x: r, y: r + 4)))
        }
        P.line(&g, abdruck, P.ink, 1.6, opacity: 0.55)
        var glanz = Path()
        glanz.addArc(center: CGPoint(x: 88, y: 196), radius: 30, startAngle: .degrees(222), endAngle: .degrees(270), clockwise: false)
        P.line(&g, glanz, .white, 4, opacity: 0.8)

        P.sparkle(&g, CGPoint(x: 46, y: 46), 7)
        P.sparkle(&g, CGPoint(x: 274, y: 140), 5)
        P.sparkle(&g, CGPoint(x: 262, y: 270), 6, color: P.cream)
    }

    // MARK: - 21

    /// Kaertchen mit achtzehn, neunzehn und zwanzig laufen im Bogen auf
    /// eine grosse rote Einundzwanzig zu, die in einem Stern explodiert.
    static func drawTwentyOne(_ g: inout GraphicsContext) {
        P.ground(&g, inner: SceneArt.rgb(47, 122, 98), outer: SceneArt.rgb(11, 42, 33), center: CGPoint(x: 150, y: 180))

        P.line(&g, P.path("M30 290 C40 230 70 170 110 132"), P.cream, 2.6, opacity: 0.7, dash: [2, 9])

        P.inked(&g, P.star(CGPoint(x: 170, y: 170), outer: 104, inner: 66, points: 16), P.orange, line: 3)
        g.fill(P.star(CGPoint(x: 170, y: 170), outer: 74, inner: 50, points: 16), with: .color(P.yellow))

        // Die 21 mit Schatten und dunkler Kontur – die Kontur als Ring aus
        // versetzten Kopien, weil Text auf der Leinwand keinen Strich kennt
        let mitte = CGPoint(x: 170, y: 166)
        P.letter(&g, "21", at: CGPoint(x: mitte.x + 6, y: mitte.y + 6), size: 104, color: Color.black.opacity(0.3))
        for k in 0..<12 {
            let w = Double(k) * .pi / 6
            P.letter(&g, "21", at: CGPoint(x: mitte.x + 3 * CGFloat(cos(w)), y: mitte.y + 3 * CGFloat(sin(w))), size: 104, color: P.ink)
        }
        P.letter(&g, "21", at: mitte, size: 104, color: SceneArt.rgb(198, 56, 28))

        let kaertchen: [(CGFloat, CGFloat, String, Double, CGFloat)] = [
            (44, 248, "18", -16, 0.75), (62, 196, "19", -10, 0.85), (92, 146, "20", -4, 0.95)
        ]
        for (x, y, zahl, grad, s) in kaertchen {
            var k = turned(g, grad, around: CGPoint(x: x, y: y))
            k.translateBy(x: x, y: y)
            k.scaleBy(x: s, y: s)
            k.fill(P.box(-18, -23, 44, 56, corner: 6), with: .color(Color.black.opacity(0.3)))
            P.inked(&k, P.box(-22, -28, 44, 56, corner: 6), P.cream, line: 2.6)
            P.letter(&k, zahl, at: .zero, size: 26, color: P.ink)
        }

        P.sparkle(&g, CGPoint(x: 254, y: 50), 9)
        P.sparkle(&g, CGPoint(x: 276, y: 256), 6, color: P.cream)
        P.sparkle(&g, CGPoint(x: 40, y: 50), 6)
    }
}
