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

    /// `currentUserId` ist `nil`, wenn ohne Konto gespielt wird. Dann
    /// fehlen genau zwei Dinge: Beerpong und die Spieler-Zentrale. Alles
    /// andere laeuft lokal weiter (siehe `GuestMode`).
    init(container: AppContainer, currentUserId: String?) {
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
                    gamePickerLink
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

    // MARK: - Der Würfel

    /// Steht UNTER dem Raster, nicht darin.
    ///
    /// Als siebte Kachel haette er die Ordnung zerschossen, die das Raster
    /// ausmacht – Beerpong oben links, Turnier unten rechts, vier Gruppen
    /// dazwischen. Und er ist auch nichts davon: kein Ort mit Spielen
    /// dahinter, sondern eine Abkuerzung fuer den Fall, dass die Runde sich
    /// nicht einigen kann.
    private var gamePickerLink: some View {
        NavigationLink {
            GamePickerView()
        } label: {
            HStack(spacing: 12) {
                Text("🎲").font(.system(size: 24))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Was spielen wir?")
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                    Text("Die App sucht eins aus, das zur Runde passt")
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
            .neonEdge(BeerStatsColor.accent, cornerRadius: 16, intensity: 0.35)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
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
        // Die Spieler-Zentrale haengt an den Profilen und damit am Konto.
        // Ohne Konto ist sie weg statt grau: Ein Symbol, das nichts tut,
        // probiert man am Tisch dreimal.
        if let ownerId = viewModel.currentUserId {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ProfilesView(container: container, ownerId: ownerId)
                } label: {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(BeerStatsColor.accent)
                }
                .accessibilityLabel("Spieler")
            }
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
            if viewModel.currentUserId != nil {
                menuTile(
                    emoji: "🍺",
                    title: "Beerpong",
                    subtitle: "Werfen, treffen – die App schreibt mit",
                    detail: beerpongDetail,
                    // Wer heute am Tisch steht, statt der Spiele darin: Bei
                    // Beerpong ist die Frage vor dem Antippen nicht "was",
                    // sondern "mit wem".
                    preview: tablePlayers.map(\.emoji),
                    tint: BeerStatsColor.accent
                ) {
                    BeerpongMenuView(container: container, viewModel: viewModel)
                }
            } else {
                // Ohne Konto bleibt die Kachel stehen und sagt, was fehlt.
                // Sie wegzulassen waere die schlechtere Wahl: Dann sieht
                // niemand, dass die App ueberhaupt Beerpong kann, und das
                // ist der Grund, warum es sie gibt.
                menuTile(
                    emoji: "🍺",
                    title: "Beerpong",
                    subtitle: "Werfen, treffen – die App schreibt mit",
                    detail: "Braucht ein Konto",
                    preview: [],
                    tint: BeerStatsColor.textSecondary
                ) {
                    AccountNeededView()
                }
            }

            // Die Gruppen kommen aus dem Katalog, nicht von Hand: Ein neues
            // Spiel landet dadurch von selbst in seiner Kachel.
            ForEach(PartyGame.Group.allCases) { group in
                menuTile(
                    emoji: group.emoji,
                    title: group.label,
                    subtitle: group.subtitle,
                    detail: "\(group.games.count) Spiele",
                    preview: group.games.map(\.emoji),
                    tint: group.tint
                ) {
                    PartyGameFolderView(group: group)
                }
            }

            menuTile(
                emoji: "🏆",
                title: "Turnier",
                subtitle: "Runde für Runde, die Strafe steigt",
                detail: "\(tournamentGames.count) Spiele im Topf",
                preview: tournamentGames.map(\.emoji),
                tint: BeerStatsColor.warning
            ) {
                TournamentView()
            }
        }
    }

    /// Die Spiele, die das Turnier ueberhaupt auslosen kann.
    ///
    /// Gerechnet, nicht getippt – sonst steht hier nach dem naechsten Spiel
    /// eine falsche Zahl (dieselbe Falle wie beim Spielezaehler).
    private var tournamentGames: [PartyGame] {
        PartyGame.allCases.filter(\.isTournamentReady)
    }

    /// Was unter "Beerpong" steht.
    ///
    /// Die drei Kennzahlen von vorher – Mitspieler, Partien, Spitzenreiter –
    /// passen nicht in eine Kachel. Die beiden, die sich ueberhaupt aendern,
    /// passen in eine Zeile; der Spitzenreiter steht einen Tipp weiter in
    /// der Rangliste, wo man ihn ohnehin sucht.
    ///
    /// Gezaehlt wird, wer am Tisch steht – dieselbe Quelle wie die
    /// Emoji-Reihe darueber. Mit den aktiven Profilen stuenden sonst vier
    /// Gesichter ueber "6 Leute", sobald jemand abgewaehlt ist, und das
    /// sieht aus wie ein Fehler.
    private var beerpongDetail: String {
        let partien = viewModel.totalGamesTracked
        guard partien > 0 else { return "Noch keine Partie" }
        let wort = partien == 1 ? "Partie" : "Partien"
        guard !tablePlayers.isEmpty else { return "\(partien) \(wort)" }
        return "\(partien) \(wort) · \(tablePlayers.count) am Tisch"
    }

    /// Eine Kachel.
    ///
    /// Drei Zeilen und eine Vorschau, nicht bloss Titel und Zahl: Die Kachel
    /// fuellt den halben Bildschirm, und was darin steht, soll die Frage
    /// beantworten, die man vor dem Antippen hat – was ist da drin? Die
    /// Emoji-Reihe ist genau das: die Spiele der Gruppe, am Tisch erkennt
    /// man sie daran schneller als an ihren Namen.
    ///
    /// Die Hoehe ist eine MINDESThoehe: Mit grosser Schrift wird die Kachel
    /// hoeher, statt den Titel abzuschneiden, und das Raster zieht die
    /// Nachbarin in derselben Zeile mit.
    private func menuTile<Destination: View>(
        emoji: String,
        title: String,
        subtitle: String,
        detail: String,
        preview: [String],
        tint: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                Text(emoji)
                    .font(.system(size: 30))
                    .frame(width: 52, height: 52)
                    .background(
                        tint.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                    )

                Text(title)
                    .font(.scaled(18, weight: .bold, design: .rounded))
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.scaled(12, weight: .medium, design: .rounded))
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 6)

                if !preview.isEmpty {
                    // Eine Zeile, notfalls kleiner: Zehn Emoji passen sonst
                    // nicht in eine halbe Bildschirmbreite, und umbrechen
                    // wuerde die Kachel je nach Gruppe unterschiedlich hoch
                    // machen.
                    Text(preview.joined(separator: " "))
                        .font(.system(size: 15))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        // Fuer VoiceOver ist die Reihe Zierde – vorgelesen
                        // waere sie eine Kette von Emoji-Namen.
                        .accessibilityHidden(true)
                }

                Text(detail)
                    .font(.scaled(11, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // `maxHeight: .infinity` zieht die kuerzere Kachel auf die
            // Hoehe ihrer Nachbarin: "Beerpong" ist einzeilig, "Schnell
            // zwischendurch" zweizeilig – ohne das stuenden in einer Reihe
            // zwei verschieden hohe Panels nebeneinander.
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 172, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
            .glassPanel()
            .neonEdge(tint, intensity: 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
