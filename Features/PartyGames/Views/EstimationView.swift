//
//  EstimationView.swift
//  BeerStats
//
//  Schaetzmeister: Frage vorlesen, jeder schaetzt eine Zahl, dann
//  aufloesen. Wer am weitesten daneben liegt, trinkt.
//
//  Zwei Arten, im Vorspann gewaehlt (Wunsch des Nutzers vom 4. November):
//
//  - **Reinrufen**: Alle sagen ihre Zahl laut. Die App stellt die Frage und
//    kennt die Wahrheit, mehr nicht – acht Zahlen einzutippen dauerte
//    laenger als die Runde, und verglichen ist am Tisch in zwei Sekunden.
//  - **Aufschreiben**: Das Handy geht reihum wie beim Spion, jeder tippt
//    seine Zahl geheim ein und gibt ab – danach ist sie weg. Am Ende deckt
//    die App von ganz daneben bis am naechsten dran auf. Niemand kann sich
//    an die Zahl des Vorgaengers haengen, und weil die App den Verlierer
//    kennt, bucht sie die Strafe selbst in den Abend.
//
//  Die Rechnung dazu steht in `EstimationRound`.
//

import SwiftUI

struct EstimationView: View {

    private enum Phase: Equatable {
        case setup
        /// Die Frage steht, noch niemand hat geschaetzt.
        case question
        /// Aufschreiben: Das Handy ist bei `order[step]`.
        case entering(step: Int, isRevealed: Bool)
        /// Aufschreiben: alle haben abgegeben, noch nicht aufgedeckt.
        case allIn
        case revealed
    }

    @AppStorage("estimation.mode") private var storedMode = EstimationMode.callOut.rawValue

    @State private var phase: Phase = .setup
    @State private var deck: [EstimationQuestion] = EstimationDeck.shuffled()
    @State private var index = 0
    @State private var playerCount = min(PlayerNames.suggestedCount() ?? 4, PartyGame.manyPlayers)
    /// Wie DIESE Frage gespielt wird – beim Fragebeginn aus der Einstellung
    /// uebernommen. Eine eigene Kopie, weil das Zahnrad die Art mitten in
    /// der Frage umstellen kann: Die halbe Runde hat dann schon getippt.
    @State private var questionMode: EstimationMode = .callOut
    @State private var guesses: [EstimationGuess] = []
    @State private var entry = EstimationEntry(allowsDecimals: false)
    @State private var verdict: EstimationVerdict?
    /// Wie viele Zeilen der Auflösung schon dastehen.
    @State private var shownRows = 0

    @Environment(\.gameWorld) private var world
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Grundmengen an einer Stelle, damit Anzeige und Regeltext nicht
    /// auseinanderlaufen koennen.
    private let loserAmount = DrinkAmount.sips(3)
    private let winnerAmount = DrinkAmount.sips(3)
    private let tint = BeerStatsColor.success

    /// Erst steht die Antwort auf den Walzen, dann kommt Zeile um Zeile.
    private static let firstRowDelay: Double = 1.2
    private static let rowDelay: Double = 0.7

    private var mode: EstimationMode { EstimationMode(rawValue: storedMode) ?? .callOut }

    private var current: EstimationQuestion? {
        deck.indices.contains(index) ? deck[index] : nil
    }

    private var order: [Int] {
        EstimationRound.order(playerCount: playerCount, question: index)
    }

    /// Das Zahnrad nur, solange niemandes Zahl auf dem Screen steht.
    private var settingsAvailable: Bool {
        switch phase {
        case .setup, .entering: return false
        case .question, .allIn, .revealed: return true
        }
    }

    var body: some View {
        Group {
            if phase == .setup {
                setupView
            } else {
                gameView
            }
        }
        .navigationTitle("Schätzmeister")
        .navigationBarTitleDisplayMode(.inline)
        // Die Spielerzahl fehlt im Zahnrad mit Absicht: Sie legt die Partie
        // fest, wer sie aendern will, faengt neu an
        .roundSettings(
            for: .estimation,
            isAvailable: settingsAvailable,
            note: "Die Art gilt ab der nächsten Frage, die Härte ab der nächsten Strafe.",
            onClose: applySettings
        ) {
            modeBlock
        }
    }

    // MARK: - Vorspann

