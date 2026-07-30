//
//  BeerStatsCard.swift
//  BeerStats
//
//  Wiederverwendbarer Karten-Container. Sorgt für konsistente Ecken-
//  radien, Innenabstände und Schattentiefe an allen Stellen der App,
//  an denen Inhalte "erhöht" über dem Hintergrund wirken sollen
//  (Statistik-Kacheln, Spiel-Einträge in der Historie, etc.).
//

import SwiftUI

struct BeerStatsCard<Content: View>: View {

    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(
                BeerStatsColor.surfaceElevated,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
    }
}

#Preview {
    BeerStatsCard {
        VStack(alignment: .leading, spacing: 4) {
            Text("Trefferquote")
                .font(BeerStatsFont.statLabel)
                .foregroundStyle(BeerStatsColor.textSecondary)
            Text("68%")
                .font(BeerStatsFont.statValue)
                .foregroundStyle(BeerStatsColor.textPrimary)
        }
    }
    .padding()
    .background(BeerStatsColor.backgroundPrimary)
}
