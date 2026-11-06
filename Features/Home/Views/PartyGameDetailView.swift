//
//  PartyGameDetailView.swift
//  BeerStats
//
//  Die Seite eines Spiels: Cover, worum es geht, wie lange und mit wie
//  vielen – und "Spielen".
//
//  Die Anleitung liegt hinter "Wie geht's?" unter dem grossen Knopf, nicht
//  als Absatz auf der Seite (6. November: "viel zu viel Text"). Wer sie
//  sucht, findet sie; wer spielen will, liest nicht daran vorbei.
//

import SwiftUI

struct PartyGameDetailView: View {

    let game: PartyGame

    @State private var showsHelp = false

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

                    QuietButton(title: "Wie geht's?", systemImage: "questionmark.circle") {
                        showsHelp = true
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
            .verticalScrollOnly()
        }
        .navigationTitle(game.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsHelp) {
            HowToPlaySheet(game: game)
        }
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
}
