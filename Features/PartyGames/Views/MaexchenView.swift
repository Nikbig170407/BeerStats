//
//  MaexchenView.swift
//  BeerStats
//
//  Maexchen: verdeckt wuerfeln, ansagen, luegen duerfen.
//
//  Die App uebernimmt genau die zwei Dinge, an denen es am Tisch scheitert.
//  Erstens die Rangfolge – 21 schlaegt 66, und jeder Pasch schlaegt jede
//  normale Zahl; das weiss nach dem dritten Bier niemand mehr. Deshalb gibt
//  es zur Ansage nur noch die Werte zur Auswahl, die ueberhaupt hoeher sind.
//
//  Zweitens das Aufdecken: Die App kennt den echten Wurf UND die Ansage und
//  entscheidet selbst, wer trinkt. Mit einem echten Becher sieht man den
//  Wurf beim Aufdecken auch – aber nur den letzten. Hier stimmt es immer.
//

import SwiftUI

struct MaexchenView: View {

    private enum Phase: Equatable {
        case setup
        /// Handy liegt bei Spieler `player`, Anspruch steht offen.
        case handoff(player: Int)
        case rolled(player: Int)
        case claiming(player: Int)
        case revealed(doubter: Int, liar: Bool)
    }

    @State private var playerCount = 4
    @State private var phase: Phase = .setup

    /// Wurf des Spielers, der die aktuelle Ansage gemacht hat.
    @State private var lastRoll: MaexchenRoll?
    @State private var claim: Int?
    @State private var claimant = 0
    @State private var myRoll = MaexchenRoll.random()

