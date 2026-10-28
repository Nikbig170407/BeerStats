//
//  ScaledFont.swift
//  BeerStats
//
//  Feste Schriftgroessen, die trotzdem mit der Systemeinstellung wachsen.
//
//  `Font.system(size:)` ignoriert Dynamic Type vollstaendig – wer am iPhone
//  groessere Schrift eingestellt hat, sieht in einer App, die das ueberall
//  benutzt, abgeschnittene Texte. Und dieses Handy geht am Tisch reihum.
//
//  Die Textstile aus `BeerStatsFont` waeren der saubere Weg, aber die
//  Spiele brauchen Zwischengroessen, die es dort nicht gibt (26 pt fuer eine
//  Kartenfrage, 40 pt fuer eine Zahl). Deshalb hier der Mittelweg: Die
//  gewaehlte Groesse bleibt der Ausgangspunkt und wird mit derselben Kurve
//  skaliert wie Systemtext.
//
//  Mit Deckel, und das ist Absicht: In den groessten
//  Bedienungshilfen-Stufen waere eine 40-pt-Zahl sonst dreistellig gross und
//  spraengte jede Karte. Das Anderthalbfache ist der Bereich, in dem die
//  Layouts hier noch tragen.
//

import SwiftUI
import UIKit

extension Font {

    static func scaled(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .rounded,
        maximumScale: CGFloat = 1.5
    ) -> Font {
        let grown = UIFontMetrics.default.scaledValue(for: size)
        return .system(size: min(grown, size * maximumScale), weight: weight, design: design)
    }

    /// Dasselbe mit einer Breite der Systemschrift – schmal, gestaucht oder
    /// breit. Die Spielwelten unterscheiden sich auch darin, und es bleibt
    /// eine Systemschrift: keine Schriftdatei, keine Lizenzfrage, und die
    /// Systemgroesse gilt weiter.
    static func scaled(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .rounded,
        width: Font.Width,
        maximumScale: CGFloat = 1.5
    ) -> Font {
        scaled(size, weight: weight, design: design, maximumScale: maximumScale).width(width)
    }
}
