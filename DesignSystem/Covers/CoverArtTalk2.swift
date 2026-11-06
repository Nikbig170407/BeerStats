//
//  CoverArtTalk2.swift
//  BeerStats
//
//  Die Cover der Gruppe "Raten & reden", zweite Haelfte, samt dem neuen
//  "Wer bin ich?". Vom Nutzer am 6. November abgenommen – bis auf den
//  Schaetzmeister, der noch einmal ueberarbeitet wird. Die Zahlen sind die
//  der Vorschau.
//

import SwiftUI

extension CoverArt {

    private typealias P = PosterInk

    private static let skin = SceneArt.rgb(226, 160, 106)
    private static let posterBlue = SceneArt.rgb(58, 111, 224)
    private static let posterRed = SceneArt.rgb(216, 52, 42)
    private static let posterGreen = SceneArt.rgb(63, 191, 106)

    /// Eine Pfeilspitze, die bei 0 Grad nach rechts zeigt.
    private static func arrowHead(_ g: inout GraphicsContext, at spitze: CGPoint, degrees: Double, _ farbe: Color) {
        var k = g
        k.translateBy(x: spitze.x, y: spitze.y)
        k.rotate(by: .degrees(degrees))
        P.inked(&k, P.path("M0 -11 L14 0 L0 11 Z"), farbe)
    }

    // MARK: - Wer bin ich?

    /// Ein Handy zeigt eine verdeckte Gestalt mit Zylinder hinter einem
    /// Fragezeichen, ein gruener Pfeil kippt nach unten, ein oranger nach
    /// oben, daneben tickt eine Stoppuhr.
    static func drawPhoneGuess(_ g: inout GraphicsContext) {
        P.ground(&g, inner: SceneArt.rgb(74, 47, 143), outer: SceneArt.rgb(18, 10, 44), center: CGPoint(x: 150, y: 160))

        // Kippen heisst: unten richtig, oben weiter
        let runter = P.path("M232 128 Q270 176 240 230")
        P.line(&g, runter, P.ink, 9)
        P.line(&g, runter, posterGreen, 5)
        arrowHead(&g, at: CGPoint(x: 240, y: 232), degrees: 110, posterGreen)
        let hoch = P.path("M58 246 Q24 200 50 150")
        P.line(&g, hoch, P.ink, 9)
        P.line(&g, hoch, P.orange, 5)
        arrowHead(&g, at: CGPoint(x: 50, y: 148), degrees: -65, P.orange)

        // Das Handy, gekippt
        var handy = g
        handy.translateBy(x: 140, y: 172)
        handy.rotate(by: .degrees(-12))
        handy.translateBy(x: -140, y: -172)
        handy.fill(P.box(84, 76, 124, 210, corner: 18), with: .color(Color.black.opacity(0.3)))
        P.inked(&handy, P.box(78, 70, 124, 210, corner: 18), SceneArt.rgb(29, 29, 36), line: 3)
        handy.fill(P.box(88, 88, 104, 172, corner: 8), with: .linearGradient(
            Gradient(colors: [P.orange, SceneArt.rgb(226, 85, 58)]),
            startPoint: CGPoint(x: 0, y: 88), endPoint: CGPoint(x: 0, y: 260)))
        handy.fill(P.box(124, 77, 32, 5, corner: 2.5), with: .color(SceneArt.rgb(58, 58, 68)))
        // Die Gestalt mit Zylinder, nur als Schatten
        var gestalt = P.box(124, 118, 32, 30, corner: 2)
        gestalt.addPath(P.box(112, 146, 56, 8, corner: 3))
        gestalt.addPath(P.circle(CGPoint(x: 140, y: 176), 20))
        gestalt.addPath(P.path("M100 252 Q140 190 180 252 Z"))
        handy.fill(gestalt, with: .color(SceneArt.rgb(58, 20, 8).opacity(0.5)))
        P.letter(&handy, "?", at: CGPoint(x: 146, y: 179), size: 96, color: Color.black.opacity(0.3))
        P.outlinedLetter(&handy, "?", at: CGPoint(x: 140, y: 173), size: 96, color: P.cream)

        // Die Stoppuhr
        P.inked(&g, P.box(229, 28, 14, 12, corner: 3), SceneArt.rgb(201, 194, 180), line: 2)
        let mitte = CGPoint(x: 236, y: 72)
        g.fill(P.circle(CGPoint(x: 240, y: 77), 32), with: .color(Color.black.opacity(0.3)))
        P.inked(&g, P.circle(mitte, 32), P.cream, line: 3)
        var abgelaufen = Path()
        abgelaufen.move(to: mitte)
        abgelaufen.addLine(to: CGPoint(x: 236, y: 40))
        abgelaufen.addArc(center: mitte, radius: 32, startAngle: .degrees(270), endAngle: .degrees(341.6), clockwise: false)
        abgelaufen.closeSubpath()
        g.fill(abgelaufen, with: .color(posterRed.opacity(0.85)))
        var striche = Path()
        for k in 0..<12 {
            striche.move(to: P.point(mitte, 26, Double(k) * 30))
            striche.addLine(to: P.point(mitte, 31, Double(k) * 30))
        }
        g.stroke(striche, with: .color(P.ink), lineWidth: 2)
        P.line(&g, P.path("M236 72 L250 58"), P.ink, 3.4)
        g.fill(P.circle(mitte, 4), with: .color(P.ink))

        P.sparkle(&g, CGPoint(x: 46, y: 54), 8)
        P.sparkle(&g, CGPoint(x: 276, y: 270), 6, color: P.cream)
        P.sparkle(&g, CGPoint(x: 30, y: 110), 4, color: P.cream)
    }

