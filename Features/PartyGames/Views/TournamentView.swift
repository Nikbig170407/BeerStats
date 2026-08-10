//
//  TournamentView.swift
//  BeerStats
//
//  Mehrere Spiele hintereinander als Turnier.
//
//  Der Grund fuer diesen Modus ist nicht, dass ein zwanzigstes Spiel fehlt,
//  sondern das Gegenteil: Neunzehn stehen da, und eine Runde spielt zwei
//  davon. Das Turnier zwingt die App, ihre eigene Breite auszuspielen –
//  es macht die bestehenden Spiele wertvoller, statt neue zu bauen.
//
//  Die Strafe steigt mit jeder Runde, wie bei Schlag den Raab. Das ist der
//  ganze Trick des Formats: Ein Rueckstand ist nie endgueltig, und niemand
//  steigt gedanklich aus. Bei gleichbleibender Strafe waere nach der
//  dritten Runde klar, wie es ausgeht.
//
//  Gezaehlt wird mit Spielernummern, wie ueberall sonst auch. Die
//  Reihenfolge am Tisch nummeriert die Runde von selbst, und niemand muss
//  Namen eintippen.
//

import SwiftUI

struct TournamentView: View {

    private enum Phase: Equatable {
        case setup
        /// Runde `index` steht an, das Spiel wurde noch nicht gespielt.
        case announce(index: Int)
        /// Zurueck aus dem Spiel – wer hat verloren?
        case scoring(index: Int)
        case finished
    }

    @State private var playerCount = 4
    @State private var roundCount = 5
    @State private var games: [PartyGame] = []
    @State private var strikes: [Int] = []
    @State private var phase: Phase = .setup

