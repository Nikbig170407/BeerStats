//
//  PlayerProfileRepository.swift
//  BeerStats
//
//  Fachliche Schicht über den Spieler-Profilen: Validierung beim Anlegen
//  und Umbenennen, sowie die Übersetzung eines beendeten Spiels in die
//  Kennzahlen-Änderungen der beteiligten Profile.
//

import Foundation

protocol PlayerProfileRepositoryProtocol {
    func observeProfiles(ownerId: String) -> AsyncStream<[PlayerProfile]>
    func fetchProfiles(ownerId: String) async throws -> [PlayerProfile]

    @discardableResult
    func createProfile(name: String, emoji: String, color: ProfileColor, ownerId: String) async throws -> String

    func updateProfile(
        _ profile: PlayerProfile,
        name: String,
        emoji: String,
        color: ProfileColor,
        isActive: Bool,
        ownerId: String
    ) async throws

    /// Schreibt das Ergebnis eines beendeten Spiels auf alle beteiligten
    /// Profile fort.
    func applyFinishedGame(
        state: LiveGameState,
        profileIdsByTeam: [[String]],
        ownerId: String
    ) async throws

    // MARK: - Nur für die Entwicklereinstellungen

    func overwriteStatistics(profileId: String, statistics: UserStatistics, ownerId: String) async throws
    /// Setzt die Kennzahlen aller Profile auf null. Namen, Emoji und Farbe
    /// bleiben erhalten.
    func resetAllStatistics(ownerId: String) async throws
    func deleteProfile(profileId: String, ownerId: String) async throws
}

final class PlayerProfileRepository: PlayerProfileRepositoryProtocol {

    private let profileService: PlayerProfileServiceProtocol

    init(profileService: PlayerProfileServiceProtocol) {
        self.profileService = profileService
    }

    func observeProfiles(ownerId: String) -> AsyncStream<[PlayerProfile]> {
        profileService.observeProfiles(ownerId: ownerId)
    }

    func fetchProfiles(ownerId: String) async throws -> [PlayerProfile] {
        try await profileService.fetchProfiles(ownerId: ownerId)
    }

    // MARK: - Stammdaten

    @discardableResult
    func createProfile(
        name: String,
        emoji: String,
        color: ProfileColor,
        ownerId: String
    ) async throws -> String {
        let cleanName = try validated(name)
        let profile = PlayerProfile(name: cleanName, emoji: emoji, color: color)
        return try await profileService.createProfile(profile, ownerId: ownerId)
    }

    func updateProfile(
        _ profile: PlayerProfile,
        name: String,
        emoji: String,
        color: ProfileColor,
        isActive: Bool,
        ownerId: String
    ) async throws {
        guard let profileId = profile.id else {
            throw AppError.validation("Profil ohne Kennung kann nicht geändert werden.")
        }
        let cleanName = try validated(name)
        try await profileService.updateProfileDetails(
            profileId: profileId,
            ownerId: ownerId,
            name: cleanName,
            emoji: emoji,
            color: color,
            isActive: isActive
        )
    }

    private func validated(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AppError.validation("Der Name darf nicht leer sein.")
        }
        guard trimmed.count <= AppConstants.Validation.profileNameMaxLength else {
            throw AppError.validation(
                "Der Name darf höchstens \(AppConstants.Validation.profileNameMaxLength) Zeichen haben."
            )
        }
        return trimmed
    }

    // MARK: - Spielende auswerten

    /// `profileIdsByTeam[teamIndex][slot]` muss zur Aufstellung im
    /// Spielzustand passen – sonst landen die Zahlen beim falschen Spieler.
    func applyFinishedGame(
        state: LiveGameState,
        profileIdsByTeam: [[String]],
        ownerId: String
    ) async throws {
        guard state.isFinished else {
            throw AppError.validation("Nur beendete Spiele können ausgewertet werden.")
        }

        for teamIndex in profileIdsByTeam.indices {
            for slot in profileIdsByTeam[teamIndex].indices {
                let profileId = profileIdsByTeam[teamIndex][slot]
                guard !profileId.isEmpty else { continue }
                guard state.stats.indices.contains(teamIndex),
                      state.stats[teamIndex].indices.contains(slot) else { continue }

                let playerStats = state.stats[teamIndex][slot]
                let didWin = state.winnerTeamIndex == teamIndex

                let deltas = ProfileStatisticsDelta(
                    gamesPlayed: 1,
                    gamesWon: didWin ? 1 : 0,
                    totalThrows: playerStats.attempts,
                    totalHits: playerStats.hits,
                    totalAirballs: playerStats.airballs,
                    totalBounceShotsMade: playerStats.bounces,
                    totalTrickshotsMade: playerStats.trickshots,
                    longestOnFireStreakCandidate: state.bestStreaks[teamIndex][slot],
                    didWin: didWin
                )

                try await profileService.incrementStatistics(
                    profileId: profileId,
                    ownerId: ownerId,
                    deltas: deltas
                )
            }
        }
    }

    // MARK: - Entwicklereinstellungen

    func overwriteStatistics(profileId: String, statistics: UserStatistics, ownerId: String) async throws {
        try await profileService.overwriteStatistics(
            profileId: profileId,
            ownerId: ownerId,
            statistics: statistics
        )
    }

    func resetAllStatistics(ownerId: String) async throws {
        let profiles = try await profileService.fetchProfiles(ownerId: ownerId)
        for profile in profiles {
            guard let profileId = profile.id else { continue }
            try await profileService.overwriteStatistics(
                profileId: profileId,
                ownerId: ownerId,
                statistics: UserStatistics()
            )
        }
    }

    func deleteProfile(profileId: String, ownerId: String) async throws {
        try await profileService.deleteProfile(profileId: profileId, ownerId: ownerId)
    }
}
