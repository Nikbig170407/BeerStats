//
//  HeadToHeadView.swift
//  BeerStats
//
//  Direktvergleich zweier Mitspieler.
//
//  Ausgewertet werden die abgeschlossenen Spiele. Dabei wird bewusst
//  unterschieden, ob die beiden gegeneinander oder miteinander gespielt
//  haben – ein gemeinsamer Sieg sagt nichts darüber aus, wer von beiden
//  besser ist, und würde die Bilanz sonst verfälschen.
//

import SwiftUI

struct HeadToHeadView: View {

    let left: PlayerProfile
    let right: PlayerProfile
    let gameRepository: GameRepositoryProtocol
    let ownerId: String

    @State private var record = Record()
    @State private var isLoading = true

    /// Ergebnis der Auswertung.
    struct Record: Equatable {
        var duels = 0
        var leftWins = 0
        var rightWins = 0
        var draws = 0
        var together = 0
        var togetherWins = 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                versusHeader

                if isLoading {
                    CupFillLoadingView(size: 64)
                        .padding(.top, 32)
                } else if record.duels == 0 && record.together == 0 {
                    emptyState
                } else {
                    if record.duels > 0 { duelSection }
                    if record.together > 0 { teamSection }
                }
            }
            .padding(20)
        }
        .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Direktvergleich")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: - Kopf

    private var versusHeader: some View {
        HStack(spacing: 12) {
            playerColumn(left, wins: record.leftWins)

            Text("vs")
                .font(BeerStatsFont.headline)
                .foregroundStyle(BeerStatsColor.textSecondary)

            playerColumn(right, wins: record.rightWins)
        }
    }

    private func playerColumn(_ profile: PlayerProfile, wins: Int) -> some View {
        VStack(spacing: 8) {
            ProfileAvatarView(profile: profile, size: 68)
            Text(profile.name)
                .font(BeerStatsFont.headline)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .lineLimit(1)
            if !isLoading && record.duels > 0 {
                Text("\(wins)")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(isLeading(wins: wins) ? BeerStatsColor.accent : BeerStatsColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func isLeading(wins: Int) -> Bool {
        wins > 0 && wins == max(record.leftWins, record.rightWins) && record.leftWins != record.rightWins
    }

    // MARK: - Abschnitte

    private var duelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Gegeneinander")
            BeerStatsCard {
                VStack(spacing: 12) {
                    balanceBar
                    HStack {
                        Text("\(record.duels) Duelle")
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                        Spacer()
                        if record.draws > 0 {
                            Text("\(record.draws) unentschieden")
                                .font(BeerStatsFont.caption)
                                .foregroundStyle(BeerStatsColor.textSecondary)
                        }
                    }
                }
            }
        }
    }

    /// Zeigt das Kräfteverhältnis als geteilter Balken – schneller erfassbar
    /// als zwei Zahlen nebeneinander.
    private var balanceBar: some View {
        GeometryReader { geometry in
            let decided = max(record.leftWins + record.rightWins, 1)
            let leftWidth = geometry.size.width * CGFloat(record.leftWins) / CGFloat(decided)

            HStack(spacing: 0) {
                Rectangle().fill(left.color.color).frame(width: leftWidth)
                Rectangle().fill(right.color.color)
            }
            .clipShape(Capsule())
        }
        .frame(height: 14)
    }

    private var teamSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Zusammen im Team")
            BeerStatsCard {
                HStack {
                    Text("\(record.together) Spiele")
                        .font(BeerStatsFont.body)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                    Spacer()
                    Text("\(record.togetherWins) gewonnen")
                        .font(BeerStatsFont.statValue)
                        .foregroundStyle(BeerStatsColor.accent)
                }
            }
        }
    }

    private var emptyState: some View {
        BeerStatsCard {
            VStack(spacing: 6) {
                Text("Noch kein gemeinsames Spiel")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text("Sobald \(left.name) und \(right.name) zusammen oder gegeneinander gespielt haben, steht hier die Bilanz.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(BeerStatsFont.statLabel)
            .foregroundStyle(BeerStatsColor.accent)
    }

    // MARK: - Auswertung

    private func load() async {
        guard let leftId = left.id, let rightId = right.id else {
            isLoading = false
            return
        }
        defer { isLoading = false }

        do {
            let games = try await gameRepository.fetchFinishedGames(userId: ownerId)
            record = Self.evaluate(games: games, leftId: leftId, rightId: rightId)
        } catch {
            AppLogger.firestore.error("Direktvergleich konnte nicht geladen werden: \(error.localizedDescription)")
        }
    }

    /// Reine Auswertung ohne Firestore – dadurch für sich prüfbar.
    static func evaluate(games: [Game], leftId: String, rightId: String) -> Record {
        var record = Record()

        for game in games {
            guard let leftTeam = game.teams.firstIndex(where: { $0.playerIds.contains(leftId) }),
                  let rightTeam = game.teams.firstIndex(where: { $0.playerIds.contains(rightId) })
            else { continue }

            let winningTeam = game.winnerTeamId.flatMap { winnerId in
                game.teams.firstIndex { $0.id == winnerId }
            }

            if leftTeam == rightTeam {
                record.together += 1
                if winningTeam == leftTeam { record.togetherWins += 1 }
            } else {
                record.duels += 1
                switch winningTeam {
                case leftTeam:  record.leftWins += 1
                case rightTeam: record.rightWins += 1
                default:        record.draws += 1
                }
            }
        }

        return record
    }
}
