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

    @State private var playerCount = PlayerNames.suggestedCount ?? 4
    @State private var phase: Phase = .setup

    @State private var dice = [1, 1, 1]
    @State private var kept = [false, false, false]
    @State private var throwsUsed = 0
    /// Vom ersten Spieler der Runde gesetzt. `nil`, solange niemand fertig ist.
    @State private var throwLimit: Int?
    @State private var results: [SchockenThrow?] = []

    private let penalty = DrinkAmount.sips(3)
    private let schockAusPenalty = DrinkAmount.sips(6)

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.warning)

            ScrollView {
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
            Text("🎲").font(.system(size: 56))

            Text("Wie viele spielen mit?")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Drei Würfel, bis zu drei Würfe. Der Erste legt fest, wie viele Würfe die Runde hat.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            PlayerCountStepper(count: $playerCount, range: 2...10, tint: BeerStatsColor.warning)

            rankingCard

            PrimaryButton(title: "Runde starten", systemImage: "play.fill") { startRound() }
        }
    }

    /// Die Rangfolge steht im Spiel selbst, nicht nur im Kopf des Erklaerers.
    private var rankingCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("RANGFOLGE, NIEDRIG NACH HOCH")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .kerning(1.4)
                .foregroundStyle(BeerStatsColor.textSecondary)
            Text("Zahl · Straße · General · Schock · Schock aus")
                .font(BeerStatsFont.caption)
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
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            if let throwLimit {
                Text("Du hast \(throwLimit) \(throwLimit == 1 ? "Wurf" : "Würfe")")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.warning)
            } else {
                Text("Du fängst an – bis zu drei Würfe. Womit du aufhörst, gilt für alle.")
                    .font(BeerStatsFont.body)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if !results.isEmpty { standings }

            PrimaryButton(title: "Würfeln", systemImage: "dice") { beginTurn(player) }
        }
    }

    // MARK: - Würfeln

    private func rollingView(_ player: Int) -> some View {
        VStack(spacing: 20) {
            Text("\(PlayerNames.name(for: player)) · Wurf \(throwsUsed) von \(throwLimit ?? 3)")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)

            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { slot in
                    dieButton(slot)
                }
            }

            Text(SchockenThrow.evaluate(dice).label)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.warning)

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
        let faces = ["", "⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
        let isKept = kept[slot]

        return Button {
            kept[slot].toggle()
            HapticManager.lightImpact()
        } label: {
            Text(faces[dice[slot]])
                .font(.system(size: 52))
                .foregroundStyle(isKept ? BeerStatsColor.warning : BeerStatsColor.textPrimary)
                .frame(width: 78, height: 78)
                .glassPanel(cornerRadius: 16)
                .neonEdge(BeerStatsColor.warning, cornerRadius: 16, intensity: isKept ? 0.9 : 0.12)
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Zwischenstand und Ergebnis

    private var standings: some View {
        VStack(spacing: 6) {
            ForEach(results.indices, id: \.self) { index in
                if let result = results[index] {
                    HStack {
                        Text("\(PlayerNames.name(for: index))")
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                        Spacer()
                        Text(result.symbols)
                        Text(result.label)
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textPrimary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .glassPanel(cornerRadius: 12)
                }
            }
        }
    }

    private var roundOverView: some View {
        let loser = worstPlayer()
        let hadSchockAus = results.compactMap { $0 }.contains { $0.kind == .schockAus }
        let amount = hadSchockAus ? schockAusPenalty : penalty

        return VStack(spacing: 16) {
            Text(hadSchockAus ? "💥" : "🍺").font(.system(size: 54))

            standings

            if let loser {
                Text("\(PlayerNames.name(for: loser)) trinkt \(amount.text)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
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

            Button("Spielerzahl ändern") {
                withAnimation(AppAnimation.standard) { phase = .setup }
            }
            .font(BeerStatsFont.caption)
            .foregroundStyle(BeerStatsColor.textSecondary)
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
        }
        throwsUsed += 1
        HapticManager.mediumImpact()
        SoundManager.play(.cupHit)
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
