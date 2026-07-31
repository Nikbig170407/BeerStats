//
//  ProfilesView.swift
//  BeerStats
//
//  Übersicht aller Mitspieler-Profile mit Anlegen und Bearbeiten.
//
//  In dieser Ausbaustufe liegt die App nur auf einem Gerät und alle
//  Mitspieler werden von hier aus verwaltet – dieser Screen ist damit der
//  Ort, an dem festgelegt wird, wer überhaupt mitspielen kann.
//

import SwiftUI

struct ProfilesView: View {

    @StateObject private var viewModel: ProfilesViewModel
    @State private var editorTarget: EditorTarget?

    private let container: AppContainer
    private let ownerId: String

    init(container: AppContainer, ownerId: String) {
        self.container = container
        self.ownerId = ownerId
        _viewModel = StateObject(
            wrappedValue: ProfilesViewModel(repository: container.playerProfileRepository, ownerId: ownerId)
        )
    }

    /// Steuert das Editor-Sheet. Als eigener Typ statt zweier Bool-Flags,
    /// damit „neu anlegen" und „bearbeiten" sich nicht überlagern können.
    private enum EditorTarget: Identifiable {
        case new
        case existing(PlayerProfile)

        var id: String {
            switch self {
            case .new: return "new"
            case .existing(let profile): return profile.id ?? profile.name
            }
        }

        var profile: PlayerProfile? {
            if case .existing(let profile) = self { return profile }
            return nil
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                CupFillLoadingView(size: 72)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.profiles.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Mitspieler")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorTarget = .new
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(BeerStatsColor.accent)
                }
                .accessibilityLabel("Profil anlegen")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    LeaderboardView(profiles: viewModel.profiles)
                } label: {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(BeerStatsColor.textPrimary)
                }
                .accessibilityLabel("Rangliste")
                .disabled(viewModel.profiles.isEmpty)
            }
        }
        .sheet(item: $editorTarget) { target in
            ProfileEditorView(
                existingProfile: target.profile,
                isSaving: viewModel.isSaving
            ) { name, emoji, color, isActive in
                Task {
                    let success: Bool
                    if let existing = target.profile {
                        success = await viewModel.updateProfile(
                            existing, name: name, emoji: emoji, color: color, isActive: isActive
                        )
                    } else {
                        success = await viewModel.createProfile(name: name, emoji: emoji, color: color)
                    }
                    if success { editorTarget = nil }
                }
            }
        }
        .alert(
            "Fehler",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Zustände

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🍺")
                .font(.system(size: 56))
            Text("Noch keine Mitspieler")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
            Text("Lege für jeden, der regelmäßig mitspielt, ein Profil an. Danach werden die Statistiken automatisch mitgeschrieben.")
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            PrimaryButton(title: "Ersten Mitspieler anlegen", systemImage: "plus") {
                editorTarget = .new
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(viewModel.activeProfiles) { profile in
                    profileRow(profile)
                }

                if !viewModel.inactiveProfiles.isEmpty {
                    Text("Spielen nicht mehr mit")
                        .font(BeerStatsFont.statLabel)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 16)

                    ForEach(viewModel.inactiveProfiles) { profile in
                        profileRow(profile)
                    }
                }
            }
            .padding(20)
        }
    }

    private func profileRow(_ profile: PlayerProfile) -> some View {
        NavigationLink {
            ProfileDetailView(
                profile: profile,
                otherProfiles: viewModel.profiles.filter { $0.id != profile.id },
                gameRepository: container.gameRepository,
                ownerId: ownerId
            ) {
                editorTarget = .existing(profile)
            }
        } label: {
            BeerStatsCard {
                HStack(spacing: 14) {
                    ProfileAvatarView(profile: profile)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(profile.name)
                            .font(BeerStatsFont.headline)
                            .foregroundStyle(BeerStatsColor.textPrimary)
                            .lineLimit(1)
                        Text(summary(for: profile))
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func summary(for profile: PlayerProfile) -> String {
        let stats = profile.statistics
        guard stats.gamesPlayed > 0 else { return "Noch kein Spiel gewertet" }
        let hitRate = Int((stats.hitRate * 100).rounded())
        return "\(stats.gamesPlayed) Spiele · \(stats.gamesWon) Siege · \(hitRate)% Trefferquote"
    }
}
