//
//  FuturisticStyle.swift
//  BeerStats
//
//  Bausteine für den technischeren Look: leuchtende Kanten, ein feines
//  Raster im Hintergrund und eine Glasfläche.
//
//  Bewusst als wiederverwendbare Modifier statt als Kopien in jeder View.
//  Und bewusst auf dem bestehenden Bernstein-Rot-Schema: Der Look wird
//  technischer, bleibt aber erkennbar dieselbe App.
//

import SwiftUI

// MARK: - Leuchtende Kante

/// Umrandung mit Farbverlauf und äußerem Schein.
///
/// Der Verlauf von hell nach transparent lässt die Kante an einer Seite
/// „angeleuchtet" wirken – das erzeugt Tiefe, die eine gleichmäßige Linie
/// nicht hat.
struct NeonEdge: ViewModifier {

    var color: Color = BeerStatsColor.accent
    var cornerRadius: CGFloat = 18
    var intensity: Double = 1

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                color.opacity(0.95 * intensity),
                                color.opacity(0.25 * intensity),
                                color.opacity(0.7 * intensity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.4
                    )
            )
            .shadow(color: color.opacity(0.35 * intensity), radius: 14)
    }
}

extension View {
    func neonEdge(
        _ color: Color = BeerStatsColor.accent,
        cornerRadius: CGFloat = 18,
        intensity: Double = 1
    ) -> some View {
        modifier(NeonEdge(color: color, cornerRadius: cornerRadius, intensity: intensity))
    }
}

// MARK: - Glasfläche

/// Dunkle, leicht durchscheinende Fläche als Untergrund für Panels.
struct GlassPanel: ViewModifier {

    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BeerStatsColor.surfaceElevated.opacity(0.95),
                            BeerStatsColor.backgroundSecondary.opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 18) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius))
    }
}

// MARK: - Raster-Hintergrund

/// Feines Linienraster mit weichem Farbschein – gibt Bildschirmen Tiefe,
/// ohne vom Inhalt abzulenken.
struct GridBackdrop: View {

    var spacing: CGFloat = 34
    var lineOpacity: Double = 0.05
    var glow: Color = BeerStatsColor.accent

    var body: some View {
        ZStack {
            BeerStatsColor.backgroundPrimary

            Canvas { context, size in
                let stroke = GraphicsContext.Shading.color(BeerStatsColor.textPrimary.opacity(lineOpacity))

                var x: CGFloat = 0
                while x <= size.width {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: stroke, lineWidth: 0.7)
                    x += spacing
                }

                var y: CGFloat = 0
                while y <= size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: stroke, lineWidth: 0.7)
                    y += spacing
                }
            }

            // Zwei weiche Farbschleier, damit das Raster nicht technisch-kalt wirkt.
            RadialGradient(
                colors: [glow.opacity(0.16), .clear],
                center: UnitPoint(x: 0.15, y: 0.0),
                startRadius: 0,
                endRadius: 420
            )
            RadialGradient(
                colors: [BeerStatsColor.accentSecondary.opacity(0.12), .clear],
                center: UnitPoint(x: 0.95, y: 0.25),
                startRadius: 0,
                endRadius: 380
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ZStack {
        GridBackdrop()
        VStack(spacing: 20) {
            Text("Panel")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(24)
                .glassPanel()
                .neonEdge()

            Text("Zweiter Akzent")
                .font(BeerStatsFont.headline)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(20)
                .glassPanel(cornerRadius: 14)
                .neonEdge(BeerStatsColor.accentSecondary, cornerRadius: 14)
        }
        .padding(24)
    }
}
