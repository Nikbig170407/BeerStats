//
//  NeonSign.swift
//  BeerStats
//
//  Die Welt von "Ich hab noch nie": Leuchtreklame auf Backstein. Jeder Satz
//  zuendet wie eine Neonroehre – kurz flackernd, dann ruhig. Strafkarten
//  brummen rot und hoeren nicht ganz auf zu zucken.
//
//  Hier – und nur hier – ist Neon die Welt. Die App hatte Neonkanten
//  ueberall; in den anderen Spielen sind sie deshalb der Welt gewichen.
//
//  Das Flackern ist gerechnet, nicht gewuerfelt: Sonst zuendete derselbe
//  Satz bei jedem Neuzeichnen anders. Und es ist kurz – nach einer knappen
//  halben Sekunde steht der Satz ruhig da (Regel aus der Vorschau).
//

import SwiftUI

enum NeonSign {

    /// Die Farben der Roehren als Anteile, damit sich Kern und Schein
    /// mischen lassen.
    typealias Tube = (r: Double, g: Double, b: Double)

    static let pink: Tube = (255, 72, 170)
    static let red: Tube = (255, 64, 52)
    static let cyan: Tube = (80, 226, 255)

    /// Der Schein einer Roehre.
    static func glow(_ tube: Tube) -> Color {
        SceneArt.rgb(tube.r, tube.g, tube.b)
    }

    /// Der helle Kern – Roehrenfarbe, Richtung Weiss gemischt.
    static func core(_ tube: Tube, _ white: Double) -> Color {
        SceneArt.rgb(tube.r + (255 - tube.r) * white, tube.g + (255 - tube.g) * white, tube.b + (255 - tube.b) * white)
    }

    /// So lange zuendet eine Roehre.
    static let ignition: Double = 0.45

    /// Helligkeit einer Roehre `elapsed` Sekunden nach dem Einschalten.
    ///
    /// Beim Zuenden springt sie zwischen fast aus und an, mit wachsender
    /// Chance auf an. Danach brennt sie ruhig – oder, wenn sie `restless`
    /// ist, zuckt sie ab und zu kurz ab, wie eine Roehre kurz vor dem Ende.
    static func brightness(_ elapsed: Double, restless: Bool) -> Double {
        guard elapsed >= 0 else { return 0.06 }
        if elapsed < ignition {
            let bild = Int(elapsed * 28)
            return SceneArt.unit(bild, restless ? 23 : 17) > 0.75 - elapsed * 1.5 ? 1 : 0.06
        }
        guard restless else { return 1 }
        // Das Zucken bleibt lesbar: nie dunkler als drei Viertel
        return SceneArt.unit(Int(elapsed * 11), 29) > 0.1 ? 1 : 0.75
    }
}

// MARK: - Roehrentext

/// Ein Text als Neonroehre: heller Kern, farbiger Schein.
struct NeonText: View {

    let text: String
    let tube: NeonSign.Tube
    let font: Font
    var brightness: Double = 1

    var body: some View {
        let an = brightness > 0.5

        Text(text)
            .font(font)
            .foregroundStyle(NeonSign.core(tube, 0.55).opacity(0.18 + 0.82 * brightness))
            .shadow(color: NeonSign.glow(tube).opacity(an ? 0.95 : 0), radius: 6)
            .shadow(color: NeonSign.glow(tube).opacity(an ? 0.6 : 0), radius: 16)
    }
}

// MARK: - Das Schild

/// Eine Karte als Leuchtschild: oben die Zeile in Tuerkis, darunter der Satz
/// in einem Rahmen aus Roehre. Zuendet bei jedem neuen `id`.
struct NeonCard: View {

    let id: String
    let header: String
    let text: String
    let isPenalty: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var litAt = Date()
    @State private var igniting = true

    private var tube: NeonSign.Tube { isPenalty ? NeonSign.red : NeonSign.pink }

    var body: some View {
        Group {
            if reduceMotion {
                sign(header: 1, body: 1)
            } else if igniting || isPenalty {
                // Strafkarten zucken weiter; sonst steht die Zeitleiste nach
                // dem Zuenden still
                SwiftUI.TimelineView(.animation(minimumInterval: isPenalty && !igniting ? 1.0 / 11 : nil)) { timeline in
                    let t = timeline.date.timeIntervalSince(litAt)
                    sign(header: NeonSign.brightness(t + 5, restless: false),
                         body: NeonSign.brightness(t - 0.15, restless: isPenalty))
                }
            } else {
                sign(header: 1, body: 1)
            }
        }
        .task(id: id) {
            litAt = Date()
            igniting = true
            try? await Task.sleep(nanoseconds: UInt64((NeonSign.ignition + 0.2) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            igniting = false
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(header): \(text)")
    }

    private func sign(header kopf: Double, body hell: Double) -> some View {
        VStack(spacing: 18) {
            NeonText(text: header, tube: NeonSign.cyan, font: .scaled(19, weight: .semibold), brightness: kopf)
                .kerning(3)

            VStack(spacing: 16) {
                if isPenalty {
                    WarningTriangle(tube: tube, brightness: hell)
                        .frame(width: 64, height: 56)
                }

                NeonText(text: text, tube: tube, font: .scaled(isPenalty ? 27 : 30, weight: .semibold), brightness: hell)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(NeonSign.core(tube, 0.3).opacity(0.15 + 0.85 * hell), lineWidth: 5)
                    .shadow(color: NeonSign.glow(tube).opacity(hell > 0.5 ? 0.95 : 0), radius: 11)
            }
            // Der Schein faellt auf die Wand
            .background {
                RadialGradient(colors: [NeonSign.glow(tube).opacity(0.22 * hell), .clear],
                               center: .center, startRadius: 10, endRadius: 300)
                    .padding(-60)
                    .allowsHitTesting(false)
            }
        }
    }
}

/// Ein Warndreieck aus Roehre, mit Ausrufezeichen.
struct WarningTriangle: View {

    let tube: NeonSign.Tube
    var brightness: Double = 1

    var body: some View {
        ZStack {
            Triangle()
                .stroke(NeonSign.core(tube, 0.3).opacity(0.15 + 0.85 * brightness), style: StrokeStyle(lineWidth: 4, lineJoin: .round))
                .shadow(color: NeonSign.glow(tube).opacity(brightness > 0.5 ? 0.9 : 0), radius: 8)
            NeonText(text: "!", tube: tube, font: .scaled(30, weight: .heavy), brightness: brightness)
                .offset(y: 6)
        }
        .accessibilityHidden(true)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
