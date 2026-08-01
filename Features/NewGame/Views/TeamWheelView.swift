//
//  TeamWheelView.swift
//  BeerStats
//
//  Glücksrad zur Auslosung der Aufstellung.
//
//  Das Rad ist bewusst mehr als ein Zufallsgenerator mit Animation: Der
//  Reiz beim Auslosen liegt darin, dass alle zusehen können, wie es
//  ausgeht. Deshalb wird jeder Platz einzeln gezogen, mit sichtbarem
//  Ausschlag und Haptik pro Treffer, statt alle vier auf einmal zu zeigen.
//

import SwiftUI

struct TeamWheelView: View {

    let profiles: [PlayerProfile]
    let playersPerTeam: Int
    /// Liefert die fertige Aufstellung: `[teamIndex][slot]` als Profil-ID.
    let onDraw: ([[String]]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var rotation: Double = 0
    @State private var drawn: [PlayerProfile] = []
    @State private var isSpinning = false

    private var neededPlayers: Int { playersPerTeam * 2 }
    private var isComplete: Bool { drawn.count == neededPlayers }

    /// Wer noch im Topf ist. Gezogene Spieler fallen heraus, damit niemand
    /// zweimal antritt.
    private var remaining: [PlayerProfile] {
        let drawnIds = Set(drawn.compactMap(\.id))
        return profiles.filter { profile in
            guard let id = profile.id else { return false }
            return !drawnIds.contains(id)
        }
    }

    var body: some View {
        ZStack {
            GridBackdrop()

            VStack(spacing: 18) {
                Text(isComplete ? "Aufstellung steht" : "Wer spielt mit wem?")
                    .font(BeerStatsFont.title)
                    .foregroundStyle(BeerStatsColor.textPrimary)

                Text(isComplete
                     ? "Viel Erfolg – oder viel zu trinken."
                     : "Noch \(neededPlayers - drawn.count) von \(neededPlayers) Plätzen frei")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                wheel
                    .frame(width: 260, height: 260)

                drawnLineup

                Spacer(minLength: 0)

                actions
            }
            .padding(20)
        }
        .navigationTitle("Glücksrad")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Rad

    private var wheel: some View {
        ZStack {
            // Segmente
            ForEach(Array(segmentProfiles.enumerated()), id: \.offset) { index, profile in
                WheelSegment(
                    index: index,
                    total: max(segmentProfiles.count, 1),
                    color: profile.color.color
                )
            }
            .rotationEffect(.degrees(rotation))

            Circle()
                .strokeBorder(BeerStatsColor.textSecondary.opacity(0.4), lineWidth: 3)

            // Emojis auf den Segmenten
            ForEach(Array(segmentProfiles.enumerated()), id: \.offset) { index, profile in
                Text(profile.emoji)
                    .font(.system(size: 24))
                    .offset(y: -92)
                    .rotationEffect(.degrees(segmentAngle * Double(index) + segmentAngle / 2))
            }
            .rotationEffect(.degrees(rotation))

            // Nabe
            Circle()
                .fill(BeerStatsColor.backgroundPrimary)
                .frame(width: 74, height: 74)
                .overlay(Circle().strokeBorder(BeerStatsColor.accent, lineWidth: 2))
            Text(isComplete ? "✓" : "\(remaining.count)")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.accent)

            // Zeiger
            Triangle()
                .fill(BeerStatsColor.textPrimary)
                .frame(width: 20, height: 22)
                .offset(y: -142)
                .shadow(color: .black.opacity(0.6), radius: 4)
        }
        .opacity(remaining.isEmpty && !isComplete ? 0.4 : 1)
    }

    private var segmentProfiles: [PlayerProfile] {
        remaining.isEmpty ? profiles : remaining
    }

    private var segmentAngle: Double {
        360.0 / Double(max(segmentProfiles.count, 1))
    }

    // MARK: - Ergebnis

    private var drawnLineup: some View {
        VStack(spacing: 10) {
            ForEach(0..<2, id: \.self) { teamIndex in
                let tint = teamIndex == 0 ? BeerStatsColor.accent : BeerStatsColor.accentSecondary
                HStack(spacing: 10) {
                    Text("TEAM \(teamIndex + 1)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .kerning(1.3)
                        .foregroundStyle(tint)
                        .frame(width: 62, alignment: .leading)

                    ForEach(0..<playersPerTeam, id: \.self) { slot in
                        let position = teamIndex * playersPerTeam + slot
                        if position < drawn.count {
                            HStack(spacing: 6) {
                                ProfileAvatarView(profile: drawn[position], size: 30)
                                Text(drawn[position].name)
                                    .font(BeerStatsFont.caption)
                                    .foregroundStyle(BeerStatsColor.textPrimary)
                                    .lineLimit(1)
                            }
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            Capsule()
                                .strokeBorder(
                                    tint.opacity(0.35),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                                )
                                .frame(height: 30)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassPanel(cornerRadius: 14)
                .neonEdge(tint, cornerRadius: 14, intensity: 0.3)
            }
        }
        .animation(AppAnimation.standard, value: drawn.count)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if isComplete {
                PrimaryButton(title: "Mit dieser Aufstellung spielen", systemImage: "play.fill") {
                    onDraw(assembleTeams())
                    // Zurück zur Aufstellung, wo die Auslosung jetzt steht.
                    dismiss()
                }
                Button("Nochmal auslosen") { reset() }
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            } else {
                PrimaryButton(title: isSpinning ? "Dreht…" : "Drehen", systemImage: "arrow.triangle.2.circlepath") {
                    spin()
                }
                .disabled(isSpinning || remaining.isEmpty)
                .opacity(isSpinning || remaining.isEmpty ? 0.5 : 1)
            }
        }
    }

    // MARK: - Auslosen

    private func spin() {
        guard !isSpinning, let winner = remaining.randomElement() else { return }
        isSpinning = true
        HapticManager.lightImpact()
        SoundManager.play(.reRack)

        // Mehrere volle Umdrehungen plus ein zufälliger Rest – ohne die
        // Umdrehungen sähe es aus, als würde das Rad nur zucken.
        let extraTurns = Double(Int.random(in: 3...5)) * 360
        withAnimation(.easeOut(duration: 1.6)) {
            rotation += extraTurns + Double.random(in: 0..<360)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation(AppAnimation.standard) { drawn.append(winner) }
            HapticManager.mediumImpact()
            SoundManager.play(.cupHit)
            isSpinning = false

            if drawn.count == neededPlayers {
                SoundManager.play(.victory)
                HapticManager.success()
            }
        }
    }

    private func reset() {
        withAnimation(AppAnimation.standard) { drawn.removeAll() }
        HapticManager.lightImpact()
    }

    /// Die Ziehungsreihenfolge füllt abwechselnd nicht, sondern der Reihe
    /// nach: erst Team 1 voll, dann Team 2. So sieht man beim Ziehen sofort,
    /// wer zusammengehört.
    private func assembleTeams() -> [[String]] {
        var teams: [[String]] = [[], []]
        for (position, profile) in drawn.enumerated() {
            guard let id = profile.id else { continue }
            teams[position < playersPerTeam ? 0 : 1].append(id)
        }
        return teams
    }
}

// MARK: - Formen

/// Ein Tortenstück des Rades.
private struct WheelSegment: View {
    let index: Int
    let total: Int
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width, geometry.size.height) / 2
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let angle = 360.0 / Double(total)

            Path { path in
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(angle * Double(index) - 90),
                    endAngle: .degrees(angle * Double(index + 1) - 90),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(color.opacity(0.75))
            .overlay(
                Path { path in
                    path.move(to: center)
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(angle * Double(index) - 90),
                        endAngle: .degrees(angle * Double(index + 1) - 90),
                        clockwise: false
                    )
                    path.closeSubpath()
                }
                .stroke(BeerStatsColor.backgroundPrimary.opacity(0.6), lineWidth: 1.5)
            )
        }
    }
}

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
