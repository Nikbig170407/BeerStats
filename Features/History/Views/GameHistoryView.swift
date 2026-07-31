//
//  GameHistoryView.swift
//  BeerStats
//
//  Vergangene Partien mit Aufstellung, Ergebnis und Datum.
//
//  Macht aus Zählwerten eine Geschichte: Eine Trefferquote von 61 Prozent
//  sagt wenig, „letzten Freitag 3:1 gegen Tom" dagegen viel. Deshalb steht
//  hier das einzelne Spiel im Vordergrund und nicht die Summe.
//

import SwiftUI

struct GameHistoryView: View {

    let gameRepository: GameRepositoryProtocol
    let ownerId: String

    @State private var games: [Game] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if isLoading {
                    CupFillLoadingView(size: 64).padding(.top, 40)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.error)
                        .padding(.top, 40)
                } else if games.isEmpty {
                    emptyState
                } else {
                    ForEach(games) { game in
                        row(for: game)
                    }
                }
            }
            .padding(20)
        }
        .background(GridBackdrop())
        .navigationTitle("Spielverlauf")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🕗").font(.system(size: 44))
            Text("Noch keine beendete Partie")
                .font(BeerStatsFont.headline)
                .foregroundStyle(BeerStatsColor.textPrimary)
            Text("Sobald ihr ein Spiel zu Ende gespielt und das Ergebnis übernommen habt, steht es hier.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 40)
    }

    private func row(for game: Game) -> some View {
        let winnerIndex = game.winnerTeamId.flatMap { id in
            game.teams.firstIndex { $0.id == id }
        }

        return VStack(spacing: 10) {
            HStack(alignment: .top) {
                teamColumn(game.teams.first, isWinner: winnerIndex == 0, alignment: .leading)

                VStack(spacing: 3) {
                    Text(scoreText(for: game))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(BeerStatsColor.textPrimary)
                    Text(winnerIndex == nil ? "unentschieden" : "Becher")
                        .font(BeerStatsFont.statLabel)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
                .frame(width: 92)

                teamColumn(game.teams.last, isWinner: winnerIndex == 1, alignment: .trailing)
            }

            HStack {
                Text(game.type == .oneVsOne ? "1 vs 1" : "2 vs 2")
                Spacer()
                Text(dateText(for: game))
            }
            .font(BeerStatsFont.caption)
            .foregroundStyle(BeerStatsColor.textSecondary)
        }
        .padding(16)
        .glassPanel()
        .neonEdge(
            winnerIndex == nil ? BeerStatsColor.textSecondary : BeerStatsColor.accent,
            intensity: 0.3
        )
    }

    private func teamColumn(_ team: Team?, isWinner: Bool, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            ForEach(team?.playerNames ?? [], id: \.self) { name in
                Text(name)
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(isWinner ? BeerStatsColor.accent : BeerStatsColor.textSecondary)
                    .lineLimit(1)
            }
            if isWinner {
                Text("🏆").font(.system(size: 13))
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    /// Wie viele Becher noch standen – der Abstand am Ende ist das, woran
    /// man sich erinnert.
    private func scoreText(for game: Game) -> String {
        let remaining = game.teams.map { game.cupsRemaining[$0.id] ?? 0 }
        guard remaining.count == 2 else { return "–" }
        return "\(remaining[0]) : \(remaining[1])"
    }

    private func dateText(for game: Game) -> String {
        guard let date = game.endedAt ?? game.createdAt else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE, d. MMM"
        return formatter.string(from: date)
    }

    private func load() async {
        defer { isLoading = false }
        do {
            games = try await gameRepository.fetchFinishedGames(userId: ownerId)
        } catch {
            errorMessage = AppError.from(error).errorDescription
        }
    }
}
