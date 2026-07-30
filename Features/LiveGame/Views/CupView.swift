//
//  CupView.swift
//  BeerStats
//
//  Ein einzelner Red Solo Cup in 3/4-Perspektive: weiße Rand-Ellipse oben,
//  darunter der rote, sich verjüngende Körper mit Rillen und Glanzkante.
//
//  Bewusst komplett aus SwiftUI-Formen gezeichnet statt als Bild-Asset:
//  So skaliert der Becher verlustfrei auf jede Gerätegröße, die Farben
//  kommen aus dem Design-System, und die Zustände (leer, wählbar, gesperrt)
//  lassen sich ohne zusätzliche Assets darstellen.
//

import SwiftUI

/// Optischer Zustand eines Bechers im Rack.
enum CupState: Equatable {
    /// Steht und ist antippbar (das werfende Team ist am Zug).
    case active
    /// Steht, ist aber gerade nicht antippbar (Gegner am Zug).
    case idle
    /// Steht und muss im Rahmen einer erzwungenen Auswahl weggestellt werden.
    case choosable
    /// Bereits abgeräumt.
    case removed
    /// Abgeräumt und im laufenden Zug vom Teamkollegen getroffen – die
    /// Markierung ist die Entscheidungsgrundlage für die Bombe.
    case removedHighlighted
}

struct CupView: View {

    let state: CupState
    var width: CGFloat = 40

    private var height: CGFloat { width * 1.325 }
    private var rimHeight: CGFloat { width * 0.375 }

    var body: some View {
        ZStack(alignment: .top) {
            switch state {
            case .removed, .removedHighlighted:
                emptySlot
            case .active, .idle, .choosable:
                standingCup
            }
        }
        .frame(width: width, height: height)
        .opacity(state == .idle ? 0.55 : 1)
        .saturation(state == .idle ? 0.5 : 1)
        .animation(AppAnimation.tap, value: state)
    }

    // MARK: - Stehender Becher

    private var standingCup: some View {
        ZStack(alignment: .top) {
            cupBody
                .padding(.top, rimHeight * 0.45)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.white, Color(white: 0.94), Color(white: 0.81)],
                        center: UnitPoint(x: 0.5, y: 0.32),
                        startRadius: 0,
                        endRadius: width * 0.55
                    )
                )
                .overlay(
                    Ellipse().strokeBorder(BeerStatsColor.cupRimEdge, lineWidth: state == .choosable ? 2.6 : 1.6)
                )
                .frame(width: width, height: rimHeight)
                .shadow(
                    color: state == .choosable ? BeerStatsColor.accent.opacity(0.9) : .clear,
                    radius: state == .choosable ? 7 : 0
                )
        }
        .shadow(color: .black.opacity(0.55), radius: 4, x: 0, y: 3)
    }

    /// Der konische Körper. Die Rillen entstehen durch übereinandergelegte,
    /// leicht abgedunkelte Streifen – wie die Griffrippen am echten Becher.
    private var cupBody: some View {
        CupBodyShape()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: BeerStatsColor.cupShadow, location: 0.00),
                        .init(color: BeerStatsColor.cupMid, location: 0.20),
                        .init(color: BeerStatsColor.cupHighlight, location: 0.33),
                        .init(color: BeerStatsColor.cupBase, location: 0.50),
                        .init(color: BeerStatsColor.cupMid, location: 0.72),
                        .init(color: BeerStatsColor.cupShadow, location: 1.00)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(ribs.clipShape(CupBodyShape()))
    }

    private var ribs: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { index in
                Rectangle()
                    .fill(Color.black.opacity(index.isMultiple(of: 2) ? 0.13 : 0.0))
                    .frame(height: 2)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Abgeräumter Platz

    private var emptySlot: some View {
        Ellipse()
            .strokeBorder(
                state == .removedHighlighted ? BeerStatsColor.accent : BeerStatsColor.textSecondary.opacity(0.28),
                style: StrokeStyle(
                    lineWidth: state == .removedHighlighted ? 2 : 1.5,
                    dash: state == .removedHighlighted ? [] : [3, 3]
                )
            )
            .frame(width: width * 0.82, height: rimHeight)
            .shadow(
                color: state == .removedHighlighted ? BeerStatsColor.accent.opacity(0.8) : .clear,
                radius: state == .removedHighlighted ? 6 : 0
            )
            .padding(.top, 3)
    }
}

/// Trapezform des Bechers: oben so breit wie der Rand, nach unten
/// verjüngt – das erzeugt zusammen mit der Rand-Ellipse den 3D-Eindruck.
private struct CupBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = rect.width * 0.16
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.01, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.01, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    HStack(spacing: 12) {
        CupView(state: .active)
        CupView(state: .idle)
        CupView(state: .choosable)
        CupView(state: .removed)
        CupView(state: .removedHighlighted)
    }
    .padding(32)
    .background(BeerStatsColor.backgroundPrimary)
}
