//
//  DrinkBingoView.swift
//  BeerStats
//
//  Trinkbingo: ein Blatt aus sechzehn Ereignissen, das den ganzen Abend
//  offen liegt. Passiert eines, wird es angetippt.
//
//  Ein gemeinsames Blatt fuer die ganze Runde, nicht eines pro Person.
//  Sechzehn Felder pro Kopf AUF DIESEM GERAET zu verteilen hiesse, das
//  Handy erst reihum zu schicken und danach staendig weiterzureichen – bei
//  einem Spiel, das nebenher laufen soll, ist das genau falsch. Ein Blatt
//  in der Tischmitte sehen alle, und jeder darf ankreuzen.
//
//  Den anderen Weg gibt es seit dem 22. Oktober trotzdem: „Blätter
//  verteilen" schickt jedem sein eigenes Blatt als BILD aufs eigene Handy
//  (`BingoHandoutView`). Das umgeht das Weiterreichen, ohne dass jemand
//  die App braucht – und das ist der Punkt, denn niemand sonst hat sie.
//
//  Getrunken wird zweimal: sofort von dem, der das Ereignis ausgeloest hat,
//  und noch einmal, wenn eine Reihe voll wird. Ohne den Sofort-Schluck
//  waere das Blatt vierzig Minuten lang folgenlos.
//

import SwiftUI

struct DrinkBingoView: View {

    private static let size = 4
    private static let tileHeight: CGFloat = 78
    private static let gap: CGFloat = 6

    @State private var fields: [String] = BingoDeck.draw()
    @State private var marked: Set<Int> = []
    @State private var completedLines = 0
    @State private var showBingo = false
    @State private var bingoTask: Task<Void, Never>?
    @State private var showsHandout = false

    private let spotPenalty = DrinkAmount.sips(1)
    private let bingoReward = DrinkAmount.sips(5)


    var body: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.success)

            FillingScrollView {
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
        .sheet(isPresented: $showsHandout) {
            BingoHandoutView(
                spotPenalty: spotPenalty.text,
                bingoReward: bingoReward.text
            )
        }
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

    /// Das Blatt als Papier: Jeder Tipp drueckt einen Stempelklecks aufs
    /// Feld, eine volle Reihe bekommt einen Filzstiftstrich. Die Kleckse
    /// bleiben – man sieht dem Blatt den Abend an.
    private var board: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ForEach(Array("BINGO"), id: \.self) { buchstabe in
                    Text(String(buchstabe))
                        .font(.scaled(34, weight: .black, design: .rounded, maximumScale: 1.2))
                        .foregroundStyle(BingoHall.red)
                }
            }
            .padding(.vertical, 8)
            .accessibilityHidden(true)

            VStack(spacing: Self.gap) {
                ForEach(0..<Self.size, id: \.self) { reihe in
                    HStack(spacing: Self.gap) {
                        ForEach(0..<Self.size, id: \.self) { spalte in
                            tile(reihe * Self.size + spalte)
                        }
                    }
                }
            }
            .overlay { strikes }
        }
        .padding(10)
        .background(BingoHall.paper, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
    }

    private func tile(_ index: Int) -> some View {
        let isMarked = marked.contains(index)

        return Button {
            toggle(index)
        } label: {
            Text(fields[index])
                .font(.scaled(10, weight: .bold, design: .rounded))
                .foregroundStyle(BingoHall.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(4)
                .padding(5)
                .frame(maxWidth: .infinity)
                .frame(height: Self.tileHeight)
                .background {
                    if isMarked { BingoDaub(seed: index) }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(BingoHall.ink.opacity(0.2), lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityValue(isMarked ? "angekreuzt" : "")
    }

    /// Je voller Reihe ein Filzstiftstrich quer hindurch.
    private var strikes: some View {
        GeometryReader { geometry in
            ForEach(fullLines, id: \.self) { linie in
                let enden = endpoints(of: linie, in: geometry.size)
                MarkerStrike(from: enden.0, to: enden.1)
            }
        }
        .allowsHitTesting(false)
    }

    /// Die vollen Reihen: erst die Zeilen, dann die Spalten, dann die
    /// beiden Diagonalen – jede mit ihrer festen Nummer.
    private var fullLines: [Int] {
        let n = Self.size
        var linien: [Int] = []
        for reihe in 0..<n where (0..<n).allSatisfy({ marked.contains(reihe * n + $0) }) {
            linien.append(reihe)
        }
        for spalte in 0..<n where (0..<n).allSatisfy({ marked.contains($0 * n + spalte) }) {
            linien.append(n + spalte)
        }
        if (0..<n).allSatisfy({ marked.contains($0 * n + $0) }) { linien.append(2 * n) }
        if (0..<n).allSatisfy({ marked.contains($0 * n + (n - 1 - $0)) }) { linien.append(2 * n + 1) }
        return linien
    }

    private func endpoints(of linie: Int, in size: CGSize) -> (CGPoint, CGPoint) {
        let n = Self.size
        let breite = (size.width - Self.gap * CGFloat(n - 1)) / CGFloat(n)
        let hoehe = Self.tileHeight

        func mitte(_ reihe: Int, _ spalte: Int) -> CGPoint {
            CGPoint(x: CGFloat(spalte) * (breite + Self.gap) + breite / 2,
                    y: CGFloat(reihe) * (hoehe + Self.gap) + hoehe / 2)
        }

        if linie < n {
            let y = mitte(linie, 0).y
            return (CGPoint(x: 8, y: y), CGPoint(x: size.width - 8, y: y))
        }
        if linie < 2 * n {
            let x = mitte(0, linie - n).x
            return (CGPoint(x: x, y: 8), CGPoint(x: x, y: size.height - 8))
        }
        if linie == 2 * n { return (mitte(0, 0), mitte(n - 1, n - 1)) }
        return (mitte(0, n - 1), mitte(n - 1, 0))
    }

    // MARK: - Fuß

    private var footer: some View {
        VStack(spacing: 10) {
            Text("\(marked.count) von \(fields.count) · \(completedLines) Reihen")
                .font(BeerStatsFont.statLabel)
                .foregroundStyle(BeerStatsColor.textSecondary)

            // Steht unter dem Blatt und nicht darueber: Erst spielt man,
            // dann merkt man, dass jeder ein eigenes haben will.
            PrimaryButton(title: "Blätter an alle verteilen", systemImage: "paperplane.fill") {
                showsHandout = true
            }

            QuietButton(title: "Neues Blatt") { reset() }
        }
    }

    private var bingoOverlay: some View {
        ZStack {
            BeerStatsColor.backgroundPrimary.opacity(0.93)
            VStack(spacing: 18) {
                BingoBadge()
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

    /// Dieselbe Rechnung wie die Striche auf dem Blatt – eine Quelle fuer
    /// beides, sonst stuende ein Strich da, ohne dass Bingo gemeldet wird.
    private func countLines() -> Int {
        fullLines.count
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
