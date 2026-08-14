//
//  NeverHaveIEverView.swift
//  BeerStats
//
//  Ich hab noch nie als Kartenstapel.
//
//  Der Stapel wird einmal gemischt und dann durchgegangen, statt jedes Mal
//  zufaellig zu ziehen. Der Unterschied ist wichtig: Beim zufaelligen Ziehen
//  kaemen Karten doppelt, bevor der Satz durch ist – und nichts bremst einen
//  Abend so zuverlaessig wie eine Frage, die schon dran war.
//
//  Strafkarten sehen bewusst voellig anders aus als Fragen. Wer vorliest,
//  greift sonst zur gewohnten Formel und macht aus einer Anweisung wieder
//  eine Frage.
//

import SwiftUI

struct NeverHaveIEverView: View {

    @State private var levels: Set<NeverHaveIEverLevel> = [.kids, .spicy]
    @State private var includePenalties = true
    @State private var deck: [NeverHaveIEverCard] = []
    @State private var index = 0
    @State private var hasStarted = false

    @State private var isFlashingPenalty = false
    @State private var flashPulse = false
    @State private var flashTask: Task<Void, Never>?

    private var currentCard: NeverHaveIEverCard? {
        deck.indices.contains(index) ? deck[index] : nil
    }

    var body: some View {
        ZStack {
            GridBackdrop(glow: currentCard?.isPenalty == true
                ? BeerStatsColor.accentSecondary
                : BeerStatsColor.success)

            VStack(spacing: 22) {
                if !hasStarted {
                    setup
                } else if let card = currentCard {
                    progressLine
                    cardView(card)
                    Spacer(minLength: 0)
                    nextButton(for: card)
                } else {
                    finishedView
                }
            }
            .padding(24)

            if isFlashingPenalty {
                penaltyFlash
                    // Liegt bewusst ueber allem und faengt Tipper ab: Ohne das
                    // klickt jemand die Strafe mit dem naechsten Antippen weg,
                    // bevor die Runde sie ueberhaupt gelesen hat.
                    .zIndex(2)
            }
        }
        .navigationTitle("Ich hab noch nie")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { flashTask?.cancel() }
    }

