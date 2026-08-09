//
//  MostLikelyView.swift
//  BeerStats
//
//  "Wer von uns?" – Karte vorlesen, bis drei zaehlen, alle zeigen
//  gleichzeitig. Die meisten Finger trinken.
//
//  Der Countdown ist der Kern des Spiels und deshalb in der App und nicht
//  im Kopf der Runde: Zaehlt jemand selbst, schauen alle erst, wohin die
//  anderen zeigen. Drei Sekunden gleichzeitig sind etwas anderes.
//

import SwiftUI

struct MostLikelyView: View {

    private enum Phase: Equatable { case reading, counting(Int), reveal }

    @State private var deck: [MostLikelyCard] = MostLikelyDeck.shuffled()
    @State private var index = 0
    @State private var phase: Phase = .reading
    @State private var countTask: Task<Void, Never>?

    private var currentCard: MostLikelyCard? {
        deck.indices.contains(index) ? deck[index] : nil
    }

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.warning)

            VStack(spacing: 22) {
                if let card = currentCard {
                    progressLine
                    cardView(card)
                    Spacer(minLength: 0)
                    controls
                } else {
                    finishedView
                }
            }
            .padding(24)
        }
        .navigationTitle("Wer von uns?")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { countTask?.cancel() }
    }

    private var progressLine: some View {
        HStack {
            Text("Karte \(index + 1) von \(deck.count)")
                .font(BeerStatsFont.statLabel)
                .foregroundStyle(BeerStatsColor.textSecondary)
            Spacer()
            Button("Neu mischen") { restart() }
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    private func cardView(_ card: MostLikelyCard) -> some View {
        VStack(spacing: 18) {
            Text("👉").font(.system(size: 34))

            Text(card.text)
                .font(.scaled(25, weight: .bold, design: .rounded))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            countdownLabel
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .glassPanel(cornerRadius: 24)
        .neonEdge(BeerStatsColor.warning, cornerRadius: 24, intensity: 0.6)
        .id(card.id)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(AppAnimation.standard, value: card.id)
    }

    @ViewBuilder
    private var countdownLabel: some View {
        switch phase {
        case .reading:
            EmptyView()
        case .counting(let value):
            Text("\(value)")
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.warning)
                .transition(.scale.combined(with: .opacity))
                .id(value)
        case .reveal:
            Text("ZEIGEN!")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .kerning(3)
                .foregroundStyle(BeerStatsColor.success)
                .transition(.scale.combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch phase {
        case .reading:
            PrimaryButton(title: "Countdown starten", systemImage: "timer") { startCountdown() }
        case .counting:
            Text("Gleich zeigen …")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .frame(height: 52)
        case .reveal:
            PrimaryButton(title: "Nächste Karte", systemImage: "arrow.right") { advance() }
        }
    }

    private var finishedView: some View {
        VStack(spacing: 18) {
            Text("🏁").font(.system(size: 60))
            Text("Stapel durch")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
            Text("\(deck.count) Karten gespielt.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
            Spacer(minLength: 0)
            PrimaryButton(title: "Neu mischen", systemImage: "shuffle") { restart() }
        }
    }

    // MARK: - Ablauf

    private func startCountdown() {
        countTask?.cancel()
        countTask = Task { @MainActor in
            for value in stride(from: 3, through: 1, by: -1) {
                withAnimation(AppAnimation.standard) { phase = .counting(value) }
                HapticManager.lightImpact()
                SoundManager.play(.tap)
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard !Task.isCancelled else { return }
            }
            withAnimation(AppAnimation.standard) { phase = .reveal }
            HapticManager.success()
            SoundManager.play(.ballsBack)
        }
    }

    private func advance() {
        countTask?.cancel()
        withAnimation(AppAnimation.standard) {
            index += 1
            phase = .reading
        }
        HapticManager.lightImpact()
    }

    private func restart() {
        countTask?.cancel()
        deck = MostLikelyDeck.shuffled()
        index = 0
        phase = .reading
        HapticManager.success()
    }
}
