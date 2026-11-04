//
//  EstimationKeypad.swift
//  BeerStats
//
//  Der Ziffernblock fuer den Schaetzmeister mit Aufschreiben.
//
//  Ein eigener statt der Tastatur des iPhones: Die schiebt sich ueber die
//  halbe Frage, hat das Komma je nach Sprache an anderer Stelle und kennt
//  keine Frage, bei der es gar keins geben darf. Hier fehlt es dann einfach
//  – der Platz bleibt leer, damit die Tasten nicht von Frage zu Frage
//  woanders liegen.
//

import SwiftUI

/// Die getippte Zahl, gross, mit der Einheit dahinter.
struct EstimationDisplay: View {

    let text: String
    let unit: String

    @Environment(\.gameWorld) private var world

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(text.isEmpty ? "–" : text)
                .font(.scaled(36, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(text.isEmpty ? BeerStatsColor.textSecondary : QuizShow.bulb)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if !unit.isEmpty {
                Text(unit)
                    .font(Font.world(world, 17, weight: .bold))
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct EstimationKeypad: View {

    let allowsDecimals: Bool
    let onDigit: (Int) -> Void
    let onComma: () -> Void
    let onDelete: () -> Void

    /// Apples Mindestgroesse fuer einen Tipp, mit etwas Luft: Am Tisch wird
    /// nicht gezielt getippt.
    private static let keyHeight: CGFloat = 50
    private static let spacing: CGFloat = 8

    var body: some View {
        VStack(spacing: Self.spacing) {
            ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { reihe in
                HStack(spacing: Self.spacing) {
                    ForEach(reihe, id: \.self) { ziffer in
                        key(String(ziffer), label: String(ziffer)) { onDigit(ziffer) }
                    }
                }
            }
            HStack(spacing: Self.spacing) {
                if allowsDecimals {
                    key(",", label: "Komma", action: onComma)
                } else {
                    Color.clear.frame(maxWidth: .infinity, minHeight: Self.keyHeight)
                }
                key("0", label: "0") { onDigit(0) }
                key(systemImage: "delete.left", label: "Löschen", action: onDelete)
            }
        }
    }

    private func key(_ text: String, label: String, action: @escaping () -> Void) -> some View {
        keyButton(label: label, action: action) {
            Text(text)
                .font(.scaled(24, weight: .heavy, design: .rounded))
        }
    }

    private func key(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        keyButton(label: label, action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
        }
    }

    /// Hintergrund und Trefferflaeche im Label, nicht daneben – sonst
    /// reagiert nur die Ziffer selbst (Lessons Learned Nr. 4).
    private func keyButton<Inhalt: View>(
        label: String,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Inhalt
    ) -> some View {
        let inhalt = content()
        return Button {
            HapticManager.lightImpact()
            action()
        } label: {
            inhalt
                .foregroundStyle(BeerStatsColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: Self.keyHeight)
                .background(BeerStatsColor.surfaceElevated.opacity(0.75),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(label)
    }
}
