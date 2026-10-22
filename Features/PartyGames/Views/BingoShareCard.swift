//
//  BingoShareCard.swift
//  BeerStats
//
//  Ein Bingo-Blatt als Bild – damit jeder sein eigenes auf dem eigenen
//  Handy hat.
//
//  Warum ein Bild und kein Link: Die App laeuft nur auf diesem einen
//  Geraet. Sie ist nicht im App Store, sie ist sideloaded, und die
//  Signatur haelt sieben Tage. Ein Link, der die App oeffnet, oeffnet bei
//  deinen Gaesten gar nichts. Ein Bild dagegen kommt bei jedem an – per
//  WhatsApp, AirDrop, Signal, Mail, egal womit.
//
//  Daraus folgt die wichtigste Entscheidung an diesem Blatt: **Es muss
//  ohne die App funktionieren.** Niemand kann darauf tippen, also steht
//  die ganze Regel darauf, und abgehakt wird mit dem Finger im Kopf oder
//  mit einem Screenshot. Das ist kein Mangel – ein Bingo-Blatt am
//  Kneipentisch ist auch nur Papier.
//
//  Dieselben Masse wie `ShareCard`: vier zu fuenf, das Format, das in
//  einem Chat ohne Zuschneiden ganz zu sehen ist. Und dieselbe Regel –
//  feste Schriftgroessen, denn die Systemeinstellung des Absenders darf
//  nicht bestimmen, wie der Empfaenger das Bild sieht.
//

import SwiftUI

struct BingoShareCard: View {

    /// Wem das Blatt gehoert – steht gross darauf, damit in einer Gruppe
    /// mit sieben Bildern niemand das falsche abhakt.
    let owner: String
    let fields: [String]
    /// Was ein einzelnes Kreuz kostet und was eine volle Reihe bringt.
    let spotPenalty: String
    let bingoReward: String

    static let size = CGSize(width: 540, height: 675)
    private static let columns = 4

    /// Die sechzehn Felder in vier Reihen zu vier.
    ///
    /// Von Hand aufgeteilt und bewusst KEIN `LazyVGrid`: Ein lazy Container
    /// baut seine Zellen erst, wenn ein Sichtfenster sie anfordert. Im
    /// `ImageRenderer` gibt es keines – das Blatt kaeme leer heraus, und
    /// zwar genau dann, wenn es verschickt wird.
    private var rows: [[String]] {
        let felder = Array(fields.prefix(Self.columns * Self.columns))
        return stride(from: 0, to: felder.count, by: Self.columns).map {
            Array(felder[$0..<min($0 + Self.columns, felder.count)])
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BeerStatsColor.backgroundSecondary, BeerStatsColor.backgroundPrimary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            CupShape()
                .stroke(BeerStatsColor.success.opacity(0.14), lineWidth: 6)
                .frame(width: 300, height: 360)
                .offset(x: 160, y: 210)

            VStack(alignment: .leading, spacing: 10) {
                Text("TRINKBINGO")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .kerning(4)
                    .foregroundStyle(BeerStatsColor.success)

                Text(owner)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                VStack(spacing: 6) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, reihe in
                        HStack(spacing: 6) {
                            ForEach(Array(reihe.enumerated()), id: \.offset) { _, feld in
                                tile(feld)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Passiert eins, trinkt der Schuldige \(spotPenalty).")
                        .foregroundStyle(BeerStatsColor.textSecondary)
                    Text("Volle Reihe: Bingo rufen und \(bingoReward) verteilen.")
                        .foregroundStyle(BeerStatsColor.success)
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private func tile(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(BeerStatsColor.textPrimary)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.55)
            .lineLimit(5)
            .padding(4)
            .frame(maxWidth: .infinity)
            .frame(height: 104)
            .background(
                BeerStatsColor.surfaceElevated.opacity(0.75),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(BeerStatsColor.textSecondary.opacity(0.3), lineWidth: 1)
            )
    }
}
