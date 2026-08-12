//
//  ThrowRepository.swift
//  BeerStats
//
//  Fachliche Schicht über dem Wurf-Log.
//
//  Zwei Aufgaben: Aktionen in Throw-Dokumente übersetzen (inklusive der
//  fachlichen Felder, aus denen später die Statistik aggregiert wird), und
//  aus einem Log wieder einen Spielstand machen.
//
//  Das Nachspielen ist der Kern der Geräte-Synchronisation: Der Server
//  rechnet nichts, er speichert nur die Reihenfolge. Weil die Engine eine
//  reine Funktion ist, kommt jedes Gerät aus demselben Log zwangsläufig auf
//  denselben Spielstand.
//

import Foundation

protocol ThrowRepositoryProtocol {
    func observeThrows(gameId: String) -> AsyncStream<[Throw]>

    func record(
        action: GameAction,
        by player: PlayerRef,
        before: LiveGameState,
        after: LiveGameState,
        gameId: String,
        teams: [Team]
    ) async throws

    func recordUndo(
        by player: PlayerRef,
        in state: LiveGameState,
        gameId: String,
        teams: [Team]
    ) async throws

    func replay(_ entries: [Throw], format: GameFormat, playersPerTeam: Int) -> LiveGameState

    /// Roher Wurf-Log einer Partie, unveraendert wie gespeichert.
    ///
    /// Die Auswertungen unten spielen den Log nach und geben Kennzahlen
    /// zurueck. Fuer eine Sicherung waere genau das falsch – dort zaehlt der
    /// unveraenderte Log, weil nur aus ihm der Rest wieder entsteht.
    func fetchThrows(gameId: String) async throws -> [Throw]

    /// Trefferverteilung über die Becher-Positionen eines Spielers.
    func cupHeatmap(
        games: [Game],
        profileId: String,
        limit: Int
    ) async throws -> CupHeatmap

    /// Trefferquote der letzten Partien, aelteste zuerst.
    func hitRateTrend(
        profileId: String,
        games: [Game],
        limit: Int
    ) async throws -> [TrendPoint]

    /// Rechnet die Kennzahlen eines Spielers aus einer Menge von Partien neu.
    ///
    /// Grundlage für den Zeitraum-Filter: Die Werte am Profil sind
    /// Lebenszeit-Summen und lassen sich nicht nachträglich zerlegen. Aus dem
    /// Wurf-Log dagegen ergibt sich jeder beliebige Zeitraum – und weil dabei
    /// nachgespielt statt roh gezählt wird, sind zurückgenommene Würfe
    /// automatisch heraus.
    func aggregateStatistics(
        profileId: String,
        games: [Game]
    ) async throws -> UserStatistics
}

/// Zeitraum, über den Statistiken betrachtet werden.
enum StatisticsPeriod: String, CaseIterable, Identifiable {
    case allTime
    case lastMonth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allTime: return "Gesamt"
        case .lastMonth: return "Letzter Monat"
        }
    }

    /// Grenzt eine Liste von Partien auf den Zeitraum ein.
    func filter(_ games: [Game]) -> [Game] {
        guard case .lastMonth = self else { return games }
        guard let cutoff = Calendar.current.date(byAdding: .month, value: -1, to: Date()) else {
            return games
        }
        // Partien ohne Endzeitpunkt fallen bewusst heraus: Sie stammen aus
        // einer Zeit vor dem Feld und lassen sich keinem Monat zuordnen.
        return games.filter { game in
            guard let endedAt = game.endedAt else { return false }
            return endedAt >= cutoff
        }
    }
}

/// Eine einzelne Partie im Verlauf.
///
/// Bewusst mit Sieg-Kennzeichen: Eine Trefferquote allein sagt wenig – erst
/// zusammen mit dem Ausgang sieht man, ob ein guter Abend auch einer war,
/// an dem man gewonnen hat.
struct TrendPoint: Equatable, Identifiable {
    let id: Int
    let endedAt: Date?
    let hits: Int
    let attempts: Int
    let won: Bool

    var hitRate: Double {
        attempts > 0 ? Double(hits) / Double(attempts) : 0
    }
}

/// Wie oft welche Becher-Position getroffen wurde.
///
/// Bewusst auf die Ausgangsaufstellung bezogen: Nach einem Umstellen
/// bedeutet derselbe Index eine andere Stelle auf dem Tisch, ein
/// spielübergreifender Vergleich wäre dann sinnlos. Würfe nach einem
/// Re-Rack bleiben deshalb außen vor – `ignoredAfterReRack` sagt, wie
/// viele das waren, damit die Zahl nicht stillschweigend fehlt.
struct CupHeatmap: Equatable {
    /// Treffer je Becher-Index der Startaufstellung.
    var hitsByCupIndex: [Int: Int] = [:]
    var cupCount: Int = 0
    var totalHits: Int = 0
    var consideredGames: Int = 0
    var ignoredAfterReRack: Int = 0

