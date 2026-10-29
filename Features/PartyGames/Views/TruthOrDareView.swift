//
//  TruthOrDareView.swift
//  BeerStats
//
//  Wahrheit oder Pflicht mit klarer Trinkregel: Verweigern kostet vier
//  Schluecke – und ist damit ausdruecklich erlaubt.
//
//  Beide Stapel laufen getrennt und werden je einmal gemischt durchgegangen.
//  Wuerde jedes Mal frei gezogen, kaeme dieselbe Frage zurueck, bevor der
//  Satz durch ist.
//

import SwiftUI

struct TruthOrDareView: View {

    @State private var truths: [TruthOrDareCard] = TruthOrDareDeck.shuffled(.truth)
    @State private var dares: [TruthOrDareCard] = TruthOrDareDeck.shuffled(.dare)
    @State private var current: TruthOrDareCard?
    @State private var isRefusing = false
    @State private var refusalTask: Task<Void, Never>?
    /// Wie oft weitergegeben wurde. Wer das ist, rechnet `TurnRow`.
    @State private var turn = 0

    @Environment(\.gameWorld) private var world

    private var tint: Color {
        current?.kind == .dare ? BeerStatsColor.accentSecondary : BeerStatsColor.accent
    }

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: tint)

            VStack(spacing: 20) {
                if let card = current {
                    cardView(card)
                    // Karten ohne Kennung sind selbst eingetippt – die
                    // loescht man unter "Eigene Karten", nicht hier.
                    if !card.key.isEmpty {
                        HideCardButton(cardKey: card.key, deck: .truthOrDare)
                    }
                    resolveControls
                } else {
                    chooser
                }
            }
            .padding(24)

            if isRefusing {
                refusalOverlay
                    .zIndex(2)
            }
        }
        .navigationTitle("Wahrheit oder Pflicht")
        .navigationBarTitleDisplayMode(.inline)
        .roundSettings(for: .truthOrDare)
        .onDisappear { refusalTask?.cancel() }
    }

    // MARK: - Auswahl

    private var chooser: some View {
        VStack(spacing: 18) {
            TurnRow(turn: turn)

            Text(PlayerNames.knowsNames ? "Wahrheit oder Pflicht?" : "Wer dran ist, wählt.")
                .font(Font.world(world, 26, weight: .heavy))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)

            Text("Verweigern ist erlaubt und kostet \(TruthOrDareDeck.refusal.text).")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            // Die Stapel liegen, wo ihre Haelfte des Tisches ist: die
            // Wahrheit oben links, die Pflicht unten rechts
            pile(.truth, remaining: truths.count)
                .frame(maxWidth: .infinity, alignment: .leading)
            pile(.dare, remaining: dares.count)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func pile(_ kind: TruthOrDareKind, remaining: Int) -> some View {
        Button {
            draw(kind)
        } label: {
            CardPile(kind: kind, remaining: remaining)
                .frame(width: 220)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(kind.title) ziehen, \(remaining) übrig")
    }

    // MARK: - Karte

    /// Die gezogene Karte. Sie fuellt den Platz (`maxHeight: .infinity` in
    /// `TruthOrDareFace`), statt ihn frei zu lassen – und wer verweigert,
    /// zerreisst sie.
    private func cardView(_ card: TruthOrDareCard) -> some View {
        Group {
            if isRefusing {
                TornApart { face(card) }
            } else {
                face(card)
            }
        }
        .id(card.id)
        .transition(.asymmetric(
            insertion: .drawn(from: card.kind),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(AppAnimation.standard, value: card.id)
    }

    private func face(_ card: TruthOrDareCard) -> some View {
        TruthOrDareFace(
            kind: card.kind,
            text: card.text,
            price: "Verweigern kostet \(TruthOrDareDeck.refusal.text)"
        )
    }

    private var resolveControls: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "Gemacht", systemImage: "checkmark") {
                HapticManager.success()
                SoundManager.play(.ballsBack)
                withAnimation(AppAnimation.standard) {
                    current = nil
                    turn += 1
                }
            }

            Button {
                refuse()
            } label: {
                Text("Verweigern – \(TruthOrDareDeck.refusal.text)")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.error)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        BeerStatsColor.error.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: - Verweigert

    /// Nur abgedunkelt, nicht zugedeckt: Dahinter faellt die zerrissene
    /// Karte auseinander, und das soll man sehen.
    private var refusalOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
            RadialGradient(
                colors: [BeerStatsColor.error.opacity(0.35), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            Text(TruthOrDareDeck.refusal.text.uppercased())
                .font(.scaled(44, weight: .black, design: .default, width: .compressed))
                .kerning(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(BeerStatsColor.error)
                .shadow(color: .black.opacity(0.7), radius: 10)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { endRefusal() }
        .transition(.opacity)
    }

    // MARK: - Ablauf

    private func draw(_ kind: TruthOrDareKind) {
        // Ist ein Stapel durch, wird nur dieser neu gemischt – der andere
        // laeuft weiter, wo er war.
        switch kind {
        case .truth:
            if truths.isEmpty { truths = TruthOrDareDeck.shuffled(.truth) }
            current = truths.popLast()
        case .dare:
            if dares.isEmpty { dares = TruthOrDareDeck.shuffled(.dare) }
            current = dares.popLast()
        }
        HapticManager.lightImpact()
        SoundManager.play(.cardFlip)
    }

    private func refuse() {
        refusalTask?.cancel()
        HapticManager.error()
        SoundManager.play(.bombe)
        withAnimation(AppAnimation.standard) { isRefusing = true }

        refusalTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            guard !Task.isCancelled else { return }
            endRefusal()
        }
    }

    private func endRefusal() {
        refusalTask?.cancel()
        withAnimation(AppAnimation.smoothFade) {
            isRefusing = false
            current = nil
        }
    }
}
