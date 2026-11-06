//
//  CoverArtCards.swift
//  BeerStats
//
//  Die Cover der Gruppe "Mit Karten" (ausser Ring of Fire, der steht in
//  `CoverArt.swift`). Vom Nutzer am 6. November in der Vorschau abgenommen:
//  "die cover sind gut". Die Zahlen sind die der Vorschau – wer hier etwas
//  aendert, aendert das Bild, das abgenommen wurde.
//

import SwiftUI

extension CoverArt {

    private typealias P = PosterInk

    // MARK: - Pferderennen

    private static let horseHead = P.path("M20 110 C18 80 22 55 35 38 L40 20 L46 4 L52 22 C64 26 76 34 86 48 C94 58 98 66 94 72 C90 78 80 78 74 74 C66 70 60 72 56 78 C52 88 58 100 64 110 Z")
    private static let horseMane = P.path("M20 110 L10 100 L18 94 L8 84 L17 78 L9 66 L19 62 L13 50 L24 48 L22 36 L33 38 C25 55 20 80 20 110 Z")

    /// Ein Pferdekopf springt aus dem Pik-Ass, die Bahn laeuft zum Horizont,
    /// rechts weht die Zielflagge.
    static func drawRaceAce(_ g: inout GraphicsContext) {
        P.ground(&g, inner: SceneArt.rgb(63, 143, 74), outer: SceneArt.rgb(14, 53, 25), center: CGPoint(x: 150, y: 160))

        // Die Bahn und ihre Linien zum Horizont
        g.fill(P.path("M-20 296 L110 120 L190 120 L320 296 Z"), with: .color(SceneArt.rgb(122, 74, 36).opacity(0.55)))
        var linien = Path()
        let fuesse: [CGFloat] = [-20, 60, 140, 220, 320]
        for x in fuesse {
            let oben = 110 + (x + 20) / 340 * 80
            linien.move(to: CGPoint(x: x, y: 296))
            linien.addLine(to: CGPoint(x: oben, y: 120))
        }
        P.line(&g, linien, P.cream, 2, opacity: 0.55)

        // Zielflagge, kariert
        P.line(&g, P.path("M246 30 L246 128"), P.ink, 4)
        for reihe in 0..<3 {
            for spalte in 0..<4 {
                let feld = P.box(CGFloat(248 + spalte * 10), CGFloat(32 + reihe * 9 + (spalte % 2) * 2), 10, 9)
                g.fill(feld, with: .color((reihe + spalte) % 2 == 1 ? P.ink : P.cream))
            }
        }
        g.stroke(P.box(248, 32, 40, 29), with: .color(P.ink), lineWidth: 2)

        // Das Pik-Ass, gekippt
        var karte = g
        karte.translateBy(x: 96, y: 200)
        karte.rotate(by: .degrees(-10))
        karte.translateBy(x: -96, y: -200)
        karte.fill(P.box(45, 135, 112, 152, corner: 10), with: .color(Color.black.opacity(0.3)))
        P.inked(&karte, P.box(40, 128, 112, 152, corner: 10), P.cream, line: 3)
        P.line(&karte, P.box(48, 136, 96, 136, corner: 6), P.ink, 1.2, opacity: 0.45)
        P.letter(&karte, "A", at: CGPoint(x: 61, y: 151), size: 22, color: P.ink)
        karte.fill(P.suit(P.spade, at: CGPoint(x: 96, y: 214), scale: 1.15), with: .color(P.ink))

        // Staub, wo das Pferd die Karte verlaesst
        g.fill(P.circle(CGPoint(x: 150, y: 172), 10), with: .color(P.cream.opacity(0.5)))
        g.fill(P.circle(CGPoint(x: 166, y: 160), 7), with: .color(P.cream.opacity(0.4)))
        g.fill(P.circle(CGPoint(x: 140, y: 186), 6), with: .color(P.cream.opacity(0.35)))

        // Der Pferdekopf
        var pferd = g
        pferd.translateBy(x: 92, y: 34)
        pferd.scaleBy(x: 1.42, y: 1.42)
        pferd.fill(horseHead.offsetBy(dx: 4, dy: 5), with: .color(Color.black.opacity(0.3)))
        P.inked(&pferd, horseMane, P.cream, line: 2)
        P.inked(&pferd, horseHead, SceneArt.rgb(196, 97, 42))
        P.line(&pferd, P.path("M60 30 C70 34 80 42 86 50"), SceneArt.rgb(232, 137, 74), 5, opacity: 0.9)
        pferd.fill(P.circle(CGPoint(x: 62, y: 44), 3.4), with: .color(P.ink))
        pferd.fill(P.ellipse(88, 66, 2.6, 1.8), with: .color(P.ink))

        P.sparkle(&g, CGPoint(x: 40, y: 50), 8)
        P.sparkle(&g, CGPoint(x: 214, y: 96), 5)
        P.sparkle(&g, CGPoint(x: 270, y: 214), 7)
    }

