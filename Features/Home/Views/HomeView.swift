//
//  HomeView.swift
//  BeerStats
//
//  Das Hauptmenue: die Auswahl, was gespielt wird.
//
//  Bewusst nur Spiele, keine Verwaltung. Beerpong hat mit Mitspielern,
//  Rangliste und Verlauf genug eigene Unterpunkte, um eine eigene Ebene zu
//  rechtfertigen – die lagen vorher gleichrangig neben den Partyspielen und
//  liessen das Menue wie eine Einstellungsliste wirken statt wie eine
//  Spielauswahl.
//

import SwiftUI

struct HomeView: View {

    @StateObject private var viewModel: HomeViewModel
    private let container: AppContainer
    /// Spiegelt die dauerhaft gespeicherte Einstellung, damit das Symbol in
    /// der Leiste sofort umspringt.
    @State private var isSoundOn = SoundManager.isEnabled
    @State private var isSpeechOn = SpeechAnnouncer.isEnabled
    /// Wird beim Zurueckkehren neu gelesen – UserDefaults meldet sich
    /// nicht von selbst bei SwiftUI.
    @State private var recentGames = RecentPartyGames.games

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
                VStack(alignment: .leading, spacing: 24) {
                    header
                    beerpongCard
                    // Die Härte steht über den Partyspielen, weil sie nur für
                    // die gilt – Beerpong hat keine Trinkregeln in der App.
                    DrinkIntensityPicker()
                    partySection
                }
                .padding(20)
            }
            .background(GridBackdrop())
            .toolbar { toolbarContent }
            .onAppear { recentGames = RecentPartyGames.games }
        }
    }

    // MARK: - Kopf

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
                Text("Was wird gespielt?")
                    .font(BeerStatsFont.body)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                try? container.authRepository.signOut()
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            .accessibilityLabel("Abmelden")
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
        ToolbarItem(placement: .topBarLeading) {
            Button {
                isSpeechOn.toggle()
                SpeechAnnouncer.isEnabled = isSpeechOn
                if isSpeechOn { SpeechAnnouncer.announce("Ansage ist an") }
                HapticManager.lightImpact()
            } label: {
                Image(systemName: isSpeechOn ? "bubble.left.and.text.bubble.right.fill" : "bubble.left.and.text.bubble.right")
                    .foregroundStyle(isSpeechOn ? BeerStatsColor.accent : BeerStatsColor.textSecondary)
            }
            .accessibilityLabel(isSpeechOn ? "Ansage ausschalten" : "Ansage einschalten")
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

    // MARK: - Beerpong

    /// Steht bewusst allein und groesser als die uebrigen Spiele: Es ist das
    /// Spiel, um das herum die App gebaut ist, und das einzige mit Statistik.
    private var beerpongCard: some View {
        NavigationLink {
            BeerpongMenuView(container: container, viewModel: viewModel)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Text("🍺").font(.system(size: 40))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Beerpong")
                            .font(BeerStatsFont.title)
                            .foregroundStyle(BeerStatsColor.textPrimary)
                        Text(beerpongSubtitle)
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(
                                viewModel.resumableGame == nil
                                    ? BeerStatsColor.textSecondary
                                    : BeerStatsColor.accent
                            )
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }

                HStack(spacing: 10) {
                    miniStat("\(viewModel.activeProfiles.count)", "Mitspieler")
                    miniStat("\(viewModel.totalGamesTracked)", "Partien")
                    miniStat(
                        viewModel.leadingProfile?.emoji ?? "–",
                        viewModel.leadingProfile?.name ?? "Noch offen"
                    )
                }
            }
            .padding(18)
            .glassPanel()
            .neonEdge(BeerStatsColor.accent, intensity: 0.55)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var beerpongSubtitle: String {
        viewModel.resumableGame == nil
            ? "Tracken, Statistiken, Rangliste"
            : "Eine Partie läuft noch – fortsetzen"
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(BeerStatsFont.statLabel)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(
            BeerStatsColor.surfaceElevated.opacity(0.6),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    // MARK: - Spiele auf dem Handy

    /// Die Liste kommt aus `PartyGame`, nicht aus dieser Datei. Neunzehn
    /// Einträge von Hand zu pflegen war der sichere Weg, bei jedem neuen
    /// Spiel eine der fünf Angaben zu vergessen.
    private var partySection: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Ein Abend spielt zwei bis drei Spiele und scrollt sonst an
            // neunzehn vorbei. Die stehen deshalb oben.
            if !recentGames.isEmpty {
                gameGroup("ZULETZT GESPIELT") {
                    ForEach(recentGames) { gameLink($0) }
                }
            }

            tournamentCard

            ForEach(PartyGame.Group.allCases) { group in
                gameGroup(group.title) {
                    ForEach(PartyGame.allCases.filter { $0.group == group }) { gameLink($0) }
                }
            }
        }
    }

    /// Steht ueber den Gruppen, weil es kein zwanzigstes Spiel ist, sondern
    /// eine Klammer um die neunzehn vorhandenen.
    private var tournamentCard: some View {
        NavigationLink {
            TournamentView()
        } label: {
            HStack(spacing: 14) {
                Text("🏆")
                    .font(.system(size: 30))
                    .frame(width: 54, height: 54)
                    .background(
                        BeerStatsColor.warning.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text("Turnier")
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                    Text("Mehrere Spiele hintereinander – jede Runde kostet mehr")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            .padding(16)
            .glassPanel()
            .neonEdge(BeerStatsColor.warning, intensity: 0.55)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func gameLink(_ game: PartyGame) -> some View {
        NavigationLink {
            // Vermerkt wird beim Erscheinen, nicht beim Antippen: Wer sich
            // vertippt und sofort zurückgeht, hat nicht gespielt.
            game.destination
                .onAppear { RecentPartyGames.record(game) }
        } label: {
            gameCard(
                emoji: game.emoji,
                title: game.title,
                subtitle: game.subtitle,
                tint: game.tint
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func gameGroup<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .kerning(1.8)
                .foregroundStyle(BeerStatsColor.textSecondary)
            content()
        }
    }

    private func gameCard(emoji: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: 16) {
            Text(emoji)
                .font(.system(size: 32))
                .frame(width: 54, height: 54)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text(subtitle)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .lineLimit(2)
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
}
