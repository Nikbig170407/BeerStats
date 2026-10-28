//
//  ReactionDuelView.swift
//  BeerStats
//
//  Zwei Spieler, ein Handy: Jeder legt den Daumen auf seine Haelfte, nach
//  einer zufaelligen Wartezeit wird der Bildschirm gruen. Wer zuerst tippt,
//  gewinnt – wer zu frueh tippt, verliert sofort.
//
//  Die obere Haelfte steht auf dem Kopf, damit das Handy zwischen beiden
//  auf dem Tisch liegen kann und jeder seine Seite richtig herum sieht.
//
//  Die Wartezeit ist bewusst zufaellig und ohne jeden Hinweis: Sobald sie
//  vorhersehbar waere, gewaenne nicht die Reaktion, sondern das Mitzaehlen.
//  Der Frueh-Tipp muss deshalb hart bestraft werden, sonst haemmern beide
//  einfach los.
//

import SwiftUI

struct ReactionDuelView: View {

    private enum Phase: Equatable {
        case idle
        case waiting
        case go
        /// Gewonnen hat `winner` (0 = oben, 1 = unten).
        case done(winner: Int, tooEarly: Bool)
    }

    @State private var phase: Phase = .idle
    @State private var armTask: Task<Void, Never>?
    @State private var goDate: Date?
    @State private var reactionMillis: Int?
    @State private var scores = [0, 0]
    /// Zaehlt die Signale – jedes kommt mit einem weissen Blitz.
    @State private var signals = 0

    @Environment(\.gameWorld) private var world

    /// Was Verlieren kostet – und was der Frueh-Tipp zusaetzlich kostet.
    ///
    /// Bisher war der Frueh-Tipp nur mit "du verlierst sofort" bestraft.
    /// Das ist dieselbe Strafe wie zu langsam zu sein, obwohl das eine ein
    /// Versuch zu schummeln ist und das andere nur langsam. Jetzt kostet er
    /// das Doppelte, und die eingestellte Haerte gilt auch hier.
    private let penalty = DrinkAmount.sips(2)
    private let earlyPenalty = DrinkAmount.sips(4)

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                half(playerIndex: 0, height: geometry.size.height / 2)
                    .rotationEffect(.degrees(180))
                half(playerIndex: 1, height: geometry.size.height / 2)
            }
            .overlay { EffectFlash(trigger: signals, tint: .white, peak: 0.85) }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle("Reaktionsduell")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { armTask?.cancel() }
    }

    // MARK: - Eine Spielerhaelfte

    private func half(playerIndex: Int, height: CGFloat) -> some View {
        ZStack {
            background(for: playerIndex)

            VStack(spacing: 10) {
                Text(headline(for: playerIndex))
                    .font(Font.world(world, 40, weight: .heavy))
                    .foregroundStyle(HighNoon.sand)
                    .shadow(color: .black.opacity(0.7), radius: 6)
                    .multilineTextAlignment(.center)

                Text(subline(for: playerIndex))
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textPrimary.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("\(scores[playerIndex])")
                    .font(.scaled(20, weight: .heavy, design: .rounded))
                    .foregroundStyle(BeerStatsColor.textPrimary.opacity(0.6))
                    .padding(.top, 4)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .contentShape(Rectangle())
        .onTapGesture { handleTap(by: playerIndex) }
    }

    /// Jede Haelfte ist eine Wueste in der Daemmerung. Was sie bedeutet,
    /// liegt als Licht darueber: Rot heisst warten, Gruen heisst jetzt –
    /// diese Bedeutung bleibt in jeder Welt.
    private func background(for playerIndex: Int) -> some View {
        let color: Color
        let staerke: Double
        switch phase {
        case .idle:
            color = .clear
            staerke = 0
        case .waiting:
            color = BeerStatsColor.error
            staerke = 0.3
        case .go:
            color = BeerStatsColor.success
            staerke = 0.6
        case .done(let winner, _):
            color = winner == playerIndex ? BeerStatsColor.success : BeerStatsColor.error
            staerke = 0.4
        }

        // Wer zu frueh gezogen hat, behaelt das Loch bis zur naechsten Runde
        let getroffen: Bool
        if case .done(let winner, let tooEarly) = phase {
            getroffen = tooEarly && winner != playerIndex
        } else {
            getroffen = false
        }

        return ZStack {
            DesertHalf(breathing: phase == .waiting, bulletHole: getroffen)
            color.opacity(staerke)
        }
        .animation(AppAnimation.tap, value: phase)
    }

    private func headline(for playerIndex: Int) -> String {
        switch phase {
        case .idle:    return playerIndex == 0 ? "Spieler 1" : "Spieler 2"
        case .waiting: return "Warten …"
        case .go:      return "JETZT!"
        case .done(let winner, let tooEarly):
            if winner == playerIndex { return tooEarly ? "Gewonnen" : "Schneller!" }
            return tooEarly ? "Zu früh!" : "Zu langsam"
        }
    }

    private func subline(for playerIndex: Int) -> String {
        switch phase {
        case .idle:
            return "Beide bereit? Tippen zum Starten."
        case .waiting:
            return "Nicht tippen, bevor es grün wird."
        case .go:
            return "Tippen!"
        case .done(let winner, let tooEarly):
            let menge = (tooEarly ? earlyPenalty : penalty).text

            if winner == playerIndex {
                guard !tooEarly, let millis = reactionMillis else {
                    return "Der andere trinkt \(menge)."
                }
                return "\(millis) ms – der andere trinkt \(menge)."
            }
            return tooEarly
                ? "Vorschnell getippt – du trinkst \(menge)."
                : "Du trinkst \(menge)."
        }
    }

    // MARK: - Ablauf

    private func handleTap(by playerIndex: Int) {
        switch phase {
        case .idle, .done:
            start()

        case .waiting:
            // Zu frueh: Der andere gewinnt sofort. Ohne diese Strafe waere
            // Dauerfeuer die beste Strategie.
            armTask?.cancel()
            finish(winner: 1 - playerIndex, tooEarly: true)

        case .go:
            if let goDate {
                reactionMillis = Int(Date().timeIntervalSince(goDate) * 1000)
            }
            finish(winner: playerIndex, tooEarly: false)
        }
    }

    private func start() {
        armTask?.cancel()
        reactionMillis = nil
        goDate = nil
        withAnimation(AppAnimation.tap) { phase = .waiting }
        HapticManager.lightImpact()

        armTask = Task { @MainActor in
            let delay = Double.random(in: 1.8...6.0)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            goDate = Date()
            signals += 1
            withAnimation(AppAnimation.tap) { phase = .go }
            HapticManager.success()
            SoundManager.play(.ballsBack)
        }
    }

    private func finish(winner: Int, tooEarly: Bool) {
        armTask?.cancel()
        scores[winner] += 1
        withAnimation(AppAnimation.standard) { phase = .done(winner: winner, tooEarly: tooEarly) }
        HapticManager.error()
        SoundManager.play(tooEarly ? .miss : .victory)
    }
}
