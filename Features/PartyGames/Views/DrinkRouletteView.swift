//
//  DrinkRouletteView.swift
//  BeerStats
//
//  Ein Rad mit acht Feldern: drehen, warten, trinken.
//
//  Die alte Fassung liess Namen eintippen und war danach nur ein
//  Zufallsgenerator. Beides ist weg. Wer trinkt, entscheidet jetzt das Feld
//  selbst – ueber die Sitzordnung ("dein linker Nachbar") oder ueber die
//  Runde ("wer zuletzt gelacht hat"). Damit gibt es keine Einrichtung mehr:
//  aufmachen, drehen.
//
//  Das Zielfeld wird VOR der Drehung ausgelost und die noetige Umdrehung
//  daraus berechnet. Andersherum – drehen und hinterher ablesen, wo der
//  Zeiger steht – haengt das Ergebnis an Rundungsfehlern im Winkel.
//

import SwiftUI

struct DrinkRouletteView: View {

    private struct Wedge: Identifiable {
        let id = UUID()
        /// Kurzform auf dem Rad. Alles Längere ist bei acht Feldern nicht
        /// mehr lesbar.
        let label: String
        let format: String
        var amount: DrinkAmount?
        let color: Color

        var resolved: String {
            guard let amount else { return format }
            return format.replacingOccurrences(of: "{}", with: amount.text)
        }
    }

    private static let wedges: [Wedge] = [
        Wedge(label: "Du", format: "Du trinkst {}", amount: .sips(3), color: BeerStatsColor.accent),
        Wedge(label: "Alle", format: "Alle trinken {}", amount: .sips(2), color: BeerStatsColor.accentSecondary),
        Wedge(label: "Verteilen", format: "Verteile {}", amount: .sips(4), color: BeerStatsColor.warning),
        Wedge(label: "Shot", format: "Du trinkst {}", amount: .shot, color: BeerStatsColor.error),
        Wedge(label: "Links", format: "Dein linker Nachbar trinkt {}", amount: .sips(3), color: BeerStatsColor.success),
        Wedge(label: "Glück", format: "Glück gehabt – niemand trinkt", amount: nil, color: BeerStatsColor.accent),
        Wedge(label: "Rechts", format: "Dein rechter Nachbar trinkt {}", amount: .sips(3), color: BeerStatsColor.accentSecondary),
        Wedge(label: "Zuletzt", format: "Wer zuletzt gelacht hat, trinkt {}", amount: .sips(3), color: BeerStatsColor.warning)
    ]

    private static let spinDuration: Double = 3.0
    private static let fullTurns: Double = 4

    @State private var rotation: Double = 0
    @State private var result: Wedge?
    @State private var isSpinning = false
    @State private var spinTask: Task<Void, Never>?

    private var step: Double { 360.0 / Double(Self.wedges.count) }

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.error)

            VStack(spacing: 22) {
                wheel
                resultPanel
                Spacer(minLength: 0)
                PrimaryButton(
                    title: isSpinning ? "Dreht …" : "Drehen",
                    systemImage: "arrow.triangle.2.circlepath"
                ) { spin() }
                .disabled(isSpinning)
                .opacity(isSpinning ? 0.5 : 1)
            }
            .padding(24)
        }
        .navigationTitle("Trink-Roulette")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { spinTask?.cancel() }
    }

    // MARK: - Rad

    private var wheel: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                ZStack {
                    ForEach(Array(Self.wedges.enumerated()), id: \.element.id) { index, wedge in
                        PieSlice(index: index, total: Self.wedges.count)
                            .fill(wedge.color.opacity(0.85))

                        PieSlice(index: index, total: Self.wedges.count)
                            .stroke(BeerStatsColor.backgroundPrimary.opacity(0.6), lineWidth: 2)

                        Text(wedge.label)
                            .font(.system(size: size * 0.055, weight: .heavy, design: .rounded))
                            .foregroundStyle(BeerStatsColor.textOnAccent)
                            // Erst nach außen schieben, dann um die Mitte
                            // drehen – in dieser Reihenfolge landet die
                            // Beschriftung mittig auf ihrem Feld.
                            .offset(y: -size * 0.32)
                            .rotationEffect(.degrees(Double(index) * step + step / 2))
                    }
                }
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation))

                Circle()
                    .fill(BeerStatsColor.backgroundPrimary)
                    .frame(width: size * 0.22, height: size * 0.22)
                    .overlay(
                        Circle().strokeBorder(BeerStatsColor.accent.opacity(0.6), lineWidth: 2)
                    )

                // Zeiger oben, fest stehend.
                Triangle()
                    .fill(BeerStatsColor.textPrimary)
                    .frame(width: size * 0.08, height: size * 0.07)
                    .offset(y: -size * 0.5)
                    .shadow(color: .black.opacity(0.6), radius: 4)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(height: 300)
    }

    @ViewBuilder
    private var resultPanel: some View {
        if let result, !isSpinning {
            Text(result.resolved)
                .font(.scaled(24, weight: .bold, design: .rounded))
                .foregroundStyle(result.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(18)
                .glassPanel(cornerRadius: 20)
                .neonEdge(result.color, cornerRadius: 20, intensity: 0.8)
                .transition(.scale.combined(with: .opacity))
        } else {
            Text("Reihum drehen. Was der Zeiger trifft, gilt.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .frame(height: 62)
        }
    }

    // MARK: - Ablauf

    private func spin() {
        guard !isSpinning else { return }
        spinTask?.cancel()
        isSpinning = true
        withAnimation(AppAnimation.smoothFade) { result = nil }

        // Ziel zuerst auslosen, Drehung daraus berechnen.
        let target = Int.random(in: 0..<Self.wedges.count)
        let targetCenter = Double(target) * step + step / 2
        let current = rotation.truncatingRemainder(dividingBy: 360)
        var delta = (360 - targetCenter - current).truncatingRemainder(dividingBy: 360)
        if delta < 0 { delta += 360 }

        withAnimation(.easeOut(duration: Self.spinDuration)) {
            rotation += Self.fullTurns * 360 + delta
        }

        spinTask = Task { @MainActor in
            // Das Ticken wird langsamer, passend zum Auslaufen des Rades.
            var elapsed: Double = 0
            var interval: Double = 0.07

            while elapsed < Self.spinDuration, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                elapsed += interval
                interval *= 1.22
                HapticManager.lightImpact()
                SoundManager.play(.tap)
            }

            guard !Task.isCancelled else { return }
            withAnimation(AppAnimation.standard) {
                result = Self.wedges[target]
                isSpinning = false
            }
            HapticManager.error()
            SoundManager.play(.bombe)
        }
    }
}

// MARK: - Formen

/// Ein Tortenstück, gemessen ab oben und im Uhrzeigersinn.
private struct PieSlice: Shape {
    let index: Int
    let total: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let step = 360.0 / Double(total)

        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(Double(index) * step - 90),
            endAngle: .degrees(Double(index + 1) * step - 90),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

/// Zeiger über dem Rad, Spitze nach unten.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
