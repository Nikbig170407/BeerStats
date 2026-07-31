//
//  BeerGlassMark.swift
//  BeerStats
//
//  Gefülltes Bierglas als Bildmarke – für Kopfbereiche, in denen ein
//  ruhendes Symbol gebraucht wird.
//
//  Nutzt dieselbe `CupShape` wie Ladeanzeige und Kennzahl-Becher. Ein
//  SF-Symbol täte es zwar auch, aber der Becher ist das wiedererkennbare
//  Element der App und taucht so vom Login bis zum Spielscreen durchgängig
//  auf.
//

import SwiftUI

struct BeerGlassMark: View {

    var size: CGFloat = 56
    var fillLevel: CGFloat = 0.72

    private var height: CGFloat { size * 1.15 }

    var body: some View {
        ZStack {
            // Bier
            CupShape()
                .fill(
                    LinearGradient(
                        colors: [BeerStatsColor.accent, Color(red: 0.76, green: 0.44, blue: 0.10)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: height)
                .mask(alignment: .bottom) {
                    Rectangle().frame(height: height * fillLevel)
                }

            // Schaumkrone auf der Füllhöhe
            Ellipse()
                .fill(Color(white: 0.97))
                .frame(width: size * 0.74, height: size * 0.16)
                .offset(y: height * (0.5 - fillLevel) - height * 0.5 + size * 0.08)

            CupShape()
                .stroke(BeerStatsColor.textSecondary.opacity(0.7), lineWidth: 2.5)
                .frame(width: size, height: height)
        }
        .frame(width: size, height: height)
        .shadow(color: BeerStatsColor.accent.opacity(0.45), radius: 14)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 28) {
        BeerGlassMark()
        BeerGlassMark(size: 88, fillLevel: 0.5)
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BeerStatsColor.backgroundPrimary)
}
