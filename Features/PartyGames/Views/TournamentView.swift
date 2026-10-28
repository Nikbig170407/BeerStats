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
//  Gezaehlt wird ueber Positionen, wie ueberall sonst auch: Die Reihenfolge
//  am Tisch nummeriert die Runde von selbst, und niemand muss Namen
//  eintippen. Laeuft ein Abend, tragen dieselben Positionen dessen Namen –
//  und jede Runde landet in der Trinkbilanz.
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

    @State private var playerCount = PlayerNames.suggestedCount() ?? 4
    @State private var roundCount = 5
    @State private var games: [PartyGame] = []
    @State private var strikes: [Int] = []
    @State private var phase: Phase = .setup

    private let roundOptions = [3, 5, 7]

    /// Die Schrift des Stadions. Direkt aus der Welt und nicht aus der
    /// Umgebung: Die Welt setzt diese Ansicht selbst, fuer ihre Kinder.
    private let stadion = GameWorld.stadium

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.warning)

            FillingScrollView {
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
        // Kein Spiel, aber ein eigener Ort: das Stadion. Die Spiele darin
        // bringen ihre eigene Welt mit (`PartyGame.destination`).
        .environment(\.gameWorld, .stadium)
        .navigationTitle("Turnier")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Vorbereitung

    private var setupView: some View {
        VStack(spacing: 18) {
            Text("TURNIER")
                .font(stadion.font(44, weight: .heavy))
                .kerning(3)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Die App lost Spiele aus. Wer eine Runde verliert, trinkt – und je später die Runde, desto teurer.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Text("SPIELER")
                    .font(.scaled(11, weight: .heavy, design: .rounded))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                PlayerCountStepper(count: $playerCount, range: 2...12, tint: BeerStatsColor.warning)

                Text("RUNDEN")
                    .font(.scaled(11, weight: .heavy, design: .rounded))
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
            scoreboard(round: index)

            PenaltyStairs(rounds: games.count, current: index)
                .id(index)

            VStack(spacing: 12) {
                Text(game.emoji).font(.system(size: 52))

                Text(game.title)
                    .font(stadion.font(28, weight: .heavy))
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

            QuietButton(title: "Gespielt – jetzt werten") {
                withAnimation(AppAnimation.standard) { phase = .scoring(index: index) }
                HapticManager.lightImpact()
            }
        }
    }

    // MARK: - Wertung

    private func scoringView(_ index: Int) -> some View {
        VStack(spacing: 16) {
            Text("Wer hat \(games[index].title) verloren?")
                .font(stadion.font(26, weight: .heavy))
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
                            Text("\(PlayerNames.name(for: player))")
                                .font(BeerStatsFont.headline)
                                .foregroundStyle(BeerStatsColor.textPrimary)
                            Spacer()
                            // Mit Bereichsprüfung, wie in der Endtabelle
                            // auch: `playerCount` und `strikes` werden an
                            // verschiedenen Stellen gesetzt, und ein Zugriff
                            // daneben ist in SwiftUI kein leeres Feld,
                            // sondern ein Absturz mitten im Abend.
                            if strikes.indices.contains(player), strikes[player] > 0 {
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
            QuietButton(title: "Unentschieden – überspringen") {
                advance(after: index)
            }
        }
    }

    // MARK: - Ergebnis

    private var finishedView: some View {
        let worst = strikes.max() ?? 0
        let losers = strikes.indices.filter { strikes[$0] == worst && worst > 0 }

        return VStack(spacing: 18) {
            Text("ENDSTAND")
                .font(stadion.font(40, weight: .heavy))
                .kerning(3)
                .foregroundStyle(BeerStatsColor.textPrimary)

            standings
                .padding(12)
                .background(StadiumArt.board, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(StadiumArt.rim, lineWidth: 3))

            if losers.isEmpty {
                Text("Keine Striche verteilt – ihr seid euch alle einig gewesen.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(losers.count == 1
                     ? "\(PlayerNames.name(for: losers[0])) hat am häufigsten verloren"
                     : "Gleichstand: \(losers.map { "\(PlayerNames.name(for: $0))" }.joined(separator: ", "))")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Zum Abschluss \(DrinkAmount.shot.text)")
                    .font(.scaled(22, weight: .bold, design: .rounded))
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

    /// Die Anzeigetafel: Runde von Runden gross, darunter die Striche je
    /// Person – in Sieben-Segment-Ziffern wie im Stadion.
    private func scoreboard(round index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text("RUNDE")
                    .font(stadion.font(15, weight: .heavy))
                    .kerning(3)
                    .foregroundStyle(Color.white.opacity(0.8))
                Spacer(minLength: 0)
                SevenSegmentNumber(value: index + 1, height: 54)
                Text("/")
                    .font(stadion.font(36, weight: .light))
                    .foregroundStyle(StadiumArt.red.opacity(0.6))
                SevenSegmentNumber(value: games.count, height: 54)
            }
            standings
        }
        .padding(16)
        .background(StadiumArt.board, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(StadiumArt.rim, lineWidth: 3))
    }

    private var standings: some View {
        VStack(spacing: 6) {
            ForEach(0..<playerCount, id: \.self) { player in
                let striche = strikes.indices.contains(player) ? strikes[player] : 0
                HStack {
                    Text(PlayerNames.plainName(for: player).uppercased())
                        .font(stadion.font(16, weight: .heavy))
                        .kerning(1)
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(1)
                    Spacer()
                    SevenSegmentNumber(value: striche, color: striche > 0 ? StadiumArt.amber : StadiumArt.idle, height: 26)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(PlayerNames.plainName(for: player)): \(striche) verloren")
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
        EveningLog.record(penalty(for: round), forPlayer: loser)
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
