//
//  LobbyView.swift
//  BeerStats
//
//  Zeigt die beiden Teams und den aktuellen Spielstatus live an. Der
//  Ersteller sieht einen "Spiel starten"-Button; alle anderen Teilnehmer
//  sehen automatisch, sobald gestartet wurde (Echtzeit-Listener).
//

import SwiftUI

struct LobbyView: View {

    @StateObject private var viewModel: LobbyViewModel
    /// Über die Environment statt über den Initialisierer, damit der
    /// aufrufende HomeView-Code unverändert bleibt.
    @Environment(\.appContainer) private var appContainer

    init(gameRepository: GameRepositoryProtocol, gameId: String, currentUserId: String) {
        _viewModel = StateObject(
            wrappedValue: LobbyViewModel(gameRepository: gameRepository, gameId: gameId, currentUserId: currentUserId)
        )
    }

    var body: some View {
        VStack(spacing: 24) {
            if let game = viewModel.game {
                content(for: game)
            } else {
                CupFillLoadingView(size: 72)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Lobby")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(for game: Game) -> some View {
        Text(game.type == .oneVsOne ? "1 vs 1" : "2 vs 2")
            .font(BeerStatsFont.title)
            .foregroundStyle(BeerStatsColor.textPrimary)

        HStack(spacing: 16) {
            teamCard(game.teams.first)
            Text("vs")
                .font(BeerStatsFont.headline)
                .foregroundStyle(BeerStatsColor.textSecondary)
            teamCard(game.teams.last)
        }

        Text(statusLabel(game.status))
            .font(BeerStatsFont.body)
            .foregroundStyle(BeerStatsColor.textSecondary)

        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.error)
        }

        Spacer()

        if viewModel.isCreator && game.status == .lobby {
            if viewModel.isStarting {
                CupFillLoadingView(size: 56)
            } else {
                PrimaryButton(title: "Spiel starten", systemImage: "play.fill") {
                    Task { await viewModel.startGame() }
                }
            }
        } else if game.status == .active {
            NavigationLink {
                LiveGameView(
                    teams: game.teams,
                    format: game.format,
                    playersPerTeam: game.type == .oneVsOne ? 1 : 2,
                    perspectiveTeamIndex: perspectiveTeamIndex(in: game),
                    gameId: viewModel.gameId,
                    throwRepository: appContainer.throwRepository,
                    gameRepository: appContainer.gameRepository,
                    profileRepository: appContainer.playerProfileRepository,
                    ownerId: viewModel.currentUserId
                )
            } label: {
                Text("Live-Tracking öffnen")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(BeerStatsColor.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    /// Das eigene Team gehört nach unten auf den Spielscreen – man tippt auf
    /// die gegnerischen Becher, und die sollen oben liegen.
    private func perspectiveTeamIndex(in game: Game) -> Int {
        game.teams.firstIndex { $0.playerIds.contains(viewModel.currentUserId) } ?? 0
    }

    private func teamCard(_ team: Team?) -> some View {
        BeerStatsCard {
            VStack(spacing: 4) {
                ForEach(team?.playerNames ?? [], id: \.self) { name in
                    Text(name)
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                }
            }
            .frame(minWidth: 100)
        }
    }

    private func statusLabel(_ status: GameStatus) -> String {
        switch status {
        case .lobby: return "Wartet auf Spielstart"
        case .active: return "Spiel läuft"
        case .paused: return "Pausiert"
        case .finished: return "Beendet"
        case .cancelled: return "Abgebrochen"
        }
    }
}
