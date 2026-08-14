//
//  GameEngine.swift
//  BeerStats
//
//  Das komplette Beerpong-Regelwerk als reine Funktion: Zustand + Aktion
//  ergibt neuen Zustand + eine Liste von Ereignissen.
//
//  Warum ein Reducer statt Logik im ViewModel: Das Regelwerk ist der
//  fachlich anspruchsvollste Teil der App (On Fire, Bombe, Bounce,
//  Trickshot, Redemption greifen ineinander). Hier liegt es an genau einer
//  Stelle, ohne UI und ohne Netzwerk – dadurch ist es vollständig
//  unit-testbar und verhält sich auf allen Geräten garantiert gleich.
//
//  Die zurückgegebenen `GameEvent`s sind der Aufhänger für alles, was
//  *zusätzlich* passieren soll: Animationen, Haptik und später je ein
//  Throw-Dokument im Append-Only-Log (siehe Throw.swift).
//

import Foundation

/// Was durch eine Aktion tatsächlich passiert ist – Grundlage für
/// Animationen, Haptik und den Ereignis-Log.
enum GameEvent: Equatable {
    case hit(thrower: PlayerRef, bounce: Bool, trickshot: Bool, cupIndex: Int)
    case missed(thrower: PlayerRef)
    case airball(thrower: PlayerRef, penalised: Bool)
    case rebound(thrower: PlayerRef)
    case caughtFire(player: PlayerRef)
    case ballsBack(teamIndex: Int)
    case bombe(choosingTeamIndex: Int)
    case cupChosen(byTeamIndex: Int, cupIndex: Int)
    case reRacked(teamIndex: Int, formation: RackFormation)
    case redemptionStarted(teamIndex: Int)
    case finished(winnerTeamIndex: Int?)
}

enum GameEngine {

    // MARK: - Öffentliche Schnittstelle

    static func makeInitialState(format: GameFormat, playersPerTeam: Int) -> LiveGameState {
        LiveGameState(
            cupCount: format.cupCount,
            playersPerTeam: playersPerTeam,
            handicap: [format.startingHandicap(for: 0), format.startingHandicap(for: 1)]
        )
    }

    /// Wendet eine Aktion an. Ist die Aktion im aktuellen Zustand nicht
    /// erlaubt, bleibt der Zustand unverändert und es entstehen keine
    /// Ereignisse – der Aufrufer muss also nicht jeden Sonderfall selbst
    /// prüfen.
    static func apply(
        _ action: GameAction,
        to state: LiveGameState,
        format: GameFormat
    ) -> (state: LiveGameState, events: [GameEvent]) {

        var newState = state
        var events: [GameEvent] = []

        switch action {
        case .hitCup(let index):
            registerHit(cupIndex: index, state: &newState, events: &events, format: format)
        case .miss:
            registerMiss(kind: .miss, state: &newState, events: &events, format: format)
        case .airball:
            registerMiss(kind: .airball, state: &newState, events: &events, format: format)
        case .rebound:
            registerMiss(kind: .rebound, state: &newState, events: &events, format: format)
        case .bombe:
            registerBombe(state: &newState, events: &events, format: format)
        case .toggleBounce:
            toggleBounce(state: &newState, format: format)
        case .chooseCup(let index):
            resolveChoice(cupIndex: index, state: &newState, events: &events, format: format)
        case .reRack(let formation):
            applyReRack(formation, state: &newState, events: &events, format: format)
        }

        return (newState, events)
    }

    // MARK: - Erlaubnis-Abfragen (die View spiegelt damit ihre Buttons)

    static func canThrow(in state: LiveGameState) -> Bool {
        state.phase != .finished && state.pendingChoice == nil
    }

    /// Ein Rebound aus einem laufenden Trickshot heraus wird bewusst nicht
    /// verkettet – sonst könnte ein Spieler endlos Bonuswürfe erzeugen.
    static func canRebound(in state: LiveGameState, format: GameFormat) -> Bool {
        canThrow(in: state) && format.trickshotsAllowed && state.pending != .trickshot
    }