    private let roundOptions = [3, 5, 7]

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.warning)

            ScrollView {
                VStack(spacing: 20) {
                    switch phase {
                    case .setup: setupView
                    case .announce(let index): announceView(index)
                    case .scoring(let index): scoringView(index)
                    case .finished: finishedView
                    }
                }
                .padding(22)
            }
        }
        .navigationTitle("Turnier")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Vorbereitung

    private var setupView: some View {
        VStack(spacing: 18) {
            Text("🏆").font(.system(size: 56))

            Text("Turnier")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Die App lost Spiele aus. Wer eine Runde verliert, trinkt – und je später die Runde, desto teurer.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Text("SPIELER")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                PlayerCountStepper(count: $playerCount, range: 2...12, tint: BeerStatsColor.warning)

                Text("RUNDEN")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .padding(.top, 6)

                HStack(spacing: 8) {
                    ForEach(roundOptions, id: \.self) { option in
                        Button {
                            roundCount = option
                            HapticManager.lightImpact()
                        } label: {
                            Text("\(option)")
                                .font(BeerStatsFont.headline)
                                .foregroundStyle(
                                    roundCount == option
                                        ? BeerStatsColor.textOnAccent
                                        : BeerStatsColor.textSecondary
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    roundCount == option
                                        ? BeerStatsColor.warning
                                        : BeerStatsColor.surfaceElevated.opacity(0.6),
                                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }

            PrimaryButton(title: "Spiele auslosen", systemImage: "shuffle") { start() }
        }
    }

    // MARK: - Runde ankündigen

    private func announceView(_ index: Int) -> some View {
        let game = games[index]

        return VStack(spacing: 18) {
            standings

            VStack(spacing: 12) {
                Text("RUNDE \(index + 1) VON \(games.count)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .kerning(2)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                Text(game.emoji).font(.system(size: 52))

                Text(game.title)
                    .font(BeerStatsFont.title)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(game.subtitle)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Verlieren kostet \(penalty(for: index).text)")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.warning)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(22)
            .glassPanel(cornerRadius: 22)
            .neonEdge(game.tint, cornerRadius: 22, intensity: 0.7)

            // Nach dem Spiel landet man wieder hier – deshalb geht es von
            // dort aus weiter zur Wertung und nicht direkt zur nächsten Runde.
            NavigationLink {
                game.destination
            } label: {
                Text("Spielen")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(BeerStatsColor.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())

            Button("Gespielt – jetzt werten") {
                withAnimation(AppAnimation.standard) { phase = .scoring(index: index) }
                HapticManager.lightImpact()
            }
            .font(BeerStatsFont.caption)
            .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    // MARK: - Wertung

    private func scoringView(_ index: Int) -> some View {
        VStack(spacing: 16) {
            Text("😬").font(.system(size: 48))

            Text("Wer hat \(games[index].title) verloren?")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Trinkt \(penalty(for: index).text) und bekommt einen Strich.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)

            VStack(spacing: 8) {
                ForEach(0..<playerCount, id: \.self) { player in
                    Button {
                        record(loser: player, round: index)
                    } label: {
                        HStack {
                            Text("Spieler \(player + 1)")
                                .font(BeerStatsFont.headline)
                                .foregroundStyle(BeerStatsColor.textPrimary)
                            Spacer()
                            if strikes[player] > 0 {
                                Text(String(repeating: "×", count: strikes[player]))
                                    .font(BeerStatsFont.caption)
                                    .foregroundStyle(BeerStatsColor.error)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .glassPanel(cornerRadius: 15)
                        .neonEdge(BeerStatsColor.error, cornerRadius: 15, intensity: 0.25)
                        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }

            // Nicht jede Runde geht auf: Bei manchen Spielen verliert
            // niemand eindeutig, und dann soll man weiterkommen, ohne
            // jemandem einen Strich anzuhängen.
            Button("Unentschieden – überspringen") {
                advance(after: index)
            }
            .font(BeerStatsFont.caption)
            .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    // MARK: - Ergebnis

    private var finishedView: some View {
        let worst = strikes.max() ?? 0
        let losers = strikes.indices.filter { strikes[$0] == worst && worst > 0 }

        return VStack(spacing: 18) {
            Text("🏆").font(.system(size: 56))

            Text("Turnier vorbei")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            standings

            if losers.isEmpty {
                Text("Keine Striche verteilt – ihr seid euch alle einig gewesen.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(losers.count == 1
                     ? "Spieler \(losers[0] + 1) hat am häufigsten verloren"
                     : "Gleichstand: \(losers.map { "Spieler \($0 + 1)" }.joined(separator: ", "))")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Zum Abschluss \(DrinkAmount.shot.text)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(BeerStatsColor.error)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .glassPanel(cornerRadius: 18)
                    .neonEdge(BeerStatsColor.error, cornerRadius: 18, intensity: 0.7)
            }

            PrimaryButton(title: "Neues Turnier", systemImage: "arrow.counterclockwise") {
                withAnimation(AppAnimation.standard) { phase = .setup }
            }
        }
    }

    private var standings: some View {
        VStack(spacing: 6) {
            ForEach(0..<playerCount, id: \.self) { player in
                HStack {
                    Text("Spieler \(player + 1)")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                    Spacer()
                    Text(strikes.indices.contains(player) && strikes[player] > 0
                         ? String(repeating: "×", count: strikes[player])
                         : "–")
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(
                            strikes.indices.contains(player) && strikes[player] > 0
                                ? BeerStatsColor.error
                                : BeerStatsColor.textSecondary
                        )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassPanel(cornerRadius: 12)
            }
        }
    }

    // MARK: - Ablauf

    /// Runde 1 kostet einen Schluck, Runde 5 fünf. Erst dadurch entscheidet
    /// sich ein Turnier hinten und nicht vorne.
    private func penalty(for index: Int) -> DrinkAmount {
        .sips(index + 1)
    }

    private func start() {
        let pool = PartyGame.allCases.filter(\.isTournamentReady).shuffled()
        // Weniger geeignete Spiele als Runden gibt es nicht – aber falls doch,
        // lieber ein kürzeres Turnier als ein doppeltes Spiel.
        games = Array(pool.prefix(roundCount))
        strikes = Array(repeating: 0, count: playerCount)
        withAnimation(AppAnimation.standard) { phase = .announce(index: 0) }
        HapticManager.success()
        SoundManager.play(.victory)
    }

    private func record(loser: Int, round: Int) {
        strikes[loser] += 1
        HapticManager.error()
        SoundManager.play(.bombe)
        advance(after: round)
    }

    private func advance(after round: Int) {
        withAnimation(AppAnimation.standard) {
            phase = round + 1 < games.count ? .announce(index: round + 1) : .finished
        }
    }
}
