//
//  HitparadeView.swift
//  BeerStats
//
//  Hitparade: Ein Lied laeuft, und die App fragt etwas dazu – wohin es in
//  deine Reihe gehoert, wie es heisst, wer es singt oder aus welchem Jahr es
//  ist. Wer richtig liegt, bekommt die Karte; wer zuerst genug hat, gewinnt.
//  Vorbild ist Hitster, die Regeln stehen als reine Rechnung in
//  `HitparadeGame`.
//
//  Hiess bis zum 29. Oktober "Zeitstrahl" und konnte nur einsortieren. Im
//  Katalog heisst der Fall weiter `timeline` – sein Rohwert steckt in den
//  Einstellungen (Haerte), siehe CLAUDE.md. Der Screen heisst dagegen nicht
//  mehr `TimelineView`: Der Name verdeckte die Zeitleiste von SwiftUI und
//  hat einmal einen ganzen Build gekostet (Lessons Learned Nr. 15).
//
//  **Die App spielt das Lied selbst** (`SongPreviewPlayer`): Das Handy liegt
//  in der Mitte, und vor dem Aufdecken steht nirgends Titel, Interpret,
//  Cover oder Jahr. Vorher musste der Nachbar das Lied von Hand auf der Box
//  suchen und sah dabei genau das, wonach jetzt gefragt wird. Diesen Weg
//  gibt es weiter – als Wahl im Vorspann und als Rueckfall, wenn die
//  Hoerprobe nicht kommt (`usesBox`).
//
//  Getippt wird auf Luecken in einer senkrechten Liste, nicht auf einen
//  Zeitstrahl, den man schiebt. Mit acht Karten waere die Reihe schmaler
//  als ein Daumen, und wer am Tisch daneben tippt, verliert eine Runde,
//  die er richtig geraten hat.
//

import SwiftUI

struct HitparadeView: View {

    private enum Phase: Equatable {
        case setup
        /// Nur ueber die Box: Das Handy geht zum Nachbarn, der das Lied anspielt.
        case handoff
        /// Die Frage steht, das Lied laeuft, geantwortet wird.
        case turn
        /// Titel oder Interpret: aufgedeckt, die Runde entscheidet.
        case judging
        case result(correct: Bool)
        case won(player: Int)
    }

    /// Woher die Musik kommt.
    enum MusicSource: String {
        /// Die App spielt die Hoerprobe – braucht Netz.
        case app
        /// Der Nachbar spielt das Lied auf eurer Box an.
        case box
    }

    @AppStorage("hitparade.questions") private var storedQuestions = HitQuestion.allCases.map(\.rawValue).joined(separator: ",")
    @AppStorage("hitparade.source") private var storedSource = MusicSource.app.rawValue
    @AppStorage("hitparade.target") private var target = 7

    @State private var phase: Phase = .setup
    @State private var playerCount = 4
    @State private var game: HitparadeGame?
    @State private var yearGuess = HitparadeView.middleYear
    /// Woher die Musik in DIESEM Zug kommt – beim Zugbeginn aus der
    /// Einstellung uebernommen, und auf die Box umgestellt, wenn die
    /// Hoerprobe nicht kam. Eine eigene Kopie, weil die Einstellung sich
    /// im Zahnrad mitten im Zug aendern laesst: Liesse der Zug sich davon
    /// umstellen, stuende ploetzlich die Huelle mit Titel da, waehrend
    /// geraten wird.
    @State private var turnSource: MusicSource = .app
    /// Wurde fuer die falsche Antwort von eben schon getrunken? Dann bekommt
    /// man den Schluck zurueck, wenn die Runde das Jahr verwirft.
    @State private var bookedPenalty = false
    /// Zaehlt die Zuege – damit der Aufkleber jede Runde neu aufschlaegt.
    @State private var turnCount = 0
    @StateObject private var music = SongPreviewPlayer()

    @Environment(\.gameWorld) private var world
    @Environment(\.openURL) private var openURL

    private let penalty = DrinkAmount.sips(2)
    private var tint: Color { BeerStatsColor.accentSecondary }

    /// Grob gerechnet fuer die Dauer im Vorspann: Richtig liegt man am Tisch
    /// etwa bei drei von fuenf Liedern, und ein Lied dauert mit Hoeren,
    /// Raten und Aufdecken gut eine Dreiviertelminute. Geschaetzt, nicht
    /// gemessen – steht deshalb auch unter den Pruefpunkten am Geraet.
    private static let hitRate = 0.6
    private static let minutesPerSong = 0.75

