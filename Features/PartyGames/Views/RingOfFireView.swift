//
//  RingOfFireView.swift
//  BeerStats
//
//  Ring of Fire: 52 verdeckte Karten liegen im Kreis um die Flasche. Wer
//  dran ist, zieht eine und tut, was darauf steht.
//
//  Der Ring ist nicht Deko, sondern die Anzeige des Spielstands: Man sieht
//  auf einen Blick, wie viel noch kommt, und die Luecken erzaehlen den
//  bisherigen Abend. Eine Fortschrittsleiste koennte dasselbe, waere aber
//  eine Zahl statt eines Bildes.
//
//  Die Karten behalten ihren Platz im Ring, auch wenn sie gezogen sind –
//  deshalb ein Feld fester Laenge mit Luecken statt eines schrumpfenden
//  Stapels. Ein Ring, der sich beim Ziehen zusammenschiebt, sieht jedes Mal
//  anders aus und verliert genau die Information, die ihn ausmacht.
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
    @State private var current: PlayingCard?
    @State private var flipAngle: Double = 0
    @State private var flipTask: Task<Void, Never>?

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
    private var rule: RingOfFireRule? { current.map { RingOfFireRules.rule(for: $0.rank) } }

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
            flipTask?.cancel()
            drawTask?.cancel()
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
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
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
            }
        }
    }

    // MARK: - Tisch

    private var table: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.error)

            ScrollView {
                VStack(spacing: 18) {
                    ringOfCards
                    cardPanel
                    drawButton
                    roleBoard
                }
                .padding(20)
            }
            .verticalScrollOnly()
        }
    }

    // MARK: - Der Ring

    private var ringOfCards: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let cardWidth = side * 0.045
            let cardHeight = side * 0.068
            let radius = side / 2 - cardHeight

            ZStack {
                VStack(spacing: 2) {
                    Text("🍾").font(.system(size: side * 0.17))
                    Text("\(remaining)")
                        .font(.system(size: side * 0.09, weight: .heavy, design: .rounded))
                        .foregroundStyle(BeerStatsColor.error)
                    Text("übrig")
                        .font(BeerStatsFont.statLabel)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }

                ForEach(ring.indices, id: \.self) { position in
                    if ring[position] != nil {
                        ringCard(
                            width: cardWidth,
                            height: cardHeight,
                            isLit: spotlight == position
                        )
                            // Erst nach aussen schieben, dann um die Mitte
                            // drehen: `offset` verschiebt nur die Darstellung,
                            // nicht den Rahmen – der Drehpunkt bleibt also die
                            // Mitte des Rings.
                            .offset(y: -radius)
                            .rotationEffect(.degrees(angle(for: position)))
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(height: 290)
        .animation(AppAnimation.standard, value: remaining)
    }

    private func angle(for position: Int) -> Double {
        Double(position) / Double(ring.count) * 360
    }

    /// Eine Karte im Ring. `isLit` ist der Lichtpunkt, der beim Ziehen
    /// herumwandert.
    ///
    /// Die Karten sind nicht mehr antippbar: Gezogen wird ausgelost. Wer
    /// selbst aussucht, nimmt am Ende immer die Karte vor sich – und der
    /// Ring ist ohnehin verdeckt, die Wahl war also nie eine.
    private func ringCard(width: CGFloat, height: CGFloat, isLit: Bool) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(
                isLit
                    ? LinearGradient(
                        colors: [BeerStatsColor.error, BeerStatsColor.warning],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    : LinearGradient(
                        colors: [BeerStatsColor.surfaceElevated, BeerStatsColor.backgroundPrimary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(
                        BeerStatsColor.error.opacity(isLit ? 1 : 0.65),
                        lineWidth: isLit ? 1.4 : 0.8
                    )
            )
            .shadow(color: BeerStatsColor.error.opacity(isLit ? 0.9 : 0), radius: 8)
            .frame(width: width, height: height)
            .scaleEffect(isLit ? 1.55 : 1)
            .frame(width: 26, height: 32)
    }

    // MARK: - Gezogene Karte

    @ViewBuilder
    private var cardPanel: some View {
        if let rule, let current {
            VStack(spacing: 14) {
                PlayingCardView(card: current, width: 110)
                    .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0))

                Text(rule.nickname)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .kerning(2)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                HStack(spacing: 8) {
                    Text(rule.emoji).font(.system(size: 26))
                    Text(rule.title)
                        .font(.scaled(26, weight: .heavy, design: .rounded))
                        .foregroundStyle(tint(for: rule))
                }

                Text(rule.text)
                    .font(BeerStatsFont.body)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(22)
            .glassPanel(cornerRadius: 22)
            .neonEdge(tint(for: rule), cornerRadius: 22, intensity: 0.8)

        } else if remaining == 0 {
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

        } else {
            VStack(spacing: 8) {
                Text("Reihum ziehen")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text("Der Ring lost aus. Was auf der Karte steht, gilt sofort.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
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

    private func tint(for rule: RingOfFireRule) -> Color {
        rule.role == nil ? BeerStatsColor.accent : BeerStatsColor.error
    }

    // MARK: - Merkliste

    @ViewBuilder
    private var roleBoard: some View {
        if thumbMasters + questionQueens + drinkingMates + houseRules.count > 0 {
            VStack(alignment: .leading, spacing: 10) {
                Text("LÄUFT NOCH")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
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

                Button("Alles zurücksetzen") { clearRoles() }
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
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
            Button("Ohne Notiz weiter") {
                ruleDraft = ""
                isAskingForRule = false
            }
            .font(BeerStatsFont.caption)
            .foregroundStyle(BeerStatsColor.textSecondary)

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
        flipTask?.cancel()

        withAnimation(AppAnimation.standard) { ring[position] = nil }

        // Zweistufiger Umschlag: Auf halbem Weg steht die Karte hochkant, erst
        // dort wird sie ausgetauscht. Sonst sieht man das Motiv wechseln.
        withAnimation(.easeIn(duration: 0.16)) { flipAngle = 90 }

        flipTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard !Task.isCancelled else { return }

            current = card
            flipAngle = -90
            withAnimation(.easeOut(duration: 0.18)) { flipAngle = 0 }

            apply(RingOfFireRules.rule(for: card.rank), rank: card.rank)
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
            isAskingForRule = true
        case .none:
            // Das Ass ist der einzige Rang mit einem Shot – dafür der harte
            // Ton, alles andere bleibt der leise Kartenklang. Am Rang und
            // nicht am Emoji festgemacht, damit eine Umbenennung den Klang
            // nicht stillschweigend mitnimmt.
            SoundManager.play(rank == 14 ? .bombe : .cardFlip)
        }
    }

    private func start() {
        flipTask?.cancel()
        drawTask?.cancel()
        ring = PlayingCardDeck.shuffled(count: cardCount).map { Optional($0) }
        current = nil
        flipAngle = 0
        spotlight = nil
        isDrawing = false
        clearRoles()
        hasStarted = true
        HapticManager.success()
    }

    private func restart() {
        flipTask?.cancel()
        drawTask?.cancel()
        isDrawing = false
        spotlight = nil
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
