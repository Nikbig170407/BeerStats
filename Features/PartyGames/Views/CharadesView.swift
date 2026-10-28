//
//  CharadesView.swift
//  BeerStats
//
//  Pantomime: vorspielen ohne ein Wort, die Runde raet.
//
//  Verwandt mit "Wer bin ich?", aber genau andersherum: Dort steht der
//  Begriff an der Stirn der ratenden Person und alle ausser ihr kennen ihn.
//  Hier kennt ihn nur die vorspielende Person – deshalb der Zwischenschritt
//  vor der Runde ("nimm das Handy, sonst guckt keiner"), den es dort nicht
//  braucht.
//
//  Der Begriffsstapel ist derselbe (`HeadsUpDeck`). Ein eigener waere
//  zweimal dieselbe Arbeit, und was sich an die Stirn halten laesst, laesst
//  sich auch vorspielen: ein Begriff, kein Satz.
//
//  Die Rechnung am Ende ist ebenfalls dieselbe – ein Schluck je verpasstem
//  Begriff, einer zu verteilen je getroffenem. Das ist Absicht: Sie ist am
//  Tisch erprobt, und zwei verwandte Spiele mit verschiedenen Mengen waeren
//  nur eine Quelle fuer Streit darueber, welche jetzt gilt.
//

import SwiftUI

struct CharadesView: View {

    private enum Phase: Equatable { case setup, ready, playing, finished }

    private static let roundSeconds: Double = 90

    @State private var category: HeadsUpCategory = .everyday
    @State private var phase: Phase = .setup
    @State private var deck: [String] = []
    @State private var index = 0
    @State private var remaining: Double = roundSeconds
    @State private var hits = 0
    @State private var misses = 0
    /// Wie oft weitergegeben wurde – daraus macht `TurnRow` einen Namen.
    @State private var turn = 0
    @State private var tickTask: Task<Void, Never>?
    /// Wann die Runde losging – daran haengt der Zeiger des Film-Vorlaufs.
    @State private var startedAt = Date()
    /// Jeder neue Begriff ist ein Schnitt.
    @State private var cuts = 0

    @Environment(\.gameWorld) private var world

    private var current: String? { deck.indices.contains(index) ? deck[index] : nil }

    var body: some View {
        Group {
            switch phase {
            case .setup: setupView
            case .ready: readyView
            case .playing: playingView
            case .finished: finishedView
            }
        }
        .navigationTitle("Pantomime")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { tickTask?.cancel() }
    }

    // MARK: - Vorbereitung

    private var setupView: some View {
        GameSetupScreen(
            emoji: "🤸",
            title: "Pantomime",
            subtitle: "Einer spielt vor, die Runde rät – 90 Sekunden, so viele Begriffe wie möglich.",
            tint: BeerStatsColor.success,
            startTitle: "Los geht's",
            onStart: { withAnimation(AppAnimation.standard) { phase = .ready } }
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("WORUM GEHT ES?")
                    .font(.scaled(11, weight: .heavy, design: .rounded))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                ForEach(HeadsUpCategory.allCases) { option in
                    OptionRow(
                        emoji: option.emoji,
                        title: option.title,
                        detail: "\(HeadsUpDeck.count(option)) Begriffe",
                        isOn: category == option,
                        tint: BeerStatsColor.success
                    ) {
                        category = option
                    }
                }

                Text("Kein Wort, kein Laut, nichts aufmalen – nur spielen. Zeigen auf Dinge im Raum zählt nicht.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                DrinkIntensityPicker(game: .charades)
            }
        }
    }

    // MARK: - Übergabe

