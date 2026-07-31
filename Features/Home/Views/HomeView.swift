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
            wrappedValue: HomeViewModel(gameRepository: container.gameRepository, currentUserId: currentUserId)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    newGameLink

                    // Bewusst nur das zuletzt begonnene Spiel statt einer
                    // Liste: Es läuft immer höchstens eine Partie, und die
                    // soll nach einem versehentlichen Verlassen weitergehen.
                    if let running = viewModel.resumableGame {
                        resumeLink(for: running)
                    }
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
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ProfilesView(container: container, ownerId: viewModel.currentUserId)
                    } label: {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .foregroundStyle(BeerStatsColor.textPrimary)
                    }
                    .accessibilityLabel("Mitspieler verwalten")
                }
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
