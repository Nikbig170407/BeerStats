//
//  Throw.swift
//  BeerStats
//
//  Append-Only-Ereignis-Log (siehe Architektur-Dokument 3.5): ein Throw-
//  Dokument wird nie verändert oder gelöscht, nur erstellt. Korrekturen
//  laufen über einen kompensierenden Eintrag mit result == .undo, nicht
//  über Löschen – das hält die Cloud-Function-Aggregation robust und
//  nachvollziehbar.
//
//  Alle Sonderregeln (On Fire, Bounce Shot, Trickshot, Airball,
//  Doppeltreffer) sind bewusst als einzelne, klar benannte Felder auf
//  diesem einen Modell abgebildet statt über mehrere verschachtelte Typen –
//  das hält die Cloud Function, die pro Throw die Statistiken fortschreibt,
//  einfach und die Regel-Logik an einer Stelle nachvollziehbar.
//

import Foundation
import FirebaseFirestore

/// Das Ergebnis eines einzelnen Wurfs.
enum ThrowResult: String, Codable {
    case hit
    case miss
    /// Weder Becher (auch keine Kante) noch Tisch getroffen – eigene
    /// Kategorie statt `miss`, damit Airball-Statistiken separat auswertbar
    /// sind und die Trink-Strafe eindeutig zuordenbar bleibt.
    case airball
    case redemption
    case reRack
    case undo
}

/// Woher dieser Wurf kommt – entscheidet u. a. darüber, ob bei einem
/// Fehlwurf die Airball-Regel überhaupt greift (bei Trickshots nicht).
enum ThrowType: String, Codable {
    case normal
    /// Bonus-Wurf durch On-Fire-Serie (3+ Treffer in Folge desselben Spielers).
    case onFireBonus
    /// Bonus-Wurf durch einen gefangenen Trickshot. Ein Fehlwurf hier zählt
    /// bewusst NIE als Airball (siehe Regelbesprechung).
    case trickshotAttempt
}

struct Throw: Codable, Identifiable, Equatable {

    @DocumentID var id: String?

    var playerId: String
    var teamId: String
    var targetTeamId: String

    /// Welcher Becher getroffen wurde, falls zutreffend (nicht gesetzt bei
    /// miss/airball).
    var cupId: String?

    var result: ThrowResult
    var throwType: ThrowType = .normal

    /// Fortlaufende Wurf-Nummer, garantiert die Reihenfolge unabhängig von
    /// Netzwerk-Latenz einzelner Geräte.
    var sequenceNumber: Int

    /// Durchgangs-Nummer – wird gebraucht, um zu erkennen, ob zwei Treffer
    /// "im selben Durchgang" liegen (Regel: beide Spieler eines Teams
    /// treffen → Bälle zurück).
    var roundNumber: Int

    /// Aufsetzer, der trotzdem im Becher landet – zählt 2 Becher, aber nur
    /// +1 für den On-Fire-Streak (siehe Regelbesprechung).
    var isBounce: Bool = false

    /// Wird auf `true` gesetzt, wenn dieser (verfehlte) Wurf die
    /// Trickshot-Bedingung erfüllt hat (Ball fliegt ohne Bodenkontakt
    /// zurück und wird vom eigenen Team gefangen). Der werfende Spieler
    /// bekommt dadurch einen Trickshot-Bonuswurf.
    var enablesTrickshot: Bool = false

    /// Bei throwType == .onFireBonus oder .trickshotAttempt: Referenz auf
    /// den ursprünglichen Wurf, der diesen Bonuswurf ausgelöst hat –
    /// hält die Kausalkette im Log nachvollziehbar.
    var triggeredByThrowId: String?

    /// Anzahl der durch diesen Wurf entfernten Becher: normalerweise 1,
    /// bei Bounce Shot oder erfolgreichem Trickshot 2, bei
    /// Doppeltreffer-gleicher-Becher 3 (der Becher selbst + 2 gewählte).
    var cupsRemoved: Int = 0

    /// Nur bei "beide treffen denselben Becher": die 2 zusätzlich
    /// entfernten Becher, ausgewählt vom Team, das sie trinken muss.
    var chosenCupIds: [String]?

    @ServerTimestamp var timestamp: Date?

    init(
        id: String? = nil,
        playerId: String,
        teamId: String,
        targetTeamId: String,
        cupId: String? = nil,
        result: ThrowResult,
        throwType: ThrowType = .normal,
        sequenceNumber: Int,
        roundNumber: Int,
        isBounce: Bool = false,
        enablesTrickshot: Bool = false,
        triggeredByThrowId: String? = nil,
        cupsRemoved: Int = 0,
        chosenCupIds: [String]? = nil
    ) {
        self.id = id
        self.playerId = playerId
        self.teamId = teamId
        self.targetTeamId = targetTeamId
        self.cupId = cupId
        self.result = result
        self.throwType = throwType
        self.sequenceNumber = sequenceNumber
        self.roundNumber = roundNumber
        self.isBounce = isBounce
        self.enablesTrickshot = enablesTrickshot
        self.triggeredByThrowId = triggeredByThrowId
        self.cupsRemoved = cupsRemoved
        self.chosenCupIds = chosenCupIds
    }

    /// Ob ein Airball bei diesem Wurf eine Trink-Strafe auslöst. Zentral
    /// hier als eine Regel definiert, statt die throwType-Prüfung an
    /// mehreren Stellen (Cloud Function, ViewModel, UI) zu wiederholen.
    var triggersAirballPenalty: Bool {
        result == .airball && throwType != .trickshotAttempt
    }
}
