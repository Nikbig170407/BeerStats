//
//  TwoTruthsView.swift
//  BeerStats
//
//  Zwei Wahrheiten, eine Luege: drei Behauptungen, die Runde raet.
//
//  Getrunken wird in alle drei Richtungen, und das ist der ganze Trick.
//  Durchschaut dich jeder, warst du zu offensichtlich – du trinkst.
//  Durchschaut dich keiner, hat die Runde geschlafen – alle anderen trinken.
//  Und im Normalfall trinkt, wer danebenlag.
//
//  Ohne die erste Regel waere die beste Strategie eine absurde Luege, die
//  niemand glaubt; ohne die zweite eine so beilaeufige, dass keiner hinhoert.
//  Erst beide zusammen zwingen zur knappen Luege.
//

import SwiftUI

struct TwoTruthsView: View {

    private enum Outcome: Equatable { case everyone, nobody, mixed }

    @State private var deck: [String] = TwoTruthsDeck.shuffled()
    @State private var index = 0
    @State private var outcome: Outcome?

    private var theme: String { deck.indices.contains(index) ? deck[index] : deck.first ?? "" }

    private let tellerPenalty = DrinkAmount.shot
    private let groupPenalty = DrinkAmount.sips(3)
    private let wrongPenalty = DrinkAmount.sips(2)

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.accent)

            ScrollView {
                VStack(spacing: 18) {
                    themeCard
                    if let outcome {
                        resultCard(outcome)
                        PrimaryButton(title: "Nächster ist dran", systemImage: "arrow.right") { advance() }
                    } else {
                        instructions
                        outcomeButtons
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Zwei Wahrheiten")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var themeCard: some View {
        VStack(spacing: 10) {
            Text("🎭").font(.system(size: 34))
            Text("THEMA")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .kerning(2.4)
                .foregroundStyle(BeerStatsColor.textSecondary)
            Text(theme)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassPanel(cornerRadius: 22)
        .neonEdge(BeerStatsColor.accent, cornerRadius: 22, intensity: 0.7)
        .id(theme)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private var instructions: some View {
        Text("Sag drei Sätze zu diesem Thema – zwei stimmen, einer ist erfunden. Die Runde zeigt gleichzeitig auf den Satz, den sie für gelogen hält.")
            .font(BeerStatsFont.body)
            .foregroundStyle(BeerStatsColor.textSecondary)
            .multilineTextAlignment(.center)
    }

    private var outcomeButtons: some View {
        VStack(spacing: 10) {
            outcomeButton(
                "Alle haben die Lüge gefunden",
                detail: "Zu offensichtlich – du trinkst \(tellerPenalty.text)",
                tint: BeerStatsColor.error,
                outcome: .everyone
            )
            outcomeButton(
                "Niemand hat sie gefunden",
                detail: "Alle anderen trinken \(groupPenalty.text)",
                tint: BeerStatsColor.success,
                outcome: .nobody
            )
            outcomeButton(
                "Gemischt",
                detail: "Wer danebenlag, trinkt \(wrongPenalty.text)",
                tint: BeerStatsColor.accentSecondary,
                outcome: .mixed
            )
        }
    }

    private func outcomeButton(_ title: String, detail: String, tint: Color, outcome value: Outcome) -> some View {
        Button {
            withAnimation(AppAnimation.standard) { outcome = value }
            HapticManager.success()
            SoundManager.play(value == .nobody ? .victory : .bombe)
        } label: {
            VStack(spacing: 3) {
                Text(title)
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text(detail)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(tint)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .glassPanel(cornerRadius: 18)
            .neonEdge(tint, cornerRadius: 18, intensity: 0.5)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func resultCard(_ value: Outcome) -> some View {
        VStack(spacing: 8) {
            Text(emoji(for: value)).font(.system(size: 48))
            Text(text(for: value))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(BeerStatsColor.error)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassPanel(cornerRadius: 20)
        .neonEdge(BeerStatsColor.error, cornerRadius: 20, intensity: 0.7)
    }

    private func emoji(for value: Outcome) -> String {
        switch value {
        case .everyone: return "🙈"
        case .nobody: return "😎"
        case .mixed: return "🤷"
        }
    }

    private func text(for value: Outcome) -> String {
        switch value {
        case .everyone: return "Du trinkst \(tellerPenalty.text)."
        case .nobody: return "Alle anderen trinken \(groupPenalty.text)."
        case .mixed: return "Wer danebenlag, trinkt \(wrongPenalty.text)."
        }
    }

    private func advance() {
        withAnimation(AppAnimation.standard) {
            index += 1
            if index >= deck.count {
                deck = TwoTruthsDeck.shuffled()
                index = 0
            }
            outcome = nil
        }
        HapticManager.lightImpact()
        SoundManager.play(.tap)
    }
}
