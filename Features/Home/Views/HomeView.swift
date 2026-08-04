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

    private var partySection: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Gruppen statt einer langen Liste: Nach zehn Einträgen ohne
            // Trennung findet niemand mehr, was er sucht. Sortiert danach,
            // was man am Tisch tut – Karten ziehen, reden, oder schnell
            // etwas entscheiden.
            gameGroup("MIT KARTEN") {
                NavigationLink { RingOfFireView() } label: {
                    gameCard(
                        emoji: "🔥",
                        title: "Ring of Fire",
                        subtitle: "52 Karten im Kreis um die Flasche – jede bedeutet etwas anderes",
                        tint: BeerStatsColor.error
                    )
                }
                .buttonStyle(PressableButtonStyle())

                NavigationLink { BusRideView() } label: {
                    gameCard(
                        emoji: "🚌",
                        title: "Bussfahrer",
                        subtitle: "Vier Fragen, jede teurer – ein Fehler und zurück auf Anfang",
                        tint: BeerStatsColor.accentSecondary
                    )
                }
                .buttonStyle(PressableButtonStyle())

                NavigationLink { TruthOrDareView() } label: {
                    gameCard(
                        emoji: "🎭",
                        title: "Wahrheit oder Pflicht",
                        subtitle: "90 Karten – verweigern kostet vier Schlücke",
                        tint: BeerStatsColor.accent
                    )
                }
                .buttonStyle(PressableButtonStyle())

                NavigationLink { NeverHaveIEverView() } label: {
                    gameCard(
                        emoji: "🍻",
                        title: "Ich hab noch nie",
                        subtitle: "150 Fragen in drei Stufen, dazu Strafen",
                        tint: BeerStatsColor.success
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }

            gameGroup("RATEN & REDEN") {
                NavigationLink { SpyView() } label: {
                    gameCard(
                        emoji: "🕵️",
                        title: "Der Spion",
                        subtitle: "Alle kennen das Wort – einer nicht, und der muss es überspielen",
                        tint: BeerStatsColor.accentSecondary
                    )
                }
                .buttonStyle(PressableButtonStyle())

                NavigationLink { HeadsUpView() } label: {
                    gameCard(
                        emoji: "🙈",
                        title: "Wer bin ich?",
                        subtitle: "Handy an die Stirn – jeder verpasste Begriff kostet einen Schluck",
                        tint: BeerStatsColor.accent
                    )
                }
                .buttonStyle(PressableButtonStyle())

                NavigationLink { CountTo21View() } label: {
                    gameCard(
                        emoji: "🔢",
                        title: "21",
                        subtitle: "Reihum zählen – wer 21 sagt, macht eine neue Regel",
                        tint: BeerStatsColor.error
                    )
                }
                .buttonStyle(PressableButtonStyle())

                NavigationLink { EstimationView() } label: {
                    gameCard(
                        emoji: "🤔",
                        title: "Schätzmeister",
                        subtitle: "50 Fragen mit einer Zahl – wer am weitesten daneben liegt, trinkt",
                        tint: BeerStatsColor.success
                    )
                }
                .buttonStyle(PressableButtonStyle())

                NavigationLink { CategoriesView() } label: {
                    gameCard(
                        emoji: "⏱️",
                        title: "Kategorien",
                        subtitle: "Reihum ein Begriff – die Bedenkzeit wird jede Runde knapper",
                        tint: BeerStatsColor.warning
                    )
                }
                .buttonStyle(PressableButtonStyle())

                NavigationLink { MostLikelyView() } label: {
                    gameCard(
                        emoji: "👉",
                        title: "Wer von uns?",
                        subtitle: "Alle zeigen gleichzeitig – die meisten Finger trinken",
                        tint: BeerStatsColor.accent
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }

            gameGroup("SCHNELL ZWISCHENDURCH") {
                NavigationLink { BombPassView() } label: {
                    gameCard(
                        emoji: "💣",
                        title: "Bombe weitergeben",
                        subtitle: "Zünden, herumreichen, nicht drauf sitzen bleiben",
                        tint: BeerStatsColor.accentSecondary
                    )
                }
                .buttonStyle(PressableButtonStyle())

                NavigationLink { ReactionDuelView() } label: {
                    gameCard(
                        emoji: "⚡️",
                        title: "Reaktionsduell",
                        subtitle: "Zwei Daumen, ein Signal – wer zu früh tippt, verliert",
                        tint: BeerStatsColor.accent
                    )
                }
                .buttonStyle(PressableButtonStyle())

                NavigationLink { DrinkRouletteView() } label: {
                    gameCard(
                        emoji: "🎯",
                        title: "Trink-Roulette",
                        subtitle: "Acht Felder, ein Zeiger – keine Einrichtung nötig",
                        tint: BeerStatsColor.error
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }

            // Eigene Gruppe, obwohl nur ein Eintrag drin steht: Dieses Spiel
            // startet man einmal und legt das Handy dann weg. Zwischen den
            // anderen stehend würde niemand verstehen, warum es keine Runde
            // hat.
            gameGroup("LÄUFT NEBENHER") {
                NavigationLink { ForbiddenWordsView() } label: {
                    gameCard(
                        emoji: "🤐",
                        title: "Verbotene Wörter",
                        subtitle: "Jeder zieht ein Wort, das er den Abend über nicht sagen darf",
                        tint: BeerStatsColor.warning
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
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