    // MARK: - Kategorien

    private static let hourglassGlass = P.path("M74 66 C74 120 104 140 108 164 C104 188 74 208 74 262 L146 262 C146 208 116 188 112 164 C116 140 146 120 146 66 Z")

    /// Eine Sanduhr laeuft, daneben faechern sich drei Karten mit Apfel,
    /// Auto und Stern auf.
    static func drawHourglass(_ g: inout GraphicsContext) {
        let sand = SceneArt.rgb(242, 196, 106)
        let holz = SceneArt.rgb(122, 74, 36)
        P.ground(&g, inner: SceneArt.rgb(201, 130, 47), outer: SceneArt.rgb(58, 29, 8), center: CGPoint(x: 120, y: 160))

        g.fill(P.box(70, 64, 100, 216), with: .color(Color.black.opacity(0.3)))
        g.fill(hourglassGlass, with: .color(SceneArt.rgb(232, 244, 246).opacity(0.3)))
        P.inked(&g, P.path("M82 96 C84 126 104 144 110 160 C116 144 136 126 138 96 Z"), sand, line: 1.6)
        P.line(&g, P.path("M110 160 L110 248"), sand, 2.4)
        P.inked(&g, P.path("M78 262 Q110 222 142 262 Z"), sand, line: 1.6)
        g.stroke(hourglassGlass, with: .color(P.ink), lineWidth: 2.6)
        P.line(&g, P.path("M84 80 C86 112 98 128 104 140"), .white, 3, opacity: 0.6)
        let pfosten = P.path("M66 66 L66 262 M154 66 L154 262")
        P.line(&g, pfosten, P.ink, 9)
        P.line(&g, pfosten, SceneArt.rgb(154, 98, 52), 5)
        P.inked(&g, P.box(56, 52, 108, 16, corner: 5), holz, line: 2.6)
        P.inked(&g, P.box(56, 260, 108, 16, corner: 5), holz, line: 2.6)

        categoryCard(&g, CGPoint(x: 190, y: 174), -16) { k, x, y in
            P.inked(&k, P.circle(CGPoint(x: x, y: y + 4), 15), posterRed, line: 2)
            P.line(&k, P.path("M\(x) \(y - 10) L\(x + 2) \(y - 18)"), P.ink, 2.4)
            P.inked(&k, P.path("M\(x + 3) \(y - 14) Q\(x + 14) \(y - 22) \(x + 16) \(y - 12) Q\(x + 8) \(y - 8) \(x + 3) \(y - 14) Z"), posterGreen, line: 1.4)
        }
        categoryCard(&g, CGPoint(x: 226, y: 146), 0) { k, x, y in
            P.inked(&k, P.box(x - 10, y - 10, 20, 10, corner: 3), posterBlue, line: 1.8)
            P.inked(&k, P.box(x - 18, y - 2, 36, 12, corner: 4), posterBlue, line: 2)
            k.fill(P.circle(CGPoint(x: x - 9, y: y + 11), 4.5), with: .color(P.ink))
            k.fill(P.circle(CGPoint(x: x + 9, y: y + 11), 4.5), with: .color(P.ink))
        }
        categoryCard(&g, CGPoint(x: 262, y: 178), 16) { k, x, y in
            P.inked(&k, P.star(CGPoint(x: x, y: y), outer: 17, inner: 7.5, points: 5), P.yellow, line: 2)
        }

        P.sparkle(&g, CGPoint(x: 222, y: 60), 9)
        P.sparkle(&g, CGPoint(x: 272, y: 100), 5, color: P.cream)
        P.sparkle(&g, CGPoint(x: 30, y: 160), 5)
    }

