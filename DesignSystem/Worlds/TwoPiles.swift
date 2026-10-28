//
//  TwoPiles.swift
//  BeerStats
//
//  Die Welt von Wahrheit oder Pflicht: zwei Stapel, zwei Tonlagen. Die
//  Wahrheit ist kuehles Blau mit kursiver Serifenschrift, ein Gestaendnis
//  bei gedimmtem Licht. Die Pflicht ist Rot mit Warnstreifen und schmalen
//  Grossbuchstaben, ein Befehl.
//
//  Beide Karten sahen bisher gleich aus, nur das Licht wechselte. Am Tisch
//  muss man aber auf einen Blick sehen, WAS gezogen wurde – auch der, der
//  nicht vorliest.
//
//  Wer verweigert, zerreisst die Karte: zwei Haelften, die auseinander
//  fallen. Verweigern ist erlaubt und kostet – das soll man sehen.
//

import SwiftUI

enum TwoPiles {
    static let truth = SceneArt.rgb(22, 50, 92)
    static let truthInk = SceneArt.rgb(150, 196, 255)
    static let dare = SceneArt.rgb(120, 22, 30)
    static let hazard = SceneArt.rgb(240, 196, 40)
}

// MARK: - Die Karte

/// Die Vorderseite einer Karte – ohne Rahmen um sie herum, damit sie auch
/// zerrissen werden kann.
struct TruthOrDareFace: View {

    let kind: TruthOrDareKind
    let text: String
    let price: String

    var body: some View {
        VStack(spacing: 16) {
            if kind == .dare {
                Text("PFLICHT")
                    .font(.scaled(22, weight: .black, design: .default, width: .compressed))
                    .kerning(3)
                    .foregroundStyle(TwoPiles.hazard)
                    .padding(.top, 14)
            } else {
                Text("Wahrheit")
                    .font(.scaled(22, weight: .regular, design: .serif).italic())
                    .foregroundStyle(TwoPiles.truthInk)
            }

            Spacer(minLength: 0)

            Group {
                if kind == .dare {
                    Text(text.uppercased())
                        .font(.scaled(30, weight: .black, design: .default, width: .compressed))
                } else {
                    Text(text)
                        .font(.scaled(25, weight: .regular, design: .serif).italic())
                }
            }
            .foregroundStyle(Color.white)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text(price)
                .font(kind == .dare
                      ? Font.scaled(15, weight: .semibold, design: .default, width: .condensed)
                      : Font.scaled(15, weight: .regular, design: .serif).italic())
                .foregroundStyle(Color.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { CardStock(kind: kind) }
    }
}

/// Der Karton der Karte: Blau mit einem grossen, blassen Fragezeichen –
/// oder Rot mit einem Warnstreifen oben.
private struct CardStock: View {

    let kind: TruthOrDareKind

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(kind == .dare ? TwoPiles.dare : TwoPiles.truth)

            if kind == .dare {
                HazardStripes()
                    .frame(height: 18)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                Text("?")
                    .font(.system(size: 230, weight: .regular, design: .serif).italic())
                    .foregroundStyle(Color.white.opacity(0.07))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 18)
                    .accessibilityHidden(true)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.55), radius: 18, y: 10)
    }
}

/// Schwarz-gelbe Warnstreifen.
struct HazardStripes: View {

    var stripe: Double = 8

