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

// MARK: - Hintergrund

/// Warmer, weicher Hintergrund: dunkler Grund, zwei Lichtquellen in den
/// Markenfarben und ein paar sehr blasse Blasen.
///
/// Hier lag vorher ein technisches Linienraster. Das gab Tiefe, sah aber nach
/// Entwicklerwerkzeug aus – und diese App steht auf einem Tisch mit Bier
/// darauf, nicht auf einem Schreibtisch. Die Blasen sind dasselbe Motiv wie
/// `CupShape` und `BeerGlassMark`: Der Hintergrund soll nach dem Getränk
/// aussehen, nicht nach Messgerät.
///
/// Die Blasen stehen als feste Liste im Code und werden **nicht gewürfelt**.
/// Ein `Canvas` zeichnet bei jeder Layout-Änderung neu; mit Zufallszahlen
/// sprängen sie bei jedem Tastendruck an eine andere Stelle.
struct AmbientBackdrop: View {

    /// Die Lichtquelle oben links. Jeder Screen gibt seine eigene Farbe mit –
    /// so bleibt der Hintergrund derselbe und trägt trotzdem die Stimmung des
    /// Screens.
    var glow: Color = BeerStatsColor.accent

    /// Lage und Größe relativ zur Fläche, damit es auf jedem Gerät gleich
    /// aussieht. Bewusst unregelmäßig – gleichmäßig verteilt wäre wieder ein
    /// Raster, nur mit runden Ecken.
    private static let bubbles: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = [
        (0.09, 0.07, 0.20, 0.055),
        (0.78, 0.04, 0.11, 0.040),
        (0.36, 0.14, 0.06, 0.070),
        (0.92, 0.17, 0.26, 0.030),
        (0.17, 0.29, 0.09, 0.055),
        (0.61, 0.26, 0.15, 0.035),
        (0.04, 0.46, 0.13, 0.045),
        (0.85, 0.44, 0.07, 0.065),
        (0.44, 0.52, 0.22, 0.028),
        (0.24, 0.63, 0.05, 0.075),
        (0.71, 0.66, 0.17, 0.038),
        (0.11, 0.78, 0.10, 0.050),
        (0.52, 0.83, 0.07, 0.060),
        (0.89, 0.88, 0.19, 0.032),
        (0.31, 0.95, 0.12, 0.042)
    ]

    var body: some View {
        ZStack {
            BeerStatsColor.backgroundPrimary

            // Oben eine Spur heller: gibt der Fläche eine Richtung, ohne dass
            // man eine Kante sieht.
            LinearGradient(
                colors: [
                    BeerStatsColor.backgroundSecondary.opacity(0.6),
                    BeerStatsColor.backgroundPrimary
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [glow.opacity(0.20), .clear],
                center: UnitPoint(x: 0.12, y: -0.02),
                startRadius: 0,
                endRadius: 520
            )
            RadialGradient(
                colors: [BeerStatsColor.accentSecondary.opacity(0.13), .clear],
                center: UnitPoint(x: 1.02, y: 0.82),
                startRadius: 0,
                endRadius: 460
            )

            Canvas { context, size in
                // An der kürzeren Kante gemessen, sonst werden die Blasen im
                // Querformat zu Ellipsen-Ersatz in Übergröße.
                let kante = min(size.width, size.height)

                for blase in Self.bubbles {
                    let durchmesser = blase.size * kante
                    let kreis = Path(
                        ellipseIn: CGRect(
                            x: blase.x * size.width - durchmesser / 2,
                            y: blase.y * size.height - durchmesser / 2,
                            width: durchmesser,
                            height: durchmesser
                        )
                    )
                    // Gefüllt in der Stimmungsfarbe, umrandet in Weiß: Erst
                    // die helle Kante macht daraus eine Blase statt eines
                    // Farbflecks.
                    context.fill(kreis, with: .color(glow.opacity(blase.opacity * 0.55)))
                    context.stroke(
                        kreis,
                        with: .color(BeerStatsColor.textPrimary.opacity(blase.opacity * 0.8)),
                        lineWidth: 1
                    )
                }
            }
            .blur(radius: 0.6)

            // Nach unten satter: Der Inhalt soll oben schweben, und die
            // Knöpfe am unteren Rand brauchen ruhigen Grund unter sich.
            LinearGradient(
                colors: [.clear, BeerStatsColor.backgroundPrimary.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Senkrecht bleiben

extension View {

    /// Nimmt einer senkrechten Liste das seitliche Nachfedern.
    ///
    /// Eine `ScrollView` federt waagerecht mit, sobald irgendein Kind breiter
    /// ist als der Bildschirm – man schiebt die Kacheln ein Stück zur Seite
    /// und sie rutschen zurück. Gewollt ist das nie, es sieht nur nach
    /// kaputtem Layout aus.
    ///
    /// `.basedOnSize` federt nur noch, wenn der Inhalt die Richtung wirklich
    /// braucht. Gibt es ab iOS 16.4; darunter bleibt es beim alten Verhalten,
    /// das Deployment-Target ist 16.0.
    @ViewBuilder
    func verticalScrollOnly() -> some View {
        if #available(iOS 16.4, *) {
            scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        } else {
            self
        }
    }
}

#Preview {
    ZStack {
        AmbientBackdrop()
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
