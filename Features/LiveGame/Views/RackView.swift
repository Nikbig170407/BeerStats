//
//  RackView.swift
//  BeerStats
//
//  Zeichnet die Becher eines Teams als gestaffeltes Rack.
//
//  Die Reihen überlappen sich vertikal und die vorderen Reihen liegen
//  optisch über den hinteren – dadurch entsteht der Eindruck eines echten,
//  auf dem Tisch stehenden Racks statt einer flachen Punktematrix.
//

import SwiftUI

struct RackView: View {

    let rack: RackLayout
    /// Wie das Rack ausgerichtet wird: Das gegnerische Rack zeigt mit der
    /// breiten Seite nach oben, das eigene gespiegelt nach unten – so liegt
    /// bei beiden die hintere Tischkante außen.
    let isOpponentRack: Bool
    /// Liefert den Zustand pro Becher-Platz.
    let stateForCup: (Int) -> CupState
    let onTap: (Int) -> Void

    var cupWidth: CGFloat = 40

    private var rowOrder: [Int] {
        let indices = Array(rack.rows.indices)
        return isOpponentRack ? indices : indices.reversed()
    }

    var body: some View {
        VStack(spacing: -(cupWidth * 0.42)) {
            ForEach(Array(rowOrder.enumerated()), id: \.element) { position, rowIndex in
                HStack(spacing: cupWidth * 0.1) {
                    ForEach(Array(rack.indices(inRow: rowIndex)), id: \.self) { cupIndex in
                        cupButton(at: cupIndex)
                    }
                }
                // Seitlicher Versatz der Reihe – macht aus zwei gleich langen
                // Reihen den Berserker statt eines Blocks.
                .offset(x: cupWidth * 1.1 * rack.offset(forRow: rowIndex))
                // Später gezeichnete Reihen liegen vorn und überlappen die
                // dahinterliegenden.
                .zIndex(Double(position))
            }
        }
    }

    @ViewBuilder
    private func cupButton(at index: Int) -> some View {
        let state = stateForCup(index)
        let isTappable = state == .active || state == .choosable

        Button {
            onTap(index)
        } label: {
            CupView(state: state, width: cupWidth)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isTappable)
        .accessibilityLabel(accessibilityLabel(for: state))
    }

    private func accessibilityLabel(for state: CupState) -> String {
        switch state {
        case .active: return "Becher treffen"
        case .choosable: return "Diesen Becher wegstellen"
        case .idle: return "Becher, Gegner ist am Zug"
        case .removed, .removedHighlighted: return "Becher bereits abgeräumt"
        }
    }
}

#Preview {
    // Bewusst ohne lokale Variablen: Der Closure von #Preview ist ein
    // ViewBuilder und erlaubt keine freien Anweisungen.
    VStack(spacing: 40) {
        RackView(
            rack: RackLayout(cupCount: 10),
            isOpponentRack: true,
            stateForCup: { index in index % 4 == 0 ? .removed : .active },
            onTap: { _ in }
        )
        RackView(
            rack: RackLayout(cupCount: 6),
            isOpponentRack: false,
            stateForCup: { _ in .idle },
            onTap: { _ in }
        )
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BeerStatsColor.backgroundPrimary)
}
