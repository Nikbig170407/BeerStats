//
//  CupHeatmapView.swift
//  BeerStats
//
//  Zeigt, auf welche Becher ein Spieler am häufigsten trifft.
//
//  Die Auswertung stammt aus dem Wurf-Log: Jeder Treffer hält fest, welcher
//  Becher gefallen ist. Daraus wird sichtbar, ob jemand immer dieselbe Ecke
//  anvisiert – eine Auswertung, die es kaum eine App sonst gibt, weil dafür
//  ein Ereignis-Log statt bloßer Summen nötig ist.
//

import SwiftUI

struct CupHeatmapView: View {

    let profile: PlayerProfile
    let gameRepository: GameRepositoryProtocol
    let throwRepository: ThrowRepositoryProtocol
    let ownerId: String

    @State private var heatmap = CupHeatmap()
    @State private var isLoading = true
    @State private var errorMessage: String?

    /// Mehr Partien bringen kaum bessere Aussagen, kosten aber je eine
    /// Abfrage – deshalb gedeckelt.
    private static let maximumGames = 25

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header

                if isLoading {
                    CupFillLoadingView(size: 64).padding(.top, 30)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.error)
                } else if heatmap.totalHits == 0 {
                    emptyState
                } else {
                    rack
                    legend
                    footnote
                }
            }
            .padding(20)
        }
        .background(GridBackdrop())
        .navigationTitle("Trefferbild")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            ProfileAvatarView(profile: profile, size: 64)
            Text(profile.name)
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
        }
    }

    /// Das Rack in der Ausgangsaufstellung, eingefärbt nach Trefferhäufigkeit.
    private var rack: some View {
        let layout = RackLayout(cupCount: heatmap.cupCount)

        return VStack(spacing: -6) {
            ForEach(Array(layout.rows.indices), id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(Array(layout.indices(inRow: row)), id: \.self) { index in
                        cupCell(index: index)
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func cupCell(index: Int) -> some View {
        let hits = heatmap.hitsByCupIndex[index] ?? 0
        let intensity = heatmap.intensity(forCup: index)

        return ZStack {
            Circle()
                .fill(BeerStatsColor.cupBase.opacity(0.12 + 0.88 * intensity))
            Circle()
                .strokeBorder(
                    BeerStatsColor.cupRimEdge.opacity(0.35 + 0.65 * intensity),
                    lineWidth: 1.5
                )
            Text("\(hits)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(intensity > 0.45 ? .white : BeerStatsColor.textSecondary)
        }
        .frame(width: 46, height: 46)
        .shadow(color: BeerStatsColor.cupBase.opacity(intensity * 0.7), radius: 10)
    }

    private var legend: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(0..<10, id: \.self) { step in
                    Rectangle()
                        .fill(BeerStatsColor.cupBase.opacity(0.12 + 0.88 * Double(step) / 9))
                        .frame(height: 10)
                }
            }
            .clipShape(Capsule())

            HStack {
                Text("selten")
                Spacer()
                Text("\(heatmap.maximumHits)× am häufigsten")
                Spacer()
                Text("oft")
            }
            .font(BeerStatsFont.statLabel)
            .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    private var footnote: some View {
        VStack(spacing: 6) {
            Text("\(heatmap.totalHits) Treffer aus \(heatmap.consideredGames) Partien")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)

            if heatmap.ignoredAfterReRack > 0 {
                // Ehrlichkeit statt schöner Zahl: Nach einem Umstellen meint
                // derselbe Platz eine andere Stelle auf dem Tisch.
                Text("\(heatmap.ignoredAfterReRack) Treffer nach einem Umstellen sind nicht enthalten, weil die Becher danach woanders standen.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("🎯").font(.system(size: 44))
            Text("Noch keine Treffer erfasst")
                .font(BeerStatsFont.headline)
                .foregroundStyle(BeerStatsColor.textPrimary)
            Text("Nach ein paar beendeten Partien zeigt sich hier, auf welche Becher \(profile.name) am liebsten wirft.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }

    private func load() async {
        defer { isLoading = false }
        guard let profileId = profile.id else { return }
        do {
            let games = try await gameRepository.fetchFinishedGames(userId: ownerId)
            heatmap = try await throwRepository.cupHeatmap(
                games: games,
                profileId: profileId,
                limit: Self.maximumGames
            )
        } catch {
            errorMessage = AppError.from(error).errorDescription
        }
    }
}
