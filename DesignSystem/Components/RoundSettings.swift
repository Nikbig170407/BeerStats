//
//  RoundSettings.swift
//  BeerStats
//
//  Die Einstellungen eines Spiels mitten in der Runde: ein Zahnrad oben
//  rechts und ein Blatt mit denselben Schaltern wie im Vorspann.
//
//  Wunsch des Nutzers vom 28. Oktober, nach "Ich hab noch nie": "füg
//  während der Runde noch irgendwo ein Zahnrad ein, das man anklicken kann,
//  und dann die Einstellungen für das Spiel nochmal ändern kann". Vorher
//  ging das nur ueber "Einstellungen ändern" am Ende des Stapels – wer nach
//  zehn Karten merkte, dass die Runde mehr vertraegt, musste neu anfangen.
//
//  Zwei Bausteine, damit jedes Spiel dasselbe Zahnrad an derselben Stelle
//  hat und dasselbe Blatt oeffnet: `RoundSettingsButton` fuer die Leiste,
//  `RoundSettingsSheet` fuer das Blatt. Was im Blatt steht, bringt das Spiel
//  mit – im Idealfall genau die Schalter aus seinem Vorspann, damit es nur
//  EINE Stelle gibt, an der sie gebaut werden.
//

import SwiftUI

/// Das Zahnrad fuer die Leiste oben rechts.
///
/// Dasselbe Zeichen wie die Einstellungen der App im Hauptmenue – nur dass
/// es hier die Einstellungen des Spiels oeffnet, in dem man gerade ist.
struct RoundSettingsButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .foregroundStyle(BeerStatsColor.textSecondary)
                // Die ganze Flaeche nimmt den Tipp an, nicht nur das Zeichen
                // (Lessons Learned Nr. 4 und 12)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Einstellungen des Spiels")
    }
}

/// Das Blatt mit den Einstellungen eines Spiels.
///
/// `note` sagt, wann die Aenderung gilt – das ist je Spiel verschieden
/// ("ab der nächsten Karte", "ab der nächsten Runde") und gehoert dazu:
/// Wer mitten im Spiel umstellt, will wissen, was mit der laufenden Runde
/// passiert.
struct RoundSettingsSheet<Content: View>: View {

    let note: String
    /// Schon fertig gebaut und kein Closure: Der Inhalt landet in einer
    /// Ansicht mit `GeometryReader`, und dessen Closure darf keinen
    /// ViewBuilder-Parameter einfangen (Lessons Learned Nr. 13).
    let content: Content

    @Environment(\.dismiss) private var dismiss

    init(note: String, @ViewBuilder content: () -> Content) {
        self.note = note
        self.content = content()
    }

    var body: some View {
        let inhalt = content

        NavigationStack {
            ZStack {
                AmbientBackdrop()

                FillingScrollView(alignment: .top) {
                    VStack(spacing: 18) {
                        inhalt

                        Text(note)
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .font(BeerStatsFont.headline)
                }
            }
        }
        // Gross: Die Schalter sind der ganze Inhalt, und auf halber Hoehe
        // laege die Haerte unter dem Rand
        .presentationDetents([.large])
    }
}
