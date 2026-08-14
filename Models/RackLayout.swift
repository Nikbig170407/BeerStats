//
//  RackLayout.swift
//  BeerStats
//
//  Beschreibt die Becher-Aufstellung eines Teams: welche Reihen es gibt und
//  welche Becher davon noch stehen.
//
//  Warum Reihen statt einer reinen Anzahl: Nach einem Treffer bleibt an der
//  Stelle des Bechers eine Lücke – die verbleibenden Becher rücken NICHT
//  nach. Erst ein Re-Rack ordnet sie neu und schließt die Lücken. Ohne
//  Reihen-Information ließe sich das weder korrekt anzeigen noch die
//  Re-Rack-Regel "mindestens ein Becher an der hinteren Kante" prüfen.
//
//  Konvention: Reihe 0 ist immer die **hintere Tischkante** (vom Werfer aus
//  gesehen die am weitesten entfernte Reihe). Die View spiegelt das eigene
//  Rack beim Zeichnen, das Modell bleibt für beide Teams identisch.
//

import Foundation

struct RackLayout: Equatable {

    /// Anzahl Becher pro Reihe, Index 0 = hintere Tischkante.
    private(set) var rows: [Int]

    /// Seitlicher Versatz je Reihe, gemessen in Becherbreiten.
    ///
    /// Normalerweise überall 0, dann sind alle Reihen mittig ausgerichtet.
    /// Gebraucht wird das für versetzte Formationen wie den Berserker, bei
    /// dem zwei gleich lange Reihen um eine halbe Becherbreite gegeneinander
    /// verschoben stehen – ohne diesen Wert ließe sich das nicht von einem
    /// gewöhnlichen Block unterscheiden.
    private(set) var rowOffsets: [Double]

    /// Ein Eintrag je Becher-Platz, fortlaufend über alle Reihen hinweg
    /// (Reihe 0 zuerst). `true` = Becher steht noch.
    private(set) var cupsAlive: [Bool]

    // MARK: - Initialisierung

    /// Standard-Dreieck für die gewünschte Becherzahl.
    init(cupCount: Int) {
        let rows = Self.triangleRows(forCupCount: cupCount)
        self.init(rows: rows)
    }

    /// Aufstellung aus einer Reihenliste, alle Becher stehend.
    init(rows: [Int], rowOffsets: [Double]? = nil) {
        self.rows = rows
        self.rowOffsets = rowOffsets ?? Array(repeating: 0, count: rows.count)
        self.cupsAlive = Array(repeating: true, count: rows.reduce(0, +))
    }

    /// Versatz einer Reihe, robust gegen unpassend lange Versatz-Listen.
    func offset(forRow row: Int) -> Double {
        rowOffsets.indices.contains(row) ? rowOffsets[row] : 0
    }

    // MARK: - Abfragen

    var totalSlots: Int { cupsAlive.count }

    var remainingCount: Int { cupsAlive.filter { $0 }.count }

    /// Positionen, an denen noch ein Becher steht.
    var aliveCupIndices: [Int] {
        cupsAlive.indices.filter { cupsAlive[$0] }
    }

    var isCleared: Bool { remainingCount == 0 }

    func isAlive(at index: Int) -> Bool {
        guard cupsAlive.indices.contains(index) else { return false }
        return cupsAlive[index]
    }

    /// Die Platz-Indizes einer Reihe – die View braucht das, um die Becher
    /// zeilenweise zu zeichnen.
    func indices(inRow row: Int) -> Range<Int> {
        guard rows.indices.contains(row) else { return 0..<0 }
        let start = rows[0..<row].reduce(0, +)
        return start..<(start + rows[row])
    }

    // MARK: - Veränderungen

    /// Entfernt einen Becher. Gibt `false` zurück, wenn der Platz leer oder
    /// ungültig war – der Aufrufer kann den Wurf dann verwerfen, statt einen
    /// inkonsistenten Zustand zu erzeugen.
    @discardableResult
    mutating func removeCup(at index: Int) -> Bool {
        guard isAlive(at: index) else { return false }
        cupsAlive[index] = false
        return true
    }

    /// Entfernt den ersten noch stehenden Becher. Fallback für Regeln, bei
    /// denen kein Becher ausgewählt werden kann (z. B. weil nur noch einer
    /// steht, aber zwei fallen müssten).
    @discardableResult
    mutating func removeFirstAliveCup() -> Int? {
        guard let index = cupsAlive.firstIndex(of: true) else { return nil }
        cupsAlive[index] = false
        return index
    }

