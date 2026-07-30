//
//  Team.swift
//  BeerStats
//
//  Wird eingebettet im Game-Dokument gehalten (nicht als Subcollection),
//  da Teams klein, während des Spiels unveränderlich in der Zusammensetzung
//  und immer zusammen mit dem Spiel gelesen werden (siehe Architektur-
//  Dokument 3.4).
//

import Foundation

struct Team: Codable, Identifiable, Equatable {

    var id: String
    var playerIds: [String]

    /// Denormalisiert, damit Spielernamen ohne zusätzliche User-Lookups
    /// direkt in der Spiel-Ansicht angezeigt werden können.
    var playerNames: [String]

    var score: Int = 0

    /// Bälle, die dieses Team aktuell im Spiel hat. Normalerweise 1 pro
    /// Spieler, kann durch die "beide treffen"-Regel kurzzeitig auf 2 pro
    /// Spieler steigen (beide Bälle werden zurückgegeben).
    var ballsInPlay: Int
}
