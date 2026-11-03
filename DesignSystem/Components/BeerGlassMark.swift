//
//  BeerGlassMark.swift
//  BeerStats
//
//  Gefülltes Bierglas als Bildmarke – für Kopfbereiche, in denen ein
//  ruhendes Symbol gebraucht wird.
//
//  Nutzt dieselbe `CupShape` wie Ladeanzeige und Kennzahl-Becher. Ein
//  SF-Symbol täte es zwar auch, aber der Becher ist das wiedererkennbare
//  Element der App und taucht so vom Login bis zum Spielscreen durchgängig
//  auf.
//
//  Bis zum 3. November schwebte die Schaumkrone über dem Glas: Ihr Versatz
//  zog von der Füllhöhe noch einmal eine halbe Glashöhe ab, und so stand
//  sie im Hauptmenü acht Punkte über dem Rand, die Bieroberfläche vierzehn
//  darunter. Die Lage ist deshalb jetzt eine Rechnung mit Test
//  (`foamFrame`), und ihre Breite kommt aus der Form des Bechers statt aus
//  einer geschätzten Zahl.
//

import SwiftUI

struct BeerGlassMark: View {

    var size: CGFloat = 56
    var fillLevel: CGFloat = 0.72

    private var height: CGFloat { size * Self.heightRatio }

    /// Hoehe des Glases im Verhaeltnis zur Breite.
    static let heightRatio: CGFloat = 1.15
    /// Wie dick der Schaum ist, im Verhaeltnis zur Breite.
    static let foamThickness: CGFloat = 0.16
    /// Um diesen Teil seiner Dicke liegt der Schaum hoeher als die
    /// Bieroberflaeche – er sitzt wie eine Krone darauf und deckt deren
    /// Kante trotzdem ab. Mittig auf der Oberflaeche wirkte er flach wie ein
    /// Deckel.
    static let foamLift: CGFloat = 0.2
    /// Der Rand des Glases.
    static let rimWidth: CGFloat = 2.5

    /// Wo der Schaum liegt, im Rahmen des Zeichens (oben links ist 0, 0).
    ///
    /// So breit wie das Glas innen auf seiner Hoehe – der Rand deckt eine
    /// halbe Strichbreite je Seite ab – und nie ueber dem oberen Rand: Bei
    /// einem randvollen Glas sitzt er oben auf, statt hinauszuragen.
    static func foamFrame(size: CGFloat, fillLevel: CGFloat) -> CGRect {
        let hoehe = size * heightRatio
        let dicke = size * foamThickness
        let oberflaeche = hoehe * (1 - fillLevel)
        let mitte = max(dicke / 2, oberflaeche - dicke * foamLift)
        let breite = CupShape.width(size, atDepth: mitte / hoehe) - rimWidth
        return CGRect(x: (size - breite) / 2, y: mitte - dicke / 2, width: breite, height: dicke)
    }

    var body: some View {
        ZStack {
            // Bier
            CupShape()
                .fill(
                    LinearGradient(
                        colors: [BeerStatsColor.accent, Color(red: 0.76, green: 0.44, blue: 0.10)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: height)
                .mask(alignment: .bottom) {
                    Rectangle().frame(height: height * fillLevel)
                }

            // Schaumkrone auf der Füllhöhe
            let schaum = Self.foamFrame(size: size, fillLevel: fillLevel)
            Ellipse()
                .fill(Color(white: 0.97))
                .frame(width: schaum.width, height: schaum.height)
                // Der ZStack legt in die Mitte – verschoben wird also um den
                // Abstand der Schaummitte von der Glasmitte
                .offset(y: schaum.midY - height / 2)

            CupShape()
                .stroke(BeerStatsColor.textSecondary.opacity(0.7), lineWidth: Self.rimWidth)
                .frame(width: size, height: height)
        }
        .frame(width: size, height: height)
        .shadow(color: BeerStatsColor.accent.opacity(0.45), radius: 14)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 28) {
        BeerGlassMark()
        BeerGlassMark(size: 88, fillLevel: 0.5)
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BeerStatsColor.backgroundPrimary)
}
