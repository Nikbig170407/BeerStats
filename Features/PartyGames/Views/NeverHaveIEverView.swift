//
//  NeverHaveIEverView.swift
//  BeerStats
//
//  „Ich hab noch nie" als Kartenstapel.
//
//  Der Stapel wird einmal gemischt und dann durchgegangen, statt jedes Mal
//  zufällig zu ziehen. Der Unterschied ist wichtig: Beim zufälligen Ziehen
//  kämen Karten doppelt, bevor der Satz durch ist – und nichts bremst einen
//  Abend so zuverlässig wie eine Frage, die schon dran war.
//

import SwiftUI

struct NeverHaveIEverView: View {

    @State private var levels: Set<NeverHaveIEverLevel> = [.harmless, .medium]
    @State private var deck: [NeverHaveIEverCard] = []
    @State private var index = 0
    @State private var hasStarted = false

    private var currentCard: NeverHaveIEverCard? {
        deck.indices.contains(index) ? deck[index] : nil
    }

    private var isFinished: Bool { hasStarted && currentCard == nil }

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.success)

            VStack(spacing: 22) {
                if !hasStarted {
                    setup
                } else if let card = currentCard {
                    progressLine
                    cardView(card)
                    Spacer(minLength: 0)
                    nextButton
                } else {
                    finishedView
                }
            }
            .padding(24)
        }
        .navigationTitle("Ich hab noch nie")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Vorbereitung

    private var setup: some View {
        VStack(spacing: 20) {
            Text("🍻")
                .font(.system(size: 60))

            Text("Reihum vorlesen. Wer es schon gemacht hat, trinkt.")
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                ForEach(NeverHaveIEverLevel.allCases) { level in
                    levelToggle(level)
                }
            }

            Spacer(minLength: 0)

            PrimaryButton(title: "Los geht's", systemImage: "play.fill") { start() }
                .opacity(levels.isEmpty ? 0.4 : 1)
                .disabled(levels.isEmpty)
        }
    }

    private func levelToggle(_ level: NeverHaveIEverLevel) -> some View {
        let isOn = levels.contains(level)
        let count = NeverHaveIEverDeck.all.filter { $0.level == level }.count

        return Button {
            // Mindestens eine Stufe muss bleiben, sonst wäre der Stapel leer.
            if isOn, levels.count > 1 {
                levels.remove(level)
            } else if !isOn {
                levels.insert(level)
            }
            HapticManager.lightImpact()
        } label: {
            HStack(spacing: 14) {
                Text(level.emoji).font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.title)
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                    Text("\(count) Karten")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isOn ? BeerStatsColor.success : BeerStatsColor.textSecondary)
            }
            .padding(16)
            .glassPanel()
            .neonEdge(BeerStatsColor.success, intensity: isOn ? 0.6 : 0.15)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Spiel

    private var progressLine: some View {
        HStack {
            Text("Karte \(index + 1) von \(deck.count)")
                .font(BeerStatsFont.statLabel)
                .foregroundStyle(BeerStatsColor.textSecondary)
            Spacer()
            Button("Neu mischen") { start() }
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    private func cardView(_ card: NeverHaveIEverCard) -> some View {
        VStack(spacing: 18) {
            Text(card.level.emoji)
                .font(.system(size: 34))

            Text("Ich hab noch nie…")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)

            Text(card.text)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .glassPanel(cornerRadius: 24)
        .neonEdge(BeerStatsColor.success, cornerRadius: 24, intensity: 0.6)
        // Der Kartenwechsel schiebt seitlich – so wirkt es wie ein Stapel
        // und nicht wie ein Text, der sich austauscht.
        .id(card.id)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(AppAnimation.standard, value: card.id)
    }

    private var nextButton: some View {
        PrimaryButton(title: "Nächste Karte", systemImage: "arrow.right") {
            withAnimation(AppAnimation.standard) { index += 1 }
            HapticManager.lightImpact()
            SoundManager.play(.tap)
        }
    }

    private var finishedView: some View {
        VStack(spacing: 18) {
            Text("🏁").font(.system(size: 60))
            Text("Stapel durch")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
            Text("\(deck.count) Karten gespielt. Neu mischen für die nächste Runde.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            PrimaryButton(title: "Neu mischen", systemImage: "shuffle") { start() }
            Button("Stufen ändern") { hasStarted = false }
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    private func start() {
        deck = NeverHaveIEverDeck.shuffled(levels: levels)
        index = 0
        hasStarted = true
        HapticManager.success()
    }
}
