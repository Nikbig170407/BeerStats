//
//  NewGameView.swift
//  BeerStats
//
//  Modus und Becherzahl wählen, die Plätze mit Mitspieler-Profilen
//  besetzen, Spiel erstellen. Nach erfolgreicher Erstellung geht es
//  automatisch in die Lobby.
//
//  Die Aufstellung wird als zwei Reihen von Plätzen gezeigt statt als Liste
//  mit Häkchen: So ist auf einen Blick erkennbar, wer gegen wen spielt –
//  und genau so liegen die Teams später auch auf dem Spielscreen.
//

import SwiftUI

struct NewGameView: View {

    @StateObject private var viewModel: NewGameViewModel
    private let gameRepository: GameRepositoryProtocol
    private let currentUserId: String

    /// Offener Platz, für den gerade ein Spieler gewählt wird.
    @State private var pickerTarget: SlotTarget?

    init(
        gameRepository: GameRepositoryProtocol,
        profileRepository: PlayerProfileRepositoryProtocol,
        currentUserId: String
    ) {
        self.gameRepository = gameRepository
        self.currentUserId = currentUserId
        _viewModel = StateObject(
            wrappedValue: NewGameViewModel(
                gameRepository: gameRepository,
                profileRepository: profileRepository,
                currentUserId: currentUserId
            )
        )
    }

    private struct SlotTarget: Identifiable {
        let teamIndex: Int
        let slot: Int
        var id: String { "\(teamIndex)-\(slot)" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                modePicker
                cupPicker

                if viewModel.isLoading {
                    CupFillLoadingView(size: 64)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                } else if !viewModel.hasEnoughProfiles {
                    notEnoughProfiles
                } else {
                    lineup
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.error)
                }
            }
            .padding(20)
        }
        .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Neues Spiel")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if viewModel.hasEnoughProfiles {
                createButton
                    .padding(20)
                    .background(BeerStatsColor.backgroundPrimary)
            }
        }
        .sheet(item: $pickerTarget) { target in
            playerPicker(for: target)
        }
        .navigationDestination(isPresented: hasCreatedGame) {
            LobbyView(
                gameRepository: gameRepository,
                gameId: viewModel.createdGameId ?? "",
                currentUserId: currentUserId
            )
        }
    }

    private var hasCreatedGame: Binding<Bool> {
        Binding(
            get: { viewModel.createdGameId != nil },
            set: { if !$0 { viewModel.clearCreatedGame() } }
        )
    }

    // MARK: - Einstellungen

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Modus")
            Picker("Spielmodus", selection: $viewModel.gameType) {
                Text("1 vs 1").tag(GameType.oneVsOne)
                Text("2 vs 2").tag(GameType.twoVsTwo)
            }
            .pickerStyle(.segmented)
        }
    }

    private var cupPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Becher pro Team")
            Picker("Becher", selection: $viewModel.cupCount) {
                Text("10 Becher").tag(10)
                Text("6 Becher").tag(6)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Aufstellung

    private var lineup: some View {
        VStack(spacing: 16) {
            teamRow(teamIndex: 0)

            Text("gegen")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)

            teamRow(teamIndex: 1)
        }
    }

    private func teamRow(teamIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Team \(teamIndex + 1)")
            HStack(spacing: 12) {
                ForEach(0..<viewModel.playersPerTeam, id: \.self) { slot in
                    slotView(teamIndex: teamIndex, slot: slot)
                }
            }
        }
    }

    private func slotView(teamIndex: Int, slot: Int) -> some View {
        let profile = viewModel.profile(teamIndex: teamIndex, slot: slot)

        return Button {
            if profile == nil {
                pickerTarget = SlotTarget(teamIndex: teamIndex, slot: slot)
            } else {
                viewModel.clear(teamIndex: teamIndex, slot: slot)
            }
        } label: {
            VStack(spacing: 8) {
                if let profile {
                    ProfileAvatarView(profile: profile, size: 56)
                    Text(profile.name)
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                        .lineLimit(1)
                } else {
                    ZStack {
                        Circle()
                            .strokeBorder(
                                BeerStatsColor.textSecondary.opacity(0.4),
                                style: StrokeStyle(lineWidth: 2, dash: [5, 4])
                            )
                        Image(systemName: "plus")
                            .foregroundStyle(BeerStatsColor.textSecondary)
                    }
                    .frame(width: 56, height: 56)
                    Text("Wählen")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                BeerStatsColor.surfaceElevated,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(
            profile.map { "\($0.name), zum Entfernen antippen" } ?? "Freier Platz, Spieler wählen"
        )
    }

    // MARK: - Auswahl-Sheet

    private func playerPicker(for target: SlotTarget) -> some View {
        NavigationStack {
            Group {
                if viewModel.unassignedProfiles.isEmpty {
                    Text("Alle Profile sind schon eingeteilt.")
                        .font(BeerStatsFont.body)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(viewModel.unassignedProfiles) { profile in
                                Button {
                                    if let id = profile.id {
                                        viewModel.assign(profileId: id, teamIndex: target.teamIndex, slot: target.slot)
                                    }
                                    pickerTarget = nil
                                } label: {
                                    BeerStatsCard {
                                        HStack(spacing: 14) {
                                            ProfileAvatarView(profile: profile)
                                            Text(profile.name)
                                                .font(BeerStatsFont.headline)
                                                .foregroundStyle(BeerStatsColor.textPrimary)
                                            Spacer()
                                        }
                                    }
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Team \(target.teamIndex + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { pickerTarget = nil }
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Randfälle

    private var notEnoughProfiles: some View {
        BeerStatsCard {
            VStack(spacing: 8) {
                Text("Zu wenige Mitspieler")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text("Für \(viewModel.gameType == .oneVsOne ? "1 vs 1" : "2 vs 2") brauchst du \(viewModel.playersPerTeam * 2) aktive Profile. Lege sie über das Personen-Symbol im Hauptmenü an.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var createButton: some View {
        Group {
            if viewModel.isCreating {
                CupFillLoadingView(size: 52)
                    .frame(maxWidth: .infinity)
            } else {
                PrimaryButton(title: "Spiel erstellen", systemImage: "play.fill") {
                    Task { await viewModel.createGame() }
                }
                .opacity(viewModel.canCreateGame ? 1 : 0.4)
                .disabled(!viewModel.canCreateGame)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(BeerStatsFont.statLabel)
            .foregroundStyle(BeerStatsColor.accent)
    }
}
