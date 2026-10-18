//
//  LiveGameFeedback.swift
//  BeerStats
//
//  Was das Geraet bei einem Ereignis tut: ruetteln und klingen.
//
//  Reine Nebenwirkung, kein Zustand – deshalb statisch. Stand bis zum
//  18. Oktober in derselben Funktion wie die Einblendungstexte; jede
//  Aenderung an einem Satz war damit auch eine Aenderung an etwas, das sich
//  nur am Geraet pruefen laesst.
//
//  Das Spielende klingt hier NICHT nach Sieg fuer eine Seite: Die Haptik
//  kennt kein Team. Der Sieger-Screen macht das Weitere.
//

import Foundation

enum LiveGameFeedback {

    static func play(for event: GameEvent) {
        switch event {
        case .hit:
            HapticManager.mediumImpact()
            SoundManager.play(.cupHit)
        case .airball(_, let penalised):
            HapticManager.error()
            // Der folgenlose Airball im Trickshot bleibt still: Ein
            // Warnklang fuer etwas, das nichts kostet, erzieht die Runde
            // dazu, den Klang zu ignorieren.
            if penalised { SoundManager.play(.airball) }
        case .caughtFire:
            HapticManager.success()
            SoundManager.play(.onFire)
        case .ballsBack:
            HapticManager.success()
            SoundManager.play(.ballsBack)
        case .bombe:
            HapticManager.success()
            SoundManager.play(.bombe)
        case .redemptionStarted:
            HapticManager.mediumImpact()
            SoundManager.play(.onFire)
        case .reRacked:
            HapticManager.mediumImpact()
            SoundManager.play(.reRack)
        case .finished:
            HapticManager.success()
            SoundManager.play(.victory)
        case .cupChosen:
            HapticManager.lightImpact()
            SoundManager.play(.tap)
        case .missed, .rebound:
            HapticManager.lightImpact()
            SoundManager.play(.miss)
        }
    }
}
