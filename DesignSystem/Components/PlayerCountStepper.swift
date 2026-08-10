//
//  PlayerCountStepper.swift
//  BeerStats
//
//  Minus, Zahl, Plus – die Spielerzahl einstellen.
//
//  Stand fuenfmal fast gleich im Projekt: bei Spion, Verbotene Woerter,
//  Maexchen, Schocken und im Turnier. Fuenf Kopien heissen fuenf Stellen,
//  an denen eine Aenderung vergessen wird, und sie waren bereits leicht
//  auseinandergelaufen – unterschiedliche Groessen, unterschiedliche
//  Eckenradien, obwohl sie dasselbe tun.
//
//  Bewusst NICHT `Stepper` aus SwiftUI: Der ist fuer Einstellungslisten
//  gemacht und hat Trefferflaechen, die man am Tisch mit einem Bier in der
//  Hand nicht zuverlaessig trifft.
//

import SwiftUI

struct PlayerCountStepper: View {

    @Binding var count: Int
    var range: ClosedRange<Int> = 2...12
    var tint: Color = BeerStatsColor.accent

    var body: some View {
        HStack(spacing: 14) {
            button("−", enabled: count > range.lowerBound) {
                count = max(range.lowerBound, count - 1)
            }

            Text("\(count)")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .frame(minWidth: 78)
                .monospacedDigit()

            button("+", enabled: count < range.upperBound) {
                count = min(range.upperBound, count + 1)
            }
        }
        .animation(AppAnimation.tap, value: count)
    }

    private func button(_ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard enabled else { return }
            action()
            HapticManager.lightImpact()
        } label: {
            Text(label)
                .font(.system(size: 29, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .frame(width: 60, height: 60)
                .glassPanel(cornerRadius: 18)
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        // Am Rand des erlaubten Bereichs bleibt der Knopf sichtbar, reagiert
        // aber nicht mehr – das erklaert die Grenze, statt sie zu verstecken.
        .opacity(enabled ? 1 : 0.3)
    }
}
