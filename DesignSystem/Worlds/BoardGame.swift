//
//  BoardGame.swift
//  BeerStats
//
//  Die Welt von 21: ein Spielbrett. Die Zahlen liegen als Felder auf einem
//  gewundenen Pfad, fuenf je Reihe, hin und zurueck – und die 21 allein
//  unten, mit Krone. Jede Regel klebt als Aufkleber auf ihrem Feld.
//
//  Ein Raster aus 21 gleichen Kacheln war richtig, aber es sah aus wie ein
//  Taschenrechner. Am Tisch zaehlt man einen WEG entlang, und auf einem Weg
//  sieht man, wie weit es noch bis zur 21 ist.
//

import SwiftUI

enum BoardGame {

    static let field = SceneArt.rgb(232, 222, 196)
    static let ink = SceneArt.rgb(28, 26, 26)
    static let gold = SceneArt.rgb(250, 214, 90)

    /// Die Farben der Aufkleber, reihum nach Zahl – benachbarte Felder
    /// bekommen so verschiedene Farben.
    static let stickers: [Color] = [
        SceneArt.rgb(250, 214, 70), SceneArt.rgb(240, 120, 170), SceneArt.rgb(120, 220, 170),
        SceneArt.rgb(180, 150, 250), SceneArt.rgb(255, 150, 60),
    ]

    static func stickerColor(for number: Int) -> Color {
        stickers[number % stickers.count]
    }

    static let perRow = 5
    static let rowHeight: CGFloat = 76

    /// Wo ein Feld liegt, als Anteil der Breite und Nummer der Reihe.
    /// Schlangenlinie: fuenf je Reihe, abwechselnd hin und zurueck, die 21
    /// allein in der Mitte darunter.
    static func slot(_ number: Int) -> (column: Double, row: Int) {
        guard number < 21 else { return (Double(perRow) / 2, (20 / perRow)) }
        let reihe = (number - 1) / perRow
        let spalte = (number - 1) % perRow
        let lage = reihe % 2 == 0 ? spalte : perRow - 1 - spalte
        return (Double(lage) + 0.5, reihe)
    }

    static func center(_ number: Int, width: CGFloat) -> CGPoint {
        let s = slot(number)
        return CGPoint(x: width * s.column / CGFloat(perRow), y: (CGFloat(s.row) + 0.5) * rowHeight)
    }

    static var height: CGFloat { rowHeight * CGFloat(20 / perRow + 1) }
}

// MARK: - Der Weg

/// Die gepunktete Spur von Feld zu Feld.
struct BoardTrail: View {

    var body: some View {
        Canvas { context, size in
            var weg = Path()
            weg.move(to: BoardGame.center(1, width: size.width))
            for zahl in 2...21 { weg.addLine(to: BoardGame.center(zahl, width: size.width)) }
            context.stroke(weg, with: .color(BoardGame.field.opacity(0.45)),
                           style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round, dash: [2, 12]))
            let ziel = BoardGame.center(21, width: size.width)
            SceneArt.glow(&context, Double(ziel.x), Double(ziel.y), 70, BoardGame.gold, 0.3)
        }
        .frame(height: BoardGame.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Eine Krone fuer das Zielfeld.
struct BoardCrown: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, x = rect.minX, y = rect.minY
        var p = Path()
        p.move(to: CGPoint(x: x, y: y + h))
        p.addLine(to: CGPoint(x: x + w * 0.17, y: y + h * 0.2))
        p.addLine(to: CGPoint(x: x + w * 0.39, y: y + h * 0.8))
        p.addLine(to: CGPoint(x: x + w * 0.5, y: y))
        p.addLine(to: CGPoint(x: x + w * 0.61, y: y + h * 0.8))
        p.addLine(to: CGPoint(x: x + w * 0.83, y: y + h * 0.2))
        p.addLine(to: CGPoint(x: x + w, y: y + h))
        p.closeSubpath()
        return p
    }
}

// MARK: - Aufkleber

/// Ein Aufkleber mit einer Regel: bunt, schief, mit umgeknickter Ecke.
/// Er klatscht beim Erscheinen aufs Feld und federt ein.
struct BoardSticker: View {

    let text: String
    let color: Color
    let angle: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stuck = false

    var body: some View {
        let klebt = stuck || reduceMotion

        Text(text)
            .font(.scaled(11, weight: .heavy, design: .rounded, maximumScale: 1.2))
            .foregroundStyle(BoardGame.ink)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(width: 66)
            .background(color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                // Die Ecke loest sich schon
                Triangle()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: 10, height: 10)
            }
            .shadow(color: .black.opacity(0.4), radius: 3, x: 1, y: 2)
            .rotationEffect(.degrees(klebt ? angle : angle - 30))
            .scaleEffect(klebt ? 1 : 2.3)
            .opacity(klebt ? 1 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                // Wartet, bis der Editor zu ist – sonst klatscht er dahinter
                withAnimation(.spring(response: 0.32, dampingFraction: 0.55).delay(0.35)) { stuck = true }
            }
    }

    private struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
            return p
        }
    }
}
