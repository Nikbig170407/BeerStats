//
//  Evening.swift
//  BeerStats
//
//  Der Abend als eigene Einheit – und die Trinkbilanz darin.
//
//  Die App kannte bisher nur zwei Zeitraeume: eine Partie und die Ewigkeit.
//  Was fehlte, war genau das, was ihr tatsaechlich erlebt. Ihr spielt drei
//  Runden Beerpong, zwei Ring of Fire, ein Turnier - und danach gibt es
//  keine Zusammenfassung davon. Am naechsten Tag ist der Abend in
//  Lebenszeit-Summen aufgegangen, wo er verschwindet.
//
//  Zwei Entscheidungen praegen den Aufbau:
//
//  Erstens liegt das hier LOKAL in UserDefaults, nicht in Firestore. Ein
//  Abend ist fluechtig, gehoert einem Geraet, und jeder Schluck als
//  Schreibzugriff waere im Spark-Tarif verschwendetes Kontingent.
//
//  Zweitens ist es ein statischer Speicher wie `TableRoster` und kein
//  Dienst im AppContainer. Der Abend muss aus zwanzig Partyspiel-Ansichten
//  erreichbar sein, die heute gar keinen Container bekommen - ihn dort
//  durchzufaedeln waere mehr Umbau als der Abend selbst.
//
//  Die Trinkbilanz zaehlt, was die App den ganzen Abend ansagt und bisher
//  nie mitgeschrieben hat. Gespeichert werden rohe Schluecke und Shots, nicht
//  die ausformulierte Menge: Wer die Haerte mitten im Abend umstellt, soll
//  nicht ruekwirkend anders getrunken haben.
//

import Foundation

// MARK: - Bausteine

struct EveningParticipant: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var emoji: String
    var sips: Int = 0
    var shots: Int = 0

    /// Grobes Mass, um den Abend zu sortieren. Ein Shot zaehlt wie fuenf
    /// Schluecke – dieselbe Umrechnung, die `DrinkAmount` benutzt, wenn ohne
    /// Shots gespielt wird.
    var weight: Int { sips + shots * 5 }
}

struct EveningEntry: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var emoji: String
    var at: Date
    /// Wer gewonnen hat, sofern das Spiel einen Sieger kennt – als Text,
    /// zum Anzeigen.
    var winner: String? = nil

    /// Welches Spiel das war (`PartyGame.rawValue`), um den Sieger spaeter
    /// an genau diesen Eintrag zu haengen.
    ///
    /// Ein Eintrag entsteht beim BETRETEN des Spiels, der Sieger steht erst
    /// am Ende fest. Ohne diese Kennung muesste das Nachtragen den Eintrag
    /// ueber seinen Titel suchen – und Titel aendern sich.
    var gameId: String? = nil

    /// Wer gewonnen hat, als Teilnehmer-IDs. Fuer den Pokal.
    ///
    /// Getrennt von `winner`: Dort steht "Lena & Jan" als ein Text, hier
    /// stehen zwei Personen. Ohne die Trennung zaehlte ein 2-gegen-2-Sieg
    /// fuer niemanden einzeln.
    var winnerIds: [String]? = nil

    /// Was dieser Sieg wert ist.
    ///
    /// Steht IM Eintrag und wird nicht spaeter aus dem Katalog geholt: Ein
    /// Abend von letztem Monat soll so ausgewertet werden, wie er gespielt
    /// wurde – dieselbe Entscheidung wie bei der Sicherungsdatei.
    var points: Int? = nil

    /// Alte Abende haben keine Punkte; sie zaehlen deshalb auch nicht mit.
    var trophyPoints: Int { winnerIds == nil ? 0 : (points ?? 0) }
}

struct Evening: Codable, Equatable {
    var startedAt: Date
    var endedAt: Date?
    var participants: [EveningParticipant]
    var entries: [EveningEntry]

