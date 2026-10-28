//
//  HeadsUpView.swift
//  BeerStats
//
//  Wer bin ich? Handy an die Stirn, die Runde beschreibt, du raetst.
//
//  Getrunken wird nach Ergebnis und nicht pauschal am Ende: Jeder verpasste
//  Begriff ist ein Schluck fuer dich, jeder getroffene einer, den du
//  verteilen darfst. Dadurch zaehlt jede einzelne Karte – bei einer festen
//  Strafe waere es egal, ob man zwei oder zwoelf schafft.
//
//  Getippt wird von den Beschreibenden, nicht vom Ratenden: Wer das Handy an
//  der Stirn haelt, trifft keine Knoepfe. Deshalb zwei grosse Flaechen
//  nebeneinander statt kleiner Schaltflaechen.
//

import SwiftUI

struct HeadsUpView: View {

    private enum Phase: Equatable { case setup, playing, finished }

    private static let roundSeconds: Double = 60

    @State private var category: HeadsUpCategory = .people
    @State private var phase: Phase = .setup
    @State private var deck: [String] = []
    @State private var index = 0
    @State private var remaining: Double = roundSeconds
    @State private var hits = 0
    @State private var misses = 0
    @State private var tickTask: Task<Void, Never>?
    /// Wie die letzte Karte ausging – daran haengt, wohin sie fliegt.
    @State private var lastHit = true
    /// Zaehlt die Karten der Runde; jede ist eine eigene Ansicht.
    @State private var cards = 0

    @Environment(\.gameWorld) private var world

    private var current: String? { deck.indices.contains(index) ? deck[index] : nil }

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.accent)

            switch phase {
            case .setup:
                FillingScrollView {
                    setupView.padding(24)
                }
            case .playing: playingView
            case .finished: finishedView.padding(24)
            }
        }
        .navigationTitle("Wer bin ich?")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { tickTask?.cancel() }
    }

    // MARK: - Vorbereitung

    private var setupView: some View {
        VStack(spacing: 16) {
            Text("HANDY AN DIE STIRN")
                .font(Font.world(world, 34, weight: .black))
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Die Runde beschreibt, du rätst. Ein Nachbar tippt: links daneben, rechts getroffen.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                ForEach(HeadsUpCategory.allCases) { option in
                    categoryRow(option)
                }
            }

            DrinkIntensityPicker(game: .headsUp)

            Spacer(minLength: 0)

            PrimaryButton(title: "60 Sekunden – los", systemImage: "play.fill") { start() }
        }
    }

    private func categoryRow(_ option: HeadsUpCategory) -> some View {
        OptionRow(
            emoji: option.emoji,
            title: option.title,
            detail: "\(HeadsUpDeck.count(option)) Begriffe",
            isOn: category == option,
            tint: BeerStatsColor.accent
        ) {
            category = option
        }
    }

    // MARK: - Runde

    /// Die Karte fuellt den Screen: Sie wird aus zwei Metern gelesen, von
    /// der Runde, nicht vom Ratenden. Die Zeit laeuft als Band um den Rand –
    /// das Band gehoert zur Runde, nicht zur Karte, und bleibt deshalb
    /// stehen, waehrend die Karten durchfliegen.
    private var playingView: some View {
        VStack(spacing: 0) {
            ZStack {
                if let current {
                    ForeheadCardFace(category: category.title, term: current)
                        .padding(10)
                        .id(cards)
                        // Getroffen faellt die Karte nach unten, weiter fliegt
                        // sie nach oben; die naechste kommt von der anderen Seite
                        .transition(.asymmetric(
                            insertion: .move(edge: lastHit ? .top : .bottom),
                            removal: .move(edge: lastHit ? .bottom : .top)
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay { TimeBand(share: remaining / Self.roundSeconds).padding(10) }
            .overlay(alignment: .bottom) {
                Text(String(format: "%.0f", remaining))
                    .font(Font.world(world, 20, weight: .heavy))
                    .foregroundStyle(remaining <= 10 ? BeerStatsColor.error : Color.white.opacity(0.7))
                    .monospacedDigit()
                    .padding(.bottom, 24)
            }
            .clipped()
            .padding(.horizontal, 6)
            .padding(.top, 4)

            HStack(spacing: 0) {
                TapZone(title: "Daneben", tint: BeerStatsColor.error) { advance(hit: false) }
                TapZone(title: "Getroffen", tint: BeerStatsColor.success) { advance(hit: true) }
            }
            .frame(height: TapZone.height)
        }
        .overlay {
            EffectFlash(trigger: cards, tint: lastHit ? BeerStatsColor.success : ForeheadCard.pass, peak: 0.4)
        }
    }

    // MARK: - Ergebnis

    private var finishedView: some View {
        VStack(spacing: 16) {
            Text("ZEIT UM")
                .font(Font.world(world, 44, weight: .black))
                .foregroundStyle(ForeheadCard.band)

            Text("\(hits) getroffen, \(misses) daneben")
                .font(Font.world(world, 26, weight: .bold))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)

            // Nur zeigen, was tatsächlich anfällt: `DrinkAmount` rundet auf
            // mindestens einen Schluck auf, sonst stünde hier auch bei einer
            // fehlerfreien Runde eine Strafe.
            VStack(spacing: 10) {
                if misses > 0 {
                    Text("Du trinkst \(DrinkAmount.sips(misses).text)")
                        .font(.scaled(22, weight: .bold, design: .rounded))
                        .foregroundStyle(BeerStatsColor.error)
                } else {
                    Text("Ohne Fehler durch")
                        .font(.scaled(22, weight: .bold, design: .rounded))
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
            .neonEdge(BeerStatsColor.error, cornerRadius: 20, intensity: 0.6)

            Spacer(minLength: 0)

            PrimaryButton(title: "Nächster ist dran", systemImage: "arrow.right") { start() }
            QuietButton(title: "Kategorie wechseln") {
                withAnimation(AppAnimation.standard) { phase = .setup }
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

        // Erst die Richtung festhalten, dann die Karte wechseln: Die alte
        // Karte fliegt mit dem Uebergang davon, den sie zuletzt hatte – im
        // selben Durchlauf floege sie noch in die Richtung der vorigen.
        lastHit = hit
        DispatchQueue.main.async {
            withAnimation(.easeIn(duration: 0.28)) {
                cards += 1
                // Ist der Stapel durch, wird neu gemischt statt abgebrochen:
                // Bei 35 Begriffen und 60 Sekunden passiert das nur den ganz
                // Schnellen, und die sollen nicht dafuer bestraft werden.
                index += 1
                if index >= deck.count {
                    deck = HeadsUpDeck.shuffled(category)
                    index = 0
                }
            }
        }
    }

    private func finish() {
        tickTask?.cancel()
        withAnimation(AppAnimation.standard) { phase = .finished }
        HapticManager.error()
        SoundManager.play(.bombe)
    }
}
