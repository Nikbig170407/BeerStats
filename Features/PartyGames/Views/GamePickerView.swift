//
//  GamePickerView.swift
//  BeerStats
//
//  "Was spielen wir?" – der Wuerfel ueber die Spiele.
//
//  Zweiundzwanzig Spiele sind viele. Am Tisch heisst das nicht, dass man
//  die Auswahl geniesst, sondern dass fuenf Minuten lang diskutiert wird,
//  waehrend niemand spielt. Ein Knopf, der eines auslost, beendet das.
//
//  Nicht zu verwechseln mit "Zuletzt gespielt", das im Oktober wieder
//  rausgeflogen ist: Das war eine Liste, die sich bei jedem Aufmachen
//  anders sortierte und die festen Ordner nach unten schob. Der Wuerfel
//  liegt immer an derselben Stelle und verspricht nichts – er hat genau
//  ein Ergebnis, und das darf man wegwerfen.
//
//  Gelost wird aus dem, was zur Runde PASST: Die Spielerzahl ist eine
//  echte Bedingung, keine Empfehlung. Ein ausgelostes "Der Spion" zu
//  zweit waere kein Vorschlag, sondern ein Fehler.
//

import SwiftUI

struct GamePickerView: View {

    @Environment(\.tablePlayers) private var tablePlayers

    private enum Phase: Equatable { case setup, rolling, drawn }

    /// Die Dauer als Filter – mit "egal" als eigenem Fall, damit die
    /// Auswahl ohne Optional auskommt.
    private enum LengthFilter: Hashable, CaseIterable {
        case any, quick, round, long

        var length: PartyGame.Length? {
            switch self {
            case .any: return nil
            case .quick: return .quick
            case .round: return .round
            case .long: return .long
            }
        }

        var title: String {
            switch self {
            case .any: return "Egal"
            case .quick: return "Kurz"
            case .round: return "Mittel"
            case .long: return "Lang"
            }
        }

        var detail: String? {
            switch self {
            case .any: return nil
            case .quick: return "2 Min."
            case .round: return "10 Min."
            case .long: return "länger"
            }
        }
    }

    @State private var phase: Phase = .setup
    @State private var playerCount = 4
    @State private var filter: LengthFilter = .any
    @State private var game: PartyGame?
    @State private var rollTask: Task<Void, Never>?

    private var passende: [PartyGame] {
        PartyGame.fitting(players: playerCount, length: filter.length)
    }

    var body: some View {
        Group {
            switch phase {
            case .setup: setupView
            case .rolling, .drawn: resultView
            }
        }
        .navigationTitle("Was spielen wir?")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: adoptTableCount)
        .onDisappear { rollTask?.cancel() }
    }

    // MARK: - Vorbereitung

    private var setupView: some View {
        GameSetupScreen(
            emoji: "🎲",
            title: "Was spielen wir?",
            subtitle: "Die App sucht ein Spiel aus, das zu eurer Runde passt.",
            tint: BeerStatsColor.accent,
            startTitle: "Auslosen",
            isStartDisabled: passende.isEmpty,
            onStart: roll
        ) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    label("WIE VIELE SPIELT IHR?")
                    PlayerCountStepper(count: $playerCount, range: 2...PartyGame.manyPlayers, tint: BeerStatsColor.accent)
                }

                VStack(alignment: .leading, spacing: 10) {
                    label("WIE LANGE?")
                    ChoiceRow(
                        options: LengthFilter.allCases.map {
                            ChoiceOption(value: $0, title: $0.title, detail: $0.detail)
                        },
                        selection: $filter,
                        tint: BeerStatsColor.accent
                    )
                }

                Text(auswahlHinweis)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(passende.isEmpty ? BeerStatsColor.error : BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.scaled(11, weight: .heavy, design: .rounded))
            .kerning(1.8)
            .foregroundStyle(BeerStatsColor.textSecondary)
    }

    /// Sagt, woraus gelost wird – und wenn nichts passt, warum.
    private var auswahlHinweis: String {
        guard !passende.isEmpty else {
            return "Dazu passt gerade nichts. Mit dieser Spielerzahl gibt es keine Runde in dieser Länge – nimm „Egal“."
        }
        let wort = passende.count == 1 ? "Spiel" : "Spiele"
        return "\(passende.count) \(wort) kommen in Frage. Was nebenher läuft – Trinkbingo, verbotene Wörter, die Regel des Abends – ist nicht dabei: Das begleitet den Abend, statt eine Runde zu sein."
    }

    // MARK: - Das Ergebnis

    private var resultView: some View {
        ZStack {
            AmbientBackdrop(glow: game?.tint ?? BeerStatsColor.accent)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 16) {
                        if let game { card(game) } else { Spacer(minLength: 0) }

                        Spacer(minLength: 8)

                        if phase == .drawn, let game {
                            NavigationLink {
                                // Dasselbe wie an der Spielkachel: vermerkt
                                // wird beim Erscheinen, nicht beim Antippen.
                                game.destination
                                    .onAppear { EveningLog.record(partyGame: game) }
                            } label: {
                                PrimaryButtonLabel(title: "Los geht's", systemImage: "play.fill")
                            }
                            .buttonStyle(PressableButtonStyle())

                            QuietButton(title: "Nochmal würfeln") { roll() }
                            QuietButton(title: "Anders einstellen") {
                                withAnimation(AppAnimation.standard) { phase = .setup }
                            }
                        }
                    }
                    .padding(24)
                    .frame(minHeight: geometry.size.height)
                }
                .verticalScrollOnly()
            }
        }
    }

    private func card(_ game: PartyGame) -> some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            Text(game.emoji)
                .font(.system(size: 64))
                // Waehrend des Wuerfelns wechselt nur der Inhalt, nicht die
                // Groesse – sonst huepft die Karte.
                .animation(nil, value: game)

            Text(game.title)
                .font(.scaled(30, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(game.subtitle)
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(game.length.label) · \(game.playersLabel)")
                .font(.scaled(12, weight: .heavy, design: .rounded))
                .foregroundStyle(game.tint)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .glassPanel(cornerRadius: 24)
        .neonEdge(game.tint, cornerRadius: 24, intensity: phase == .drawn ? 0.8 : 0.3)
    }

    // MARK: - Ablauf

    /// Wer heute am Tisch steht, ist die beste Vorgabe – meistens stimmt
    /// sie schon.
    private func adoptTableCount() {
        guard phase == .setup, tablePlayers.count >= 2 else { return }
        playerCount = min(tablePlayers.count, PartyGame.manyPlayers)
    }

    /// Kurz durchblättern, dann stehen bleiben.
    ///
    /// Eine halbe Sekunde, nicht drei: Das Blättern soll zeigen, dass
    /// wirklich gelost wird – warten will darauf niemand.
    private func roll() {
        rollTask?.cancel()
        guard !passende.isEmpty else { return }

        let vorher = game
        withAnimation(AppAnimation.standard) { phase = .rolling }
        HapticManager.lightImpact()

        rollTask = Task { @MainActor in
            for _ in 0..<6 {
                game = passende.randomElement()
                SoundManager.play(.tap)
                try? await Task.sleep(nanoseconds: 90_000_000)
                guard !Task.isCancelled else { return }
            }

            game = PartyGame.draw(
                players: playerCount,
                length: filter.length,
                excluding: vorher
            ) ?? passende.randomElement()

            withAnimation(AppAnimation.standard) { phase = .drawn }
            HapticManager.success()
            SoundManager.play(.victory)
        }
    }
}