    /// Ein Trickshot zählt bereits doppelt; ein zusätzlicher Bounce darauf
    /// ist im Regelwerk nicht definiert und daher gesperrt.
    static func canArmBounce(in state: LiveGameState, format: GameFormat) -> Bool {
        canThrow(in: state) && format.bounceShotsAllowed && state.pending != .trickshot
    }

    /// Die Bombe steht nur dem zweiten Werfer offen, und nur wenn sein
    /// Teamkollege im selben Zug regulär getroffen hat.
    static func canDeclareBombe(in state: LiveGameState) -> Bool {
        guard canThrow(in: state), state.supportsDoubleHitRules else { return false }
        guard state.pending == .normal, state.currentBallIndex == 1 else { return false }
        return state.roundHits[state.turnTeamIndex][0] == true
    }

    static func canReRack(in state: LiveGameState, format: GameFormat) -> Bool {
        guard canThrow(in: state), format.reRacksAllowed else { return false }
        guard state.pending == .normal else { return false }
        guard !state.reRackUsed[state.turnTeamIndex] else { return false }
        return !availableFormations(in: state).isEmpty
    }

    static func availableFormations(in state: LiveGameState) -> [RackFormation] {
        RackFormationCatalog.applicableFormations(for: state.racks[state.targetRackIndex])
    }

    // MARK: - Treffer

    private static func registerHit(
        cupIndex: Int,
        state: inout LiveGameState,
        events: inout [GameEvent],
        format: GameFormat
    ) {
        guard canThrow(in: state) else { return }

        let thrower = state.currentThrower
        let rackIndex = state.targetRackIndex
        guard state.racks[rackIndex].isAlive(at: cupIndex) else { return }

        let wasBounce = state.bounceArmed
        let wasTrickshot = state.pending == .trickshot
        let wasOnFireBonus = state.pending == .onFireBonus

        state.bounceArmed = false
        state.racks[rackIndex].removeCup(at: cupIndex)
        state.sequenceNumber += 1

        state.stats[thrower.teamIndex][thrower.slot].hits += 1
        state.stats[thrower.teamIndex][thrower.slot].attempts += 1
        if wasBounce { state.stats[thrower.teamIndex][thrower.slot].bounces += 1 }
        if wasTrickshot { state.stats[thrower.teamIndex][thrower.slot].trickshots += 1 }

        // Nur reguläre Bälle zählen für Balls Back und Bombe – Bonuswürfe
        // sind Zusatz und dürfen den Zug nicht verlängern.
        if !wasTrickshot && !wasOnFireBonus {
            state.roundHits[thrower.teamIndex][state.currentBallIndex] = true
            state.lastHitCupIndex = cupIndex
        }

        events.append(.hit(thrower: thrower, bounce: wasBounce, trickshot: wasTrickshot, cupIndex: cupIndex))

        // Bounce und Trickshot nehmen zwei Becher – den zweiten wählt das
        // Team, das ihn trinken muss.
        if wasBounce || wasTrickshot {
            beginChoice(
                rackTeamIndex: rackIndex,
                count: 1,
                choosingTeamIndex: rackIndex,
                continuation: .afterHit(thrower: thrower, wasTrickshot: wasTrickshot),
                state: &state,
                events: &events,
                format: format
            )
            return
        }

        finishHit(thrower: thrower, wasTrickshot: wasTrickshot, state: &state, events: &events, format: format)
    }

    private static func finishHit(
        thrower: PlayerRef,
        wasTrickshot: Bool,
        state: inout LiveGameState,
        events: inout [GameEvent],
        format: GameFormat
    ) {
        // Ein Trickshot-Bonuswurf ist mit diesem Treffer erledigt.
        if wasTrickshot { state.pending = .normal }

        // Die Serie wird bewusst VOR der Rack-Prüfung fortgeschrieben. Sonst
        // fiele ausgerechnet der Treffer, der das Rack leert, aus der
        // Bestserie heraus – der spektakulärste Wurf des Spiels würde nicht
        // mitgezählt.
        let keepsBall = grantStreak(for: thrower, state: &state, events: &events, format: format)

        if handleRackCleared(attacker: thrower.teamIndex, state: &state, events: &events) { return }
        if keepsBall { return }

        advanceAfterThrow(thrower: thrower, state: &state, events: &events, format: format)
    }

