//
//  DataExportService.swift
//  BeerStats
//
//  Schreibt alles, was der Nutzer je erspielt hat, in eine Datei.
//
//  Der Grund ist unangenehm einfach: Profile, Kennzahlen und Wurf-Logs
//  haengen an genau einem Firebase-Konto. Geht das Passwort verloren oder
//  loescht jemand das Projekt, ist alles weg – es gibt keine zweite Kopie
//  und ohne Blaze-Tarif auch keinen serverseitigen Weg, eine anzulegen.
//  Diese Datei ist das einzige Netz, das die App hat.
//
//  Bewusst EIGENE Felder statt der Firestore-Modelle:
//
//  Erstens technisch – `@DocumentID` und `@ServerTimestamp` sind fuer
//  Firestores eigenen Codierer gebaut und lassen sich mit einem normalen
//  JSONEncoder nicht verlaesslich schreiben.
//
//  Zweitens und wichtiger: Eine Sicherung, die an den internen Modellen
//  klebt, wird von jeder Umbenennung entwertet. Ein Feld umbenannt, und die
//  Sicherung von letztem Jahr passt nicht mehr zu dem, was die App liest.
//  Die Struktur hier ist deshalb ein eigenes, stabiles Format mit einer
//  Versionsnummer – sie darf sich langsamer aendern als der Code darunter.
//
//  Was NICHT drin ist: laufende Partien. Gesichert wird, was abgeschlossen
//  ist. Ein Spiel, das gerade am Tisch laeuft, ist noch kein Ergebnis.
//

import Foundation

// MARK: - Format der Datei

/// Wurzel der Sicherungsdatei.
struct DataExportPayload: Encodable {
    /// Steigt, sobald sich die Struktur unvertraeglich aendert. Wer die Datei
    /// spaeter einliest, kann daran erkennen, ob er sie versteht.
    let formatVersion: Int
    let exportedAt: Date
    let profiles: [ExportedProfile]
    let games: [ExportedGame]
}

struct ExportedProfile: Encodable {
    let id: String
    let name: String
    let emoji: String
    let color: String
    let isActive: Bool
    let createdAt: Date?
    let statistics: ExportedStatistics
}

/// Lebenszeit-Summen, so wie sie am Profil stehen.
struct ExportedStatistics: Encodable {
    let gamesPlayed: Int
    let gamesWon: Int
    let totalThrows: Int
    let totalHits: Int
    let totalAirballs: Int
    let totalBounceShotsMade: Int
    let totalTrickshotsMade: Int
    let currentWinStreak: Int
    let longestWinStreak: Int
    let longestOnFireStreak: Int
    let eloRating: Int
}

struct ExportedGame: Encodable {
    let id: String
    let type: String
    let status: String
    let createdBy: String
    let createdAt: Date?
    let startedAt: Date?
    let endedAt: Date?
    let winnerTeamId: String?
    let teams: [ExportedTeam]
    let cupCount: Int
    /// Der vollstaendige Wurf-Log. Er ist die Wahrheit der Partie – aus ihm
    /// laesst sich jeder Zwischenstand wieder herstellen, die Kennzahlen
    /// oben sind daraus nur abgeleitet.
    let throwLog: [ExportedThrow]
}

struct ExportedTeam: Encodable {
    let id: String
    let playerIds: [String]
    let playerNames: [String]
    let score: Int
}

struct ExportedThrow: Encodable {
    let id: String
    let sequenceNumber: Int
    let roundNumber: Int
    let playerId: String
    let teamId: String
    let targetTeamId: String
    let cupId: String?
    let result: String
    let throwType: String
    let isBounce: Bool
    let cupsRemoved: Int
    let chosenCupIds: [String]?
    let timestamp: Date?
}

// MARK: - Ergebnis eines Laufs

struct DataExportSummary {
    let profileCount: Int
    let gameCount: Int
    let throwCount: Int
    let fileURL: URL
    let byteCount: Int

    /// Dateigroesse in einer Form, die man vorlesen kann.
    var readableSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }
}

// MARK: - Dienst

protocol DataExportServiceProtocol {
    func makeExport(ownerId: String) async throws -> DataExportSummary
}

struct DataExportService: DataExportServiceProtocol {

