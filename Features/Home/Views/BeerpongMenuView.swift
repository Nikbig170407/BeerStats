//
//  BeerpongMenuView.swift
//  BeerStats
//
//  Alles, was zu Beerpong gehoert – eine Ebene unter dem Hauptmenue.
//
//  Mitspieler, Rangliste und Verlauf haengen ausschliesslich an Beerpong:
//  Die Partyspiele erzeugen keine dieser Zahlen. Im Hauptmenue standen sie
//  trotzdem gleichrangig neben den Spielen und liessen die Auswahl wie eine
//  Einstellungsliste wirken.
//
//  Das HomeViewModel wird von oben durchgereicht statt hier neu gebaut:
//  Sonst liefe ein zweiter Firestore-Listener auf dieselben Daten.
//

import SwiftUI

struct BeerpongMenuView: View {

    let container: AppContainer
    @ObservedObject var viewModel: HomeViewModel

    /// Wohin es nach der Frage weitergeht.
    private enum Route: Hashable {
        case running
        case newGame
        case quickStart
    }

    /// Die offene Partie, nach der gefragt wird.
    @State private var prompt: Game?
    /// Nach welcher Partie in dieser Sitzung schon gefragt wurde. Ohne das
    /// stuende die Frage nach jedem Zurueckgehen wieder da.
    @State private var askedFor: String?
    /// Gesetzt, waehrend das Blatt noch zugeht – navigiert wird erst danach.
    @State private var pendingRoute: Route?
    @State private var route: Route?
    @State private var resuming: Game?