    var maximumHits: Int { hitsByCupIndex.values.max() ?? 0 }

    /// Anteil von 0 bis 1, bezogen auf den meistgetroffenen Becher.
    func intensity(forCup index: Int) -> Double {
        guard maximumHits > 0 else { return 0 }
        return Double(hitsByCupIndex[index] ?? 0) / Double(maximumHits)
    }
}

final class ThrowRepository: ThrowRepositoryProtocol {

    private let throwService: ThrowServiceProtocol

    init(throwService: ThrowServiceProtocol) {
        self.throwService = throwService
    }

    func observeThrows(gameId: String) -> AsyncStream<[Throw]> {
        throwService.observeThrows(gameId: gameId)
    }

    func fetchThrows(gameId: String) async throws -> [Throw] {
        try await throwService.fetchThrows(gameId: gameId)
    }

    // MARK: - Schreiben

    func record(
        action: GameAction,
        by player: PlayerRef,
        before: LiveGameState,
        after: LiveGameState,
        gameId: String,
        teams: [Team]
    ) async throws {
        guard action.isPersistable else { return }

        // Wichtig: Wurf-Typ und Bounce-Kennzeichen stammen aus dem Zustand
        // VOR der Aktion. Danach ist der Bounce-Schalter bereits
        // zurückgesetzt und `pending` beschreibt schon den nächsten Wurf –
        // beides wäre für diesen Eintrag falsch. Die laufenden Nummern
        // kommen dagegen aus dem Zustand danach, weil sie erst dort
        // hochgezählt wurden.
        let entry = Throw(
            playerId: playerId(for: player, teams: teams),
            teamId: teamId(at: player.teamIndex, teams: teams),
            targetTeamId: teamId(at: before.opponent(of: player.teamIndex), teams: teams),
            cupId: cupId(for: action),
            result: action.throwResult,
            throwType: throwType(for: before),
            sequenceNumber: after.sequenceNumber,
            roundNumber: after.roundNumber,
            isBounce: before.bounceArmed && isThrowAtCup(action),
            enablesTrickshot: action == .rebound,
            cupsRemoved: cupsRemoved(for: action),
            action: action
        )
        try await throwService.appendThrow(entry, gameId: gameId)
    }

    /// Eine Korrektur wird als eigener Eintrag angehängt, nicht durch
    /// Löschen – siehe Kommentar in ThrowServiceProtocol.
    func recordUndo(
        by player: PlayerRef,
        in state: LiveGameState,
        gameId: String,
        teams: [Team]
    ) async throws {
        let entry = Throw(
            playerId: playerId(for: player, teams: teams),
            teamId: teamId(at: player.teamIndex, teams: teams),
            targetTeamId: teamId(at: state.opponent(of: player.teamIndex), teams: teams),
            result: .undo,
            sequenceNumber: state.sequenceNumber + 1,
            roundNumber: state.roundNumber
        )
        try await throwService.appendThrow(entry, gameId: gameId)
    }

    // MARK: - Nachspielen

    /// Bringt die Einträge in eine eindeutige Reihenfolge.
    ///
    /// `sorted(by:)` ist in Swift **nicht stabil**: Bei gleicher laufender
    /// Nummer ist die Reihenfolge unbestimmt und kann sich zwischen zwei
    /// Durchläufen unterscheiden. Genau das ist passiert, solange Auswahl und
    /// Umstellen die Nummer nicht hochgezählt haben – eine `chooseCup` konnte
    /// vor der Aktion landen, die sie erzeugt hat, und ging verloren.
    ///
    /// Die Engine zählt inzwischen überall hoch. Für die Partien, die schon
    /// mit doppelten Nummern in Firestore liegen, entscheidet hier zusätzlich
    /// der Zeitstempel und zuletzt die gelieferte Reihenfolge.
    private func ordered(_ entries: [Throw]) -> [Throw] {
        entries.enumerated().sorted { left, right in
            if left.element.sequenceNumber != right.element.sequenceNumber {
                return left.element.sequenceNumber < right.element.sequenceNumber
            }
            if let leftDate = left.element.timestamp,
               let rightDate = right.element.timestamp,
               leftDate != rightDate {
                return leftDate < rightDate
            }
            return left.offset < right.offset
        }
        .map(\.element)
    }