    // MARK: - Bussfahrer

    /// Ein Nachtbus kommt frontal mit Lichtkegeln, auf der Zielanzeige
    /// stehen die vier Kartenfarben, hinter der Scheibe klemmt ein Koenig.
    static func drawNightBus(_ g: inout GraphicsContext) {
        let tuerkis = SceneArt.rgb(31, 138, 138)
        P.ground(&g, inner: SceneArt.rgb(44, 58, 122), outer: SceneArt.rgb(8, 13, 38), center: CGPoint(x: 150, y: 120))

        // Mond
        g.fill(P.circle(CGPoint(x: 52, y: 46), 20), with: .color(P.cream))
        g.fill(P.circle(CGPoint(x: 62, y: 40), 18), with: .color(SceneArt.rgb(20, 29, 74)))

        // Strasse und Mittellinie
        g.fill(P.path("M40 296 L128 196 L172 196 L260 296 Z"), with: .color(SceneArt.rgb(20, 22, 38)))
        P.line(&g, P.path("M150 204 L150 214 M150 226 L150 242 M150 258 L150 282"), P.orange, 5)

        // Lichtkegel kommen auf den Betrachter zu
        g.fill(P.path("M106 196 L10 296 L120 296 Z"), with: .color(P.yellow.opacity(0.22)))
        g.fill(P.path("M194 196 L180 296 L290 296 Z"), with: .color(P.yellow.opacity(0.22)))

        // Spiegel
        P.line(&g, P.path("M66 74 L54 74 L54 104"), P.ink, 3)
        P.line(&g, P.path("M234 74 L246 74 L246 104"), P.ink, 3)
        P.inked(&g, P.box(46, 98, 14, 22, corner: 3), tuerkis, line: 2)
        P.inked(&g, P.box(240, 98, 14, 22, corner: 3), tuerkis, line: 2)

        // Der Bus
        g.fill(P.box(75, 62, 160, 150, corner: 22), with: .color(Color.black.opacity(0.3)))
        P.inked(&g, P.box(70, 56, 160, 150, corner: 22), tuerkis, line: 3)

        // Zielanzeige mit den vier Farben
        P.inked(&g, P.box(90, 64, 120, 24, corner: 4), SceneArt.rgb(18, 12, 6), line: 2)
        let farben = [P.spade, P.heart, P.diamond, P.club]
        for (k, form) in farben.enumerated() {
            g.fill(P.suit(form, at: CGPoint(x: 123 + CGFloat(k) * 18, y: 76), scale: 0.26), with: .color(P.orange))
        }

        // Scheibe mit Spiegelung und dem Koenig dahinter
        P.inked(&g, P.box(84, 96, 132, 58, corner: 8), SceneArt.rgb(22, 36, 79), line: 2.6)
        g.fill(P.path("M96 150 L130 100 L146 100 L112 150 Z M128 150 L160 104 L168 104 L136 150 Z"), with: .color(P.cream.opacity(0.18)))
        var koenig = g
        koenig.translateBy(x: 191, y: 130)
        koenig.rotate(by: .degrees(8))
        koenig.translateBy(x: -191, y: -130)
        P.inked(&koenig, P.box(178, 112, 26, 36, corner: 3), P.cream, line: 1.6)
        P.letter(&koenig, "K", at: CGPoint(x: 191, y: 130), size: 16, color: SceneArt.rgb(198, 56, 28))

        // Kuehlergrill
        P.inked(&g, P.box(120, 166, 60, 22, corner: 4), SceneArt.rgb(20, 82, 79), line: 2)
        P.line(&g, P.path("M126 172 L174 172 M126 177 L174 177 M126 182 L174 182"), P.ink, 1.6, opacity: 0.6)

        // Scheinwerfer mit Schein
        for x: CGFloat in [98, 202] {
            let mitte = CGPoint(x: x, y: 178)
            g.fill(P.circle(mitte, 26), with: .radialGradient(
                Gradient(colors: [P.yellow.opacity(0.9), P.yellow.opacity(0)]),
                center: mitte, startRadius: 0, endRadius: 26))
            P.inked(&g, P.circle(mitte, 12), SceneArt.rgb(255, 251, 232))
        }

        // Stossstange und Raeder
        P.inked(&g, P.box(66, 198, 168, 14, corner: 5), SceneArt.rgb(38, 48, 63))
        g.fill(P.box(80, 210, 26, 16, corner: 4), with: .color(SceneArt.rgb(12, 15, 25)))
        g.fill(P.box(194, 210, 26, 16, corner: 4), with: .color(SceneArt.rgb(12, 15, 25)))

        let funken: [(CGFloat, CGFloat, CGFloat)] = [(244, 40, 7), (272, 120, 4), (26, 140, 4), (208, 30, 4)]
        for (x, y, r) in funken {
            P.sparkle(&g, CGPoint(x: x, y: y), r, color: P.cream)
        }
    }

