//
//  ForbiddenWordsView.swift
//  BeerStats
//
//  Verbotene Woerter: Jeder zieht heimlich ein Wort, das er den ganzen
//  Abend nicht sagen darf.
//
//  Das einzige Spiel hier, das NEBEN allen anderen laeuft. Man richtet es
//  einmal ein, legt das Handy weg und spielt weiter Ring of Fire – das
//  verbotene Wort laeuft im Hintergrund mit. Deshalb gibt es hier auch
//  keinen Spielablauf, nur Verteilen und am Ende Aufloesen.
//
//  Zwei Regeln, nicht eine: Wer sein Wort sagt, trinkt – aber wer jemand
//  anderen dazu bringt, dessen Wort zu sagen, laesst trinken. Ohne die
//  zweite Haelfte schweigt man einfach vorsichtig vor sich hin. Mit ihr
//  wird der ganze Abend zum Versuch, die anderen in die Falle zu locken.
//

import SwiftUI

struct ForbiddenWordsView: View {

    private enum Phase: Equatable {
        case setup
        case dealing(index: Int, isRevealed: Bool)
        case running
        case revealed
    }

    @State private var playerCount = PlayerNames.suggestedCount ?? 5
    @State private var words: [String] = []
    @State private var phase: Phase = .setup

    private let penalty = DrinkAmount.sips(3)

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.warning)

            ScrollView {
                VStack(spacing: 20) {
                    switch phase {
                    case .setup: setupView
                    case .dealing(let index, let isRevealed): dealingView(index: index, isRevealed: isRevealed)
                    case .running: runningView
                    case .revealed: revealedView
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Verbotene Wörter")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Vorbereitung

    private var setupView: some View {
        VStack(spacing: 18) {
            Text("🤐").font(.system(size: 56))

            Text("Wie viele spielen mit?")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Jeder zieht ein Wort, das er ab jetzt nicht mehr sagen darf. Läuft neben allen anderen Spielen weiter.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            PlayerCountStepper(count: $playerCount, range: 2...12, tint: BeerStatsColor.warning)

            PrimaryButton(title: "Wörter verteilen", systemImage: "square.and.pencil") { startDealing() }
        }
    }

    // MARK: - Verteilen

    private func dealingView(index: Int, isRevealed: Bool) -> some View {
        HandoffPanel(
            player: index,
            isRevealed: isRevealed,
            tint: BeerStatsColor.warning,
            continueTitle: "Gemerkt – weitergeben",
            onReveal: {
                withAnimation(AppAnimation.standard) { phase = .dealing(index: index, isRevealed: true) }
            },
            onContinue: { nextPlayer(after: index) }
        ) {
            Text("🤐").font(.system(size: 48))

            Text("Dein verbotenes Wort")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)

            // Der Bereich hat bis zu zwoelf Woerter, und manche sind lang –
            // lieber kleiner setzen als umbrechen.
            Text(words.indices.contains(index) ? words[index] : "–")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.warning)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("Merk es dir. Niemand sonst darf es sehen.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Läuft

    private var runningView: some View {
        VStack(spacing: 18) {
            Text("🤐").font(.system(size: 56))

            Text("\(playerCount) Wörter im Umlauf")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            VStack(alignment: .leading, spacing: 12) {
                ruleRow("Wer sein eigenes Wort sagt", "trinkt \(penalty.text)")
                ruleRow("Wer jemanden dazu bringt, dessen Wort zu sagen", "darf \(penalty.text) verteilen")
                ruleRow("Gilt den ganzen Abend", "auch während aller anderen Spiele")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassPanel(cornerRadius: 20)
            .neonEdge(BeerStatsColor.warning, cornerRadius: 20, intensity: 0.5)

            Text("Legt das Handy jetzt weg und spielt weiter.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            PrimaryButton(title: "Am Ende auflösen", systemImage: "eye.fill") {
                withAnimation(AppAnimation.standard) { phase = .revealed }
                HapticManager.success()
                SoundManager.play(.victory)
            }

            Button("Neu verteilen") { startDealing() }
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    private func ruleRow(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•").foregroundStyle(BeerStatsColor.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text(detail)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.warning)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Auflösung

    private var revealedView: some View {
        VStack(spacing: 16) {
            Text("🔓").font(.system(size: 52))

            Text("Das waren die Wörter")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            VStack(spacing: 8) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    HStack {
                        Text("\(PlayerNames.name(for: index))")
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                        Spacer()
                        Text(word)
                            .font(BeerStatsFont.headline)
                            .foregroundStyle(BeerStatsColor.warning)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassPanel(cornerRadius: 14)
                }
            }

            Text("Wer bis zum Schluss durchgehalten hat, darf \(penalty.text) verteilen.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.success)
                .multilineTextAlignment(.center)

            PrimaryButton(title: "Neue Runde", systemImage: "shuffle") { startDealing() }
        }
    }

    // MARK: - Ablauf

    private func startDealing() {
        words = ForbiddenWordDeck.draw(playerCount)
        withAnimation(AppAnimation.standard) { phase = .dealing(index: 0, isRevealed: false) }
        HapticManager.success()
    }

    private func nextPlayer(after index: Int) {
        HapticManager.lightImpact()
        withAnimation(AppAnimation.standard) {
            phase = index + 1 < playerCount
                ? .dealing(index: index + 1, isRevealed: false)
                : .running
        }
    }
}
