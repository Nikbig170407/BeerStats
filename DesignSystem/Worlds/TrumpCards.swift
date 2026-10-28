//
//  TrumpCards.swift
//  BeerStats
//
//  Die Welt von "Kennst du deine Leute?": Quartett. Zwei Sammelkarten
//  liegen nebeneinander, jede mit dem Namen im Kopf und dem Wert, um den es
//  geht. Bis geraten ist, steht dort ein Fragezeichen; danach fuellt sich
//  der Balken, der bessere Wert leuchtet, und die andere Karte kippt weg.
//
//  Ein Folienglanz streicht ueber die Karten – Sammelkarten glaenzen.
//

import SwiftUI

enum TrumpCards {
    static let stock = SceneArt.rgb(236, 232, 222)
    static let ink = SceneArt.rgb(28, 26, 26)
    static let gold = SceneArt.rgb(255, 214, 90)
}

/// Eine Quartettkarte fuer eine Person.
struct QuartetCard<Avatar: View>: View {

    let name: String
    let color: Color
    let statLabel: String
    /// `nil`, solange nicht geraten ist – dann steht ein Fragezeichen da.
    let value: String?
    /// Wie voll der Balken ist, im Vergleich zur anderen Karte.
    let share: Double
    let isBetter: Bool
    /// Versetzt den Glanz, damit er nicht auf beiden Karten gleichzeitig
    /// laeuft.
    var shineOffset: Double = 0
    private let avatar: Avatar

    init(
        name: String,
        color: Color,
        statLabel: String,
        value: String?,
        share: Double,
        isBetter: Bool,
        shineOffset: Double = 0,
        @ViewBuilder avatar: () -> Avatar
    ) {
        self.name = name
        self.color = color
        self.statLabel = statLabel
        self.value = value
        self.share = share
        self.isBetter = isBetter
        self.shineOffset = shineOffset
        self.avatar = avatar()
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(name.uppercased())
                .font(.scaled(17, weight: .heavy, design: .default, width: .condensed))
                .kerning(1.2)
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 10)
                .padding(.top, 12)
                .padding(.bottom, 34)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color)

            avatar
                .padding(4)
                .background(Circle().fill(TrumpCards.stock))
                .offset(y: -28)
                .padding(.bottom, -28)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(statLabel)
                        .font(.scaled(13, weight: .semibold, design: .default, width: .condensed))
                        .opacity(0.75)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    Text(value ?? "?")
                        .font(.scaled(17, weight: .heavy, design: .default, width: .condensed))
                        .monospacedDigit()
                }
                .foregroundStyle(TrumpCards.ink)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(TrumpCards.ink.opacity(0.12))
                        Capsule()
                            .fill(isBetter ? SceneArt.rgb(220, 150, 20) : color)
                            .frame(width: geometry.size.width * (value == nil ? 0 : max(0, min(1, share))))
                    }
                }
                .frame(height: 6)
                .animation(.easeOut(duration: 0.45), value: value)
            }
            .padding(10)
            .background(isBetter ? TrumpCards.gold.opacity(0.3) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(6)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(TrumpCards.stock)
        .overlay { FoilShine(offset: shineOffset) }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
    }
}

/// Ein Lichtstreif, der alle drei Sekunden ueber die Karte zieht.
private struct FoilShine: View {

    let offset: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                Canvas { context, size in
                    let w = Double(size.width), h = Double(size.height)
                    let p = SceneArt.fract(timeline.date.timeIntervalSinceReferenceDate / 3 + offset)
                    let x = -120 + p * (w + 240)
                    let a: SceneArt.Point = (x, 0)
                    let b: SceneArt.Point = (x + 50, 0)
                    let c: SceneArt.Point = (x - 40, h)
                    let d: SceneArt.Point = (x - 90, h)
                    let links: SceneArt.Point = (x - 90, 0)
                    let rechts: SceneArt.Point = (x + 50, 0)
                    SceneArt.fill(&context, [a, b, c, d], from: links, to: rechts,
                                  [(0, .white, 0), (0.5, .white, 0.28), (1, .white, 0)])
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
