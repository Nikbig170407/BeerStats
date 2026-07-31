//
//  HighlightOverlayView.swift
//  BeerStats
//
//  Die gefeierten Momente: Airball, Bombe, Balls Back, On Fire, Umstellen
//  und Redemption als kurze Vollbild-Einblendung.
//
//  Zwei Dinge sind hier bewusst gesetzt. Erstens fängt das Overlay keine
//  Taps ab – wer schnell weitertippt, soll nicht auf die Animation warten
//  müssen. Zweitens ist alles auf rund 1,2 Sekunden ausgelegt: lang genug
//  zum Wahrnehmen, kurz genug, dass es auch beim fünften Airball hinter-
//  einander nicht nervt.
//

import SwiftUI

struct HighlightOverlayView: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let highlight: LiveGameViewModel.Highlight
    /// Wird beim Antippen aufgerufen – die Einblendung lässt sich damit
    /// überspringen, ohne dass der Tipp die Bedienelemente darunter erreicht.
    var onTap: () -> Void = {}

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            artwork
                .frame(height: 96)
                // Farbiger Schein direkt am Motiv statt flächig im
                // Hintergrund – so hebt es sich ab, statt darin zu versinken.
                .shadow(color: highlight.tint.opacity(0.55), radius: 26)

            Text(highlight.title)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(highlight.tint)
                .shadow(color: .black.opacity(0.9), radius: 2, y: 2)
                .shadow(color: highlight.tint.opacity(0.6), radius: 22)
                .scaleEffect(isAnimating ? 1 : 0.5)
                .opacity(isAnimating ? 1 : 0)

            Text(highlight.subtitle)
                .font(BeerStatsFont.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .shadow(color: .black.opacity(0.8), radius: 2)
                .padding(.horizontal, 32)
                .offset(y: isAnimating ? 0 : 12)
                .opacity(isAnimating ? 1 : 0)

            Text("Tippen zum Überspringen")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .padding(.top, 18)
                .opacity(isAnimating ? 0.7 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backdrop)
        // Fängt Eingaben bewusst ab: Während der Einblendung darf kein Tipp
        // versehentlich einen Becher oder Button darunter treffen. Wer es
        // eilig hat, tippt die Einblendung weg.
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onAppear {
            guard !reduceMotion else { isAnimating = true; return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.55)) { isAnimating = true }
        }
    }

    /// Nahezu deckendes Dunkel statt eines eingefärbten Verlaufs.
    ///
    /// Vorher lag hinter dem Motiv ein Radialverlauf in genau der Farbe des
    /// Motivs – Flamme auf Bernstein, Explosion auf Rot. Das Ergebnis war
    /// matschig. Jetzt trägt der Hintergrund keine Farbe mehr, der Akzent
    /// sitzt ausschließlich am Objekt selbst.
    private var backdrop: some View {
        ZStack {
            Color.black.opacity(0.72)
            BeerStatsColor.backgroundPrimary.opacity(0.93)
            // Sehr dezenter Schein, damit die Mitte nicht tot wirkt.
            RadialGradient(
                colors: [highlight.tint.opacity(0.13), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 240
            )
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var artwork: some View {
        switch highlight.kind {
        case .airball:      ShotGlassArt(isAnimating: isAnimating, reduceMotion: reduceMotion)
        case .ballsBack:    BallsBackArt(isAnimating: isAnimating, reduceMotion: reduceMotion)
        case .bombe:        BombArt(isAnimating: isAnimating, reduceMotion: reduceMotion)
        case .onFire:       FlameArt(isAnimating: isAnimating, reduceMotion: reduceMotion)
        case .reRack:       SpinArt(symbol: "arrow.triangle.2.circlepath", isAnimating: isAnimating, reduceMotion: reduceMotion)
        case .redemption:   SpinArt(symbol: "flame.circle", isAnimating: isAnimating, reduceMotion: reduceMotion)
        case .bounce:       BounceArt(reduceMotion: reduceMotion)
        case .trickshot:    SpinArt(symbol: "tornado", isAnimating: isAnimating, reduceMotion: reduceMotion)
        case .neutral:      EmptyView()
        }
    }
}

// MARK: - Airball: Shotglas, das sich leert und kippt

private struct ShotGlassArt: View {
    let isAnimating: Bool
    let reduceMotion: Bool

    @State private var fill: CGFloat = 0.78
    @State private var tilt: Double = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Die Flüssigkeit ist ein einfaches Rechteck, das auf die
            // Glasform beschnitten wird. Das ist deutlich robuster als eine
            // Maske aus derselben Form über sich selbst.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [BeerStatsColor.accent, Color(red: 0.79, green: 0.46, blue: 0.11)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 68 * fill)
            }
            .frame(width: 54, height: 68)
            .clipShape(ShotGlassShape())

            ShotGlassShape()
                .stroke(BeerStatsColor.textPrimary.opacity(0.75), lineWidth: 2.5)
                .frame(width: 54, height: 68)
        }
        .rotationEffect(.degrees(tilt), anchor: .bottomTrailing)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeIn(duration: 0.5).delay(0.25)) { fill = 0 }
            withAnimation(.easeInOut(duration: 0.4).delay(0.3)) { tilt = -48 }
        }
    }
}

/// Konisches Schnapsglas, oben breiter als unten.
private struct ShotGlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.width * 0.14
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Balls Back: zwei Bälle fliegen zurück

private struct BallsBackArt: View {
    let isAnimating: Bool
    let reduceMotion: Bool

