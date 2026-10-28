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

    @State private var playerCount = PlayerNames.suggestedCount(atLeast: 3) ?? 5
    @State private var phase: Phase = .setup
    @State private var word = SpyDeck.randomWord()
    @State private var spyIndex = 0

    private let spyPenalty = DrinkAmount.shot
    private let groupPenalty = DrinkAmount.sips(3)

    @Environment(\.gameWorld) private var world

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.accentSecondary)

            FillingScrollView {
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
            RubberStamp(text: "STRENG GEHEIM")

            Text("Wie viele spielen mit?")
                .font(Font.world(world, 22, weight: .semibold))
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Alle bekommen dasselbe Wort – außer einem. Reihum beschreibt jeder das Wort mit einem Satz, ohne es zu nennen.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            PlayerCountStepper(count: $playerCount, range: 3...12, tint: BeerStatsColor.accentSecondary)

            DrinkIntensityPicker(game: .spy)

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
            // Die Farbe kommt vom Blatt – rotes Papier fuer den Spion, die
            // Tinte stellt die Akte. Deshalb hier keine eigene Farbe.
            Text(isSpy ? "ACHTUNG" : "AUFTRAG")
                .font(Font.world(world, 13, weight: .bold))
                .kerning(3)
                .opacity(0.75)

            Rectangle()
                .frame(height: 1)
                .opacity(0.35)

            Text(isSpy ? "Deine Rolle:" : "Dein Wort lautet:")
                .font(Font.world(world, 15, weight: .regular))
                .opacity(0.85)

            // Ein Wort in einer Zeile, lieber kleiner: Ein langes
            // zusammengesetztes Wort braeche sonst mitten im Wort um.
            TypewriterText(
                text: isSpy ? "DU BIST\nDER SPION" : word.uppercased(),
                font: Font.world(world, 30, weight: .heavy)
            )
            .lineLimit(isSpy ? 2 : 1)
            .minimumScaleFactor(0.4)

            Text(isSpy
                 ? "Du kennst das Wort nicht. Tu so, als wüsstest du es."
                 : "Beschreibe es mit einem Satz, ohne es zu nennen.")
                .font(Font.world(world, 13, weight: .regular))
                .opacity(0.75)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Beschreiben

    private var describingView: some View {
        VStack(spacing: 18) {
            RubberStamp(text: "BEFRAGUNG", angle: 5)

            Text("Reihum beschreiben")
                .font(Font.world(world, 22, weight: .semibold))
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("\(PlayerNames.plainName(for: 0)) fängt an. Jeder sagt genau einen Satz über das Wort – nicht zu genau, sonst hilft er dem Spion.")
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
            RubberStamp(text: "ABSTIMMUNG", angle: -4)

            Text("Wer war es?")
                .font(Font.world(world, 22, weight: .semibold))
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
                    .font(Font.world(world, 17, weight: .semibold))
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
            stamp(for: outcome)

            Text("\(PlayerNames.name(for: spyIndex)) war der Spion")
                .font(Font.world(world, 22, weight: .semibold))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)

            Text("Das Wort war „\(word)“")
                .font(Font.world(world, 17, weight: .semibold))
                .foregroundStyle(SecretFile.folderLight)

            Text(penaltyText(for: outcome))
                .font(Font.world(world, 22, weight: .bold))
                .foregroundStyle(BeerStatsColor.error)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(18)
                .glassPanel(cornerRadius: 18)
                .neonEdge(BeerStatsColor.error, cornerRadius: 18, intensity: 0.7)

            PrimaryButton(title: "Nächste Runde", systemImage: "arrow.counterclockwise") { startDealing() }

            QuietButton(title: "Spielerzahl ändern") {
                withAnimation(AppAnimation.standard) { phase = .setup }
            }
        }
    }

    /// Der Stempel auf der Akte. Gruen nur, wenn die Runde gewonnen hat –
    /// dieselbe Bedeutung wie ueberall in der App.
    private func stamp(for outcome: Outcome) -> some View {
        switch outcome {
        case .spyCaught:
            return RubberStamp(text: "ENTTARNT", color: BeerStatsColor.success, angle: -8)
        case .spyEscaped:
            return RubberStamp(text: "ENTKOMMEN", angle: -8)
        case .spyGuessedWord:
            return RubberStamp(text: "WORT GEKNACKT", angle: -8)
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
