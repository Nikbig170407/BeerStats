//
//  BusRideView.swift
//  BeerStats
//
//  Bussfahrer, in zwei Haelften – so, wie das Spiel am Tisch laeuft.
//
//  **Erst die Fragerunde:** Vier Fragen hintereinander, jede schwerer als
//  die vorige. Wer daneben liegt, trinkt und faengt von vorne an. Die Strafe
//  steigt mit der Runde – ein Fehler bei Frage vier tut mehr weh als bei
//  Frage eins. Ohne diese Staffelung waere es egal, wie weit man kommt, und
//  genau das ist der Reiz: Je naeher am Ziel, desto teurer.
//
//  **Dann die Busfahrt:** Der Teil, der dem Spiel seinen Namen gibt – und
//  der hier lange gefehlt hat. Das Spiel hoerte nach der vierten richtigen
//  Antwort einfach auf ("Das Handy geht weiter"), und der Bussfahrer kam
//  nie vor. Wer am meisten daneben lag, faehrt Bus: Er deckt eine Reihe
//  Karten auf, und jede Bildkarte schickt ihn zurueck an den Anfang.
//
//  Gleichstand zaehlt bewusst als falsch. Sonst waere bei "hoeher oder
//  tiefer" die Karte selbst eine Ausrede.
//

import SwiftUI

struct BusRideView: View {

    private enum Phase: Equatable {
        // Fragerunde
        case asking
        case wrong(sips: Int)
        case survived
        // Busfahrt
        case rideReady
        case riding
        case busted(sips: Int)
        case escaped
    }

    private struct Question {
        let title: String
        let options: [String]
    }

    private static let questions: [Question] = [
        Question(title: "Rot oder Schwarz?", options: ["Rot", "Schwarz"]),
        Question(title: "Höher oder tiefer?", options: ["Höher", "Tiefer"]),
        Question(title: "Innerhalb oder außerhalb?", options: ["Innerhalb", "Außerhalb"]),
        Question(title: "Welche Farbe?", options: ["Herz", "Karo", "Pik", "Kreuz"])
    ]

    /// Wie viele Karten die Busfahrt lang ist.
    ///
    /// Fuenf, und das ist gerechnet: Sechzehn der zweiundfuenfzig Karten sind
    /// Bildkarten (Bube bis Ass), eine Karte ist also mit knapp 31 Prozent
    /// ein Rueckschlag. Fuenf gute hintereinander gelingen dadurch in etwa
    /// jedem sechsten Versuch – der Bussfahrer sitzt lange genug, dass es
    /// wehtut, und kommt sicher genug raus, dass die Runde nicht einschlaeft.
    /// Bei acht Karten waere es jeder zwanzigste Versuch, und das ist keine
    /// Busfahrt mehr, sondern eine Haftstrafe.
    private static let rideLength = 5

    /// Ab diesem Rang ist es eine Bildkarte: Bube, Dame, Koenig, Ass.
    private static let faceCardRank = 11

    @State private var deck: [PlayingCard] = PlayingCardDeck.shuffled()
    @State private var drawn: [PlayingCard] = []
    @State private var phase: Phase = .asking

    /// Die Reihe der Busfahrt, verdeckt. Aufgedeckt ist, was vor
    /// `ridePosition` liegt.
    @State private var ride: [PlayingCard] = []
    @State private var ridePosition = 0

    /// Wie oft weitergegeben wurde. Wer dran ist, rechnet `TurnRow` – und
    /// auf der Busfahrt bleibt es derselbe, der fahren muss.
    @State private var turn = 0

    /// Die laufende Frage. Bewusst gedeckelt: Nach der vierten richtigen
    /// Antwort steht `drawn.count` auf 4, und ein Zugriff auf `questions[4]`
    /// wuerde abstuerzen, falls die Ansicht in genau dem Moment noch einmal
    /// zeichnet.
    private var round: Int { min(drawn.count, Self.questions.count - 1) }

