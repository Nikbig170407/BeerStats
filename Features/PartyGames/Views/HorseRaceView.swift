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
//  Die Seitenstrecke ist das, was das Spiel ausmacht: verdeckte Karten
//  neben der Bahn. Sobald ALLE Pferde an einer davon vorbei sind, wird sie
//  aufgedeckt, das Pferd dieser Farbe muss zurueck, und wer darauf gesetzt
//  hat, trinkt. Je weiter hinten, desto teurer. Dadurch ist eine Fuehrung nie
//  sicher, und niemand steigt gedanklich aus.
//
//  Bahn und Seitenstrecke sind EIN Raster (4. November: "man soll besser
//  sehen, welche obere Karte zu welcher unteren gehoert"). Die Spalten sind
//  die Felder der Bahn; die Seitenkarte k steht ueber Spalte k und wird
//  aufgedeckt, wenn das letzte Pferd dort ankommt. Start und Ziel haben
//  keine Karte – am Start ist noch niemand vorbei, im Ziel ist das Rennen aus.
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

    private static let finishLine = HorseRaceTrack.finishLine
    private static let sideCount = HorseRaceTrack.sideCount

    // Masse des Rasters. Die Spaltenbreite wird aus diesen Zahlen gerechnet
    // (`columnWidth(in:)`), damit die Seitenkarten genau ueber den Feldern
    // der Bahn stehen – mit freier Breite liefen beide auseinander.
    private static let screenPadding: CGFloat = 18
    private static let panelPadding: CGFloat = 12
    private static let laneInset: CGFloat = 3
    private static let labelWidth: CGFloat = 22
    private static let labelGap: CGFloat = 6
    private static let cardGap: CGFloat = 4

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
    @Environment(\.gameWorld) private var world

    private var isFinished: Bool {
        if case .finished = phase { return true }
        return false
    }

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

            // Die Breite des Screens bestimmt die Spalten des Rasters, deshalb
            // steht sie hier fest und nicht erst tief im Baum. Dann sind auch
            // alle Hoehen berechenbar, und `ViewThatFits` weiss vorher, ob es
            // passt.
            GeometryReader { geometry in
                let breite = columnWidth(in: geometry.size.width)
                // Ein Spielscreen scrollt nicht – gescrollt wird nur, wenn es
                // selbst mit kleinster Bahn nicht passt (viele Leute beim
                // Setzen, sehr grosse Schrift).
                ViewThatFits(in: .vertical) {
                    raceLayout(columnWidth: breite)
                    ScrollView { raceLayout(columnWidth: breite) }
                        .verticalScrollOnly()
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .navigationTitle("Pferderennen")
        .navigationBarTitleDisplayMode(.inline)
        .roundSettings(for: .horseRace)
        .onAppear { if deck.isEmpty { newRace() } }
    }

    /// Das Raster hat Vorrang und nimmt, was uebrig ist; alles andere
    /// behaelt seine volle Hoehe. Schrumpfen soll die Bahn, nicht der Text.
    private func raceLayout(columnWidth: CGFloat) -> some View {
        VStack(spacing: 14) {
            raceGrid(columnWidth: columnWidth)
                .layoutPriority(1)
            Group {
                betsBoard
                statusPanel
                bettingPanel
                controls
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Self.screenPadding)
    }

    /// Breite einer Spalte: Start, die Felder und das Ziel teilen sich, was
    /// neben dem Farbzeichen links uebrig bleibt.
    private func columnWidth(in screenWidth: CGFloat) -> CGFloat {
        let frei = screenWidth
            - 2 * Self.screenPadding
            - 2 * Self.panelPadding
            - 2 * Self.laneInset
            - Self.labelWidth
            - Self.labelGap
        return max(20, frei / CGFloat(Self.finishLine + 1))
    }

    // MARK: - Raster

    /// Oben die Seitenkarten, darunter die Bahnen – Spalte fuer Spalte
    /// untereinander.
    private func raceGrid(columnWidth: CGFloat) -> some View {
        VStack(spacing: 6) {
            sideRow(columnWidth: columnWidth)

            VStack(spacing: 6) {
                ForEach(suits.indices, id: \.self) { index in
                    lane(index)
                }
            }
            // Die Spalte, an der die naechste Seitenkarte haengt
            .overlay { nextColumnMarker(columnWidth: columnWidth) }
        }
        .padding(Self.panelPadding)
        .glassPanel(cornerRadius: 18)
        // Im Ziel: Blitz, Schwarzweiss, Stillstand
        .modifier(PhotoFinish(isFinished: isFinished))
    }

    /// Welche Spalte als naechste eine Seitenkarte aufdeckt – `nil`, wenn
    /// nichts mehr zu erwarten ist.
    private var nextColumn: Int? {
        guard phase == .racing, revealedSides < Self.sideCount else { return nil }
        return revealedSides + 1
    }

    /// Ein heller Streifen ueber der Spalte der naechsten Seitenkarte: Sobald
    /// das letzte Pferd dort ankommt, dreht sich die Karte darueber um.
    private func nextColumnMarker(columnWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0...Self.finishLine, id: \.self) { column in
                Rectangle()
                    .fill(column == nextColumn ? Color.white.opacity(0.14) : Color.clear)
                    .frame(width: columnWidth)
            }
        }
        .padding(.leading, Self.laneInset + Self.labelWidth + Self.labelGap)
        .padding(.vertical, Self.laneInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .animation(AppAnimation.standard, value: nextColumn)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Seitenstrecke

    /// Die Seitenkarten in den Spalten der Bahn. Links bleibt Platz fuer die
    /// Farbzeichen, wie in den Bahnen darunter.
    private func sideRow(columnWidth: CGFloat) -> some View {
        HStack(spacing: Self.labelGap) {
            Color.clear.frame(width: Self.labelWidth, height: 1)

            HStack(spacing: 0) {
                ForEach(0...Self.finishLine, id: \.self) { column in
                    sideCell(column, width: columnWidth)
                }
            }
        }
        .padding(.horizontal, Self.laneInset)
    }

    @ViewBuilder
    private func sideCell(_ column: Int, width: CGFloat) -> some View {
        if column == 0 || column == Self.finishLine {
            // Start und Ziel haben keine Karte – das Schild fuellt die Ecke,
            // statt dass dort ein Loch im Raster bleibt
            Text(column == 0 ? "START" : "ZIEL")
                .font(Font.world(world, 10, weight: .heavy))
                .kerning(1)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: width, height: sideCellHeight(width: width))
        } else {
            sideCard(column - 1, width: width)
        }
    }

    private func sideCellHeight(width: CGFloat) -> CGFloat {
        (width - Self.cardGap) * PlayingCardView.aspect + 16
    }

    private func sideCard(_ index: Int, width: CGFloat) -> some View {
        let isOpen = index < revealedSides
        let card = side.indices.contains(index) ? side[index] : nil
        let isNext = index == revealedSides && nextColumn != nil
        let kartenbreite = width - Self.cardGap

        // Echte Karten ueber der Bahn, verdeckt, bis alle Pferde vorbei
        // sind – dann dreht sich die Karte um.
        return VStack(spacing: 3) {
            PlayingCardView(card: isOpen ? card : nil, width: kartenbreite)
                .modifier(FlipOnReveal(value: isOpen ? card : nil))
                .overlay {
                    // Die Karte, auf die das Raster gerade wartet
                    RoundedRectangle(cornerRadius: kartenbreite * 0.1, style: .continuous)
                        .strokeBorder(Color.white.opacity(isNext ? 0.9 : 0), lineWidth: 2)
                }

            Text("\(index + 1)")
                .font(Font.world(world, 11, weight: .bold))
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
        .frame(width: width, height: sideCellHeight(width: width))
        .animation(AppAnimation.standard, value: isNext)
    }

    // MARK: - Bahn

    private func lane(_ index: Int) -> some View {
        let suit = suits[index]
        let isWinner: Bool
        if case .finished(let w) = phase { isWinner = w == index } else { isWinner = false }

        return HStack(spacing: 6) {
            Text(suit.symbol)
                .font(.system(size: 19))
                .foregroundStyle(suit.isRed ? BeerStatsColor.error : BeerStatsColor.textPrimary)
                .frame(width: 22)

            RaceLane(suit: suit, position: positions[index], finish: Self.finishLine)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .padding(3)
        // Hell statt gruen: Das Zielfoto ist schwarzweiss, und der Sieger
        // soll darauf trotzdem herausstechen
        .background(
            isWinner ? Color.white.opacity(0.22) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
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
                    .font(Font.world(world, 13, weight: .heavy))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                ForEach(tablePlayers) { profile in
                    betRow(profile)
                }

                Text("Nochmal tippen nimmt den Einsatz zurück.")
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
                Text("SETZT EURE PFERDE")
                    .font(Font.world(world, 28, weight: .heavy))
                    .kerning(1.5)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text(tablePlayers.isEmpty
                     ? "Jeder sagt laut seine Farbe. Richtig: verteilt \(winnerReward.text). Falsch: trinkt \(loserPenalty.text)."
                     : "Setzt unten auf eine Farbe. Richtig: verteilt \(winnerReward.text). Falsch: trinkt \(loserPenalty.text).")
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
                                .font(Font.world(world, 20, weight: .bold))
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
                Text("\(suits[winner].name.uppercased()) GEWINNT")
                    .font(Font.world(world, 30, weight: .heavy))
                    .kerning(1.5)
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
                SoundManager.play(.chips)
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
            // Sollte mit dem Stapel und sechs Feldern nie passieren – aber ein
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
            SoundManager.play(.penalty)
        }
    }
}
