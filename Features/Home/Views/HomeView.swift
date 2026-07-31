//
//  HomeView.swift
//  BeerStats
//
//  Erster echter Einstiegspunkt nach dem Login. Führt die bisher gebauten
//  Features zusammen: neues Spiel erstellen, Freunde verwalten, laufende
//  Spiele fortsetzen. Statistiken/Ranglisten (Schritt 8/9) und ein
//  eigener Settings-Screen (Schritt 10) folgen später – "Abmelden" lebt
//  bis dahin übergangsweise hier.
//

import SwiftUI

struct HomeView: View {

    @StateObject private var viewModel: HomeViewModel
    private let container: AppContainer
    /// Spiegelt die dauerhaft gespeicherte Einstellung, damit das Symbol in
    /// der Leiste sofort umspringt.
    @State private var isSoundOn = SoundManager.isEnabled

    init(container: AppContainer, currentUserId: String) {
        self.container = container
        _viewModel = StateObject(
            wrappedValue: HomeViewModel(
                gameRepository: container.gameRepository,
                profileRepository: container.playerProfileRepository,
                currentUserId: currentUserId
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    // Bewusst nur das zuletzt begonnene Spiel statt einer
                    // Liste: Es läuft immer höchstens eine Partie, und die
                    // soll nach einem versehentlichen Verlassen weitergehen.
                    if let running = viewModel.resumableGame {
                        resumeLink(for: running)
                    }

                    newGameLink
                    overviewStrip
                    destinationCards
                }
                .padding(20)
            }
            .background(GridBackdrop())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        try? container.authRepository.signOut()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(BeerStatsColor.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isSoundOn.toggle()
                        SoundManager.isEnabled = isSoundOn
                        if isSoundOn { SoundManager.play(.tap) }
                        HapticManager.lightImpact()
                    } label: {
                        Image(systemName: isSoundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .foregroundStyle(isSoundOn ? BeerStatsColor.accent : BeerStatsColor.textSecondary)
                    }
                    .accessibilityLabel(isSoundOn ? "Ton ausschalten" : "Ton einschalten")
                }
                // Mitspieler und Rangliste sind jetzt große Karten im Inhalt –
                // in der Kopfzeile bleiben nur Nebensachen.
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        DeveloperSettingsView(
                            repository: container.playerProfileRepository,
                            ownerId: viewModel.currentUserId
                        )
                    } label: {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundStyle(BeerStatsColor.textSecondary)
                    }
                    .accessibilityLabel("Entwicklereinstellungen")
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            BeerGlassMark(size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("BeerStats")
                    .font(BeerStatsFont.largeTitle)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [BeerStatsColor.textPrimary, BeerStatsColor.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Bereit für die nächste Runde?")
                    .font(BeerStatsFont.body)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private var newGameLink: some View {
        NavigationLink {
            NewGameView(container: container, currentUserId: viewModel.currentUserId)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("Neues Spiel")
            }
            .font(BeerStatsFont.headline)
            .foregroundStyle(BeerStatsColor.textOnAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(BeerStatsColor.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    /// Kennzahlen-Streifen: Gibt dem Startbildschirm Inhalt und zeigt auf
    /// einen Blick, ob überhaupt schon gespielt wurde.
    private var overviewStrip: some View {
        HStack(spacing: 12) {
            overviewTile(
                value: "\(viewModel.activeProfiles.count)",
                label: "Mitspieler",
                tint: BeerStatsColor.accent
            )
            overviewTile(
                value: "\(viewModel.totalGamesTracked)",
                label: "Partien",
                tint: BeerStatsColor.accentSecondary
            )
            overviewTile(
                value: viewModel.leadingProfile?.emoji ?? "–",
                label: viewModel.leadingProfile?.name ?? "Noch offen",
                tint: BeerStatsColor.success
            )
        }
    }

    private func overviewTile(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 25, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(BeerStatsFont.statLabel)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassPanel(cornerRadius: 16)
        .neonEdge(tint, cornerRadius: 16, intensity: 0.35)
    }

    /// Große Einstiege statt kleiner Symbole in der Kopfzeile – die Statistik
    /// ist der zweitwichtigste Ort der App und war vorher nur ein Icon.
    private var destinationCards: some View {
        VStack(spacing: 12) {
            NavigationLink {
                ProfilesView(container: container, ownerId: viewModel.currentUserId)
            } label: {
                destinationCard(
                    title: "Mitspieler & Statistiken",
                    subtitle: "Profile anlegen, Werte ansehen, vergleichen",
                    systemImage: "chart.bar.xaxis",
                    tint: BeerStatsColor.accent
                )
            }
            .buttonStyle(PressableButtonStyle())

            NavigationLink {
                LeaderboardView(profiles: viewModel.profiles)
            } label: {
                destinationCard(
                    title: "Rangliste",
                    subtitle: viewModel.leadingProfile.map { "Aktuell vorn: \($0.name)" }
                        ?? "Noch keine Wertung",
                    systemImage: "trophy.fill",
                    tint: BeerStatsColor.warning
                )
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(viewModel.profiles.isEmpty)
            .opacity(viewModel.profiles.isEmpty ? 0.45 : 1)
        }
    }

    private func destinationCard(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.18))
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text(subtitle)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
        .padding(16)
        .glassPanel()
        .neonEdge(tint, intensity: 0.4)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func resumeLink(for game: Game) -> some View {
        NavigationLink {
            LiveGameView(
                teams: game.teams,
                format: game.format,
                playersPerTeam: game.type == .oneVsOne ? 1 : 2,
                perspectiveTeamIndex: 0,
                gameId: game.id,
                throwRepository: container.throwRepository,
                gameRepository: container.gameRepository,
                profileRepository: container.playerProfileRepository,
                ownerId: viewModel.currentUserId
            )
        } label: {
            BeerStatsCard {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(BeerStatsColor.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spiel fortsetzen")
                            .font(BeerStatsFont.headline)
                            .foregroundStyle(BeerStatsColor.textPrimary)
                        Text(game.teams.map { $0.playerNames.joined(separator: " & ") }.joined(separator: " vs "))
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