    var isRunning: Bool { endedAt == nil }

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }

    /// Ausformulierte Dauer – "2 Stunden 15 Minuten" liest sich am Tisch
    /// besser als eine Uhrzeitspanne.
    var readableDuration: String {
        let minuten = max(0, Int(duration / 60))
        let stunden = minuten / 60
        let rest = minuten % 60
        if stunden == 0 { return "\(rest) Minuten" }
        return rest == 0 ? "\(stunden) Stunden" : "\(stunden) h \(rest) min"
    }

    var mostDrinks: EveningParticipant? {
        participants.filter { $0.weight > 0 }.max { $0.weight < $1.weight }
    }

    var winCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for entry in entries {
            guard let winner = entry.winner else { continue }
            counts[winner, default: 0] += 1
        }
        return counts
    }

    var mostWins: (name: String, count: Int)? {
        guard let best = winCounts.max(by: { $0.value < $1.value }) else { return nil }
        return (best.key, best.value)
    }

    // MARK: - Der Pokal

    /// Ein Platz in der Siegerwertung.
    struct TrophyRank: Identifiable, Equatable {
        let participant: EveningParticipant
        let points: Int
        let wins: Int

        var id: String { participant.id }
    }

    /// Die Siegerwertung: Punkte je gewonnenem Spiel, gewichtet nach seiner
    /// Laenge.
    ///
    /// Die Gewichtung ist der Kern. Ohne sie gewinnt den Abend, wer am
    /// meisten Reaktionsduell gespielt hat – eine Runde dauert zwei
    /// Minuten, eine Partie Beerpong eine Viertelstunde. Was das einzelne
    /// Spiel wert ist, steht im Eintrag und nicht hier.
    ///
    /// Wer nichts gewonnen hat, steht trotzdem in der Liste: Eine Wertung,
    /// aus der man verschwindet, sobald man verliert, erzaehlt vom Abend
    /// die halbe Wahrheit.
    var trophyBoard: [TrophyRank] {
        var punkte: [String: Int] = [:]
        var siege: [String: Int] = [:]

        for eintrag in entries {
            guard let gewinner = eintrag.winnerIds else { continue }
            for id in gewinner {
                punkte[id, default: 0] += eintrag.trophyPoints
                siege[id, default: 0] += 1
            }
        }

        return participants
            .map { TrophyRank(participant: $0, points: punkte[$0.id] ?? 0, wins: siege[$0.id] ?? 0) }
            .sorted { links, rechts in
                // Bei Punktgleichstand entscheidet, wer dafuer weniger
                // Spiele gebraucht hat.
                if links.points != rechts.points { return links.points > rechts.points }
                return links.wins < rechts.wins
            }
    }

    /// Der Sieger des Abends – oder niemand, solange nichts gewonnen wurde.
    var trophyWinner: TrophyRank? {
        guard let bester = trophyBoard.first, bester.points > 0 else { return nil }
        // Gleichstand an der Spitze ist kein Sieg. Zwei Namen unter einem
        // Pokal waeren am Tisch der Anfang einer Diskussion, und die
        // entscheidet die Runde besser selbst.
        let gleichauf = trophyBoard.filter { $0.points == bester.points }
        return gleichauf.count == 1 ? bester : nil
    }

    /// Der Abend in Worten – zum Vorlesen und zum Teilen.
    ///
    /// Bewusst Text und kein Bild: Text laesst sich in jede Gruppe schicken,
    /// vorlesen, suchen und in zehn Jahren noch oeffnen. Ein Bild sieht am
    /// Abend besser aus und ist eine Sackgasse.
    var shareText: String {
        let datum = DateFormatter()
        datum.locale = Locale(identifier: "de_DE")
        datum.dateFormat = "EEEE, d. MMMM"

        var zeilen = ["🌅 Unser Abend am \(datum.string(from: startedAt))"]
        zeilen.append("\(readableDuration) · \(entries.count) \(entries.count == 1 ? "Spiel" : "Spiele")")

        if let pokal = trophyWinner {
            zeilen.append("🏆 Sieger des Abends: \(pokal.participant.name) (\(pokal.points) Punkte)")
        } else if let sieger = mostWins {
            zeilen.append("🏆 Meiste Siege: \(sieger.name) (\(sieger.count)×)")
        }
        if let durstig = mostDrinks {
            zeilen.append("🍺 Durstigste Person: \(durstig.name)")
        }

        zeilen.append("")
        for teilnehmer in participants.sorted(by: { $0.weight > $1.weight }) {
            var menge: [String] = []
            if teilnehmer.sips > 0 {
                menge.append(teilnehmer.sips == 1 ? "1 Schluck" : "\(teilnehmer.sips) Schlücke")
            }
            if teilnehmer.shots > 0 {
                menge.append(teilnehmer.shots == 1 ? "1 Shot" : "\(teilnehmer.shots) Shots")
            }
            zeilen.append("\(teilnehmer.emoji) \(teilnehmer.name): \(menge.isEmpty ? "nichts" : menge.joined(separator: ", "))")
        }

        return zeilen.joined(separator: "\n")
    }
}

// MARK: - Speicher

enum EveningLog {

    private static let storageKey = "evening.current"

