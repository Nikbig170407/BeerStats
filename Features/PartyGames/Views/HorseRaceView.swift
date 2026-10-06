//
//  HorseRaceView.swift
//  BeerStats
//
//  Pferderennen: Die vier Asse laufen um die Wette, jeder setzt vorher auf
//  eine Farbe.
//
//  Der Aufbau bleibt liegen wie bei Ring of Fire, aber er schrumpft nicht –
//  er waechst. Man sieht die ganze Zeit, wie weit sein Pferd ist und wie
//  weit die anderen sind, und genau daraus entsteht die Spannung.
//
//  Die Seitenstrecke ist das, was das Spiel ausmacht: Sechs verdeckte Karten
//  neben der Bahn. Sobald ALLE Pferde an einer davon vorbei sind, wird sie
//  aufgedeckt, das Pferd dieser Farbe muss zurueck, und wer darauf gesetzt
//  hat, trinkt. Je weiter hinten, desto teurer. Dadurch ist eine Fuehrung nie
//  sicher, und niemand steigt gedanklich aus.
//
//  Ohne Namen: Die App sagt "wer auf Pik gesetzt hat, trinkt". Wer das war,
//  weiss die Runde selbst – das braucht keine Eingabe.
//

import SwiftUI

struct HorseRaceView: View {

    private enum Phase: Equatable {
        case betting
        case racing
        case finished(winner: Int)
    }

    /// Felder bis zum Ziel. Sieben ist die uebliche Laenge: kurz genug fuer
    /// mehrere Rennen am Abend, lang genug, dass die Seitenstrecke greift.
    private static let finishLine = 7
    private static let sideCount = 6

    @State private var deck: [PlayingCard] = []
    @State private var side: [PlayingCard] = []
    @State private var revealedSides = 0
    @State private var positions = [0, 0, 0, 0]
    @State private var lastCard: PlayingCard?
    @State private var message: String?
    @State private var phase: Phase = .betting

    /// Wer heute am Tisch steht. Leer ist gueltig – dann laeuft das Rennen
    /// wie frueher, nur ohne Namen.
    @Environment(\.tablePlayers) private var tablePlayers

    /// Wer auf welche Bahn gesetzt hat: Profil-ID → Index der Farbe.
    ///
    /// Bleibt ueber das Rennen hinaus stehen. Nach einem Rennen setzt fast
    /// jeder wieder auf dasselbe Pferd; wer wechseln will, tippt einmal.
    @State private var bets: [String: Int] = [:]

