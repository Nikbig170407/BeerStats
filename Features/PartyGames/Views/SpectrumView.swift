//
//  SpectrumView.swift
//  BeerStats
//
//  Die Skala: Zwischen zwei Polen liegt eine Stelle, die nur einer kennt.
//
//  Er gibt einen Hinweis – ein Wort, ein Beispiel, keine Zahl –, und die
//  Runde schiebt einen Regler dorthin, wo sie ihn vermutet.
//
//  Die Strafe trifft den **Hinweisgeber**, nicht die Runde. Das ist
//  Absicht: Der Hinweis ist die eigentliche Leistung des Spiels, und wer
//  ihn gibt, soll etwas riskieren. Traefe es die Ratenden, waere der beste
//  Zug, absichtlich vage zu bleiben – dann verliert immer jemand anderes.
//
//  Zwei Zonen statt einer: Die Mitte (plus/minus fuenf) ist der Treffer,
//  ein breiterer Ring darum geht straffrei durch. Ohne diesen Ring waere
//  das Spiel eine Lotterie – ein Regler trifft fuenf von hundert Stellen
//  nicht zuverlaessig, auch nicht mit einem guten Hinweis.
//

import SwiftUI

struct SpectrumView: View {

    private enum Phase: Equatable {
        /// Das Handy geht an den, der die Stelle sehen darf.
        case handoff
        /// Er sieht die Stelle und denkt sich einen Hinweis aus.
        case secret
        /// Die Runde schiebt den Regler.
        case guessing
        case result
    }

    /// Haelfte der Trefferzone: funfzehn Prozent der Skala insgesamt.
    private static let bullseye: Double = 7.5
    /// Haelfte des straffreien Rings.
    private static let nearMiss: Double = 18

    @State private var phase: Phase = .handoff
    @State private var deck: [SpectrumCard] = []
    @State private var card: SpectrumCard?
    @State private var target: Double = 50
    @State private var guess: Double = 50
    @State private var turn = 0

    private let penalty = DrinkAmount.sips(2)
    private let reward = DrinkAmount.sips(3)

