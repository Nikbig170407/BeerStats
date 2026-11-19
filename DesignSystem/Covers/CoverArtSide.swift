//
//  CoverArtSide.swift
//  BeerStats
//
//  Die Cover der Gruppe "Laeuft nebenher": Verbotene Woerter, Trinkbingo und
//  Regel des Abends. Vom Nutzer am 19. November in der Vorschau abgenommen;
//  die Zahlen sind die der Vorschau.
//

import SwiftUI

extension CoverArt {

    private typealias P = PosterInk

    private static let red = SceneArt.rgb(216, 52, 42)

    // MARK: - Verbotene Woerter

    /// Eine Karte mit einem grossen Wort, die drei Zeilen darunter sind rot
    /// durchgestrichen, davor ein Verbotsschild und ein Streifen Klebeband.
    static func drawBannedCard(_ g: inout GraphicsContext) {
        P.ground(&g, inner: SceneArt.rgb(143, 42, 82), outer: SceneArt.rgb(34, 6, 26), center: CGPoint(x: 150, y: 180))

        var karte = turned(g, around: CGPoint(x: 150, y: 150), degrees: -7)
        karte.fill(P.box(62, 44, 176, 206, corner: 14), with: .color(Color.black.opacity(0.3)))
        P.inked(&karte, P.box(56, 38, 176, 206, corner: 14), P.cream, line: 3.2)
        P.inked(&karte, P.box(56, 38, 176, 44, corner: 14), P.yellow, line: 3.2)
        P.letter(&karte, "WORT", at: CGPoint(x: 144, y: 62), size: 30, color: P.ink)
        let zeilen: [(CGFloat, CGFloat)] = [(128, 112), (160, 96), (192, 118)]
        for (y, w) in zeilen {
            karte.fill(P.box(150 - w / 2 - 8, y, w, 14, corner: 4), with: .color(P.ink.opacity(0.75)))
            P.line(&karte, P.path("M\(150 - w / 2 - 20) \(y + 7) L\(150 + w / 2 + 6) \(y + 7)"), red, 5)
        }

        // Das Klebeband
        var band = turned(g, around: CGPoint(x: 70, y: 250), degrees: 8)
        P.inked(&band, P.box(18, 236, 104, 26, corner: 3), SceneArt.rgb(216, 208, 188), line: 2.6)
        P.line(&band, P.path("M30 242 L44 256 M58 242 L72 256 M86 242 L100 256"), P.ink, 2, opacity: 0.35)

        // Das Verbotsschild
        let schild = CGPoint(x: 226, y: 226)
        g.fill(P.circle(CGPoint(x: 231, y: 232), 56), with: .color(Color.black.opacity(0.3)))
        P.inked(&g, P.circle(schild, 52), red, line: 3.4)
        P.inked(&g, P.circle(schild, 36), P.cream, line: 3)
        P.letter(&g, "?", at: schild, size: 34, color: P.ink.opacity(0.5))
        P.line(&g, P.path("M200 252 L252 200"), red, 12)

        P.sparkle(&g, CGPoint(x: 262, y: 52), 7)
        P.sparkle(&g, CGPoint(x: 36, y: 56), 5, color: P.cream)
        P.sparkle(&g, CGPoint(x: 40, y: 196), 4)
    }

    // MARK: - Trinkbingo