    /// Wo das Zaehlwerk steht, bevor jemand dreht: die Mitte des Stapels.
    /// Ein Anfang am Rand waere ein Hinweis, wo die Antwort liegt.
    private static var middleYear: Int { (SongDeck.span.lowerBound + SongDeck.span.upperBound) / 2 }
    /// Das Zaehlwerk reicht weiter als der Stapel – sonst verraete sein Ende,
    /// dass es kein Lied von danach gibt.
    private static var yearRange: ClosedRange<Int> { 1950...Calendar.current.component(.year, from: Date()) }

    private var chosenQuestions: Set<HitQuestion> {
        Set(storedQuestions.split(separator: ",").compactMap { HitQuestion(rawValue: String($0)) })
    }

    private var source: MusicSource { MusicSource(rawValue: storedSource) ?? .app }
    private var usesBox: Bool { turnSource == .box }

    private var player: Int { game?.player ?? 0 }
    /// Wer ueber die Box anspielt: der Nachbar dessen, der dran ist.
    private var dj: Int { playerCount > 1 ? (player + 1) % playerCount : 0 }
    private var name: String { PlayerNames.name(for: player) }

    var body: some View {
        Group {
            switch phase {
            case .setup: setupView
            case .handoff: handoffView
            case .turn: turnView
            case .judging: judgingView
            case .result(let correct): resultView(correct: correct)
            case .won(let player): wonView(player: player)
            }
        }
        .navigationTitle("Hitparade")
        .navigationBarTitleDisplayMode(.inline)
        // Spielerzahl und Ziel fehlen im Zahnrad mit Absicht: Beides legt
        // die Partie fest, und wer es aendern will, faengt eine neue an
        .roundSettings(
            for: .timeline,
            isAvailable: phase != .setup,
            note: "Fragen und Musik gelten ab dem nächsten Lied, die Härte ab der nächsten Strafe.",
            onClose: applySettings
        ) {
            VStack(alignment: .leading, spacing: 20) {
                questionsBlock
                sourceBlock
            }
        }
        .onAppear(perform: adoptTableCount)
        // Nichts laeuft weiter, wenn das Spiel weg ist
        .onDisappear { music.stop() }
    }

    // MARK: - Vorbereitung

    private var setupView: some View {
        GameSetupScreen(
            emoji: "🎵",
            title: "Hitparade",
            subtitle: "Ein Lied läuft – die App fragt, wie es heißt, wer es singt, aus welchem Jahr es ist oder wohin es in deine Reihe gehört.",
            tint: tint,
            startTitle: "Los geht's",
            onStart: start
        ) {
            VStack(alignment: .leading, spacing: 20) {
                block("WIE VIELE SPIELT IHR?") {
                    PlayerCountStepper(count: $playerCount, range: 2...PartyGame.manyPlayers, tint: tint)
                }

                block("WER ZUERST SO VIELE KARTEN HAT, GEWINNT") {
                    ChoiceRow(
                        options: [
                            ChoiceOption(value: 5, title: "5", detail: "kurz"),
                            ChoiceOption(value: 7, title: "7", detail: "mittel"),
                            ChoiceOption(value: 10, title: "10", detail: "wie bei Hitster")
                        ],
                        selection: $target,
                        tint: tint
                    )
                    hint(lengthHint)
                }

                questionsBlock
                sourceBlock

                DrinkIntensityPicker(game: .timeline)
            }
        }
    }

    /// Im Vorspann und im Zahnrad dieselben Schalter.
    private var questionsBlock: some View {
        block("WAS GEFRAGT WIRD") {
            questionToggles
            hint("Jede Runde lost die App eine der angehakten Fragen aus. Wer richtig liegt, bekommt die Karte in seine Reihe – egal, was gefragt war.")
        }
    }

    private var sourceBlock: some View {
        block("WOHER DIE MUSIK KOMMT") {
            ChoiceRow(
                options: [
                    ChoiceOption(value: MusicSource.app.rawValue, title: "App", detail: "Hörprobe, braucht Netz"),
                    ChoiceOption(value: MusicSource.box.rawValue, title: "Box", detail: "Nachbar spielt an")
                ],
                selection: $storedSource,
                tint: tint
            )
            hint(source == .app
                 ? "Die App spielt 30 Sekunden des Lieds, ohne Titel oder Cover zu zeigen. Ein Knopf schickt den Ton auf eure Box."
                 : "Der Nachbar sieht Titel und Interpret, sucht das Lied auf eurer Box und spielt es an, ohne den Titel vorzulesen.")
        }
    }