    /// Stellt die verbleibenden Becher in einer neuen Formation auf. Die
    /// Becherzahl bleibt dabei zwingend gleich (Regel 3), Lücken verschwinden.
    mutating func reRack(to formation: RackFormation) {
        guard formation.cupCount == remainingCount else { return }
        rows = formation.rows
        rowOffsets = formation.resolvedRowOffsets
        cupsAlive = Array(repeating: true, count: formation.cupCount)
    }

    // MARK: - Dreiecksaufbau

    /// Baut die klassische Dreiecksform: breiteste Reihe hinten, Spitze zum
    /// Werfer. Funktioniert auch für Becherzahlen, die keine Dreieckszahl
    /// sind – der Rest wandert dann in die hintere Reihe.
    static func triangleRows(forCupCount count: Int) -> [Int] {
        guard count > 0 else { return [] }

        // Breiteste Reihe suchen, die noch vollständig ins Dreieck passt.
        var baseWidth = 1
        while (baseWidth + 1) * (baseWidth + 2) / 2 <= count {
            baseWidth += 1
        }

        var rows: [Int] = []
        var remaining = count
        var width = baseWidth
        while remaining > 0 && width > 0 {
            let inRow = min(width, remaining)
            rows.append(inRow)
            remaining -= inRow
            width -= 1
        }
        if remaining > 0, !rows.isEmpty {
            rows[0] += remaining
        }
        return rows
    }
}

// MARK: - Formationen

/// Eine wählbare Aufstellung beim Re-Rack.
///
/// `Codable`, weil ein Re-Rack als Eintrag im Throw-Log landet und beim
/// Nachspielen exakt dieselbe Aufstellung ergeben muss.
struct RackFormation: Identifiable, Equatable, Codable {

    let name: String
    /// Becher pro Reihe, Index 0 = hintere Tischkante.
    let rows: [Int]
    /// Seitlicher Versatz je Reihe in Becherbreiten. `nil` bedeutet: alle
    /// Reihen mittig. Optional, damit bereits gespeicherte Log-Einträge ohne
    /// dieses Feld weiterhin gelesen werden können.
    let rowOffsets: [Double]?

    init(name: String, rows: [Int], rowOffsets: [Double]? = nil) {
        self.name = name
        self.rows = rows
        self.rowOffsets = rowOffsets
    }

    var id: String { "\(name)-\(rows.map(String.init).joined(separator: "-"))" }

    var cupCount: Int { rows.reduce(0, +) }

    var resolvedRowOffsets: [Double] {
        rowOffsets ?? Array(repeating: 0, count: rows.count)
    }

    /// Prüft die drei mit dem Regelwerk abgestimmten Bedingungen:
    /// 1. Kein Becher darf allein stehen.
    /// 2. Mindestens ein Becher steht an der hintersten Tischkante.
    /// 3. Die Becherzahl bleibt gleich (wird beim Anwenden geprüft, siehe
    ///    `RackLayout.reRack`).
    var isValid: Bool {
        guard !rows.isEmpty, rows.allSatisfy({ $0 >= 1 }) else { return false }
        guard rows[0] >= 1 else { return false }                            // Regel 2
        return !Self.hasIsolatedCup(rows: rows, offsets: resolvedRowOffsets) // Regel 1
    }

    /// Regel 1 auf dem Dreiecksraster geprüft: Zwei Becher gelten als
    /// benachbart, wenn sie in derselben Reihe nebeneinander liegen oder in
    /// angrenzenden Reihen höchstens eine Becherbreite versetzt sind. Die
    /// Reihen sind mittig zueinander ausgerichtet, daher der Versatz von 0,5.
    static func hasIsolatedCup(rows: [Int], offsets: [Double]) -> Bool {
        let total = rows.reduce(0, +)
        guard total > 1 else { return false }   // ein einzelner Becher ist unvermeidbar allein

        // Mittenposition jedes Bechers, gemessen in Becherbreiten – inklusive
        // des Reihenversatzes, sonst würde eine versetzte Formation falsch
        // beurteilt.
        let positions: [[Double]] = rows.enumerated().map { index, count in
            let shift = offsets.indices.contains(index) ? offsets[index] : 0
            let start = -Double(count - 1) / 2.0 + shift
            return (0..<count).map { start + Double($0) }
        }

        for row in positions.indices {
            for x in positions[row] {
                var hasNeighbour = false

                // Gleiche Reihe: direkter Nachbar links oder rechts.
                if positions[row].contains(where: { abs($0 - x) > 0.01 && abs($0 - x) <= 1.01 }) {
                    hasNeighbour = true
                }
                // Angrenzende Reihen.
                for offset in [-1, 1] {
                    let neighbourRow = row + offset
                    guard positions.indices.contains(neighbourRow) else { continue }
                    if positions[neighbourRow].contains(where: { abs($0 - x) <= 1.01 }) {
                        hasNeighbour = true
                    }
                }
                if !hasNeighbour { return true }
            }
        }
        return false
    }
}

