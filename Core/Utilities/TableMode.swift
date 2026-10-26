//
//  TableMode.swift
//  BeerStats
//
//  Der Tischmodus: Das Handy liegt in der Mitte, alle schauen drauf.
//
//  Die App ist fuer eine Hand gebaut – fuer die Person, die gerade tippt.
//  Den groesseren Teil des Abends liegt sie aber auf dem Tisch und wird von
//  fuenf bis sieben Leuten aus anderthalb Metern angeschaut. Aus der
//  Entfernung ist Fliesstext nicht mehr zu lesen, und waehrend alle reden,
//  schaltet sich der Bildschirm ab.
//
//  Zwei Schalter loesen beides, und zwar APP-WEIT statt Screen fuer Screen:
//
//  1. **Groessere Schrift.** Nur als UNTERGRENZE (`.accessibility1...`),
//     nicht als feste Groesse: Wer die Systemschrift ohnehin groesser
//     gestellt hat, behaelt seine Einstellung. Eine feste Groesse wuerde
//     ausgerechnet denen, die sie brauchen, die Schrift verkleinern.
//     Moeglich ist das ueberhaupt nur, weil die Textstile seit Oktober
//     ueber `Font.scaled` laufen und damit der Systemeinstellung folgen –
//     haetten sie feste Groessen, waere der Tischmodus hundert
//     Einzelaenderungen.
//  2. **Der Bildschirm bleibt an.** Ein Handy, das mitten in der Runde
//     Ring of Fire zusperrt, ist der haeufigste Griff zum Geraet, den es
//     gar nicht braeuchte.
//
//  Was der Modus NICHT tut: die Ansichten umbauen. Querformat erlaubt die
//  App ohnehin (es gibt keine Orientierungs-Sperre), aber die Layouts sind
//  nie darin geprueft worden – ein eigener Quer-Aufbau waere fuenfundzwanzig
//  Spiele Arbeit und gehoert nicht in denselben Schritt.
//

import SwiftUI

enum TableMode {

    static let storageKey = "app.tableMode"

    static var isOn: Bool {
        get { UserDefaults.standard.bool(forKey: storageKey) }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }
}

/// Legt den Tischmodus ueber die ganze App.
///
/// Als Modifier und nicht als Einstellung in jeder Ansicht: Es gibt genau
/// eine Stelle, an der die App zusammengesetzt wird, und genau dort gehoert
/// etwas hin, das fuer alles gilt.
struct TableModeModifier: ViewModifier {

    let isOn: Bool

    func body(content: Content) -> some View {
        Group {
            if isOn {
                // Untergrenze, keine feste Groesse – siehe Dateikopf.
                content.dynamicTypeSize(.accessibility1...)
            } else {
                content
            }
        }
        // Der Bildschirm gehoert zum Modus, nicht zum Screen: Er muss auch
        // dann anbleiben, wenn gerade niemand tippt.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = isOn }
        .onChange(of: isOn) { neu in
            UIApplication.shared.isIdleTimerDisabled = neu
        }
        // Beim Verlassen der App zuruecknehmen: Sonst bliebe das Display
        // einer fremden App wach, weil hier einmal ein Schalter umgelegt
        // wurde.
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

extension View {

    /// Siehe `TableMode`.
    func tableMode(_ isOn: Bool) -> some View {
        modifier(TableModeModifier(isOn: isOn))
    }
}
