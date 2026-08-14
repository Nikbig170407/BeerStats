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
//  Die Reihenfolge der Weitergabe nummeriert die Runde von selbst – damit
//  laesst sich am Ende sagen, WER der Spion war. Laeuft ein Abend, stehen
//  statt der Nummern die Namen der Teilnehmer da; ohne ihn bleibt es bei
//  "Spieler 3", und das Spiel funktioniert trotzdem allein.
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

    @State private var playerCount = PlayerNames.suggestedCount ?? 5
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

            PlayerCountStepper(count: $playerCount, range: 3...12, tint: BeerStatsColor.accentSecondary)

            PrimaryButton(title: "Rollen verteilen", systemImage: "person.2.fill") { startDealing() }
        }
    }

    // MARK: - Rollen verteilen

    private func dealingView(index: Int, isRevealed: Bool) -> some View {
        let isSpy = index == spyIndex

        return HandoffPanel(
            player: index,
            isRevealed: isRevealed,
            tint: isSpy ? BeerStatsColor.error : BeerStatsColor.success,
            continueTitle: "Gesehen – weitergeben",
            onReveal: {
                withAnimation(AppAnimation.standard) { phase = .dealing(index: index, isRevealed: true) }
            },
            onContinue: { nextPlayer(after: index) }
        ) {
            Text(isSpy ? "🕵️" : "📍").font(.system(size: 54))

            Text(isSpy ? "Du bist der Spion" : word)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(isSpy ? BeerStatsColor.error : BeerStatsColor.success)
                .multilineTextAlignment(.center)

            Text(isSpy
                 ? "Du kennst das Wort nicht. Tu so, als wüsstest du es."
                 : "Beschreibe es mit einem Satz, ohne es zu nennen.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
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
            recordDrinks(for: outcome)
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

            Text("\(PlayerNames.name(for: spyIndex)) war der Spion")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)

            Text("Das Wort war „\(word)“")
                .font(BeerStatsFont.headline)
                .foregroundStyle(BeerStatsColor.accentSecondary)

            Text(penaltyText(for: outcome))
                .font(.scaled(22, weight: .bold, design: .rounded))
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
            return "\(PlayerNames.name(for: spyIndex)) trinkt \(spyPenalty.text)."
        case .spyEscaped:
            return "Alle außer \(PlayerNames.name(for: spyIndex)) trinken \(groupPenalty.text)."
        case .spyGuessedWord:
            return "Doppelt erwischt: Alle außer \(PlayerNames.name(for: spyIndex)) trinken \(spyPenalty.text)."
        }
    }

    /// Traegt die Strafe der Bilanz ein – in beide Richtungen, so wie das
    /// Spiel es auch ansagt.
    private func recordDrinks(for outcome: Outcome) {
        let andere = (0..<playerCount).filter { $0 != spyIndex }

        switch outcome {
        case .spyCaught:
            EveningLog.record(spyPenalty, forPlayer: spyIndex)
        case .spyEscaped:
            EveningLog.record(groupPenalty, forPlayers: andere)
        case .spyGuessedWord:
            EveningLog.record(spyPenalty, forPlayers: andere)
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
