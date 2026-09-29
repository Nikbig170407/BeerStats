//
//  GameSetupScreen.swift
//  BeerStats
//
//  Der Bildschirm VOR dem Spiel: einstellen, dann starten.
//
//  Bisher fing jedes Spiel sofort an und fragte unterwegs nach, was es noch
//  wissen musste – die Spielerzahl mitten im Screen, die Kartenzahl gar
//  nicht. Am Tisch heisst das: Man startet, merkt, dass es nicht passt, und
//  geht zurueck.
//
//  Deshalb ein gemeinsamer Baustein statt eines eigenen Vorspanns je Spiel.
//  Er gibt Kopf, Abstaende und den Startknopf vor; was dazwischen steht,
//  bringt das Spiel selbst mit. Wer einen zweiten Vorspann von Hand baut,
//  laesst ihn anders aussehen – genau so sind `PlayerCountStepper` und
//  `HandoffPanel` entstanden, jeweils nach der vierten Kopie.
//

import SwiftUI

struct GameSetupScreen<Content: View>: View {

    let emoji: String
    let title: String
    /// Ein Satz dazu, was hier entschieden wird – nicht die Spielregeln.
    let subtitle: String
    var tint: Color = BeerStatsColor.accent
    var startTitle: String = "Los geht's"
    var isStartDisabled: Bool = false
    let onStart: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: tint)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    content()
                }
                .padding(20)
                .padding(.bottom, 12)
            }
            .verticalScrollOnly()
        }
        // Der Startknopf klebt unten: Er ist das Ziel des Screens und soll
        // nicht ans Ende einer Liste rutschen, die laenger wird, sobald ein
        // Spiel mehr einzustellen hat.
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: startTitle, systemImage: "play.fill") {
                onStart()
            }
            .opacity(isStartDisabled ? 0.4 : 1)
            .disabled(isStartDisabled)
            .padding(20)
            .background(
                LinearGradient(
                    colors: [
                        BeerStatsColor.backgroundPrimary.opacity(0),
                        BeerStatsColor.backgroundPrimary
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emoji).font(.system(size: 46))

            Text(title)
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text(subtitle)
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Auswahl aus wenigen Werten

/// Ein Wert in einer `ChoiceRow`.
struct ChoiceOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    /// Zweite Zeile, klein. Fuer die Folge der Wahl, nicht fuer eine
    /// Wiederholung des Titels.
    var detail: String? = nil

    var id: Value { value }
}

/// Gleich breite Knoepfe nebeneinander – eine Wahl, sofort sichtbar.
///
/// Dasselbe Muster stand schon dreimal im Projekt (Haerte, Extreme-Modus,
/// Becherzahl), jedes Mal mit anderen Radien und Groessen. Ab hier gibt es
/// einen Baustein dafuer.
struct ChoiceRow<Value: Hashable>: View {

    let options: [ChoiceOption<Value>]
    @Binding var selection: Value
    var tint: Color = BeerStatsColor.accent

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                button(for: option)
            }
        }
    }

    private func button(for option: ChoiceOption<Value>) -> some View {
        let isOn = selection == option.value

        return Button {
            selection = option.value
            HapticManager.lightImpact()
        } label: {
            VStack(spacing: 2) {
                Text(option.title)
                    .font(BeerStatsFont.headline)
                if let detail = option.detail {
                    Text(detail)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(isOn ? BeerStatsColor.textOnAccent : BeerStatsColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isOn ? tint : BeerStatsColor.surfaceElevated.opacity(0.6),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
