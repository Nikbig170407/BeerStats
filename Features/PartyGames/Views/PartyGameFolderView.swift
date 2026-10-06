//
//  PartyGameFolderView.swift
//  BeerStats
//
//  Die Spiele einer Gruppe.
//
//  Neunzehn Kacheln untereinander waren eine Liste, durch die man scrollt,
//  bis man das Richtige sieht – und bei neunzehn sieht man es nicht mehr.
//  Vier Ordner sind dagegen eine Frage, die man am Tisch ohnehin stellt:
//  Karten in der Mitte, oder reden, oder schnell was zwischendurch?
//
//  Der Ordner selbst ist absichtlich dumm: Er zeigt die Spiele seiner
//  Gruppe und sonst nichts. Die Liste kommt aus `PartyGame.Group.games`,
//  nicht aus dieser Datei – ein neues Spiel taucht hier also von selbst
//  auf, sobald es im Katalog steht.
//

import SwiftUI

struct PartyGameFolderView: View {

    let group: PartyGame.Group

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: group.tint)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(group.games) { game in
                        PartyGameCard(game: game)
                    }
                }
                .padding(20)
            }
            .verticalScrollOnly()
        }
        .navigationTitle(group.label)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Eine Spielkachel samt Weg ins Spiel.
///
/// Stand vorher als zwei Funktionen in `HomeView`. Jetzt brauchen sie zwei
/// Screens – der Ordner und „Zuletzt gespielt" –, und zwei Kopien waeren
/// zwei Stellen, an denen man das Vermerken vergisst.
struct PartyGameCard: View {

    let game: PartyGame

    var body: some View {
        NavigationLink {
            // Vermerkt wird beim Erscheinen, nicht beim Antippen: Wer sich
            // vertippt und sofort zurückgeht, hat nicht gespielt.
            game.destination
                .onAppear {
                    RecentPartyGames.record(game)
                    // Tut nichts, wenn kein Abend laeuft – deshalb steht der
                    // Aufruf hier ohne Abfrage.
                    EveningLog.record(partyGame: game)
                }
        } label: {
            HStack(spacing: 16) {
                Text(game.emoji)
                    .font(.system(size: 32))
                    .frame(width: 54, height: 54)
                    .background(
                        game.tint.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(game.title)
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                    Text(game.subtitle)
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
            .neonEdge(game.tint, intensity: 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
