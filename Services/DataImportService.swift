//
//  DataImportService.swift
//  BeerStats
//
//  Liest eine Sicherungsdatei zurueck.
//
//  Damit ist die Sicherung erst eine. Vorher gab es einen Weg hinaus und
//  keinen zurueck – eine Datei, die man im Ernstfall zwar hat, aber nicht
//  benutzen kann.
//
//  Der Kern des Problems sind die Kennungen. Firestore vergibt beim Anlegen
//  neue, die alten aus der Datei gibt es nicht mehr. Ein Profil heisst nach
//  dem Wiederherstellen also anders als vorher – und jeder Wurf, jede
//  Aufstellung zeigt noch auf den alten Namen. Deshalb entsteht beim
//  Anlegen eine Uebersetzungstabelle alt -> neu, durch die alles Weitere
//  hindurchgereicht wird. Wer sie vergisst, bekommt Partien ohne Spieler.
//
//  Team-Kennungen bleiben dagegen unveraendert: Sie sind keine
//  Firestore-Dokumente, sondern Werte im Spiel-Dokument. Der Wurf-Log
//  verweist auf sie, und sie kommen unveraendert wieder mit.
//
//  Zwei Umfaenge, und das ist keine Bequemlichkeit. Ein vollstaendiger
//  Wiederherstellungslauf schreibt ein Dokument pro Wurf; eine Sicherung mit
//  fuenfzig Partien sind schnell tausend Schreibzugriffe. Im Spark-Tarif
//  sind zwanzigtausend am Tag frei. Wer nur seine Leute und deren Werte
//  zurueck will, soll dafuer nicht sein Kontingent verbrennen.
//

import Foundation

// MARK: - Was drinsteht

/// Was eine Datei enthaelt, bevor irgendetwas geschrieben wird.
struct DataImportPreview {
    let formatVersion: Int
    let exportedAt: Date
    let profileCount: Int
    let gameCount: Int
    let throwCount: Int

    /// Sicherungen der ersten Fassung tragen keine Wurf-Aktionen. Ihre
    /// Partien lassen sich anlegen, aber nicht mehr nachspielen – Heatmap,
    /// Verlaufskurve und Zeitraum-Statistiken bleiben leer. Das muss vorher
    /// dastehen, nicht hinterher auffallen.
    var canRestoreThrowLog: Bool { formatVersion >= 2 }
}

struct DataImportSummary {
    let profiles: Int
    let games: Int
    let throwEntries: Int
}

// MARK: - Dienst

protocol DataImportServiceProtocol {
    func preview(_ data: Data) throws -> DataImportPreview
    func restore(
        _ data: Data,
        ownerId: String,
        includeGames: Bool,
        progress: @MainActor (String) -> Void
    ) async throws -> DataImportSummary
}

struct DataImportService: DataImportServiceProtocol {

    let profileRepository: PlayerProfileRepositoryProtocol
    let gameRepository: GameRepositoryProtocol
    let throwRepository: ThrowRepositoryProtocol

    // MARK: Lesen

