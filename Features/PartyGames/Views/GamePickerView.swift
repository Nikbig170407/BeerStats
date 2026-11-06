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

    @State private var phase: Phase = .setup
    @State private var playerCount = 4
    @State private var game: PartyGame?
    @State private var rollTask: Task<Void, Never>?

    private var passende: [PartyGame] {
        PartyGame.fitting(players: playerCount)
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
        // Kein Spiel, aber ein eigener Ort: die Abfahrtstafel
        .environment(\.gameWorld, .departureBoard)
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

                // Nach der Dauer wird nicht mehr gefragt (6. November:
                // "schreib nicht dazu, wie lange die Spiele dauern")

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
            return "Dazu passt gerade nichts."
        }
        let wort = passende.count == 1 ? "Spiel" : "Spiele"
        return "\(passende.count) \(wort) kommen in Frage."
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

    /// Das Ergebnis als Abfahrtstafel: Der Spielname klappert auf
    /// Fallblaettern durch und bleibt stehen, darunter Dauer und Spieler.
    ///
    /// Die Schrift kommt direkt aus der Welt und nicht aus der Umgebung:
    /// Die Welt setzt diese Ansicht selbst, fuer ihre Kinder – hier oben
    /// gilt sie noch nicht.
    private func card(_ game: PartyGame) -> some View {
        let tafel = GameWorld.departureBoard

        return VStack(spacing: 14) {
            Spacer(minLength: 0)

            HStack {
                Text("ABFAHRT")
                    .font(tafel.font(13, weight: .bold))
                    .kerning(3)
                    .foregroundStyle(Color.white.opacity(0.8))
                Spacer()
                Text(Date(), style: .time)
                    .font(tafel.font(13, weight: .bold))
                    .foregroundStyle(DepartureBoard.yellow)
            }

            HStack(spacing: 10) {
                Text(game.emoji)
                    .font(.system(size: 30))
                    // Waehrend des Wuerfelns wechselt nur der Inhalt, nicht
                    // die Groesse – sonst huepft die Karte.
                    .animation(nil, value: game)
                Text("SPIEL")
                    .font(tafel.font(11, weight: .semibold))
                    .kerning(2)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                Spacer(minLength: 0)
            }

            SplitFlapText(text: game.title)

            VStack(spacing: 4) {
                Text("SPIELER")
                    .font(tafel.font(11, weight: .semibold))
                    .kerning(2)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                Text(game.playersLabel.uppercased())
                    .font(tafel.font(17, weight: .heavy))
                    .foregroundStyle(DepartureBoard.yellow)
            }

            Text(game.subtitle)
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .background(DepartureBoard.housing, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(DepartureBoard.rim, lineWidth: 2)
        )
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

            game = PartyGame.draw(players: playerCount, excluding: vorher)
                ?? passende.randomElement()

            withAnimation(AppAnimation.standard) { phase = .drawn }
            HapticManager.success()
            SoundManager.play(.roundWon)
        }
    }
}