    private var setupView: some View {
        GameSetupScreen(
            emoji: "🤔",
            title: "Schätzmeister",
            subtitle: "Eine Frage, eine Zahl. Wer am weitesten daneben liegt, trinkt.",
            tint: tint,
            onStart: start
        ) {
            VStack(alignment: .leading, spacing: 20) {
                modeBlock

                if mode == .writeDown {
                    block("WIE VIELE SPIELEN MIT?") {
                        PlayerCountStepper(count: $playerCount, range: 2...PartyGame.manyPlayers, tint: tint)
                    }
                }

                DrinkIntensityPicker(game: .estimation)
            }
        }
    }

    /// Im Vorspann und im Zahnrad derselbe Schalter.
    private var modeBlock: some View {
        block("WIE WIRD GESCHÄTZT?") {
            ChoiceRow(
                options: [
                    ChoiceOption(value: EstimationMode.callOut.rawValue, title: "Reinrufen", detail: "Alle sagen laut"),
                    ChoiceOption(value: EstimationMode.writeDown.rawValue, title: "Aufschreiben", detail: "Geheim ins Handy")
                ],
                selection: $storedMode,
                tint: tint
            )
        }
    }

    private func block<Inhalt: View>(_ titel: String, @ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titel)
                .font(.scaled(11, weight: .heavy, design: .rounded))
                .kerning(1.6)
                .foregroundStyle(BeerStatsColor.textSecondary)
            inhalt()
        }
    }

    // MARK: - Spiel

    private var gameView: some View {
        ZStack {
            AmbientBackdrop(glow: tint)

            if let question = current {
                if case .entering(let step, let isRevealed) = phase {
                    FillingScrollView {
                        entryPanel(question, step: step, isRevealed: isRevealed)
                            .padding(24)
                    }
                } else if phase == .revealed, questionMode == .writeDown, let verdict {
                    FillingScrollView {
                        writtenReveal(question, verdict: verdict)
                            .padding(24)
                    }
                } else {
                    VStack(spacing: 20) {
                        progressLine
                        questionCard(question)
                        controls
                    }
                    .padding(24)
                }
            } else {
                finishedView
                    .padding(24)
            }
        }
    }

    private var progressLine: some View {
        HStack {
            Text("Frage \(index + 1) von \(deck.count)")
                .font(BeerStatsFont.statLabel)
                .foregroundStyle(BeerStatsColor.textSecondary)
            Spacer()
            QuietButton(title: "Neu mischen") { restart() }
        }
    }

    private func questionCard(_ question: EstimationQuestion) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            Text(question.text)
                .font(Font.world(world, 23, weight: .heavy))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if phase == .revealed {
                answerReels(question)

                Text("Wer am weitesten daneben liegt, trinkt \(loserAmount.text).")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)

                Text("Wer am nächsten dran ist, darf \(winnerAmount.text) verteilen.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.accent)
                    .multilineTextAlignment(.center)
            } else {
                Text(cardHint)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        // Fuellt den Platz, statt ihn frei zu lassen: Hier stand ein
        // `Spacer` zwischen Karte und Knoepfen, und die Karte blieb so klein
        // wie ihr Text – auf einem grossen Geraet lag die Haelfte des
        // Screens leer. Die Spacer INNEN halten den Text in der Mitte der
        // Karte.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
        .glassPanel(cornerRadius: 24)
        // Die Lauflichter der Quizshow um die Frage
        .overlay { MarqueeLights().padding(4) }
        .animation(AppAnimation.standard, value: phase)
        .id(question.id)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private var cardHint: String {
        switch (questionMode, phase) {
        case (.writeDown, .allIn):
            return "Alle haben geschätzt. Jetzt wird aufgedeckt – von ganz daneben bis am nächsten dran."
        case (.writeDown, _):
            return "Vorlesen, dann geht das Handy reihum. Jeder tippt seine Schätzung geheim ein."
        case (.callOut, _):
            return "Reihum schätzt jeder eine Zahl. Keine Zahl darf doppelt kommen."
        }
    }

    /// Die Loesung rollt auf Walzen ein, die Einheit steht darunter.
    @ViewBuilder
    private func answerReels(_ question: EstimationQuestion) -> some View {
        Text("AUFLÖSUNG")
            .font(Font.world(world, 13, weight: .bold))
            .kerning(3)
            .foregroundStyle(QuizShow.bulb)

        DigitReels(text: question.numberText, size: question.numberText.count > 4 ? 36 : 44)
        if !question.unit.isEmpty {
            Text(question.unit)
                .font(Font.world(world, 20, weight: .bold))
                .foregroundStyle(BeerStatsColor.textPrimary)
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch (questionMode, phase) {
        case (.callOut, .revealed):
            PrimaryButton(title: "Nächste Frage", systemImage: "arrow.right") { advance() }
        case (.callOut, _):
            PrimaryButton(title: "Auflösen", systemImage: "eye.fill") { revealCalledOut() }
        case (.writeDown, .allIn):
            PrimaryButton(title: "Aufdecken", systemImage: "eye.fill") { revealWritten() }
        case (.writeDown, _):
            PrimaryButton(title: "Schätzungen abgeben", systemImage: "hand.point.up.left.fill") { beginEntering() }
        }
    }

    private var finishedView: some View {
        VStack(spacing: 18) {
            Text("Alle Fragen durch")
                .font(Font.world(world, 28, weight: .heavy))
                .foregroundStyle(BeerStatsColor.textPrimary)
            Spacer(minLength: 0)
            PrimaryButton(title: "Neu mischen", systemImage: "shuffle") { restart() }
        }
    }

    // MARK: - Aufschreiben

    /// Uebernehmen, tippen, abgeben – der Ablauf vom Spion. Die Frage steht
    /// mit auf dem Blatt, weil man beim Tippen nachlesen will, ob nach Metern
    /// oder Kilometern gefragt war.
    private func entryPanel(_ question: EstimationQuestion, step: Int, isRevealed: Bool) -> some View {
        HandoffPanel(
            player: order[step],
            isRevealed: isRevealed,
            tint: tint,
            continueTitle: "Abgeben",
            canContinue: entry.tenths != nil,
            onReveal: {
                withAnimation(AppAnimation.standard) { phase = .entering(step: step, isRevealed: true) }
            },
            onContinue: { submit(step: step) }
        ) {
            Text(question.text)
                .font(Font.world(world, 17, weight: .heavy))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            EstimationDisplay(text: entry.display, unit: question.unit)

            EstimationKeypad(
                allowsDecimals: question.allowsDecimals,
                onDigit: { entry.type($0) },
                onComma: { entry.typeComma() },
                onDelete: { entry.delete() }
            )
        }
    }

    /// Antwort oben, darunter Zeile um Zeile, wer was getippt hat.
    private func writtenReveal(_ question: EstimationQuestion, verdict: EstimationVerdict) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Text(question.text)
                    .font(Font.world(world, 17, weight: .heavy))
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                answerReels(question)
            }
            .frame(maxWidth: .infinity)
            .padding(22)
            .glassPanel(cornerRadius: 22)
            .overlay { MarqueeLights().padding(4) }

            VStack(spacing: 8) {
                ForEach(Array(verdict.rows.enumerated()), id: \.offset) { stelle, zeile in
                    if stelle < shownRows {
                        guessRow(zeile)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }

            if shownRows >= verdict.rows.count, verdict.isDraw {
                Text("Alle gleich weit daneben – keiner trinkt.")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)

            PrimaryButton(title: "Nächste Frage", systemImage: "arrow.right") { advance() }

            // Weiter geht es danach mit der naechsten Frage, nicht mit
            // einem neuen Stapel
            QuietButton(title: "Spielerzahl ändern") {
                index += 1
                withAnimation(AppAnimation.standard) { phase = .setup }
            }
        }
        // Aufgedeckt wird von selbst, Zeile um Zeile. Die Aufgabe haengt an
        // der Frage und endet mit dem Screen – kein Timer, der weiterlaeuft.
        .task(id: index) { await revealRows(count: verdict.rows) }
    }

    private func guessRow(_ zeile: EstimationVerdict.Row) -> some View {
        let farbe: Color
        let vermerk: String
        switch zeile.place {
        case .farthest:
            farbe = BeerStatsColor.error
            vermerk = "trinkt \(loserAmount.text)"
        case .nearest:
            farbe = BeerStatsColor.accent
            vermerk = zeile.distance == 0 ? "Volltreffer! Verteilt \(winnerAmount.text)" : "verteilt \(winnerAmount.text)"
        case .between:
            farbe = BeerStatsColor.textSecondary
            vermerk = zeile.distance == 0 ? "Volltreffer!" : ""
        }

        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(PlayerNames.name(for: zeile.player))
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                if !vermerk.isEmpty {
                    Text(vermerk)
                        .font(.scaled(12, weight: .heavy, design: .rounded))
                        .foregroundStyle(farbe)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(EstimationEntry.format(tenths: zeile.tenths))
                    .font(.scaled(22, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(QuizShow.bulb)
                Text(zeile.distance == 0 ? "genau" : "\(EstimationEntry.format(tenths: zeile.distance)) daneben")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassPanel(cornerRadius: 16)
        .neonEdge(farbe, cornerRadius: 16, intensity: zeile.place == .between ? 0.15 : 0.7)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Ablauf

    /// Gemischt ist der Stapel schon beim Betreten. Wer aus dem Spiel
    /// heraus die Spielerzahl aendert, spielt mit dem Rest weiter.
    private func start() {
        beginQuestion()
        HapticManager.success()
    }

    /// Jede Frage faengt hier an – mit der Art, die jetzt eingestellt ist.
    private func beginQuestion() {
        questionMode = mode
        guesses = []
        verdict = nil
        shownRows = 0
        withAnimation(AppAnimation.standard) { phase = .question }
    }

    /// Hat noch niemand geschaetzt, gilt eine neue Art sofort – sonst ab der
    /// naechsten Frage, wie unter dem Blatt steht.
    private func applySettings() {
        if phase == .question { questionMode = mode }
    }

    private func beginEntering() {
        guard let question = current, !order.isEmpty else { return }
        guesses = []
        entry = EstimationEntry(allowsDecimals: question.allowsDecimals)
        withAnimation(AppAnimation.standard) { phase = .entering(step: 0, isRevealed: false) }
    }

    /// Die Zahl ist weg, sobald abgegeben ist: Der Naechste sieht nur noch
    /// den verdeckten Screen mit seinem Namen.
    private func submit(step: Int) {
        guard let question = current, let zehntel = entry.tenths else { return }
        guesses.append(EstimationGuess(player: order[step], tenths: zehntel))
        entry = EstimationEntry(allowsDecimals: question.allowsDecimals)
        SoundManager.play(.chips)
        withAnimation(AppAnimation.standard) {
            phase = step + 1 < order.count ? .entering(step: step + 1, isRevealed: false) : .allIn
        }
    }

    private func revealCalledOut() {
        withAnimation(AppAnimation.standard) { phase = .revealed }
        HapticManager.success()
        SoundManager.play(.reveal)
    }

    private func revealWritten() {
        guard let question = current else { return }
        let urteil = EstimationVerdict(answer: question.answer, guesses: guesses)
        verdict = urteil
        shownRows = 0
        // Die App kennt den Verlierer, also bucht sie. Das Verteilen nicht:
        // Wer dabei etwas abbekommt, weiss nur die Runde.
        EveningLog.record(loserAmount, forPlayers: urteil.farthest)
        withAnimation(AppAnimation.standard) { phase = .revealed }
        HapticManager.success()
        SoundManager.play(.reveal)
    }

    /// Zeile um Zeile, ganz daneben zuerst. Mit "Bewegung reduzieren" steht
    /// alles sofort da.
    @MainActor
    private func revealRows(count zeilen: [EstimationVerdict.Row]) async {
        guard !reduceMotion else {
            shownRows = zeilen.count
            return
        }
        for (stelle, zeile) in zeilen.enumerated() {
            let warten = stelle == 0 ? Self.firstRowDelay : Self.rowDelay
            try? await Task.sleep(nanoseconds: UInt64(warten * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(AppAnimation.standard) { shownRows = stelle + 1 }
            switch zeile.place {
            case .farthest:
                HapticManager.mediumImpact()
                SoundManager.play(.penalty)
            case .nearest:
                HapticManager.success()
                SoundManager.play(.correct)
            case .between:
                HapticManager.lightImpact()
                SoundManager.play(.tap)
            }
        }
    }

    private func advance() {
        withAnimation(AppAnimation.standard) { index += 1 }
        beginQuestion()
        HapticManager.lightImpact()
        SoundManager.play(.tap)
    }

    private func restart() {
        deck = EstimationDeck.shuffled()
        index = 0
        beginQuestion()
        HapticManager.success()
    }
}
