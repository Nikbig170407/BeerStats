//
//  LiveGameActivity.swift
//  BeerStats
//
//  Startet, aktualisiert und beendet die Anzeige auf dem Sperrbildschirm.
//
//  Der ganze ActivityKit-Umgang liegt hier, damit das ViewModel nichts davon
//  wissen muss: Es ruft drei Funktionen, und ob die Anzeige ueberhaupt
//  moeglich ist, entscheidet sich hier drin. Auf iOS 16.0 oder mit
//  abgeschalteten Live-Aktivitaeten passiert schlicht nichts.
//
//  Die laufende Aktivitaet steckt in einem `Any?`, weil `Activity<…>` erst ab
//  16.1 existiert und eine gespeicherte Eigenschaft dieses Typs den ganzen
//  Typ hier mit einer Verfuegbarkeitsangabe belegen wuerde – und damit auch
//  jeden Aufrufer.
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

enum LiveGameActivity {

    private static var handle: Any?

    /// Beginnt eine Anzeige fuer die laufende Partie. Eine bereits laufende
    /// wird vorher beendet – zwei Anzeigen fuer dasselbe Spiel waeren nur
    /// verwirrend.
    static func start(
        teamOne: String,
        teamTwo: String,
        cupsTeamOne: Int,
        cupsTeamTwo: Int,
        thrower: String,
        detail: String
    ) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        end()

        let attributes = BeerpongActivityAttributes(teamOne: teamOne, teamTwo: teamTwo)
        let state = BeerpongActivityAttributes.ContentState(
            cupsTeamOne: cupsTeamOne,
            cupsTeamTwo: cupsTeamTwo,
            thrower: thrower,
            detail: detail
        )

        // Bewusst `try?`: Scheitert der Start – etwa weil das System gerade
        // keine weitere Aktivitaet zulaesst –, soll das Spiel trotzdem
        // weiterlaufen. Die Anzeige ist Beiwerk.
        handle = try? Activity.request(attributes: attributes, contentState: state)
        #endif
    }

    static func update(cupsTeamOne: Int, cupsTeamTwo: Int, thrower: String, detail: String) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        guard let activity = handle as? Activity<BeerpongActivityAttributes> else { return }

        let state = BeerpongActivityAttributes.ContentState(
            cupsTeamOne: cupsTeamOne,
            cupsTeamTwo: cupsTeamTwo,
            thrower: thrower,
            detail: detail
        )
        Task { await activity.update(using: state) }
        #endif
    }

    static func end() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        guard let activity = handle as? Activity<BeerpongActivityAttributes> else { return }
        handle = nil
        // `.immediate`, nicht auslaufen lassen: Eine Partie ist vorbei, wenn
        // sie vorbei ist – ein Rest, der noch Minuten auf dem Sperrbildschirm
        // klebt, waere nur im Weg.
        Task { await activity.end(using: nil, dismissalPolicy: .immediate) }
        #endif
    }
}
