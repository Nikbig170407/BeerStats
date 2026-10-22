//
//  TimelineView.swift
//  BeerStats
//
//  Zeitstrahl: Ein Lied laeuft, und du sagst, in welches Jahrzehnt es
//  gehoert – genauer gesagt, zwischen welche deiner Karten.
//
//  Das Spiel braucht etwas, das sonst keines hier braucht: **jemanden, der
//  das Lied abspielt.** Deshalb wandert das Handy zum Nachbarn, bevor die
//  Runde beginnt. Er sieht Titel und Interpret, sucht das Lied auf der Box
//  und tippt am Ende die Luecke an, die der Ratende ansagt.
//
//  **Das Jahr sieht er nicht** – erst nach dem Setzen. Sonst stuende die
//  Antwort die ganze Zeit neben dem, der sie nicht wissen darf, und ein
//  falscher Blick waere kein Versehen mehr, sondern eine Einladung.
//
//  Getippt wird auf Luecken in einer senkrechten Liste, nicht auf einen
//  Zeitstrahl, den man schiebt. Mit acht Karten waere die Reihe schmaler
//  als ein Daumen, und wer am Tisch daneben tippt, verliert eine Runde,
//  die er richtig geraten hat.
//

import SwiftUI

struct TimelineView: View {

    private enum Phase: Equatable {
        case setup
        /// Das Handy geht zum Nachbarn.
        case handoff
        /// Der Nachbar spielt das Lied an, die Runde raet.
        case playing
        case result(correct: Bool)
        case won(player: Int)
    }

    @State private var phase: Phase = .setup
    @State private var playerCount = 4
    @State private var target = 5
    @State private var timelines: [SongTimeline] = []
    @State private var deck: [SongCard] = []
    @State private var current: SongCard?
    @State private var guesser = 0

    private let penalty = DrinkAmount.sips(2)

    /// Wer das Lied abspielt: der Nachbar des Ratenden.
    private var dj: Int { playerCount > 1 ? (guesser + 1) % playerCount : 0 }

    private var timeline: SongTimeline {
        timelines.indices.contains(guesser) ? timelines[guesser] : SongTimeline()
    }

