//
//  KingsCupView.swift
//  BeerStats
//
//  Koenigsbecher: Reihum eine Karte ziehen, jeder Rang bedeutet etwas
//  anderes. Wer den vierten Koenig zieht, trinkt den Becher aus der Mitte.
//
//  Die Karte dreht sich sichtbar um, statt einfach zu erscheinen. Das ist
//  nicht nur Schmuck: Der halbe Reiz des Spiels ist der Moment, in dem
//  keiner weiss, was kommt – und beim vierten Koenig ist er alles.
//

import SwiftUI

struct KingsCupView: View {

    @State private var deck: [PlayingCard] = PlayingCardDeck.shuffled()
    @State private var current: PlayingCard?
    @State private var flipAngle: Double = 0
    @State private var kingsDrawn = 0
    @State private var isFinalKing = false
    @State private var drawTask: Task<Void, Never>?

    private var rule: KingsCupRule? {
        current.map { KingsCupRules.rule(for: $0.rank) }
    }

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.accent)

            VStack(spacing: 18) {
                kingRow
                cardArea
                rulePanel
                Spacer(minLength: 0)
                controls
            }
            .padding(24)

            if isFinalKing {
                finalKingOverlay
                    // Muss ueber allem liegen und Eingaben abfangen: Wer den
                    // vierten Koenig zieht, soll ihn nicht wegtippen, bevor
                    // die Runde ihn gesehen hat.
                    .zIndex(2)
            }
        }
        .navigationTitle("Königsbecher")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { drawTask?.cancel() }
    }

    // MARK: - Kopf

    private var kingRow: some View {
        HStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { index in
                Text("👑")
                    .font(.system(size: 24))
                    .opacity(index < kingsDrawn ? 1 : 0.18)
                    .scaleEffect(index < kingsDrawn ? 1 : 0.85)
            }

            Spacer()

            Text("\(deck.count) Karten")
                .font(BeerStatsFont.statLabel)
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
        .animation(AppAnimation.standard, value: kingsDrawn)
    }

    // MARK: - Karte

    private var cardArea: some View {
        PlayingCardView(card: current, width: 150)
            .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0))
            .frame(height: 230)
    }

    @ViewBuilder
    private var rulePanel: some View {
        if let rule, let current {
            VStack(spacing: 10) {
                Text(rule.emoji).font(.system(size: 32))

                Text(rule.title.uppercased())
                    .font(Font.system(size: 13, weight: .heavy, design: .rounded))
                    .kerning(2.6)
                    .foregroundStyle(rule.isKing ? BeerStatsColor.warning : BeerStatsColor.accent)

                Text(rule.text)
                    .font(BeerStatsFont.body)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .glassPanel(cornerRadius: 20)
            .neonEdge(
                rule.isKing ? BeerStatsColor.warning : BeerStatsColor.accent,
                cornerRadius: 20,
                intensity: rule.isKing ? 0.9 : 0.5
            )
            .id(current.id)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else {
            Text("Reihum ziehen. Jeder Rang bedeutet etwas anderes.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var controls: some View {
        if deck.isEmpty {
            VStack(spacing: 10) {
                Text("Blatt durch")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                PrimaryButton(title: "Neu mischen", systemImage: "shuffle") { restart() }
            }
        } else {
            PrimaryButton(title: "Karte ziehen", systemImage: "hand.tap.fill") { draw() }
        }
    }

    // MARK: - Vierter Koenig

    private var finalKingOverlay: some View {
        ZStack {
            BeerStatsColor.backgroundPrimary.opacity(0.94)
            RadialGradient(
                colors: [BeerStatsColor.warning.opacity(0.4), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 300
            )

            VStack(spacing: 14) {
                Text("👑").font(.system(size: 96))
                Text("VIERTER KÖNIG")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .kerning(3)
                    .foregroundStyle(BeerStatsColor.warning)
                    .multilineTextAlignment(.center)
                Text("Du trinkst den Becher aus der Mitte.")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button("Ausgetrunken") {
                    withAnimation(AppAnimation.smoothFade) { isFinalKing = false }
                }
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .padding(.top, 20)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .transition(.opacity)
    }

    // MARK: - Ablauf

    /// Zieht in zwei Schritten: erst hochkant drehen, dann die neue Karte
    /// einsetzen und zurueckdrehen. Bei 90 Grad steht die Karte auf der
    /// Kante, der Wechsel ist dort unsichtbar.
    private func draw() {
        guard let next = deck.last else { return }
        drawTask?.cancel()
        deck.removeLast()
        HapticManager.lightImpact()
        SoundManager.play(.tap)

        withAnimation(.easeIn(duration: 0.17)) { flipAngle = 90 }

        drawTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 170_000_000)
            guard !Task.isCancelled else { return }

            current = next
            flipAngle = -90
            withAnimation(.easeOut(duration: 0.2)) { flipAngle = 0 }

            guard next.rank == 13 else {
                SoundManager.play(.cupHit)
                return
            }

            kingsDrawn += 1
            HapticManager.error()

            guard kingsDrawn >= 4 else {
                SoundManager.play(.onFire)
                return
            }

            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            SoundManager.play(.bombe)
            HapticManager.success()
            withAnimation(AppAnimation.standard) { isFinalKing = true }
        }
    }

    private func restart() {
        drawTask?.cancel()
        deck = PlayingCardDeck.shuffled()
        current = nil
        flipAngle = 0
        kingsDrawn = 0
        isFinalKing = false
        HapticManager.success()
    }
}
