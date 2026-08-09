//
//  BeerpongActivityAttributes.swift
//  BeerStats · BeerStatsWidgets
//
//  Was auf dem Sperrbildschirm steht, waehrend eine Partie laeuft.
//
//  Diese Datei liegt in BEIDEN Zielen – der App, die die Anzeige startet und
//  fortschreibt, und der Widget-Extension, die sie zeichnet. Nur so kennen
//  beide denselben Typ; ein zweites, gleich aussehendes Struct wuerde beim
//  Dekodieren scheitern.
//
//  ActivityKit gibt es erst ab iOS 16.1, das Deployment-Target der App ist
//  16.0. Deshalb ist alles hier ausdruecklich als verfuegbar-ab markiert; die
//  App prueft das zur Laufzeit, das Widget-Ziel baut gleich gegen 16.1.
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct BeerpongActivityAttributes: ActivityAttributes {

    /// Aendert sich waehrend der Partie.
    struct ContentState: Codable, Hashable {
        var cupsTeamOne: Int
        var cupsTeamTwo: Int
        /// Wer gerade wirft.
        var thrower: String
        /// Ball 1/2, Trickshot, On Fire – der Zusatz aus der Zug-Anzeige.
        var detail: String
    }

    /// Steht beim Start fest und bleibt gleich.
    var teamOne: String
    var teamTwo: String
}
#endif
