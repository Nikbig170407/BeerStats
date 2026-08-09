//
//  HitRateTrendChart.swift
//  BeerStats
//
//  Die Trefferquote der letzten Partien als Kurve.
//
//  Selbst gezeichnet statt mit Swift Charts. Der Rest der App zeichnet
//  ohnehin selbst – Ring, Rad, Becher –, und fuer eine Linie mit fuenfzehn
//  Punkten ist ein Diagramm-Framework mehr Abhaengigkeit als Nutzen.
//
//  Gewonnene Partien sind gefuellte Punkte, verlorene hohl. Ohne das waere
//  es eine Quotenkurve; mit dem Unterschied sieht man, ob ein guter Abend
//  auch einer war, an dem man gewonnen hat – und das ist die Frage, die am
//  Tisch tatsaechlich gestellt wird.
//

import SwiftUI

struct HitRateTrendChart: View {

    let points: [TrendPoint]
    var tint: Color = BeerStatsColor.accent

    private let height: CGFloat = 92
    /// Rand oben und unten, damit die Punkte am Rand nicht angeschnitten
    /// werden.
    private let inset: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let usable = height - inset * 2

            ZStack {
                // Bezugslinie bei 50 Prozent. Ohne sie ist eine Kurve nur
                // eine Zickzacklinie – erst die Marke macht sie lesbar.
                Path { path in
                    path.move(to: CGPoint(x: 0, y: inset + usable / 2))
                    path.addLine(to: CGPoint(x: width, y: inset + usable / 2))
                }
                .stroke(
                    BeerStatsColor.textSecondary.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )

                line(width: width, usable: usable)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                ForEach(points) { point in
                    marker(for: point)
                        .position(
                            x: x(point.id, width: width),
                            y: y(point.hitRate, usable: usable)
                        )
                }
            }
            .frame(width: width, height: height)
        }
        .frame(height: height)
    }

    @ViewBuilder
    private func marker(for point: TrendPoint) -> some View {
        if point.won {
            Circle().fill(tint).frame(width: 8, height: 8)
        } else {
            Circle()
                .strokeBorder(tint.opacity(0.7), lineWidth: 2)
                .background(Circle().fill(BeerStatsColor.backgroundPrimary))
                .frame(width: 8, height: 8)
        }
    }

    private func line(width: CGFloat, usable: CGFloat) -> Path {
        Path { path in
            for point in points {
                let position = CGPoint(
                    x: x(point.id, width: width),
                    y: y(point.hitRate, usable: usable)
                )
                if point.id == 0 {
                    path.move(to: position)
                } else {
                    path.addLine(to: position)
                }
            }
        }
    }

    /// Bei einer einzelnen Partie gaebe eine Division durch null einen
    /// ungueltigen Wert – dann steht der Punkt einfach in der Mitte.
    private func x(_ index: Int, width: CGFloat) -> CGFloat {
        guard points.count > 1 else { return width / 2 }
        return width * CGFloat(index) / CGFloat(points.count - 1)
    }

    private func y(_ rate: Double, usable: CGFloat) -> CGFloat {
        inset + usable * (1 - CGFloat(min(max(rate, 0), 1)))
    }
}