    static var current: Evening? {
        get {
            guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
            return try? JSONDecoder().decode(Evening.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                UserDefaults.standard.removeObject(forKey: storageKey)
                return
            }
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    static var isRunning: Bool { current?.isRunning == true }

    // MARK: Ablauf

    static func start(with profiles: [PlayerProfile]) {
        current = Evening(
            startedAt: Date(),
            endedAt: nil,
            participants: profiles.map {
                EveningParticipant(id: $0.id ?? UUID().uuidString, name: $0.name, emoji: $0.emoji)
            },
            entries: []
        )
    }

    /// Beendet den Abend und gibt ihn zur Auswertung zurueck.
    @discardableResult
    static func finish() -> Evening? {
        guard var abend = current else { return nil }
        abend.endedAt = Date()
        current = nil
        archive(abend)
        return abend
    }

    // MARK: - Frueher

    private static let archiveKey = "evening.archive"

    /// Wie viele Abende aufgehoben werden.
    ///
    /// Zwanzig, nicht alle: Die Liste liegt in UserDefaults und wird bei
    /// jedem Start gelesen. Ein Jahr Freitage waere sie immer noch klein,
    /// aber irgendwo muss eine Grenze stehen, und zwanzig Abende reichen
    /// weit zurueck – wer den vom Maerz sucht, sucht ihn ohnehin nicht hier.
    private static let archiveLimit = 20

    /// Die beendeten Abende, der jüngste zuerst.
    ///
    /// Der Rueckblick war bis Oktober 2026 einmalig: "Fertig" antippen, und
    /// er war weg. Dabei ist er das Einzige, was von einem Abend uebrig
    /// bleibt – die Partyspiele schreiben keine Statistik.
    static var archived: [Evening] {
        get {
            guard let data = UserDefaults.standard.data(forKey: archiveKey) else { return [] }
            return (try? JSONDecoder().decode([Evening].self, from: data)) ?? []
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: archiveKey)
        }
    }

    private static func archive(_ abend: Evening) {
        // Ein Abend ohne Spiel und ohne Schluck ist ein Fehlstart, kein
        // Abend. Er wuerde die Liste fuellen, ohne etwas zu erzaehlen.
        guard !abend.entries.isEmpty || abend.participants.contains(where: { $0.weight > 0 }) else { return }
        archived = Array(([abend] + archived).prefix(archiveLimit))
    }

    static func discard() {
        current = nil
    }

    // MARK: Eintraege

    /// Vermerkt ein gespieltes Spiel. Tut nichts, wenn kein Abend laeuft –
    /// so darf der Aufruf ueberall stehen, ohne dass jede Aufrufstelle
    /// vorher fragen muss.
    static func record(
        title: String,
        emoji: String,
        winner: String? = nil,
        gameId: String? = nil,
        winnerIds: [String] = [],
        points: Int = 0
    ) {
        guard var abend = current, abend.isRunning else { return }
        abend.entries.append(
            EveningEntry(
                id: UUID().uuidString,
                title: title,
                emoji: emoji,
                at: Date(),
                winner: winner,
                gameId: gameId,
                winnerIds: winnerIds.isEmpty ? nil : winnerIds,
                points: winnerIds.isEmpty ? nil : points
            )
        )
        current = abend
    }

    static func record(partyGame: PartyGame) {
        record(title: partyGame.title, emoji: partyGame.emoji, gameId: partyGame.rawValue)
    }

    /// Traegt den Sieger in den Eintrag nach, der beim Betreten entstanden
    /// ist.
    ///
    /// Nicht als neuer Eintrag: Der Abend zeigt sonst dasselbe Spiel
    /// zweimal – einmal beim Aufmachen und einmal beim Gewinnen. Gesucht
    /// wird von hinten, weil ein Spiel mehrmals am Abend laufen kann, und
    /// nur ein Eintrag ohne Sieger kommt in Frage.
    ///
    /// Die Positionen sind Plaetze am Tisch, keine Profil-IDs – dieselbe
    /// Zaehlung, mit der die Partyspiele auch ihre Schluecke buchen.
    static func recordWinner(positions: [Int], for game: PartyGame) {
        guard var abend = current, abend.isRunning, !positions.isEmpty else { return }

        let ids = positions.compactMap { platz -> String? in
            abend.participants.indices.contains(platz) ? abend.participants[platz].id : nil
        }
        guard !ids.isEmpty else { return }

        guard let stelle = abend.entries.lastIndex(where: {
            $0.gameId == game.rawValue && $0.winnerIds == nil
        }) else { return }

        abend.entries[stelle].winnerIds = ids
        abend.entries[stelle].points = game.length.points
        abend.entries[stelle].winner = ids
            .compactMap { id in abend.participants.first { $0.id == id }?.name }
            .joined(separator: " & ")
        current = abend
    }

    // MARK: Trinkbilanz

    static func addSips(_ count: Int, to participantId: String) {
        change(participantId) { $0.sips += count }
    }

    static func addShot(to participantId: String) {
        change(participantId) { $0.shots += 1 }
    }

    /// Zuruecknehmen muss genauso einfach sein wie Eintragen – am Tisch
    /// vertippt man sich, und eine Bilanz, die man nicht korrigieren kann,
    /// glaubt nach einer Stunde niemand mehr.
    static func undoLastDrink(for participantId: String) {
        change(participantId) { teilnehmer in
            // Zwei Faelle reichen: Sind Schluecke da, geht einer davon weg -
            // sonst ein Shot. Ein dritter Zweig fuer "nur Shots" waere nicht
            // erreichbar, weil genau das schon der erste Fall ist.
            if teilnehmer.sips > 0 {
                teilnehmer.sips -= 1
            } else if teilnehmer.shots > 0 {
                teilnehmer.shots -= 1
            }
        }
    }

    private static func change(_ participantId: String, _ body: (inout EveningParticipant) -> Void) {
        guard var abend = current, abend.isRunning,
              let index = abend.participants.firstIndex(where: { $0.id == participantId })
        else { return }

        body(&abend.participants[index])
        current = abend
    }
}