    // MARK: - Wahrheit oder Pflicht

    private static let speechBubble = P.path("M30 52 Q30 30 54 30 L132 30 Q156 30 156 52 L156 104 Q156 126 132 126 L80 126 L52 150 L60 126 L54 126 Q30 126 30 104 Z")

    /// Diagonal geteilt: links die Sprechblase mit Fragezeichen auf Blau,
    /// rechts das Ausrufezeichen im Zackenstern auf Rot, dazwischen ein Blitz.
    static func drawSplitBolt(_ g: inout GraphicsContext) {
        let alles = CGRect(x: 0, y: 0, width: width, height: height)
        g.fill(Path(alles), with: .linearGradient(
            Gradient(colors: [SceneArt.rgb(226, 74, 44), SceneArt.rgb(122, 20, 8)]),
            startPoint: .zero, endPoint: CGPoint(x: width, y: height)))
        g.fill(P.path("M0 0 L300 0 L300 40 L0 296 Z"), with: .linearGradient(
            Gradient(colors: [SceneArt.rgb(58, 92, 200), SceneArt.rgb(19, 42, 112)]),
            startPoint: .zero, endPoint: CGPoint(x: 300, y: 296)))
        P.dots(&g, width: width, until: height - 74, opacity: 0.1)

        P.inked(&g, P.path("M300 40 L214 112 L230 120 L146 186 L164 192 L60 260 L120 214 L104 208 L176 150 L160 144 Z"), P.yellow, line: 2.6)

        P.dropShadow(&g, speechBubble)
        P.inked(&g, speechBubble, P.cream, line: 3)
        P.letter(&g, "?", at: CGPoint(x: 93, y: 80), size: 84, color: SceneArt.rgb(35, 70, 168))

        let zacken = P.star(CGPoint(x: 212, y: 212), outer: 66, inner: 46, points: 12)
        P.dropShadow(&g, zacken)
        P.inked(&g, zacken, P.yellow, line: 3)
        P.inked(&g, P.circle(CGPoint(x: 212, y: 212), 36), P.orange)
        P.letter(&g, "!", at: CGPoint(x: 212, y: 214), size: 72, color: SceneArt.rgb(179, 32, 15))

        P.sparkle(&g, CGPoint(x: 246, y: 64), 8, color: P.cream)
        P.sparkle(&g, CGPoint(x: 40, y: 236), 7)
        P.sparkle(&g, CGPoint(x: 122, y: 262), 5)
        P.sparkle(&g, CGPoint(x: 176, y: 40), 5, color: P.cream)
    }

    // MARK: - Ich hab noch nie

