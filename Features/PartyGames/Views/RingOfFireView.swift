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

    /// `nil` bedeutet: Platz im Ring, Karte schon gezogen.
    @State private var ring: [PlayingCard?] = PlayingCardDeck.shuffled().map { Optional($0) }
    @State private var current: PlayingCard?
    @State private var flipAngle: Double = 0
    @State private var flipTask: Task<Void, Never>?

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
        ZStack {
            GridBackdrop(glow: BeerStatsColor.error)

            ScrollView {
                VStack(spacing: 18) {
                    ringOfCards
                    cardPanel
                    roleBoard
                }
                .padding(20)
            }
        }
        .navigationTitle("Ring of Fire")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { flipTask?.cancel() }
        .sheet(isPresented: $isAskingForRule) {
            rulePrompt
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
                        ringCard(width: cardWidth, height: cardHeight)
                            // Erst nach aussen schieben, dann um die Mitte
                            // drehen: `offset` verschiebt nur die Darstellung,
                            // nicht den Rahmen – der Drehpunkt bleibt also die
                            // Mitte des Rings.
                            .offset(y: -radius)
                            .rotationEffect(.degrees(angle(for: position)))
                            .onTapGesture { draw(at: position) }
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

    private func ringCard(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [BeerStatsColor.surfaceElevated, BeerStatsColor.backgroundPrimary],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(BeerStatsColor.error.opacity(0.65), lineWidth: 0.8)
            )
            .frame(width: width, height: height)
            // Die Trefferflaeche ist bewusst groesser als die Karte. Bei 52
            // Karten auf dem Kreis waere sie sonst schmaler als ein Daumen –
            // und weil alle verdeckt liegen, ist ein Danebentippen ohnehin
            // folgenlos.
            .frame(width: 26, height: 32)
            .contentShape(Rectangle())
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
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
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
                PrimaryButton(title: "Neuer Ring", systemImage: "shuffle") { restart() }
            }
            .frame(maxWidth: .infinity)
            .padding(22)
            .glassPanel(cornerRadius: 22)

        } else {
            VStack(spacing: 8) {
                Text("Tipp eine Karte im Ring an")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text("Reihum. Was auf der Karte steht, gilt sofort.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(22)
            .glassPanel(cornerRadius: 22)
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
            SoundManager.play(rank == 14 ? .bombe : .cupHit)
        }
    }

    private func restart() {
        flipTask?.cancel()
        ring = PlayingCardDeck.shuffled().map { Optional($0) }
        current = nil
        flipAngle = 0
        clearRoles()
        HapticManager.success()
    }

    private func clearRoles() {
        thumbMasters = 0
        questionQueens = 0
        drinkingMates = 0
        houseRules.removeAll()
    }
}
