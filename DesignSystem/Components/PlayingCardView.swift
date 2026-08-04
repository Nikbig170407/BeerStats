//
//  PlayingCardView.swift
//  BeerStats
//
//  Eine Spielkarte, gezeichnet statt als Bild.
//
//  Gezeichnet, weil 52 Bilddateien die App aufblaehen wuerden und weil eine
//  gezeichnete Karte in jeder Groesse scharf bleibt – im Bussfahrer liegen
//  vier nebeneinander, im Koenigsbecher eine gross in der Mitte.
//
//  Die Rueckseite gehoert bewusst dazu: Ohne sie muesste jedes Spiel selbst
//  etwas erfinden, das vor dem Aufdecken zu sehen ist.
//

import SwiftUI

struct PlayingCardView: View {

    let card: PlayingCard?
    var width: CGFloat = 120

    /// Karten sind hochkant und laenger als breit – das Verhaeltnis eines
    /// echten Blattes.
    private var height: CGFloat { width * 1.45 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.1, style: .continuous)
                .fill(card == nil ? backSurface : faceSurface)

            RoundedRectangle(cornerRadius: width * 0.1, style: .continuous)
                .strokeBorder(
                    card == nil
                        ? BeerStatsColor.accent.opacity(0.55)
                        : Color.black.opacity(0.18),
                    lineWidth: 1.5
                )

            if let card {
                face(for: card)
            } else {
                back
            }
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
    }

    // MARK: - Vorderseite

    private var faceSurface: some ShapeStyle {
        LinearGradient(
            colors: [Color(white: 0.97), Color(white: 0.88)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func face(for card: PlayingCard) -> some View {
        VStack(spacing: 0) {
            corner(for: card)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Text(card.suit.symbol)
                .font(.system(size: width * 0.46))
                .foregroundStyle(card.suit.color)

            Spacer(minLength: 0)

            corner(for: card)
                .frame(maxWidth: .infinity, alignment: .trailing)
                // Auf dem Kopf wie bei einer echten Karte.
                .rotationEffect(.degrees(180))
        }
        .padding(width * 0.09)
    }

    private func corner(for card: PlayingCard) -> some View {
        VStack(spacing: -width * 0.02) {
            Text(card.label)
                .font(.system(size: width * 0.2, weight: .bold, design: .rounded))
            Text(card.suit.symbol)
                .font(.system(size: width * 0.15))
        }
        .foregroundStyle(card.suit.color)
    }

    // MARK: - Rueckseite

    private var backSurface: some ShapeStyle {
        LinearGradient(
            colors: [BeerStatsColor.surfaceElevated, BeerStatsColor.backgroundPrimary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var back: some View {
        ZStack {
            // Das Becher-Signet ist das durchgaengige Zeichen der App – vom
            // Login ueber das Icon bis hierher.
            CupShape()
                .stroke(BeerStatsColor.accent.opacity(0.5), lineWidth: 2)
                .frame(width: width * 0.42, height: width * 0.5)

            RoundedRectangle(cornerRadius: width * 0.06, style: .continuous)
                .strokeBorder(BeerStatsColor.accent.opacity(0.25), lineWidth: 1)
                .padding(width * 0.08)
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        PlayingCardView(card: PlayingCard(rank: 14, suit: .hearts))
        PlayingCardView(card: PlayingCard(rank: 13, suit: .spades))
        PlayingCardView(card: nil)
    }
    .padding(30)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BeerStatsColor.backgroundPrimary)
}
