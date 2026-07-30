//
//  GameAction.swift
//  BeerStats
//
//  Das Vokabular dessen, was während eines Spiels passieren kann.
//
//  Liegt bewusst bei den Modellen und nicht in der Engine: Die Aktion ist
//  Teil der Fachsprache des Spiels und wird an drei Stellen gebraucht – von
//  der Engine (die sie ausführt), von der View (die sie auslöst) und vom
//  Throw-Log in Firestore (der sie speichert).
//
//  `Codable`, weil jede Aktion als Feld eines Throw-Dokuments abgelegt wird.
//  Erst dadurch ist der Log exakt wiederabspielbar: Jedes Gerät schickt
//  denselben Log durch dieselbe Engine und landet zwangsläufig auf demselben
//  Spielstand – ohne dass der Server irgendetwas berechnen müsste.
//

import Foundation

enum GameAction: Codable, Equatable {

    /// Becher auf dem gegnerischen Rack getroffen.
    case hitCup(index: Int)
    /// Danebengeworfen, Ball ist aus dem Spiel.
    case miss
    /// Weder Becher noch Tisch getroffen.
    case airball
    /// Ball kam ohne Bodenkontakt zurück und wurde gefangen – derselbe
    /// Spieler bekommt einen Trickshot-Bonuswurf.
    case rebound
    /// Zweiter Werfer trifft denselben Becher wie sein Teamkollege.
    case bombe
    /// Nächster Treffer war ein Aufsetzer.
    case toggleBounce
    /// Becher im Rahmen einer erzwungenen Auswahl wegstellen.
    case chooseCup(index: Int)
    /// Gegnerische Becher neu aufstellen.
    case reRack(RackFormation)

    /// Ob diese Aktion überhaupt in den Log gehört. Das Scharfschalten des
    /// Bounce-Schalters ist reine Bedienung und verändert den Spielstand
    /// nicht – im Log wäre es nur Rauschen.
    var isPersistable: Bool {
        if case .toggleBounce = self { return false }
        return true
    }

    /// Wie diese Aktion im Throw-Log als Wurf-Ergebnis erscheint. Grundlage
    /// für die spätere Statistik-Aggregation per Cloud Function.
    var throwResult: ThrowResult {
        switch self {
        case .hitCup, .bombe: return .hit
        case .miss, .rebound: return .miss
        case .airball: return .airball
        case .chooseCup: return .hit
        case .reRack: return .reRack
        case .toggleBounce: return .miss
        }
    }
}