    private var lengthHint: String {
        let lieder = Int((Double(max(1, target - 1) * playerCount) / Self.hitRate).rounded())
        let minuten = max(5, Int((Double(lieder) * Self.minutesPerSong).rounded()))
        return "Mit \(playerCount) Leuten sind das ungefähr \(lieder) Lieder, also gut \(minuten) Minuten."
    }

    private var questionToggles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(HitQuestion.allCases) { frage in
                let an = chosenQuestions.contains(frage)
                Button {
                    toggle(frage)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: an ? "checkmark.circle.fill" : "circle")
                        Text(frage.title)
                            .font(BeerStatsFont.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(an ? BeerStatsColor.textOnAccent : BeerStatsColor.textSecondary)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                    .background(
                        an ? tint : BeerStatsColor.surfaceElevated.opacity(0.6),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityAddTraits(an ? .isSelected : [])
            }
        }
    }

    /// Die letzte angehakte Frage bleibt stehen – ohne Frage gaebe es kein
    /// Spiel, und ein Startknopf, der dann nichts tut, waere ein Raetsel.
    private func toggle(_ frage: HitQuestion) {
        var auswahl = chosenQuestions
        if auswahl.contains(frage) {
            guard auswahl.count > 1 else { return }
            auswahl.remove(frage)
        } else {
            auswahl.insert(frage)
        }
        storedQuestions = HitQuestion.allCases.filter(auswahl.contains).map(\.rawValue).joined(separator: ",")
        HapticManager.lightImpact()
    }

