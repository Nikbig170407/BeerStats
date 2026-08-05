//
//  BingoDeck.swift
//  BeerStats
//
//  Ereignisse fuer das Trinkbingo.
//
//  Alle so gewaehlt, dass sie an einem normalen Abend von selbst passieren –
//  niemand soll etwas absichtlich herbeifuehren muessen. Ein Feld wie
//  "jemand macht einen Handstand" waere kein Bingo, sondern eine Aufgabe.
//
//  Und alle so, dass die ganze Runde sie mitbekommt. Was nur einer sieht,
//  fuehrt zu Diskussionen statt zu einem Kreuz.
//

import Foundation

enum BingoDeck {

    static var count: Int { all.count }

    /// Sechzehn verschiedene Ereignisse fuer ein Blatt.
    static func draw(_ count: Int = 16) -> [String] {
        Array(all.shuffled().prefix(count))
    }

    static let all: [String] = [
        "Jemand verschüttet etwas",
        "Jemand geht aufs Klo",
        "Jemand schaut aufs Handy",
        "Jemand sagt „ich trink nichts mehr“",
        "Jemand lacht sich weg",
        "Zwei reden gleichzeitig",
        "Jemand erzählt dieselbe Geschichte nochmal",
        "Jemand macht das Licht anders",
        "Jemand ändert die Musik",
        "Jemand singt mit",
        "Jemand steht auf und setzt sich wieder",
        "Jemand holt Nachschub",
        "Jemand macht ein Foto",
        "Jemand vergisst, wer dran ist",
        "Jemand erklärt die Regeln neu",
        "Jemand beschwert sich über die Regeln",
        "Jemand will ein anderes Spiel",
        "Jemand redet über die Arbeit",
        "Jemand redet über seinen Ex",
        "Jemand gähnt",
        "Jemand niest",
        "Jemand stößt an, ohne dass es nötig wäre",
        "Jemand nimmt das falsche Glas",
        "Jemand verliert seinen Platz",
        "Jemand fragt, wie spät es ist",
        "Jemand macht ein Fenster auf",
        "Jemand redet mit dem Handy in der Hand",
        "Jemand isst etwas vom Tisch",
        "Jemand sagt „nur noch eine Runde“",
        "Jemand ruft jemanden an",
        "Jemand fällt fast vom Stuhl",
        "Jemand wiederholt einen Witz",
        "Jemand verteidigt seinen Musikgeschmack",
        "Jemand behauptet, nüchtern zu sein",
        "Jemand zählt falsch",
        "Jemand fragt nach den Regeln von vorhin",
        "Jemand macht ein Kompliment",
        "Jemand ärgert sich über eine Karte",
        "Jemand wettet um etwas",
        "Jemand verlässt kurz den Raum"
    ]
}