    func replay(_ entries: [Throw], format: GameFormat, playersPerTeam: Int) -> LiveGameState {
        // Ein Eintrag kann mehr als eine Aktion bedeuten: Das Scharfschalten
        // des Aufsetzers ist reine Bedienung und steht deshalb nicht als
        // eigene Aktion im Log, sondern als Kennzeichen am Wurf. Wird es hier
        // nicht wieder vorangestellt, kommt ein Bounce Shot beim Nachspielen
        // als gewöhnlicher Treffer heraus – der zweite Becher und die ganze
        // Auswahl fallen weg, und ab da weicht der nachgespielte Stand
        // dauerhaft vom echten ab.
        //
        // Die Aktionen bleiben dabei je Eintrag gruppiert, damit ein Undo den
        // Wurf samt seinem Scharfschalten streicht. Andernfalls bliebe ein
        // aktiver Bounce für den nächsten Wurf zurück.
        var steps: [[GameAction]] = []
        for entry in ordered(entries) {
            if entry.result == .undo {
                if !steps.isEmpty { steps.removeLast() }
                continue
            }
            guard let action = entry.action else { continue }
            steps.append(entry.isBounce ? [.toggleBounce, action] : [action])
        }

        var state = GameEngine.makeInitialState(format: format, playersPerTeam: playersPerTeam)
        for step in steps {
            for action in step {
                state = GameEngine.apply(action, to: state, format: format).state
            }
        }
        return state
    }

    // MARK: - Heatmap

    func cupHeatmap(
        games: [Game],
        profileId: String,
        limit: Int
    ) async throws -> CupHeatmap {
        // Nur Partien mit derselben Becherzahl lassen sich sinnvoll
        // übereinanderlegen. Die häufigste Zahl gewinnt, damit ein einzelnes
        // Spiel im abweichenden Format den Rest nicht verwirft.
        let relevant = games.filter { $0.teams.contains { $0.playerIds.contains(profileId) } }
        let counts = Dictionary(grouping: relevant, by: { $0.format.cupCount })
        guard let (cupCount, sameFormat) = counts.max(by: { $0.value.count < $1.value.count }) else {
            return CupHeatmap()
        }

        var heatmap = CupHeatmap(cupCount: cupCount)

        for game in sameFormat.prefix(limit) {
            guard let gameId = game.id else { continue }
            let entries = try await throwService.fetchThrows(gameId: gameId)
            heatmap.consideredGames += 1
            accumulate(entries, of: profileId, into: &heatmap)
        }

        return heatmap
    }

    private func accumulate(_ entries: [Throw], of profileId: String, into heatmap: inout CupHeatmap) {
        var sawReRack = false

        for entry in ordered(entries) {
            if entry.result == .reRack {
                sawReRack = true
                continue
            }
            // Zusatzbecher aus Bounce, Trickshot oder Bombe wählt der Gegner
            // aus – geworfen hat auf sie niemand. Sie stehen im Log unter dem
            // Werfer und mit Ergebnis "hit", würden die Trefferkarte also an
            // Stellen einfärben, auf die nie jemand gezielt hat.
            if case .chooseCup = entry.action { continue }

            guard entry.playerId == profileId,
                  entry.result == .hit,
                  let cupId = entry.cupId,
                  let index = Int(cupId)
            else { continue }

            if sawReRack {
                heatmap.ignoredAfterReRack += 1
                continue
            }
            heatmap.hitsByCupIndex[index, default: 0] += 1
            heatmap.totalHits += 1
        }
    }

    // MARK: - Verlauf

    func hitRateTrend(
        profileId: String,
        games: [Game],
        limit: Int
    ) async throws -> [TrendPoint] {
        // Die JUENGSTEN `limit` Partien, aber aufsteigend dargestellt: Eine
        // Kurve, die rechts endet, liest man von links nach rechts.
        let relevant = games
            .filter { $0.teams.contains { $0.playerIds.contains(profileId) } }
            .sorted { ($0.endedAt ?? .distantPast) < ($1.endedAt ?? .distantPast) }
            .suffix(limit)

        var points: [TrendPoint] = []

        for game in relevant {
            guard let gameId = game.id,
                  let teamIndex = game.teams.firstIndex(where: { $0.playerIds.contains(profileId) }),
                  let slot = game.teams[teamIndex].playerIds.firstIndex(of: profileId)
            else { continue }

            let entries = try await throwService.fetchThrows(gameId: gameId)
            guard !entries.isEmpty else { continue }

            let finalState = replay(
                entries,
                format: game.format,
                playersPerTeam: game.type == .oneVsOne ? 1 : 2
            )
            guard finalState.stats.indices.contains(teamIndex),
                  finalState.stats[teamIndex].indices.contains(slot)
            else { continue }

            let playerStats = finalState.stats[teamIndex][slot]
            // Partien ohne einen einzigen Wurf ergaeben eine Quote von null
            // und wuerden die Kurve grundlos nach unten ziehen.
            guard playerStats.attempts > 0 else { continue }

            points.append(TrendPoint(
                id: points.count,
                endedAt: game.endedAt,
                hits: playerStats.hits,
                attempts: playerStats.attempts,
                won: game.winnerTeamId == game.teams[teamIndex].id
            ))
        }

        return points
    }

