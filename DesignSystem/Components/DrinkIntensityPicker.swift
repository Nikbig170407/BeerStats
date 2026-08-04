//
//  DrinkIntensityPicker.swift
//  BeerStats
//
//  Die Haerte-Wahl als eigene Komponente.
//
//  Sie steht im Hauptmenue und nicht in jedem Spiel: Die Einstellung gilt
//  fuer den Abend, nicht fuer die Runde. In jedem Spiel dieselbe Zeile zu
//  wiederholen waere derselbe Schalter an sechs Stellen – und sechs Stellen,
//  an denen man ihn vergessen kann.
//

import SwiftUI

struct DrinkIntensityPicker: View {

    /// Eigener Zustand, weil `DrinkIntensity.current` in UserDefaults liegt
    /// und SwiftUI Aenderungen dort nicht von sich aus bemerkt.
    @State private var selection = DrinkIntensity.current

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HÄRTE")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .kerning(1.8)
                .foregroundStyle(BeerStatsColor.textSecondary)

            HStack(spacing: 8) {
                ForEach(DrinkIntensity.allCases) { intensity in
                    option(intensity)
                }
            }

            Text(selection.subtitle)
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .animation(AppAnimation.standard, value: selection)
        }
    }

    private func option(_ intensity: DrinkIntensity) -> some View {
        let isOn = selection == intensity

        return Button {
            selection = intensity
            DrinkIntensity.current = intensity
            HapticManager.lightImpact()
            SoundManager.play(.tap)
        } label: {
            VStack(spacing: 3) {
                Text(intensity.emoji).font(.system(size: 20))
                Text(intensity.title)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(isOn ? BeerStatsColor.textOnAccent : BeerStatsColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isOn ? BeerStatsColor.accent : BeerStatsColor.surfaceElevated.opacity(0.6),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