    private let normalPenalty = DrinkAmount.sips(3)
    private let miaPenalty = DrinkAmount.sips(6)

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.accentSecondary)

            ScrollView {
                VStack(spacing: 20) {
                    switch phase {
                    case .setup: setupView
                    case .handoff(let player): handoffView(player)
                    case .rolled(let player): rolledView(player)
                    case .claiming(let player): claimingView(player)
                    case .revealed(let doubter, let liar): revealedView(doubter: doubter, liar: liar)
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Mäxchen")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Vorbereitung

    private var setupView: some View {
        VStack(spacing: 18) {
            Text("🎲").font(.system(size: 56))

            Text("Wie viele spielen mit?")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Verdeckt würfeln, ansagen – wahr oder gelogen. Der Nächste glaubt dir oder deckt auf.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                stepButton("−") { if playerCount > 2 { playerCount -= 1 } }
                Text("\(playerCount)")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(BeerStatsColor.accentSecondary)
                    .frame(minWidth: 80)
                stepButton("+") { if playerCount < 12 { playerCount += 1 } }
            }

            PrimaryButton(title: "Los geht's", systemImage: "play.fill") { startRound(firstPlayer: 0) }
        }
    }

    private func stepButton(_ label: String, action: @escaping () -> Void) -> some View {
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

    // MARK: - Übergabe

    private func handoffView(_ player: Int) -> some View {
        VStack(spacing: 18) {
            Text("Spieler \(player + 1)")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            if let claim {
                VStack(spacing: 6) {
                    Text("Spieler \(claimant + 1) sagt")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                    Text(MaexchenRanking.label(claim))
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(BeerStatsColor.accentSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .glassPanel(cornerRadius: 22)
                .neonEdge(BeerStatsColor.accentSecondary, cornerRadius: 22, intensity: 0.7)

                Text("Glaubst du das?")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)

                if MaexchenRanking.values(above: claim).isEmpty {
                    // Über 21 geht nichts mehr – Aufdecken ist die einzige Wahl.
                    Text("Höher geht nicht. Du musst aufdecken.")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    PrimaryButton(title: "Glauben und würfeln", systemImage: "dice") { roll(player) }
                }

                Button {
                    reveal(doubter: player)
                } label: {
                    Text("Aufdecken")
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.error)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .glassPanel(cornerRadius: 16)
                        .neonEdge(BeerStatsColor.error, cornerRadius: 16, intensity: 0.5)
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())

            } else {
                Text("Du fängst an. Würfle verdeckt und sag etwas an – die Wahrheit oder nicht.")
                    .font(BeerStatsFont.body)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)

                PrimaryButton(title: "Würfeln", systemImage: "dice") { roll(player) }
            }
        }
    }

    // MARK: - Wurf

    private func rolledView(_ player: Int) -> some View {
        VStack(spacing: 18) {
            Text("Nur für Spieler \(player + 1)")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)

            VStack(spacing: 10) {
                Text(myRoll.diceSymbols)
                    .font(.system(size: 72))
                Text(MaexchenRanking.label(myRoll.value))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(myRoll.isMia ? BeerStatsColor.error : BeerStatsColor.success)
            }
            .frame(maxWidth: .infinity)
            .padding(26)
            .glassPanel(cornerRadius: 22)
            .neonEdge(myRoll.isMia ? BeerStatsColor.error : BeerStatsColor.success, cornerRadius: 22, intensity: 0.8)

            Text("Niemand sonst sieht das. Jetzt ansagen – du darfst lügen.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            PrimaryButton(title: "Ansage machen", systemImage: "megaphone") {
                withAnimation(AppAnimation.standard) { phase = .claiming(player: player) }
                HapticManager.lightImpact()
            }
        }
    }

    // MARK: - Ansage

    private func claimingView(_ player: Int) -> some View {
        VStack(spacing: 14) {
            Text("Was sagst du an?")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Es muss höher sein als \(claim.map { MaexchenRanking.label($0) } ?? "nichts"). Ob es stimmt, ist deine Sache.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            // Nur die Werte, die überhaupt zulässig sind. Damit ist die
            // Rangfolge nicht mehr Kopfsache.
            ForEach(MaexchenRanking.values(above: claim), id: \.self) { value in
                Button {
                    makeClaim(value, by: player)
                } label: {
                    HStack {
                        Text(MaexchenRanking.label(value))
                            .font(BeerStatsFont.headline)
                            .foregroundStyle(BeerStatsColor.textPrimary)
                        Spacer()
                        if value == myRoll.value {
                            Text("dein Wurf")
                                .font(BeerStatsFont.caption)
                                .foregroundStyle(BeerStatsColor.success)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .glassPanel(cornerRadius: 14)
                    .neonEdge(
                        value == myRoll.value ? BeerStatsColor.success : BeerStatsColor.textSecondary,
                        cornerRadius: 14,
                        intensity: value == myRoll.value ? 0.6 : 0.12
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    // MARK: - Auflösung

    private func revealedView(doubter: Int, liar: Bool) -> some View {
        let loser = liar ? claimant : doubter
        let wasMia = lastRoll?.isMia == true
        let amount = wasMia && !liar ? miaPenalty : normalPenalty

        return VStack(spacing: 16) {
            Text(liar ? "🤥" : "😬").font(.system(size: 56))

            VStack(spacing: 6) {
                Text("Spieler \(claimant + 1) sagte")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                Text(claim.map { MaexchenRanking.label($0) } ?? "–")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.accentSecondary)

                Text("gewürfelt war")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .padding(.top, 6)
                Text(lastRoll.map { "\($0.diceSymbols)  \(MaexchenRanking.label($0.value))" } ?? "–")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(liar ? BeerStatsColor.error : BeerStatsColor.success)
            }
            .frame(maxWidth: .infinity)
            .padding(22)
            .glassPanel(cornerRadius: 22)

            Text("Spieler \(loser + 1) trinkt \(amount.text)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(BeerStatsColor.error)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(18)
                .glassPanel(cornerRadius: 18)
                .neonEdge(BeerStatsColor.error, cornerRadius: 18, intensity: 0.7)

            if wasMia && !liar {
                Text("Mäxchen zu Unrecht angezweifelt – das kostet doppelt.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            PrimaryButton(title: "Nächste Runde", systemImage: "arrow.counterclockwise") {
                startRound(firstPlayer: loser)
            }

            Button("Spielerzahl ändern") {
                withAnimation(AppAnimation.standard) { phase = .setup }
            }
            .font(BeerStatsFont.caption)
            .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    // MARK: - Ablauf

    private func startRound(firstPlayer: Int) {
        claim = nil
        lastRoll = nil
        claimant = firstPlayer
        withAnimation(AppAnimation.standard) { phase = .handoff(player: firstPlayer) }
        HapticManager.success()
    }

    private func roll(_ player: Int) {
        myRoll = MaexchenRoll.random()
        withAnimation(AppAnimation.standard) { phase = .rolled(player: player) }
        HapticManager.mediumImpact()
        SoundManager.play(.cupHit)
    }

    private func makeClaim(_ value: Int, by player: Int) {
        claim = value
        lastRoll = myRoll
        claimant = player
        HapticManager.lightImpact()
        SoundManager.play(.tap)
        withAnimation(AppAnimation.standard) {
            phase = .handoff(player: (player + 1) % playerCount)
        }
    }

    private func reveal(doubter: Int) {
        // Gelogen hat, wer weniger gewürfelt hat, als er angesagt hat.
        let liar: Bool
        if let claim, let lastRoll {
            liar = !MaexchenRanking.beats(claim, lastRoll.value)
        } else {
            liar = false
        }

        withAnimation(AppAnimation.standard) { phase = .revealed(doubter: doubter, liar: liar) }
        HapticManager.error()
        SoundManager.play(.bombe)
    }
}
