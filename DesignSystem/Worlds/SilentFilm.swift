//
//  SilentFilm.swift
//  BeerStats
//
//  Die Welt der Pantomime: Stummfilm. Ein Spiel ohne Worte bekommt seine
//  Worte so, wie das Kino sie hatte, als es selbst noch stumm war – als
//  Zwischentitel im verzierten Rahmen. Die Uhr ist ein Film-Vorlauf.
//
//  Schwarzweiss bleibt Schwarzweiss, mit einer Ausnahme: Die letzten zehn
//  Sekunden werden rot. Das ist eine Warnung und keine Farbe des Spiels –
//  Rot behaelt in jeder Welt seine Bedeutung.
//

import SwiftUI

enum SilentFilm {
    static let card = Color(white: 0.025)
    static let leaderDisc = SceneArt.rgb(58, 58, 56)
    static let leaderSweep = SceneArt.rgb(104, 104, 100)
}

// MARK: - Zwischentitel

/// Schwarze Tafel, doppelter weisser Rahmen, Ornamente in den Ecken.
struct Intertitle<Content: View>: View {

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 10) { content }
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 34)
            .padding(.vertical, 38)
            .frame(maxWidth: .infinity)
            .background { IntertitleFrame() }
    }
}

private struct IntertitleFrame: View {

    var body: some View {
        Canvas { context, size in
            let w = Double(size.width), h = Double(size.height)
            context.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 4),
                         with: .color(SilentFilm.card.opacity(0.96)))
            context.stroke(Path(roundedRect: CGRect(x: 10, y: 10, width: w - 20, height: h - 20), cornerRadius: 3),
                           with: .color(.white.opacity(0.88)), lineWidth: 2.5)
            context.stroke(Path(roundedRect: CGRect(x: 18, y: 18, width: w - 36, height: h - 36), cornerRadius: 2),
                           with: .color(.white.opacity(0.6)), lineWidth: 1)

            // Ein Viertelbogen und ein Punkt in jeder Ecke, nach innen gedreht
            let r = 18.0
            let ecken: [SceneArt.Point] = [(r, r), (w - r, r), (w - r, h - r), (r, h - r)]
            for (i, ecke) in ecken.enumerated() {
                let a0 = Double(i) * .pi / 2
                SceneArt.stroke(&context, SceneArt.arc(ecke.x, ecke.y, 12, a0, a0 + .pi / 2, 10), .white, 0.7, 1.5)
                SceneArt.circle(&context, ecke.x, ecke.y, 2.5, .white, 0.8)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

// MARK: - Film-Vorlauf

/// Die Uhr als Film-Vorlauf: Ein Zeiger streicht je Sekunde einmal um die
/// Zahl, wie die Countdown-Scheibe vor einer Filmrolle.
struct FilmLeader: View {

    let seconds: Int
    /// Wann die Uhr losgelaufen ist – daran haengt der Zeiger, damit er
    /// gleichmaessig streicht, auch wenn die Zahl in Schritten zaehlt.
    let startedAt: Date
    var warning: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if reduceMotion {
                Canvas { context, size in Self.draw(&context, size, sweep: 0) }
            } else {
                SwiftUI.TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        Self.draw(&context, size, sweep: SceneArt.fract(timeline.date.timeIntervalSince(startedAt)))
                    }
                }
            }

            Text("\(seconds)")
                .font(.scaled(50, weight: .bold, design: .serif))
                .monospacedDigit()
                .foregroundStyle(warning ? BeerStatsColor.error : Color.white)
        }
        .frame(width: 128, height: 128)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Noch \(seconds) Sekunden")
    }

    private static func draw(_ g: inout GraphicsContext, _ size: CGSize, sweep: Double) {
        let w = Double(size.width), h = Double(size.height)
        let cx = w / 2, cy = h / 2, r = min(w, h) / 2 - 10
        SceneArt.circle(&g, cx, cy, r, SilentFilm.leaderDisc, 0.95)
        if sweep > 0 {
            var keil: [SceneArt.Point] = [(cx, cy)]
            keil += SceneArt.arc(cx, cy, r, -.pi / 2, -.pi / 2 + sweep * 2 * .pi, 48)
            SceneArt.fill(&g, keil, SilentFilm.leaderSweep, 0.95)
        }
        g.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)),
                 with: .color(.white.opacity(0.85)), lineWidth: 3)
        let innen = r * 0.8
        g.stroke(Path(ellipseIn: CGRect(x: cx - innen, y: cy - innen, width: 2 * innen, height: 2 * innen)),
                 with: .color(.white.opacity(0.7)), lineWidth: 2)
        let links: SceneArt.Point = (cx - r - 8, cy)
        let rechts: SceneArt.Point = (cx + r + 8, cy)
        let oben: SceneArt.Point = (cx, cy - r - 8)
        let unten: SceneArt.Point = (cx, cy + r + 8)
        SceneArt.lines(&g, [(links, rechts), (oben, unten)], .white, 0.55, 2)
    }
}

// MARK: - Schnitt

/// Ein Schnitt wie im alten Film: Bei jedem neuen Bild springt der Inhalt
/// kurz und blitzt auf.
struct FilmCut<Trigger: Equatable>: ViewModifier {

    let trigger: Trigger

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var jump: CGFloat = 0
    @State private var flash: Double = 0

    func body(content: Content) -> some View {
        content
            .offset(y: jump)
            .overlay {
                Color.white
                    .opacity(flash)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .onChange(of: trigger) { _ in
                guard !reduceMotion else { return }
                jump = 9
                flash = 0.35
                // Erst den Sprung zeigen, dann zurueck – im selben Durchlauf
                // gesetzt, saehe SwiftUI nur den Endwert und es geschaehe nichts.
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.12)) {
                        jump = 0
                        flash = 0
                    }
                }
            }
    }
}
