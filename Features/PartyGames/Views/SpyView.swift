//
//  SpyView.swift
//  BeerStats
//
//  Der Spion: Alle kennen dasselbe Wort – einer nicht.
//
//  Das Handy geht einmal reihum, jeder tippt einmal und sieht seine Rolle
//  allein. Danach beschreibt reihum jeder das Wort mit einem Satz, ohne es
//  zu nennen. Am Ende stimmt die Runde ab.
//
//  Getrunken wird in beide Richtungen, und das ist der Punkt: Enttarnt die
//  Runde den Spion, trinkt er. Kommt er durch, trinken alle anderen. Ohne
//  die zweite Haelfte waere Schweigen die beste Strategie – niemand haette
//  einen Grund, sich festzulegen.
//
//  Spielernummern statt Namen: Die Reihenfolge der Weitergabe nummeriert die
//  Runde von selbst. Damit laesst sich am Ende sagen, WER der Spion war,
//  ohne dass jemand Namen eintippen muss.
//

import SwiftUI

struct SpyView: View {

    private enum Phase: Equatable {
        case setup
        /// Das Handy wandert: `index` ist der Spieler, der gerade dran ist.
        case dealing(index: Int, isRevealed: Bool)
        case describing
        case verdict
        case result(Outcome)
    }

    private enum Outcome: Equatable {
        case spyCaught
        case spyEscaped
        case spyGuessedWord
    }

    @State private var playerCount = 5
    @State private var phase: Phase = .setup
    @State private var word = SpyDeck.randomWord()
    @State private var spyIndex = 0