    private func block<Inhalt: View>(_ titel: String, @ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            label(titel)
            inhalt()
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.scaled(11, weight: .heavy, design: .rounded))
            .kerning(1.6)
            .foregroundStyle(BeerStatsColor.textSecondary)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(BeerStatsFont.caption)
            .foregroundStyle(BeerStatsColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Uebergabe (nur ueber die Box)

    private var handoffView: some View {
        panel {
            Text("\(PlayerNames.name(for: dj)) nimmt das Handy")
                .font(Font.world(world, 24, weight: .heavy))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(name) ist dran und darf nicht aufs Display schauen.")
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } buttons: {
            PrimaryButton(title: "Hab's – Lied anzeigen", systemImage: "music.note") {
                withAnimation(AppAnimation.standard) { phase = .turn }
            }
        }
    }

    // MARK: - Der Zug

    private var turnView: some View {
        ZStack {
            AmbientBackdrop(glow: tint)

            FillingScrollView(alignment: .top) {
                VStack(spacing: 18) {
                    scoreboard

                    if let game {
                        Text(name + " ist dran")
                            .font(Font.world(world, 22, weight: .heavy))
                            .foregroundStyle(BeerStatsColor.textPrimary)
                            .multilineTextAlignment(.center)

                        QuestionSticker(question: game.question)
                            .id(turnCount)
                            .transition(.scale(scale: 1.35).combined(with: .opacity))

                        Text(game.question.prompt)
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        if usesBox {
                            boxSleeve(game)
                        } else {
                            playerDeck
                        }

                        answerArea(game)
                    }
                }
                .padding(20)
            }
        }
    }

    /// Wer wie viele Karten hat – wer dran ist, ist hervorgehoben.
    private var scoreboard: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<playerCount, id: \.self) { index in
                    let dran = index == player
                    HStack(spacing: 6) {
                        Text(PlayerNames.plainName(for: index))
                            .lineLimit(1)
                        Text("\(game?.timelines[index].count ?? 0)/\(target)")
                            .monospacedDigit()
                    }
                    .font(.scaled(12, weight: .heavy, design: .rounded))
                    .foregroundStyle(dran ? BeerStatsColor.textOnAccent : BeerStatsColor.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(dran ? tint : BeerStatsColor.surfaceElevated.opacity(0.6), in: Capsule())
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Der Plattenspieler mit seinen Knoepfen.
    private var playerDeck: some View {
        VStack(spacing: 12) {
            Turntable(
                isPlaying: music.state == .playing,
                progress: music.progress,
                isLoading: music.state == .loading,
                tint: tint
            )
            .frame(maxWidth: 280)

            HStack(spacing: 18) {
                Button {
                    music.restart()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.scaled(17, weight: .bold))
                        .foregroundStyle(BeerStatsColor.textPrimary)
                        .frame(width: 48, height: 48)
                        .background(Color.white.opacity(0.08), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Von vorn")
                .disabled(music.state == .loading || music.state == .idle || music.state == .failed)

                playButton

                AudioRoutePicker()
                    .frame(width: 48, height: 48)
                    .accessibilityLabel("Ton auf eine Box schicken")
            }

            if music.state == .failed {
                Text("Die Hörprobe kommt nicht – vielleicht kein Netz.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.warning)
                    .multilineTextAlignment(.center)
                HStack(spacing: 4) {
                    QuietButton(title: "Anderes Lied", systemImage: "shuffle") { replaceSong() }
                    QuietButton(title: "Über die Box spielen", systemImage: "hifispeaker") { switchToBox() }
                }
            }
        }
    }

    private var playButton: some View {
        let spielt = music.state == .playing
        return Button {
            switch music.state {
            case .playing: music.pause()
            case .idle, .failed: playCurrent()
            case .loading: break
            case .paused, .finished: music.resume()
            }
        } label: {
            Image(systemName: spielt ? "pause.fill" : "play.fill")
                .font(.scaled(26, weight: .bold))
                .foregroundStyle(BeerStatsColor.textOnAccent)
                .frame(width: 68, height: 68)
                .background(tint, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(spielt ? "Pause" : "Abspielen")
        .disabled(music.state == .loading)
    }

    /// Ueber die Box: Der Nachbar sieht, was er anspielen soll – das Jahr
    /// nicht, und die Huelle bleibt schwarz.
    private func boxSleeve(_ game: HitparadeGame) -> some View {
        VStack(spacing: 10) {
            Text("SPIEL DAS AN")
                .font(Font.world(world, 12, weight: .heavy))
                .kerning(1.8)
                .foregroundStyle(BeerStatsColor.textSecondary)

            RecordSleeve(title: game.current?.title ?? "–", artist: game.current?.artist ?? "", year: nil)
                .frame(width: 210, height: 210)

            Text("Titel nicht vorlesen – vielleicht ist er die Frage.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func answerArea(_ game: HitparadeGame) -> some View {
        switch game.question {
        case .placement:
            VStack(spacing: 8) {
                hint("Tipp die Lücke, in die es gehört.")
                shelf(game.timeline, interactive: true)
            }
        case .yearWithinThree, .yearWithinOne:
            VStack(spacing: 14) {
                YearCounter(year: $yearGuess, range: Self.yearRange, tint: tint)
                PrimaryButton(title: "Aufdecken", systemImage: "eye") { answer(.year(yearGuess)) }
                shelf(game.timeline, interactive: false)
            }
        case .title, .artist:
            VStack(spacing: 14) {
                hint("Laut sagen, dann aufdecken. Die Runde entscheidet, ob es zählt.")
                PrimaryButton(title: "Aufdecken", systemImage: "eye") {
                    withAnimation(AppAnimation.standard) { phase = .judging }
                }
                shelf(game.timeline, interactive: false)
            }
        }
    }

    /// Die Reihe dessen, der dran ist: Karten, und beim Einsortieren die
    /// Luecken dazwischen.
    private func shelf(_ reihe: SongTimeline, interactive: Bool) -> some View {
        VStack(spacing: 8) {
            if !interactive {
                label("DEINE REIHE")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            }
            ForEach(Array(0..<reihe.gapCount), id: \.self) { luecke in
                if interactive {
                    gapButton(luecke, label: reihe.label(forGap: luecke))
                }
                if luecke < reihe.count {
                    cardRow(reihe.cards[luecke])
                }
            }
        }
    }

    private func gapButton(_ gap: Int, label text: String) -> some View {
        Button {
            answer(.gap(gap))
        } label: {
            Text(text)
                .font(.scaled(13, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    /// Ein Lied im Regal: der Ruecken in der Farbe seines Jahrzehnts.
    private func cardRow(_ card: SongCard) -> some View {
        HStack(spacing: 12) {
            RecordSpine(year: card.year)

            VStack(alignment: .leading, spacing: 1) {
                Text(card.title)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .lineLimit(1)
                Text(card.artist)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 12)
    }

    // MARK: - Aufdecken

    /// Die Platte rutscht aus der Huelle, jetzt mit Cover und der Farbe ihres
    /// Jahrzehnts – und darunter das Jahr in gross.
    @ViewBuilder
    private var revealedRecord: some View {
        if let card = game?.current {
            RecordReveal(title: card.title, artist: card.artist, year: card.year, artwork: usesBox ? nil : music.artworkURL)
                .frame(height: 190)

            Text(String(card.year))
                .font(Font.world(world, 48, weight: .heavy))
                .foregroundStyle(RecordShelf.color(forYear: card.year))
                .monospacedDigit()
        }
    }

    /// Titel oder Interpret: Die App kann nicht hoeren, was gesagt wurde –
    /// die Runde entscheidet.
    private var judgingView: some View {
        panel {
            revealedRecord

            if let game {
                Text(game.question == .title ? "Hatte \(name) den Titel?" : "Hatte \(name) den Interpreten?")
                    .font(Font.world(world, 22, weight: .heavy))
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if game.question == .artist {
                    hint("Singen mehrere, reicht einer.")
                }
            }
        } buttons: {
            HStack(spacing: 12) {
                verdictButton(true)
                verdictButton(false)
            }
        }
    }

    private func verdictButton(_ richtig: Bool) -> some View {
        Button {
            answer(.judged(richtig))
        } label: {
            HStack(spacing: 8) {
                Image(systemName: richtig ? "checkmark" : "xmark")
                Text(richtig ? "Richtig" : "Falsch")
            }
            .font(BeerStatsFont.headline)
            .foregroundStyle(BeerStatsColor.textOnAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(richtig ? BeerStatsColor.success : BeerStatsColor.error,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func resultView(correct: Bool) -> some View {
        panel {
            revealedRecord

            if let game, game.question.tolerance != nil {
                hint("Getippt: \(yearGuess)")
            }

            Text(correct
                 ? "Sitzt. Die Karte bleibt bei \(name)."
                 : "Daneben. \(name) trinkt \(penalty.text).")
                .font(BeerStatsFont.headline)
                .foregroundStyle(correct ? BeerStatsColor.success : BeerStatsColor.error)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } buttons: {
            PrimaryButton(title: "Weiter", systemImage: "arrow.right") { nextTurn() }

            if let card = game?.current, let spotify = spotifyLink(for: card) {
                // Erst jetzt: Spotify zeigt den Titel, sobald es aufgeht
                QuietButton(title: "Auf Spotify weiterhören", systemImage: "arrow.up.right") { openURL(spotify) }
            }

            // Die Notbremse: Der Stapel ist von Hand geschrieben, und wenn
            // die Runde das Jahr besser weiss als die App, gewinnt die
            // Runde. Ohne diesen Knopf traenke jemand fuer meinen Tippfehler.
            QuietButton(title: "Jahr stimmt nicht – Karte verwerfen") { discard() }
        }
    }

    private func wonView(player: Int) -> some View {
        panel {
            // Hinter dem Pokal, nicht darueber: Wer gewonnen hat, soll man
            // lesen koennen.
            Text("🏆")
                .font(.system(size: 62))
                // Eine Schallplatte dreht sich dahinter – das Spiel ist
                // Musik, und der Sieg soll nach diesem Spiel aussehen und
                // nicht nach jedem anderen.
                .background(
                    EffectCanvas(draw: SceneArt.record)
                        .frame(width: 260, height: 260)
                )

            Text("\(PlayerNames.name(for: player)) gewinnt")
                .font(Font.world(world, 24, weight: .heavy))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(target) Karten in der Reihe. Alle anderen trinken \(penalty.text).")
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } buttons: {
            PrimaryButton(title: "Neue Runde", systemImage: "arrow.clockwise") { start() }
            QuietButton(title: "Einstellungen ändern") {
                withAnimation(AppAnimation.standard) { phase = .setup }
            }
        }
    }

    /// Der gemeinsame Rahmen der Zwischenbildschirme – Inhalt mittig,
    /// Knoepfe unten, der Platz dazwischen gehoert dem Inhalt.
    private func panel<Content: View, Buttons: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder buttons: () -> Buttons
    ) -> some View {
        // Die beiden Closures werden HIER ausgewertet und nicht erst im
        // GeometryReader: Der ist escaping, und ein nicht-escaping
        // ViewBuilder darf dort nicht hinein (Lessons Learned Nr. 13).
        let inhalt = content()
        let knoepfe = buttons()

        return ZStack {
            AmbientBackdrop(glow: tint)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 14) {
                        Spacer(minLength: 0)
                        inhalt
                        Spacer(minLength: 0)
                        knoepfe
                    }
                    .padding(24)
                    .frame(minHeight: geometry.size.height)
                }
                .verticalScrollOnly()
            }
        }
    }

    // MARK: - Ablauf

    private func adoptTableCount() {
        guard phase == .setup, let vorschlag = PlayerNames.suggestedCount() else { return }
        playerCount = min(vorschlag, PartyGame.manyPlayers)
    }

    private func start() {
        var zufall = SystemRandomNumberGenerator()
        game = HitparadeGame(
            playerCount: playerCount,
            target: target,
            questions: chosenQuestions,
            songs: SongDeck.all,
            using: &zufall
        )
        turnCount = 0
        HapticManager.success()
        beginTurn()
    }

    /// Ein neuer Zug: Zaehlwerk zurueck auf die Mitte, und ueber die App
    /// laeuft das Lied sofort los – niemand muss erst etwas antippen.
    private func beginTurn() {
        turnSource = source
        bookedPenalty = false
        yearGuess = Self.middleYear
        withAnimation(AppAnimation.standard) {
            turnCount += 1
            phase = usesBox ? .handoff : .turn
        }
        if usesBox {
            music.stop()
        } else {
            playCurrent()
        }
    }

    private func playCurrent() {
        guard let game, let card = game.current else { return }
        music.play(card)
        if let naechstes = game.upcoming { music.prefetch(naechstes) }
    }

    private func answer(_ antwort: HitAnswer) {
        guard var partie = game, phase == .turn || phase == .judging else { return }
        let richtig = partie.answer(antwort)
        game = partie

        if richtig {
            HapticManager.success()
            SoundManager.play(.cupHit)
        } else {
            EveningLog.record(penalty, forPlayer: partie.player)
            bookedPenalty = true
            HapticManager.error()
            SoundManager.play(.miss)
        }
        withAnimation(AppAnimation.standard) { phase = .result(correct: richtig) }
    }

    /// Die Runde haelt das Jahr fuer falsch: Karte weg, und wer dafuer
    /// getrunken hat, bekommt den Schluck zurueck.
    private func discard() {
        guard var partie = game else { return }
        partie.discardCurrent()
        game = partie
        if bookedPenalty { EveningLog.undoLastBooking() }
        HapticManager.lightImpact()
        nextTurn(skipWinCheck: true)
    }

    private func nextTurn(skipWinCheck: Bool = false) {
        guard var partie = game else { return }

        if !skipWinCheck, let sieger = partie.winner {
            // Haengt den Sieger an den Eintrag, der beim Betreten entstanden
            // ist – kein zweiter Eintrag fuer dasselbe Spiel.
            EveningLog.recordWinner(positions: [sieger], for: .timeline)
            music.stop()
            withAnimation(AppAnimation.standard) { phase = .won(player: sieger) }
            HapticManager.success()
            SoundManager.play(.victory)
            return
        }

        var zufall = SystemRandomNumberGenerator()
        partie.advance(using: &zufall)
        game = partie
        beginTurn()
    }

    /// Nach dem Zahnrad: Die Partie lost ab dem naechsten Zug aus den neu
    /// angehakten Fragen. Die Musikquelle braucht nichts – der naechste Zug
    /// liest sie ohnehin neu (`turnSource`).
    private func applySettings() {
        guard var partie = game else { return }
        partie.choose(chosenQuestions)
        game = partie
    }

    /// Die Hoerprobe kommt nicht: ein anderes Lied, dieselbe Frage, keine
    /// Strafe.
    private func replaceSong() {
        guard var partie = game else { return }
        var zufall = SystemRandomNumberGenerator()
        partie.replaceSong(using: &zufall)
        game = partie
        playCurrent()
    }

    /// Ohne Hoerprobe weiter: Dieser Zug laeuft ueber die Box.
    private func switchToBox() {
        music.stop()
        turnSource = .box
        withAnimation(AppAnimation.standard) { phase = .handoff }
    }

    /// Die Suche nach dem Lied in Spotify. Ohne Spotify-Nummer und ohne
    /// Konto: Die Suche oeffnet die App, wenn sie da ist, sonst die Seite.
    private func spotifyLink(for card: SongCard) -> URL? {
        var erlaubt = CharacterSet.urlPathAllowed
        erlaubt.remove(charactersIn: "/")
        guard let begriff = "\(card.title) \(card.artist)".addingPercentEncoding(withAllowedCharacters: erlaubt) else { return nil }
        return URL(string: "https://open.spotify.com/search/\(begriff)")
    }
}
