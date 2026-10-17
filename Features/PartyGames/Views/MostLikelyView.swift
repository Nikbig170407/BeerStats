//
//  MostLikelyView.swift
//  BeerStats
//
//  "Wer würde eher?" – Karte vorlesen, bis drei zaehlen, alle zeigen
//  gleichzeitig. Die meisten Finger trinken.
//
//  Der Countdown ist der Kern des Spiels und deshalb in der App und nicht
//  im Kopf der Runde: Zaehlt jemand selbst, schauen alle erst, wohin die
//  anderen zeigen. Drei Sekunden gleichzeitig sind etwas anderes.
//

import SwiftUI

struct MostLikelyView: View {

    private enum Phase: Equatable { case reading, counting(Int), reveal }

    @State private var deck: [MostLikelyCard] = MostLikelyDeck.shuffled()
    @State private var index = 0
    @State private var phase: Phase = .reading
    @State private var countTask: Task<Void, Never>?

    /// Was die meisten Finger kosten.
    ///
    /// Stand bis Oktober 2026 nirgends: Das Spiel sagte "die meisten Finger
    /// trinken" und liess die Menge offen. Damit war es auch das einzige
    /// Kartenspiel ohne Haerte – es gab ja nichts zu staerken oder zu
    /// mildern. Jetzt steht die Menge nach dem Zeigen auf dem Schirm, und
    /// damit greift die Haerte auch hier.
    private let penalty = DrinkAmount.sips(3)

    private var currentCard: MostLikelyCard? {
        deck.indices.contains(index) ? deck[index] : nil
    }

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.warning)

            VStack(spacing: 22) {
                if let card = currentCard {
                    progressLine
                    cardView(card)
                    controls
                    hideRow
                } else {
                    finishedView
                }
            }
            .padding(24)
        }
        .navigationTitle("Wer würde eher?")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { countTask?.cancel() }
    }

    private var progressLine: some View {
        HStack {
            Text("Karte \(index + 1) von \(deck.count)")
                .font(BeerStatsFont.statLabel)
                .foregroundStyle(BeerStatsColor.textSecondary)
            Spacer()
            QuietButton(title: "Neu mischen") { restart() }
        }
    }

    private func cardView(_ card: MostLikelyCard) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            Text("👉").font(.system(size: 34))

            Text(card.text)
                .font(.scaled(25, weight: .bold, design: .rounded))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            countdownLabel

            Spacer(minLength: 0)
        }
        // Fuellt den Platz, statt ihn frei zu lassen: Hier stand ein
        // `Spacer` zwischen Karte und Knoepfen, und die Karte blieb so klein
        // wie ihr Text. Die Spacer INNEN halten den Text in der Mitte.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
        .glassPanel(cornerRadius: 24)
        .neonEdge(BeerStatsColor.warning, cornerRadius: 24, intensity: 0.6)
        .id(card.id)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(AppAnimation.standard, value: card.id)
    }

    @ViewBuilder
    private var countdownLabel: some View {
        switch phase {
        case .reading:
            EmptyView()
        case .counting(let value):
            Text("\(value)")
                .font(.scaled(64, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.warning)
                .transition(.scale.combined(with: .opacity))
                .id(value)
        case .reveal:
            VStack(spacing: 6) {
                Text("ZEIGEN!")
                    .font(.scaled(34, weight: .heavy, design: .rounded))
                    .kerning(3)
                    .foregroundStyle(BeerStatsColor.success)

                Text("Die meisten Finger: \(penalty.text)")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            .transition(.scale.combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch phase {
        case .reading:
            PrimaryButton(title: "Countdown starten", systemImage: "timer") { startCountdown() }
        case .counting:
            Text("Gleich zeigen …")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .frame(height: 52)
        case .reveal:
            PrimaryButton(title: "Nächste Karte", systemImage: "arrow.right") { advance() }
        }
    }

    /// Der Daumen nach unten steht die ganze Zeit da, in jedem Schritt.
    ///
    /// Erst nach dem Zeigen war falsch: Die Frage steht von Anfang an auf
    /// der Karte, und wer sie nicht mag, sieht das beim Vorlesen – nicht
    /// drei Sekunden Countdown spaeter. Vor allem aber war er so praktisch
    /// unsichtbar: Wer das Spiel aufmacht, sieht "Countdown starten" und
    /// sonst nichts.
    ///
    /// Eigene Karten tragen ihn nicht – die loescht man unter "Eigene
    /// Karten".
    @ViewBuilder
    private var hideRow: some View {
        if let card = currentCard, !card.isCustom {
            HideCardButton(cardKey: card.text, deck: .mostLikely)
        }
    }

    /// Zwei Enden, die verschieden aussehen muessen: Stapel durchgespielt –
    /// oder gar keine Karte uebrig, weil alles weggedaumt ist. Im zweiten
    /// Fall hilft "Neu mischen" nicht, und wer nicht weiss, wo das zurueck
    /// geht, sitzt vor einem Spiel ohne Inhalt.
    private var finishedView: some View {
        VStack(spacing: 18) {
            Text(deck.isEmpty ? "🫥" : "🏁").font(.system(size: 60))

            Text(deck.isEmpty ? "Keine Karte übrig" : "Stapel durch")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text(deck.isEmpty
                 ? "Alle Karten sind ausgeblendet. Unter „Eigene Karten“ im Hauptmenü lassen sie sich wieder anzeigen."
                 : "\(deck.count) Karten gespielt.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if !deck.isEmpty {
                PrimaryButton(title: "Neu mischen", systemImage: "shuffle") { restart() }
            }
        }
    }

    // MARK: - Ablauf

    private func startCountdown() {
        countTask?.cancel()
        countTask = Task { @MainActor in
            for value in stride(from: 3, through: 1, by: -1) {
                withAnimation(AppAnimation.standard) { phase = .counting(value) }
                HapticManager.lightImpact()
                SoundManager.play(.tap)
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard !Task.isCancelled else { return }
            }
            withAnimation(AppAnimation.standard) { phase = .reveal }
            HapticManager.success()
            SoundManager.play(.ballsBack)
        }
    }

    private func advance() {
        countTask?.cancel()
        withAnimation(AppAnimation.standard) {
            index += 1
            phase = .reading
        }
        HapticManager.lightImpact()
    }

    private func restart() {
        countTask?.cancel()
        deck = MostLikelyDeck.shuffled()
        index = 0
        phase = .reading
        HapticManager.success()
    }
}
