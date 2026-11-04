//
//  PartyGameCover.swift
//  BeerStats
//
//  Ein Spiel als Cover im Raster der Spielauswahl.
//
//  Oben das Bild, unten ein Balken mit Titel, Dauer und Spielerzahl. Der
//  Titel kommt aus der App und nicht aus der Zeichnung: So steht er in der
//  Schrift der Spielwelt, bleibt scharf und folgt der Schriftgroesse.
//
//  Hat ein Spiel noch keine Zeichnung (`PartyGame.coverArt` ist `nil`),
//  traegt es den stillen Grund seiner Welt mit seinem Zeichen – derselbe
//  Deckel, den vorher die Kacheln in den Ordnern hatten.
//

import SwiftUI

struct PartyGameCover: View {

    let game: PartyGame

    /// Dieselbe Einstellung wie fuer den Grund im Spiel: Bei "Schlicht" traegt
    /// der Deckel nur die Grundfarbe seiner Welt.
    @AppStorage(AppAppearance.backdropKey) private var backdropRaw = BackdropStyle.bubbles.rawValue

    private static let corner: CGFloat = 16

    var body: some View {
        ZStack(alignment: .bottom) {
            artwork
            titleBand
        }
        .aspectRatio(CoverArt.aspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Self.corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.corner, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: Self.corner, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(game.title), \(game.length.label), Spieler \(game.playersLabel)")
    }

    @ViewBuilder
    private var artwork: some View {
        if let kunst = game.coverArt {
            // Still gezeichnet: Eine Liste, in der ueberall etwas laeuft,
            // liest sich nicht mehr
            Canvas { context, size in kunst.draw(&context, size) }
                .accessibilityHidden(true)
        } else {
            ZStack {
                WorldGround(
                    world: game.world,
                    plain: backdropRaw == BackdropStyle.plain.rawValue,
                    moves: false,
                    fillsScreen: false
                )
                .equatable()
                LinearGradient(
                    colors: [Color.black.opacity(0.1), Color.black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // Feste Groesse: Emoji in einem Rahmen fester Form laufen
                // sonst ueber
                Text(game.emoji)
                    .font(.system(size: 58))
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
                    .offset(y: -22)
            }
            .accessibilityHidden(true)
        }
    }

    /// Titel und die zwei Angaben, nach denen am Tisch gefragt wird, bevor
    /// jemand antippt: Wie lange dauert das, und reichen wir dafuer?
    private var titleBand: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(game.title)
                .font(Font.world(game.world, 15, weight: .heavy))
                .foregroundStyle(PosterInk.cream)
                .keepsWordsWhole(game.title)
            Text("\(game.length.label) · \(game.playersLabel)")
                .font(.scaled(10, weight: .heavy, design: .rounded))
                .foregroundStyle(PosterInk.cream.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(game.coverArt?.band ?? Color.black.opacity(0.72))
    }
}