    var body: some View {
        Canvas { context, size in
            let h = Double(size.height)
            let band: [SceneArt.Point] = [(0, 0), (Double(size.width), 0), (Double(size.width), h), (0, h)]
            SceneArt.hazard(&context, band, stripe: stripe)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

// MARK: - Die Stapel

/// Ein Stapel zum Ziehen: drei Karten, leicht versetzt.
struct CardPile: View {

    let kind: TruthOrDareKind
    let remaining: Int

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { lage in
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(kind == .dare ? TwoPiles.dare : TwoPiles.truth)
                    .brightness(Double(lage) * 0.04)
                    .overlay(alignment: .top) {
                        if kind == .dare {
                            HazardStripes(stripe: 6)
                                .frame(height: 10)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
                    .offset(x: Double(lage) * 3, y: Double(lage) * -4)
                    .rotationEffect(.degrees(kind == .dare ? 4 : -4))
            }

            VStack(spacing: 4) {
                Text(kind == .dare ? "PFLICHT" : "Wahrheit")
                    .font(kind == .dare
                          ? Font.scaled(24, weight: .black, design: .default, width: .compressed)
                          : Font.scaled(24, weight: .regular, design: .serif).italic())
                    .foregroundStyle(kind == .dare ? TwoPiles.hazard : TwoPiles.truthInk)
                Text("\(remaining) übrig")
                    .font(.scaled(13, weight: .medium, design: .default, width: .condensed))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .offset(x: 6, y: -8)
        }
        .frame(height: 120)
        .padding(.horizontal, 10)
    }
}

// MARK: - Zerreissen

/// Zwei Haelften entlang einer gezackten Kante, die auseinanderfallen.
struct TornApart<Content: View>: View {

    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fallen = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            half(left: true)
            half(left: false)
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.4) : .easeIn(duration: 0.9).delay(0.12)) {
                fallen = true
            }
        }
    }

    private func half(left: Bool) -> some View {
        let seite: Double = left ? -1 : 1
        return content
            .clipShape(TornHalf(left: left))
            .rotationEffect(.degrees(fallen && !reduceMotion ? seite * 18 : 0), anchor: left ? .bottomLeading : .bottomTrailing)
            .offset(x: fallen && !reduceMotion ? seite * 70 : 0, y: fallen && !reduceMotion ? (left ? 340 : 400) : 0)
            .opacity(fallen ? 0 : 1)
    }
}

/// Eine Haelfte einer zerrissenen Karte. Die Zacken sind gerechnet, damit
/// beide Haelften genau ineinanderpassen.
private struct TornHalf: Shape {

    let left: Bool

    func path(in rect: CGRect) -> Path {
        let zacken = 14
        let mitte = Double(rect.midX)
        var kante: [CGPoint] = []
        for i in 0...zacken {
            let y = Double(rect.minY) + Double(rect.height) * Double(i) / Double(zacken)
            kante.append(CGPoint(x: mitte + SceneArt.noise(i, 13) * 9, y: y))
        }
        // Ueber den Rand hinaus, damit der Schatten der Karte nicht
        // abgeschnitten wird
        let aussen = left ? Double(rect.minX) - 60 : Double(rect.maxX) + 60
        var p = Path()
        p.move(to: CGPoint(x: aussen, y: Double(rect.minY) - 60))
        p.addLine(to: CGPoint(x: kante[0].x, y: Double(rect.minY) - 60))
        for punkt in kante { p.addLine(to: punkt) }
        p.addLine(to: CGPoint(x: kante[zacken].x, y: Double(rect.maxY) + 60))
        p.addLine(to: CGPoint(x: aussen, y: Double(rect.maxY) + 60))
        p.closeSubpath()
        return p
    }
}

// MARK: - Vom Stapel ziehen

extension AnyTransition {

    /// Die Karte kommt aus ihrer Ecke: die Wahrheit von oben links, die
    /// Pflicht von unten rechts – dort liegen die Stapel.
    static func drawn(from kind: TruthOrDareKind) -> AnyTransition {
        .modifier(active: PileDraw(kind: kind, progress: 0), identity: PileDraw(kind: kind, progress: 1))
    }
}

private struct PileDraw: ViewModifier {

    let kind: TruthOrDareKind
    let progress: Double

    func body(content: Content) -> some View {
        let richtung: Double = kind == .dare ? 1 : -1
        let rest = 1 - progress

        return content
            .scaleEffect(0.3 + 0.7 * progress)
            .rotationEffect(.degrees(rest * 14 * richtung))
            .offset(x: rest * 130 * richtung, y: rest * 250 * richtung)
            .opacity(progress)
    }
}
