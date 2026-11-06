//
//  BeerpongPoster.swift
//  BeerStats
//
//  Das Plakat fuer Beerpong: "Der Wurf". Vom Nutzer am 6. November in der
//  Vorschau abgenommen, zusammen mit den Covern von "Mit Karten".
//
//  Quadratisch und ohne Titelbalken, weil es an zwei Stellen steht, die
//  beide keinen haben: oben im Hauptmenue im Beerpong-Kasten und als
//  App-Icon. Das Icon ist dieselbe Zeichnung, als Bild gerechnet
//  (`scripts/make_app_icon.js`) – wer hier etwas aendert, rechnet das Icon
//  neu, sonst sieht die App anders aus als ihr Symbol.
//

import SwiftUI

enum BeerpongPoster {

    /// Gezeichnet wird in diesem Quadrat.
    static let side: CGFloat = 300

    /// Was zu sehen ist, in einem Satz (dieselbe Regel wie bei den Covern).
    static let sentence = "Schräg über den Tisch: hinten ein Dreieck aus roten Bechern mit Bier, vorn die eigenen Becher, dazwischen fliegt der Ball im Bogen."

    private typealias P = PosterInk

    private static let red = SceneArt.rgb(216, 52, 42)
    private static let redLight = SceneArt.rgb(242, 102, 74)

    static func draw(_ g: inout GraphicsContext, _ size: CGSize) {
        var bild = g
        bild.scaleBy(x: size.width / side, y: size.height / side)
        drawThrow(&bild)
    }

    private static func drawThrow(_ g: inout GraphicsContext) {
        let quadrat = CGSize(width: side, height: side)
        P.ground(&g, inner: SceneArt.rgb(49, 80, 184), outer: SceneArt.rgb(12, 24, 68),
                 center: CGPoint(x: 150, y: 152), size: quadrat, dotsUntil: side)

        // Der Tisch in Fluchtperspektive, vorn reicht er aus dem Bild
        P.inked(&g, P.path("M-40 300 L62 128 L238 128 L340 300 Z"), SceneArt.rgb(20, 86, 63), line: 3)
        P.line(&g, P.path("M-22 300 L70 140 L230 140 L322 300"), P.cream, 2.4, opacity: 0.85)
        P.line(&g, P.path("M150 210 L150 300"), P.cream, 2, opacity: 0.55, dash: [9, 7])
        g.fill(P.path("M62 128 L238 128 L240 137 L60 137 Z"), with: .color(SceneArt.rgb(11, 58, 41)))

        // Das Dreieck hinten, von hinten nach vorn
        // Mit Typ: Zahlenliterale in Tupeln lassen den Typpruefer sonst
        // raten (Lessons Learned Nr. 16)
        let dreieck: [(CGFloat, CGFloat, CGFloat)] = [
            (114, 136, 0.9), (150, 136, 0.9), (186, 136, 0.9),
            (132, 158, 0.98), (168, 158, 0.98), (150, 182, 1.06)
        ]
        for (x, y, s) in dreieck {
            cup(&g, x, y, s)
        }

        // Die Bahn: gestrichelt von links unten, gepunktet weiter zum Becher
        P.line(&g, P.path("M-6 210 C16 110 52 62 92 52"), P.cream, 3.2, opacity: 0.85, dash: [2, 10])
        P.line(&g, P.path("M124 56 C140 66 150 92 150 166"), P.yellow, 2.4, opacity: 0.9, dash: [1, 8])
        P.line(&g, P.path("M70 40 L88 45 M64 56 L86 56 M70 72 L88 66"), P.cream, 2.8, opacity: 0.75)

        // Der Ball, darunter sein Schatten auf dem Tisch
        g.fill(P.ellipse(118, 214, 16, 5), with: .color(Color.black.opacity(0.28)))
        P.inked(&g, P.circle(CGPoint(x: 108, y: 54), 16), SceneArt.rgb(255, 250, 240), line: 3)
        P.line(&g, P.path("M98 47 Q103 41 111 42"), .white, 3)
        P.line(&g, P.path("M96 62 Q108 72 121 60"), P.orange, 2.4, opacity: 0.8)

        // Die eigenen Becher vorn, angeschnitten
        cup(&g, 26, 258, 1.95)
        cup(&g, 274, 258, 1.95)

        P.sparkle(&g, CGPoint(x: 236, y: 46), 10)
        P.sparkle(&g, CGPoint(x: 266, y: 92), 6)
        P.sparkle(&g, CGPoint(x: 40, y: 128), 5, color: P.cream)
        P.sparkle(&g, CGPoint(x: 210, y: 214), 6)
    }

    /// Ein roter Becher, der Rand oben bei (x, y), Groesse s – mit Glanz,
    /// zwei Rillen und Bier darin.
    private static func cup(_ g: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat) {
        let rw = 18 * s, rh = 6 * s, bw = 13 * s, hh = 34 * s
        let kontur = 2.2 * max(1, s * 0.8)

        var koerper = Path()
        koerper.move(to: CGPoint(x: x - rw, y: y))
        koerper.addLine(to: CGPoint(x: x - bw, y: y + hh))
        koerper.addQuadCurve(to: CGPoint(x: x + bw, y: y + hh), control: CGPoint(x: x, y: y + hh + 5 * s))
        koerper.addLine(to: CGPoint(x: x + rw, y: y))
        koerper.closeSubpath()
        P.inked(&g, koerper, red, line: kontur)

        var glanz = Path()
        glanz.move(to: CGPoint(x: x - rw * 0.72, y: y + 3 * s))
        glanz.addLine(to: CGPoint(x: x - bw * 0.62, y: y + hh - 2 * s))
        glanz.addLine(to: CGPoint(x: x - bw * 0.3, y: y + hh - s))
        glanz.addLine(to: CGPoint(x: x - rw * 0.42, y: y + 3 * s))
        glanz.closeSubpath()
        g.fill(glanz, with: .color(redLight.opacity(0.85)))

        var rillen = Path()
        rillen.move(to: CGPoint(x: x - rw * 0.93, y: y + 9 * s))
        rillen.addQuadCurve(to: CGPoint(x: x + rw * 0.93, y: y + 9 * s), control: CGPoint(x: x, y: y + 13 * s))
        rillen.move(to: CGPoint(x: x - rw * 0.8, y: y + 21 * s))
        rillen.addQuadCurve(to: CGPoint(x: x + rw * 0.8, y: y + 21 * s), control: CGPoint(x: x, y: y + 25 * s))
        P.line(&g, rillen, P.ink, 1.1 * s, opacity: 0.45)

        // Der Rand und das Bier darin
        P.inked(&g, P.ellipse(x, y, rw, rh), P.cream, line: 2 * max(1, s * 0.8))
        g.fill(P.ellipse(x, y + 0.6 * s, rw * 0.8, rh * 0.68), with: .color(P.orange))
        g.fill(P.ellipse(x - rw * 0.25, y, rw * 0.32, rh * 0.3), with: .color(SceneArt.rgb(255, 244, 214).opacity(0.9)))
    }
}

/// Das Plakat als Ansicht – still gezeichnet, fuer VoiceOver unsichtbar:
/// Daneben steht ohnehin "Beerpong".
struct BeerpongPosterView: View {

    var body: some View {
        Canvas { context, size in
            BeerpongPoster.draw(&context, size)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
