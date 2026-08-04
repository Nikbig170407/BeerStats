//
//  BusRideView.swift
//  BeerStats
//
//  Bussfahrer: Vier Fragen hintereinander, jede schwerer als die vorige.
//  Wer daneben liegt, trinkt und faengt von vorne an.
//
//  Die Strafe steigt mit der Runde – ein Fehler bei Frage vier tut mehr weh
//  als bei Frage eins. Ohne diese Staffelung waere es egal, wie weit man
//  kommt, und genau das ist der Reiz: Je naeher am Ziel, desto teurer.
//
//  Gleichstand zaehlt bewusst als falsch. Sonst waere bei "hoeher oder
//  tiefer" die Karte selbst eine Ausrede.
//

import SwiftUI

struct BusRideView: View {

    private enum Phase: Equatable {
        case asking
        case wrong(sips: Int)
        case survived
    }

    private struct Question {
        let title: String
        let options: [String]
    }

    private static let questions: [Question] = [
        Question(title: "Rot oder Schwarz?", options: ["Rot", "Schwarz"]),
        Question(title: "Höher oder tiefer?", options: ["Höher", "Tiefer"]),
        Question(title: "Innerhalb oder außerhalb?", options: ["Innerhalb", "Außerhalb"]),
        Question(title: "Welche Farbe?", options: ["Herz", "Karo", "Pik", "Kreuz"])
    ]

    @State private var deck: [PlayingCard] = PlayingCardDeck.shuffled()
    @State private var drawn: [PlayingCard] = []
    @State private var phase: Phase = .asking

    /// Die laufende Frage. Bewusst gedeckelt: Nach der vierten richtigen
    /// Antwort steht `drawn.count` auf 4, und ein Zugriff auf `questions[4]`
    /// wuerde abstuerzen, falls die Ansicht in genau dem Moment noch einmal
    /// zeichnet.
    private var round: Int { min(drawn.count, Self.questions.count - 1) }

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.accentSecondary)

            VStack(spacing: 20) {
                cardRow
                statusPanel
                Spacer(minLength: 0)
                controls
            }
            .padding(24)
        }
        .navigationTitle("Bussfahrer")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Karten

    private var cardRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { slot in
                PlayingCardView(
                    card: drawn.indices.contains(slot) ? drawn[slot] : nil,
                    width: 68
                )
                .opacity(slot <= round ? 1 : 0.35)
            }
        }
        .animation(AppAnimation.standard, value: drawn.count)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusPanel: some View {
        switch phase {
        case .asking:
            VStack(spacing: 8) {
                Text("FRAGE \(round + 1) VON 4")
                    .font(Font.system(size: 12, weight: .heavy, design: .rounded))
                    .kerning(2.4)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                Text(Self.questions[round].title)
                    .font(BeerStatsFont.title)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Falsch kostet \(round + 1) \(round == 0 ? "Schluck" : "Schlücke")")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.accentSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(18)
            .glassPanel(cornerRadius: 20)
            .neonEdge(BeerStatsColor.accentSecondary, cornerRadius: 20, intensity: 0.5)

        case .wrong(let sips):
            resultPanel(
                emoji: "🍺",
                title: "DANEBEN",
                message: "Trink \(sips) \(sips == 1 ? "Schluck" : "Schlücke") und fang von vorne an.",
                tint: BeerStatsColor.error
            )

        case .survived:
            resultPanel(
                emoji: "🎉",
                title: "DURCHGEKOMMEN",
                message: "Alle vier richtig. Das Handy geht weiter.",
                tint: BeerStatsColor.success
            )
        }
    }

    private func resultPanel(emoji: String, title: String, message: String, tint: Color) -> some View {
        VStack(spacing: 10) {
            Text(emoji).font(.system(size: 40))
            Text(title)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .kerning(2)
                .foregroundStyle(tint)
            Text(message)
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .glassPanel(cornerRadius: 20)
        .neonEdge(tint, cornerRadius: 20, intensity: 0.8)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Bedienung

    @ViewBuilder
    private var controls: some View {
        switch phase {
        case .asking:
            let options = Self.questions[round].options
            VStack(spacing: 10) {
                // Zwei Antworten nebeneinander, vier in zwei Reihen – so
                // bleiben die Flaechen in jeder Runde gleich gross.
                ForEach(Array(stride(from: 0, to: options.count, by: 2)), id: \.self) { start in
                    HStack(spacing: 10) {
                        // Als Array und nicht als Bereich: Ein ForEach über
                        // einen berechneten Range erwartet konstante Daten,
                        // und die Antwortzahl wechselt zwischen 2 und 4.
                        ForEach(Array(start..<min(start + 2, options.count)), id: \.self) { index in
                            answerButton(options[index], index: index)
                        }
                    }
                }
            }

        case .wrong, .survived:
            PrimaryButton(title: "Nächster Versuch", systemImage: "arrow.counterclockwise") {
                restartHand()
            }
        }
    }

    private func answerButton(_ title: String, index: Int) -> some View {
        Button {
            answer(index)
        } label: {
            Text(title)
                .font(BeerStatsFont.headline)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    BeerStatsColor.surfaceElevated,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(BeerStatsColor.accentSecondary.opacity(0.45), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Ablauf

    private func answer(_ index: Int) {
        guard case .asking = phase else { return }
        if deck.count < 2 { deck = PlayingCardDeck.shuffled() }
        guard let card = deck.popLast() else { return }

        let correct = isCorrect(answer: index, card: card)
        let filled = drawn.count + 1

        // Karte und Phase wandern in einem Schritt, nicht in zweien: Sonst
        // gäbe es einen Moment, in dem vier Karten liegen und trotzdem noch
        // nach einer fünften Frage gesucht wird.
        withAnimation(AppAnimation.standard) {
            drawn.append(card)
            if !correct {
                phase = .wrong(sips: filled)
            } else if filled == Self.questions.count {
                phase = .survived
            }
        }

        if correct {
            HapticManager.success()
            SoundManager.play(filled == Self.questions.count ? .victory : .ballsBack)
        } else {
            HapticManager.error()
            SoundManager.play(.miss)
        }
    }

    private func isCorrect(answer index: Int, card: PlayingCard) -> Bool {
        switch drawn.count {
        case 0:
            return index == 0 ? card.isRed : !card.isRed

        case 1:
            // Gleichstand ist falsch – sonst waere jede Zehn eine Ausrede.
            guard card.rank != drawn[0].rank else { return false }
            return index == 0 ? card.rank > drawn[0].rank : card.rank < drawn[0].rank

        case 2:
            let low = min(drawn[0].rank, drawn[1].rank)
            let high = max(drawn[0].rank, drawn[1].rank)
            // Auf der Grenze zaehlt als aussen: innerhalb heisst echt dazwischen.
            let inside = card.rank > low && card.rank < high
            return index == 0 ? inside : !inside

        default:
            let suits: [PlayingCard.Suit] = [.hearts, .diamonds, .spades, .clubs]
            guard suits.indices.contains(index) else { return false }
            return card.suit == suits[index]
        }
    }

    private func restartHand() {
        if deck.count < 8 { deck = PlayingCardDeck.shuffled() }
        withAnimation(AppAnimation.standard) {
            drawn.removeAll()
            phase = .asking
        }
        HapticManager.lightImpact()
    }
}
