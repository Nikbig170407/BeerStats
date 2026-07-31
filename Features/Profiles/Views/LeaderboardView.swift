//
//  LeaderboardView.swift
//  BeerStats
//
//  Rangliste über alle Mitspieler.
//
//  Die Sortierung ist umschaltbar, weil es keine einzig richtige Antwort
//  auf „wer ist der Beste" gibt: Wer viel spielt, sammelt Siege; wer selten
//  spielt, kann trotzdem die bessere Quote haben. Beide Sichten
//  nebeneinander sind ehrlicher als eine erfundene Gesamtwertung.
//
//  Profile ohne gewertetes Spiel bleiben unten und ohne Platzierung – eine
//  Trefferquote von 0 % würde sonst wie ein schlechtes Ergebnis aussehen,
//  obwohl schlicht keine Daten vorliegen.
//

import SwiftUI

struct LeaderboardView: View {

    let profiles: [PlayerProfile]

    @State private var metric: Metric = .wins

    enum Metric: String, CaseIterable, Identifiable {
        case wins, hitRate, games

        var id: String { rawValue }

        var title: String {
            switch self {
            case .wins: return "Siege"
            case .hitRate: return "Trefferquote"
            case .games: return "Spiele"
            }
        }
    }

    /// Nur Profile mit mindestens einem gewerteten Spiel werden platziert.
    private var ranked: [PlayerProfile] {
        let rated = profiles.filter { $0.statistics.gamesPlayed > 0 }
        switch metric {
        case .wins:
            return rated.sorted {
                ($0.statistics.gamesWon, $0.winRate) > ($1.statistics.gamesWon, $1.winRate)
            }
        case .hitRate:
            return rated.sorted { $0.statistics.hitRate > $1.statistics.hitRate }
        case .games:
            return rated.sorted { $0.statistics.gamesPlayed > $1.statistics.gamesPlayed }
        }
    }

    private var unrated: [PlayerProfile] {
        profiles.filter { $0.statistics.gamesPlayed == 0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Picker("Wertung", selection: $metric) {
                    ForEach(Metric.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 4)

                if ranked.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(ranked.enumerated()), id: \.element.id) { position, profile in
                        row(profile, position: position)
                    }
                }

                if !unrated.isEmpty {
                    Text("Noch ohne gewertetes Spiel")
                        .font(BeerStatsFont.statLabel)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)

                    ForEach(unrated) { profile in
                        row(profile, position: nil)
                    }
                }
            }
            .padding(20)
            .animation(AppAnimation.standard, value: metric)
        }
        .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Rangliste")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        BeerStatsCard {
            VStack(spacing: 6) {
                Text("Noch keine Wertung")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text("Sobald das erste Spiel zu Ende gespielt ist, steht hier eine Rangliste.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func row(_ profile: PlayerProfile, position: Int?) -> some View {
        BeerStatsCard {
            HStack(spacing: 14) {
                rankBadge(position)
                ProfileAvatarView(profile: profile, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                        .lineLimit(1)
                    Text(subtitle(for: profile))
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }

                Spacer()

                Text(primaryValue(for: profile))
                    .font(BeerStatsFont.statValue)
                    .foregroundStyle(position == nil ? BeerStatsColor.textSecondary : BeerStatsColor.accent)
            }
        }
    }

    /// Die ersten drei bekommen eine Medaille, danach die schlichte Zahl.
    @ViewBuilder
    private func rankBadge(_ position: Int?) -> some View {
        if let position {
            switch position {
            case 0: Text("🥇").font(.system(size: 24)).frame(width: 30)
            case 1: Text("🥈").font(.system(size: 24)).frame(width: 30)
            case 2: Text("🥉").font(.system(size: 24)).frame(width: 30)
            default:
                Text("\(position + 1)")
                    .font(BeerStatsFont.statValue)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .frame(width: 30)
            }
        } else {
            Text("–")
                .font(BeerStatsFont.statValue)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .frame(width: 30)
        }
    }

    private func primaryValue(for profile: PlayerProfile) -> String {
        let stats = profile.statistics
        switch metric {
        case .wins: return "\(stats.gamesWon)"
        case .hitRate: return "\(Int((stats.hitRate * 100).rounded()))%"
        case .games: return "\(stats.gamesPlayed)"
        }
    }

    private func subtitle(for profile: PlayerProfile) -> String {
        let stats = profile.statistics
        guard stats.gamesPlayed > 0 else { return "Noch kein Spiel" }
        let winRate = Int((profile.winRate * 100).rounded())
        return "\(stats.gamesPlayed) Spiele · \(winRate)% gewonnen"
    }
}
