//
//  HandoffPanel.swift
//  BeerStats
//
//  Das Handy wandert reihum: uebernehmen, aufdecken, weitergeben.
//
//  Zwei Spiele brauchen denselben Ablauf, weil beide ein Geheimnis pro
//  Person verteilen – der Spion seine Rolle, Verbotene Woerter das Wort.
//  Beide standen fast gleich da, und "fast" ist hier das Problem: Die
//  Kartenmasse war identisch, nur eine der beiden Deckseiten war zentriert.
//
//  Wichtig ist die Zwischenstufe. Ohne die verdeckte Seite laege das
//  Geheimnis schon auf dem Bildschirm, waehrend das Handy noch durch die
//  Runde geht – der Nebenmann liest mit, und das Spiel ist vorbei, bevor es
//  angefangen hat. Deshalb ist `isRevealed` ein Zustand des Aufrufers und
//  nicht eine interne Sache: Er gehoert in die Phase des Spiels, damit ein
//  Neuzeichnen ihn nicht versehentlich auf "aufgedeckt" zuruecksetzt.
//

import SwiftUI

struct HandoffPanel<Secret: View>: View {

    private let player: Int
    private let isRevealed: Bool
    private let tint: Color
    private let continueTitle: String
    private let onReveal: () -> Void
    private let onContinue: () -> Void
    private let secret: Secret

    init(
        player: Int,
        isRevealed: Bool,
        tint: Color,
        continueTitle: String,
        onReveal: @escaping () -> Void,
        onContinue: @escaping () -> Void,
        @ViewBuilder secret: () -> Secret
    ) {
        self.player = player
        self.isRevealed = isRevealed
        self.tint = tint
        self.continueTitle = continueTitle
        self.onReveal = onReveal
        self.onContinue = onContinue
        self.secret = secret()
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Spieler \(player + 1)")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            if isRevealed {
                VStack(spacing: 12) { secret }
                    .frame(maxWidth: .infinity)
                    .padding(26)
                    .glassPanel(cornerRadius: 22)
                    .neonEdge(tint, cornerRadius: 22, intensity: 0.8)

                PrimaryButton(title: continueTitle, systemImage: "arrow.right", action: onContinue)
            } else {
                coverCard

                PrimaryButton(title: "Aufdecken", systemImage: "eye.fill") {
                    onReveal()
                    // Kraeftiger als der Standard-Tap von PrimaryButton: Das
                    // Aufdecken ist der Moment, in dem man das Handy schon in
                    // der Hand hat und hinsehen soll.
                    HapticManager.mediumImpact()
                    SoundManager.play(.tap)
                }
            }
        }
    }

    private var coverCard: some View {
        VStack(spacing: 10) {
            Text("🤫").font(.system(size: 54))

            Text("Handy übernehmen, dann aufdecken.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .glassPanel(cornerRadius: 22)
    }
}
