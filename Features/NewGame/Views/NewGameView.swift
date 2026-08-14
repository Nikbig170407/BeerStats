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
    private let container: AppContainer
    private let currentUserId: String

    /// Offener Platz, für den gerade ein Spieler gewählt wird.
    @State private var pickerTarget: SlotTarget?
    @State private var extremeCups: Double = 0
    @State private var extremeMode: ExtremeMode = .normal

    // Direkt auf denselben Schluesseln wie die Partyspiele: Was hier
    // umgestellt wird, gilt dort auch. Zwei getrennte Einstellungen fuer
    // dieselbe Frage waeren nur eine Quelle fuer Verwirrung am Tisch.
    @AppStorage(DrinkIntensity.storageKey) private var intensity = DrinkIntensity.normal.rawValue
    @AppStorage(DrinkRules.shotsStorageKey) private var shotsEnabled = true

    init(container: AppContainer, currentUserId: String) {
        self.container = container
        self.currentUserId = currentUserId
        _viewModel = StateObject(
            wrappedValue: NewGameViewModel(
                gameRepository: container.gameRepository,
                profileRepository: container.playerProfileRepository,
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
                extremeSection

                if viewModel.isLoading {
                    CupFillLoadingView(size: 64)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                } else if !viewModel.hasEnoughProfiles {
                    notEnoughProfiles
                } else {
                    wheelLink
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
        .background(GridBackdrop())
        .navigationTitle("Neues Spiel")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if viewModel.hasEnoughProfiles {
                createButton
                    .padding(20)
                    // Weicher Verlauf statt harter Kante, damit der Inhalt
                    // darunter auszulaufen scheint.
                    .background(
                        LinearGradient(
                            colors: [
                                BeerStatsColor.backgroundPrimary.opacity(0),
                                BeerStatsColor.backgroundPrimary
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    )
            }
        }
        .sheet(item: $pickerTarget) { target in
            playerPicker(for: target)
        }
        // Kein Zwischenschritt: Nach dem Start geht es sofort ins Tracking.
        .navigationDestination(isPresented: hasCreatedGame) {
            LiveGameView(
                teams: viewModel.createdTeams,
                format: GameFormat(cupCount: viewModel.cupCount),
                playersPerTeam: viewModel.playersPerTeam,
                perspectiveTeamIndex: 0,
                gameId: viewModel.createdGameId,
                throwRepository: container.throwRepository,
                gameRepository: container.gameRepository,
                profileRepository: container.playerProfileRepository,
                ownerId: currentUserId,
                extreme: ExtremeSettings(loadedCups: Int(extremeCups), mode: extremeMode)
            )
        }
    }

    // MARK: - Beerpong Extreme

    /// Kein eigener Modus im Menü, sondern ein Regler in der normalen
    /// Spielvorbereitung. Bei null ist es gewöhnliches Beerpong, bei zehn
    /// löst jeder Becher aus – das ist dieselbe Partie mit einem Regler
    /// dazwischen, und deshalb gehört es hierher und nicht in ein zweites
    /// Menü mit doppeltem Aufbau.
    private var extremeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Beerpong Extreme")

            HStack {
                // Gedeckelt auf die tatsächliche Becherzahl: Der Regler geht
                // bis zehn, gespielt wird aber vielleicht mit sechs.
                Text(extremeCups == 0
                     ? "Aus – normales Beerpong"
                     : "\(min(Int(extremeCups), viewModel.cupCount)) von \(viewModel.cupCount) Bechern geladen")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(
                        extremeCups == 0 ? BeerStatsColor.textSecondary : BeerStatsColor.error
                    )
                Spacer()
            }

            Slider(value: $extremeCups, in: 0...10, step: 1)
                .tint(BeerStatsColor.error)

            if extremeCups > 0 {
                Text("Wer einen geladenen Becher trifft, zieht eine Ereigniskarte. Welche geladen sind, weiß niemand.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ForEach(ExtremeMode.allCases, id: \.self) { mode in
                        Button {
                            extremeMode = mode
                            HapticManager.lightImpact()
                        } label: {
                            VStack(spacing: 2) {
                                Text(mode.title)
                                    .font(BeerStatsFont.headline)
                                Text(mode.detail)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .foregroundStyle(
                                extremeMode == mode
                                    ? BeerStatsColor.textOnAccent
                                    : BeerStatsColor.textSecondary
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                extremeMode == mode
                                    ? BeerStatsColor.error
                                    : BeerStatsColor.surfaceElevated.opacity(0.6),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }

                drinkRules

                Text("Zählt nicht in die Statistiken – die Karten verfälschen jede Trefferquote.")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Härte und Shots stehen hier, obwohl sie für ALLE Spiele gelten.
    ///
    /// Sie hier zu wiederholen ist Absicht: Beides entscheidet sich am Tisch,
    /// kurz bevor es losgeht, und wer erst in ein Einstellungsmenü abbiegen
    /// muss, lässt es. Geschrieben wird derselbe Wert, den auch die
    /// Partyspiele lesen – es gibt keine zweite Wahrheit.
    private var drinkRules: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HÄRTE")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .kerning(1.4)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .padding(.top, 4)

            HStack(spacing: 8) {
                ForEach(DrinkIntensity.allCases, id: \.self) { level in
                    Button {
                        intensity = level.rawValue
                        HapticManager.lightImpact()
                    } label: {
                        VStack(spacing: 1) {
                            Text(level.emoji).font(.system(size: 17))
                            Text(level.title)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(
                            intensity == level.rawValue
                                ? BeerStatsColor.textOnAccent
                                : BeerStatsColor.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            intensity == level.rawValue
                                ? BeerStatsColor.accent
                                : BeerStatsColor.surfaceElevated.opacity(0.6),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }

            Toggle(isOn: $shotsEnabled) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Mit Shots")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                    Text(shotsEnabled
                         ? "Karten dürfen Shots verlangen"
                         : "Shots werden in Schlücke umgerechnet")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
            }
            .tint(BeerStatsColor.accent)
            .padding(.top, 2)
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

    /// Einstieg ins Glücksrad. Steht bewusst über der Aufstellung: Wer
    /// auslosen will, soll nicht erst von Hand wählen müssen.
    private var wheelLink: some View {
        NavigationLink {
            TeamWheelView(
                profiles: viewModel.selectableProfiles,
                playersPerTeam: viewModel.playersPerTeam
            ) { teams in
                viewModel.applyDrawnLineup(teams)
            }
        } label: {
            HStack(spacing: 14) {
                Text("🎡").font(.system(size: 30))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Teams auslosen")
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                    Text("Glücksrad entscheidet, wer mit wem spielt")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            .padding(16)
            .glassPanel()
            .neonEdge(BeerStatsColor.success, intensity: 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var lineup: some View {
        VStack(spacing: 0) {
            teamPanel(teamIndex: 0, tint: BeerStatsColor.accent)
            versusBadge
            teamPanel(teamIndex: 1, tint: BeerStatsColor.accentSecondary)
        }
    }

    /// Das VS zwischen den Teams, mit Leuchtlinien nach beiden Seiten –
    /// macht aus zwei Listen ein Duell.
    private var versusBadge: some View {
        HStack(spacing: 12) {
            LinearGradient(
                colors: [.clear, BeerStatsColor.accent.opacity(0.7)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 1)

            Text("VS")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .glassPanel(cornerRadius: 20)
                .neonEdge(BeerStatsColor.textSecondary, cornerRadius: 20, intensity: 0.5)

            LinearGradient(
                colors: [BeerStatsColor.accentSecondary.opacity(0.7), .clear],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 1)
        }
        .padding(.vertical, 14)
    }

    private func teamPanel(teamIndex: Int, tint: Color) -> some View {
        let filled = viewModel.selection[teamIndex].compactMap { $0 }.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TEAM \(teamIndex + 1)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .kerning(1.6)
                    .foregroundStyle(tint)
                Spacer()
                Text("\(filled)/\(viewModel.playersPerTeam)")
                    .font(BeerStatsFont.statLabel)
                    .foregroundStyle(
                        filled == viewModel.playersPerTeam ? tint : BeerStatsColor.textSecondary
                    )
            }

            HStack(spacing: 12) {
                ForEach(0..<viewModel.playersPerTeam, id: \.self) { slot in
                    slotView(teamIndex: teamIndex, slot: slot, tint: tint)
                }
            }
        }
        .padding(16)
        .glassPanel()
        .neonEdge(tint, intensity: filled == viewModel.playersPerTeam ? 1 : 0.35)
        .animation(AppAnimation.standard, value: filled)
    }

    private func slotView(teamIndex: Int, slot: Int, tint: Color) -> some View {
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
                        .shadow(color: profile.color.color.opacity(0.6), radius: 12)
                    Text(profile.name)
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                        .lineLimit(1)
                } else {
                    ZStack {
                        Circle()
                            .strokeBorder(
                                tint.opacity(0.55),
                                style: StrokeStyle(lineWidth: 2, dash: [5, 4])
                            )
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(tint.opacity(0.8))
                    }
                    .frame(width: 56, height: 56)
                    Text("Wählen")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        profile == nil
                            ? BeerStatsColor.backgroundSecondary.opacity(0.6)
                            : profile!.color.color.opacity(0.14)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        profile?.color.color.opacity(0.8) ?? Color.clear,
                        lineWidth: 1.2
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .animation(AppAnimation.tap, value: profile?.id)
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
                PrimaryButton(title: "Spiel starten", systemImage: "play.fill") {
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