    /// Ein Bingoblatt mit vier mal vier Feldern, einige tragen rote Klekse,
    /// eine Reihe ist gruen durchgestrichen.
    static func drawBingoSheet(_ g: inout GraphicsContext) {
        P.ground(&g, inner: SceneArt.rgb(27, 122, 152), outer: SceneArt.rgb(4, 32, 44), center: CGPoint(x: 150, y: 200))

        let x0: CGFloat = 62
        let y0: CGFloat = 100
        let z: CGFloat = 44

        g.fill(P.box(x0 + 6, y0 - 32, 4 * z, 4 * z + 48, corner: 8), with: .color(Color.black.opacity(0.3)))
        P.inked(&g, P.box(x0 - 6, y0 - 48, 4 * z + 12, 4 * z + 56, corner: 10), P.cream, line: 3.2)
        P.inked(&g, P.box(x0 - 6, y0 - 48, 4 * z + 12, 44, corner: 10), P.orange, line: 3.2)
        P.letter(&g, "BINGO", at: CGPoint(x: 150, y: y0 - 26), size: 34, color: P.ink)

        let voll: Set<Int> = [2, 4, 5, 6, 7, 9, 14]
        let hell = SceneArt.rgb(239, 227, 200)
        for r in 0..<4 {
            for c in 0..<4 {
                let i = r * 4 + c
                let x = x0 + CGFloat(c) * z
                let y = y0 + CGFloat(r) * z
                let feld = Path(CGRect(x: x, y: y, width: z, height: z))
                g.fill(feld, with: .color((r + c) % 2 == 1 ? hell : P.cream))
                g.stroke(feld, with: .color(P.ink), lineWidth: 2)
                if voll.contains(i) {
                    let mitte = CGPoint(x: x + z / 2, y: y + z / 2)
                    var klecks = turned(g, around: mitte, degrees: Double((i * 37) % 30 - 15))
                    P.inked(&klecks, P.circle(mitte, 14), red.opacity(0.95), line: 2.6)
                    klecks.fill(P.circle(CGPoint(x: mitte.x - 4, y: mitte.y - 5), 3.4), with: .color(Color.white.opacity(0.5)))
                } else {
                    P.line(&g, P.path("M\(x + 10) \(y + 16) L\(x + z - 10) \(y + 16) M\(x + 10) \(y + 28) L\(x + z - 18) \(y + 28)"), P.ink, 3, opacity: 0.35)
                }
            }
        }
        g.stroke(Path(CGRect(x: x0, y: y0, width: 4 * z, height: 4 * z)), with: .color(P.ink), lineWidth: 3)

        let linie = P.path("M\(x0 + 8) \(y0 + z * 1.5) L\(x0 + 4 * z - 8) \(y0 + z * 1.5)")
        P.line(&g, linie, SceneArt.rgb(53, 210, 122), 9, opacity: 0.9)
        P.line(&g, linie, P.ink, 2, opacity: 0.5)

        P.sparkle(&g, CGPoint(x: 262, y: 40), 8)
        P.sparkle(&g, CGPoint(x: 34, y: 44), 5, color: P.cream)
        P.sparkle(&g, CGPoint(x: 270, y: 276), 6)
        P.sparkle(&g, CGPoint(x: 30, y: 270), 5, color: P.cream)
    }

    // MARK: - Regel des Abends

    /// Ein Richterhammer schlaegt auf ein aufgerolltes Pergament mit dem Wort
    /// REGEL, daneben ein rotes Wachssiegel.
    static func drawGavelScroll(_ g: inout GraphicsContext) {
        P.ground(&g, inner: SceneArt.rgb(75, 44, 138), outer: SceneArt.rgb(14, 8, 36), center: CGPoint(x: 150, y: 200))

        // Das Pergament
        g.fill(Path(CGRect(x: 57, y: 92, width: 196, height: 122)), with: .color(Color.black.opacity(0.3)))
        let blatt = Path(CGRect(x: 52, y: 86, width: 196, height: 122))
        g.fill(blatt, with: .color(SceneArt.rgb(241, 226, 180)))
        g.stroke(blatt, with: .color(P.ink), lineWidth: 3)
        let text: [(CGFloat, CGFloat)] = [(146, 124), (166, 100), (186, 92)]
        for (y, w) in text {
            g.fill(P.box(150 - w / 2, y, w, 9, corner: 3), with: .color(P.ink.opacity(0.55)))
        }
        P.letter(&g, "REGEL", at: CGPoint(x: 150, y: 118), size: 30, color: SceneArt.rgb(122, 42, 28))
        for y: CGFloat in [66, 194] {
            P.inked(&g, P.box(40, y, 220, 26, corner: 13), SceneArt.rgb(232, 212, 160), line: 3)
            for x: CGFloat in [46, 254] {
                P.inked(&g, P.ellipse(x, y + 13, 9, 13), SceneArt.rgb(201, 176, 122), line: 2.6)
            }
        }

        // Das Siegel
        P.inked(&g, P.star(CGPoint(x: 212, y: 206), outer: 30, inner: 24, points: 12), red, line: 3)
        P.inked(&g, P.circle(CGPoint(x: 212, y: 206), 17), SceneArt.rgb(168, 34, 28), line: 2.6)
        g.fill(P.star(CGPoint(x: 212, y: 206), outer: 11, inner: 4.5, points: 5), with: .color(P.yellow))

        // Der Hammer
        var hammer = g
        hammer.translateBy(x: 66, y: 42)
        hammer.rotate(by: .degrees(-62))
        P.inked(&hammer, P.box(-8, 0, 16, 96, corner: 6), SceneArt.rgb(154, 90, 36), line: 3)
        P.inked(&hammer, P.box(-34, -26, 68, 34, corner: 9), SceneArt.rgb(201, 138, 60), line: 3.2)
        P.inked(&hammer, P.box(-34, -26, 14, 34, corner: 6), SceneArt.rgb(138, 90, 30), line: 2.6)
        P.inked(&hammer, P.box(20, -26, 14, 34, corner: 6), SceneArt.rgb(138, 90, 30), line: 2.6)

        P.line(&g, P.path("M26 64 L14 52 M22 90 L8 94 M46 20 L40 8"), P.yellow, 4)

        P.sparkle(&g, CGPoint(x: 262, y: 52), 7)
        P.sparkle(&g, CGPoint(x: 40, y: 262), 5, color: P.cream)
        P.sparkle(&g, CGPoint(x: 256, y: 262), 5)
    }
}
