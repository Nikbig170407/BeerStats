//
//  LiveGameState.swift
//  BeerStats
//
//  Der vollständige Zustand eines laufenden Spiels als reiner Wert-Typ,
//  ohne jede Firebase- oder UI-Abhängigkeit.
//
//  Warum als Struct und nicht als ObservableObject: Dadurch lässt sich der
//  Zustand kostenlos kopieren. Das macht zwei Dinge trivial, die sonst
//  fehleranfällig wären – die Undo-Funktion (einfach der vorherige Wert)
//  und Unit-Tests des Regelwerks (Zustand rein, Zustand raus, kein Mocking).
//

import Foundation

/// Verweist auf einen konkreten Spieler: Team-Index (0 oder 1) und Position
/// innerhalb des Teams.
struct PlayerRef: Equatable, Hashable {
    var teamIndex: Int
    var slot: Int
}

/// Zählwerte pro Spieler für die Live-Statistik im Spielscreen.
/// (`attempts` statt `throws`, weil `throws` in Swift ein Schlüsselwort ist.)
struct PlayerStats: Equatable {
    var hits: Int = 0
    var attempts: Int = 0
    var airballs: Int = 0
    var bounces: Int = 0
    var trickshots: Int = 0

    var accuracy: Double? {
        guard attempts > 0 else { return nil }
        return Double(hits) / Double(attempts)
    }
}

struct LiveGameState: Equatable {

    enum Phase: Equatable {
        case playing
        /// Ein Rack ist leer, das unterlegene Team wirft nach.
        case redemption
        case finished
    }

    /// Woher der nächste Wurf kommt – bestimmt, ob die Airball-Strafe greift
    /// und ob der Wurf für Balls Back / Bombe zählt.
    enum PendingThrow: Equatable {
        case normal
        /// Der Spieler ist on Fire und behält den Ball.
        case onFireBonus
        /// Bonuswurf nach gefangenem Rebound.
        case trickshot
    }

    /// Eine erzwungene Becher-Auswahl durch das betroffene Team (Bounce,
    /// Trickshot, Bombe). Die Fortsetzung ist bewusst als Datum abgelegt und
    /// nicht als Closure – nur so bleibt der Zustand ein kopierbarer Wert und
    /// damit Undo-fähig.
    struct PendingChoice: Equatable {
        enum Continuation: Equatable {
            case afterHit(thrower: PlayerRef, wasTrickshot: Bool)
            case afterBombe(teamIndex: Int)
        }

        /// Aus welchem Rack gewählt wird (Team-Index des Rack-Eigentümers).
        var rackTeamIndex: Int
        var remaining: Int
        /// Wer auswählen darf – das Team, das die Becher trinken muss.
        var choosingTeamIndex: Int
        var continuation: Continuation
    }

    // MARK: - Aufstellung

    /// `racks[i]` sind die eigenen Becher von Team i. Team i wirft immer auf
    /// `racks[1 - i]`.
    var racks: [RackLayout]

    var playersPerTeam: Int

    /// Bälle, die ein Team pro Zug wirft – unabhängig davon, wie viele
    /// Spieler es hat.
    ///
    /// Bewusst von `playersPerTeam` getrennt: Auch im 1 gegen 1 wirft jeder
    /// zwei Bälle, sonst gäbe es dort weder Balls Back noch Bombe. Wer den
    /// jeweiligen Ball wirft, bestimmt `playerSlot(forBall:)`.
    var ballsPerTurn: Int = 2

    // MARK: - Zug

    var turnTeamIndex: Int = 0
    /// Der wievielte Ball des laufenden Zuges geworfen wird (0-basiert).
    var currentBallIndex: Int = 0
    var pending: PendingThrow = .normal
    var bounceArmed: Bool = false

    // MARK: - Verlauf

    var phase: Phase = .playing
    /// Nur gesetzt, wenn `phase == .finished`. `nil` bedeutet unentschieden.
    var winnerTeamIndex: Int?

    var streaks: [[Int]]
    var bestStreaks: [[Int]]
    var onFire: [[Bool]]
    var stats: [[PlayerStats]]

    /// Treffer der regulären Bälle im laufenden Zug, je Ball – nicht je
    /// Spieler. Im 1 gegen 1 stehen hier also beide Würfe derselben Person.
    /// `nil` = noch nicht geworfen.
    var roundHits: [[Bool?]]
    /// Zweiter Werfer hat denselben Becher getroffen wie sein Teamkollege.
    var doubleHitSameCup: Bool = false

