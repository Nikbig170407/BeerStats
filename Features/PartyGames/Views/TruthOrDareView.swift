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
    @State private var refusal: Int?
    @State private var refusalTask: Task<Void, Never>?

    private var tint: Color {
        current?.kind == .dare ? BeerStatsColor.accentSecondary : BeerStatsColor.accent
    }

    var body: some View {
        ZStack {
            GridBackdrop(glow: tint)

            VStack(spacing: 20) {
                if let card = current {
                    cardView(card)
                    Spacer(minLength: 0)
                    resolveControls
                } else {
                    chooser
                }
            }
            .padding(24)

            if let sips = refusal {
                refusalOverlay(sips: sips)
                    .zIndex(2)
            }
        }
        .navigationTitle("Wahrheit oder Pflicht")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { refusalTask?.cancel() }
    }

    // MARK: - Auswahl

    private var chooser: some View {
        VStack(spacing: 18) {
            Text("🎭").font(.system(size: 56))

            Text("Wer dran ist, wählt.")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Verweigern ist erlaubt und kostet \(TruthOrDareDeck.refusalSips) Schlücke.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            chooserButton(.truth, tint: BeerStatsColor.accent, remaining: truths.count)
            chooserButton(.dare, tint: BeerStatsColor.accentSecondary, remaining: dares.count)
        }
    }

    private func chooserButton(_ kind: TruthOrDareKind, tint: Color, remaining: Int) -> some View {
        Button {
            draw(kind)
        } label: {
            HStack(spacing: 16) {
                Text(kind.emoji).font(.system(size: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(BeerStatsFont.title)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                    Text("\(remaining) übrig")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .glassPanel(cornerRadius: 20)
            .neonEdge(tint, cornerRadius: 20, intensity: 0.6)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Karte

    private func cardView(_ card: TruthOrDareCard) -> some View {
        VStack(spacing: 16) {
            Text(card.kind.emoji).font(.system(size: 36))

            Text(card.kind.title.uppercased())
                .font(Font.system(size: 13, weight: .heavy, design: .rounded))
                .kerning(2.8)
                .foregroundStyle(tint)

            Text(card.text)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .glassPanel(cornerRadius: 24)
        .neonEdge(tint, cornerRadius: 24, intensity: 0.7)
        .id(card.id)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(AppAnimation.standard, value: card.id)
    }

    private var resolveControls: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "Gemacht", systemImage: "checkmark") {
                HapticManager.success()
                SoundManager.play(.ballsBack)
                withAnimation(AppAnimation.standard) { current = nil }
            }

            Button {
                refuse()
            } label: {
                Text("Verweigern – \(TruthOrDareDeck.refusalSips) Schlücke")
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

    private func refusalOverlay(sips: Int) -> some View {
        ZStack {
            BeerStatsColor.backgroundPrimary.opacity(0.93)
            RadialGradient(
                colors: [BeerStatsColor.error.opacity(0.4), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            VStack(spacing: 14) {
                Text("🍺").font(.system(size: 90))
                Text("\(sips) SCHLÜCKE")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .kerning(3)
                    .foregroundStyle(BeerStatsColor.error)
            }
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
        SoundManager.play(.tap)
    }

    private func refuse() {
        refusalTask?.cancel()
        HapticManager.error()
        SoundManager.play(.bombe)
        withAnimation(AppAnimation.standard) { refusal = TruthOrDareDeck.refusalSips }

        refusalTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            guard !Task.isCancelled else { return }
            endRefusal()
        }
    }

    private func endRefusal() {
        refusalTask?.cancel()
        withAnimation(AppAnimation.smoothFade) {
            refusal = nil
            current = nil
        }
    }
}