    private var distance: Double { abs(guess - target) }
    private var isBullseye: Bool { distance <= Self.bullseye }
    private var isNear: Bool { distance <= Self.nearMiss }

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.accent)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 18) {
                        switch phase {
                        case .handoff: handoffContent
                        case .secret: secretContent
                        case .guessing: guessingContent
                        case .result: resultContent
                        }
                    }
                    .padding(22)
                    .frame(minHeight: geometry.size.height)
                }
                .verticalScrollOnly()
            }
        }
        .navigationTitle("Die Skala")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: startIfNeeded)
    }

    // MARK: - Übergabe

    private var handoffContent: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            Text("🎚️").font(.system(size: 56))

            TurnRow(turn: turn, tint: BeerStatsColor.accent)

            Text("Nur du schaust")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Du siehst gleich eine Stelle zwischen zwei Begriffen. Gib der Runde einen Hinweis, der genau dorthin führt – ein Wort oder ein Beispiel, keine Zahl.")
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            PrimaryButton(title: "Stelle anzeigen", systemImage: "eye.fill") {
                withAnimation(AppAnimation.standard) { phase = .secret }
                HapticManager.lightImpact()
            }
        }
    }

    // MARK: - Die geheime Stelle

    private var secretContent: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            poles

            scale(showingTarget: true, marker: nil)

            Text("Dein Hinweis muss hierher führen. Sag ihn laut – dann weitergeben.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            PrimaryButton(title: "Hinweis gesagt – weitergeben", systemImage: "arrow.right") {
                guess = 50
                withAnimation(AppAnimation.standard) { phase = .guessing }
                HapticManager.lightImpact()
            }
        }
    }

    // MARK: - Raten

    private var guessingContent: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            poles

            scale(showingTarget: false, marker: guess)

            Slider(value: $guess, in: 0...100)
                .tint(BeerStatsColor.accent)

            Text("Schiebt gemeinsam. Wenn ihr euch einig seid, festlegen.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            PrimaryButton(title: "Festlegen", systemImage: "checkmark") { reveal() }
        }
    }

    // MARK: - Auflösung

    private var resultContent: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            Text(isBullseye ? "🎯" : (isNear ? "😌" : "💀"))
                .font(.system(size: 54))

            poles

            scale(showingTarget: true, marker: guess)

            Text(verdict)
                .font(BeerStatsFont.headline)
                .foregroundStyle(isBullseye ? BeerStatsColor.success : (isNear ? BeerStatsColor.textSecondary : BeerStatsColor.error))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            PrimaryButton(title: "Nächster ist dran", systemImage: "arrow.right") { nextRound() }
        }
    }

    private var verdict: String {
        let wer = PlayerNames.nameForTurn(turn) ?? "Wer den Hinweis gegeben hat"
        if isBullseye {
            return "Volltreffer. \(wer) darf \(reward.text) verteilen."
        }
        if isNear {
            return "Knapp daneben – das geht gerade noch durch."
        }
        return "Zu weit weg. \(wer) trinkt \(penalty.text) für den Hinweis."
    }

    // MARK: - Bausteine

    private var poles: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(card?.left ?? "")
                .font(BeerStatsFont.headline)
                .foregroundStyle(BeerStatsColor.accentSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(card?.right ?? "")
                .font(BeerStatsFont.headline)
                .foregroundStyle(BeerStatsColor.warning)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Der Balken. Die Zonen werden in Anteilen der Breite gezeichnet, nicht
    /// in Punkten – sonst sieht die Trefferzone auf jedem Geraet anders
    /// gross aus, als sie gerechnet wird.
    private func scale(showingTarget: Bool, marker: Double?) -> some View {
        GeometryReader { geo in
            let breite = geo.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(BeerStatsColor.surfaceElevated.opacity(0.6))

                if showingTarget {
                    zone(width: breite, half: Self.nearMiss, color: BeerStatsColor.accent.opacity(0.25))
                    zone(width: breite, half: Self.bullseye, color: BeerStatsColor.accent.opacity(0.85))
                }

                if let marker {
                    Capsule()
                        .fill(BeerStatsColor.textPrimary)
                        .frame(width: 3)
                        .offset(x: breite * CGFloat(marker / 100) - 1.5)
                }
            }
        }
        .frame(height: 26)
    }

    private func zone(width: CGFloat, half: Double, color: Color) -> some View {
        let von = max(0, target - half) / 100
        let bis = min(100, target + half) / 100

        return Capsule()
            .fill(color)
            .frame(width: width * CGFloat(bis - von))
            .offset(x: width * CGFloat(von))
    }

    // MARK: - Ablauf

    private func startIfNeeded() {
        guard card == nil else { return }
        nextRound(advanceTurn: false)
    }

    private func reveal() {
        withAnimation(AppAnimation.standard) { phase = .result }

        if isBullseye {
            HapticManager.success()
            SoundManager.play(.victory)
        } else if isNear {
            HapticManager.lightImpact()
            SoundManager.play(.tap)
        } else {
            // Ueber die POSITION buchen, nicht ueber den Zaehler: Die
            // Bilanz kennt nur so viele Plaetze, wie Leute da sind.
            if let platz = PlayerNames.position(forTurn: turn) {
                EveningLog.record(penalty, forPlayer: platz)
            }
            HapticManager.error()
            SoundManager.play(.miss)
        }
    }

    private func nextRound(advanceTurn: Bool = true) {
        if advanceTurn { turn += 1 }
        if deck.isEmpty { deck = SpectrumDeck.shuffled() }
        card = deck.popLast()

        // Nicht ganz an den Rand: Eine Stelle bei 2 waere mit "ganz links"
        // zu treffen, ohne dass jemand nachdenkt – und der Regler kommt
        // dort ohnehin kaum hin.
        target = Double.random(in: 10...90)
        withAnimation(AppAnimation.standard) { phase = .handoff }
    }
}
