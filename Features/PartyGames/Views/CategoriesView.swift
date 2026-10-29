//
//  CategoriesView.swift
//  BeerStats
//
//  Kategorien: Eine Kategorie steht auf dem Tisch, reihum nennt jeder einen
//  Begriff und tippt weiter. Wer die Zeit reissen laesst, trinkt.
//
//  Der Kern ist, dass die Zeit mit jeder Runde knapper wird. Bei fester
//  Bedenkzeit gewinnt, wer die groesste Sammlung im Kopf hat, und die
//  Runde plaetschert. Mit schrumpfender Zeit endet jede Kategorie
//  zwangslaeufig – und zwar spuerbar naeher kommend.
//
//  Das Handy bleibt liegen und wird nicht weitergereicht: Wer gerade dran
//  ist, tippt einmal. Weiterreichen kostet bei zwei Sekunden Bedenkzeit
//  mehr Zeit als das Nachdenken.
//

import SwiftUI

struct CategoriesView: View {

    private enum Phase: Equatable { case ready, running, lost }

    @State private var category = CategoryDeck.next(after: nil)
    @State private var phase: Phase = .ready
    @State private var remaining: Double = 0
    @State private var turnLimit: Double = Self.startLimit
    @State private var turns = 0
    @State private var tickTask: Task<Void, Never>?
    /// Jedes "Gesagt" dreht die Sanduhr einmal um.
    @State private var flips = 0

    @Environment(\.gameWorld) private var world

    /// Erste Bedenkzeit und wie schnell sie schrumpft. Die Untergrenze ist
    /// bewusst nicht null: Unter zwei Sekunden gewinnt nur noch, wer den
    /// Daumen schon auf dem Knopf hat.
    private static let startLimit: Double = 6
    private static let step: Double = 0.25
    private static let minimumLimit: Double = 2

    private let penalty = DrinkAmount.sips(3)

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.warning)

            VStack(spacing: 22) {
                // Dieselbe Zahl zaehlt hier zwei Dinge: die Runde (daran
                // haengt die Bedenkzeit) und wer dran ist. Das geht auf,
                // weil eine Runde eine Person ist.
                TurnRow(turn: turns, tint: BeerStatsColor.warning)
                categoryCard
                hourglass
                Spacer(minLength: 0)
                controls
            }
            .padding(24)
        }
        .navigationTitle("Kategorien")
        .navigationBarTitleDisplayMode(.inline)
        // Nicht, solange die Sanduhr laeuft – das Blatt laege darueber
        .roundSettings(for: .categories, isAvailable: phase != .running)
        .onDisappear { tickTask?.cancel() }
    }

    // MARK: - Kategorie

    private var categoryCard: some View {
        VStack(spacing: 10) {
            Text("KATEGORIE")
                .font(Font.world(world, 13, weight: .heavy))
                .kerning(2.6)
                .foregroundStyle(BeerStatsColor.textSecondary)

            Text(category)
                .font(Font.world(world, 30, weight: .bold))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if turns > 0 {
                Text("\(turns) geschafft")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.success)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .glassPanel(cornerRadius: 22)
        .neonEdge(BeerStatsColor.warning, cornerRadius: 22, intensity: 0.6)
    }

    // MARK: - Uhr

    /// Die Sanduhr: Der Sand rieselt, solange jemand ueberlegt, und sie
    /// wird mit jeder Runde kleiner – so knapp, wie die Bedenkzeit wird.
    private var hourglass: some View {
        VStack(spacing: 4) {
            HourglassView(
                fill: phase == .lost ? 0 : Double(progress),
                scale: 0.55 + 0.45 * turnLimit / Self.startLimit,
                running: phase == .running,
                flips: flips
            )
            .frame(width: 190, height: 190)

            switch phase {
            case .ready:
                Text("Bereit")
                    .font(Font.world(world, 18, weight: .semibold))
                    .foregroundStyle(BeerStatsColor.textSecondary)
            case .running:
                Text(String(format: "%.1f Sekunden", remaining))
                    .font(Font.world(world, 20, weight: .heavy))
                    .foregroundStyle(ringColor)
                    .monospacedDigit()
            case .lost:
                Text("Abgelaufen")
                    .font(Font.world(world, 20, weight: .heavy))
                    .foregroundStyle(BeerStatsColor.error)
            }
        }
        .animation(AppAnimation.standard, value: phase)
    }

    private var progress: CGFloat {
        guard turnLimit > 0, phase == .running else { return phase == .lost ? 0 : 1 }
        return CGFloat(remaining / turnLimit)
    }

    private var ringColor: Color {
        guard phase != .lost else { return BeerStatsColor.error }
        return remaining <= 2 ? BeerStatsColor.error : BeerStatsColor.warning
    }

    // MARK: - Bedienung

    @ViewBuilder
    private var controls: some View {
        switch phase {
        case .ready:
            VStack(spacing: 10) {
                PrimaryButton(title: "Los", systemImage: "play.fill") { startTurn() }
                QuietButton(title: "Andere Kategorie") { newCategory() }
            }

        case .running:
            Button {
                nextTurn()
            } label: {
                Text("Gesagt")
                    .font(.scaled(26, weight: .heavy, design: .rounded))
                    .foregroundStyle(BeerStatsColor.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 92)
                    .background(BeerStatsColor.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())

        case .lost:
            VStack(spacing: 12) {
                Text("Zeit vorbei – trink \(penalty.text)")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.error)
                    .multilineTextAlignment(.center)
                PrimaryButton(title: "Neue Kategorie", systemImage: "arrow.right") { newCategory() }
            }
        }
    }

    // MARK: - Ablauf

    private func startTurn() {
        tickTask?.cancel()
        remaining = turnLimit
        phase = .running

        tickTask = Task { @MainActor in
            var lastWholeSecond = Int(remaining.rounded(.up))

            while remaining > 0, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled else { return }

                remaining = max(0, remaining - 0.1)

                // Nur in den letzten Sekunden ticken. Über die ganze Zeit
                // wäre es Lärm statt Druck.
                let whole = Int(remaining.rounded(.up))
                if whole != lastWholeSecond, whole <= 3, whole > 0 {
                    lastWholeSecond = whole
                    HapticManager.lightImpact()
                    SoundManager.play(.tap)
                }
            }

            guard !Task.isCancelled else { return }
            lose()
        }
    }

    private func nextTurn() {
        turns += 1
        flips += 1
        // Dieselbe Zahl zaehlt zwei Dinge: wie viele Runden gespielt sind
        // (die Bedenkzeit haengt daran) und wer dran ist. Das geht auf, weil
        // beides im selben Takt laeuft – eine Runde ist eine Person.
        // Jede Runde ein Stück knapper, bis zur Untergrenze.
        turnLimit = max(Self.minimumLimit, turnLimit - Self.step)
        HapticManager.lightImpact()
        SoundManager.play(.cupHit)
        startTurn()
    }

    private func lose() {
        tickTask?.cancel()
        withAnimation(AppAnimation.standard) { phase = .lost }
        HapticManager.error()
        SoundManager.play(.bombe)
    }

    private func newCategory() {
        tickTask?.cancel()
        category = CategoryDeck.next(after: category)
        turnLimit = Self.startLimit
        turns = 0
        remaining = 0
        withAnimation(AppAnimation.standard) { phase = .ready }
        HapticManager.success()
    }
}
