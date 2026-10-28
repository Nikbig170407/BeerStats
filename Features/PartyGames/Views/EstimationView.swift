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

    @Environment(\.gameWorld) private var world

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.success)

            VStack(spacing: 20) {
                if let question = current {
                    progressLine
                    questionCard(question)
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
            QuietButton(title: "Neu mischen") { restart() }
        }
    }

    private func questionCard(_ question: EstimationQuestion) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            Text(question.text)
                .font(Font.world(world, 23, weight: .heavy))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if isRevealed {
                Text("AUFLÖSUNG")
                    .font(Font.world(world, 13, weight: .bold))
                    .kerning(3)
                    .foregroundStyle(QuizShow.bulb)

                // Die Loesung rollt auf Walzen ein, die Einheit steht darunter
                DigitReels(text: question.numberText, size: question.numberText.count > 4 ? 36 : 44)
                if !question.unit.isEmpty {
                    Text(question.unit)
                        .font(Font.world(world, 20, weight: .bold))
                        .foregroundStyle(BeerStatsColor.textPrimary)
                }

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
            Spacer(minLength: 0)
        }
        // Fuellt den Platz, statt ihn frei zu lassen: Hier stand ein
        // `Spacer` zwischen Karte und Knoepfen, und die Karte blieb so klein
        // wie ihr Text – auf einem grossen Geraet lag die Haelfte des
        // Screens leer. Die Spacer INNEN halten den Text in der Mitte der
        // Karte.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
        .glassPanel(cornerRadius: 24)
        // Die Lauflichter der Quizshow um die Frage
        .overlay { MarqueeLights().padding(4) }
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
            Text("Alle Fragen durch")
                .font(Font.world(world, 28, weight: .heavy))
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
