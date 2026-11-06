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
//  Aufgebaut wie ein App-Store (Entscheidung des Nutzers vom 4. November,
//  Entwurf B): Beerpong gross oben, darunter Wuerfel und Turnier als zwei
//  Abkuerzungen, dann alle Partyspiele als Cover in einem Raster – mit
//  Filtern nach Gruppe statt vier Ordnern. Ein Ordner war ein Tipp mehr
//  vor jedem Spiel und versteckte, was drin liegt; ein Cover zeigt es.
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
    /// Welche Gruppe gezeigt wird; `nil` heisst alle.
    @State private var filter: PartyGame.Group?

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
                    // Direkt unter dem Abend: Wer sich vertippt hat, geht
                    // aus dem Spiel einmal zurueck und sieht es hier.
                    LastBookingRow(evening: runningEvening) {
                        runningEvening = EveningLog.current
                    }
                    // Die Härte stand hier, über allen Partyspielen. Sie
                    // steht jetzt im Vorspann jedes Spiels, das Mengen
                    // ausspricht: Mäxchen wird anders getrunken als
                    // Trink-Roulette, und von hier oben aus ist das nicht zu
                    // treffen.
                    beerpongHero
                    shortcuts
                    VStack(alignment: .leading, spacing: 14) {
                        filterChips
                        gridHeading
                        coverGrid
                    }
                    customCardsLink
                }
                .padding(20)
            }
            .background(AmbientBackdrop())
            // Die Spielauswahl liess sich seitlich verschieben und federte
            // zurueck - irgendein Kind ist breiter als der Bildschirm.
            .verticalScrollOnly()
            .toolbar { toolbarContent }
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
        // Jedes Spiel, das Namen zeigen kann, nimmt sie sich von hier – und
        // zwar AUSSEN am Stack, nicht an seinem ersten Screen. Was der
        // NavigationStack hereinschiebt, erbt die Umgebung vom Stack, nicht
        // vom Screen, auf dem der Link sass: Innen gesetzt kam die Liste in
        // keinem Spiel an, und "Kennst du deine Leute?" verlangte Mitspieler,
        // obwohl sie angehakt waren (4. November).
        .environment(\.tablePlayers, tablePlayers)
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

    // MARK: - Beerpong

    /// Gross und ueber allem: der haeufigste Griff des Abends.
    @ViewBuilder
    private var beerpongHero: some View {
        if let ownerId = viewModel.currentUserId {
            NavigationLink {
                BeerpongMenuView(container: container, viewModel: viewModel, ownerId: ownerId)
            } label: {
                // Wer heute am Tisch steht, statt einer Vorschau: Bei
                // Beerpong ist die Frage vor dem Antippen nicht "was",
                // sondern "mit wem".
                heroLabel(detail: beerpongDetail, faces: tablePlayers.map(\.emoji), tint: BeerStatsColor.accent)
            }
            .buttonStyle(PressableButtonStyle())
        } else {
            // Ohne Konto bleibt Beerpong stehen und sagt, was fehlt. Es
            // wegzulassen waere die schlechtere Wahl: Dann sieht niemand,
            // dass die App ueberhaupt Beerpong kann, und das ist der Grund,
            // warum es sie gibt.
            NavigationLink {
                AccountNeededView()
            } label: {
                heroLabel(detail: "Braucht ein Konto", faces: [], tint: BeerStatsColor.textSecondary)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func heroLabel(detail: String, faces: [String], tint: Color) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Beerpong")
                    .font(.scaled(26, weight: .heavy, design: .rounded))
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text("Werfen, treffen – die App schreibt mit")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !faces.isEmpty {
                    // Eine Zeile, notfalls kleiner – umbrechen wuerde den
                    // Kasten je nach Runde verschieden hoch machen
                    Text(faces.joined(separator: " "))
                        .font(.system(size: 17))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        // Fuer VoiceOver Zierde: vorgelesen waere sie eine
                        // Kette von Emoji-Namen
                        .accessibilityHidden(true)
                }
                Text(detail)
                    .font(.scaled(11, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Platz fuer das Plakat rechts, damit kein Text darauf steht
            Spacer(minLength: Self.heroArtVisible)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Das Plakat "Der Wurf" statt eines Bierglases (6. November) –
        // dieselbe Zeichnung wie das App-Icon. Links blendet es aus, damit
        // es in den Kasten uebergeht statt daraufzukleben.
        .background(alignment: .trailing) {
            BeerpongPosterView()
                .frame(width: Self.heroArtSize, height: Self.heroArtSize)
                .offset(x: 8)
                .mask(
                    LinearGradient(
                        stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.34)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        // Das Plakat ist hoeher als der Kasten – es endet an seinem Rand
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(
            LinearGradient(
                colors: [tint.opacity(0.22), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .glassPanel(cornerRadius: 20)
        .neonEdge(tint, cornerRadius: 20, intensity: 0.5)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// So gross steht das Plakat im Beerpong-Kasten, und so viel davon ist
    /// zu sehen, bevor es nach links ausblendet.
    private static let heroArtSize: CGFloat = 150
    private static let heroArtVisible: CGFloat = 92

    /// Was unter "Beerpong" steht.
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

    // MARK: - Abkuerzungen

    /// Wuerfel und Turnier nebeneinander, unter Beerpong und ueber den
    /// Spielen: Beide sind kein Spiel, sondern ein Weg zu einem – fuer den
    /// Fall, dass die Runde sich nicht einigen kann oder alles will.
    private var shortcuts: some View {
        HStack(spacing: 12) {
            NavigationLink {
                GamePickerView()
            } label: {
                shortcutLabel(emoji: "🎲", title: "Was spielen wir?", detail: "Die App sucht aus", tint: BeerStatsColor.accent)
            }
            .buttonStyle(PressableButtonStyle())

            NavigationLink {
                TournamentView()
            } label: {
                shortcutLabel(emoji: "🏆", title: "Turnier", detail: "\(tournamentGames.count) Spiele im Topf", tint: BeerStatsColor.warning)
            }
            .buttonStyle(PressableButtonStyle())
        }
        // Erst damit kann `maxHeight: .infinity` beide auf die Hoehe der
        // hoeheren ziehen
        .fixedSize(horizontal: false, vertical: true)
    }

    private func shortcutLabel(emoji: String, title: String, detail: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 24))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.scaled(14, weight: .bold, design: .rounded))
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.scaled(11, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        // Beide gleich hoch, auch wenn ein Titel umbricht
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 16)
        .neonEdge(tint, cornerRadius: 16, intensity: 0.3)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Die Spiele, die das Turnier ueberhaupt auslosen kann.
    ///
    /// Gerechnet, nicht getippt – sonst steht hier nach dem naechsten Spiel
    /// eine falsche Zahl (dieselbe Falle wie beim Spielezaehler).
    private var tournamentGames: [PartyGame] {
        PartyGame.allCases.filter(\.isTournamentReady)
    }

    // MARK: - Die Spiele

    /// Die Gruppen sind Filter, keine Ordner. Sie kommen aus dem Katalog,
    /// nicht von Hand: Ein neues Spiel landet von selbst unter seinem Filter.
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(emoji: "✨", label: "Alle", group: nil, tint: BeerStatsColor.accent)
                ForEach(PartyGame.Group.allCases) { group in
                    chip(emoji: group.emoji, label: group.label, group: group, tint: group.tint)
                }
            }
            // Platz fuer den Schein der gewaehlten Kante
            .padding(.vertical, 2)
        }
    }

    private func chip(emoji: String, label: String, group: PartyGame.Group?, tint: Color) -> some View {
        let gewaehlt = filter == group
        return Button {
            filter = group
            HapticManager.lightImpact()
        } label: {
            HStack(spacing: 5) {
                Text(emoji)
                Text(label)
            }
            .font(.scaled(13, weight: .heavy, design: .rounded))
            .foregroundStyle(gewaehlt ? BeerStatsColor.textPrimary : BeerStatsColor.textSecondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(
                gewaehlt ? tint.opacity(0.3) : BeerStatsColor.surfaceElevated.opacity(0.6),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(gewaehlt ? tint : Color.clear, lineWidth: 1.5))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(gewaehlt ? .isSelected : [])
    }

    /// Was gerade gezeigt wird – mit dem Satz der Gruppe, der vorher oben im
    /// Ordner stand: Passt diese Gruppe gerade zur Runde?
    private var gridHeading: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(filter?.label ?? "Alle Spiele")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Spacer(minLength: 8)
                Text("\(shownGames.count) Spiele")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            if let filter {
                Text(filter.subtitle)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var shownGames: [PartyGame] {
        filter?.games ?? PartyGame.allCases
    }

    /// Zwei Spalten Cover. Ein Tipp fuehrt auf die Seite des Spiels, nicht
    /// direkt hinein: Dort stehen Anleitung und "Spielen", und die Anleitung
    /// liegt nicht mehr als Fragezeichen genau neben dem Weg ins Spiel.
    private var coverGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ],
            spacing: 16
        ) {
            ForEach(shownGames) { game in
                NavigationLink {
                    PartyGameDetailView(game: game)
                } label: {
                    PartyGameCover(game: game)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }
}