    private let suits = PlayingCard.Suit.allCases
    private let loserPenalty = DrinkAmount.sips(3)
    private let winnerReward = DrinkAmount.sips(5)

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.success)

            ScrollView {
                VStack(spacing: 16) {
                    sideTrack
                    track
                    betsBoard
                    statusPanel
                    bettingPanel
                    controls
                }
                .padding(18)
            }
        }
        .navigationTitle("Pferderennen")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if deck.isEmpty { newRace() } }
    }

    // MARK: - Seitenstrecke

    private var sideTrack: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SEITENSTRECKE")
                .font(.scaled(10, weight: .heavy, design: .rounded))
                .kerning(1.6)
                .foregroundStyle(BeerStatsColor.textSecondary)

            HStack(spacing: 5) {
                ForEach(0..<Self.sideCount, id: \.self) { index in
                    sideCard(index)
                }
            }
        }
    }

    private func sideCard(_ index: Int) -> some View {
        let isOpen = index < revealedSides
        let card = side.indices.contains(index) ? side[index] : nil

        return VStack(spacing: 3) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isOpen ? Color(white: 0.94) : BeerStatsColor.surfaceElevated)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(
                        isOpen ? Color.black.opacity(0.2) : BeerStatsColor.success.opacity(0.5),
                        lineWidth: 1
                    )
                if isOpen, let card {
                    Text(card.suit.symbol)
                        .font(.system(size: 17))
                        .foregroundStyle(card.suit.isRed ? Color(red: 0.79, green: 0.16, blue: 0.14) : .black)
                }
            }
            .frame(height: 40)

            Text("\(index + 1)")
                .font(.scaled(9, weight: .bold, design: .rounded))
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bahn

    private var track: some View {
        VStack(spacing: 7) {
            ForEach(suits.indices, id: \.self) { index in
                lane(index)
            }
        }
        .padding(12)
        .glassPanel(cornerRadius: 18)
    }

    private func lane(_ index: Int) -> some View {
        let suit = suits[index]
        let isWinner: Bool
        if case .finished(let w) = phase { isWinner = w == index } else { isWinner = false }

        return HStack(spacing: 3) {
            Text(suit.symbol)
                .font(.system(size: 19))
                .foregroundStyle(suit.isRed ? BeerStatsColor.error : BeerStatsColor.textPrimary)
                .frame(width: 24)

            ForEach(0...Self.finishLine, id: \.self) { field in
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(field == Self.finishLine
                              ? BeerStatsColor.success.opacity(0.25)
                              : BeerStatsColor.surfaceElevated.opacity(0.55))
                    if positions[index] == field {
                        Text("🐎")
                            .font(.system(size: 15))
                    }
                }
                .frame(height: 26)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 5)
        .background(
            isWinner ? BeerStatsColor.success.opacity(0.16) : Color.clear,
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .animation(AppAnimation.standard, value: positions[index])
    }

    // MARK: - Einsaetze

    /// Wer auf welcher Bahn steht.
    private func bettors(on lane: Int) -> [PlayerProfile] {
        tablePlayers.filter { profile in
            guard let id = profile.id else { return false }
            return bets[id] == lane
        }
    }

    private func names(on lane: Int) -> String? {
        let leute = bettors(on: lane)
        guard !leute.isEmpty else { return nil }
        return leute.map(\.name).joined(separator: ", ")
    }

    /// „trinkt" oder „trinken" – ein Satz mit falschem Verb faellt am Tisch
    /// sofort auf.
    private func verb(_ singular: String, _ plural: String, on lane: Int) -> String {
        bettors(on: lane).count == 1 ? singular : plural
    }

    /// Das Setzen vor dem Rennen: eine Zeile je Person, vier Farben zum
    /// Antippen.
    ///
    /// Eine Zeile je PERSON und nicht je Farbe: So sieht man auf einen Blick,
    /// wer noch nicht gesetzt hat – und das ist die Frage, die am Tisch
    /// gestellt wird.
    @ViewBuilder
    private var bettingPanel: some View {
        if phase == .betting, !tablePlayers.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("WER SETZT AUF WAS")
                    .font(.scaled(11, weight: .heavy, design: .rounded))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                ForEach(tablePlayers) { profile in
                    betRow(profile)
                }

                Text("Nochmal auf dieselbe Farbe tippen nimmt den Einsatz zurück. Nach dem Rennen bleiben die Einsätze stehen.")
                    .font(.scaled(10, weight: .medium, design: .rounded))
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .glassPanel(cornerRadius: 18)
        }
    }

    private func betRow(_ profile: PlayerProfile) -> some View {
        HStack(spacing: 7) {
            ProfileAvatarView(profile: profile, size: 30)

            Text(profile.name)
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(suits.indices, id: \.self) { index in
                suitButton(profile: profile, lane: index)
            }
        }
    }

    private func suitButton(profile: PlayerProfile, lane: Int) -> some View {
        let suit = suits[lane]
        let isSet = profile.id.map { bets[$0] == lane } ?? false

        return Button {
            guard let id = profile.id else { return }
            if bets[id] == lane {
                bets[id] = nil
            } else {
                bets[id] = lane
            }
            HapticManager.lightImpact()
        } label: {
            Text(suit.symbol)
                .font(.system(size: 17))
                .foregroundStyle(
                    isSet
                        ? BeerStatsColor.textOnAccent
                        : (suit.isRed ? BeerStatsColor.error : BeerStatsColor.textPrimary)
                )
                .frame(width: 34, height: 34)
                .background(
                    isSet ? BeerStatsColor.success : BeerStatsColor.surfaceElevated.opacity(0.6),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(profile.name) auf \(suit.name)")
    }

    /// Waehrend des Rennens: wer auf welchem Pferd sitzt.
    ///
    /// Genau dafuer ist das Setzen da – merken muss es sich niemand mehr,
    /// auch nicht nach dem vierten Bier.
    @ViewBuilder
    private var betsBoard: some View {
        let belegt = suits.indices.filter { !bettors(on: $0).isEmpty }

        if phase != .betting, !belegt.isEmpty {
            VStack(spacing: 6) {
                ForEach(belegt, id: \.self) { lane in
                    HStack(spacing: 8) {
                        Text(suits[lane].symbol)
                            .font(.system(size: 15))
                            .foregroundStyle(
                                suits[lane].isRed ? BeerStatsColor.error : BeerStatsColor.textPrimary
                            )
                            .frame(width: 20)
                        Text(names(on: lane) ?? "")
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassPanel(cornerRadius: 14)
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusPanel: some View {
        switch phase {
        case .betting:
            VStack(spacing: 8) {
                Text("🐎").font(.system(size: 40))
                Text("Setzt eure Pferde")
                    .font(BeerStatsFont.title)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text(tablePlayers.isEmpty
                     ? "Jeder sagt laut, auf welche Farbe er setzt. Wer auf den Sieger tippt, verteilt \(winnerReward.text) – alle anderen trinken \(loserPenalty.text)."
                     : "Setzt euch unten auf eine Farbe. Wer auf den Sieger tippt, verteilt \(winnerReward.text) – alle anderen trinken \(loserPenalty.text).")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(18)
            .glassPanel(cornerRadius: 18)
            .neonEdge(BeerStatsColor.success, cornerRadius: 18, intensity: 0.6)

        case .racing:
            VStack(spacing: 8) {
                if let lastCard {
                    HStack(spacing: 10) {
                        PlayingCardView(card: lastCard, width: 54)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(lastCard.suit.name) rückt vor")
                                .font(BeerStatsFont.headline)
                                .foregroundStyle(BeerStatsColor.textPrimary)
                            Text("\(deck.count) Karten im Stapel")
                                .font(BeerStatsFont.caption)
                                .foregroundStyle(BeerStatsColor.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                } else {
                    Text("Deck eine Karte auf – die Farbe rückt vor.")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }

                if let message {
                    Text(message)
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.error)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(
                            BeerStatsColor.error.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .glassPanel(cornerRadius: 18)

        case .finished(let winner):
            VStack(spacing: 10) {
                Text("🏁").font(.system(size: 44))
                Text("\(suits[winner].name) gewinnt")
                    .font(BeerStatsFont.title)
                    .foregroundStyle(BeerStatsColor.success)
                Text(names(on: winner).map { "\($0) \(verb("verteilt", "verteilen", on: winner)) \(winnerReward.text)." }
                     ?? "Wer auf \(suits[winner].name) gesetzt hat, verteilt \(winnerReward.text).")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Alle anderen trinken \(loserPenalty.text).")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.error)
            }
            .frame(maxWidth: .infinity)
            .padding(18)
            .glassPanel(cornerRadius: 18)
            .neonEdge(BeerStatsColor.success, cornerRadius: 18, intensity: 0.8)
        }
    }

    // MARK: - Bedienung

    @ViewBuilder
    private var controls: some View {
        switch phase {
        case .betting:
            PrimaryButton(title: "Rennen starten", systemImage: "flag.checkered") {
                withAnimation(AppAnimation.standard) { phase = .racing }
                HapticManager.success()
                SoundManager.play(.ballsBack)
            }
        case .racing:
            PrimaryButton(title: "Karte aufdecken", systemImage: "hand.tap.fill") { drawCard() }
        case .finished:
            PrimaryButton(title: "Neues Rennen", systemImage: "arrow.counterclockwise") { newRace() }
        }
    }

    // MARK: - Ablauf

    private func newRace() {
        // Die vier Asse sind die Pferde und laufen deshalb nicht im Stapel mit.
        var full = PlayingCardDeck.shuffled().filter { $0.rank != 14 }
        side = Array(full.prefix(Self.sideCount))
        full.removeFirst(min(Self.sideCount, full.count))
        deck = full

        revealedSides = 0
        positions = [0, 0, 0, 0]
        lastCard = nil
        message = nil
        withAnimation(AppAnimation.standard) { phase = .betting }
        HapticManager.success()
    }

    private func drawCard() {
        if deck.isEmpty {
            // Sollte bei 42 Karten und sieben Feldern nie passieren – aber ein
            // leerer Stapel mitten im Rennen waere ein Spielabbruch.
            deck = PlayingCardDeck.shuffled().filter { $0.rank != 14 }
        }
        guard let card = deck.popLast() else { return }

        lastCard = card
        message = nil
        HapticManager.mediumImpact()
        SoundManager.play(.cardFlip)

        guard let lane = suits.firstIndex(of: card.suit) else { return }
        withAnimation(AppAnimation.standard) {
            positions[lane] = min(Self.finishLine, positions[lane] + 1)
        }

        if positions[lane] >= Self.finishLine {
            withAnimation(AppAnimation.standard) { phase = .finished(winner: lane) }
            HapticManager.success()
            SoundManager.play(.victory)
            return
        }

        revealSidesIfPassed()
    }

    /// Deckt jede Seitenkarte auf, an der inzwischen ALLE Pferde vorbei sind.
    ///
    /// In der Schleife und nicht als einzelne Prüfung: Schickt eine Seitenkarte
    /// ein Pferd zurück, kann dadurch die nächste sofort wieder fällig werden –
    /// und beim nächsten Zug wäre sie sonst stillschweigend übersprungen.
    private func revealSidesIfPassed() {
        while revealedSides < side.count,
              let slowest = positions.min(),
              slowest >= revealedSides + 1 {

            let card = side[revealedSides]
            revealedSides += 1

            guard let lane = suits.firstIndex(of: card.suit) else { continue }
            withAnimation(AppAnimation.standard) {
                positions[lane] = max(0, positions[lane] - 1)
            }

            // Je weiter hinten die Seitenkarte lag, desto teurer – deshalb
            // die laufende Nummer als Menge.
            let strafe = DrinkAmount.sips(revealedSides).text
            message = names(on: lane).map {
                "Seitenstrecke \(revealedSides): \(card.suit.name) muss zurück. \($0) \(verb("trinkt", "trinken", on: lane)) \(strafe)."
            } ?? "Seitenstrecke \(revealedSides): \(card.suit.name) muss zurück. Wer darauf gesetzt hat, trinkt \(strafe)."
            HapticManager.error()
            SoundManager.play(.bombe)
        }
    }
}
