//
//  PrimaryButton.swift
//  BeerStats
//
//  Primärer Call-to-Action-Button. Große Tap-Fläche für einhändige
//  Bedienung während eines laufenden Spiels (siehe Architektur-Vorgabe
//  „1–2 Sekunden Bedienzeit“), mit Haptik-Feedback beim Tap.
//

import SwiftUI

struct PrimaryButton: View {

    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.lightImpact()
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(BeerStatsFont.headline)
            .foregroundStyle(BeerStatsColor.textOnAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 56) // großzügige Tap-Fläche, siehe Design-Vorgabe "große Buttons"
            .background(BeerStatsColor.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Spiel starten", systemImage: "play.fill") {}
        PrimaryButton(title: "Weiter") {}
    }
    .padding()
    .background(BeerStatsColor.backgroundPrimary)
}