    var body: some View {
        Group {
            switch phase {
            case .setup: setupView
            case .handoff: handoffView
            case .playing: playingView
            case .result(let correct): resultView(correct: correct)
            case .won(let player): wonView(player: player)
            }
        }
        .navigationTitle("Zeitstrahl")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: adoptTableCount)
    }

    // MARK: - Vorbereitung

    private var setupView: some View {
        GameSetupScreen(
            emoji: "🎵",
            title: "Zeitstrahl",
            subtitle: "Ein Lied läuft – du sagst, zwischen welche deiner Karten es gehört.",
            tint: BeerStatsColor.accentSecondary,
            startTitle: "Los geht's",
            onStart: start
        ) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    label("WIE VIELE SPIELT IHR?")
                    PlayerCountStepper(count: $playerCount, range: 2...PartyGame.manyPlayers, tint: BeerStatsColor.accentSecondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    label("WER ZUERST SO VIELE KARTEN HAT, GEWINNT")
                    ChoiceRow(
                        options: [
                            ChoiceOption(value: 3, title: "3", detail: "kurz"),
                            ChoiceOption(value: 5, title: "5", detail: "mittel"),
                            ChoiceOption(value: 8, title: "8", detail: "lang")
                        ],
                        selection: $target,
                        tint: BeerStatsColor.accentSecondary
                    )
                    Text(dauerHinweis)
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Ihr braucht etwas, das Musik abspielt. Die App nennt dem Nachbarn des Ratenden Titel und Interpret – er sucht das Lied und spielt es an, ohne den Titel vorzulesen.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                DrinkIntensityPicker(game: .timeline)
            }
        }
    }

    /// Bei vielen Leuten dauert dieselbe Zahl deutlich laenger – das soll
    /// vorher dastehen und nicht nach vierzig Minuten auffallen.
    private var dauerHinweis: String {
        let runden = target * playerCount
        return "Mit \(playerCount) Leuten sind das ungefähr \(runden) Lieder, also gut \(max(5, runden / 2)) Minuten."
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.scaled(11, weight: .heavy, design: .rounded))
            .kerning(1.6)
            .foregroundStyle(BeerStatsColor.textSecondary)
    }

    // MARK: - Übergabe

    private var handoffView: some View {
        panel {
            Text("📱").font(.system(size: 54))

            Text("\(PlayerNames.name(for: dj)) nimmt das Handy")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(PlayerNames.name(for: guesser)) rät diese Runde und darf nicht aufs Display schauen.")
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } buttons: {
            PrimaryButton(title: "Hab's – Lied anzeigen", systemImage: "music.note") {
                withAnimation(AppAnimation.standard) { phase = .playing }
                HapticManager.lightImpact()
            }
        }
    }

    // MARK: - Die Runde

    private var playingView: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.accentSecondary)

            ScrollView {
                VStack(spacing: 16) {
                    songPanel

                    Text("\(PlayerNames.name(for: guesser)) sagt an – tipp die Lücke.")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .multilineTextAlignment(.center)

                    timelineList
                }
                .padding(20)
            }
            .verticalScrollOnly()
        }
    }

    private var songPanel: some View {
        VStack(spacing: 8) {
            Text("SPIEL DAS AN")
                .font(.scaled(11, weight: .heavy, design: .rounded))
                .kerning(1.8)
                .foregroundStyle(BeerStatsColor.textSecondary)

            Text(current?.title ?? "–")
                .font(.scaled(24, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(current?.artist ?? "")
                .font(BeerStatsFont.headline)
                .foregroundStyle(BeerStatsColor.accentSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Jahr nicht verraten – es steht hier ohnehin noch nicht.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .glassPanel(cornerRadius: 20)
        .neonEdge(BeerStatsColor.accentSecondary, cornerRadius: 20, intensity: 0.6)
    }

    /// Die Reihe des Ratenden: Karten und dazwischen die Luecken.
    private var timelineList: some View {
        VStack(spacing: 8) {
            ForEach(Array(0..<timeline.gapCount), id: \.self) { gap in
                gapButton(gap)

                if gap < timeline.count {
                    cardRow(timeline.cards[gap])
                }
            }
        }
    }

    private func gapButton(_ gap: Int) -> some View {
        Button {
            place(at: gap)
        } label: {
            Text(timeline.label(forGap: gap))
                .font(.scaled(13, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.accentSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            BeerStatsColor.accentSecondary.opacity(0.55),
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func cardRow(_ card: SongCard) -> some View {
        HStack(spacing: 12) {
            Text(String(card.year))
                .font(.scaled(17, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .monospacedDigit()

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

    // MARK: - Auflösung

    private func resultView(correct: Bool) -> some View {
        panel {
            Text(correct ? "✅" : "❌").font(.system(size: 54))

            Text(String(current?.year ?? 0))
                .font(.scaled(48, weight: .heavy, design: .rounded))
                .foregroundStyle(correct ? BeerStatsColor.success : BeerStatsColor.error)
                .monospacedDigit()

            Text(current?.title ?? "")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(current?.artist ?? "")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)

            Text(correct
                 ? "Sitzt. Die Karte bleibt bei \(PlayerNames.name(for: guesser))."
                 : "Daneben. \(PlayerNames.name(for: guesser)) trinkt \(penalty.text).")
                .font(BeerStatsFont.headline)
                .foregroundStyle(correct ? BeerStatsColor.success : BeerStatsColor.error)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } buttons: {
            PrimaryButton(title: "Weiter", systemImage: "arrow.right") { nextTurn() }

            // Die Notbremse: Der Stapel ist von Hand geschrieben, und wenn
            // die Runde das Jahr besser weiss als die App, gewinnt die
            // Runde. Ohne diesen Knopf traenke jemand fuer meinen Tippfehler.
            QuietButton(title: "Jahr stimmt nicht – Karte verwerfen") { discard() }
        }
    }

    private func wonView(player: Int) -> some View {
        panel {
            Text("🏆").font(.system(size: 62))

            Text("\(PlayerNames.name(for: player)) gewinnt")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(target) Karten auf dem Zeitstrahl. Alle anderen trinken \(penalty.text).")
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

    /// Der gemeinsame Rahmen der drei Zwischenbildschirme – Inhalt mittig,
    /// Knoepfe unten, der Platz dazwischen gehoert dem Inhalt.
    private func panel<Content: View, Buttons: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder buttons: () -> Buttons
    ) -> some View {
        // Die beiden Closures werden HIER ausgewertet und nicht erst im
        // GeometryReader: Der ist escaping, und ein nicht-escaping
        // ViewBuilder darf dort nicht hinein. Fertige Ansichten sind
        // dagegen Werte und duerfen ueberall mit.
        let inhalt = content()
        let knoepfe = buttons()

        return ZStack {
            AmbientBackdrop(glow: BeerStatsColor.accentSecondary)

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
        deck = SongDeck.shuffled()
        timelines = (0..<playerCount).map { _ in SongTimeline() }

        // Jeder beginnt mit einer offenen Karte. Ohne sie waere der erste
        // Zug jedes Spielers eine Luecke ohne Nachbarn – immer richtig, und
        // damit kein Zug, sondern eine Formalitaet.
        for index in timelines.indices {
            if let karte = deck.popLast() { timelines[index].insert(karte) }
        }

        guesser = 0
        drawNext()
        HapticManager.success()
    }

    private func drawNext() {
        if deck.isEmpty { deck = SongDeck.shuffled() }
        current = deck.popLast()
        withAnimation(AppAnimation.standard) { phase = .handoff }
    }

    private func place(at gap: Int) {
        guard let card = current, timelines.indices.contains(guesser) else { return }

        let richtig = timelines[guesser].isCorrect(card, at: gap)
        if richtig {
            timelines[guesser].insert(card)
            HapticManager.success()
            SoundManager.play(.cupHit)
        } else {
            EveningLog.record(penalty, forPlayer: guesser)
            HapticManager.error()
            SoundManager.play(.miss)
        }

        withAnimation(AppAnimation.standard) { phase = .result(correct: richtig) }
    }

    /// Die Runde haelt das Jahr fuer falsch: Karte zurueck, keine Strafe.
    private func discard() {
        if let card = current, timelines.indices.contains(guesser) {
            timelines[guesser].remove(card)
        }
        HapticManager.lightImpact()
        nextTurn(skipWinCheck: true)
    }

    private func nextTurn(skipWinCheck: Bool = false) {
        if !skipWinCheck, timelines.indices.contains(guesser), timelines[guesser].count >= target {
            // Haengt den Sieger an den Eintrag, der beim Betreten entstanden
            // ist – kein zweiter Eintrag fuer dasselbe Spiel.
            EveningLog.recordWinner(positions: [guesser], for: .timeline)
            withAnimation(AppAnimation.standard) { phase = .won(player: guesser) }
            HapticManager.success()
            SoundManager.play(.victory)
            return
        }

        guesser = (guesser + 1) % max(playerCount, 1)
        drawNext()
    }
}
