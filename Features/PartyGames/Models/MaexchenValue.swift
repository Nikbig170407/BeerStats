//
//  MaexchenValue.swift
//  BeerStats
//
//  Die Rangfolge von Maexchen.
//
//  Zwei Wuerfel, gelesen als hoehere Ziffer zuerst: 6 und 3 ergibt 63. Die
//  Reihenfolge ist NICHT die der Zahlen – 21 ist der hoechste Wurf, danach
//  kommen die Paesche, erst dann alles andere. Genau daran verhaspelt sich
//  am Tisch jeder ab dem dritten Bier, und genau deshalb steht sie hier als
//  Liste statt als Rechenregel: Eine Liste kann man nachlesen, eine Formel
//  fuer diese Ordnung gibt es nicht.
//

import Foundation

struct MaexchenRoll: Equatable {
    let high: Int
    let low: Int

    static func random() -> MaexchenRoll {
        let a = Int.random(in: 1...6)
        let b = Int.random(in: 1...6)
        return MaexchenRoll(high: max(a, b), low: min(a, b))
    }

    var value: Int { high * 10 + low }
    var label: String { "\(high)\(low)" }
    var isMia: Bool { high == 2 && low == 1 }
    var isPasch: Bool { high == low }

    /// Augenzahlen als Wuerfelsymbole – lesbarer als zwei nackte Ziffern.
    var diceSymbols: String {
        let faces = ["", "⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
        return "\(faces[high]) \(faces[low])"
    }
}

enum MaexchenRanking {

    /// Aufsteigend vom schwaechsten zum staerksten Wurf.
    static let ordered: [Int] = [
        31, 32, 41, 42, 43, 51, 52, 53, 54, 61, 62, 63, 64, 65,
        11, 22, 33, 44, 55, 66,
        21
    ]

    static func rank(of value: Int) -> Int {
        ordered.firstIndex(of: value) ?? -1
    }

    /// Alles, was ueber dem angegebenen Wert liegt. Ohne Vorgabe der ganze
    /// Satz – der erste Spieler einer Runde darf alles ansagen.
    static func values(above claim: Int?) -> [Int] {
        guard let claim else { return ordered }
        let index = rank(of: claim)
        guard index >= 0, index + 1 < ordered.count else { return [] }
        return Array(ordered[(index + 1)...])
    }

    static func beats(_ claim: Int, _ actual: Int) -> Bool {
        rank(of: actual) >= rank(of: claim)
    }

    static func label(_ value: Int) -> String {
        if value == 21 { return "21 – Mäxchen" }
        if value % 11 == 0 { return "\(value) – Pasch" }
        return "\(value)"
    }
}
