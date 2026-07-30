//
//  NewGameView.swift
//  BeerStats
//
//  Modus wählen (1v1/2v2), Mitspieler aus der Freundesliste antippen,
//  Spiel erstellen. Nach erfolgreicher Erstellung automatischer Übergang
//  zur Lobby.
//

import SwiftUI

struct NewGameView: View {

    @StateObject private var viewModel: NewGameViewModel
    private let gameRepository: GameRepositoryProtocol
    private let currentUserId: String

    init(
        gameRepository: GameRepositoryProtocol,
        friendRepository: FriendRepositoryProtocol,
        userService: UserServiceProtocol,
        currentUserId: String
    ) {
        self.gameRepository = gameRepository
        self.currentUserId = currentUserId
        _viewModel = StateObject(
            wrappedValue: NewGameViewModel(
                gameRepository: gameRepository,
                friendRepository: friendRepository,
                userService: userService,
                currentUserId: currentUserId
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Picker("Spielmodus", selection: $viewModel.gameType) {
                    Text("1 vs 1").tag(GameType.oneVsOne)
                    Text("2 vs 2").tag(GameType.twoVsTwo)
                }
                .pickerStyle(.segmented)

                if viewModel.isLoadingFriends {
                    CupFillLoadingView(size: 48)
                        .frame(maxWidth: .infinity)
                } else if viewModel.friends.isEmpty {
                    Text("Du hast noch keine Freunde hinzugefügt. Geh dafür zuerst in den Freunde-Bereich.")
                        .font(BeerStatsFont.body)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                } else {
                    if viewModel.gameType == .twoVsTwo {
                        pickerSection(
                            title: "Dein Partner",
                            users: viewModel.friends,
                            isSelected: { $0 == viewModel.teammateId },
                            onTap: { userId in
                                viewModel.teammateId = (viewModel.teammateId == userId) ? nil : userId
                            }
                        )
                    }

                    pickerSection(
                        title: viewModel.gameType == .oneVsOne ? "Gegner" : "Gegner (2 auswählen)",
                        users: viewModel.availableOpponents,
                        isSelected: { viewModel.opponentIds.contains($0) },
                        onTap: { viewModel.toggleOpponent($0) }
                    )
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.error)
                }

                if viewModel.isCreating {
                    CupFillLoadingView(size: 56)
                        .frame(maxWidth: .infinity)
                } else {
                    PrimaryButton(title: "Spiel erstellen", systemImage: "sportscourt.fill") {
                        Task { await viewModel.createGame() }
                    }
                    .opacity(viewModel.canCreateGame ? 1 : 0.4)
                    .disabled(!viewModel.canCreateGame)
                }
            }
            .padding(20)
        }
        .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Neues Spiel")
        .task { await viewModel.loadFriends() }
        .navigationDestination(isPresented: isShowingLobby) {
            if let gameId = viewModel.createdGameId {
                LobbyView(gameRepository: gameRepository, gameId: gameId, currentUserId: currentUserId)
            }
        }
    }

    private var isShowingLobby: Binding<Bool> {
        Binding(
            get: { viewModel.createdGameId != nil },
            set: { isPresented in
                if !isPresented { viewModel.clearCreatedGame() }
            }
        )
    }

    @ViewBuilder
    private func pickerSection(
        title: String,
        users: [User],
        isSelected: @escaping (String) -> Bool,
        onTap: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(BeerStatsFont.headline)
                .foregroundStyle(BeerStatsColor.textPrimary)

            ForEach(users) { user in
                if let userId = user.id {
                    friendRow(user, isSelected: isSelected(userId)) {
                        HapticManager.lightImpact()
                        onTap(userId)
                    }
                }
            }
        }
    }

    private func friendRow(_ user: User, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(user.displayName)
                    .font(BeerStatsFont.body)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BeerStatsColor.accent)
                }
            }
            .padding(14)
            .background(
                isSelected ? BeerStatsColor.accent.opacity(0.15) : BeerStatsColor.surfaceElevated,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}
