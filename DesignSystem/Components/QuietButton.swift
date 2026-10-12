//
//  QuietButton.swift
//  BeerStats
//
//  Die leise Nebenhandlung: "Neu mischen", "Spielerzahl ändern",
//  "Rückgängig".
//
//  Vierundzwanzigmal stand dafuer dasselbe im Projekt – ein `Button` mit
//  Beschriftung in Kleinschrift und grauer Farbe, ohne alles andere. Genau
//  dieses "ohne alles andere" war das Problem: Ohne Innenabstand und ohne
//  `contentShape` ist nur die Schrift selbst tastbar, und die ist bei
//  Kleinschrift rund fuenfzehn Punkte hoch. Apple nennt vierundvierzig als
//  Mindestmass, und am Tisch wird nicht gezielt. Wer knapp daneben tippt,
//  hat einen Knopf, der nicht reagiert – nicht, weil er kaputt ist,
//  sondern weil er nicht getroffen wurde. Das ist Lessons Learned Nr. 4 in
//  seiner leisen Form: Die Trefferflaeche gehoert ins Label.
//
//  Bewusst ohne eigene Haptik: Die Aufrufstellen melden sich selbst, wenn
//  es etwas zu melden gibt. Zwei Rueckmeldungen auf einen Tipp fuehlen sich
//  nach Doppeltipp an.
//

import SwiftUI

struct QuietButton: View {

    let title: String
    var systemImage: String? = nil
    /// Nur fuer die seltenen Faelle, in denen die Nebenhandlung warnt.
    var tint: Color = BeerStatsColor.textSecondary
    let action: () -> Void

    /// Ein abgeschalteter Knopf muss auch abgeschaltet aussehen. `.disabled`
    /// von aussen sperrt sonst nur die Reaktion, und ein Knopf, der normal
    /// aussieht und nichts tut, ist genau der Fehler, den dieser Baustein
    /// beheben soll.
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(BeerStatsFont.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(tint)
            .opacity(isEnabled ? 1 : 0.4)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    VStack(spacing: 12) {
        QuietButton(title: "Neu mischen") {}
        QuietButton(title: "Rückgängig", systemImage: "arrow.uturn.backward") {}
        QuietButton(title: "Abend verwerfen", tint: BeerStatsColor.error) {}
        QuietButton(title: "Gesperrt") {}
            .disabled(true)
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BeerStatsColor.backgroundPrimary)
}
