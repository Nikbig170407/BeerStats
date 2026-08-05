//
//  DrinkBingoView.swift
//  BeerStats
//
//  Trinkbingo: ein Blatt aus sechzehn Ereignissen, das den ganzen Abend
//  offen liegt. Passiert eines, wird es angetippt.
//
//  Ein gemeinsames Blatt fuer die ganze Runde, nicht eines pro Person.
//  Sechzehn Felder pro Kopf zu verteilen hiesse, das Handy erst reihum zu
//  schicken und danach staendig weiterzureichen – bei einem Spiel, das
//  nebenher laufen soll, ist das genau falsch. Ein Blatt in der Tischmitte
//  sehen alle, und jeder darf ankreuzen.
//
//  Getrunken wird zweimal: sofort von dem, der das Ereignis ausgeloest hat,
//  und noch einmal, wenn eine Reihe voll wird. Ohne den Sofort-Schluck
//  waere das Blatt vierzig Minuten lang folgenlos.
//

import SwiftUI

struct DrinkBingoView: View {

    private static let size = 4

    @State private var fields: [String] = BingoDeck.draw()
    @State private var marked: Set<Int> = []
    @State private var completedLines = 0
    @State private var showBingo = false
    @State private var bingoTask: Task<Void, Never>?

    private let spotPenalty = DrinkAmount.sips(1)
    private let bingoReward = DrinkAmount.sips(5)

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 6),
        count: DrinkBingoView.size
    )

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.success)

            ScrollView {
                VStack(spacing: 16) {
                    rules
                    board
                    footer
                }
                .padding(16)
            }

            if showBingo {
                bingoOverlay.zIndex(2)
            }
        }
        .navigationTitle("Trinkbingo")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { bingoTask?.cancel() }
    }

    // MARK: - Regeln

    private var rules: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Passiert eines der Felder, wird es angetippt – wer es ausgelöst hat, trinkt \(spotPenalty.text).")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textPrimary)
            Text("Wer eine Reihe vollmacht, ruft Bingo und verteilt \(bingoReward.text).")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.success)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassPanel(cornerRadius: 16)
    }

    // MARK: - Blatt

    private var board: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(fields.indices, id: \.self) { index in
                tile(index)
            }
        }
    }

    private func tile(_ index: Int) -> some View {
        let isMarked = marked.contains(index)

        return Button {
            toggle(index)
        } label: {
            Text(fields[index])
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(isMarked ? BeerStatsColor.textOnAccent : BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(4)
                .padding(5)
                .frame(maxWidth: .infinity)
                .frame(height: 78)
                .background(
                    isMarked ? BeerStatsColor.success : BeerStatsColor.surfaceElevated.opacity(0.7),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isMarked ? BeerStatsColor.success : BeerStatsColor.textSecondary.opacity(0.25),
                            lineWidth: 1
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Fuß

    private var footer: some View {
        VStack(spacing: 10) {
            Text("\(marked.count) von \(fields.count) · \(completedLines) Reihen")
                .font(BeerStatsFont.statLabel)
                .foregroundStyle(BeerStatsColor.textSecondary)

            Button("Neues Blatt") { reset() }
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    private var bingoOverlay: some View {
        ZStack {
            BeerStatsColor.backgroundPrimary.opacity(0.93)
            VStack(spacing: 14) {
                Text("🎉").font(.system(size: 84))
                Text("BINGO")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .kerning(5)
                    .foregroundStyle(BeerStatsColor.success)
                Text("Verteile \(bingoReward.text)")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { endBingo() }
        .transition(.opacity)
    }

    // MARK: - Ablauf

    private func toggle(_ index: Int) {
        if marked.contains(index) {
            marked.remove(index)
            HapticManager.lightImpact()
        } else {
            marked.insert(index)
            HapticManager.mediumImpact()
            SoundManager.play(.cupHit)
        }

        // Erst nach dem Setzen zählen, und nur melden, wenn WIRKLICH eine
        // Reihe dazugekommen ist. Sonst meldet jedes Antippen auf einer schon
        // vollen Reihe erneut Bingo.
        let lines = countLines()
        if lines > completedLines { startBingo() }
        completedLines = lines
    }

    private func countLines() -> Int {
        let n = Self.size
        var lines = 0

        for row in 0..<n {
            if (0..<n).allSatisfy({ marked.contains(row * n + $0) }) { lines += 1 }
        }
        for column in 0..<n {
            if (0..<n).allSatisfy({ marked.contains($0 * n + column) }) { lines += 1 }
        }
        if (0..<n).allSatisfy({ marked.contains($0 * n + $0) }) { lines += 1 }
        if (0..<n).allSatisfy({ marked.contains($0 * n + (n - 1 - $0)) }) { lines += 1 }

        return lines
    }

    private func startBingo() {
        bingoTask?.cancel()
        withAnimation(AppAnimation.standard) { showBingo = true }
        HapticManager.success()
        SoundManager.play(.victory)

        bingoTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            endBingo()
        }
    }

    private func endBingo() {
        bingoTask?.cancel()
        withAnimation(AppAnimation.smoothFade) { showBingo = false }
    }

    private func reset() {
        bingoTask?.cancel()
        fields = BingoDeck.draw()
        marked.removeAll()
        completedLines = 0
        showBingo = false
        HapticManager.success()
    }
}
