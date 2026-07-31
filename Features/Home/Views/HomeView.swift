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

                    if !viewModel.games.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Deine Spiele")
                                .font(BeerStatsFont.title)
                                .foregroundStyle(BeerStatsColor.textPrimary)

                            ForEach(viewModel.games) { game in
                                NavigationLink {
                                    LobbyView(
                                        gameRepository: container.gameRepository,
                                        gameId: game.id ?? "",
                                        currentUserId: viewModel.currentUserId
                                    )
                                } label: {
                                    gameRow(game)
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        try? container.authRepository.signOut()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(BeerStatsColor.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ProfilesView(
                            repository: container.playerProfileRepository,
                            ownerId: viewModel.currentUserId
                        )
                    } label: {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .foregroundStyle(BeerStatsColor.textPrimary)
                    }
                    .accessibilityLabel("Mitspieler verwalten")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        FriendsView(friendRepository: container.friendRepository, currentUserId: viewModel.currentUserId)
                    } label: {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(BeerStatsColor.textSecondary)
                    }
                    .accessibilityLabel("Freunde")
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BeerStats")
                .font(BeerStatsFont.largeTitle)
                .foregroundStyle(BeerStatsColor.textPrimary)
            Text("Bereit für die nächste Runde?")
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
        .padding(.top, 8)
    }

    private var newGameLink: some View {
        NavigationLink {
            NewGameView(
                gameRepository: container.gameRepository,
                profileRepository: container.playerProfileRepository,
                currentUserId: viewModel.currentUserId
            )
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

    private func gameRow(_ game: Game) -> some View {
        BeerStatsCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.teams.map { $0.playerNames.joined(separator: " & ") }.joined(separator: " vs "))
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                        .lineLimit(1)
                    Text(statusLabel(game.status))
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
        }
    }

    private func statusLabel(_ status: GameStatus) -> String {
        switch status {
        case .lobby: return "Wartet auf Spielstart"
        case .active: return "Läuft"
        case .paused: return "Pausiert"
        case .finished: return "Beendet"
        case .cancelled: return "Abgebrochen"
        }
    }
}
