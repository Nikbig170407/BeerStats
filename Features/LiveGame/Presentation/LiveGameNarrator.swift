//
//  LiveGameNarrator.swift
//  BeerStats
//
//  Macht aus einem Ereignis Worte: die Protokollzeile und die Einblendung.
//
//  Beides stand im ViewModel, und die Einblendung steckte dort in derselben
//  Funktion wie Haptik und Klang (`applyFeedback`). Das war die Stelle, an
//  der man einen Satz nicht aendern konnte, ohne an einem Geraet zu
//  pruefen, ob dabei das Ruetteln heil bleibt – obwohl ein Satz eine reine
//  Rechnung ist.
//
//  Jetzt sind es zwei reine Funktionen auf einem Wert: gleiche Eingabe,
//  gleiche Ausgabe, ohne Firebase, ohne Geraet, ohne ViewModel. Die
//  Grammatik ("Lena wirft" / "Lena & Jan werfen") laeuft dabei ueber
//  `LiveGameNaming` und ist in `Team` getestet.
//

import Foundation

struct LiveGameNarrator {

    let naming: LiveGameNaming

    // MARK: - Das mitlaufende Protokoll

    func logText(for event: GameEvent) -> String {
        switch event {
        case .hit(let thrower, let bounce, let trickshot, _):
            let suffix = bounce ? " 🏓 Bounce Shot" : (trickshot ? " 🌀 Trickshot" : "")
            return "\(naming.player(thrower))\(suffix) trifft."
        case .missed(let thrower):
            return "\(naming.player(thrower)) wirft daneben."
        case .airball(let thrower, let penalised):
            return penalised
                ? "💀 Airball! \(naming.player(thrower)) muss shotten."
                : "💀 Airball im Trickshot — \(naming.player(thrower)) bleibt verschont."
        case .rebound(let thrower):
            return "🌀 Rebound! \(naming.player(thrower)) fängt den Ball."
        case .caughtFire(let player):
            return "🔥 \(naming.player(player)) ist ON FIRE."
        case .ballsBack(let teamIndex):
            return "🙌 Balls Back! \(naming.team(teamIndex)) \(naming.verb(teamIndex, "wirft", "werfen")) nochmal."
        case .bombe(let choosingTeamIndex):
            return "💣 BOMBE! \(naming.team(choosingTeamIndex)) \(naming.verb(choosingTeamIndex, "wählt", "wählen")) 2 weitere Becher."
        case .cupChosen(let byTeamIndex, _):
            return "🍺 \(naming.team(byTeamIndex)) \(naming.verb(byTeamIndex, "stellt", "stellen")) einen Becher weg."
        case .reRacked(let teamIndex, let formation):
            return "🔄 \(naming.team(teamIndex)) \(naming.verb(teamIndex, "stellt", "stellen")) auf \(formation.name) um."
        case .redemptionStarted(let teamIndex):
            return "🥤 Rack leer — Redemption für \(naming.team(teamIndex))."
        case .finished(let winner):
            guard let winner else { return "🤝 Unentschieden — beide Racks leer." }
            return "🏆 \(naming.team(winner)) \(naming.verb(winner, "gewinnt", "gewinnen"))!"
        }
    }

    // MARK: - Die Einblendung

    /// Welche Einblendung dieses Ereignis verdient – oder keine.
    ///
    /// Nicht jedes Ereignis bekommt eine: Ein normaler Treffer und ein
    /// Fehlwurf passieren im Minutentakt, und was dauernd aufblitzt, nimmt
    /// niemand mehr wahr. Eingeblendet wird nur, was die Runde angeht.
    func highlight(for event: GameEvent) -> GameHighlight? {
        switch event {
        case .hit(_, let bounce, let trickshot, _):
            if bounce {
                return GameHighlight(
                    kind: .bounce,
                    title: "BOUNCE!",
                    subtitle: "Aufsetzer im Becher – zwei Becher, der Gegner wählt den zweiten"
                )
            }
            if trickshot {
                return GameHighlight(
                    kind: .trickshot,
                    title: "TRICKSHOT!",
                    subtitle: "Zwei Becher – der Gegner wählt den zweiten"
                )
            }
            return nil

        case .airball(let thrower, let penalised):
            // Ohne Strafe keine Einblendung: Der Airball im Trickshot
            // kostet nichts, und ein rotes "AIRBALL!" ueber einem Wurf, der
            // folgenlos bleibt, waere eine Luege.
            guard penalised else { return nil }
            return GameHighlight(
                kind: .airball,
                title: "AIRBALL!",
                subtitle: "\(naming.player(thrower)) muss shotten"
            )

        case .caughtFire(let player):
            return GameHighlight(
                kind: .onFire,
                title: "ON FIRE!",
                subtitle: "\(naming.player(player)) behält den Ball bis zum ersten Fehlwurf"
            )

        case .ballsBack(let teamIndex):
            return GameHighlight(
                kind: .ballsBack,
                title: "BALLS BACK!",
                subtitle: "\(naming.team(teamIndex)) \(naming.verb(teamIndex, "wirft", "werfen")) nochmal"
            )

        case .bombe(let choosingTeamIndex):
            return GameHighlight(
                kind: .bombe,
                title: "BOMBE!",
                subtitle: "\(naming.team(choosingTeamIndex)) \(naming.verb(choosingTeamIndex, "wählt", "wählen")) 2 weitere Becher"
            )

        case .redemptionStarted(let teamIndex):
            return GameHighlight(
                kind: .redemption,
                title: "REDEMPTION",
                subtitle: "\(naming.team(teamIndex)) \(naming.verb(teamIndex, "wirft", "werfen")) nach"
            )

        case .reRacked(let teamIndex, let formation):
            return GameHighlight(
                kind: .reRack,
                title: "UMGESTELLT",
                subtitle: "\(naming.team(teamIndex)) \(naming.verb(teamIndex, "stellt", "stellen")) auf \(formation.name) um"
            )

        case .missed, .rebound, .cupChosen, .finished:
            return nil
        }
    }
}