    var reRackUsed: [Bool]

    /// Becher, den der erste Werfer im laufenden Zug getroffen hat – die View
    /// markiert ihn, damit der zweite Werfer die Bombe beurteilen kann.
    var lastHitCupIndex: Int?

    var pendingChoice: PendingChoice?

    /// Fortlaufende Nummern für den späteren Append-Only-Log in Firestore.
    var roundNumber: Int = 1
    var sequenceNumber: Int = 0

    // MARK: - Abgeleitete Werte

    /// Wer den angegebenen Ball wirft. Bei zwei Spielern wirft jeder einen,
    /// bei einem Spieler wirft dieselbe Person beide.
    func playerSlot(forBall ballIndex: Int) -> Int {
        guard playersPerTeam > 1 else { return 0 }
        return min(ballIndex, playersPerTeam - 1)
    }

    var currentThrower: PlayerRef {
        PlayerRef(teamIndex: turnTeamIndex, slot: playerSlot(forBall: currentBallIndex))
    }

    /// Rack, auf das gerade geworfen wird.
    var targetRackIndex: Int { 1 - turnTeamIndex }

    var isFinished: Bool { phase == .finished }

    var isDraw: Bool { phase == .finished && winnerTeamIndex == nil }

    /// Balls Back und Bombe brauchen zwei Bälle pro Zug – die gibt es in
    /// beiden Modi, also gelten die Regeln überall.
    var supportsDoubleHitRules: Bool { ballsPerTurn > 1 }

    func opponent(of teamIndex: Int) -> Int { 1 - teamIndex }

    func playerStats(for player: PlayerRef) -> PlayerStats {
        stats[player.teamIndex][player.slot]
    }

    func teamStats(_ teamIndex: Int) -> PlayerStats {
        stats[teamIndex].reduce(into: PlayerStats()) { total, player in
            total.hits += player.hits
            total.attempts += player.attempts
            total.airballs += player.airballs
            total.bounces += player.bounces
            total.trickshots += player.trickshots
        }
    }

    /// Becher, die dieses Team dem Gegner bereits abgeräumt hat.
    func cupsKnockedDown(by teamIndex: Int) -> Int {
        let rack = racks[opponent(of: teamIndex)]
        return rack.totalSlots - rack.remainingCount
    }

    // MARK: - Aufbau

    init(cupCount: Int, playersPerTeam: Int, ballsPerTurn: Int = 2, handicap: [Int] = []) {
        // Ein Vorsprung nimmt Becher aus dem fertigen Rack, statt ein
        // kleineres aufzubauen. Das ist nicht nur naeher am echten Tisch – ein
        // Dreieck aus neun Bechern gibt es dort auch nicht –, es sieht auch
        // richtig aus: `triangleRows` wuerde aus neun ein [6,2,1] machen, also
        // einen Klotz statt einer Pyramide mit Luecke.
        self.racks = (0..<2).map { team in
            var rack = RackLayout(cupCount: cupCount)
            let fehlend = handicap.indices.contains(team)
                ? max(0, min(handicap[team], cupCount - 1))
                : 0
            // Von der Spitze her, also von hinten: Dort faellt eine Luecke am
            // wenigsten auf, und die breite Grundreihe bleibt erhalten.
            for schritt in 0..<fehlend {
                _ = rack.removeCup(at: rack.totalSlots - 1 - schritt)
            }
            return rack
        }
        self.playersPerTeam = playersPerTeam
        self.ballsPerTurn = ballsPerTurn
        // Serien und Zählwerte hängen am Spieler …
        self.streaks = Array(repeating: Array(repeating: 0, count: playersPerTeam), count: 2)
        self.bestStreaks = Array(repeating: Array(repeating: 0, count: playersPerTeam), count: 2)
        self.onFire = Array(repeating: Array(repeating: false, count: playersPerTeam), count: 2)
        self.stats = Array(repeating: Array(repeating: PlayerStats(), count: playersPerTeam), count: 2)
        // … die Treffer des laufenden Zuges dagegen am Ball.
        self.roundHits = Array(repeating: Array(repeating: nil, count: ballsPerTurn), count: 2)
        self.reRackUsed = [false, false]
    }
}
