//
//  Team.swift
//  BeerStats
//
//  Wird eingebettet im Game-Dokument gehalten (nicht als Subcollection),
//  da Teams klein, während des Spiels unveränderlich in der Zusammensetzung
//  und immer zusammen mit dem Spiel gelesen werden (siehe Architektur-
//  Dokument 3.4).
//

import Foundation

struct Team: Codable, Identifiable, Equatable {

    var id: String
    var playerIds: [String]

    /// Denormalisiert, damit Spielernamen ohne zusätzliche User-Lookups
    /// direkt in der Spiel-Ansicht angezeigt werden können.
    var playerNames: [String]

    var score: Int = 0

    /// Bälle, die dieses Team aktuell im Spiel hat. Normalerweise 1 pro
    /// Spieler, kann durch die "beide treffen"-Regel kurzzeitig auf 2 pro
    /// Spieler steigen (beide Bälle werden zurückgegeben).
    var ballsInPlay: Int
}

// MARK: - Wie das Team heisst

/// Beerpong nannte seine Teams bis Oktober 2026 "Team 1" und "Team 2" – an
/// acht Stellen auf dem Schirm, obwohl die Namen hier daneben stehen. Das
/// trifft die Zugzeile, jede Einblendung ("BALLS BACK! Team 2 wirft
/// nochmal"), die Becherwahl, den Sieger-Screen und den Sperrbildschirm.
///
/// Fuer die Partyspiele steht die Regel laengst in der Uebergabe – Namen
/// statt Nummern, weil "Spieler 3" jeden am Tisch zwingt, im Kopf
/// mitzuzaehlen, und nach dem dritten Bier zaehlt niemand mehr richtig.
/// Beerpong, das Herzstueck, hielt sich nicht daran.
///
/// Die Benennung liegt hier und nicht in der Ansicht: Sie ist reine
/// Zeichenarbeit, haengt an nichts als den Namen – und sie ist pruefbar,
/// was bei deutscher Grammatik kein Luxus ist.
extension Team {

    /// Wie lang ein Name werden darf, bevor die Kurzform greift. Am
    /// Sperrbildschirm stehen beide Teams neben dem Stand in einer Zeile.
    static let shortNameLimit = 18

    /// Namen ohne Leereintraege. Ein halb besetztes Team hat leere Plaetze,
    /// und die duerfen weder im Namen auftauchen noch beim Verb mitzaehlen.
    static func usableNames(_ names: [String]) -> [String] {
        names.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Die Leute als Name – "Lena" oder "Lena & Jan".
    ///
    /// Auf einer Namensliste und nicht nur auf einem `Team`, weil der
    /// Neues-Spiel-Screen ueber Teams spricht, die es noch nicht gibt: Dort
    /// liegen nur die gewaehlten Profile.
    ///
    /// Der Rueckfall auf die Nummer bleibt: Ein Spiel kann ohne Namen
    /// angelegt worden sein, etwa aus einer Sicherung.
    static func displayName(for names: [String], fallbackIndex: Int) -> String {
        let namen = usableNames(names)
        guard !namen.isEmpty else { return "Team \(fallbackIndex + 1)" }
        guard namen.count > 1 else { return namen[0] }

        // Mehr als zwei kommt heute nicht vor (zwei pro Team), ist aber
        // billiger mitgeschrieben als spaeter nachgeruestet.
        return namen.dropLast().joined(separator: ", ") + " & " + namen[namen.count - 1]
    }

    /// Dasselbe, aber kurz: "Maximilian & K." statt
    /// "Maximilian & Konstantin".
    static func shortDisplayName(for names: [String], fallbackIndex: Int) -> String {
        let voll = displayName(for: names, fallbackIndex: fallbackIndex)
        guard voll.count > shortNameLimit else { return voll }

        let namen = usableNames(names)
        guard namen.count > 1 else { return String(voll.prefix(shortNameLimit)) }

        let rest = namen.dropFirst().compactMap { $0.first.map { "\($0)." } }
        return ([namen[0]] + rest).joined(separator: " & ")
    }

    static func isPlural(_ names: [String]) -> Bool {
        usableNames(names).count > 1
    }

    /// Das Verb zu einer Namensliste.
    static func verb(for names: [String], _ singular: String, _ plural: String) -> String {
        isPlural(names) ? plural : singular
    }

    func displayName(fallbackIndex: Int) -> String {
        Team.displayName(for: playerNames, fallbackIndex: fallbackIndex)
    }

    func shortDisplayName(fallbackIndex: Int) -> String {
        Team.shortDisplayName(for: playerNames, fallbackIndex: fallbackIndex)
    }

    /// Sind es mehrere Leute? Entscheidet ueber die Konjugation.
    var isPlural: Bool { Team.isPlural(playerNames) }

    /// Das Verb passend zur Teamgroesse.
    ///
    /// Das ist der unsichtbare Teil der Umstellung: Mit "Team 2" war immer
    /// Singular richtig. Sobald das Team seine Leute nennt, heisst es "Lena
    /// wirft nochmal", aber "Lena & Jan WERFEN nochmal" – und ein Satz, der
    /// grammatisch daneben liegt, faellt am Tisch sofort auf.
    func verb(_ singular: String, _ plural: String) -> String {
        isPlural ? plural : singular
    }
}
