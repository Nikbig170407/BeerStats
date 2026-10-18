//
//  ShareCard.swift
//  BeerStats
//
//  Das Ergebnis als Bild – die einzige Form, in der die App den Tisch
//  verlaesst.
//
//  Bis jetzt gab sie nur Text nach aussen (den Abend-Rueckblick). Text ist
//  robust und laesst sich in zehn Jahren noch oeffnen – aber in eine
//  Gruppe schickt man ein Bild. Und genau das holt die Runde am naechsten
//  Abend wieder in die App.
//
//  Die Karte ist bewusst NICHT der Screen, sondern ein eigener Aufbau:
//
//  Feste Groesse und feste Schriftgroessen. Ein geteiltes Bild soll auf
//  jedem Geraet gleich aussehen – mit `Font.scaled` haette die
//  Systemeinstellung des Absenders bestimmt, wie der Empfaenger es sieht.
//  Das ist die eine Stelle, an der feste Groessen richtig sind.
//
//  Kein `AmbientBackdrop`, sondern ein einfacher Verlauf: Der Hintergrund
//  der App streut zufaellige Blasen und liest Einstellungen – beides
//  gehoert nicht in ein Bild, das Bestand haben soll. Die Becherform
//  bleibt, sie ist das Zeichen der App.
//

import SwiftUI

struct ShareCard: View {

    struct Row: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    /// Die Zeile ganz oben, in Grossbuchstaben – "BEERPONG" oder
    /// "UNSER ABEND".
    let title: String
    /// Die Nachricht: wer gewonnen hat.
    let headline: String
    /// Der Stand darunter, wenn es einen gibt.
    var subline: String?
    /// Bis zu drei Kennzahlen. Mehr wird auf einem Handybild unlesbar.
    var rows: [Row] = []
    let footnote: String
    var tint: Color = BeerStatsColor.accent

    /// Vier zu fuenf, wie ein Foto im Hochformat: Das ist das Format, das in
    /// einem Chat ohne Zuschneiden ganz zu sehen ist.
    static let size = CGSize(width: 540, height: 675)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BeerStatsColor.backgroundSecondary, BeerStatsColor.backgroundPrimary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Die Becherform als Wasserzeichen – vom Login ueber das Icon bis
            // hierher dasselbe Signet.
            CupShape()
                .stroke(tint.opacity(0.16), lineWidth: 6)
                .frame(width: 320, height: 380)
                .offset(x: 150, y: 190)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .kerning(4)
                    .foregroundStyle(tint)

                Spacer(minLength: 0)

                Text(headline)
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)

                if let subline {
                    Text(subline)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(tint)
                        .padding(.top, 10)
                }

                Spacer(minLength: 0)

                if !rows.isEmpty {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(rows) { row in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.value)
                                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                                    .foregroundStyle(BeerStatsColor.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                Text(row.label.uppercased())
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .kerning(1.2)
                                    .foregroundStyle(BeerStatsColor.textSecondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.bottom, 24)
                }

                HStack(spacing: 10) {
                    Text(footnote)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(BeerStatsColor.textSecondary)
                    Spacer(minLength: 0)
                    Text("🍺 BeerStats")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(tint)
                }
            }
            .padding(44)
        }
        .frame(width: ShareCard.size.width, height: ShareCard.size.height)
    }
}

// MARK: - Rendern

enum ShareImage {

    /// Rendert eine Ansicht in eine PNG-Datei und gibt deren Adresse zurueck.
    ///
    /// Eine Datei und kein `UIImage`: `ShareLink` nimmt Dateien ohne weiteres
    /// Zutun, und was im Teilen-Blatt landet, traegt dann einen Namen statt
    /// "Bild". Der Ordner ist das Temporaer-Verzeichnis – das Bild ist
    /// unterwegs, kein Dokument.
    ///
    /// Die Skalierung ist fest auf drei: Das Bild soll auf jedem Geraet
    /// dieselbe Groesse haben, nicht die des Absenders.
    @MainActor
    static func file<Content: View>(
        named name: String,
        @ViewBuilder content: () -> Content
    ) -> URL? {
        let renderer = ImageRenderer(content: content())
        renderer.scale = 3
        renderer.isOpaque = true

        guard let image = renderer.uiImage, let data = image.pngData() else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name).png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            // Ein nicht geschriebenes Bild ist kein Grund, das Spiel
            // anzuhalten – der Knopf bleibt dann einfach weg.
            return nil
        }
    }
}
