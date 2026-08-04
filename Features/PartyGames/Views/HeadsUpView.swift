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

    private var current: String? { deck.indices.contains(index) ? deck[index] : nil }

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.accent)

            switch phase {
            case .setup: setupView.padding(24)
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
            Text("🙈").font(.system(size: 54))

            Text("Handy an die Stirn")
                .font(BeerStatsFont.title)
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

            Spacer(minLength: 0)

            PrimaryButton(title: "60 Sekunden – los", systemImage: "play.fill") { start() }
        }
    }

    private func categoryRow(_ option: HeadsUpCategory) -> some View {
        let isOn = category == option

        return Button {
            category = option
            HapticManager.lightImpact()
        } label: {
            HStack(spacing: 14) {
                Text(option.emoji).font(.system(size: 24))
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                    Text("\(HeadsUpDeck.count(option)) Begriffe")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isOn ? BeerStatsColor.accent : BeerStatsColor.textSecondary)
            }
            .padding(14)
            .glassPanel(cornerRadius: 16)
            .neonEdge(BeerStatsColor.accent, cornerRadius: 16, intensity: isOn ? 0.6 : 0.15)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Runde

    private var playingView: some View {
        VStack(spacing: 0) {
            Text(String(format: "%.0f", remaining))
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(remaining <= 10 ? BeerStatsColor.error : BeerStatsColor.textSecondary)
                .monospacedDigit()
                .padding(.top, 8)

            Spacer(minLength: 0)

            Text(current ?? "")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.4)
                .lineLimit(3)
                .padding(.horizontal, 20)

            Spacer(minLength: 0)

            HStack(spacing: 0) {
                tapZone(title: "Daneben", tint: BeerStatsColor.error) { advance(hit: false) }
                tapZone(title: "Getroffen", tint: BeerStatsColor.success) { advance(hit: true) }
            }
            .frame(height: 130)
        }
    }

    private func tapZone(title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(tint.opacity(0.15))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Ergebnis

    private var finishedView: some View {
        VStack(spacing: 16) {
            Text("⏱️").font(.system(size: 54))

            Text("\(hits) getroffen, \(misses) daneben")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)

            // Nur zeigen, was tatsächlich anfällt: `DrinkAmount` rundet auf
            // mindestens einen Schluck auf, sonst stünde hier auch bei einer
            // fehlerfreien Runde eine Strafe.
            VStack(spacing: 10) {
                if misses > 0 {
                    Text("Du trinkst \(DrinkAmount.sips(misses).text)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(BeerStatsColor.error)
                } else {
                    Text("Ohne Fehler durch")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
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
            Button("Kategorie wechseln") {
                withAnimation(AppAnimation.standard) { phase = .setup }
            }
            .font(BeerStatsFont.caption)
            .foregroundStyle(BeerStatsColor.textSecondary)
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

        // Ist der Stapel durch, wird neu gemischt statt abgebrochen: Bei 35
        // Begriffen und 60 Sekunden passiert das nur den ganz Schnellen, und
        // die sollen nicht dafuer bestraft werden.
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
