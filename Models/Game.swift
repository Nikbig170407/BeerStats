//
//  Game.swift
//  BeerStats
//
//  Zentrales Datenmodell für ein Spiel. Enthält bewusst mehrere
//  denormalisierte Felder (cupsRemaining, currentTurnTeamId,
//  playerStreaks), die von einer Cloud Function bei jedem neuen Throw-
//  Dokument inkrementell aktualisiert werden – die Views lesen so den
//  Live-Zustand direkt aus dem Game-Dokument, ohne bei jeder Änderung den
//  kompletten throws-Log neu auswerten zu müssen (siehe Architektur-
//  Dokument, Abschnitt Performance/Statistiken).
//

import Foundation
import FirebaseFirestore

enum GameType: String, Codable, CaseIterable {
    case oneVsOne
    case twoVsTwo
}

enum GameStatus: String, Codable {
    case lobby
    case active
    case paused
    case finished
    case cancelled
}

struct Game: Codable, Identifiable, Equatable {

    @DocumentID var id: String?

    var type: GameType
    var status: GameStatus
    var createdBy: String
    var teams: [Team]
    var format: GameFormat

    /// Verbleibende Becher pro Team-ID – denormalisiert für eine performante
    /// Live-Anzeige ohne den throws-Log auszählen zu müssen.
    var cupsRemaining: [String: Int]

    /// Alle Konten, die dieses Spiel sehen und bearbeiten dürfen. Firestore
    /// kann mit `array-contains` nicht in verschachtelte Objekt-Arrays
    /// (teams) hineinsehen – dieses Feld ist der Grund, warum Security Rules
    /// und Queries wie "alle aktiven Spiele eines Nutzers" überhaupt
    /// effizient möglich sind (siehe firestore.rules und
    /// firestore.indexes.json).
    ///
    /// Wichtig: Das sind **Konto-IDs**, nicht zwingend die Spieler des
    /// Spiels. Seit der Umstellung auf Mitspieler-Profile enthalten
    /// `Team.playerIds` Profil-IDs von Leuten ohne eigenes Konto – die
    /// dürfen hier nicht auftauchen, sonst greift die Zugriffsregel ins
    /// Leere.
    var allPlayerIds: [String]

    /// Laufender Trefferserien-Zähler pro Spieler-ID für die On-Fire-Regel.
    /// Wird bei jedem `miss` dieses Spielers von der Cloud Function auf 0
    /// zurückgesetzt.
    var playerStreaks: [String: Int]

    var currentTurnTeamId: String?

    @ServerTimestamp var createdAt: Date?
    var startedAt: Date?
    var endedAt: Date?
    var winnerTeamId: String?

    /// Für die spätere Zuschauer-/Liga-Funktion vorgesehen (siehe Roadmap-
    /// Erweiterungen), aktuell ohne Auswirkung auf die UI.
    var isPublic: Bool = false

    init(
        id: String? = nil,
        type: GameType,
        status: GameStatus = .lobby,
        createdBy: String,
        teams: [Team],
        format: GameFormat = GameFormat(),
        currentTurnTeamId: String? = nil,
        isPublic: Bool = false,
        accessUserIds: [String]? = nil
    ) {
        self.id = id
        self.type = type
        self.status = status
        self.createdBy = createdBy
        self.teams = teams
        self.format = format
        self.cupsRemaining = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, format.cupCount) })
        // Standardmäßig sind die Spieler auch die Zugriffsberechtigten – das
        // gilt, solange alle Beteiligten ein eigenes Konto haben. Bei
        // Profil-Spielen übergibt der Aufrufer stattdessen die Konten.
        self.allPlayerIds = accessUserIds ?? teams.flatMap(\.playerIds)
        self.playerStreaks = Dictionary(uniqueKeysWithValues: teams.flatMap(\.playerIds).map { ($0, 0) })
        self.currentTurnTeamId = currentTurnTeamId
        self.isPublic = isPublic
    }
}

/// Das komplette, konfigurierbare Regelwerk eines Spiels. Als eigenes,
/// eingebettetes Objekt statt hartkodierter Konstanten – neue Spielvarianten
/// lassen sich später hinzufügen, ohne das Game-Modell selbst zu ändern
/// (siehe Architektur-Dokument, Vorschlag "Regelwerk als Konfigurationsobjekt").
struct GameFormat: Codable, Equatable {
    var cupCount: Int = AppConstants.GameDefaults.standardCupCount
    var reRacksAllowed: Bool = true
    var redemptionAllowed: Bool = true
    var bounceShotsAllowed: Bool = true
    var trickshotsAllowed: Bool = true
    var onFireEnabled: Bool = true
    var onFireStreakThreshold: Int = AppConstants.GameDefaults.onFireStreakThreshold
    var airballPenaltyEnabled: Bool = true
}