    // MARK: - Fehlwürfe

    private enum MissKind { case miss, airball, rebound }

    private static func registerMiss(
        kind: MissKind,
        state: inout LiveGameState,
        events: inout [GameEvent],
        format: GameFormat
    ) {
        guard canThrow(in: state) else { return }
        if kind == .rebound && !canRebound(in: state, format: format) { return }

        let thrower = state.currentThrower
        let wasTrickshot = state.pending == .trickshot
        let wasOnFireBonus = state.pending == .onFireBonus

        state.stats[thrower.teamIndex][thrower.slot].attempts += 1
        state.bounceArmed = false
        state.sequenceNumber += 1

        switch kind {
        case .airball:
            // Beim Trickshot-Bonuswurf hat ein Fehlwurf bewusst keine
            // Konsequenz – auch kein Airball.
            let penalised = !wasTrickshot && format.airballPenaltyEnabled
            if penalised { state.stats[thrower.teamIndex][thrower.slot].airballs += 1 }
            events.append(.airball(thrower: thrower, penalised: penalised))
        case .rebound:
            events.append(.rebound(thrower: thrower))
        case .miss:
            events.append(.missed(thrower: thrower))
        }

        state.streaks[thrower.teamIndex][thrower.slot] = 0
        state.onFire[thrower.teamIndex][thrower.slot] = false

        if !wasTrickshot && !wasOnFireBonus {
            state.roundHits[thrower.teamIndex][state.currentBallIndex] = false
        }

        // Der Rebound gibt demselben Spieler sofort den Bonuswurf, der Zug
        // wechselt dabei nicht.
        if kind == .rebound && !wasTrickshot {
            state.pending = .trickshot
            return
        }

        state.pending = .normal
        advanceAfterThrow(thrower: thrower, state: &state, events: &events, format: format)
    }

    // MARK: - Bombe

    private static func registerBombe(
        state: inout LiveGameState,
        events: inout [GameEvent],
        format: GameFormat
    ) {
        guard canDeclareBombe(in: state) else { return }

        let thrower = state.currentThrower
        state.stats[thrower.teamIndex][thrower.slot].hits += 1
        state.stats[thrower.teamIndex][thrower.slot].attempts += 1
        state.bounceArmed = false
        state.sequenceNumber += 1
        state.roundHits[thrower.teamIndex][state.currentBallIndex] = true
        state.doubleHitSameCup = true

        events.append(.hit(thrower: thrower, bounce: false, trickshot: false, cupIndex: state.lastHitCupIndex ?? -1))

        // Die Serie zählt weiter, der Ball bleibt aber bewusst NICHT beim
        // Werfer: Die Bombe ist immer der zweite Ball des Zuges, und alles
        // Weitere – die Auswahl der zwei Zusatzbecher und das anschließende
        // Balls Back – hängt am Zugabschluss. Würde ein gleichzeitig
        // ausgelöstes On Fire hier den Ball behalten, fiele die ganze Bombe
        // aus: keine Auswahl, kein Balls Back.
        _ = grantStreak(for: thrower, state: &state, events: &events, format: format)
        state.pending = .normal
        advanceAfterThrow(thrower: thrower, state: &state, events: &events, format: format)
    }

    // MARK: - On Fire

    /// Gibt `true` zurück, wenn der Spieler den Ball behält.
    ///
    /// Ab dem dritten Treffer in Folge wirft derselbe Spieler ununterbrochen
    /// weiter, bis er das erste Mal verfehlt.
    private static func grantStreak(
        for player: PlayerRef,
        state: inout LiveGameState,
        events: inout [GameEvent],
        format: GameFormat
    ) -> Bool {
        state.streaks[player.teamIndex][player.slot] += 1
        let streak = state.streaks[player.teamIndex][player.slot]
        state.bestStreaks[player.teamIndex][player.slot] = max(
            state.bestStreaks[player.teamIndex][player.slot],
            streak
        )

        guard format.onFireEnabled, streak >= format.onFireStreakThreshold else {
            state.pending = .normal
            return false
        }

        if !state.onFire[player.teamIndex][player.slot] {
            state.onFire[player.teamIndex][player.slot] = true
            events.append(.caughtFire(player: player))
        }
        state.pending = .onFireBonus
        return true
    }

