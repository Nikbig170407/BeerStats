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
    /// Wird beim Zurueckkehren neu gelesen – UserDefaults meldet sich
    /// nicht von selbst bei SwiftUI.
    @State private var recentGames = RecentPartyGames.games
    @State private var runningEvening = EveningLog.current
    /// Wer heute am Tisch steht. Wie oben: UserDefaults meldet sich nicht von
    /// selbst, also beim Erscheinen neu lesen.
    @State private var tablePlayers: [PlayerProfile] = []

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
                    eveningCard
                    beerpongCard
                    // Die Härte steht über den Partyspielen, weil sie nur für
                    // die gilt – Beerpong hat keine Trinkregeln in der App.
                    DrinkIntensityPicker()
                    partySection
                    customCardsLink
                }
                .padding(20)
            }
            .background(AmbientBackdrop())
            // Die Spielauswahl liess sich seitlich verschieben und federte
            // zurueck - irgendein Kind ist breiter als der Bildschirm.
            .verticalScrollOnly()
            .toolbar { toolbarContent }
            // Jedes Spiel, das Namen zeigen kann, nimmt sie sich von hier.
            .environment(\.tablePlayers, tablePlayers)
            .onAppear {
                recentGames = RecentPartyGames.games
                runningEvening = EveningLog.current
                tablePlayers = TableRoster.players(from: viewModel.profiles)
                TableRoster.remember(tablePlayers)
            }
            // Die Profile kommen ueber einen Listener nach – beim ersten
            // Erscheinen ist die Liste oft noch leer.
            .onChange(of: viewModel.profiles.count) { _ in
                tablePlayers = TableRoster.players(from: viewModel.profiles)
                TableRoster.remember(tablePlayers)
            }
        }
    }

    // MARK: - Eigene Karten

    /// Steht unter den Spielen, nicht darueber: Man kommt darauf, nachdem man
    /// ein paar Runden gespielt hat und die eigene Geschichte vermisst – nicht
    /// vorher.
    private var customCardsLink: some View {
        NavigationLink {
            CustomCardsView()
        } label: {
            HStack(spacing: 12) {
                Text("✍️").font(.system(size: 24))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Eigene Karten")
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                    Text("Eure Sprüche in die Stapel mischen")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .glassPanel(cornerRadius: 16)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Abend

    /// Steht ganz oben, weil der Abend alles darunter klammert.
    ///
    /// Zeigt im laufenden Zustand die Dauer und die Zahl der Spiele – das
    /// reicht als Beleg, dass mitgezaehlt wird, ohne den Bildschirm mit einer
    /// zweiten Bilanz zu fuellen.
    private var eveningCard: some View {
        NavigationLink {
            EveningView(profiles: viewModel.profiles.filter(\.isActive))
        } label: {
            HStack(spacing: 14) {
                Text(runningEvening?.isRunning == true ? "🌙" : "🌑")
                    .font(.system(size: 30))

                VStack(alignment: .leading, spacing: 2) {
                    Text(runningEvening?.isRunning == true ? "Abend läuft" : "Abend starten")
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)

                    Text(eveningSubtitle)
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassPanel(cornerRadius: 18)
            .neonEdge(
                BeerStatsColor.accentSecondary,
                cornerRadius: 18,
                intensity: runningEvening?.isRunning == true ? 0.7 : 0.2
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var eveningSubtitle: String {
        guard let abend = runningEvening, abend.isRunning else {
            return "Spiele und Trinkbilanz eines Abends sammeln"
        }
        let spiele = abend.entries.count
        return "\(abend.readableDuration) · \(spiele) \(spiele == 1 ? "Spiel" : "Spiele")"
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

    /// Zwei Symbole, nicht fuenf.
    ///
    /// Hier lagen abmelden, Ton, Ansage und Entwicklereinstellungen
    /// nebeneinander – vier Schalter, von denen man drei nie braucht, und
    /// einer davon meldet einen ab, direkt neben der Spielauswahl. Alles vier
    /// steht jetzt in den Einstellungen; oben bleiben die zwei Wege, die man
    /// am Abend wirklich geht.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
                ProfilesView(container: container, ownerId: viewModel.currentUserId)
            } label: {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(BeerStatsColor.accent)
            }
            .accessibilityLabel("Spieler")
        }
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
                SettingsView(container: container, ownerId: viewModel.currentUserId)
            } label: {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            .accessibilityLabel("Einstellungen")
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
                            .foregroundStyle(BeerStatsColor.textSecondary)
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

    /// Immer derselbe Satz.
    ///
    /// Hier stand "Eine Partie läuft noch – fortsetzen", solange eine offen
    /// war. Eine Meldung, die niemand angefordert hat und die stehen bleibt,
    /// bis sich jemand kümmert. Gefragt wird jetzt dort, wo die Frage
    /// aufkommt: eine Ebene tiefer, beim Griff nach Beerpong.
    private var beerpongSubtitle: String {
        "Tracken, Statistiken, Rangliste"
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.scaled(19, weight: .heavy, design: .rounded))
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
            // Ein Abend spielt zwei bis drei Spiele. Die stehen deshalb oben,
            // vor den Ordnern – sonst waere der haeufigste Weg der laengste.
            if !recentGames.isEmpty {
                gameGroup("ZULETZT GESPIELT") {
                    ForEach(recentGames) { PartyGameCard(game: $0) }
                }
            }

            gameGroup("SPIELE") {
                ForEach(PartyGame.Group.allCases) { folderCard($0) }
            }

            tournamentCard
        }
    }

    /// Eine Gruppe als Kachel.
    ///
    /// Neunzehn Spiele untereinander waren eine Liste, durch die man
    /// scrollt, bis man das Richtige sieht – und bei neunzehn sieht man es
    /// nicht mehr. Vier Ordner sind dagegen die Frage, die am Tisch ohnehin
    /// gestellt wird: Karten in der Mitte, oder reden, oder schnell was
    /// zwischendurch?
    private func folderCard(_ group: PartyGame.Group) -> some View {
        NavigationLink {
            PartyGameFolderView(group: group)
        } label: {
            HStack(spacing: 16) {
                Text(group.emoji)
                    .font(.system(size: 30))
                    .frame(width: 54, height: 54)
                    .background(
                        group.tint.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(group.label)
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                    Text(group.subtitle)
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Text("\(group.games.count)")
                    .font(.scaled(15, weight: .heavy, design: .rounded))
                    .foregroundStyle(group.tint)
                    .monospacedDigit()

                Image(systemName: "chevron.right")
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            .padding(16)
            .glassPanel()
            .neonEdge(group.tint, intensity: 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
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

    private func gameGroup<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.scaled(11, weight: .heavy, design: .rounded))
                .kerning(1.8)
                .foregroundStyle(BeerStatsColor.textSecondary)
            content()
        }
    }
}
