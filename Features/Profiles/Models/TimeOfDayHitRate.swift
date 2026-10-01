//
//  TimeOfDayHitRate.swift
//  BeerStats
//
//  Trefferquote nach Tageszeit.
//
//  Jeder Wurf traegt seit jeher einen Zeitstempel, und bis hierher hat ihn
//  nichts gelesen. Dabei ist das die ehrlichste Statistik, die diese App
//  haben kann: Sie misst nicht, wer besser wirft, sondern was der Abend aus
//  einem macht. Neue Daten kostet sie keine.
//
//  Die Rechnung ist bewusst eine reine Funktion ueber Wurf-Logs, ohne
//  Firebase und ohne Oberflaeche – dadurch pruefbar. Zwei Dinge sind daran
//  heikel, und beide sind hier geloest:
//
//  Erstens muessen zurueckgenommene Wuerfe heraus. Ein Undo ist ein eigener
//  Eintrag und streicht den letzten davor (so wie beim Nachspielen) – wer
//  stattdessen roh zaehlt, bekommt Wuerfe in die Statistik, die am Tisch
//  nie stattgefunden haben.
//
//  Zweitens wird je PARTIE gezaehlt und erst danach zusammengelegt. Wuerde
//  man die Logs mehrerer Partien hintereinanderhaengen, koennte ein Undo am
//  Anfang der einen den letzten Wurf der vorherigen streichen.
//

import Foundation

/// Ein Zeitfenster des Tages mit den Wuerfen, die hineinfielen.
struct TimeSlotStats: Identifiable, Equatable {

    /// Volle Stunde, mit der das Fenster beginnt (0, 4, 8, …).
    let startHour: Int
    let hits: Int
    let attempts: Int

    var id: Int { startHour }

    var endHour: Int { startHour + TimeOfDayHitRate.slotLength }

    /// „20 – 24 Uhr". Das Ende als 24 statt als 0 geschrieben: Ein Fenster,
    /// das um 0 Uhr endet, liest sich wie eins, das dort anfaengt.
    var title: String { "\(startHour) – \(endHour) Uhr" }

    /// Die Quote – oder `nil`, wenn zu wenig geworfen wurde.
    ///
    /// Lieber keine Zahl als eine aus fuenf Wuerfen. Dieselbe Entscheidung
    /// wie beim fairen Anwurf: Geraten mit einer Prozentzahl darauf ist
    /// schlimmer als gar nichts, weil es nach Messung aussieht.
    var hitRate: Double? {
        guard attempts >= AppConstants.GameDefaults.minimumThrowsPerTimeSlot else { return nil }
        return Double(hits) / Double(attempts)
    }
}

struct TimeOfDayHitRate {

    /// Laenge eines Fensters in Stunden.
    ///
    /// Vier, nicht eine: Stundenweise waere die Datenlage ueberall zu duenn,
    /// und ein Abend hat ohnehin nur wenige Phasen. Vier teilt den Tag
    /// glatt, deshalb kommt kein Fenster ueber Mitternacht zu liegen – das
    /// erspart die Sonderfaelle beim Rechnen.
    static let slotLength = 4

    private var tally: [Int: (hits: Int, attempts: Int)] = [:]

    init() {}

    /// Zaehlt den Wurf-Log EINER Partie dazu.
    mutating func add(gameLog entries: [Throw], profileId: String, calendar: Calendar = .current) {
        for entry in Self.valid(entries) {
            guard entry.playerId == profileId,
                  let action = entry.action,
                  Self.isAttempt(action),
                  let timestamp = entry.timestamp else { continue }

            let hour = calendar.component(.hour, from: timestamp)
            let slot = (hour / slotLengthSafe) * slotLengthSafe

            var werte = tally[slot] ?? (hits: 0, attempts: 0)
            werte.attempts += 1
            if Self.isHit(action) { werte.hits += 1 }
            tally[slot] = werte
        }
    }

    /// Nur die Fenster, in denen tatsaechlich geworfen wurde, nach Uhrzeit.
    ///
    /// Leere Fenster bleiben weg: Ein Balken mit null Wuerfen sagt nichts
    /// ueber den Spieler, nur etwas darueber, wann niemand spielt.
    var slots: [TimeSlotStats] {
        tally
            .map { TimeSlotStats(startHour: $0.key, hits: $0.value.hits, attempts: $0.value.attempts) }
            .sorted { $0.startHour < $1.startHour }
    }

    var totalAttempts: Int {
        tally.values.reduce(0) { $0 + $1.attempts }
    }

    // MARK: - Regeln

    private var slotLengthSafe: Int { max(1, Self.slotLength) }

    /// Die Eintraege, die nach allen Ruecknahmen uebrig bleiben.
    ///
    /// Dieselbe Stapel-Rechnung wie `ThrowRepository.replay`: Ein Undo nimmt
    /// den letzten Eintrag zurueck, nicht irgendeinen.
    private static func valid(_ entries: [Throw]) -> [Throw] {
        let sortiert = entries.enumerated().sorted { left, right in
            if left.element.sequenceNumber != right.element.sequenceNumber {
                return left.element.sequenceNumber < right.element.sequenceNumber
            }
            return left.offset < right.offset
        }.map(\.element)

        var stapel: [Throw] = []
        for entry in sortiert {
            if entry.result == .undo {
                if !stapel.isEmpty { stapel.removeLast() }
                continue
            }
            guard entry.action != nil else { continue }
            stapel.append(entry)
        }
        return stapel
    }

    /// Was als Wurf zaehlt – dieselbe Abgrenzung wie in der Engine.
    ///
    /// Becher auswaehlen und Umstellen stehen im Log, sind aber keine
    /// Wuerfe; wer sie mitzaehlt, verduennt jede Quote um die Zuege, in
    /// denen gar nicht geworfen wurde.
    private static func isAttempt(_ action: GameAction) -> Bool {
        switch action {
        case .hitCup, .miss, .airball, .rebound, .bombe: return true
        case .chooseCup, .reRack, .toggleBounce: return false
        }
    }

    private static func isHit(_ action: GameAction) -> Bool {
        switch action {
        case .hitCup, .bombe: return true
        default: return false
        }
    }
}