    /// Die frisch angelegte Partie aus „Nochmal" – Aufstellung und Kennung
    /// liegen hier, bis der Spielscreen sie uebernimmt.
    @State private var quickStart: (teams: [Team], format: GameFormat, gameId: String)?
    @State private var isStartingQuickGame = false
    @State private var quickStartError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                newGameLink
                rematchLink
                rulesCard
                destinationCards
                backupCard
            }
            .padding(20)
        }
        .background(AmbientBackdrop())
        .verticalScrollOnly()
        .navigationTitle("Beerpong")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: askAboutRunningGame)
        // Die Partien kommen ueber einen Listener nach; beim Erscheinen ist
        // die Liste oft noch leer.
        .onChange(of: viewModel.resumableGame?.id) { _ in askAboutRunningGame() }
        // Navigiert wird erst, wenn das Blatt zu ist. Beides gleichzeitig
        // laesst den Push verschlucken.
        .sheet(item: $prompt, onDismiss: {
            route = pendingRoute
            pendingRoute = nil
        }) { game in
            ResumePromptView(
                game: game,
                throwRepository: container.throwRepository,
                onResume: {
                    resuming = game
                    pendingRoute = .running
                    prompt = nil
                },
                onNewGame: {
                    // Abbrechen laeuft nebenher: Der Log bleibt erhalten, die
                    // Partie verschwindet nur aus der Wertung. Scheitert es,
                    // steht die Frage beim naechsten Mal wieder da – das ist
                    // die harmlosere Richtung als eine Partie, die gar nicht
                    // mehr auftaucht.
                    if let id = game.id {
                        Task { try? await container.gameRepository.cancelGame(gameId: id) }
                    }
                    pendingRoute = .newGame
                    prompt = nil
                }
            )
        }
        .navigationDestination(
            isPresented: Binding(
                get: { route != nil },
                set: { if !$0 { route = nil } }
            )
        ) {
            switch route {
            case .running:
                if let resuming { liveGame(for: resuming) }
            case .newGame:
                NewGameView(container: container, currentUserId: viewModel.currentUserId)
            case .quickStart:
                if let quickStart {
                    LiveGameView(
                        teams: quickStart.teams,
                        format: quickStart.format,
                        playersPerTeam: quickStart.teams.first?.playerIds.count ?? 2,
                        perspectiveTeamIndex: 0,
                        gameId: quickStart.gameId,
                        throwRepository: container.throwRepository,
                        gameRepository: container.gameRepository,
                        profileRepository: container.playerProfileRepository,
                        ownerId: viewModel.currentUserId
                    )
                }
            case .none:
                EmptyView()
            }
        }
    }

    /// Fragt einmal je Partie nach – beim Betreten des Menues.
    private func askAboutRunningGame() {
        guard let game = viewModel.resumableGame,
              let id = game.id,
              id != askedFor else { return }

        askedFor = id
        prompt = game
    }

    // MARK: - Spielen

    private var newGameLink: some View {
        NavigationLink {
            NewGameView(container: container, currentUserId: viewModel.currentUserId)
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
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    /// Die laufende Partie, so wie sie verlassen wurde.
    private func liveGame(for game: Game) -> some View {
        LiveGameView(
            teams: game.teams,
            format: game.format,
            playersPerTeam: game.type == .oneVsOne ? 1 : 2,
            perspectiveTeamIndex: 0,
            gameId: game.id,
            throwRepository: container.throwRepository,
            gameRepository: container.gameRepository,
            profileRepository: container.playerProfileRepository,
            ownerId: viewModel.currentUserId
        )
    }

    // MARK: - Auswertung

    private var destinationCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AUSWERTUNG")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .kerning(1.8)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .padding(.top, 4)

            NavigationLink {
                ProfilesView(container: container, ownerId: viewModel.currentUserId)
            } label: {
                destinationCard(
                    title: "Mitspieler & Statistiken",
                    subtitle: "Profile anlegen, Werte ansehen, vergleichen",
                    systemImage: "chart.bar.xaxis",
                    tint: BeerStatsColor.accent
                )
            }
            .buttonStyle(PressableButtonStyle())

            NavigationLink {
                LeaderboardView(profiles: viewModel.profiles)
            } label: {
                destinationCard(
                    title: "Rangliste",
                    subtitle: viewModel.leadingProfile.map { "Aktuell vorn: \($0.name)" }
                        ?? "Noch keine Wertung",
                    systemImage: "trophy.fill",
                    tint: BeerStatsColor.warning
                )
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(viewModel.profiles.isEmpty)
            .opacity(viewModel.profiles.isEmpty ? 0.45 : 1)

            NavigationLink {
                GameHistoryView(
                    gameRepository: container.gameRepository,
                    ownerId: viewModel.currentUserId
                )
            } label: {
                destinationCard(
                    title: "Spielverlauf",
                    subtitle: "Vergangene Partien mit Ergebnis",
                    systemImage: "clock.arrow.circlepath",
                    tint: BeerStatsColor.success
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: - Nochmal dieselben

    /// Dieselbe Aufstellung wie beim letzten Mal, in einem Griff.
    ///
    /// Verschwindet, sobald auch nur eine Person fehlt – ausgemustert oder
    /// geloescht. Eine Aufstellung mit einer Luecke halb anzubieten waere ein
    /// Knopf, der erst im Spielscreen scheitert.
    @ViewBuilder
    private var rematchLink: some View {
        if let lineup = LastLineup.resolved(against: viewModel.profiles) {
            Button {
                Task { await startQuickGame(lineup) }
            } label: {
                HStack(spacing: 14) {
                    Text("🔁").font(.system(size: 26))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isStartingQuickGame ? "Wird gestartet …" : "Nochmal dieselben")
                            .font(BeerStatsFont.headline)
                            .foregroundStyle(BeerStatsColor.textPrimary)
                        Text(lineup.teams.map { $0.map(\.name).joined(separator: " & ") }
                            .joined(separator: " gegen "))
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
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
            .disabled(isStartingQuickGame)

            if let quickStartError {
                Text(quickStartError)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.error)
            }
        }
    }

    /// Legt die Partie an und geht hinein.
    ///
    /// Mit den aktuellen Hausregeln, nicht mit denen von damals: Die
    /// Aufstellung wird wiederholt, nicht das Regelwerk – wer seitdem den
    /// Bounce abgeschaltet hat, will ihn auch hier nicht zurueck.
    private func startQuickGame(_ lineup: (type: GameType, teams: [[PlayerProfile]])) async {
        guard !isStartingQuickGame else { return }
        isStartingQuickGame = true
        quickStartError = nil
        defer { isStartingQuickGame = false }

        let teams = lineup.teams.map { leute in
            Team(
                id: UUID().uuidString,
                playerIds: leute.compactMap(\.id),
                playerNames: leute.map(\.name),
                ballsInPlay: leute.count
            )
        }

        do {
            let format = GameFormat.houseRules
            let gameId = try await container.gameRepository.createAndStart(
                type: lineup.type,
                teams: teams,
                format: format,
                ownerId: viewModel.currentUserId
            )
            quickStart = (teams: teams, format: format, gameId: gameId)
            route = .quickStart
            HapticManager.success()
        } catch {
            HapticManager.error()
            quickStartError = AppError.from(error).errorDescription
        }
    }

    // MARK: - Nachschlagen

    /// Steht bewusst weit oben und nicht bei der Auswertung: Gebraucht wird
    /// das, BEVOR gespielt wird – meistens von jemandem, der zum ersten Mal
    /// mit am Tisch steht.
    private var rulesCard: some View {
        NavigationLink {
            // Mit den Hausregeln, nicht mit dem Standard: Seit die
            // Sonderregeln abschaltbar sind, waere eine Erklaerung des
            // Standards an einem Tisch ohne Bounce schlicht falsch – und
            // falsche Regeln sind schlimmer als keine, weil man ihnen glaubt.
            RulesView(format: .houseRules)
        } label: {
            destinationCard(
                title: "Regeln",
                subtitle: "Balls Back, Bombe, On Fire – alles zum Nachlesen",
                systemImage: "book.fill",
                tint: BeerStatsColor.textSecondary
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Sicherung

    /// Eigener Abschnitt, nicht bei der Auswertung: Das hier wertet nichts
    /// aus, es holt die Daten heraus. Und es steht bewusst im Hauptweg statt
    /// bei den Entwicklereinstellungen – hinter dem Passwort wuerde es
    /// niemand finden, der es braucht.
    private var backupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SICHERUNG")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .kerning(1.8)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .padding(.top, 4)

            NavigationLink {
                DataExportView(container: container, ownerId: viewModel.currentUserId)
            } label: {
                destinationCard(
                    title: "Daten sichern",
                    subtitle: backupSubtitle,
                    systemImage: "arrow.down.doc.fill",
                    tint: BackupReminder.isDue
                        ? BeerStatsColor.warning
                        : BeerStatsColor.accentSecondary
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    /// Sagt, wann zuletzt gesichert wurde – und wird deutlich, wenn es zu
    /// lange her ist.
    ///
    /// Die Datei ist das einzige Netz, das diese Daten haben. Ein Hinweis,
    /// der erst erscheint, wenn etwas passiert ist, waere keiner.
    private var backupSubtitle: String {
        guard let tage = BackupReminder.daysSinceLastExport else {
            return "Noch nie gesichert – es gibt keine zweite Kopie"
        }
        switch tage {
        case 0: return "Heute gesichert"
        case 1: return "Gestern gesichert"
        case ..<BackupReminder.reminderAfterDays: return "Vor \(tage) Tagen gesichert"
        default: return "Letzte Sicherung vor \(tage) Tagen – wird Zeit"
        }
    }

    private func destinationCard(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.18))
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text(subtitle)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .lineLimit(1)
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