    private static func categoryCard(
        _ g: inout GraphicsContext,
        _ mitte: CGPoint,
        _ grad: Double,
        motif: (inout GraphicsContext, CGFloat, CGFloat) -> Void
    ) {
        var k = g
        k.translateBy(x: mitte.x, y: mitte.y)
        k.rotate(by: .degrees(grad))
        k.translateBy(x: -mitte.x, y: -mitte.y)
        k.fill(P.box(mitte.x - 23, mitte.y - 33, 54, 76, corner: 6), with: .color(Color.black.opacity(0.3)))
        P.inked(&k, P.box(mitte.x - 27, mitte.y - 38, 54, 76, corner: 6), P.cream)
        motif(&k, mitte.x, mitte.y)
    }

    // MARK: - Wer wuerde eher?

    /// Aus allen Richtungen zeigen sechs Haende mit ausgestrecktem Finger
    /// auf eine leuchtende Gestalt in der Mitte.
    static func drawPointingHands(_ g: inout GraphicsContext) {
        let mitte = CGPoint(x: 150, y: 150)
        P.ground(&g, inner: SceneArt.rgb(138, 31, 92), outer: SceneArt.rgb(42, 8, 32), center: CGPoint(x: 150, y: 180))

        var strahlen = Path()
        for k in 0..<20 {
            strahlen.addPath(P.wedge(mitte, 300, from: Double(k) * 18, to: Double(k) * 18 + 9))
        }
        g.fill(strahlen, with: .color(SceneArt.rgb(255, 122, 184).opacity(0.12)))

        g.fill(P.circle(mitte, 70), with: .radialGradient(
            Gradient(colors: [P.yellow.opacity(0.8), P.yellow.opacity(0)]),
            center: mitte, startRadius: 0, endRadius: 70))
        P.inked(&g, P.circle(mitte, 40), P.cream, line: 3)
        g.fill(P.circle(CGPoint(x: 150, y: 140), 12), with: .color(posterRed))
        g.fill(P.path("M128 174 Q150 146 172 174 Z"), with: .color(posterRed))

        for grad: Double in [0, 180, 38, 142, -38, -142] {
            let r = grad * .pi / 180
            var hand = g
            hand.translateBy(x: mitte.x - CGFloat(cos(r)) * 108, y: mitte.y - CGFloat(sin(r)) * 108)
            hand.rotate(by: .degrees(grad))
            P.inked(&hand, P.box(-62, -15, 18, 30, corner: 3), posterBlue, line: 2.2)
            P.inked(&hand, P.box(-46, -17, 38, 34, corner: 13), skin)
            P.inked(&hand, P.box(-14, -15, 44, 12, corner: 6), skin)
            P.inked(&hand, P.box(-30, -24, 20, 11, corner: 5.5), skin, line: 2.2)
            P.line(&hand, P.path("M-34 0 L-14 0 M-34 8 L-16 8"), P.ink, 1.6, opacity: 0.5)
        }

        P.sparkle(&g, CGPoint(x: 150, y: 40), 8)
        P.sparkle(&g, CGPoint(x: 150, y: 262), 6, color: P.cream)
        P.sparkle(&g, CGPoint(x: 274, y: 80), 4, color: P.cream)
    }

    // MARK: - Kennst du deine Leute?

    /// Zwei Quartettkarten mit Balken stehen sich schraeg gegenueber,
    /// zwischen ihnen knallt ein gelber Stern mit VS.
    static func drawStatCards(_ g: inout GraphicsContext) {
        P.ground(&g, inner: SceneArt.rgb(44, 111, 176), outer: SceneArt.rgb(10, 31, 58), center: CGPoint(x: 150, y: 180))
        statCard(&g, x: 26, grad: -9, farbe: posterRed, balken: [0.85, 0.4, 0.62])
        statCard(&g, x: 170, grad: 9, farbe: posterBlue, balken: [0.5, 0.92, 0.3])

        let knall = P.star(CGPoint(x: 150, y: 158), outer: 36, inner: 25, points: 14)
        P.dropShadow(&g, knall, dx: 4, dy: 5)
        P.inked(&g, knall, P.yellow, line: 3)
        P.letter(&g, "VS", at: CGPoint(x: 150, y: 159), size: 24, color: SceneArt.rgb(198, 56, 28))

        P.sparkle(&g, CGPoint(x: 150, y: 40), 8)
        P.sparkle(&g, CGPoint(x: 44, y: 260), 6, color: P.cream)
        P.sparkle(&g, CGPoint(x: 262, y: 262), 6)
    }

