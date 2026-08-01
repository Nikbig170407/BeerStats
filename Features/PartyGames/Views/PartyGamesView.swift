//
//  PartyGamesView.swift
//  BeerStats
//
//  Sammelpunkt für die Spiele, die auf dem Handy selbst gespielt werden.
//
//  Absichtlich getrennt vom Beerpong-Teil: Diese Spiele zahlen nicht auf
//  die Wurf-Statistiken ein. Eine Runde Bombe hat keine Trefferquote, und
//  sie in dieselben Zahlen zu mischen würde die Beerpong-Auswertung
//  verfälschen.
//

import SwiftUI

struct PartyGamesView: View {

    var body: some View {
        ZStack {
            GridBackdrop()

            ScrollView {
                VStack(spacing: 14) {
                    Text("Für zwischendurch – gespielt wird auf dem Handy, das reihum geht.")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)

                    NavigationLink {
                        BombPassView()
                    } label: {
                        gameCard(
                            emoji: "💣",
                            title: "Bombe weitergeben",
                            subtitle: "Zünden, herumreichen, nicht drauf sitzen bleiben",
                            tint: BeerStatsColor.accentSecondary
                        )
                    }
                    .buttonStyle(PressableButtonStyle())

                    NavigationLink {
                        NeverHaveIEverView()
                    } label: {
                        gameCard(
                            emoji: "🍻",
                            title: "Ich hab noch nie",
                            subtitle: "60 Karten in drei Stufen",
                            tint: BeerStatsColor.success
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(20)
            }
        }
        .navigationTitle("Partyspiele")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func gameCard(emoji: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: 16) {
            Text(emoji)
                .font(.system(size: 34))
                .frame(width: 56, height: 56)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text(subtitle)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
        .padding(16)
        .glassPanel()
        .neonEdge(tint, intensity: 0.4)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
