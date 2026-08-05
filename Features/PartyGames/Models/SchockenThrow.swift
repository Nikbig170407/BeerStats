//
//  SchockenThrow.swift
//  BeerStats
//
//  Bewertung eines Schocken-Wurfs mit drei Wuerfeln.
//
//  Von Schocken gibt es regionale Fassungen, die sich widersprechen. Hier
//  steht die verbreitetste, und sie steht bewusst an genau einer Stelle:
//  Wer nach Hausregeln spielt, aendert `evaluate` und sonst nichts.
//
//  Rangfolge von niedrig nach hoch:
//    Zahl      – alles Uebrige. Wert ist die Summe, wobei die Eins 100
//                zaehlt und jeder andere Wuerfel seinen zehnfachen Wert.
//                Damit ist 1-6-5 (210) mehr wert als 6-6-5 (170).
//    Strasse   – drei aufeinanderfolgende Augen, hoechste entscheidet.
//    General   – drei gleiche Augen ausser Einsen.
//    Schock    – zwei Einsen, der dritte Wuerfel entscheidet.
//    Schock aus – drei Einsen. Nicht zu schlagen.
//

import Foundation

struct SchockenThrow: Equatable {

    enum Kind: Int, Comparable {
        case zahl = 0
        case strasse
        case general
        case schock
        case schockAus

        static func < (lhs: Kind, rhs: Kind) -> Bool { lhs.rawValue < rhs.rawValue }

        var title: String {
            switch self {
            case .zahl: return "Zahl"
            case .strasse: return "Straße"
            case .general: return "General"
            case .schock: return "Schock"
            case .schockAus: return "Schock aus"
            }
        }
    }

    /// Absteigend sortiert, damit gleiche Wuerfe gleich aussehen.
    let dice: [Int]
    let kind: Kind
    /// Vergleichswert INNERHALB einer Art.
    let score: Int

    static func evaluate(_ raw: [Int]) -> SchockenThrow {
        let dice = raw.sorted(by: >)
        let ones = dice.filter { $0 == 1 }.count

        if ones == 3 {
            return SchockenThrow(dice: dice, kind: .schockAus, score: 0)
        }
        if ones == 2 {
            return SchockenThrow(dice: dice, kind: .schock, score: dice.first { $0 != 1 } ?? 1)
        }
        if dice[0] == dice[1], dice[1] == dice[2] {
            return SchockenThrow(dice: dice, kind: .general, score: dice[0])
        }

        let ascending = dice.sorted()
        if ascending[1] == ascending[0] + 1, ascending[2] == ascending[1] + 1 {
            return SchockenThrow(dice: dice, kind: .strasse, score: ascending[2])
        }

        let value = dice.reduce(0) { $0 + ($1 == 1 ? 100 : $1 * 10) }
        return SchockenThrow(dice: dice, kind: .zahl, score: value)
    }

    /// Ist dieser Wurf schlechter als der andere?
    static func isWorse(_ lhs: SchockenThrow, than rhs: SchockenThrow) -> Bool {
        lhs.kind == rhs.kind ? lhs.score < rhs.score : lhs.kind < rhs.kind
    }

    var symbols: String {
        let faces = ["", "⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
        return dice.map { faces[$0] }.joined(separator: " ")
    }

    var label: String {
        switch kind {
        case .zahl: return "\(score)"
        case .strasse: return "Straße bis \(score)"
        case .general: return "General, \(score)er"
        case .schock: return "Schock \(score)"
        case .schockAus: return "Schock aus"
        }
    }
}