    /// Kurze Einblendung, wenn eine Strafkarte kommt.
    private var penaltyFlash: some View {
        ZStack {
            BeerStatsColor.backgroundPrimary.opacity(0.93)

            RadialGradient(
                colors: [BeerStatsColor.accentSecondary.opacity(0.45), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )

            VStack(spacing: 16) {
                Text("🥃")
                    .font(.system(size: 96))
                    .scaleEffect(flashPulse ? 1 : 0.4)
                    .rotationEffect(.degrees(flashPulse ? 0 : -25))

                Text("STRAFE")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .kerning(5)
                    .foregroundStyle(BeerStatsColor.accentSecondary)
                    .shadow(color: BeerStatsColor.accentSecondary.opacity(0.6), radius: 14)
                    .opacity(flashPulse ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { endPenaltyFlash() }
        .transition(.opacity)
    }

    // MARK: - Vorbereitung

    private var setup: some View {
        VStack(spacing: 18) {
            Text("🍻")
                .font(.system(size: 56))

            Text("Reihum vorlesen. Wer es schon gemacht hat, trinkt.")
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                ForEach(NeverHaveIEverLevel.allCases) { level in
                    levelToggle(level)
                }
                penaltyToggle
            }

            Spacer(minLength: 0)

            PrimaryButton(title: "Los geht's", systemImage: "play.fill") { start() }
                .opacity(levels.isEmpty ? 0.4 : 1)
                .disabled(levels.isEmpty)
        }
    }

    private func levelToggle(_ level: NeverHaveIEverLevel) -> some View {
        let isOn = levels.contains(level)

        return optionRow(
            emoji: level.emoji,
            title: level.title,
            subtitle: "\(NeverHaveIEverDeck.questionCount(for: level)) Fragen · \(level.subtitle)",
            isOn: isOn,
            tint: BeerStatsColor.success
        ) {
            // Mindestens eine Stufe muss bleiben, sonst waere der Stapel leer.
            if isOn, levels.count > 1 {
                levels.remove(level)
            } else if !isOn {
                levels.insert(level)
            }
            HapticManager.lightImpact()
        }
    }

    private var penaltyToggle: some View {
        optionRow(
            emoji: "🥃",
            title: "Strafen",
            subtitle: "Alle 5 bis 6 Karten eine Trinkstrafe",
            isOn: includePenalties,
            tint: BeerStatsColor.accentSecondary
        ) {
            includePenalties.toggle()
            HapticManager.lightImpact()
        }
    }

    private func optionRow(
        emoji: String,
        title: String,
        subtitle: String,
        isOn: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(emoji).font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                    Text(subtitle)
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isOn ? tint : BeerStatsColor.textSecondary)
            }
            .padding(16)
            .glassPanel()
            .neonEdge(tint, intensity: isOn ? 0.6 : 0.15)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Spiel

    private var progressLine: some View {
        HStack {
            Text("Karte \(index + 1) von \(deck.count)")
                .font(BeerStatsFont.statLabel)
                .foregroundStyle(BeerStatsColor.textSecondary)
            Spacer()
            Button("Neu mischen") { start() }
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    private func cardView(_ card: NeverHaveIEverCard) -> some View {
        let isPenalty = card.isPenalty
        let tint = isPenalty ? BeerStatsColor.accentSecondary : BeerStatsColor.success

        return VStack(spacing: 16) {
            Text(isPenalty ? "🥃" : (card.level?.emoji ?? "🍻"))
                .font(.system(size: 34))

            // Kein fester Vorspann mehr: Der ganze Satz steht auf der Karte,
            // weil "Ich bin noch nie" und "Ich hatte noch nie" sonst nicht
            // gehen. Hier steht deshalb nur noch die Stufe.
            Text(isPenalty ? "STRAFE" : (card.level?.title.uppercased() ?? ""))
                .font(Font.system(size: 12, weight: .heavy, design: .rounded))
                .kerning(2.4)
                .foregroundStyle(isPenalty ? tint : BeerStatsColor.textSecondary)

            Text(card.text)
                .font(.scaled(isPenalty ? 30 : 24, weight: .bold, design: .rounded))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .glassPanel(cornerRadius: 24)
        .neonEdge(tint, cornerRadius: 24, intensity: isPenalty ? 0.9 : 0.6)
        // Der Kartenwechsel schiebt seitlich – so wirkt es wie ein Stapel
        // und nicht wie ein Text, der sich austauscht.
        .id(card.id)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(AppAnimation.standard, value: card.id)
    }

    @ViewBuilder
    private func nextButton(for card: NeverHaveIEverCard) -> some View {
        // Nur Aussagen lassen sich ausblenden, keine Strafen: Deren Text
        // entsteht erst beim Anzeigen aus der eingestellten Haerte, es gibt
        // also keinen stabilen Schluessel dafuer. Gebraucht wird es auch
        // nicht – "Trink einen Shot" ist keine Karte, die am Tisch nervt.
        if !card.isPenalty {
            HideCardButton(cardKey: card.text, deck: .neverHaveIEver)
        }

        PrimaryButton(
            title: card.isPenalty ? "Erledigt" : "Nächste Karte",
            systemImage: "arrow.right"
        ) {
            // Was gleich kommt, entscheidet ueber Ton und Einblendung – nicht
            // die Karte, die gerade weggeht.
            let upcoming = deck.indices.contains(index + 1) ? deck[index + 1] : nil
            withAnimation(AppAnimation.standard) { index += 1 }

            if upcoming?.isPenalty == true {
                startPenaltyFlash()
            } else {
                HapticManager.lightImpact()
                SoundManager.play(.cardFlip)
            }
        }
    }

    private func startPenaltyFlash() {
        flashTask?.cancel()
        HapticManager.error()
        SoundManager.play(.bombe)

        // Der Ausgangswert wird ohne Animation gesetzt, sonst faengt das
        // Aufziehen beim zweiten Mal schon in der Endlage an.
        flashPulse = false
        withAnimation(AppAnimation.standard) { isFlashingPenalty = true }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.55).delay(0.04)) {
            flashPulse = true
        }

        flashTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard !Task.isCancelled else { return }
            endPenaltyFlash()
        }
    }

    private func endPenaltyFlash() {
        flashTask?.cancel()
        withAnimation(AppAnimation.smoothFade) { isFlashingPenalty = false }
    }

    private var finishedView: some View {
        VStack(spacing: 18) {
            Text("🏁").font(.system(size: 60))
            Text("Stapel durch")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
            Text("\(deck.count) Karten gespielt. Neu mischen für die nächste Runde.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            PrimaryButton(title: "Neu mischen", systemImage: "shuffle") { start() }
            Button("Einstellungen ändern") { hasStarted = false }
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    private func start() {
        deck = NeverHaveIEverDeck.shuffled(levels: levels, includePenalties: includePenalties)
        index = 0
        hasStarted = true
        HapticManager.success()
    }
}
