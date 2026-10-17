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
                    // Die Härte stand hier, über allen Partyspielen. Sie
                    // steht jetzt im Vorspann jedes Spiels, das Mengen
                    // ausspricht: Mäxchen wird anders getrunken als
                    // Trink-Roulette, und von hier oben aus ist das nicht zu
                    // treffen.
                    menuGrid
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

    // MARK: - Das Menue

    /// Sechs Kacheln, zwei Spalten: Beerpong oben links, dann die vier
    /// Gruppen, Turnier unten rechts.
    ///
    /// Vorher war es eine Liste ueber die ganze Breite – eine grosse Karte
    /// fuer Beerpong, darunter vier Ordnerzeilen, darunter das Turnier. Das
    /// las sich von oben nach unten und hiess jedes Mal: scrollen, lesen,
    /// treffen. Als Raster liegt alles gleichzeitig da, und jede Kachel
    /// liegt immer an derselben Stelle – nach dem zweiten Abend trifft man
    /// sie, ohne hinzusehen.
    ///
    /// Beerpong steht oben links, das Turnier unten rechts: Das eine ist der
    /// haeufigste Griff, das andere der seltenste.
    private var menuGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ],
            spacing: 14
        ) {
            menuTile(
                emoji: "🍺",
                title: "Beerpong",
                detail: beerpongDetail,
                tint: BeerStatsColor.accent
            ) {
                BeerpongMenuView(container: container, viewModel: viewModel)
            }

            // Die Gruppen kommen aus dem Katalog, nicht von Hand: Ein neues
            // Spiel landet dadurch von selbst in seiner Kachel.
            ForEach(PartyGame.Group.allCases) { group in
                menuTile(
                    emoji: group.emoji,
                    title: group.label,
                    detail: "\(group.games.count) Spiele",
                    tint: group.tint
                ) {
                    PartyGameFolderView(group: group)
                }
            }

            menuTile(
                emoji: "🏆",
                title: "Turnier",
                detail: "Quer durch die Spiele",
                tint: BeerStatsColor.warning
            ) {
                TournamentView()
            }
        }
    }

    /// Was unter "Beerpong" steht.
    ///
    /// Die drei Kennzahlen von vorher – Mitspieler, Partien, Spitzenreiter –
    /// passen nicht in eine Kachel. Die beiden, die sich ueberhaupt aendern,
    /// passen in eine Zeile; der Spitzenreiter steht einen Tipp weiter in
    /// der Rangliste, wo man ihn ohnehin sucht.
    private var beerpongDetail: String {
        let partien = viewModel.totalGamesTracked
        guard partien > 0 else { return "Noch keine Partie" }
        let wort = partien == 1 ? "Partie" : "Partien"
        return "\(partien) \(wort) · \(viewModel.activeProfiles.count) Leute"
    }

    /// Eine Kachel.
    ///
    /// Die Hoehe ist eine MINDESThoehe: Mit grosser Schrift wird die Kachel
    /// hoeher, statt den Titel abzuschneiden, und das Raster zieht die
    /// Nachbarin in derselben Zeile mit.
    private func menuTile<Destination: View>(
        emoji: String,
        title: String,
        detail: String,
        tint: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(emoji)
                    .font(.system(size: 34))
                    .frame(height: 40)

                Spacer(minLength: 4)

                Text(title)
                    .font(.scaled(18, weight: .bold, design: .rounded))
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(.scaled(11, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 142, alignment: .topLeading)
            .padding(16)
            .glassPanel()
            .neonEdge(tint, intensity: 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
