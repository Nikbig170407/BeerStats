//
//  LiveGameCommentator.swift
//  BeerStats
//
//  Die App kommentiert die Partie – laut, wie ein Reporter.
//
//  Das Handy liegt waehrend einer Partie auf dem Tisch, oft ausserhalb der
//  Blickrichtung. Bisher sagte es genau einen Satz: wer dran ist. Alles
//  andere – die Serie, die Bombe, der Airball – stand auf einem Display,
//  auf das in dem Moment niemand schaut, weil alle auf den Becher schauen.
//
//  Gebaut ist das als REINE Rechnung, genau wie `LiveGameNarrator`: Ein
//  Ereignis und eine Nummer gehen hinein, ein Satz kommt heraus. Dass der
//  Satz dann auch gesprochen wird, ist Sache von `LiveGameFeedback` – der
//  Schnitt zwischen Satz und Nebenwirkung, der am 18. Oktober gezogen
//  wurde und der Grund ist, warum man hier Saetze aendern kann, ohne ein
//  Geraet zu haben.
//
//  Drei Entscheidungen, die den Unterschied zwischen Reporter und Nervensaege
//  ausmachen:
//
//  1. **Nicht jedes Ereignis spricht.** Ein Treffer und ein Fehlwurf
//     passieren im Minutentakt; wer die kommentiert, wird nach fuenf
//     Minuten abgeschaltet. Gesprochen wird, was die Runde angeht – und
//     Alltaegliches nur gelegentlich.
//  2. **Mehrere Fassungen je Ereignis.** Derselbe Satz beim dritten Mal ist
//     schlimmer als keiner.
//  3. **Die Fassung wird GERECHNET, nicht gewuerfelt.** Mit `random` saehe
//     ein Test nie dasselbe zweimal, und derselbe Zug klaenge beim
//     Nachspielen eines Logs anders als beim Spielen. Die laufende Nummer
//     des Wurfs entscheidet.
//

import Foundation

struct LiveGameCommentator {

    let naming: LiveGameNaming

    /// Was zu diesem Ereignis gesagt wird – oder `nil`, wenn geschwiegen
    /// wird.
    ///
    /// `turn` ist die laufende Nummer des Zuges. Sie waehlt die Fassung und
    /// entscheidet bei den alltaeglichen Ereignissen, ob ueberhaupt etwas
    /// gesagt wird.
    func line(for event: GameEvent, turn: Int) -> String? {
        switch event {

        case .hit(let thrower, let bounce, let trickshot, _):
            let name = naming.player(thrower)
            if bounce { return pick(["Bounce Shot! \(name).", "Aufsetzer – und drin!"], turn) }
            if trickshot { return pick(["Trickshot! \(name).", "Der sitzt. Trickshot."], turn) }
            // Ein normaler Treffer passiert dauernd. Nur jeder dritte wird
            // kommentiert, sonst redet die App durchgehend.
            guard turn % 3 == 0 else { return nil }
            return pick(["\(name) trifft.", "Sitzt.", "Drin."], turn)

        case .missed(let thrower):
            // Noch seltener als der Treffer: Daneben ist die haeufigste
            // Sache am Tisch.
            guard turn % 4 == 0 else { return nil }
            return pick(["Daneben.", "Nichts.", "\(naming.player(thrower)) verfehlt."], turn)

        case .airball(let thrower, let penalised):
            guard penalised else { return nil }
            return pick([
                "Airball! \(naming.player(thrower)) shottet.",
                "Weder Becher noch Tisch – Airball.",
                "Das war gar nichts. Airball."
            ], turn)

        case .rebound:
            return nil

        case .caughtFire(let player):
            let name = naming.player(player)
            return pick([
                "\(name) ist on fire!",
                "Dritter in Folge – \(name) brennt.",
                "\(name) trifft alles. On fire!"
            ], turn)

        case .ballsBack(let teamIndex):
            let team = naming.team(teamIndex)
            return pick([
                "Balls Back! \(team) \(naming.verb(teamIndex, "wirft", "werfen")) nochmal.",
                "Beide drin – Balls Back.",
                "\(team) \(naming.verb(teamIndex, "darf", "dürfen")) nochmal."
            ], turn)

        case .bombe(let choosingTeamIndex):
            return pick([
                "Bombe! Drei Becher weg.",
                "Zweimal derselbe Becher – Bombe!",
                "Bombe. \(naming.team(choosingTeamIndex)) \(naming.verb(choosingTeamIndex, "wählt", "wählen"))."
            ], turn)

        case .cupChosen, .reRacked:
            // Beides ist Verwaltung. Die Runde sieht es ohnehin.
            return nil

        case .redemptionStarted(let teamIndex):
            return pick([
                "Rack leer – Redemption für \(naming.team(teamIndex)).",
                "Jetzt zählt jeder Wurf. Redemption."
            ], turn)

        case .finished(let winner):
            guard let winner else { return "Unentschieden. Beide Racks leer." }
            let team = naming.team(winner)
            return pick([
                "\(team) \(naming.verb(winner, "gewinnt", "gewinnen"))!",
                "Vorbei. \(team) \(naming.verb(winner, "holt", "holen")) sich das.",
                "Das war's. Sieg für \(team)."
            ], turn)
        }
    }

    /// Eine der Fassungen, bestimmt von der laufenden Nummer.
    ///
    /// Negative Nummern kommen nicht vor, kosten aber nichts: Ein
    /// Rueckwaerts-Modulo waere in Swift negativ und griffe ins Leere.
    private func pick(_ options: [String], _ turn: Int) -> String? {
        guard !options.isEmpty else { return nil }
        let index = ((turn % options.count) + options.count) % options.count
        return options[index]
    }
}