    private var isRiding: Bool {
        switch phase {
        case .rideReady, .riding, .busted, .escaped: return true
        case .asking, .wrong, .survived: return false
        }
    }

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: isRiding ? BeerStatsColor.warning : BeerStatsColor.accentSecondary)

            // Die Breite kommt von hier und nicht aus festen Zahlen: Die
            // Karten sollen den Bildschirm ausfuellen, nicht in seiner Mitte
            // sitzen. Vorher waren sie 68 Punkte breit, egal wie viel Platz
            // da war – auf einem grossen Geraet lag die Haelfte des Screens
            // leer.
            GeometryReader { geometry in
                VStack(spacing: 14) {
                    if !isRiding {
                        TurnRow(turn: turn, tint: BeerStatsColor.accentSecondary)
                    }
                    cardRow(in: geometry.size.width)
                    statusPanel
                    controls
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .top
                )
            }
            .padding(20)
        }
        .navigationTitle(isRiding ? "Die Busfahrt" : "Bussfahrer")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Karten

    /// Die Kartenreihe – in der Fragerunde vier, auf der Busfahrt fuenf.
    ///
    /// Die Breite teilt sich den Platz auf, mit einem Deckel: Breiter als ein
    /// Viertel des Screens muss eine Karte nicht werden, sonst wird die Reihe
    /// hoeher als das, was darunter steht.
    private func cardRow(in width: CGFloat) -> some View {
        let anzahl = isRiding ? Self.rideLength : Self.questions.count
        let abstand: CGFloat = 8
        let breite = min(
            (width - abstand * CGFloat(anzahl - 1)) / CGFloat(anzahl),
            width * 0.26
        )

        return HStack(spacing: abstand) {
            ForEach(Array(0..<anzahl), id: \.self) { slot in
                PlayingCardView(card: card(at: slot), width: breite)
                    .opacity(dimmed(slot) ? 0.35 : 1)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(AppAnimation.standard, value: drawn.count)
        .animation(AppAnimation.standard, value: ridePosition)
    }

    private func card(at slot: Int) -> PlayingCard? {
        if isRiding {
            // Aufgedeckt ist nur, was hinter dem Bus liegt.
            guard slot < ridePosition, ride.indices.contains(slot) else { return nil }
            return ride[slot]
        }
        return drawn.indices.contains(slot) ? drawn[slot] : nil
    }

    private func dimmed(_ slot: Int) -> Bool {
        isRiding ? slot > ridePosition : slot > round
    }

    // MARK: - Status

    /// Nimmt den freien Platz ein, statt ihn offen zu lassen.
    ///
    /// Hier stand ein `Spacer` zwischen Panel und Knoepfen – das Panel blieb
    /// klein, und in der Mitte des Screens war Luft. Jetzt waechst das Panel
    /// in den Platz hinein: Was zu sagen ist, steht gross da.
    @ViewBuilder
    private var statusPanel: some View {
        switch phase {
        case .asking:
            panel(tint: BeerStatsColor.accentSecondary, intensity: 0.5) {
                Text("FRAGE \(round + 1) VON 4")
                    .font(Font.scaled(12, weight: .heavy, design: .rounded))
                    .kerning(2.4)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                Text(Self.questions[round].title)
                    .font(.scaled(30, weight: .heavy, design: .rounded))
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Falsch kostet \(DrinkAmount.sips(round + 1).text)")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.accentSecondary)
            }

        case .wrong(let sips):
            resultPanel(
                emoji: "🍺",
                title: "DANEBEN",
                message: "Trink \(DrinkAmount.sips(sips).text) und fang von vorne an.",
                tint: BeerStatsColor.error
            )

        case .survived:
            resultPanel(
                emoji: "🎉",
                title: "DURCHGEKOMMEN",
                message: "Alle vier richtig – du bist raus. Das Handy geht weiter.",
                tint: BeerStatsColor.success
            )

        case .rideReady:
            resultPanel(
                emoji: "🚌",
                title: "DIE BUSFAHRT",
                message: "Wer am meisten daneben lag, fährt Bus. \(Self.rideLength) Karten aufdecken – jede Bildkarte schickt dich zurück an den Anfang. Je weiter du kommst, desto teurer.",
                tint: BeerStatsColor.warning
            )

        case .riding:
            panel(tint: BeerStatsColor.warning, intensity: 0.6) {
                Text("KARTE \(ridePosition + 1) VON \(Self.rideLength)")
                    .font(Font.scaled(12, weight: .heavy, design: .rounded))
                    .kerning(2.4)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                Text("Zahl ist gut, Bild ist schlecht.")
                    .font(.scaled(26, weight: .heavy, design: .rounded))
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Ein Bild kostet jetzt \(DrinkAmount.sips(ridePosition + 1).text)")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.warning)
            }

        case .busted(let sips):
            resultPanel(
                emoji: "🛑",
                title: "ZURÜCK AN DEN ANFANG",
                message: "Bild gezogen. Trink \(DrinkAmount.sips(sips).text) – und nochmal von Karte eins.",
                tint: BeerStatsColor.error
            )

        case .escaped:
            resultPanel(
                emoji: "🏁",
                title: "AUSGESTIEGEN",
                message: "Alle \(Self.rideLength) Karten ohne Bild. Du bist raus – verteile \(DrinkAmount.sips(3).text).",
                tint: BeerStatsColor.success
            )
        }
    }

    private func resultPanel(emoji: String, title: String, message: String, tint: Color) -> some View {
        panel(tint: tint, intensity: 0.8) {
            Text(emoji).font(.system(size: 52))
            Text(title)
                .font(.scaled(26, weight: .heavy, design: .rounded))
                .kerning(2)
                .foregroundStyle(tint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .transition(.scale.combined(with: .opacity))
    }

    /// Der gemeinsame Rahmen aller Zustaende. Einer statt sechs, damit sie
    /// nicht auseinanderlaufen – und mit `maxHeight: .infinity`, damit der
    /// Platz im Panel landet und nicht daneben.
    private func panel<Content: View>(
        tint: Color,
        intensity: Double,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .glassPanel(cornerRadius: 22)
        .neonEdge(tint, cornerRadius: 22, intensity: intensity)
    }

    // MARK: - Bedienung

    @ViewBuilder
    private var controls: some View {
        switch phase {
        case .asking:
            answerGrid

        case .wrong, .survived:
            VStack(spacing: 8) {
                PrimaryButton(title: "Nächster Versuch", systemImage: "arrow.counterclockwise") {
                    restartHand()
                }
                // Der Weg in die zweite Haelfte. Steht leise darunter, weil
                // die Runde selbst entscheidet, wann alle durch sind – die
                // App weiss nicht, wie viele mitspielen.
                QuietButton(title: "Alle durch – Busfahrt starten", tint: BeerStatsColor.warning) {
                    startRide()
                }
            }

        case .rideReady:
            PrimaryButton(title: "Losfahren", systemImage: "bus.fill") { flipNext() }

        case .riding:
            PrimaryButton(title: "Karte aufdecken", systemImage: "hand.tap.fill") { flipNext() }

        case .busted:
            PrimaryButton(title: "Nochmal von vorn", systemImage: "arrow.counterclockwise") {
                startRide()
            }

        case .escaped:
            VStack(spacing: 8) {
                PrimaryButton(title: "Neue Busfahrt", systemImage: "bus.fill") { startRide() }
                QuietButton(title: "Zurück zur Fragerunde") { restartHand() }
            }
        }
    }

    private var currentOptions: [String] { Self.questions[round].options }

    /// Zwei Antworten nebeneinander, vier in zwei Reihen – so bleiben die
    /// Flaechen in jeder Runde gleich gross.
    ///
    /// Als eigene Eigenschaft und nicht als `let` im ViewBuilder: Variablen
    /// in einem Result Builder gibt es erst ab Swift 5.9, und hier braucht
    /// es sie nicht.
    private var answerGrid: some View {
        VStack(spacing: 10) {
            ForEach(Array(stride(from: 0, to: currentOptions.count, by: 2)), id: \.self) { start in
                HStack(spacing: 10) {
                    // Als Array und nicht als Bereich: Ein ForEach über einen
                    // berechneten Range erwartet konstante Daten, und die
                    // Antwortzahl wechselt zwischen 2 und 4.
                    ForEach(Array(start..<min(start + 2, currentOptions.count)), id: \.self) { index in
                        answerButton(currentOptions[index], index: index)
                    }
                }
            }
        }
    }

    private func answerButton(_ title: String, index: Int) -> some View {
        Button {
            answer(index)
        } label: {
            Text(title)
                .font(BeerStatsFont.headline)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    BeerStatsColor.surfaceElevated,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(BeerStatsColor.accentSecondary.opacity(0.45), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Fragerunde

    private func answer(_ index: Int) {
        guard case .asking = phase else { return }
        if deck.count < 2 { deck = PlayingCardDeck.shuffled() }
        guard let card = deck.popLast() else { return }

        let correct = isCorrect(answer: index, card: card)
        let filled = drawn.count + 1

        // Karte und Phase wandern in einem Schritt, nicht in zweien: Sonst
        // gäbe es einen Moment, in dem vier Karten liegen und trotzdem noch
        // nach einer fünften Frage gesucht wird.
        withAnimation(AppAnimation.standard) {
            drawn.append(card)
            if !correct {
                phase = .wrong(sips: filled)
            } else if filled == Self.questions.count {
                phase = .survived
            }
        }

        if correct {
            HapticManager.success()
            SoundManager.play(filled == Self.questions.count ? .victory : .ballsBack)
        } else {
            HapticManager.error()
            SoundManager.play(.miss)
        }
    }

    private func isCorrect(answer index: Int, card: PlayingCard) -> Bool {
        switch drawn.count {
        case 0:
            return index == 0 ? card.isRed : !card.isRed

        case 1:
            // Gleichstand ist falsch – sonst waere jede Zehn eine Ausrede.
            guard card.rank != drawn[0].rank else { return false }
            return index == 0 ? card.rank > drawn[0].rank : card.rank < drawn[0].rank

        case 2:
            let low = min(drawn[0].rank, drawn[1].rank)
            let high = max(drawn[0].rank, drawn[1].rank)
            // Auf der Grenze zaehlt als aussen: innerhalb heisst echt dazwischen.
            let inside = card.rank > low && card.rank < high
            return index == 0 ? inside : !inside

        default:
            let suits: [PlayingCard.Suit] = [.hearts, .diamonds, .spades, .clubs]
            guard suits.indices.contains(index) else { return false }
            return card.suit == suits[index]
        }
    }

    private func restartHand() {
        if deck.count < 8 { deck = PlayingCardDeck.shuffled() }
        // Nach einer geschafften Hand ist der Naechste dran. Nach einem
        // Fehler faengt DIESELBE Person von vorne an – so steht es in der
        // Anleitung, und der Zug darf dann nicht weiterlaufen.
        switch phase {
        case .wrong, .busted: break
        default: turn += 1
        }

        withAnimation(AppAnimation.standard) {
            drawn.removeAll()
            ride.removeAll()
            ridePosition = 0
            phase = .asking
        }
        HapticManager.lightImpact()
    }

    // MARK: - Busfahrt

    /// Legt die Reihe neu aus.
    ///
    /// Jeder Versuch bekommt frische Karten aus dem gemischten Stapel. Die
    /// alte Reihe nochmal zu nehmen waere falsch: Der Bussfahrer wuesste nach
    /// dem ersten Fehlversuch, wo das Bild liegt.
    private func startRide() {
        if deck.count < Self.rideLength { deck = PlayingCardDeck.shuffled() }
        let frisch = (0..<Self.rideLength).compactMap { _ in deck.popLast() }

        withAnimation(AppAnimation.standard) {
            ride = frisch
            ridePosition = 0
            phase = .rideReady
        }
        HapticManager.lightImpact()
        SoundManager.play(.reRack)
    }

    /// Deckt die naechste Karte auf.
    private func flipNext() {
        guard ride.indices.contains(ridePosition) else { return }

        let karte = ride[ridePosition]
        let platz = ridePosition + 1
        let istBild = karte.rank >= Self.faceCardRank

        withAnimation(AppAnimation.standard) {
            ridePosition = platz
            if istBild {
                phase = .busted(sips: platz)
            } else if platz == Self.rideLength {
                phase = .escaped
            } else {
                phase = .riding
            }
        }

        if istBild {
            HapticManager.error()
            SoundManager.play(.bombe)
        } else if platz == Self.rideLength {
            HapticManager.success()
            SoundManager.play(.victory)
            SpeechAnnouncer.announce("Ausgestiegen")
        } else {
            HapticManager.lightImpact()
            SoundManager.play(.cardFlip)
        }
    }
}