    @State private var lift: CGFloat = 34

    var body: some View {
        HStack(spacing: 22) {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white, Color(white: 0.88), Color(white: 0.66)],
                            center: UnitPoint(x: 0.34, y: 0.3),
                            startRadius: 1,
                            endRadius: 26
                        )
                    )
                    .frame(width: 34, height: 34)
                    .shadow(color: .black.opacity(0.45), radius: 6, y: 4)
                    .offset(y: lift)
                    .animation(ballAnimation(index: index), value: lift)
            }
        }
        .onAppear {
            guard !reduceMotion else { lift = 0; return }
            lift = -12
        }
    }

    /// Explizit typisiert, damit der Compiler den Rückgabetyp des ternären
    /// Ausdrucks nicht erraten muss.
    private func ballAnimation(index: Int) -> Animation? {
        guard !reduceMotion else { return nil }
        return .spring(response: 0.5, dampingFraction: 0.5).delay(Double(index) * 0.1)
    }
}

// MARK: - Bounce: Ball springt auf und in den Becher

/// Der Ball setzt auf der Tischkante auf, springt hoch und fällt in den
/// Becher. Die Stauchung beim Aufkommen macht den Aufprall spürbar – ohne
/// sie wirkt eine Kugel, die sich bewegt, wie ein schwebender Punkt.
private struct BounceArt: View {

    let reduceMotion: Bool

    @State private var phase = 0

    private let path: [(x: CGFloat, y: CGFloat, squash: CGFloat)] = [
        (-46, -26, 1.00),
        (-24,  22, 0.72),   // Aufprall auf dem Tisch
        (  2, -30, 1.06),
        ( 26,  16, 0.80),
        ( 44, -10, 1.00)
    ]

    var body: some View {
        ZStack {
            // Tischkante als Bezugslinie, sonst schwebt der Ball im Nichts.
            Capsule()
                .fill(BeerStatsColor.textSecondary.opacity(0.35))
                .frame(width: 120, height: 3)
                .offset(y: 30)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, Color(white: 0.85), Color(white: 0.62)],
                        center: UnitPoint(x: 0.34, y: 0.3),
                        startRadius: 1,
                        endRadius: 20
                    )
                )
                .frame(width: 26, height: 26)
                .scaleEffect(x: 2 - current.squash, y: current.squash)
                .offset(x: current.x, y: current.y)
                .shadow(color: .black.opacity(0.5), radius: 5, y: 3)
        }
        .onAppear {
            guard !reduceMotion else { phase = path.count - 1; return }
            animateStep()
        }
    }

    private var current: (x: CGFloat, y: CGFloat, squash: CGFloat) {
        path[min(phase, path.count - 1)]
    }

    /// Schritt für Schritt statt einer durchgehenden Kurve: Nur so lässt
    /// sich das harte Aufkommen von der weichen Flugphase unterscheiden.
    private func animateStep() {
        guard phase < path.count - 1 else { return }
        let isImpact = path[phase + 1].squash < 1
        withAnimation(.easeIn(duration: isImpact ? 0.16 : 0.22)) {
            phase += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (isImpact ? 0.16 : 0.22)) {
            animateStep()
        }
    }
}

// MARK: - Bombe: Zünder und Druckwelle

private struct BombArt: View {
    let isAnimating: Bool
    let reduceMotion: Bool

    @State private var blast: CGFloat = 0.3
    @State private var blastOpacity: Double = 0.9
    @State private var shake: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(BeerStatsColor.warning, lineWidth: 3)
                .frame(width: 90, height: 90)
                .scaleEffect(blast)
                .opacity(blastOpacity)

            Text("💣")
                .font(.system(size: 52))
                .offset(x: shake)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.55).delay(0.2)) {
                blast = 2.6
                blastOpacity = 0
            }
            withAnimation(.linear(duration: 0.07).repeatCount(4, autoreverses: true)) {
                shake = 4
            }
        }
    }
}

// MARK: - On Fire: züngelnde Flammen

private struct FlameArt: View {
    let isAnimating: Bool
    let reduceMotion: Bool

    @State private var flicker = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            flame(size: 34, delay: 0.12)
            flame(size: 48, delay: 0)
            flame(size: 34, delay: 0.24)
        }
        .onAppear {
            guard !reduceMotion else { return }
            flicker = true
        }
    }

    private func flame(size: CGFloat, delay: Double) -> some View {
        Text("🔥")
            .font(.system(size: size))
            .scaleEffect(flicker ? 1.18 : 0.9)
            .offset(y: flicker ? -7 : 0)
            .animation(flameAnimation(delay: delay), value: flicker)
    }

    private func flameAnimation(delay: Double) -> Animation? {
        guard !reduceMotion else { return nil }
        return .easeInOut(duration: 0.42).repeatForever(autoreverses: true).delay(delay)
    }
}

// MARK: - Umstellen und Redemption: einfliegendes Symbol

private struct SpinArt: View {
    let symbol: String
    let isAnimating: Bool
    let reduceMotion: Bool

    @State private var angle: Double = -170
    @State private var scale: CGFloat = 0.4

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 52, weight: .semibold))
            .foregroundStyle(BeerStatsColor.accent)
            .rotationEffect(.degrees(angle))
            .scaleEffect(scale)
            .onAppear {
                guard !reduceMotion else { angle = 0; scale = 1; return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    angle = 0
                    scale = 1
                }
            }
    }
}