    // MARK: - Zugwechsel

    private static func advanceAfterThrow(
        thrower: PlayerRef,
        state: inout LiveGameState,
        events: inout [GameEvent],
        format: GameFormat
    ) {
        // Weitergezählt wird der Ball, nicht der Spieler: Im 1 gegen 1 wirft
        // dieselbe Person beide Bälle.
        if state.currentBallIndex < state.ballsPerTurn - 1 {
            state.currentBallIndex += 1
            return
        }
        resolveEndOfTurn(teamIndex: thrower.teamIndex, state: &state, events: &events, format: format)
    }

    private static func resolveEndOfTurn(
        teamIndex: Int,
        state: inout LiveGameState,
        events: inout [GameEvent],
        format: GameFormat
    ) {
        let hits = state.roundHits[teamIndex]
        let everyoneHit = state.supportsDoubleHitRules && hits.allSatisfy { $0 == true }
        let isBombe = everyoneHit && state.doubleHitSameCup
        state.doubleHitSameCup = false

        if isBombe {
            let choosing = state.opponent(of: teamIndex)
            events.append(.bombe(choosingTeamIndex: choosing))
            beginChoice(
                rackTeamIndex: choosing,
                count: 2,
                choosingTeamIndex: choosing,
                continuation: .afterBombe(teamIndex: teamIndex),
                state: &state,
                events: &events,
                format: format
            )
            return
        }

        if everyoneHit {
            ballsBack(teamIndex: teamIndex, state: &state, events: &events)
            return
        }

        // In der Redemption bedeutet ein nicht vollständiger Durchgang das
        // Spielende – das unterlegene Team hat den Ausgleich verpasst.
        if state.phase == .redemption {
            finish(winnerTeamIndex: state.opponent(of: teamIndex), state: &state, events: &events)
            return
        }

        startTurn(teamIndex: state.opponent(of: teamIndex), state: &state)
    }

    private static func ballsBack(
        teamIndex: Int,
        state: inout LiveGameState,
        events: inout [GameEvent]
    ) {
        events.append(.ballsBack(teamIndex: teamIndex))
        startTurn(teamIndex: teamIndex, state: &state)
    }

    private static func startTurn(teamIndex: Int, state: inout LiveGameState) {
        state.turnTeamIndex = teamIndex
        state.currentBallIndex = 0
        state.pending = .normal
        state.bounceArmed = false
        state.roundHits[teamIndex] = Array(repeating: nil, count: state.ballsPerTurn)
        state.doubleHitSameCup = false
        state.lastHitCupIndex = nil
        state.roundNumber += 1
    }

    // MARK: - Rack leer / Spielende

    /// Gibt `true` zurück, wenn das Rack leer war und der Ablauf damit
    /// abgeschlossen ist.
    private static func handleRackCleared(
        attacker: Int,
        state: inout LiveGameState,
        events: inout [GameEvent]
    ) -> Bool {
        let targetIndex = state.opponent(of: attacker)
        guard state.racks[targetIndex].isCleared else { return false }

        if state.phase == .redemption {
            // Auch das zweite Rack ist leer: ausgeglichen.
            finish(winnerTeamIndex: nil, state: &state, events: &events)
            return true
        }

        state.phase = .redemption
        state.pendingChoice = nil
        startTurn(teamIndex: targetIndex, state: &state)
        events.append(.redemptionStarted(teamIndex: targetIndex))
        return true
    }

    private static func finish(
        winnerTeamIndex: Int?,
        state: inout LiveGameState,
        events: inout [GameEvent]
    ) {
        state.phase = .finished
        state.winnerTeamIndex = winnerTeamIndex
        state.pendingChoice = nil
        events.append(.finished(winnerTeamIndex: winnerTeamIndex))
    }

