//
//  TypewriterText.swift
//  BeerStats
//
//  Ein Text, der sich tippt wie auf einer Schreibmaschine.
//
//  Die Grenze ist eine Zusage an den Nutzer, keine Geschmacksfrage: Text
//  steht nach spaetestens einer halben Sekunde (Rueckmeldung zur Vorschau
//  der Spielwelten, 28. Oktober – "manche Schriften dauern zu lange, um
//  dazustehen"). Deshalb ist die Dauer fest und haengt NICHT an der
//  Laenge: Ein langes Wort tippt sich schneller, nicht laenger.
//
//  Der noch nicht getippte Rest steht unsichtbar mit im Satz. So bricht die
//  Zeile von Anfang an dort um, wo sie am Ende umbricht – ohne das springt
//  der Text bei jedem Buchstaben in eine neue Lage.
//

import SwiftUI

struct TypewriterText: View {

    let text: String
    var font: Font

    /// Kurz warten, bis das, worauf der Text steht, ausgerollt ist.
    static let delay: Double = 0.2
    /// So lange tippt jeder Text, egal wie lang er ist.
    static let typing: Double = 0.25

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var done = false

    var body: some View {
        Group {
            if done || reduceMotion {
                Text(text).font(font)
            } else {
                // Voll ausgeschrieben: Bis zum 29. Oktober hiess ein eigener
                // Screen `TimelineView` (Lessons Learned Nr. 15), und ein
                // neuer koennte es wieder tun.
                SwiftUI.TimelineView(.animation) { timeline in
                    typed(upTo: count(at: timeline.date.timeIntervalSince(start)))
                }
            }
        }
        // VoiceOver liest den ganzen Text sofort, nicht Buchstabe fuer
        // Buchstabe und nicht den unsichtbaren Rest als zweiten Teil.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
        // Neuer Text, neues Tippen. Die Aufgabe endet mit der Ansicht – die
        // Zeitleiste laeuft nicht weiter, wenn niemand hinsieht.
        .task(id: text) {
            done = false
            start = Date()
            try? await Task.sleep(nanoseconds: UInt64((Self.delay + Self.typing) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            done = true
        }
    }

    private func count(at elapsed: Double) -> Int {
        let anteil = min(1, max(0, (elapsed - Self.delay) / Self.typing))
        return Int((Double(text.count) * anteil).rounded(.down))
    }

    /// Getippter Teil in der Farbe der Umgebung, der Rest unsichtbar.
    private func typed(upTo count: Int) -> Text {
        let getippt = Text(String(text.prefix(count)))
        let rest = Text(String(text.dropFirst(count))).foregroundColor(.clear)
        return (getippt + rest).font(font)
    }
}
