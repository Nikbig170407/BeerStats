//
//  SecondaryButton.swift
//  BeerStats
//
//  Zweitrangige Aktion neben einem PrimaryButton (z. B. "Abbrechen" neben
//  "Spiel starten"). Bewusst zurückhaltend gestaltet (Outline statt Fläche),
//  damit die visuelle Hierarchie zum PrimaryButton klar bleibt.
//

import SwiftUI

struct SecondaryButton: View {

    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.lightImpact()
            action()
        } label: {
            Text(title)
                .font(BeerStatsFont.headline)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BeerStatsColor.textSecondary.opacity(0.4), lineWidth: 1.5)
                )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    SecondaryButton(title: "Abbrechen") {}
        .padding()
        .background(BeerStatsColor.backgroundPrimary)
}
