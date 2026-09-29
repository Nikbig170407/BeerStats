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

    /// Spiegelt die heutige Aufstellung, weil UserDefaults sich nicht von
    /// selbst bei SwiftUI meldet.
    @State private var atTable: Set<String> = []

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
        .onAppear(perform: refreshRoster)
        // Auf die Anzahl statt auf die Profile selbst: Ein neu angelegtes
        // oder ausgemustertes Profil aendert die Aufstellung, ein
        // umbenanntes nicht.
        .onChange(of: viewModel.profiles.count) { _ in refreshRoster() }
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
                rosterHeader

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

    /// Wer heute dabei ist, auf einen Blick - und ein Weg zurueck zu "alle".
    ///
    /// Die Aufstellung gilt fuer ALLE Spiele, nicht nur fuer Beerpong. Das
    /// muss dastehen, sonst wirkt der Schalter wie eine zweite Art,
    /// jemanden auszumustern.
    private var rosterHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(atTable.count) von \(viewModel.activeProfiles.count) am Tisch")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text("Gilt für jedes Spiel – Beerpong wie Partyspiele")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }

            Spacer(minLength: 0)

            if atTable.count != viewModel.activeProfiles.count {
                Button {
                    TableRoster.reset()
                    refreshRoster()
                    HapticManager.lightImpact()
                } label: {
                    Text("Alle")
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassPanel(cornerRadius: 12)
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.bottom, 4)
    }

    private func refreshRoster() {
        atTable = Set(TableRoster.players(from: viewModel.profiles).compactMap(\.id))
    }

    /// Der Haken steht NEBEN der Karte, nicht darin: Zwei Tippziele
    /// ineinander sind auf einem Handy mit einem Bier in der Hand nicht
    /// zuverlaessig zu treffen - und wer auf die Karte tippt, will die
    /// Statistik sehen, nicht die Aufstellung aendern.
    private func tableToggle(_ profile: PlayerProfile) -> some View {
        let isAtTable = profile.id.map(atTable.contains) ?? false

        return Button {
            TableRoster.toggle(profile, in: viewModel.profiles)
            refreshRoster()
            HapticManager.lightImpact()
        } label: {
            Image(systemName: isAtTable ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 26))
                .foregroundStyle(isAtTable ? BeerStatsColor.success : BeerStatsColor.textSecondary)
                .frame(width: 52, height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(isAtTable ? "\(profile.name) ist am Tisch" : "\(profile.name) ist nicht dabei")
    }

    private func profileRow(_ profile: PlayerProfile) -> some View {
        HStack(spacing: 8) {
            profileCard(profile)
            // Ausgemusterte bekommen keinen Haken: Sie spielen nicht "heute
            // nicht mit", sie spielen gar nicht mehr mit.
            if profile.isActive {
                tableToggle(profile)
            }
        }
        .animation(AppAnimation.tap, value: atTable)
    }

    private func profileCard(_ profile: PlayerProfile) -> some View {
        NavigationLink {
            ProfileDetailView(
                profile: profile,
                otherProfiles: viewModel.profiles.filter { $0.id != profile.id },
                gameRepository: container.gameRepository,
                throwRepository: container.throwRepository,
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
