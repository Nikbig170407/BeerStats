//
//  EstimationView.swift
//  BeerStats
//
//  Schaetzmeister: Frage vorlesen, reihum schaetzt jeder eine Zahl, dann
//  aufloesen. Wer am weitesten daneben liegt, trinkt.
//
//  Die Schaetzungen werden bewusst NICHT eingetippt. Acht Zahlen einzugeben
//  dauert laenger als die ganze Runde, und der Vergleich ist am Tisch in
//  zwei Sekunden erledigt. Die App stellt die Frage und kennt die Wahrheit –
//  mehr braucht es nicht.
//

import SwiftUI

struct EstimationView: View {

    @State private var deck: [EstimationQuestion] = EstimationDeck.shuffled()
    @State private var index = 0
    @State private var isRevealed = false

    private var current: EstimationQuestion? {
        deck.indices.contains(index) ? deck[index] : nil
    }

    /// Grundmengen an einer Stelle, damit Anzeige und Regeltext nicht
    /// auseinanderlaufen koennen.
    private let loserAmount = DrinkAmount.sips(3)
    private let winnerAmount = DrinkAmount.sips(3)

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.success)

            VStack(spacing: 20) {
                if let question = current {
                    progressLine
                    questionCard(question)
                    Spacer(minLength: 0)
                    controls
                } else {
                    finishedView
                }
            }
            .padding(24)
        }
        .navigationTitle("Schätzmeister")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var progressLine: some View {
        HStack {
            Text("Frage \(index + 1) von \(deck.count)")
                .font(BeerStatsFont.statLabel)
                .foregroundStyle(BeerStatsColor.textSecondary)
            Spacer()
            Button("Neu mischen") { restart() }
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    private func questionCard(_ question: EstimationQuestion) -> some View {
        VStack(spacing: 16) {
            Text("🤔").font(.system(size: 34))

            Text(question.text)
                .font(.scaled(24, weight: .bold, design: .rounded))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if isRevealed {
                Divider().background(BeerStatsColor.textSecondary.opacity(0.3))

                Text(question.answerText)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(BeerStatsColor.success)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("Wer am weitesten daneben liegt, trinkt \(loserAmount.text).")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)

                Text("Wer am nächsten dran ist, darf \(winnerAmount.text) verteilen.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.accent)
                    .multilineTextAlignment(.center)
            } else {
                Text("Reihum schätzt jeder eine Zahl. Keine Zahl darf doppelt kommen.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(26)
        .glassPanel(cornerRadius: 24)
        .neonEdge(BeerStatsColor.success, cornerRadius: 24, intensity: isRevealed ? 0.9 : 0.5)
        .animation(AppAnimation.standard, value: isRevealed)
        .id(question.id)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    @ViewBuilder
    private var controls: some View {
        if isRevealed {
            PrimaryButton(title: "Nächste Frage", systemImage: "arrow.right") { advance() }
        } else {
            PrimaryButton(title: "Auflösen", systemImage: "eye.fill") { reveal() }
        }
    }

    private var finishedView: some View {
        VStack(spacing: 18) {
            Text("🏁").font(.system(size: 60))
            Text("Alle Fragen durch")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
            Spacer(minLength: 0)
            PrimaryButton(title: "Neu mischen", systemImage: "shuffle") { restart() }
        }
    }

    private func reveal() {
        withAnimation(AppAnimation.standard) { isRevealed = true }
        HapticManager.success()
        SoundManager.play(.ballsBack)
    }

    private func advance() {
        withAnimation(AppAnimation.standard) {
            index += 1
            isRevealed = false
        }
        HapticManager.lightImpact()
        SoundManager.play(.tap)
    }

    private func restart() {
        deck = EstimationDeck.shuffled()
        index = 0
        isRevealed = false
        HapticManager.success()
    }
}
