//
//  ThrowServiceProtocol.swift
//  BeerStats
//
//  Kapselt die `throws`-Subcollection eines Spiels.
//
//  Der Log ist bewusst append-only: Einträge werden nur angelegt, nie
//  geändert oder gelöscht. Eine Korrektur ist ein zusätzlicher Eintrag mit
//  `result == .undo`. Das hält die spätere Cloud-Function-Aggregation
//  robust – sie muss nie einen bereits verarbeiteten Eintrag zurückrollen,
//  und die Historie bleibt nachvollziehbar.
//

import Foundation

protocol ThrowServiceProtocol {

    /// Hängt einen Eintrag an den Log an.
    func appendThrow(_ throwEvent: Throw, gameId: String) async throws

    /// Echtzeit-Stream aller Einträge eines Spiels, aufsteigend nach
    /// `sequenceNumber`. Grundlage für das Nachspielen des Spielstands auf
    /// jedem beteiligten Gerät.
    func observeThrows(gameId: String) -> AsyncStream<[Throw]>

    /// Einmaliger Abruf statt Dauerbeobachtung – für Auswertungen
    /// abgeschlossener Partien, bei denen sich nichts mehr ändert.
    func fetchThrows(gameId: String) async throws -> [Throw]
}