    // MARK: - Erzwungene Becher-Auswahl

    private static func beginChoice(
        rackTeamIndex: Int,
        count: Int,
        choosingTeamIndex: Int,
        continuation: LiveGameState.PendingChoice.Continuation,
        state: inout LiveGameState,
        events: inout [GameEvent],
        format: GameFormat
    ) {
        let available = state.racks[rackTeamIndex].remainingCount
        let effective = min(count, available)

        guard effective > 0 else {
            // Nichts mehr auszuwählen – direkt fortfahren.
            runContinuation(continuation, state: &state, events: &events, format: format)
            return
        }

        state.pendingChoice = LiveGameState.PendingChoice(
            rackTeamIndex: rackTeamIndex,
            remaining: effective,
            choosingTeamIndex: choosingTeamIndex,
            continuation: continuation
        )
    }

    private static func resolveChoice(
        cupIndex: Int,
        state: inout LiveGameState,
        events: inout [GameEvent],
        format: GameFormat
    ) {
        guard var choice = state.pendingChoice else { return }
        guard state.racks[choice.rackTeamIndex].isAlive(at: cupIndex) else { return }

        state.racks[choice.rackTeamIndex].removeCup(at: cupIndex)
        // Muss hochzählen, obwohl es kein Wurf ist: Die laufende Nummer ist
        // die einzige Ordnung des Logs. Teilte sich die Auswahl ihre Nummer
        // mit dem Wurf davor, könnte sie beim Nachspielen VOR der Aktion
        // landen, die sie erzeugt hat – dann verpufft sie, und die Auswahl
        // wird nie fertig.
        state.sequenceNumber += 1
        events.append(.cupChosen(byTeamIndex: choice.choosingTeamIndex, cupIndex: cupIndex))

        choice.remaining -= 1
        if choice.remaining > 0 {
            state.pendingChoice = choice
            return
        }

        state.pendingChoice = nil
        runContinuation(choice.continuation, state: &state, events: &events, format: format)
    }

    private static func runContinuation(
        _ continuation: LiveGameState.PendingChoice.Continuation,
        state: inout LiveGameState,
        events: inout [GameEvent],
        format: GameFormat
    ) {
        switch continuation {
        case .afterHit(let thrower, let wasTrickshot):
            finishHit(thrower: thrower, wasTrickshot: wasTrickshot, state: &state, events: &events, format: format)

        case .afterBombe(let teamIndex):
            if handleRackCleared(attacker: teamIndex, state: &state, events: &events) { return }
            // Beide Teamkollegen haben getroffen – also gilt auch hier Balls Back.
            ballsBack(teamIndex: teamIndex, state: &state, events: &events)
        }
    }

    // MARK: - Bounce & Re-Rack

    private static func toggleBounce(state: inout LiveGameState, format: GameFormat) {
        guard canArmBounce(in: state, format: format) else { return }
        state.bounceArmed.toggle()
    }

    private static func applyReRack(
        _ formation: RackFormation,
        state: inout LiveGameState,
        events: inout [GameEvent],
        format: GameFormat
    ) {
        guard canReRack(in: state, format: format) else { return }

        let rackIndex = state.targetRackIndex
        guard formation.isValid, formation.cupCount == state.racks[rackIndex].remainingCount else { return }

        state.racks[rackIndex].reRack(to: formation)
        state.reRackUsed[state.turnTeamIndex] = true
        // Wie bei der Becher-Auswahl: eigene laufende Nummer, sonst kann das
        // Umstellen beim Nachspielen an die falsche Stelle rutschen. Danach
        // stimmten sämtliche Becher-Indizes nicht mehr.
        state.sequenceNumber += 1
        // Nach dem Umstellen sind die Becher-Indizes neu vergeben, die
        // Markierung des zuletzt getroffenen Bechers wäre falsch.
        state.lastHitCupIndex = nil

        events.append(.reRacked(teamIndex: state.turnTeamIndex, formation: formation))
    }
}
