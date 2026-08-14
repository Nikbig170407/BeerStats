//
//  EveningAchievements.swift
//  BeerStats
//
//  Auszeichnungen fuer einen Abend.
//
//  Dieselbe Bauart wie die Plaketten am Profil: berechnet, nicht
//  gespeichert. Eine Auszeichnung ist hier keine Urkunde, die irgendwann
//  vergeben wurde, sondern eine Aussage ueber den Stand – "diese Person hat
//  heute nichts getrunken". Nimmt jemand einen Eintrag in der Bilanz
//  zurueck, verschwindet die Plakette von selbst wieder.
//
//  Bewusst NUR auf der Trinkbilanz und den Eckdaten des Abends aufgebaut.
//  Naheliegend waeren Auszeichnungen fuer Siege gewesen, aber die traegt der
//  Abend nur als Namenszeile: Bei Beerpong steht dort ein TEAMname, bei
//  Partyspielen gar nichts. Eine Plakette "dreimal gewonnen" waere damit
//  mal richtig und mal frei erfunden – und eine Auszeichnung, der man nicht
//  trauen kann, ist schlimmer als keine.
//
//  Der Wiederverwendung wegen ist es derselbe `Achievement`-Typ und
//  dieselbe `AchievementRow` wie im Profil. Zwei Plakettentypen, die gleich
//  aussehen sollen, laufen sonst auseinander.
//

import Foundation

enum EveningAchievements {

    /// Ab so vielen Spielen ist ein Abend lang genug, dass "nichts
    /// getrunken" eine Leistung ist und nicht nur ein frueher Feierabend.
    private static let minimumEntriesForAbstinence = 3

    // MARK: - Pro Person

    static func forParticipant(_ person: EveningParticipant, in evening: Evening) -> [Achievement] {
        var earned: [Achievement] = []

        func add(_ id: String, _ emoji: String, _ title: String, _ detail: String, when condition: Bool) {
            guard condition else { return }
            earned.append(Achievement(id: id, emoji: emoji, title: title, detail: detail))
        }

        let andere = evening.participants.filter { $0.id != person.id }
        let restsumme = andere.reduce(0) { $0 + $1.weight }

        add("dry", "🧊", "Unsinkbar", "Den ganzen Abend nichts getrunken",
            when: person.weight == 0 && evening.entries.count >= minimumEntriesForAbstinence)

        add("soloAct", "💀", "Alleinunterhalter", "Mehr getrunken als alle anderen zusammen",
            when: person.weight > restsumme && restsumme > 0)

        add("shots", "🥃", "Kurz und schmerzhaft", "Drei Shots oder mehr",
            when: person.shots >= 3)

        add("marathon", "🌊", "Dauerläufer", "Über zwanzig Schlücke",
            when: person.sips >= 20)

        // Nur sinnvoll, wenn ueberhaupt jemand getrunken hat – sonst waere
        // jeder gleichauf und die Plakette wertlos.
        let hoechster = evening.participants.map(\.weight).max() ?? 0
        add("thirsty", "🍺", "Durstigste Person", "Heute vorn in der Bilanz",
            when: hoechster > 0 && person.weight == hoechster)

        return earned
    }

    // MARK: - Fuer den ganzen Abend

    static func forEvening(_ evening: Evening) -> [Achievement] {
        var earned: [Achievement] = []

        func add(_ id: String, _ emoji: String, _ title: String, _ detail: String, when condition: Bool) {
            guard condition else { return }
            earned.append(Achievement(id: id, emoji: emoji, title: title, detail: detail))
        }

        let verschiedene = Set(evening.entries.map(\.title)).count
        let stunden = evening.duration / 3600

        add("longNight", "🌗", "Lange Nacht", "Über vier Stunden",
            when: stunden >= 4)

        add("variety", "🎡", "Bunter Abend", "Fünf verschiedene Spiele",
            when: verschiedene >= 5)

        add("marathonNight", "🔁", "Dauerfeuer", "Zehn Runden oder mehr",
            when: evening.entries.count >= 10)

        // Ein Abend, an dem alle ungefaehr gleich viel abbekommen haben – das
        // ist seltener, als man denkt, und deshalb eine Erwaehnung wert.
        if let hoechster = evening.participants.map(\.weight).max(),
           let niedrigster = evening.participants.map(\.weight).min(),
           hoechster > 0 {
            add("balanced", "⚖️", "Gerecht verteilt", "Zwischen Erstem und Letztem lagen keine fünf Schlücke",
                when: hoechster - niedrigster < 5)
        }

        return earned
    }
}