    private static func statCard(_ g: inout GraphicsContext, x: CGFloat, grad: Double, farbe: Color, balken: [CGFloat]) {
        let cx = x + 52
        var k = g
        k.translateBy(x: cx, y: 150)
        k.rotate(by: .degrees(grad))
        k.translateBy(x: -cx, y: -150)
        k.fill(P.box(x + 5, 76, 104, 154, corner: 10), with: .color(Color.black.opacity(0.3)))
        P.inked(&k, P.box(x, 70, 104, 154, corner: 10), P.cream, line: 3)
        P.inked(&k, P.box(x + 8, 78, 88, 56, corner: 6), farbe, line: 2)
        P.inked(&k, P.circle(CGPoint(x: cx, y: 100), 13), skin, line: 2)
        P.inked(&k, P.path("M\(cx - 22) 134 Q\(cx) 108 \(cx + 22) 134 Z"), skin, line: 2)
        for (zeile, wert) in balken.enumerated() {
            let y = CGFloat(146 + zeile * 24)
            k.fill(P.box(x + 10, y + 2, 20, 8, corner: 2), with: .color(SceneArt.rgb(139, 127, 108).opacity(0.55)))
            k.fill(P.box(x + 36, y, 58, 12, corner: 3), with: .color(SceneArt.rgb(233, 223, 203)))
            P.inked(&k, P.box(x + 36, y, 58 * wert, 12, corner: 3), farbe, line: 1.4)
        }
    }

    // MARK: - Pantomime

    private static let curtain = P.path("M0 0 L62 0 C46 80 66 170 34 252 L0 252 Z")
    private static let curtainFolds = P.path("M18 0 C12 90 22 170 10 252 M40 0 C30 90 44 170 24 252")
    private static let curtainLight = P.path("M30 6 C24 90 34 170 20 246")

    /// Zwei weisse Handschuhe druecken gegen eine unsichtbare Glaswand
    /// zwischen roten Vorhaengen, unten laeuft ein Filmstreifen.
    static func drawMimeGloves(_ g: inout GraphicsContext) {
        P.ground(&g, inner: SceneArt.rgb(119, 112, 106), outer: SceneArt.rgb(21, 19, 18), center: CGPoint(x: 150, y: 180))

        // Die Glaswand
        let wand = P.box(62, 48, 176, 196)
        g.fill(wand, with: .color(SceneArt.rgb(207, 232, 240).opacity(0.1)))
        g.stroke(wand, with: .color(SceneArt.rgb(207, 232, 240).opacity(0.35)), lineWidth: 2)
        P.line(&g, P.path("M80 70 L120 50 M80 100 L150 60 M190 230 L236 200"), .white, 3, opacity: 0.25)

        glove(&g, CGPoint(x: 112, y: 150), -8)
        glove(&g, CGPoint(x: 190, y: 136), 6)

        // Vorhaenge links und rechts, der rechte gespiegelt
        for gespiegelt in [false, true] {
            var v = g
            if gespiegelt {
                v.translateBy(x: 300, y: 0)
                v.scaleBy(x: -1, y: 1)
            }
            P.inked(&v, curtain, SceneArt.rgb(138, 28, 28), line: 2.6)
            v.stroke(curtainFolds, with: .color(SceneArt.rgb(90, 14, 14)), lineWidth: 4)
            P.line(&v, curtainLight, SceneArt.rgb(192, 66, 58), 3, opacity: 0.7)
        }
        let samt = SceneArt.rgb(106, 18, 18)
        P.inked(&g, P.box(0, 0, 300, 22), samt, line: 2)
        for x in stride(from: CGFloat(0), through: 300, by: 30) {
            P.inked(&g, P.path("M\(x) 20 Q\(x + 15) 38 \(x + 30) 20"), samt, line: 2)
        }

        // Filmstreifen
        g.fill(P.box(0, 252, 300, 38), with: .color(SceneArt.rgb(17, 17, 17)))
        var loecher = Path()
        for x in stride(from: CGFloat(6), to: 300, by: 20) {
            loecher.addPath(P.box(x, 256, 10, 7, corner: 1.5))
            loecher.addPath(P.box(x, 279, 10, 7, corner: 1.5))
        }
        g.fill(loecher, with: .color(P.cream.opacity(0.85)))

        P.sparkle(&g, CGPoint(x: 150, y: 40), 6, color: P.cream)
        P.sparkle(&g, CGPoint(x: 84, y: 226), 5, color: P.cream)
    }

