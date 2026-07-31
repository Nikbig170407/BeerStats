//
//  CupFillGauge.swift
//  BeerStats
//
//  Kennzahl-Anzeige im Becher-Motiv: Der Becher ist bis zum angegebenen
//  Anteil gefüllt, der Wert steht als Prozentzahl darin.
//
//  Nutzt bewusst dieselbe `CupShape` wie der Lade-Indikator. Dadurch bleibt
//  der Becher das durchgängige Signatur-Element der App – im Wartezustand
//  füllt er sich, im Profil zeigt er die Trefferquote.
//

import SwiftUI

struct CupFillGauge: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Füllstand von 0 bis 1.
    let fillLevel: Double
    var size: CGFloat = 120
    var tint: Color = BeerStatsColor.accent
    var caption: String?

    @State private var animatedLevel: CGFloat = 0

    private var cupHeight: CGFloat { size * 1.15 }
    private var clampedLevel: CGFloat { CGFloat(min(max(fillLevel, 0), 1)) }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                CupShape()
                    .fill(tint)
                    .frame(width: size, height: cupHeight)
                    .mask(liquidMask)

                CupShape()
                    .stroke(BeerStatsColor.textSecondary.opacity(0.6), lineWidth: 3)
                    .frame(width: size, height: cupHeight)

                Text(percentText)
                    .font(BeerStatsFont.statValue)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    // Der Text steht auf gefülltem wie leerem Becher – ein
                    // weicher Schatten hält ihn in beiden Fällen lesbar.
                    .shadow(color: BeerStatsColor.backgroundPrimary.opacity(0.8), radius: 4)
            }

            if let caption {
                Text(caption)
                    .font(BeerStatsFont.statLabel)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
        }
        .onAppear {
            guard !reduceMotion else {
                animatedLevel = clampedLevel
                return
            }
            withAnimation(AppAnimation.ambient) { animatedLevel = clampedLevel }
        }
        .onChange(of: clampedLevel) { newValue in
            withAnimation(AppAnimation.standard) { animatedLevel = newValue }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption ?? "Anteil")
        .accessibilityValue(percentText)
    }

    private var percentText: String {
        "\(Int((clampedLevel * 100).rounded()))%"
    }

    private var liquidMask: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LiquidWaveShape(phase: 0.5)
                .frame(height: cupHeight * animatedLevel)
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        CupFillGauge(fillLevel: 0.62, caption: "Trefferquote")
        CupFillGauge(fillLevel: 0.18, size: 90, tint: BeerStatsColor.accentSecondary, caption: "Airball-Anteil")
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BeerStatsColor.backgroundPrimary)
}