    // MARK: - Kennzahlen für einen Zeitraum

    func aggregateStatistics(
        profileId: String,
        games: [Game]
    ) async throws -> UserStatistics {
        var result = UserStatistics()
        // Siegesserien ergeben sich aus der zeitlichen Reihenfolge, deshalb
        // von der ältesten zur jüngsten Partie durchgehen.
        let ordered = games
            .filter { $0.teams.contains { $0.playerIds.contains(profileId) } }
            .sorted { ($0.endedAt ?? .distantPast) < ($1.endedAt ?? .distantPast) }

        for game in ordered {
            guard let gameId = game.id,
                  let teamIndex = game.teams.firstIndex(where: { $0.playerIds.contains(profileId) }),
                  let slot = game.teams[teamIndex].playerIds.firstIndex(of: profileId)
            else { continue }

            result.gamesPlayed += 1

            let didWin = game.winnerTeamId == game.teams[teamIndex].id
            if didWin {
                result.gamesWon += 1
                result.currentWinStreak += 1
                result.longestWinStreak = max(result.longestWinStreak, result.currentWinStreak)
            } else {
                result.currentWinStreak = 0
            }

            // Der Wurf-Log liefert die Detailwerte. Fehlt er – etwa weil die
            // Partie vor dieser Funktion entstand –, zählt sie trotzdem als
            // gespieltes Spiel, nur ohne Wurfdaten.
            let entries = try await throwService.fetchThrows(gameId: gameId)
            guard !entries.isEmpty else { continue }

            let finalState = replay(
                entries,
                format: game.format,
                playersPerTeam: game.type == .oneVsOne ? 1 : 2
            )
            guard finalState.stats.indices.contains(teamIndex),
                  finalState.stats[teamIndex].indices.contains(slot)
            else { continue }

            let playerStats = finalState.stats[teamIndex][slot]
            result.totalThrows += playerStats.attempts
            result.totalHits += playerStats.hits
            result.totalAirballs += playerStats.airballs
            result.totalBounceShotsMade += playerStats.bounces
            result.totalTrickshotsMade += playerStats.trickshots
            result.longestOnFireStreak = max(
                result.longestOnFireStreak,
                finalState.bestStreaks[teamIndex][slot]
            )
        }

        return result
    }

    // MARK: - Ableitungen für die fachlichen Felder

    private func playerId(for player: PlayerRef, teams: [Team]) -> String {
        guard teams.indices.contains(player.teamIndex) else { return "" }
        let ids = teams[player.teamIndex].playerIds
        guard ids.indices.contains(player.slot) else { return "" }
        return ids[player.slot]
    }

    private func teamId(at index: Int, teams: [Team]) -> String {
        teams.indices.contains(index) ? teams[index].id : ""
    }

    private func cupId(for action: GameAction) -> String? {
        switch action {
        case .hitCup(let index), .chooseCup(let index): return String(index)
        default: return nil
        }
    }

    private func isThrowAtCup(_ action: GameAction) -> Bool {
        if case .hitCup = action { return true }
        return false
    }

    private func throwType(for state: LiveGameState) -> ThrowType {
        switch state.pending {
        case .normal: return .normal
        case .onFireBonus: return .onFireBonus
        case .trickshot: return .trickshotAttempt
        }
    }

    /// Wie viele Becher dieser eine Eintrag vom Tisch nimmt.
    ///
    /// Bewusst nur der unmittelbare Abgang: Die zusätzlichen Becher bei
    /// Bounce, Trickshot und Bombe werden vom Gegner ausgewählt und landen
    /// als eigene `chooseCup`-Einträge im Log – so bleibt nachvollziehbar,
    /// welche Becher das waren. Die Bombe selbst nimmt gar keinen Becher:
    /// Der Treffer galt dem Becher, den der Teamkollege schon abgeräumt hat.
    private func cupsRemoved(for action: GameAction) -> Int {
        switch action {
        case .hitCup, .chooseCup: return 1
        default: return 0
        }
    }
}
