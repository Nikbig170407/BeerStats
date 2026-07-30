//
//  PressableButtonStyle.swift
//  BeerStats
//
//  Wiederverwendbarer Button-Stil: skaliert beim Drücken leicht herunter
//  und wird minimal transparenter, statt abrupt die Hintergrundfarbe zu
//  wechseln. Das ist der Kern des "smoothen" Gefühls, das an vielen
//  Stellen der App gewünscht ist – ein einziger Baustein, den jeder
//  Button in der App wiederverwendet, statt dass jede View ihr eigenes
//  Press-Verhalten erfindet.
//

import SwiftUI

struct PressableButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(AppAnimation.tap, value: configuration.isPressed)
    }
}
