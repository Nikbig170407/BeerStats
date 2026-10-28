//
//  SchockenView.swift
//  BeerStats
//
//  Schocken: drei Wuerfel, bis zu drei Wuerfe, Wuerfel duerfen liegen
//  bleiben. Der schlechteste Wurf der Runde trinkt.
//
//  Der erste Spieler legt fest, wie viele Wuerfe die Runde hat – wer nach
//  einem Wurf stehen bleibt, zwingt alle anderen dazu. Das ist die
//  eigentliche Entscheidung im Spiel und der Grund, warum Schocken mehr ist
//  als Wuerfelglueck.
//
//  Die App uebernimmt die Rangfolge. Dass ein Schock jede Strasse schlaegt
//  und die Zahl 210 mehr wert ist als 665, weiss am Tisch nach dem dritten
//  Bier niemand mehr zuverlaessig – und darueber wird dann gestritten statt
//  gespielt.
//

import SwiftUI

struct SchockenView: View {

    private enum Phase: Equatable {
        case setup
        case handoff(player: Int)
        case rolling(player: Int)
        case roundOver
    }

    @State private var playerCount = PlayerNames.suggestedCount() ?? 4
    @State private var phase: Phase = .setup

    @State private var dice = [1, 1, 1]
    @State private var kept = [false, false, false]
    /// Zaehlt je Wuerfel, wie oft er geworfen wurde – daran kullert er.
    @State private var rolls = [0, 0, 0]
    /// Die Wertung steht erst, wenn die Wuerfel liegen. Vorher verriete sie,
    /// was gleich zu sehen ist.
    @State private var settled = true
    @State private var throwsUsed = 0
    /// Vom ersten Spieler der Runde gesetzt. `nil`, solange niemand fertig ist.
    @State private var throwLimit: Int?
    @State private var results: [SchockenThrow?] = []

    private let penalty = DrinkAmount.sips(3)
    private let schockAusPenalty = DrinkAmount.sips(6)

