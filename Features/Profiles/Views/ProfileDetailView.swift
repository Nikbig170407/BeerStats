//
//  ProfileDetailView.swift
//  BeerStats
//
//  Die Statistik eines Mitspielers.
//
//  Aufbau bewusst nach Wichtigkeit statt nach Datenstruktur: Ganz oben die
//  Trefferquote als gefüllter Becher – die eine Zahl, über die am Tisch
//  geredet wird. Danach das Spielergebnis, dann die Spezialwürfe, zuletzt
//  die Serien.
//

import SwiftUI

struct ProfileDetailView: View {

    let profile: PlayerProfile
    let onEdit: () -> Void

    private var stats: UserStatistics { profile.statistics }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                hitRateGauge

                if stats.gamesPlayed == 0 {
                    emptyState
                } else {
                    resultSection
                    arsenalSection
                    streakSection
                }
            }
            .padding(20)
        }
        .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Bearbeiten", action: onEdit)
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.accent)
            }
        }
    }

    // MARK: - Kopf

    private var header: some View {
        VStack(spacing: 10) {
            ProfileAvatarView(profile: profile, size: 88)
            Text(profile.name)
                .font(BeerStatsFont.largeTitle)
                .foregroundStyle(BeerStatsColor.textPrimary)
            if !profile.isActive {
                Text("Spielt aktuell nicht mit")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
        }
        .padding(.top, 8)
    }

    private var hitRateGauge: some View {
        CupFillGauge(
            fillLevel: stats.hitRate,
            size: 132,
            tint: profile.color.color,
            caption: "Trefferquote"
        )
    }

    private var emptyState: some View {
        BeerStatsCard {
            VStack(spacing: 6) {
                Text("Noch kein Spiel gewertet")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text("Sobald \(profile.name) ein Spiel zu Ende gespielt hat, stehen hier die Zahlen.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Abschnitte

    private var resultSection: some View {
        section("Bilanz") {
            HStack(spacing: 12) {
                statTile("\(stats.gamesPlayed)", label: "Spiele")
                statTile("\(stats.gamesWon)", label: "Siege")
                statTile(percent(profile.winRate), label: "Siegquote")
            }
        }
    }

    private var arsenalSection: some View {
        section("Wurf-Arsenal") {
            rowList {
                statRow("Treffer", value: "\(stats.totalHits) von \(stats.totalThrows)")
                divider
                statRow("Bounce Shots", value: "\(stats.totalBounceShotsMade)")
                divider
                statRow("Trickshots", value: "\(stats.totalTrickshotsMade)")
                divider
                statRow("Airballs", value: "\(stats.totalAirballs)", tint: BeerStatsColor.error)
            }
        }
    }

    private var streakSection: some View {
        section("Serien") {
            rowList {
                statRow("Längste On-Fire-Serie", value: "\(stats.longestOnFireStreak)", tint: BeerStatsColor.accent)
                divider
                statRow("Aktuelle Siegesserie", value: "\(stats.currentWinStreak)")
                divider
                statRow("Längste Siegesserie", value: "\(stats.longestWinStreak)")
            }
        }
    }

    /// Eigener Container statt BeerStatsCard: Die Zeilen bringen ihren
    /// Innenabstand selbst mit, damit die Trennlinien über die volle Breite
    /// laufen können.
    private func rowList<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            BeerStatsColor.surfaceElevated,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    // MARK: - Bausteine

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(BeerStatsFont.statLabel)
                .foregroundStyle(BeerStatsColor.accent)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statTile(_ value: String, label: String) -> some View {
        BeerStatsCard {
            VStack(spacing: 4) {
                Text(value)
                    .font(BeerStatsFont.statValue)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text(label)
                    .font(BeerStatsFont.statLabel)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func statRow(_ label: String, value: String, tint: Color = BeerStatsColor.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textSecondary)
            Spacer()
            Text(value)
                .font(BeerStatsFont.statValue)
                .foregroundStyle(tint)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    private var divider: some View {
        Rectangle()
            .fill(BeerStatsColor.textSecondary.opacity(0.12))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
