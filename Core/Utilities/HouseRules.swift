//
//  HouseRules.swift
//  BeerStats
//
//  Die Hausregeln: welche Sonderregeln an diesem Tisch ueberhaupt gelten.
//
//  `GameFormat` konnte das von Anfang an. Die Engine fragt jeden dieser
//  Schalter ab, und `RulesView` erklaert nur die, die auch gelten – an die
//  Oberflaeche kam davon bisher genau einer: die Becherzahl. Wer ohne Bounce
//  spielt, musste trotzdem mit Bounce werfen.
//
//  Warum die Regeln hier aufgezaehlt stehen und nicht als sechs Bloecke in
//  der View: Titel, Erklaerung und Feld gehoeren zusammen. Liegen sie
//  auseinander, steht der Schalter an einer Stelle, sein Name an der zweiten
//  und die Frage "weicht das vom Standard ab?" an einer dritten – und die
//  dritte wird vergessen. So ist eine neue Regel ein neuer Fall in der
//  Aufzaehlung, und die Zusammenfassung im Neues-Spiel-Screen kennt sie
//  sofort.
//
//  Gespeichert wird in UserDefaults, nicht am Spiel: Hausregeln gehoeren zum
//  Tisch, nicht zur Partie. Wer einmal ohne Redemption spielt, spielt
//  naechste Woche meistens auch ohne. In die Partie geschrieben wird
//  trotzdem – jedes Spiel traegt sein eigenes Regelwerk mit sich, sonst
//  wuerde eine spaeter geaenderte Hausregel den nachgespielten Wurf-Log
//  alter Partien verbiegen.
//

import Foundation

/// Eine einzelne an- und abschaltbare Regel.
///
/// Der `keyPath` ist der Grund fuer die Aufzaehlung: Damit liest und
/// schreibt die Oberflaeche das Feld, ohne es beim Namen zu nennen. Eine
/// falsch abgetippte Zuordnung – Schalter "Bounce", Feld `trickshotsAllowed`
/// – kann so gar nicht erst entstehen.
enum HouseRule: String, CaseIterable, Identifiable {
    case bounceShots
    case trickshots
    case onFire
    case airballPenalty
    case reRacks
    case redemption

    var id: String { rawValue }

    var keyPath: WritableKeyPath<GameFormat, Bool> {
        switch self {
        case .bounceShots:    return \.bounceShotsAllowed
        case .trickshots:     return \.trickshotsAllowed
        case .onFire:         return \.onFireEnabled
        case .airballPenalty: return \.airballPenaltyEnabled
        case .reRacks:        return \.reRacksAllowed
        case .redemption:     return \.redemptionAllowed
        }
    }

    var emoji: String {
        switch self {
        case .bounceShots:    return "🏓"
        case .trickshots:     return "🌀"
        case .onFire:         return "🔥"
        case .airballPenalty: return "💀"
        case .reRacks:        return "🔺"
        case .redemption:     return "⏳"
        }
    }

    var title: String {
        switch self {
        case .bounceShots:    return "Bounce Shot"
        case .trickshots:     return "Rebound und Trickshot"
        case .onFire:         return "On Fire"
        case .airballPenalty: return "Airball-Strafe"
        case .reRacks:        return "Umstellen"
        case .redemption:     return "Redemption"
        }
    }

    /// Was die Regel bewirkt, solange sie gilt. Bewusst dieselbe Aussage wie
    /// in `RulesView`, nur kuerzer – wer hier abschaltet, soll nicht erst
    /// nachschlagen muessen, was er da abschaltet.
    var detail: String {
        switch self {
        case .bounceShots:
            return "Aufsetzer im Becher zaehlt zwei Becher, den zweiten waehlt der Gegner."
        case .trickshots:
            return "Gefangener Rebound gibt einen Bonuswurf, der doppelt zaehlt."
        case .onFire:
            return "Wer in Folge trifft, behaelt den Ball, bis er verfehlt."
        case .airballPenalty:
            return "Weder Becher noch Tisch getroffen kostet einen Shot."
        case .reRacks:
            return "Einmal pro Team duerfen die Becher neu angeordnet werden."
        case .redemption:
            return "Nach dem letzten Becher darf das unterlegene Team ausgleichen."
        }
    }

    /// Wie die abgeschaltete Regel in der Zusammenfassung steht.
    var offLabel: String {
        switch self {
        case .bounceShots:    return "Ohne Bounce"
        case .trickshots:     return "Ohne Trickshot"
        case .onFire:         return "Ohne On Fire"
        case .airballPenalty: return "Airball ohne Strafe"
        case .reRacks:        return "Ohne Umstellen"
        case .redemption:     return "Ohne Redemption"
        }
    }
}

// MARK: - Regelwerk lesen

extension GameFormat {

    /// Ob an diesem Tisch nach dem Standard gespielt wird.
    ///
    /// Die Becherzahl zaehlt bewusst NICHT hinein: Sechs statt zehn Becher
    /// ist eine kuerzere Partie, keine andere Regel – und sie steht im
    /// Neues-Spiel-Screen ohnehin gross daneben.
    var isStandardRuleset: Bool {
        ruleDeviations.isEmpty
    }

    /// Alles, was vom Standard abweicht, in Worten. Leer heisst Standard.
    var ruleDeviations: [String] {
        var abweichungen = HouseRule.allCases
            .filter { !self[keyPath: $0.keyPath] }
            .map(\.offLabel)

        // Nur nennen, wenn On Fire ueberhaupt gilt – sonst stuende "On Fire
        // ab 4" neben "Ohne On Fire".
        if onFireEnabled, onFireStreakThreshold != AppConstants.GameDefaults.onFireStreakThreshold {
            abweichungen.append("On Fire ab \(onFireStreakThreshold)")
        }

        return abweichungen
    }
}

// MARK: - Speicher

extension GameFormat {

    static let houseRulesStorageKey = "beerpong.houseRules"

    /// Die zuletzt eingestellten Hausregeln.
    ///
    /// Faellt auf den Standard zurueck, wenn nichts gespeichert ist oder das
    /// Gespeicherte nicht mehr passt. Ein spaeter hinzugekommenes Feld kann
    /// das ausloesen – dann stehen die Regeln wieder auf Standard, was
    /// erklaerbar ist. Ein Absturz beim Start waere es nicht.
    static var houseRules: GameFormat {
        get {
            guard let data = UserDefaults.standard.data(forKey: houseRulesStorageKey),
                  let gespeichert = try? JSONDecoder().decode(GameFormat.self, from: data)
            else { return GameFormat() }
            return gespeichert
        }
        set {
            // Der Vorsprung gehoert zur Aufstellung, nicht an den Tisch: Er
            // wird aus den Trefferquoten der antretenden Leute vorgeschlagen
            // und angenommen. Gespeichert startete die naechste Partie mit
            // einem Handicap, das niemand mehr gewaehlt hat und das nirgends
            // mehr steht.
            var zuSpeichern = newValue
            zuSpeichern.handicapByTeam = nil

            guard let data = try? JSONEncoder().encode(zuSpeichern) else { return }
            UserDefaults.standard.set(data, forKey: houseRulesStorageKey)
        }
    }
}