    /// Der Zwischenschritt, den "Wer bin ich?" nicht braucht.
    ///
    /// Wer vorspielt, muss den Begriff sehen – und sonst niemand. Ohne
    /// diesen Halt stuende der erste Begriff schon auf dem Bildschirm,
    /// waehrend das Handy noch durch die Runde wandert.
    private var readyView: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.success)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 16) {
                        Spacer(minLength: 0)

                        TurnRow(turn: turn, tint: BeerStatsColor.success)

                        Intertitle {
                            Text("— PANTOMIME —")
                                .font(Font.world(world, 13, weight: .semibold))
                                .kerning(3)
                                .opacity(0.75)

                            Text("Nimm das Handy")
                                .font(Font.world(world, 32, weight: .bold))

                            Text("Nur du siehst die Begriffe. Die anderen rufen, was sie erkennen – du tippst unten, ob es gepasst hat.")
                                .font(Font.world(world, 16, weight: .regular).italic())
                                .opacity(0.7)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)

                        PrimaryButton(title: "90 Sekunden – los", systemImage: "play.fill") { start() }

                        QuietButton(title: "Kategorie wechseln") {
                            withAnimation(AppAnimation.standard) { phase = .setup }
                        }
                    }
                    .padding(24)
                    .frame(minHeight: geometry.size.height)
                }
                .verticalScrollOnly()
            }
        }
    }

    // MARK: - Runde

    private var playingView: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.success)

            VStack(spacing: 0) {
                HStack(spacing: 18) {
                    FilmLeader(
                        seconds: Int(remaining.rounded()),
                        startedAt: startedAt,
                        warning: remaining <= 10
                    )

                    Text("\(hits) geschafft")
                        .font(Font.world(world, 18, weight: .regular).italic())
                        .foregroundStyle(BeerStatsColor.success)
                }
                .padding(.top, 8)

                Spacer(minLength: 0)

                Intertitle {
                    Text("— DER BEGRIFF —")
                        .font(Font.world(world, 13, weight: .semibold))
                        .kerning(3)
                        .opacity(0.75)

                    Text(current ?? "")
                        .font(Font.world(world, 44, weight: .bold))
                        .minimumScaleFactor(0.4)
                        .lineLimit(3)

                    Text(category.title)
                        .font(Font.world(world, 17, weight: .regular).italic())
                        .opacity(0.62)
                }
                .modifier(FilmCut(trigger: cuts))
                .padding(.horizontal, 20)

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    TapZone(title: "Geht nicht", tint: BeerStatsColor.error) { advance(hit: false) }
                    TapZone(title: "Erraten", tint: BeerStatsColor.success) { advance(hit: true) }
                }
                .frame(height: TapZone.height)
            }
        }
    }

    // MARK: - Ergebnis

    private var finishedView: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.success)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 16) {
                        Spacer(minLength: 0)

                        Intertitle {
                            Text("— ENDE —")
                                .font(Font.world(world, 13, weight: .semibold))
                                .kerning(3)
                                .opacity(0.75)

                            Text("\(hits) erraten, \(misses) liegen geblieben")
                                .font(Font.world(world, 26, weight: .bold))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Nur nennen, was wirklich anfaellt: `DrinkAmount`
                        // rundet auf mindestens einen Schluck auf, sonst
                        // staende auch nach einer fehlerfreien Runde eine
                        // Strafe da.
                        VStack(spacing: 10) {
                            if misses > 0 {
                                Text("Du trinkst \(DrinkAmount.sips(misses).text)")
                                    .font(Font.world(world, 22, weight: .bold))
                                    .foregroundStyle(BeerStatsColor.error)
                            } else {
                                Text("Alles rübergebracht")
                                    .font(Font.world(world, 22, weight: .bold))
                                    .foregroundStyle(BeerStatsColor.success)
                            }

                            if hits > 0 {
                                Text("Du verteilst \(DrinkAmount.sips(hits).text)")
                                    .font(BeerStatsFont.headline)
                                    .foregroundStyle(BeerStatsColor.success)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .glassPanel(cornerRadius: 20)
                        .neonEdge(BeerStatsColor.success, cornerRadius: 20, intensity: 0.6)

                        Spacer(minLength: 0)

                        PrimaryButton(title: "Nächster ist dran", systemImage: "arrow.right") {
                            turn += 1
                            withAnimation(AppAnimation.standard) { phase = .ready }
                        }

                        QuietButton(title: "Kategorie wechseln") {
                            withAnimation(AppAnimation.standard) { phase = .setup }
                        }
                    }
                    .padding(24)
                    .frame(minHeight: geometry.size.height)
                }
                .verticalScrollOnly()
            }
        }
    }

    // MARK: - Ablauf

    private func start() {
        tickTask?.cancel()
        deck = HeadsUpDeck.shuffled(category)
        index = 0
        hits = 0
        misses = 0
        remaining = Self.roundSeconds
        startedAt = Date()
        withAnimation(AppAnimation.standard) { phase = .playing }
        HapticManager.success()

        tickTask = Task { @MainActor in
            while remaining > 0, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled else { return }
                remaining = max(0, remaining - 0.2)
            }
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    private func advance(hit: Bool) {
        guard phase == .playing else { return }
        if hit {
            hits += 1
            HapticManager.success()
            SoundManager.play(.cupHit)
        } else {
            misses += 1
            HapticManager.error()
            SoundManager.play(.miss)
        }

        cuts += 1

        // Ist der Stapel durch, wird neu gemischt statt abgebrochen –
        // dieselbe Entscheidung wie bei "Wer bin ich?": Wer schnell ist,
        // soll nicht dafuer bestraft werden.
        index += 1
        if index >= deck.count {
            deck = HeadsUpDeck.shuffled(category)
            index = 0
        }
    }

    private func finish() {
        tickTask?.cancel()
        withAnimation(AppAnimation.standard) { phase = .finished }
        HapticManager.error()
        SoundManager.play(.bombe)
    }
}
