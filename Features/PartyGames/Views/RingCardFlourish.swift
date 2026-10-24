//
//  RingCardFlourish.swift
//  BeerStats
//
//  Die Bewegung hinter der gezogenen Karte – für jeden Rang eine andere.
//
//  Dreizehn Karten sahen beim Aufdecken gleich aus: dieselbe Karte, derselbe
//  Aufbau, nur ein anderer Text. Am Tisch heisst das, dass die Runde den
//  Text lesen muss, um zu wissen, was los ist. Eine Bewegung, die zur Karte
//  gehoert, sagt es schon vorher – und sie sagt es ueber den Tisch hinweg,
//  wo niemand mitliest.
//
//  Deshalb keine dreizehn handgebauten Animationen, sondern **eine mit
//  dreizehn Einstellungen**: Zeichen, Anzahl und Richtung. Das ist kein
//  Sparen an der falschen Stelle, sondern die Bedingung dafuer, dass eine
//  vierzehnte Karte spaeter nicht vergessen wird – sie braucht eine Zeile,
//  keinen neuen Entwurf.
//
//  Die Richtung ist dabei nicht Geschmack: Was auf dich zukommt, faellt
//  (Dame, Drei); was von dir ausgeht, steigt (Daumen, Regel); was alle
//  gleichzeitig trifft, platzt auseinander (Kategorie, Wasserfall). Wer die
//  Karte schon kennt, erkennt sie an der Bewegung, bevor er den Titel
//  liest.
//

import SwiftUI

struct RingCardFlourish: View {

    let rank: Int

    /// Laeuft, sobald die Ansicht steht. Jedes Zeichen haengt mit eigener
    /// Verzoegerung daran – ein gemeinsamer Zustand reicht, weil die
    /// Bewegung selbst in den Modifiern steckt und nicht im `body`.
    @State private var running = false

    private enum Direction {
        /// Steigt auf – was von dir ausgeht.
        case rise
        /// Faellt herab – was auf dich zukommt.
        case fall
        /// Platzt aus der Mitte – was alle gleichzeitig trifft.
        case burst
        /// Zieht quer – was auf jemanden zeigt.
        case sweep
    }

    private struct Style {
        let symbol: String
        let count: Int
        let direction: Direction
        var tint: Color = BeerStatsColor.accent
    }

    /// Wie lange ein Zeichen unterwegs ist.
    private static let flight: Double = 2.2
    /// Abstand zwischen zwei Zeichen.
    private static let stagger: Double = 0.17

    var body: some View {
        GeometryReader { geometry in
            let style = style(for: rank)
            let breite = geometry.size.width
            let hoehe = geometry.size.height

            ZStack {
                ForEach(0..<style.count, id: \.self) { index in
                    Text(style.symbol)
                        .font(.system(size: size(index)))
                        .foregroundStyle(style.tint)
                        .opacity(running ? 0 : 0.75)
                        .offset(
                            x: offsetX(index, style: style, width: breite),
                            y: offsetY(index, style: style, height: hoehe)
                        )
                        .scaleEffect(running && style.direction == .burst ? 1.5 : 0.8)
                        .animation(
                            .easeOut(duration: Self.flight)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * Self.stagger),
                            value: running
                        )
                }
            }
            .frame(width: breite, height: hoehe)
        }
        // Reine Zierde: Fuer VoiceOver ist die Karte der Inhalt, nicht die
        // Bewegung dahinter.
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onAppear { running = true }
    }

    // MARK: - Wohin das Zeichen fliegt

    private func offsetX(_ index: Int, style: Style, width: CGFloat) -> CGFloat {
        let start = streuung(index) * width * 0.42

        switch style.direction {
        case .rise, .fall:
            // Leicht seitlich ausfaechern, damit nicht alles auf einer
            // Linie liegt.
            return start + (running ? streuung(index + 7) * width * 0.12 : 0)
        case .burst:
            return running ? richtung(index).dx * width * 0.46 : 0
        case .sweep:
            return running ? width * 0.46 : -width * 0.46
        }
    }

    private func offsetY(_ index: Int, style: Style, height: CGFloat) -> CGFloat {
        switch style.direction {
        case .rise:
            return running ? -height * 0.5 : height * 0.5
        case .fall:
            return running ? height * 0.5 : -height * 0.5
        case .burst:
            return running ? richtung(index).dy * height * 0.46 : 0
        case .sweep:
            return streuung(index + 3) * height * 0.3
        }
    }

    /// Die Richtung beim Platzen – gleichmaessig im Kreis verteilt, damit
    /// es nach allen Seiten geht und nicht nach Zufall aussieht.
    private func richtung(_ index: Int) -> (dx: CGFloat, dy: CGFloat) {
        let style = style(for: rank)
        let winkel = Double(index) / Double(max(style.count, 1)) * 2 * .pi
        return (CGFloat(cos(winkel)), CGFloat(sin(winkel)))
    }

    /// Immer dieselbe Streuung fuer denselben Index – gerechnet statt
    /// gewuerfelt, sonst springen die Zeichen bei jedem Neuzeichnen.
    private func streuung(_ index: Int) -> CGFloat {
        let wert = sin(Double(index) * 12.9898) * 43758.5453
        return CGFloat(wert - wert.rounded(.down)) * 2 - 1
    }

    private func size(_ index: Int) -> CGFloat {
        26 + abs(streuung(index + 11)) * 16
    }

    // MARK: - Welche Karte wie aussieht

    private func style(for rank: Int) -> Style {
        switch rank {
        case 2:
            // Zeigt auf jemanden – also quer durchs Bild.
            return Style(symbol: "👉", count: 5, direction: .sweep)
        case 3:
            // Kommt auf dich herunter.
            return Style(symbol: "⬇️", count: 6, direction: .fall, tint: BeerStatsColor.error)
        case 4:
            return Style(symbol: "💧", count: 10, direction: .fall, tint: BeerStatsColor.accentSecondary)
        case 5:
            return Style(symbol: "🙋‍♂️", count: 6, direction: .rise, tint: BeerStatsColor.accentSecondary)
        case 6:
            return Style(symbol: "🙋‍♀️", count: 6, direction: .rise, tint: BeerStatsColor.error)
        case 7:
            // Alle Haende hoch.
            return Style(symbol: "☝️", count: 8, direction: .rise, tint: BeerStatsColor.warning)
        case 8:
            return Style(symbol: "🤝", count: 5, direction: .burst, tint: BeerStatsColor.success)
        case 9:
            return Style(symbol: "🎵", count: 8, direction: .burst, tint: BeerStatsColor.accentSecondary)
        case 10:
            return Style(symbol: "📜", count: 6, direction: .rise, tint: BeerStatsColor.warning)
        case 11:
            return Style(symbol: "👍", count: 7, direction: .rise, tint: BeerStatsColor.success)
        case 12:
            // Kronen regnen herab.
            return Style(symbol: "👑", count: 7, direction: .fall, tint: BeerStatsColor.warning)
        case 13:
            return Style(symbol: "📚", count: 7, direction: .burst, tint: BeerStatsColor.accent)
        default:
            // Das Ass ist der einzige Shot – entsprechend heiss.
            return Style(symbol: "🔥", count: 9, direction: .rise, tint: BeerStatsColor.error)
        }
    }
}
