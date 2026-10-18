//
//  TapZone.swift
//  BeerStats
//
//  Eine grosse Flaeche am unteren Rand statt eines Knopfes.
//
//  Zwei Spiele laufen gegen die Uhr und werden dabei NICHT von der Person
//  bedient, die ruhig aufs Display schaut: Bei "Wer bin ich?" haelt die
//  ratende Person das Handy an die Stirn und ein Nachbar tippt, bei der
//  Pantomime steht die vorspielende Person daneben und greift im Vorbeigehen
//  hin. Beide Male wird nicht gezielt – deshalb je eine halbe Bildschirm-
//  breite und 130 Punkte Hoehe statt einer Schaltflaeche.
//
//  Das ist Lessons Learned Nr. 4 und Nr. 12 in gross: Hintergrund und
//  `contentShape` liegen im Label, nicht darum herum.
//

import SwiftUI

struct TapZone: View {

    let title: String
    let tint: Color
    let action: () -> Void

    static let height: CGFloat = 130

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.scaled(22, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(tint.opacity(0.15))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}
