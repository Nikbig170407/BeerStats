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
///
/// Nicht `private`, weil `CupFillGauge` dieselbe Form als Kennzahl-Anzeige
/// wiederverwendet. Ein zweiter, leicht abweichender Becher-Umriss im
/// Projekt wäre genau die Art Dopplung, die das Design-System vermeiden soll.
struct CupShape: Shape {

    /// Wie weit der Rand oben und unten eingerueckt ist, als Anteil der
    /// Breite. Hier benannt und nicht nur in `path`, weil das Bierglas im
    /// Logo seinen Schaum genau so breit zeichnen muss wie den Becher an der
    /// Stelle (`width(_:atDepth:)`).
    static let topInsetFraction: CGFloat = 0.08
    static let bottomInsetFraction: CGFloat = 0.22

    /// Wie breit der Becher in einer bestimmten Tiefe ist – 0 am Rand, 1 am
    /// Boden. Gemessen von Strichmitte zu Strichmitte.
    static func width(_ breite: CGFloat, atDepth tiefe: CGFloat) -> CGFloat {
        let einzug = topInsetFraction + (bottomInsetFraction - topInsetFraction) * tiefe
        return breite * (1 - 2 * einzug)
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topInset = rect.width * Self.topInsetFraction
        let bottomInset = rect.width * Self.bottomInsetFraction

        path.move(to: CGPoint(x: rect.minX + topInset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topInset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - bottomInset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bottomInset, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Leicht wellige Oberkante der Flüssigkeit – das eine bewusst gewählte,
/// bewegte Detail dieser Ansicht. Wird von `CupFillGauge` mitbenutzt.
struct LiquidWaveShape: Shape {
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
