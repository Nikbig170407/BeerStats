//
//  ForeheadCard.swift
//  BeerStats
//
//  Die Welt von "Wer bin ich?": eine Stirnkarte. Der Begriff fuellt den
//  ganzen Screen, so gross es geht – das Handy klebt an einer Stirn und
//  wird aus zwei Metern gelesen. Die Zeit laeuft als Band um den Rand und
//  wird kuerzer; im letzten Fuenftel wird sie rot.
//
//  Getroffen: Die Karte faellt nach unten, gruener Blitz. Weiter: Sie
//  fliegt nach oben, oranger Blitz. Zwei Richtungen, die der Ratende nicht
//  sieht – aber die Runde.
//

import SwiftUI

enum ForeheadCard {
    static let card = SceneArt.rgb(38, 46, 124)
    static let band = SceneArt.rgb(255, 200, 80)
    static let bandLate = SceneArt.rgb(255, 90, 70)
    static let pass = SceneArt.rgb(255, 150, 40)

    /// Ab diesem Rest wird das Band rot.
    static let lateShare: Double = 0.2
}

/// Die Karte an der Stirn: Kategorie oben, der Begriff riesig.
struct ForeheadCardFace: View {

    let category: String
    let term: String

    var body: some View {
        VStack(spacing: 12) {
            Text(category.uppercased())
                .font(.scaled(16, weight: .bold, design: .default, width: .condensed))
                .kerning(3)
                .opacity(0.65)

            Spacer(minLength: 0)

            Text(term)
                .font(.scaled(74, weight: .black, design: .default, width: .compressed))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.3)
                .lineLimit(3)

            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 26)
        .padding(.vertical, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Canvas { context, size in
                let rahmen = CGRect(origin: .zero, size: size)
                context.clip(to: Path(roundedRect: rahmen, cornerRadius: 30))
                context.fill(Path(rahmen), with: .color(ForeheadCard.card))
                // Breite Schraegen, wie auf einer bedruckten Spielkarte
                var schraegen: [(SceneArt.Point, SceneArt.Point)] = []
                let h = Double(size.height)
                for i in -24..<Int(Double(size.width) / 30 + 2) {
                    let x = Double(i) * 30
                    let oben: SceneArt.Point = (x, 0)
                    let unten: SceneArt.Point = (x + h, h)
                    schraegen.append((oben, unten))
                }
                SceneArt.lines(&context, schraegen, .white, 0.035, 10)
            }
            .shadow(color: .black.opacity(0.6), radius: 24, y: 12)
        }
    }
}

/// Die Zeit als Band, das um den Rand der Karte laeuft und kuerzer wird.
struct TimeBand: View {

    /// Wie viel Zeit noch uebrig ist, von 1 bis 0.
    let share: Double

    var body: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .inset(by: 4)
            .trim(from: 0, to: max(0, min(1, share)))
            .stroke(share < ForeheadCard.lateShare ? ForeheadCard.bandLate : ForeheadCard.band,
                    style: StrokeStyle(lineWidth: 7, lineCap: .butt))
            .animation(.linear(duration: 0.2), value: share)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