    let profileRepository: PlayerProfileRepositoryProtocol
    let gameRepository: GameRepositoryProtocol
    let throwRepository: ThrowRepositoryProtocol

    func makeExport(ownerId: String) async throws -> DataExportSummary {
        let profiles = try await profileRepository.fetchProfiles(ownerId: ownerId)
        let games = try await gameRepository.fetchFinishedGames(userId: ownerId)

        var exportedGames: [ExportedGame] = []
        var throwCount = 0

        // Bewusst nacheinander statt parallel: Jede Partie ist eine eigene
        // Abfrage, und ein Dutzend gleichzeitig loszuschicken bringt bei
        // dieser Datenmenge nichts ausser Spitzen im Kontingent.
        for game in games {
            guard let gameId = game.id else { continue }
            let entries = try await throwRepository.fetchThrows(gameId: gameId)
            throwCount += entries.count
            exportedGames.append(exported(game: game, id: gameId, entries: entries))
        }

        let payload = DataExportPayload(
            formatVersion: 1,
            exportedAt: Date(),
            profiles: profiles.map(exported(profile:)),
            games: exportedGames
        )

        let encoder = JSONEncoder()
        // Lesbar formatiert und mit sortierten Schluesseln: Eine Sicherung
        // soll man notfalls im Texteditor pruefen koennen, und zwei
        // Sicherungen soll man vergleichen koennen.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(payload)
        let url = try write(data)

        return DataExportSummary(
            profileCount: profiles.count,
            gameCount: exportedGames.count,
            throwCount: throwCount,
            fileURL: url,
            byteCount: data.count
        )
    }

    // MARK: - Umwandlung

    private func exported(profile: PlayerProfile) -> ExportedProfile {
        let stats = profile.statistics
        return ExportedProfile(
            id: profile.id ?? "",
            name: profile.name,
            emoji: profile.emoji,
            color: profile.color.rawValue,
            isActive: profile.isActive,
            createdAt: profile.createdAt,
            statistics: ExportedStatistics(
                gamesPlayed: stats.gamesPlayed,
                gamesWon: stats.gamesWon,
                totalThrows: stats.totalThrows,
                totalHits: stats.totalHits,
                totalAirballs: stats.totalAirballs,
                totalBounceShotsMade: stats.totalBounceShotsMade,
                totalTrickshotsMade: stats.totalTrickshotsMade,
                currentWinStreak: stats.currentWinStreak,
                longestWinStreak: stats.longestWinStreak,
                longestOnFireStreak: stats.longestOnFireStreak,
                eloRating: stats.eloRating
            )
        )
    }

    private func exported(game: Game, id: String, entries: [Throw]) -> ExportedGame {
        ExportedGame(
            id: id,
            type: game.type.rawValue,
            status: game.status.rawValue,
            createdBy: game.createdBy,
            createdAt: game.createdAt,
            startedAt: game.startedAt,
            endedAt: game.endedAt,
            winnerTeamId: game.winnerTeamId,
            teams: game.teams.map {
                ExportedTeam(
                    id: $0.id,
                    playerIds: $0.playerIds,
                    playerNames: $0.playerNames,
                    score: $0.score
                )
            },
            cupCount: game.format.cupCount,
            throwLog: entries.map(exported(entry:))
        )
    }

    private func exported(entry: Throw) -> ExportedThrow {
        ExportedThrow(
            id: entry.id ?? "",
            sequenceNumber: entry.sequenceNumber,
            roundNumber: entry.roundNumber,
            playerId: entry.playerId,
            teamId: entry.teamId,
            targetTeamId: entry.targetTeamId,
            cupId: entry.cupId,
            result: entry.result.rawValue,
            throwType: entry.throwType.rawValue,
            isBounce: entry.isBounce,
            cupsRemoved: entry.cupsRemoved,
            chosenCupIds: entry.chosenCupIds,
            timestamp: entry.timestamp
        )
    }

    // MARK: - Datei

    /// Legt die Datei mit dem Tagesdatum im Namen ab. Der Name wandert mit in
    /// die Teilen-Ansicht, und dort ist "beerstats-2026-08-12.json" die
    /// einzige Stelle, an der spaeter noch steht, wann die Sicherung entstand.
    private func write(_ data: Data) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let name = "beerstats-\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)

        try data.write(to: url, options: .atomic)
        return url
    }
}
