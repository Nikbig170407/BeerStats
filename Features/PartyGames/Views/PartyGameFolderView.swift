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

    /// Die Anleitung – auf Anforderung, nicht im Weg.
    @State private var showsRules = false

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

                Spacer(minLength: 0)

                // Das Fragezeichen liegt NEBEN dem Weg ins Spiel, nicht
                // darin: Wer eine Anleitung sucht, will nicht erst das Spiel
                // starten – und wer spielen will, soll nicht danebentippen.
                Button {
                    showsRules = true
                    HapticManager.lightImpact()
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 19))
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())

                Image(systemName: "chevron.right")
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            .padding(16)
            .glassPanel()
            .neonEdge(game.tint, intensity: 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .sheet(isPresented: $showsRules) {
            PartyGameRulesView(game: game)
        }
    }
}

/// Wie ein Partyspiel gespielt wird.
///
/// Bis Oktober 2026 hatte nur Beerpong einen Regel-Screen. Die neunzehn
/// Partyspiele erklaerten sich im Spiel selbst – wer neu am Tisch stand,
/// musste fragen, und wer die Regeln kannte, musste sie neunzehnmal
/// erzaehlen.
struct PartyGameRulesView: View {

    let game: PartyGame

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdrop(glow: game.tint)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(game.emoji).font(.system(size: 48))

                        Text(game.title)
                            .font(BeerStatsFont.title)
                            .foregroundStyle(BeerStatsColor.textPrimary)

                        Text(game.subtitle)
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(game.howToPlay)
                            .font(BeerStatsFont.body)
                            .foregroundStyle(BeerStatsColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassPanel(cornerRadius: 16)

                        Text("Die Trinkmengen richten sich nach der eingestellten Härte – nachzulesen und zu ändern in den Einstellungen.")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(BeerStatsColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(22)
                }
                .verticalScrollOnly()
            }
            .navigationTitle("Wie geht das?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(game.tint)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
