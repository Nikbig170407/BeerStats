//
//  IntensityGate.swift
//  BeerStats
//
//  Der Vorspann fuer Spiele, die sonst keinen haben: nur die Haerte, dann
//  los.
//
//  Acht Spiele fragen vorher ohnehin etwas (Spielerzahl, Kartenzahl,
//  Kategorie) – dort steht die Haerte in diesem Vorspann mit drin, sonst
//  waeren es zwei Screens hintereinander, die gleich aussehen. Die
//  restlichen acht fingen bisher sofort an; die bekommen diesen hier.
//
//  Welches Spiel was braucht, steht im Katalog (`PartyGame.intensityStep`)
//  und nicht hier: Ein neues Spiel soll an einer Stelle beschrieben werden,
//  nicht an zwei.
//
//  Der Vorspann kommt genau einmal. Wer eine Runde spielt, die Haerte
//  danach anders will, geht zurueck und wieder rein – das ist derselbe Weg
//  wie bei der Spielerzahl und braucht keinen zweiten Knopf im Spiel.
//

import SwiftUI

struct IntensityGate<Content: View>: View {

    let game: PartyGame
    @ViewBuilder let content: () -> Content

    @State private var hasStarted = false

    var body: some View {
        if hasStarted {
            content()
        } else {
            GameSetupScreen(
                emoji: game.emoji,
                title: game.title,
                subtitle: "Wie hart wird in dieser Runde getrunken?",
                tint: game.tint,
                onStart: { hasStarted = true }
            ) {
                DrinkIntensityPicker(game: game)
            }
        }
    }
}
