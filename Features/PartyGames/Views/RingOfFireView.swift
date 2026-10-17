//
//  RingOfFireView.swift
//  BeerStats
//
//  Ring of Fire: 52 verdeckte Karten liegen im Kreis um die Flasche. Wer
//  dran ist, zieht eine und tut, was darauf steht.
//
//  Der Ring ist nicht Deko, sondern spielt mit. Die Karten liegen zufaellig
//  verteilt und GESCHUPPT – jede ein Stueck unter der naechsten, wie am
//  echten Tisch. Daraus kommt die Regel, die dem Spiel seinen Namen gibt:
//  Wer den Ring reisst, trinkt einen Shot. Gerissen ist er, wenn die beiden
//  Nachbarinnen der gezogenen Karte sich danach nicht mehr beruehren
//  (`RingLayout.tearsRing`).
//
//  Vorher lagen die Karten in gleichen Abstaenden mit Luft dazwischen, und
//  die Regel gab es gar nicht – es war ein Stapel, den jemand im Kreis
//  angeordnet hatte. Der Ring sah aus wie der Ring und tat nichts.
//
//  Die Karten behalten ihren Platz, auch wenn sie gezogen sind – deshalb ein
//  Feld fester Laenge mit Luecken statt eines schrumpfenden Stapels. Die
//  Luecken sind gleichzeitig die Anzeige des Spielstands und die Landkarte
//  der Gefahr: Wo schon ein Loch ist, kann nichts mehr reissen, und das
//  sieht man.
//
//  Vier Raenge wirken weiter, nachdem die Karte gezogen wurde. Sie landen in
//  der Merkliste unter dem Ring, weil sie sonst mit der naechsten Karte aus
//  dem Blick und aus dem Sinn waeren.
//

import SwiftUI

struct RingOfFireView: View {

    /// Wie viele Karten im Ring liegen. Bleibt gespeichert – wer kurze
    /// Runden mag, mag sie auch naechste Woche.
    @AppStorage("ringOfFire.cardCount") private var cardCount = PlayingCardDeck.fullSize

    /// Vor dem Start steht die Vorbereitung, danach der Tisch.
    @State private var hasStarted = false

    /// `nil` bedeutet: Platz im Ring, Karte schon gezogen.
    @State private var ring: [PlayingCard?] = []
    /// Wo die Karten liegen – zufaellig gestreut, teils ueberlappend.
    @State private var layout = RingLayout.random(count: PlayingCardDeck.fullSize)
    @State private var current: PlayingCard?

    /// Die Stelle, an der der Ring gerade gerissen ist – fuer das
    /// Aufblitzen im Ring. Verblasst von selbst.
    @State private var tornAt: Int?
    /// Hat der ZULETZT gezogene Zug gerissen? Steht getrennt, weil der
    /// Aktionsscreen laenger offen ist als das Aufblitzen dauert.
    @State private var currentTore = false
    @State private var tearPulse = false
    @State private var tearTask: Task<Void, Never>?

    /// Der zweite Screen – die gezogene Karte in Gross.
    @State private var showsAction = false
    /// Steht die Hausregel-Frage noch aus? Sie kommt erst NACH dem
    /// Aktionsscreen: Erst liest man die Karte zu Ende, dann tippt man.
    @State private var needsRulePrompt = false

    /// Die Karte, auf der das Licht gerade steht, waehrend gezogen wird.
    @State private var spotlight: Int?
    @State private var isDrawing = false
    @State private var drawTask: Task<Void, Never>?

    // Laufende Rollen. Als Zaehler, weil jede weitere Karte desselben Rangs
    // eine weitere Person in dieselbe Rolle bringt – am Tisch liegen dann
    // eben zwei Buben vor zwei Leuten.
    @State private var thumbMasters = 0
    @State private var questionQueens = 0
    @State private var drinkingMates = 0
    @State private var houseRules: [String] = []

    @State private var isAskingForRule = false
    @State private var ruleDraft = ""

    private var remaining: Int { ring.compactMap { $0 }.count }

