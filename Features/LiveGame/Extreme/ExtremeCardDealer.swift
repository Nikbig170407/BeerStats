//
//  ExtremeCardDealer.swift
//  BeerStats
//
//  Welche Becher geladen sind – und wann daraus eine Karte wird.
//
//  Die Auslosung und das Ausloesen standen im ViewModel, mitten zwischen
//  Firestore und Haptik. Dabei ist beides eine kleine, scharfe Regel, die
//  man pruefen koennen muss: Ein geladener Becher loest GENAU EINMAL aus.
//  Ohne das Entfernen aus der Menge wuerde dieselbe Position nach einem
//  Umstellen oder in der Redemption erneut feuern, obwohl der Becher
//  laengst weg ist – und am Tisch saehe das aus wie ein Fehler der App.
//
//  Zwei weitere Entscheidungen stecken hier drin:
//
//  Ausgelost wird EINMAL je Rack und nicht bei jedem Treffer neu. Sonst
//  waere "geladen" keine Eigenschaft des Bechers mehr, sondern eine
//  Wahrscheinlichkeit pro Wurf – und der Reiz des Modus ist gerade, dass
//  ein bestimmter Becher geladen IST und niemand weiss, welcher.
//
//  Jedes Team hat eigene geladene Becher. Ein gemeinsamer Satz haette
//  bedeutet, dass ein Treffer auf Position 3 immer auf beiden Seiten
//  ausloest.
//

import Foundation

struct ExtremeCardDealer {

    let settings: ExtremeSettings

    /// Geladene Becher je Team.
    private(set) var loadedCups: [Set<Int>]

    var isEnabled: Bool { settings.isEnabled }

    init(settings: ExtremeSettings, loadedCups: [Set<Int>] = [[], []]) {
        self.settings = settings
        self.loadedCups = loadedCups
    }

    /// Lost die geladenen Becher neu aus.
    ///
    /// Muss bei JEDEM neuen Rack laufen, nicht nur beim ersten: Ein
    /// geladener Becher wird beim Ausloesen aus der Menge entfernt, eine
    /// Revanche liefe sonst mit den Resten der Vorpartie – im schlechtesten
    /// Fall mit gar keinen Karten, waehrend die App weiter "Beerpong
    /// Extreme" anzeigt.
    mutating func reload(from state: LiveGameState, format: GameFormat) {
        guard settings.isEnabled else {
            loadedCups = [[], []]
            return
        }

        // Aus den LEBENDEN Positionen ziehen, nicht aus 0..<cupCount: Beim
        // fairen Anwurf fehlen einem Team schon zu Beginn Becher, und eine
        // geladene Position an einer leeren Stelle koennte nie ausloesen.
        // Das schwaechere Team haette sonst ausgerechnet weniger Karten.
        loadedCups = (0..<2).map { team in
            let lebende = state.racks.indices.contains(team)
                ? state.racks[team].aliveCupIndices
                : Array(0..<format.cupCount)
            return Set(lebende.shuffled().prefix(min(settings.loadedCups, lebende.count)))
        }
    }

    /// Zieht eine Karte, wenn dieses Ereignis einen geladenen Becher
    /// getroffen hat – sonst `nil`.
    mutating func card(for event: GameEvent) -> ExtremeCard? {
        guard settings.isEnabled, let treffer = hitCup(in: event) else { return nil }

        guard loadedCups.indices.contains(treffer.team),
              loadedCups[treffer.team].contains(treffer.cup) else { return nil }

        loadedCups[treffer.team].remove(treffer.cup)
        return ExtremeDeck.draw(mode: settings.mode)
    }

    /// Wessen Becher an welcher Stelle weggestellt wurde.
    ///
    /// Die beiden Faelle sind nicht dasselbe: Beim Treffer ist der
    /// Betroffene der GEGNER des Werfers, bei den Zusatzbechern aus Bombe
    /// und Bounce waehlt das betroffene Team selbst.
    private func hitCup(in event: GameEvent) -> (team: Int, cup: Int)? {
        switch event {
        case .hit(let thrower, _, _, let index):
            return (1 - thrower.teamIndex, index)
        case .cupChosen(let byTeamIndex, let index):
            return (byTeamIndex, index)
        default:
            return nil
        }
    }
}
