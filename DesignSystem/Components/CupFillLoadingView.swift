//
//  CupFillLoadingView.swift
//  BeerStats
//
//  Das visuelle Signatur-Element der App: ein Becher, der sich mit Bier
//  füllt, mit einer sanft schwankenden Oberfläche. Ersetzt den generischen
//  ProgressView an zentralen Warte-Stellen (App-Start, Lade-Zustände) und
//  stellt eine klare, thematische Verbindung zum Beerpong-Kontext her,
//  statt eines austauschbaren Kreis-Spinners.
//
//  Bewusst zurückhaltend gehalten (kein Konfetti, keine Bläschen-Partikel):
//  ein ruhiges, einzelnes bewegtes Detail statt mehrerer gleichzeitiger
//  Effekte. Respektiert außerdem "Reduce Motion".
//

import SwiftUI

struct CupFillLoadingView: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var fillLevel: CGFloat = 0.12
    @State private var wavePhase: CGFloat = 0

    var size: CGFloat = 88

    private var cupHeight: CGFloat { size * 1.15 }

    var body: some View {
        ZStack {
            // Flüssigkeit: gefüllte Becherform, von unten maskiert bis zur aktuellen Füllhöhe
            CupShape()
                .fill(BeerStatsColor.accent)
                .frame(width: size, height: cupHeight)
                .mask(liquidMask)

            // Becher-Umriss, immer sichtbar
            CupShape()
                .stroke(BeerStatsColor.textSecondary, lineWidth: 3)
                .frame(width: size, height: cupHeight)
        }
        .onAppear(perform: startAnimating)
    }

    private var liquidMask: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LiquidWaveShape(phase: wavePhase)
                .frame(height: cupHeight * fillLevel)
        }
    }

    private func startAnimating() {
        guard !reduceMotion else {
            // Statt Animation: ruhiger, statisch halb gefüllter Becher.
            fillLevel = 0.6
            return
        }
        withAnimation(AppAnimation.ambient.repeatForever(autoreverses: true)) {
            fillLevel = 0.7
        }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            wavePhase = 1
        }
    }
}

/// Trapezförmiger Becher-Umriss – die typische Form eines Beerpong-Bechers,
/// oben breiter als unten.
private struct CupShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topInset = rect.width * 0.08
        let bottomInset = rect.width * 0.22

        path.move(to: CGPoint(x: rect.minX + topInset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topInset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - bottomInset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bottomInset, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Leicht wellige Oberkante der Flüssigkeit – das eine bewusst gewählte,
/// bewegte Detail dieser Ansicht.
private struct LiquidWaveShape: Shape {
    var phase: CGFloat // 0...1

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let waveHeight: CGFloat = 4
        let midY = rect.minY + waveHeight
        let controlY = midY + waveHeight - (phase * waveHeight * 2)

        path.move(to: CGPoint(x: rect.minX, y: midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: midY),
            control: CGPoint(x: rect.midX, y: controlY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    CupFillLoadingView()
        .padding(40)
        .background(BeerStatsColor.backgroundPrimary)
}