    private func decode(_ data: Data) throws -> DataExportPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DataExportPayload.self, from: data)
    }

    func preview(_ data: Data) throws -> DataImportPreview {
        let payload = try decode(data)
        return DataImportPreview(
            formatVersion: payload.formatVersion,
            exportedAt: payload.exportedAt,
            profileCount: payload.profiles.count,
            gameCount: payload.games.count,
            throwCount: payload.games.reduce(0) { $0 + $1.throwLog.count }
        )
    }

    // MARK: Schreiben

    func restore(
        _ data: Data,
        ownerId: String,
        includeGames: Bool,
        progress: @MainActor (String) -> Void
    ) async throws -> DataImportSummary {

        let payload = try decode(data)

        // Alte Kennung -> neue Kennung. Ohne diese Tabelle zeigen Wuerfe und
        // Aufstellungen ins Leere.
        var profileIds: [String: String] = [:]
        var wiederhergestellteProfile = 0

        for profil in payload.profiles {
            await progress("Profil \(profil.name)")

            let neueId = try await profileRepository.createProfile(
                name: profil.name,
                emoji: profil.emoji,
                color: ProfileColor(rawValue: profil.color) ?? .amber,
                ownerId: ownerId
            )
            profileIds[profil.id] = neueId

            // Die Kennzahlen direkt setzen statt sie aus den Partien neu
            // hochzurechnen. Sie stehen in der Datei, sind Lebenszeit-Summen
            // und enthalten auch das, was vor der aeltesten gesicherten
            // Partie liegt – nachrechnen wuerde genau das verlieren.
            try await profileRepository.overwriteStatistics(
                profileId: neueId,
                statistics: statistics(from: profil.statistics),
                ownerId: ownerId
            )

            if !profil.isActive {
                // Ausgemusterte bleiben ausgemustert, sonst stehen sie nach
                // dem Wiederherstellen wieder in jeder Aufstellung.
                if let angelegt = try? await profileRepository.fetchProfiles(ownerId: ownerId)
                    .first(where: { $0.id == neueId }) {
                    try await profileRepository.updateProfile(
                        angelegt,
                        name: profil.name,
                        emoji: profil.emoji,
                        color: ProfileColor(rawValue: profil.color) ?? .amber,
                        isActive: false,
                        ownerId: ownerId
                    )
                }
            }

            wiederhergestellteProfile += 1
        }

        guard includeGames else {
            return DataImportSummary(profiles: wiederhergestellteProfile, games: 0, throwEntries: 0)
        }

        var wiederhergestellteSpiele = 0
        var wiederhergestellteWuerfe = 0

        for (nummer, spiel) in payload.games.enumerated() {
            await progress("Partie \(nummer + 1) von \(payload.games.count)")

            let teams = spiel.teams.map { team in
                Team(
                    id: team.id,
                    // Durch die Uebersetzungstabelle: Ein Profil, das nicht
                    // mitgesichert wurde, faellt hier heraus statt auf eine
                    // Kennung zu zeigen, die es nicht gibt.
                    playerIds: team.playerIds.compactMap { profileIds[$0] },
                    playerNames: team.playerNames,
                    score: team.score,
                    ballsInPlay: team.playerIds.count
                )
            }

            let neueSpielId = try await gameRepository.createGame(
                type: GameType(rawValue: spiel.type) ?? .twoVsTwo,
                teams: teams,
                // Mitsamt der Sonderregeln, sonst spielt die Engine den Log
                // spaeter unter anderen Regeln nach als denen, unter denen er
                // entstanden ist.
                format: spiel.gameFormat,
                createdBy: ownerId,
                accessUserIds: [ownerId]
            )

            for eintrag in spiel.throwLog {
                guard let action = eintrag.action else { continue }
                try await throwRepository.append(
                    Throw(
                        playerId: profileIds[eintrag.playerId] ?? eintrag.playerId,
                        teamId: eintrag.teamId,
                        targetTeamId: eintrag.targetTeamId,
                        cupId: eintrag.cupId,
                        result: ThrowResult(rawValue: eintrag.result) ?? .miss,
                        throwType: ThrowType(rawValue: eintrag.throwType) ?? .normal,
                        sequenceNumber: eintrag.sequenceNumber,
                        roundNumber: eintrag.roundNumber,
                        isBounce: eintrag.isBounce,
                        cupsRemoved: eintrag.cupsRemoved,
                        chosenCupIds: eintrag.chosenCupIds,
                        action: action
                    ),
                    gameId: neueSpielId
                )
                wiederhergestellteWuerfe += 1
            }

            // Zum Schluss abschliessen, damit die Partie im Spielverlauf
            // auftaucht und nicht als offene Runde zum Fortsetzen angeboten
            // wird.
            try await gameRepository.finishGame(
                gameId: neueSpielId,
                winnerTeamId: spiel.winnerTeamId
            )
            wiederhergestellteSpiele += 1
        }

        return DataImportSummary(
            profiles: wiederhergestellteProfile,
            games: wiederhergestellteSpiele,
            throwEntries: wiederhergestellteWuerfe
        )
    }

    private func statistics(from exported: ExportedStatistics) -> UserStatistics {
        var werte = UserStatistics()
        werte.gamesPlayed = exported.gamesPlayed
        werte.gamesWon = exported.gamesWon
        werte.totalThrows = exported.totalThrows
        werte.totalHits = exported.totalHits
        werte.totalAirballs = exported.totalAirballs
        werte.totalBounceShotsMade = exported.totalBounceShotsMade
        werte.totalTrickshotsMade = exported.totalTrickshotsMade
        werte.currentWinStreak = exported.currentWinStreak
        werte.longestWinStreak = exported.longestWinStreak
        werte.longestOnFireStreak = exported.longestOnFireStreak
        werte.eloRating = exported.eloRating
        return werte
    }
}