    private let spyPenalty = DrinkAmount.shot
    private let groupPenalty = DrinkAmount.sips(3)

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.accentSecondary)

            ScrollView {
                VStack(spacing: 20) {
                    switch phase {
                    case .setup: setupView
                    case .dealing(let index, let isRevealed): dealingView(index: index, isRevealed: isRevealed)
                    case .describing: describingView
                    case .verdict: verdictView
                    case .result(let outcome): resultView(outcome)
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Der Spion")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Vorbereitung

    private var setupView: some View {
        VStack(spacing: 18) {
            Text("🕵️").font(.system(size: 56))

            Text("Wie viele spielen mit?")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Alle bekommen dasselbe Wort – außer einem. Reihum beschreibt jeder das Wort mit einem Satz, ohne es zu nennen.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                countButton("−") { if playerCount > 3 { playerCount -= 1 } }
                Text("\(playerCount)")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(BeerStatsColor.accentSecondary)
                    .frame(minWidth: 80)
                countButton("+") { if playerCount < 12 { playerCount += 1 } }
            }

            PrimaryButton(title: "Rollen verteilen", systemImage: "person.2.fill") { startDealing() }
        }
    }

    private func countButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .frame(width: 62, height: 62)
                .glassPanel(cornerRadius: 18)
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Rollen verteilen

    private func dealingView(index: Int, isRevealed: Bool) -> some View {
        VStack(spacing: 20) {
            Text("Spieler \(index + 1)")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            if isRevealed {
                VStack(spacing: 12) {
                    Text(index == spyIndex ? "🕵️" : "📍").font(.system(size: 54))

                    Text(index == spyIndex ? "Du bist der Spion" : word)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(index == spyIndex ? BeerStatsColor.error : BeerStatsColor.success)
                        .multilineTextAlignment(.center)

                    Text(index == spyIndex
                         ? "Du kennst das Wort nicht. Tu so, als wüsstest du es."
                         : "Beschreibe es mit einem Satz, ohne es zu nennen.")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(26)
                .glassPanel(cornerRadius: 22)
                .neonEdge(index == spyIndex ? BeerStatsColor.error : BeerStatsColor.success, cornerRadius: 22, intensity: 0.8)

                PrimaryButton(title: "Gesehen – weitergeben", systemImage: "arrow.right") { nextPlayer(after: index) }
            } else {
                VStack(spacing: 10) {
                    Text("🤫").font(.system(size: 54))
                    Text("Handy übernehmen, dann aufdecken.")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .glassPanel(cornerRadius: 22)

                PrimaryButton(title: "Aufdecken", systemImage: "eye.fill") {
                    withAnimation(AppAnimation.standard) { phase = .dealing(index: index, isRevealed: true) }
                    HapticManager.mediumImpact()
                    SoundManager.play(.tap)
                }
            }
        }
    }

    // MARK: - Beschreiben

    private var describingView: some View {
        VStack(spacing: 18) {
            Text("🗣️").font(.system(size: 54))

            Text("Reihum beschreiben")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Spieler 1 fängt an. Jeder sagt genau einen Satz über das Wort – nicht zu genau, sonst hilft er dem Spion.")
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            PrimaryButton(title: "Abstimmen", systemImage: "hand.raised.fill") {
                withAnimation(AppAnimation.standard) { phase = .verdict }
                HapticManager.lightImpact()
            }
        }
    }

    // MARK: - Abstimmung

    private var verdictView: some View {
        VStack(spacing: 14) {
            Text("🗳️").font(.system(size: 48))

            Text("Wer war es?")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Einigt euch auf einen Verdächtigen und tippt, was passiert ist.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            outcomeButton(
                "Spion enttarnt",
                detail: "Er trinkt \(spyPenalty.text)",
                tint: BeerStatsColor.success,
                outcome: .spyCaught
            )
            outcomeButton(
                "Spion kam durch",
                detail: "Alle anderen trinken \(groupPenalty.text)",
                tint: BeerStatsColor.error,
                outcome: .spyEscaped
            )
            outcomeButton(
                "Spion hat das Wort erraten",
                detail: "Alle anderen trinken \(spyPenalty.text)",
                tint: BeerStatsColor.accentSecondary,
                outcome: .spyGuessedWord
            )
        }
    }

    private func outcomeButton(_ title: String, detail: String, tint: Color, outcome: Outcome) -> some View {
        Button {
            withAnimation(AppAnimation.standard) { phase = .result(outcome) }
            HapticManager.success()
            SoundManager.play(outcome == .spyCaught ? .victory : .bombe)
        } label: {
            VStack(spacing: 3) {
                Text(title)
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text(detail)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(tint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassPanel(cornerRadius: 18)
            .neonEdge(tint, cornerRadius: 18, intensity: 0.5)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Auflösung

    private func resultView(_ outcome: Outcome) -> some View {
        VStack(spacing: 16) {
            Text(outcome == .spyCaught ? "🎉" : "🕵️").font(.system(size: 56))

            Text("Spieler \(spyIndex + 1) war der Spion")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)

            Text("Das Wort war „\(word)“")
                .font(BeerStatsFont.headline)
                .foregroundStyle(BeerStatsColor.accentSecondary)

            Text(penaltyText(for: outcome))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(BeerStatsColor.error)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(18)
                .glassPanel(cornerRadius: 18)
                .neonEdge(BeerStatsColor.error, cornerRadius: 18, intensity: 0.7)

            PrimaryButton(title: "Nächste Runde", systemImage: "arrow.counterclockwise") { startDealing() }

            Button("Spielerzahl ändern") {
                withAnimation(AppAnimation.standard) { phase = .setup }
            }
            .font(BeerStatsFont.caption)
            .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    private func penaltyText(for outcome: Outcome) -> String {
        switch outcome {
        case .spyCaught:
            return "Spieler \(spyIndex + 1) trinkt \(spyPenalty.text)."
        case .spyEscaped:
            return "Alle außer Spieler \(spyIndex + 1) trinken \(groupPenalty.text)."
        case .spyGuessedWord:
            return "Doppelt erwischt: Alle außer Spieler \(spyIndex + 1) trinken \(spyPenalty.text)."
        }
    }

    // MARK: - Ablauf

    private func startDealing() {
        word = SpyDeck.randomWord()
        spyIndex = Int.random(in: 0..<playerCount)
        withAnimation(AppAnimation.standard) { phase = .dealing(index: 0, isRevealed: false) }
        HapticManager.success()
    }

    private func nextPlayer(after index: Int) {
        HapticManager.lightImpact()
        withAnimation(AppAnimation.standard) {
            phase = index + 1 < playerCount
                ? .dealing(index: index + 1, isRevealed: false)
                : .describing
        }
    }
}
