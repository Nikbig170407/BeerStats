//
//  TurnRow.swift
//  BeerStats
//
//  „🍺 Lena ist dran" – eine Zeile, acht Spiele.
//
//  Manche Spiele sagten es (Mäxchen, Der Spion, Kennst du deine Leute?),
//  andere nicht. Dort reichte die App das Handy weiter und die Runde
//  diskutierte, wer jetzt muss – bei "Ich hab noch nie" ist das nach drei
//  Karten eine echte Frage, weil niemand mehr weiss, wo der Kreis gerade
//  steht.
//
//  Die Zeile rechnet nicht selbst, wer dran ist: Die Spiele zaehlen, wie oft
//  sie weitergegangen sind, und `PlayerNames.nameForTurn` macht daraus einen
//  Namen. Dadurch gilt dieselbe Quellen-Reihenfolge wie ueberall – laufender
//  Abend, sonst Tisch – und die Trinkbilanz bleibt auf denselben Positionen.
//
//  **Steht niemand fest, ist die Zeile weg.** Nicht "Spieler 3 ist dran":
//  Das hilft niemandem, der nicht weiss, wer die Drei ist, und wuerde einen
//  Vorspann vortaeuschen, den es nicht gibt. Leer ist ein gueltiger Zustand.
//

import SwiftUI

struct TurnRow: View {

    /// Der fortlaufende Zaehler des Spiels – nicht die Position am Tisch.
    let turn: Int
    var tint: Color = BeerStatsColor.accent

    var body: some View {
        if let name = PlayerNames.nameForTurn(turn) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 11, weight: .bold))
                Text("\(name) ist dran")
                    .font(.scaled(13, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(tint.opacity(0.14), in: Capsule())
            .transition(.opacity)
            .animation(AppAnimation.standard, value: turn)
        }
    }
}
