//
//  CoverArtEstimation.swift
//  BeerStats
//
//  Das Cover des Schaetzmeisters. Vom Nutzer am 6. November abgenommen;
//  die Zahlen sind die der Vorschau.
//

import SwiftUI

extension CoverArt {

    private typealias P = PosterInk

    private static let reel = SceneArt.rgb(143, 134, 118)
    private static let lever = SceneArt.rgb(201, 194, 180)
    private static let bulbFrame = SceneArt.rgb(74, 20, 40)
    private static let posterRed = SceneArt.rgb(216, 52, 42)

    /// Drei Zahlenwalzen in einem goldenen Zaehlwerk zeigen Vier, Zwei und
    /// ein Fragezeichen, ringsum Gluehbirnen, unten rollt sich ein gelbes
    /// Massband aus.
    static func drawEstimation(_ g: inout GraphicsContext) {
        P.ground(&g, inner: SceneArt.rgb(138, 35, 70), outer: SceneArt.rgb(30, 6, 18), center: CGPoint(x: 150, y: 166))

        // Gluehbirnen ringsum
        let rahmen = P.box(34, 68, 232, 140, corner: 20)
        g.stroke(rahmen, with: .color(P.ink), lineWidth: 20)
        g.stroke(rahmen, with: .color(bulbFrame), lineWidth: 14)
        var birnen: [CGPoint] = []
        for x in stride(from: CGFloat(52), through: 248, by: 22) {
            birnen.append(CGPoint(x: x, y: 68))
            birnen.append(CGPoint(x: x, y: 208))
        }
        for y in stride(from: CGFloat(92), through: 186, by: 24) {
            birnen.append(CGPoint(x: 34, y: y))
            birnen.append(CGPoint(x: 266, y: y))
        }
        for (k, mitte) in birnen.enumerated() {
            g.fill(P.circle(mitte, 10), with: .color(P.yellow.opacity(0.22)))
            P.inked(&g, P.circle(mitte, 5), k % 3 == 0 ? SceneArt.rgb(255, 246, 216) : P.yellow, line: 1.3)
        }

        // Das Zaehlwerk
        g.fill(P.box(60, 94, 190, 104, corner: 12), with: .color(Color.black.opacity(0.3)))
        P.inked(&g, P.box(50, 84, 200, 108, corner: 12), P.orange, line: 3)
        g.fill(P.box(58, 92, 184, 92, corner: 8), with: .color(SceneArt.rgb(26, 10, 16)))

        var fenster = g
        fenster.clip(to: P.box(62, 96, 176, 84, corner: 8))
        walze(&fenster, x: 64, oben: "3", mitte: "4", unten: "5", farbe: P.ink)
        walze(&fenster, x: 124, oben: "1", mitte: "2", unten: "3", farbe: P.ink)
        walze(&fenster, x: 184, oben: "", mitte: "?", unten: "", farbe: SceneArt.rgb(198, 56, 28))

        P.line(&g, P.path("M60 138 L240 138"), posterRed, 2, opacity: 0.55)
        P.line(&g, P.path("M58 100 L242 100"), Color.white, 3, opacity: 0.25)

        // Der Hebel
        let stange = P.path("M250 150 L282 112")
        P.line(&g, stange, P.ink, 9)
        P.line(&g, stange, lever, 5)
        P.inked(&g, P.circle(CGPoint(x: 283, y: 110), 10), posterRed, line: 2.4)

        // Das Massband rollt sich unten aus
        let band = P.path("M44 262 C70 240 80 242 96 242 L236 242 C262 242 270 262 292 256")
        P.line(&g, band, P.ink, 24)
        P.line(&g, band, P.yellow, 18)
        var striche = Path()
        for x in stride(from: CGFloat(96), through: 232, by: 8) {
            striche.move(to: CGPoint(x: x, y: 242))
            striche.addLine(to: CGPoint(x: x, y: x.truncatingRemainder(dividingBy: 32) == 0 ? 254 : 248))
        }
        g.stroke(striche, with: .color(P.ink), lineWidth: 1.6)
        let rolle = CGPoint(x: 40, y: 264)
        g.fill(P.circle(CGPoint(x: 44, y: 269), 28), with: .color(Color.black.opacity(0.3)))
        P.inked(&g, P.circle(rolle, 28), posterRed, line: 3)
        P.inked(&g, P.circle(rolle, 10), SceneArt.rgb(138, 28, 20), line: 2)

        P.sparkle(&g, CGPoint(x: 150, y: 32), 8)
        P.sparkle(&g, CGPoint(x: 270, y: 34), 5, color: P.cream)
        P.sparkle(&g, CGPoint(x: 24, y: 30), 5)
    }

    /// Eine Walze: Papier mit dunklen Raendern, die Zahl in der Mitte, ihre
    /// Nachbarn blass darueber und darunter.
    private static func walze(_ g: inout GraphicsContext, x: CGFloat, oben: String, mitte: String, unten: String, farbe: Color) {
        let flaeche = Path(CGRect(x: x, y: 96, width: 52, height: 84))
        g.fill(flaeche, with: .linearGradient(
            Gradient(stops: [
                .init(color: reel, location: 0),
                .init(color: P.cream, location: 0.22),
                .init(color: P.cream, location: 0.78),
                .init(color: reel, location: 1)
            ]),
            startPoint: CGPoint(x: 0, y: 96), endPoint: CGPoint(x: 0, y: 180)))
        g.stroke(flaeche, with: .color(P.ink), lineWidth: 2)
        P.letter(&g, oben, at: CGPoint(x: x + 26, y: 88), size: 40, color: P.ink.opacity(0.35))
        P.letter(&g, mitte, at: CGPoint(x: x + 26, y: 139), size: 58, color: farbe)
        P.letter(&g, unten, at: CGPoint(x: x + 26, y: 190), size: 40, color: P.ink.opacity(0.35))
    }
}