    /// Ein weisser Handschuh, die Handflaeche zur Scheibe.
    private static func glove(_ g: inout GraphicsContext, _ mitte: CGPoint, _ grad: Double) {
        let weiss = SceneArt.rgb(251, 250, 246)
        var h = g
        h.translateBy(x: mitte.x, y: mitte.y)
        h.rotate(by: .degrees(grad))
        h.fill(P.box(-22, -1, 52, 50, corner: 14), with: .color(Color.black.opacity(0.3)))
        let finger: [(CGFloat, CGFloat)] = [(-24, 34), (-11, 42), (2, 40), (15, 32)]
        for (x, laenge) in finger {
            P.inked(&h, P.box(x, -laenge, 11, laenge + 8, corner: 5.5), weiss, line: 2.2)
        }
        P.inked(&h, P.box(-26, -6, 52, 50, corner: 14), weiss)
        var daumen = h
        daumen.translateBy(x: -38, y: 19)
        daumen.rotate(by: .degrees(-35))
        daumen.translateBy(x: 38, y: -19)
        P.inked(&daumen, P.box(-44, 4, 12, 30, corner: 6), weiss, line: 2.2)
        P.inked(&h, P.box(-24, 42, 48, 14, corner: 4), weiss, line: 2.2)
        P.line(&h, P.path("M-12 18 L-12 34 M0 18 L0 34 M12 18 L12 34"), SceneArt.rgb(201, 194, 180), 2)
        P.line(&h, P.path("M-34 -30 L-40 -38 M34 -26 L42 -32 M0 -52 L0 -60"), P.cream, 2.4)
    }

    // MARK: - Die Skala

    /// Eine halbrunde Skala mit bunter Zielzone, die rote Nadel steht kurz
    /// davor, links ein Eiswuerfel, rechts eine Flamme.
    static func drawDial(_ g: inout GraphicsContext) {
        let mitte = CGPoint(x: 150, y: 214)
        let radius: CGFloat = 116
        P.ground(&g, inner: SceneArt.rgb(31, 122, 140), outer: SceneArt.rgb(7, 31, 38), center: CGPoint(x: 150, y: 200))

        var scheibe = Path()
        scheibe.move(to: CGPoint(x: mitte.x - radius, y: mitte.y))
        scheibe.addArc(center: mitte, radius: radius, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        scheibe.closeSubpath()
        P.dropShadow(&g, scheibe)
        P.inked(&g, scheibe, P.cream, line: 3)

        // Die Zielzone: aussen gelb, dann orange, in der Mitte rot
        let zonen: [(Double, Double, Color)] = [
            (0, 9, P.yellow), (9, 17, P.orange), (17, 27, posterRed), (27, 35, P.orange), (35, 44, P.yellow)
        ]
        for (von, bis, farbe) in zonen {
            g.fill(P.wedge(mitte, 110, from: von, to: bis), with: .color(farbe))
        }
        var striche = Path()
        for a in stride(from: -80.0, through: 80, by: 10) {
            striche.move(to: P.point(mitte, radius - 10, a))
            striche.addLine(to: P.point(mitte, radius - 2, a))
        }
        g.stroke(striche, with: .color(P.ink.opacity(0.6)), lineWidth: 2)
        g.stroke(scheibe, with: .color(P.ink), lineWidth: 3)
        P.inked(&g, P.box(24, 212, 252, 24, corner: 6), SceneArt.rgb(58, 42, 28), line: 2.6)

        var nadel = Path()
        nadel.move(to: mitte)
        nadel.addLine(to: P.point(mitte, 120, 12))
        P.line(&g, nadel, P.ink, 10)
        P.line(&g, nadel, posterRed, 5)
        P.inked(&g, P.circle(mitte, 12), P.orange, line: 2.6)

        // Kalt und heiss
        var eis = g
        eis.translateBy(x: 42, y: 120)
        eis.rotate(by: .degrees(-12))
        eis.translateBy(x: -42, y: -120)
        P.inked(&eis, P.box(20, 98, 44, 44, corner: 8), SceneArt.rgb(191, 232, 246), line: 2.6)
        eis.fill(P.path("M28 106 L44 106 L28 122 Z"), with: .color(Color.white.opacity(0.7)))
        P.flame(&g, at: CGPoint(x: 258, y: 118), scale: 0.48, fill: P.orange, outlined: true)
        P.flame(&g, at: CGPoint(x: 258, y: 124), scale: 0.26, fill: P.yellow, outlined: false)

        P.sparkle(&g, CGPoint(x: 150, y: 46), 8)
        P.sparkle(&g, CGPoint(x: 38, y: 262), 5, color: P.cream)
        P.sparkle(&g, CGPoint(x: 266, y: 270), 6)
    }
}
