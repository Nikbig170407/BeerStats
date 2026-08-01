//
//  BombPassView.swift
//  BeerStats
//
//  Bombe weitergeben: Ein Zünder mit unbekannter Laufzeit tickt, das Handy
//  wandert im Kreis. Wer es hält, wenn es knallt, trinkt.
//
//  Zwei Entscheidungen bestimmen, ob das Spiel funktioniert. Erstens darf
//  die Restzeit **nicht** sichtbar sein – sichtbare Sekunden verwandeln das
//  Spiel in ein Rechenexempel, bei dem jeder kurz vor Schluss abgibt.
//  Zweitens beschleunigt das Ticken zum Ende hin: Man spürt, dass es eng
//  wird, ohne zu wissen, wie eng.
//

import SwiftUI

struct BombPassView: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: Phase = .idle
    @State private var length: Length = .medium
    @State private var pulse = false
    @State private var tickTask: Task<Void, Never>?

    private enum Phase: Equatable { case idle, running, exploded }

    /// Spanne statt fester Dauer – eine feste Länge wäre nach zwei Runden
    /// durchschaut.
    private enum Length: String, CaseIterable, Identifiable {
        case short, medium, long

        var id: String { rawValue }

        var title: String {
            switch self {
            case .short: return "Kurz"
            case .medium: return "Mittel"
            case .long: return "Lang"
            }
        }

        var range: ClosedRange<Double> {
            switch self {
            case .short: return 10...25
            case .medium: return 20...50
            case .long: return 45...90
            }
        }
    }

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.accentSecondary)

            VStack(spacing: 24) {
                header
                bomb
                Spacer(minLength: 0)
                controls
            }
            .padding(24)
        }
        .navigationTitle("Bombe")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { stop() }
    }

    // MARK: - Kopf

    private var header: some View {
        VStack(spacing: 8) {
            Text(headline)
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)

            Text(subline)
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    private var headline: String {
        switch phase {
        case .idle: return "Wer bleibt drauf sitzen?"
        case .running: return "Weitergeben!"
        case .exploded: return "BOOM"
        }
    }

    private var subline: String {
        switch phase {
        case .idle:
            return "Zünden, dann das Handy reihum weitergeben. Wer es hält, wenn es knallt, trinkt."
        case .running:
            return "Nicht zögern – die Restzeit sieht niemand."
        case .exploded:
            return "Wer sie zuletzt in der Hand hatte, ist dran."
        }
    }

    // MARK: - Bombe

    private var bomb: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: phase == .exploded
                            ? [BeerStatsColor.warning, BeerStatsColor.accentSecondary.opacity(0.2)]
                            : [BeerStatsColor.accentSecondary.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 150
                    )
                )
                .frame(width: 260, height: 260)

            Text(phase == .exploded ? "💥" : "💣")
                .font(.system(size: 116))
                .scaleEffect(pulse ? 1.12 : 1)
                .rotationEffect(.degrees(pulse ? 3 : -3))
        }
        .frame(height: 260)
        .animation(.easeInOut(duration: 0.18), value: pulse)
        .animation(AppAnimation.standard, value: phase)
    }

    // MARK: - Bedienung

    private var controls: some View {
        VStack(spacing: 14) {
            if phase == .idle {
                Picker("Länge", selection: $length) {
                    ForEach(Length.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                PrimaryButton(title: "Zünden", systemImage: "flame.fill") { start() }
            } else if phase == .running {
                Button {
                    stop()
                    phase = .idle
                } label: {
                    Text("Abbrechen")
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .glassPanel(cornerRadius: 16)
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
            } else {
                PrimaryButton(title: "Nochmal", systemImage: "arrow.counterclockwise") { start() }
            }
        }
    }

    // MARK: - Ablauf

    private func start() {
        stop()
        phase = .running
        let total = Double.random(in: length.range)

        tickTask = Task { @MainActor in
            var elapsed: Double = 0

            while elapsed < total, !Task.isCancelled {
                // Der Abstand schrumpft von knapp einer Sekunde auf ein
                // Fünftel – das ist die eigentliche Spannungskurve.
                let progress = elapsed / total
                let interval = 0.9 - 0.7 * progress

                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { return }

                elapsed += interval
                if !reduceMotion { pulse.toggle() }
                HapticManager.lightImpact()
                SoundManager.play(.tap)
            }

            guard !Task.isCancelled else { return }
            explode()
        }
    }

    private func explode() {
        phase = .exploded
        pulse = false
        HapticManager.error()
        SoundManager.play(.bombe)
        SpeechAnnouncer.announce("Boom")
    }

    private func stop() {
        tickTask?.cancel()
        tickTask = nil
        pulse = false
    }
}