/// Katalog der anbietbaren Formationen je verbleibender Becherzahl.
///
/// Bewusst als feste Auswahl statt freiem Verschieben: Am Tisch muss das in
/// ein bis zwei Sekunden erledigt sein, und vorgegebene Formen können die
/// Regeln gar nicht erst verletzen.
enum RackFormationCatalog {

    /// Der Berserker: zwei versetzte Linien, die vom Werfer weg zum Gegner
    /// zeigen – also parallel zu den langen Tischseiten.
    ///
    /// Umgesetzt als Reihen zu je zwei Bechern, bei denen jede zweite Reihe
    /// um eine halbe Becherbreite verschoben ist. Dadurch laufen die beiden
    /// Linien in die Tiefe und greifen wie Reißverschlusszähne ineinander,
    /// statt quer vor dem Werfer zu stehen.
    private static func berserker(_ cupCount: Int) -> RackFormation {
        let rowCount = cupCount / 2
        let rows = Array(repeating: 2, count: rowCount)
        let offsets = (0..<rowCount).map { $0.isMultiple(of: 2) ? 0.0 : 0.5 }
        return RackFormation(name: "Berserker", rows: rows, rowOffsets: offsets)
    }

    private static let presets: [Int: [RackFormation]] = [
        10: [RackFormation(name: "Dreieck", rows: [4, 3, 2, 1]),
             Self.berserker(10)],
        9:  [RackFormation(name: "Block", rows: [3, 3, 3]),
             RackFormation(name: "Pfeil", rows: [4, 3, 2])],
        8:  [RackFormation(name: "Block", rows: [4, 4]),
             Self.berserker(8),
             RackFormation(name: "Pfeil", rows: [3, 3, 2])],
        7:  [RackFormation(name: "Pfeil", rows: [4, 3]),
             RackFormation(name: "Turm", rows: [3, 2, 2])],
        6:  [RackFormation(name: "Dreieck", rows: [3, 2, 1]),
             Self.berserker(6),
             RackFormation(name: "Block", rows: [2, 2, 2]),
             RackFormation(name: "Linie", rows: [6])],
        5:  [RackFormation(name: "Dreieck", rows: [3, 2]),
             RackFormation(name: "Turm", rows: [2, 2, 1]),
             RackFormation(name: "Linie", rows: [5])],
        4:  [RackFormation(name: "Raute", rows: [1, 2, 1]),
             Self.berserker(4),
             RackFormation(name: "Quadrat", rows: [2, 2]),
             RackFormation(name: "Linie", rows: [4])],
        3:  [RackFormation(name: "Dreieck", rows: [2, 1]),
             RackFormation(name: "Linie", rows: [3])],
        2:  [RackFormation(name: "Linie", rows: [2]),
             RackFormation(name: "Turm", rows: [1, 1])]
    ]

    /// Alle regelkonformen Formationen für eine Becherzahl.
    static func formations(forRemaining count: Int) -> [RackFormation] {
        (presets[count] ?? []).filter { $0.cupCount == count && $0.isValid }
    }

    /// Nur die Formationen, die die aktuelle Aufstellung tatsächlich
    /// verändern. Eine Formation, die schon exakt so steht, wäre ein toter
    /// Menüeintrag – und ein Re-Rack, das nichts bewirkt, würde das einmalige
    /// Recht pro Spiel verbrauchen.
    static func applicableFormations(for rack: RackLayout) -> [RackFormation] {
        let hasGaps = rack.cupsAlive.contains(false)
        return formations(forRemaining: rack.remainingCount).filter { formation in
            // Der Versatz gehört zum Vergleich: Quadrat und Berserker haben
            // beide zwei gleich lange Reihen und unterscheiden sich nur darin.
            hasGaps
                || formation.rows != rack.rows
                || formation.resolvedRowOffsets != rack.rowOffsets
        }
    }
}
