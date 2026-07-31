//
//  PlayerProfileServiceProtocol.swift
//  BeerStats
//
//  Kapselt die Profil-Sammlung eines Kontos:
//  `users/{ownerUid}/players/{profileId}`.
//
//  Anders als beim Wurf-Log dürfen diese Dokumente geändert werden – ein
//  Profil ist ein Stammdatensatz, kein Ereignis. Die Statistik darin wird
//  in dieser Ausbaustufe vom Gerät fortgeschrieben, nicht von einer Cloud
//  Function; deshalb braucht es hier auch eine inkrementelle
//  Aktualisierung statt nur "ganzes Dokument schreiben".
//

import Foundation

protocol PlayerProfileServiceProtocol {

    /// Echtzeit-Stream aller Profile eines Kontos.
    func observeProfiles(ownerId: String) -> AsyncStream<[PlayerProfile]>

    func fetchProfiles(ownerId: String) async throws -> [PlayerProfile]

    /// Legt ein Profil an und gibt die neue Dokument-ID zurück.
    func createProfile(_ profile: PlayerProfile, ownerId: String) async throws -> String

    /// Aktualisiert die Stammdaten – Name, Emoji, Farbe, Aktiv-Status.
    /// Rührt die Statistik bewusst nicht an, damit ein Umbenennen niemals
    /// versehentlich Kennzahlen überschreibt.
    func updateProfileDetails(
        profileId: String,
        ownerId: String,
        name: String,
        emoji: String,
        color: ProfileColor,
        isActive: Bool
    ) async throws

    /// Schreibt Kennzahlen additiv fort. Die Werte sind Deltas, keine
    /// Absolutwerte – zwei Geräte könnten sonst die Änderungen des jeweils
    /// anderen überschreiben.
    func incrementStatistics(
        profileId: String,
        ownerId: String,
        deltas: ProfileStatisticsDelta
    ) async throws

    /// Setzt die Kennzahlen auf einen festen Wert.
    ///
    /// Bewusst getrennt vom additiven Weg und nur für die
    /// Entwicklereinstellungen gedacht: Beim Korrigieren von Hand oder beim
    /// Zurücksetzen ist genau das Überschreiben gewollt, das im laufenden
    /// Betrieb vermieden werden soll.
    func overwriteStatistics(
        profileId: String,
        ownerId: String,
        statistics: UserStatistics
    ) async throws

    /// Entfernt ein Profil endgültig.
    func deleteProfile(profileId: String, ownerId: String) async throws
}

/// Die Veränderung, die ein abgeschlossenes Spiel an einem Profil bewirkt.
///
/// Eigener Typ statt eines Wörterbuchs, damit beim Aufruf nicht ein
/// Feldname vertippt werden kann, ohne dass es auffällt.
struct ProfileStatisticsDelta: Equatable {
    var gamesPlayed: Int = 0
    var gamesWon: Int = 0
    var totalThrows: Int = 0
    var totalHits: Int = 0
    var totalAirballs: Int = 0
    var totalBounceShotsMade: Int = 0
    var totalTrickshotsMade: Int = 0

    /// Serien sind Höchststände, keine Summen – sie werden nicht addiert,
    /// sondern nur angehoben, wenn der neue Wert größer ist.
    var longestOnFireStreakCandidate: Int = 0
    var didWin: Bool = false
}