    var body: some View {
        Group {
            if hasStarted {
                table
            } else {
                setup
            }
        }
        .navigationTitle("Ring of Fire")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            drawTask?.cancel()
            tearTask?.cancel()
        }
        .sheet(isPresented: $isAskingForRule) {
            rulePrompt
        }
    }

    // MARK: - Vorbereitung

    private var setup: some View {
        GameSetupScreen(
            emoji: "🔥",
            title: "Ring of Fire",
            subtitle: "Wie lang soll die Runde werden?",
            tint: BeerStatsColor.error,
            onStart: start
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("KARTEN IM RING")
                    .font(.scaled(11, weight: .heavy, design: .rounded))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                ChoiceRow(
                    options: [
                        ChoiceOption(value: 20, title: "20", detail: "kurz"),
                        ChoiceOption(value: 32, title: "32", detail: "mittel"),
                        ChoiceOption(value: PlayingCardDeck.fullSize, title: "52", detail: "ganzer Stapel")
                    ],
                    selection: $cardCount,
                    tint: BeerStatsColor.error
                )

                Text("Die Karten kommen aus dem gemischten Stapel. In einer kurzen Runde kommt deshalb nicht jede Regel vor – welche fehlt, weiß vorher niemand.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Die Karten liegen geschuppt im Kreis, jede ein Stück unter der nächsten. Reißt dein Zug den Ring – berühren sich die Nachbarn danach nicht mehr –, kostet dich das \(DrinkAmount.shot.text). Wo schon eine Lücke ist, kann nichts mehr reißen.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DrinkIntensityPicker(game: .ringOfFire)
        }
    }

    // MARK: - Tisch

    private var table: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.error)

            ScrollView {
                VStack(spacing: 18) {
                    ringOfCards
                    emptyRingPanel
                    drawButton
                    roleBoard
                }
                .padding(20)
            }
            .verticalScrollOnly()
        }
        // Vollbild statt Blatt: In dem Moment zaehlt nur, was auf der Karte
        // steht. Der Ring darunter wuerde nur ablenken.
        .fullScreenCover(isPresented: $showsAction) {
            if let current {
                RingOfFireActionView(
                    card: current,
                    rule: RingOfFireRules.rule(for: current.rank),
                    tore: currentTore
                ) {
                    showsAction = false
                }
            }
        }
        // Die Hausregel wird erst danach eingetippt – ein Textfeld ueber der
        // Karte haette man gelesen, bevor man die Karte gelesen hat.
        .onChange(of: showsAction) { istOffen in
            guard !istOffen, needsRulePrompt else { return }
            needsRulePrompt = false
            isAskingForRule = true
        }
    }

    // MARK: - Der Ring

    private var ringOfCards: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)

            // Die Kartenbreite folgt dem Layout, nicht umgekehrt: Wie viel
            // Platz eine Karte im Kreis einnimmt, steht in `cardSpan`, und
            // genau damit wird auch gerechnet, ob der Ring reisst. Waere die
            // Breite frei gewaehlt, sehe man eine Ueberlappung und es gaelte
            // eine andere – ein Bild, das luegt.
            //
            // Radius und Hoehe haengen voneinander ab (die Karten ragen nach
            // innen, der Radius muss das lassen). Einmal aufgeloest:
            //   r = (side/2) / (1 + 2 * 1.45 * 0.75 * sin(span/2))
            let halbeSpanne = CGFloat(sin(layout.cardSpan / 2 * .pi / 180))
            let radius = (side / 2) / (1 + 2.175 * halbeSpanne)
            let cardWidth = 2 * radius * halbeSpanne
            let cardHeight = cardWidth * 1.45
            // Was in der Mitte frei bleibt. Bei zwanzig Karten liegt der Ring
            // als dichter Kranz und das Loch ist klein – dann steht dort nur
            // noch die Zahl.
            let innen = radius - cardHeight / 2

            ZStack {
                VStack(spacing: 2) {
                    if innen > 56 {
                        Text("🍾").font(.system(size: innen * 0.5))
                    }
                    Text("\(remaining)")
                        .font(.system(size: innen * 0.45, weight: .heavy, design: .rounded))
                        .foregroundStyle(BeerStatsColor.error)
                        .monospacedDigit()
                    if innen > 56 {
                        Text("übrig")
                            .font(BeerStatsFont.statLabel)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                    }
                }

                ForEach(ring.indices, id: \.self) { position in
                    ringCard(
                        width: cardWidth,
                        height: cardHeight,
                        isLit: spotlight == position,
                        isEmpty: ring[position] == nil,
                        isTorn: tornAt == position
                    )
                        // Erst nach aussen schieben, dann um die Mitte
                        // drehen: `offset` verschiebt nur die Darstellung,
                        // nicht den Rahmen – der Drehpunkt bleibt also die
                        // Mitte des Rings.
                        .offset(y: -radius)
                        .rotationEffect(.degrees(angle(for: position)))
                        // Muss sein, seit die Karten sich ueberlappen: Der
                        // Lichtpunkt und der Riss liegen sonst unter der
                        // naechsten Karte, weil ein ZStack in
                        // Reihenfolge zeichnet – und genau die beiden sind
                        // das, was man sehen soll.
                        .zIndex(spotlight == position || tornAt == position ? 1 : 0)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            // Der Ruck beim Reissen. Kurz und klein – der Ring soll zucken,
            // nicht wegfliegen.
            .scaleEffect(tearPulse ? 1.04 : 1)
            .rotationEffect(.degrees(tearPulse ? 1.5 : 0))
        }
        // Nimmt sich die volle Breite und bleibt quadratisch: Der Ring ist
        // der Screen, nicht eine Zeile darin.
        .aspectRatio(1, contentMode: .fit)
        .animation(AppAnimation.standard, value: remaining)
    }

    /// Kommt aus dem Layout, nicht aus der Position: Die Karten liegen
    /// gestreut, nicht in gleichen Abstaenden.
    private func angle(for position: Int) -> Double {
        layout.angles.indices.contains(position) ? layout.angles[position] : 0
    }

    /// Eine Karte im Ring.
    ///
    /// `isEmpty` ist der freie Platz einer gezogenen Karte. Er bleibt
    /// stehen, statt zu verschwinden: Die Luecken sind die Anzeige des
    /// Spielstands – man sieht auf einen Blick, wie viel schon durch ist.
    /// Ein Ring, der sich beim Ziehen zusammenschiebt, verliert genau diese
    /// Information.
    ///
    /// `isLit` ist der Lichtpunkt, der beim Ziehen herumwandert. Die Karten
    /// sind nicht antippbar: Gezogen wird ausgelost.
    ///
    /// `isTorn` ist die Stelle, an der der Ring gerade gerissen ist. Sie
    /// leuchtet kurz auf – die Luecke selbst bleibt danach als normale
    /// Luecke stehen, denn gerissen wird sie nur einmal.
    private func ringCard(
        width: CGFloat,
        height: CGFloat,
        isLit: Bool,
        isEmpty: Bool,
        isTorn: Bool
    ) -> some View {
        RoundedRectangle(cornerRadius: max(2, width * 0.18), style: .continuous)
            .fill(
                isEmpty
                    ? LinearGradient(
                        colors: [Color.clear, Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    : (isLit
                        ? LinearGradient(
                            colors: [BeerStatsColor.error, BeerStatsColor.warning],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        : LinearGradient(
                            colors: [BeerStatsColor.surfaceElevated, BeerStatsColor.backgroundPrimary],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: max(2, width * 0.18), style: .continuous)
                    .strokeBorder(
                        BeerStatsColor.error.opacity(isEmpty ? 0.22 : (isLit ? 1 : 0.7)),
                        style: StrokeStyle(
                            lineWidth: isEmpty ? 1 : (isLit ? 1.8 : 1.1),
                            dash: isEmpty ? [2.5, 2.5] : []
                        )
                    )
            )
            .overlay(
                // Der Riss: ein kurzer heller Blitz genau dort, wo die Karte
                // lag. Liegt ueber der gestrichelten Luecke, damit man die
                // Stelle findet, ohne sie zu suchen.
                RoundedRectangle(cornerRadius: max(2, width * 0.18), style: .continuous)
                    .fill(BeerStatsColor.warning)
                    .blur(radius: width * 0.3)
                    .opacity(isTorn ? 0.9 : 0)
            )
            .shadow(
                color: isTorn
                    ? BeerStatsColor.warning.opacity(0.95)
                    : BeerStatsColor.error.opacity(isLit ? 0.9 : 0),
                radius: isTorn ? 18 : 10
            )
            .frame(width: width, height: height)
            .scaleEffect(isLit ? 1.45 : 1)
    }

    // MARK: - Ring durch

    /// Steht nur da, wenn nichts mehr liegt. Alles andere zur gezogenen
    /// Karte passiert auf dem zweiten Screen.
    @ViewBuilder
    private var emptyRingPanel: some View {
        if remaining == 0 {
            VStack(spacing: 14) {
                Text("🔥").font(.system(size: 54))
                Text("Ring durch")
                    .font(BeerStatsFont.title)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                // Zurueck in die Vorbereitung statt sofort neu: Nach einer
                // durchgespielten Runde ist genau der Moment, in dem jemand
                // "diesmal kuerzer" sagt.
                PrimaryButton(title: "Neuer Ring", systemImage: "shuffle") { restart() }
            }
            .frame(maxWidth: .infinity)
            .padding(22)
            .glassPanel(cornerRadius: 22)
        }
    }

    @ViewBuilder
    private var drawButton: some View {
        if remaining > 0 {
            PrimaryButton(
                title: isDrawing ? "Läuft …" : "Karte ziehen",
                systemImage: isDrawing ? "hourglass" : "hand.tap.fill"
            ) {
                drawRandom()
            }
            .opacity(isDrawing ? 0.5 : 1)
            .disabled(isDrawing)
        }
    }

    // MARK: - Merkliste

    @ViewBuilder
    private var roleBoard: some View {
        if thumbMasters + questionQueens + drinkingMates + houseRules.count > 0 {
            VStack(alignment: .leading, spacing: 10) {
                Text("LÄUFT NOCH")
                    .font(.scaled(11, weight: .heavy, design: .rounded))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                HStack(spacing: 8) {
                    if thumbMasters > 0 { roleChip(.thumbMaster, count: thumbMasters) }
                    if questionQueens > 0 { roleChip(.questionQueen, count: questionQueens) }
                    if drinkingMates > 0 { roleChip(.drinkingMate, count: drinkingMates) }
                    Spacer(minLength: 0)
                }

                ForEach(Array(houseRules.enumerated()), id: \.offset) { number, text in
                    HStack(alignment: .top, spacing: 8) {
                        Text("📜")
                        Text(text)
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button {
                            houseRules.remove(at: number)
                            HapticManager.lightImpact()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(BeerStatsColor.textSecondary)
                        }
                    }
                }

                QuietButton(title: "Alles zurücksetzen") { clearRoles() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassPanel(cornerRadius: 18)
        }
    }

    private func roleChip(_ role: RingOfFireRole, count: Int) -> some View {
        HStack(spacing: 5) {
            Text(role.emoji)
            Text(count > 1 ? "\(role.title) ×\(count)" : role.title)
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            BeerStatsColor.error.opacity(0.16),
            in: Capsule()
        )
    }

    // MARK: - Regel notieren

    private var rulePrompt: some View {
        VStack(spacing: 18) {
            Text("📜").font(.system(size: 48))

            Text("Welche Regel gilt ab jetzt?")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)

            TextField("z. B. Niemand darf Namen sagen", text: $ruleDraft)
                .textFieldStyle(.plain)
                .padding(14)
                .glassPanel(cornerRadius: 14)
                .submitLabel(.done)
                .onSubmit { saveRule() }

            PrimaryButton(title: "Merken", systemImage: "checkmark") { saveRule() }
                .disabled(ruleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(ruleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)

            // Aufschreiben ist freiwillig: Am Tisch wird die Regel ohnehin
            // ausgesprochen, und ein Pflichtfeld haelt das Spiel auf.
            QuietButton(title: "Ohne Notiz weiter") {
                ruleDraft = ""
                isAskingForRule = false
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    private func saveRule() {
        let text = ruleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        houseRules.append(text)
        ruleDraft = ""
        isAskingForRule = false
        HapticManager.success()
    }

    // MARK: - Ablauf

    private func draw(at position: Int) {
        guard let card = ring[position] else { return }

        // Vor dem Entfernen fragen: Danach liegt die Karte nicht mehr, und
        // die Frage "reisst das den Ring?" waere nicht mehr zu stellen.
        let reisst = layout.tearsRing(at: position, present: ring.map { $0 != nil })

        withAnimation(AppAnimation.standard) { ring[position] = nil }

        current = card
        currentTore = reisst
        apply(RingOfFireRules.rule(for: card.rank), rank: card.rank)

        if reisst {
            tear(at: position)
        } else if remaining == 0 {
            // Die letzte Karte ohne Riss: Der Ring ist heil durchgespielt,
            // und das ist am Tisch eine Meldung wert.
            SoundManager.play(.victory)
        }

        showsAction = true
    }

    /// Der Ring ist gerissen: Blitz, Ruck, Knall – und der Shot steht
    /// danach auf dem Aktionsscreen.
    ///
    /// Der Klang kommt hier und nicht in `apply`: Ein Riss schlaegt jeden
    /// Kartenklang, und zwei Toene gleichzeitig sind einer zu viel.
    private func tear(at position: Int) {
        tearTask?.cancel()
        tornAt = position

        HapticManager.error()
        SoundManager.play(.bombe)
        SpeechAnnouncer.announce("Ring gerissen")

        tearTask = Task { @MainActor in
            withAnimation(.spring(response: 0.18, dampingFraction: 0.35)) { tearPulse = true }
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.6)) { tearPulse = false }

            // Der Blitz bleibt laenger als der Ruck: Er muss den
            // Aktionsscreen ueberleben, damit man die Stelle beim
            // Zurueckkommen noch findet.
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(AppAnimation.standard) { tornAt = nil }
        }
    }

    private func apply(_ rule: RingOfFireRule, rank: Int) {
        HapticManager.mediumImpact()

        switch rule.role {
        case .thumbMaster:
            thumbMasters += 1
            SoundManager.play(.onFire)
        case .questionQueen:
            questionQueens += 1
            SoundManager.play(.onFire)
        case .drinkingMate:
            drinkingMates += 1
            SoundManager.play(.ballsBack)
        case .houseRule:
            SoundManager.play(.reRack)
            // Nicht sofort: Erst liest man die Karte zu Ende, dann tippt
            // man. Ausgeloest wird die Frage beim Schliessen des
            // Aktionsscreens.
            needsRulePrompt = true
        case .none:
            // Das Ass ist der einzige Rang mit einem Shot – dafür der harte
            // Ton, alles andere bleibt der leise Kartenklang. Am Rang und
            // nicht am Emoji festgemacht, damit eine Umbenennung den Klang
            // nicht stillschweigend mitnimmt.
            SoundManager.play(rank == 14 ? .bombe : .cardFlip)
        }
    }

    private func start() {
        drawTask?.cancel()
        tearTask?.cancel()
        ring = PlayingCardDeck.shuffled(count: cardCount).map { Optional($0) }
        // Jede Runde wird neu ausgelegt: Dieselben Karten an denselben
        // Stellen hiesse, dass auch dieselben Stellen reissen – und nach
        // zwei Abenden wuesste man, wo.
        layout = RingLayout.random(count: ring.count)
        current = nil
        currentTore = false
        spotlight = nil
        tornAt = nil
        tearPulse = false
        isDrawing = false
        clearRoles()
        hasStarted = true
        HapticManager.success()
        SoundManager.play(.reRack)
    }

    private func restart() {
        drawTask?.cancel()
        tearTask?.cancel()
        isDrawing = false
        spotlight = nil
        tornAt = nil
        tearPulse = false
        hasStarted = false
    }

    /// Lost eine der noch liegenden Karten aus und laesst das Licht dorthin
    /// laufen.
    private func drawRandom() {
        guard !isDrawing else { return }

        let liegende = ring.indices.filter { ring[$0] != nil }
        guard let ziel = liegende.randomElement() else { return }

        isDrawing = true
        drawTask?.cancel()
        drawTask = Task { @MainActor in
            await runSpotlight(to: ziel, over: liegende)
            guard !Task.isCancelled else { return }
            spotlight = nil
            isDrawing = false
            draw(at: ziel)
        }
    }

    /// Der Lichtpunkt laeuft im Uhrzeigersinn ueber die liegenden Karten und
    /// wird zum Schluss langsamer, bis er auf der gezogenen stehen bleibt.
    ///
    /// Die Schrittzahl ist so gewaehlt, dass der letzte Schritt genau auf der
    /// Zielkarte landet – das Licht haelt also dort an, wo die Karte
    /// tatsaechlich herkommt. Es sieht nicht nur nach Auslosung aus, es ist
    /// die Auslosung.
    private func runSpotlight(to target: Int, over positions: [Int]) async {
        guard let zielIndex = positions.firstIndex(of: target) else {
            spotlight = target
            return
        }

        // Eine volle Runde plus der Weg zum Ziel. Bei wenigen Karten waere das
        // ein Zucken statt einer Drehung – deshalb so lange weitere Runden
        // dazu, bis es nach etwas aussieht. Vielfache der Rundenlaenge
        // erhalten dabei, dass der letzte Schritt auf dem Ziel landet.
        var schritte = positions.count + zielIndex
        while schritte < 16 { schritte += positions.count }

        for schritt in 0...schritte {
            guard !Task.isCancelled else { return }

            spotlight = positions[schritt % positions.count]

            // Die letzten Schritte bremsen spuerbar ab – das ist der ganze
            // Trick am Gluecksrad. Davor laeuft es gleichmaessig schnell.
            let restlich = schritte - schritt
            let dauer: Double
            if restlich > 14 {
                dauer = 0.012
            } else {
                dauer = 0.05 + 0.25 * (Double(14 - restlich) / 14)
                HapticManager.lightImpact()
                // Das Ticken der letzten Schritte. Leise (`tap` ist auf ein
                // Drittel abgemischt) und nur im Auslaufen – auf jedem der
                // schnellen Schritte waere es ein Rauschen.
                SoundManager.play(.tap)
            }

            try? await Task.sleep(nanoseconds: UInt64(dauer * 1_000_000_000))
        }
    }

    private func clearRoles() {
        thumbMasters = 0
        questionQueens = 0
        drinkingMates = 0
        houseRules.removeAll()
    }
}