    /// Die Hand als ein Zug: drei Finger hoch, der kleine eingeknickt,
    /// der Daumen zur Seite. Die Fingerkuppen sind Halbkreise.
    private static let neonHandPath: Path = {
        var p = Path()
        func kuppe(_ mitteX: CGFloat, _ y: CGFloat, _ r: CGFloat) {
            p.addArc(center: CGPoint(x: mitteX, y: y), radius: r,
                     startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        }
        p.move(to: CGPoint(x: 98, y: 150))
        p.addLine(to: CGPoint(x: 98, y: 86)); kuppe(110, 86, 12)
        p.addLine(to: CGPoint(x: 122, y: 150)); p.addLine(to: CGPoint(x: 126, y: 150))
        p.addLine(to: CGPoint(x: 126, y: 74)); kuppe(138, 74, 12)
        p.addLine(to: CGPoint(x: 150, y: 150)); p.addLine(to: CGPoint(x: 154, y: 150))
        p.addLine(to: CGPoint(x: 154, y: 88)); kuppe(166, 88, 12)
        p.addLine(to: CGPoint(x: 178, y: 150)); p.addLine(to: CGPoint(x: 182, y: 150))
        p.addLine(to: CGPoint(x: 182, y: 140)); kuppe(193, 140, 11)
        p.addLine(to: CGPoint(x: 204, y: 214))
        p.addArc(center: CGPoint(x: 178, y: 214), radius: 26, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: 122, y: 240))
        p.addArc(center: CGPoint(x: 122, y: 214), radius: 26, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: 96, y: 202))
        p.addLine(to: CGPoint(x: 66, y: 172))
        p.addQuadCurve(to: CGPoint(x: 80, y: 156), control: CGPoint(x: 62, y: 156))
        p.addLine(to: CGPoint(x: 98, y: 174))
        p.closeSubpath()
        return p
    }()

    /// Eine Neonroehre: drei Lagen Schein und ein weisser Kern.
    private static func neon(_ g: inout GraphicsContext, _ path: Path, _ farbe: Color) {
        P.line(&g, path, farbe, 16, opacity: 0.14)
        P.line(&g, path, farbe, 9, opacity: 0.3)
        P.line(&g, path, farbe, 4.5)
        P.line(&g, path, .white, 1.6, opacity: 0.9)
    }

    /// Eine pinke Neonhand auf dunklem Backstein, ein blauer Rahmen in den
    /// Ecken.
    static func drawNeonHand(_ g: inout GraphicsContext) {
        let pink = SceneArt.rgb(255, 79, 163)
        let blau = SceneArt.rgb(62, 232, 255)
        P.ground(&g, inner: SceneArt.rgb(58, 26, 46), outer: SceneArt.rgb(16, 7, 16), center: CGPoint(x: 150, y: 180))
        g.fill(P.box(0, 0, width, height - 74), with: .color(SceneArt.rgb(42, 20, 32).opacity(0.55)))

        // Backstein, Reihen gegeneinander versetzt
        var fugen = Path()
        for reihe in 0..<15 {
            let y = CGFloat(reihe * 20)
            fugen.move(to: CGPoint(x: 0, y: y))
            fugen.addLine(to: CGPoint(x: width, y: y))
            var x: CGFloat = reihe % 2 == 1 ? 0 : -22
            while x < width {
                fugen.move(to: CGPoint(x: x, y: y))
                fugen.addLine(to: CGPoint(x: x, y: y + 20))
                x += 44
            }
        }
        g.stroke(fugen, with: .color(Color.black.opacity(0.35)), lineWidth: 2)

        P.line(&g, P.path("M150 240 C150 262 210 262 216 296"), SceneArt.rgb(26, 16, 22), 3)
        neon(&g, P.path("M40 56 L40 34 L64 34 M236 34 L260 34 L260 56 M260 236 L260 262 L236 262 M64 262 L40 262 L40 236"), blau)
        neon(&g, neonHandPath, pink)
        neon(&g, P.path("M184 150 Q193 160 202 150"), pink)

        // Halter, die die Roehren an der Wand halten
        let halter: [(CGFloat, CGFloat)] = [(98, 120), (150, 100), (178, 120), (120, 240), (190, 228)]
        for (x, y) in halter {
            g.fill(P.box(x - 4, y - 3, 8, 6, corner: 1.5), with: .color(SceneArt.rgb(85, 68, 77)))
        }

        P.sparkle(&g, CGPoint(x: 64, y: 120), 6, color: SceneArt.rgb(255, 156, 205))
        P.sparkle(&g, CGPoint(x: 238, y: 92), 7, color: SceneArt.rgb(157, 243, 255))
        P.sparkle(&g, CGPoint(x: 230, y: 196), 4, color: SceneArt.rgb(255, 156, 205))
    }

    // MARK: - Hitparade

    private static let noteStem = P.path("M7 -1 L7 -34 C14 -30 20 -26 18 -16")

    private static func note(_ g: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ farbe: Color) {
        var n = g
        n.translateBy(x: x, y: y)
        n.scaleBy(x: s, y: s)
        n.rotate(by: .degrees(-12))
        P.inked(&n, P.ellipse(0, 0, 8, 6), farbe, line: 2)
        P.line(&n, noteStem, P.ink, 3)
    }

    /// Eine Schallplatte rutscht vor einem Strahlenkranz aus ihrer
    /// gestreiften Huelle, ein Tonarm liegt auf, Noten fliegen heraus.
    static func drawVinyl(_ g: inout GraphicsContext) {
        let mitte = CGPoint(x: 186, y: 150)
        let rot = SceneArt.rgb(226, 85, 58)
        P.ground(&g, inner: SceneArt.rgb(31, 111, 131), outer: SceneArt.rgb(8, 31, 41), center: CGPoint(x: 186, y: 168))

        // Strahlenkranz, abwechselnd kraeftiger und leiser
        var kraeftig = Path(), leise = Path()
        for k in 0..<24 {
            let a = P.point(mitte, 260, Double(k) * 15), b = P.point(mitte, 260, Double(k) * 15 + 7.5)
            var strahl = Path()
            strahl.move(to: mitte); strahl.addLine(to: a); strahl.addLine(to: b); strahl.closeSubpath()
            if k % 2 == 0 { kraeftig.addPath(strahl) } else { leise.addPath(strahl) }
        }
        g.fill(kraeftig, with: .color(P.orange.opacity(0.2)))
        g.fill(leise, with: .color(P.orange.opacity(0.1)))

        // Die Huelle zuerst – die Platte liegt darueber und rutscht heraus
        let huelle = P.box(-6, 80, 130, 170)
        P.dropShadow(&g, huelle)
        g.fill(huelle, with: .color(P.cream))
        for k in 0..<6 {
            g.fill(P.box(CGFloat(-6 + k * 22), 80, 11, 170), with: .color((k % 2 == 1 ? P.orange : rot).opacity(0.85)))
        }
        g.stroke(huelle, with: .color(P.ink), lineWidth: 3)

        // Die Platte mit Rillen, Glanz und Etikett
        g.fill(P.circle(CGPoint(x: mitte.x + 5, y: mitte.y + 6), 108), with: .color(Color.black.opacity(0.35)))
        P.inked(&g, P.circle(mitte, 108), SceneArt.rgb(20, 20, 20), line: 3)
        var rillen = Path()
        for r in stride(from: CGFloat(46), to: 104, by: 7) { rillen.addPath(P.circle(mitte, r)) }
        g.stroke(rillen, with: .color(SceneArt.rgb(58, 58, 58)), lineWidth: 1.3)
        var glanz = Path()
        glanz.addArc(center: mitte, radius: 84, startAngle: .degrees(220), endAngle: .degrees(270), clockwise: false)
        P.line(&g, glanz, P.cream, 5, opacity: 0.25)
        var glanz2 = Path()
        glanz2.addArc(center: mitte, radius: 84, startAngle: .degrees(40), endAngle: .degrees(73), clockwise: false)
        P.line(&g, glanz2, P.cream, 4, opacity: 0.18)
        P.inked(&g, P.circle(mitte, 36), rot)
        g.stroke(P.circle(mitte, 24), with: .color(P.cream.opacity(0.7)), lineWidth: 2)
        g.fill(P.star(mitte, outer: 14, inner: 6, points: 5), with: .color(P.yellow))
        g.fill(P.circle(mitte, 4), with: .color(P.ink))

        // Tonarm
        let silber = SceneArt.rgb(201, 194, 180)
        P.inked(&g, P.circle(CGPoint(x: 266, y: 44), 14), silber)
        let arm = P.path("M266 44 L238 128 L220 136")
        P.line(&g, arm, P.ink, 7)
        P.line(&g, arm, SceneArt.rgb(232, 225, 210), 3.6)
        var kopf = g
        kopf.translateBy(x: 217, y: 136)
        kopf.rotate(by: .degrees(-20))
        kopf.translateBy(x: -217, y: -136)
        P.inked(&kopf, P.box(208, 130, 18, 12, corner: 2), silber, line: 2)

        note(&g, 66, 60, 1.1, P.yellow)
        note(&g, 110, 40, 0.8, P.cream)
        note(&g, 42, 286, 0.9, P.cream)
        note(&g, 250, 250, 1, P.yellow)

        P.sparkle(&g, CGPoint(x: 150, y: 30), 7)
        P.sparkle(&g, CGPoint(x: 278, y: 170), 5, color: P.cream)
    }
}
