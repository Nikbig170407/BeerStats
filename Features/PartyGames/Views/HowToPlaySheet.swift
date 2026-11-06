//
//  HowToPlaySheet.swift
//  BeerStats
//
//  Die Anleitung eines Spiels – hinter einem Fragezeichen, nicht im Weg.
//
//  Wunsch des Nutzers vom 6. November: "allgemein in der App ist viel zu
//  viel Text … mach das hinter so ein Fragezeichen". Vorher stand die
//  Anleitung als Absatz auf der Seite des Spiels, und jeder Vorspann
//  erklaerte die Regeln noch einmal mit eigenen Worten. Jetzt gibt es sie
//  an EINER Stelle (`PartyGame.howToPlay`) und zwei Wege dorthin: das
//  Fragezeichen auf der Seite des Spiels und das oben rechts im Spiel,
//  neben dem Zahnrad (`RoundSettingsModifier`, `IntensityGate`).
//

import SwiftUI

/// Das Fragezeichen fuer die Leiste oben rechts.
struct HowToPlayButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(BeerStatsColor.textSecondary)
                // Die ganze Flaeche nimmt den Tipp an (Lessons Learned Nr. 4)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Wie geht's?")
    }
}

/// Das Blatt mit den Schritten.
struct HowToPlaySheet: View {

    let game: PartyGame

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdrop(glow: game.tint)

                FillingScrollView(alignment: .top) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(game.howToPlay.enumerated()), id: \.offset) { nummer, schritt in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("\(nummer + 1)")
                                    .font(.scaled(15, weight: .heavy, design: .rounded))
                                    .foregroundStyle(game.tint)
                                    .frame(minWidth: 18, alignment: .trailing)
                                Text(schritt)
                                    .font(BeerStatsFont.body)
                                    .foregroundStyle(BeerStatsColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                }
            }
            .navigationTitle("Wie geht's?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .font(BeerStatsFont.headline)
                }
            }
        }
        // Halb hoch reicht fuer drei, vier Zeilen – und das Spiel bleibt
        // darunter sichtbar
        .presentationDetents([.medium, .large])
    }
}

/// Fragezeichen samt Blatt fuer Screens, an denen kein Zahnrad haengt –
/// die Seite des Spiels und der Haerte-Vorspann.
private struct HowToPlayModifier: ViewModifier {

    let game: PartyGame
    @State private var showsHelp = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HowToPlayButton { showsHelp = true }
                }
            }
            .sheet(isPresented: $showsHelp) {
                HowToPlaySheet(game: game)
            }
    }
}

extension View {

    /// Das Fragezeichen oben rechts. In einem Spiel bringt es
    /// `roundSettings` schon mit – dort nicht noch einmal anhaengen, sonst
    /// stuenden zwei Blaetter an einer Ansicht.
    func howToPlay(for game: PartyGame) -> some View {
        modifier(HowToPlayModifier(game: game))
    }
}
