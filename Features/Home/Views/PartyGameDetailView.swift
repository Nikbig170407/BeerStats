//
//  PartyGameDetailView.swift
//  BeerStats
//
//  Die Seite eines Spiels: Cover, worum es geht, wie lange und mit wie
//  vielen, die Anleitung – und "Spielen".
//
//  Ersetzt das Fragezeichen auf den alten Kacheln. Wer eine Anleitung
//  suchte, musste dort genau neben den Weg ins Spiel tippen; hier steht sie
//  einfach da, und der Weg ins Spiel ist der grosse Knopf darueber.
//

import SwiftUI

struct PartyGameDetailView: View {

    let game: PartyGame

    /// Breiter als das wird das Cover nicht – sonst schiebt es auf einem
    /// grossen Geraet "Spielen" unter den Rand.
    private static let coverWidth: CGFloat = 300

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: game.tint)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PartyGameCover(game: game)
                        .frame(maxWidth: Self.coverWidth)
                        .frame(maxWidth: .infinity)

                    Text(game.subtitle)
                        .font(BeerStatsFont.body)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    WrappingRow(spacing: 8, lineSpacing: 8, alignment: .leading) {
                        fact(game.group.emoji, game.group.label)
                        fact("⏱️", game.length.label)
                        fact("👥", "Spieler \(game.playersLabel)")
                    }

                    NavigationLink {
                        game.playScreen
                    } label: {
                        PrimaryButtonLabel(title: "Spielen", systemImage: "play.fill")
                    }
                    .buttonStyle(PressableButtonStyle())

                    rules
                }
                .padding(20)
            }
            .verticalScrollOnly()
        }
        .navigationTitle(game.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fact(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Text(emoji)
            Text(text)
        }
        .font(.scaled(12, weight: .heavy, design: .rounded))
        .foregroundStyle(BeerStatsColor.textPrimary)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(BeerStatsColor.surfaceElevated.opacity(0.7), in: Capsule())
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WIE GEHT DAS?")
                .font(.scaled(12, weight: .heavy, design: .rounded))
                .kerning(1.6)
                .foregroundStyle(BeerStatsColor.textSecondary)
            Text(game.howToPlay)
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Wie hart getrunken wird, stellst du vor dem Spiel ein.")
                .font(.scaled(11, weight: .medium, design: .rounded))
                .foregroundStyle(BeerStatsColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassPanel(cornerRadius: 16)
    }
}
