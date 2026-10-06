//
//  TermRow.swift
//  BeerStats
//
//  Eine Bedingung auf einer Karte: Symbol, Beschriftung, Wert.
//
//  „Wie lange gilt das" und „was kostet es, wenn ich verliere" sind die zwei
//  Fragen, die am Tisch gestellt werden, bevor jemand weitermacht. Sie
//  stehen auf Extreme-Karten und auf Ring-of-Fire-Karten – und sollen dort
//  gleich aussehen, sonst wirkt dieselbe Information wie zweierlei.
//
//  Die Zeile steht bewusst nicht in einer der beiden Kartenansichten,
//  sondern hier: Sie war die zweite Kopie, und zwei Kopien laufen
//  auseinander. Genau so sind `PlayerCountStepper` und `HandoffPanel`
//  entstanden, nur spaeter.
//

import SwiftUI

struct TermRow: View {

    let systemImage: String
    /// Kurz und in Grossbuchstaben – „WIE LANGE", „STRAFE".
    let label: String
    let value: String
    var tint: Color = BeerStatsColor.textSecondary

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 16)

            Text(label.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .kerning(1.2)
                .foregroundStyle(BeerStatsColor.textSecondary)

            Text(value)
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            BeerStatsColor.surfaceElevated.opacity(0.6),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
    }
}
