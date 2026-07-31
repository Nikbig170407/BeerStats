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

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 14) {
            artwork
                .frame(height: 96)

            Text(highlight.title)
                .font(BeerStatsFont.largeTitle)
                .foregroundStyle(highlight.tint)
                .shadow(color: highlight.tint.opacity(0.7), radius: 18)
                .scaleEffect(isAnimating ? 1 : 0.5)
                .opacity(isAnimating ? 1 : 0)

            Text(highlight.subtitle)
                .font(BeerStatsFont.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .padding(.horizontal, 32)
                .offset(y: isAnimating ? 0 : 12)
                .opacity(isAnimating ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RadialGradient(
                colors: [highlight.tint.opacity(0.28), BeerStatsColor.backgroundPrimary.opacity(0.97)],
                center: .center,
                startRadius: 10,
                endRadius: 380
            )
            .ignoresSafeArea()
        )
        // Darf keine Eingaben schlucken – siehe Kommentar oben.
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { isAnimating = true; return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.55)) { isAnimating = true }
        }
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
            ShotGlassShape()
                .fill(
                    LinearGradient(
                        colors: [BeerStatsColor.accent, Color(red: 0.79, green: 0.46, blue: 0.11)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 54, height: 68 * fill)
                .mask(ShotGlassShape().frame(width: 54, height: 68), alignment: .bottom)

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
                    .animation(
                        reduceMotion
                            ? nil
                            : .spring(response: 0.5, dampingFraction: 0.5).delay(Double(index) * 0.1),
                        value: lift
                    )
            }
        }
        .onAppear {
            guard !reduceMotion else { lift = 0; return }
            lift = -12
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
            .animation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: 0.42).repeatForever(autoreverses: true).delay(delay),
                value: flicker
            )
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
