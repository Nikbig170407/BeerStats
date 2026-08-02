//
//  DrinkRouletteView.swift
//  BeerStats
//
//  Namen eintragen, drehen, jemand trinkt.
//
//  Zwei Entscheidungen: Der Zeiger laeuft sichtbar aus, statt das Ergebnis
//  sofort zu zeigen – das Auslaufen ist das halbe Spiel. Und ausgelost wird
//  Person UND Aufgabe, sonst ist es nach der dritten Runde immer dasselbe.
//
//  Die Namen leben nur in dieser Ansicht und landen bewusst nicht bei den
//  Beerpong-Profilen: Wer hier mitspielt, hat damit keine Wurfstatistik.
//

import SwiftUI

struct DrinkRouletteView: View {

    @State private var names: [String] = []
    @State private var draft = ""
    @State private var selected: Int?
    @State private var task: String?
    @State private var isSpinning = false
    @State private var spinTask: Task<Void, Never>?

    /// Aufgaben bewusst in derselben Groessenordnung wie die Strafen bei
    /// "Ich hab noch nie" – ein Roulette, das reihenweise Shots verteilt,
    /// beendet den Abend statt ihn zu tragen.
    private static let tasks = [
        "trinkt 3 Schlücke",
        "trinkt 5 Schlücke",
        "trinkt einen Shot",
        "verteilt 5 Schlücke",
        "trinkt 2 Schlücke und verteilt 2",
        "sucht jemanden aus, der einen Shot trinkt",
        "trinkt so viele Schlücke, wie die Runde Leute hat",
        "darf einmal aussetzen – alle anderen trinken 2",
        "trinkt 4 Schlücke",
        "stellt eine Frage, wer nicht antwortet trinkt"
    ]

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.error)

            VStack(spacing: 20) {
                if names.count < 2 {
                    setup
                } else {
                    wheel
                    Spacer(minLength: 0)
                    controls
                }
            }
            .padding(24)
        }
        .navigationTitle("Trink-Roulette")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { spinTask?.cancel() }
    }

    // MARK: - Namen sammeln

    private var setup: some View {
        VStack(spacing: 16) {
            Text("🎯").font(.system(size: 56))

            Text("Wer spielt mit?")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Mindestens zwei Namen. Sie gelten nur für diese Runde.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                TextField("Name", text: $draft)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .glassPanel(cornerRadius: 14)
                    .submitLabel(.done)
                    .onSubmit { addName() }

                Button {
                    addName()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(BeerStatsColor.textOnAccent)
                        .frame(width: 50, height: 50)
                        .background(BeerStatsColor.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(trimmedDraft.isEmpty)
                .opacity(trimmedDraft.isEmpty ? 0.4 : 1)
            }

            nameChips

            Spacer(minLength: 0)
        }
    }

    private var nameChips: some View {
        VStack(spacing: 8) {
            ForEach(Array(names.enumerated()), id: \.offset) { position, name in
                HStack {
                    Text(name)
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                    Spacer()
                    Button {
                        names.remove(at: position)
                        HapticManager.lightImpact()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(BeerStatsColor.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassPanel(cornerRadius: 14)
            }
        }
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addName() {
        let name = trimmedDraft
        guard !name.isEmpty, names.count < 12 else { return }
        names.append(name)
        draft = ""
        HapticManager.lightImpact()
    }

    // MARK: - Rad

    private var wheel: some View {
        VStack(spacing: 18) {
            Text("🎯")
                .font(.system(size: 44))
                .scaleEffect(isSpinning ? 1.12 : 1)
                .animation(.easeInOut(duration: 0.18), value: isSpinning)

            VStack(spacing: 10) {
                ForEach(Array(names.enumerated()), id: \.offset) { position, name in
                    let isHit = selected == position
                    Text(name)
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(isHit ? BeerStatsColor.textOnAccent : BeerStatsColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            isHit ? BeerStatsColor.error : Color.clear,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    isHit ? BeerStatsColor.error : BeerStatsColor.textSecondary.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                }
            }

            if !isSpinning, let selected, let task, names.indices.contains(selected) {
                Text("\(names[selected]) \(task)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(BeerStatsColor.error)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: isSpinning ? "Dreht …" : "Drehen", systemImage: "arrow.triangle.2.circlepath") {
                spin()
            }
            .disabled(isSpinning)
            .opacity(isSpinning ? 0.5 : 1)

            Button("Namen ändern") {
                spinTask?.cancel()
                isSpinning = false
                selected = nil
                task = nil
                names.removeAll()
            }
            .font(BeerStatsFont.caption)
            .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    /// Der Zeiger springt schnell und wird langsamer, statt das Ergebnis
    /// sofort zu setzen. Ohne dieses Auslaufen ist es nur ein Zufallsgenerator.
    private func spin() {
        spinTask?.cancel()
        isSpinning = true
        task = nil

        spinTask = Task { @MainActor in
            var interval = 0.05
            var position = Int.random(in: names.indices)

            while interval < 0.34, !Task.isCancelled {
                position = (position + 1) % names.count
                selected = position
                HapticManager.lightImpact()
                SoundManager.play(.tap)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                interval *= 1.16
            }

            guard !Task.isCancelled else { return }
            withAnimation(AppAnimation.standard) {
                task = Self.tasks.randomElement()
                isSpinning = false
            }
            HapticManager.error()
            SoundManager.play(.bombe)
        }
    }
}