    @Environment(\.gameWorld) private var world
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.warning)

            FillingScrollView {
                VStack(spacing: 20) {
                    switch phase {
                    case .setup: setupView
                    case .handoff(let player): handoffView(player)
                    case .rolling(let player): rollingView(player)
                    case .roundOver: roundOverView
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Schocken")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Vorbereitung

    private var setupView: some View {
        VStack(spacing: 18) {
            DiceRow(values: [4, 5, 6], dieSize: 46)

            Text("Wie viele spielen mit?")
                .font(Font.world(world, 22, weight: .semibold))
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Drei Würfel, bis zu drei Würfe. Der Erste legt fest, wie viele Würfe die Runde hat.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            PlayerCountStepper(count: $playerCount, range: 2...10, tint: BeerStatsColor.warning)

            DrinkIntensityPicker(game: .schocken)

            rankingCard

            PrimaryButton(title: "Runde starten", systemImage: "play.fill") { startRound() }
        }
    }

    /// Die Rangfolge steht im Spiel selbst, nicht nur im Kopf des Erklaerers.
    private var rankingCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("RANGFOLGE, NIEDRIG NACH HOCH")
                .font(Font.world(world, 10, weight: .heavy))
                .kerning(1.4)
                .foregroundStyle(BeerStatsColor.textSecondary)
            Text("Zahl · Straße · General · Schock · Schock aus")
                .font(Font.world(world, 14, weight: .semibold))
                .foregroundStyle(BeerStatsColor.textPrimary)
            Text("Bei der Zahl zählt die Eins 100, jeder andere Würfel zehnfach. 1-6-5 ergibt 210.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassPanel(cornerRadius: 16)
    }

    // MARK: - Übergabe

    private func handoffView(_ player: Int) -> some View {
        VStack(spacing: 18) {
            Text("\(PlayerNames.name(for: player))")
                .font(Font.world(world, 26, weight: .bold))
                .foregroundStyle(BeerStatsColor.textPrimary)

            if let throwLimit {
                Text("Du hast \(throwLimit) \(throwLimit == 1 ? "Wurf" : "Würfe")")
                    .font(Font.world(world, 17, weight: .semibold).italic())
                    .foregroundStyle(BeerStatsColor.warning)
            } else {
                Text("Du fängst an – bis zu drei Würfe. Womit du aufhörst, gilt für alle.")
                    .font(BeerStatsFont.body)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if !results.isEmpty { standings(loser: nil) }

            PrimaryButton(title: "Würfeln", systemImage: "dice") { beginTurn(player) }
        }
    }

    // MARK: - Würfeln

    private func rollingView(_ player: Int) -> some View {
        VStack(spacing: 20) {
            Text("\(PlayerNames.name(for: player)) · Wurf \(throwsUsed) von \(throwLimit ?? 3)")
                .font(Font.world(world, 15, weight: .regular).italic())
                .foregroundStyle(BeerStatsColor.textSecondary)

            DiceBoard {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { slot in
                        dieButton(slot)
                    }
                }
            }

            Text(SchockenThrow.evaluate(dice).label)
                .font(Font.world(world, 30, weight: .bold))
                .foregroundStyle(BeerStatsColor.warning)
                .opacity(settled ? 1 : 0)
                .animation(.easeOut(duration: 0.15), value: settled)

            Text("Würfel antippen heißt liegen lassen.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)

            if throwsUsed < (throwLimit ?? 3) {
                PrimaryButton(title: "Nochmal würfeln", systemImage: "dice") { rollDice() }
            }

            Button {
                finishTurn(player)
            } label: {
                Text(throwLimit == nil ? "Stehen lassen – gilt für alle" : "Stehen lassen")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .glassPanel(cornerRadius: 16)
                    .neonEdge(BeerStatsColor.warning, cornerRadius: 16, intensity: 0.5)
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func dieButton(_ slot: Int) -> some View {
        let isKept = kept[slot]

        return Button {
            kept[slot].toggle()
            HapticManager.lightImpact()
        } label: {
            VStack(spacing: 2) {
                SchockenDie(value: dice[slot], kept: isKept, roll: rolls[slot], slot: slot)
                    .frame(height: 92)

                // Nicht nur Licht und Rahmen: Wer das Gelb nicht sieht, liest es
                Text(isKept ? "liegt" : " ")
                    .font(Font.world(world, 13, weight: .semibold).italic())
                    .foregroundStyle(RegularsTable.lamp)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Würfel \(slot + 1): \(dice[slot])")
        .accessibilityValue(isKept ? "liegt" : "wird mitgeworfen")
    }

    // MARK: - Zwischenstand und Ergebnis

    /// Der Zwischenstand. Am Ende der Runde faellt dem Verlierer ein
    /// Bierdeckel auf die Zeile – wie am Stammtisch.
    private func standings(loser: Int?, mats: Int = 1) -> some View {
        VStack(spacing: 6) {
            ForEach(results.indices, id: \.self) { index in
                if let result = results[index] {
                    HStack(spacing: 10) {
                        Text("\(PlayerNames.name(for: index))")
                            .font(Font.world(world, 14, weight: .semibold))
                            .foregroundStyle(BeerStatsColor.textSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        DiceRow(values: result.dice)
                        Text(result.label)
                            .font(Font.world(world, 14, weight: .bold))
                            .foregroundStyle(BeerStatsColor.textPrimary)
                            .lineLimit(1)
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, index == loser ? 30 : 14)
                    .padding(.vertical, 9)
                    .glassPanel(cornerRadius: 12)
                    // Der Deckel liegt auf der Kante, nicht in der Zeile –
                    // dort ist neben Name, Wuerfeln und Wertung kein Platz
                    .overlay(alignment: .trailing) {
                        if index == loser {
                            FallingBeerMat(size: 34, count: mats).offset(x: 14)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var roundOverView: some View {
        let loser = worstPlayer()
        let hadSchockAus = results.compactMap { $0 }.contains { $0.kind == .schockAus }
        let amount = hadSchockAus ? schockAusPenalty : penalty

        return VStack(spacing: 16) {
            // Doppelt so teuer, doppelt so viele Deckel
            FallingBeerMat(size: 72, count: hadSchockAus ? 2 : 1)

            standings(loser: loser, mats: hadSchockAus ? 2 : 1)

            if let loser {
                Text("\(PlayerNames.name(for: loser)) trinkt \(amount.text)")
                    .font(Font.world(world, 22, weight: .bold))
                    .foregroundStyle(BeerStatsColor.error)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .glassPanel(cornerRadius: 18)
                    .neonEdge(BeerStatsColor.error, cornerRadius: 18, intensity: 0.7)
            }

            if hadSchockAus {
                Text("Schock aus in der Runde – das kostet doppelt.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            PrimaryButton(title: "Nächste Runde", systemImage: "arrow.counterclockwise") { startRound() }

            QuietButton(title: "Spielerzahl ändern") {
                withAnimation(AppAnimation.standard) { phase = .setup }
            }
        }
    }

    private func worstPlayer() -> Int? {
        var worst: Int?
        for index in results.indices {
            guard let candidate = results[index] else { continue }
            guard let current = worst, let currentThrow = results[current] else {
                worst = index
                continue
            }
            if SchockenThrow.isWorse(candidate, than: currentThrow) { worst = index }
        }
        return worst
    }

    // MARK: - Ablauf

    private func startRound() {
        results = Array(repeating: nil, count: playerCount)
        throwLimit = nil
        withAnimation(AppAnimation.standard) { phase = .handoff(player: 0) }
        HapticManager.success()
    }

    private func beginTurn(_ player: Int) {
        kept = [false, false, false]
        throwsUsed = 0
        withAnimation(AppAnimation.standard) { phase = .rolling(player: player) }
        rollDice()
    }

    private func rollDice() {
        for slot in 0..<3 where !kept[slot] {
            dice[slot] = Int.random(in: 1...6)
            rolls[slot] += 1
        }
        throwsUsed += 1
        HapticManager.mediumImpact()
        SoundManager.play(.cupHit)

        // Die Wertung kommt, wenn die Wuerfel liegen – nicht vorher
        guard !reduceMotion else { return }
        settled = false
        let wurf = rolls
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(SchockenDie.duration * 0.8 * 1_000_000_000))
            // Ein schnellerer zweiter Wurf hat seine eigene Wartezeit
            if rolls == wurf { settled = true }
        }
    }

    private func finishTurn(_ player: Int) {
        results[player] = SchockenThrow.evaluate(dice)
        // Der Erste legt die Wurfzahl fuer alle fest.
        if throwLimit == nil { throwLimit = throwsUsed }

        HapticManager.lightImpact()
        SoundManager.play(.tap)

        withAnimation(AppAnimation.standard) {
            phase = player + 1 < playerCount ? .handoff(player: player + 1) : .roundOver
        }

        if player + 1 >= playerCount {
            SoundManager.play(.bombe)
            // Das Spiel rechnet ohnehin aus, wer verloren hat – die Bilanz
            // erfaehrt es jetzt auch. Ohne laufenden Abend passiert nichts.
            if let verlierer = worstPlayer() {
                let hadSchockAus = results.compactMap { $0 }.contains { $0.kind == .schockAus }
                EveningLog.record(hadSchockAus ? schockAusPenalty : penalty, forPlayer: verlierer)
            }
        }
    }
}
