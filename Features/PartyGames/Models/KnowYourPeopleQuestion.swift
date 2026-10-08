//
//  KnowYourPeopleQuestion.swift
//  BeerStats
//
//  Fragen aus euren eigenen Beerpong-Zahlen.
//
//  Das einzige Trinkspiel, das nur diese App haben kann: Es braucht keinen
//  geschriebenen Inhalt, sondern nimmt, was seit Monaten ohnehin
//  mitgeschrieben wird. „Wer trifft besser, Lena oder Jan?" ist am Tisch
//  eine echte Frage – und die Antwort steht fest, statt Meinung zu sein.
//
//  Zwei Dinge entscheiden darueber, ob das Spiel gut oder aergerlich ist,
//  und beide sind hier geloest:
//
//  Erstens muss die Datenlage reichen. Eine Frage nach der Trefferquote
//  zwischen zwei Leuten mit je fuenf Wuerfen ist geraten, nicht gewusst –
//  und wer sie „falsch" beantwortet, hat zu Recht das Gefuehl, betrogen
//  worden zu sein.
//
//  Zweitens muessen die Werte weit genug auseinanderliegen. Bei 47 gegen 46
//  Prozent gibt es keine richtige Antwort, nur eine, die zufaellig stimmt.
//  Solche Fragen entstehen hier gar nicht erst.
//

import Foundation

/// Eine Frage mit zwei Leuten zur Auswahl.
struct PeopleQuestion: Identifiable, Equatable {

    enum Kind: String, CaseIterable {
        case hitRate
        case airballs
        case onFireStreak
        case wins
        case games
        case bounces

        /// Die Frage selbst – immer so gestellt, dass die groessere Zahl
        /// gewinnt. „Wer wirft WENIGER Airballs" waere dieselbe Frage mit
        /// einer Verneinung, und Verneinungen versteht am Tisch niemand.
        var question: String {
            switch self {
            case .hitRate:      return "Wer trifft besser?"
            case .airballs:     return "Wer hat mehr Airballs geworfen?"
            case .onFireStreak: return "Wer hatte die längere Serie?"
            case .wins:         return "Wer hat mehr Partien gewonnen?"
            case .games:        return "Wer hat öfter mitgespielt?"
            case .bounces:      return "Wer hat mehr Bounce Shots versenkt?"
            }
        }

        var emoji: String {
            switch self {
            case .hitRate:      return "🎯"
            case .airballs:     return "💀"
            case .onFireStreak: return "🔥"
            case .wins:         return "🏆"
            case .games:        return "🍺"
            case .bounces:      return "🏓"
            }
        }
    }

    let id: String
    let kind: Kind
    /// Die beiden zur Wahl, in Anzeigereihenfolge.
    let left: PlayerProfile
    let right: PlayerProfile
    /// Die Profil-ID der richtigen Antwort.
    let correctId: String
    /// Was danach dasteht: „41 % zu 29 %".
    let revealText: String
}

enum KnowYourPeople {

    /// Baut die Fragen, die sich aus den Zahlen dieser Leute stellen lassen.
    ///
    /// Gibt eine gemischte Liste zurueck – jede Paarung und jede Sorte
    /// hoechstens einmal, damit nicht dreimal hintereinander dieselben zwei
    /// Leute verglichen werden.
    static func questions(for profiles: [PlayerProfile]) -> [PeopleQuestion] {
        let geeignet = profiles.filter { $0.id != nil }
        guard geeignet.count >= 2 else { return [] }

        var fragen: [PeopleQuestion] = []

        for (index, links) in geeignet.enumerated() {
            for rechts in geeignet.dropFirst(index + 1) {
                for kind in PeopleQuestion.Kind.allCases {
                    if let frage = question(kind, links, rechts) {
                        fragen.append(frage)
                    }
                }
            }
        }

        return fragen.shuffled()
    }

    /// Eine einzelne Frage – oder `nil`, wenn sie nichts taugt.
    private static func question(
        _ kind: PeopleQuestion.Kind,
        _ links: PlayerProfile,
        _ rechts: PlayerProfile
    ) -> PeopleQuestion? {
        guard let linksId = links.id, let rechtsId = rechts.id else { return nil }

        let a = links.statistics
        let b = rechts.statistics

        let linkerWert: Double
        let rechterWert: Double
        let text: (Double) -> String

        switch kind {
        case .hitRate:
            // Beide brauchen genug Wuerfe, sonst ist die Quote Zufall.
            let genug = AppConstants.GameDefaults.minimumThrowsForHandicap
            guard a.totalThrows >= genug, b.totalThrows >= genug else { return nil }
            linkerWert = a.hitRate
            rechterWert = b.hitRate
            text = { "\(Int(($0 * 100).rounded())) %" }

        case .airballs:
            linkerWert = Double(a.totalAirballs)
            rechterWert = Double(b.totalAirballs)
            text = { "\(Int($0))" }

        case .onFireStreak:
            linkerWert = Double(a.longestOnFireStreak)
            rechterWert = Double(b.longestOnFireStreak)
            text = { "\(Int($0)) in Folge" }

        case .wins:
            linkerWert = Double(a.gamesWon)
            rechterWert = Double(b.gamesWon)
            text = { "\(Int($0))" }

        case .games:
            linkerWert = Double(a.gamesPlayed)
            rechterWert = Double(b.gamesPlayed)
            text = { "\(Int($0))" }

        case .bounces:
            linkerWert = Double(a.totalBounceShotsMade)
            rechterWert = Double(b.totalBounceShotsMade)
            text = { "\(Int($0))" }
        }

        guard isClearEnough(kind, linkerWert, rechterWert) else { return nil }

        let linksGewinnt = linkerWert > rechterWert
        return PeopleQuestion(
            id: "\(kind.rawValue)-\(linksId)-\(rechtsId)",
            kind: kind,
            left: links,
            right: rechts,
            correctId: linksGewinnt ? linksId : rechtsId,
            revealText: "\(text(linkerWert)) zu \(text(rechterWert))"
        )
    }

    /// Ob der Abstand gross genug ist, dass es eine richtige Antwort gibt.
    ///
    /// Bei Zaehlwerten reicht ein Unterschied von zwei – eins waere
    /// innerhalb eines Abends wieder eingeholt und fuehlt sich wie Zufall
    /// an. Bei der Trefferquote sind es fuenf Prozentpunkte, dieselbe
    /// Schwelle, ab der auch der faire Anwurf einen Becher vergibt.
    private static func isClearEnough(_ kind: PeopleQuestion.Kind, _ links: Double, _ rechts: Double) -> Bool {
        let abstand = abs(links - rechts)
        switch kind {
        case .hitRate: return abstand >= 0.05
        default: return abstand >= 2
        }
    }
}
