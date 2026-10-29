//
//  Hitparade.swift
//  BeerStats
//
//  Die Regeln der Hitparade als reine Rechnung – ohne Ansicht, ohne Ton und
//  deshalb ohne Geraet pruefbar (`HitparadeTests`).
//
//  Vorbild ist Hitster: Jeder legt sich eine eigene Reihe aus Liedern, nach
//  Jahr sortiert, und beginnt mit einer offenen Karte. Wer zuerst genug
//  Karten hat, gewinnt. Dazu kommt, was bei Hitster Bingo die Discokugel
//  macht: Jede Runde lost die App aus, WAS gefragt wird (`HitQuestion`) –
//  einsortieren, Titel, Interpret oder das Jahr auf drei oder auf ein Jahr
//  genau. Wunsch des Nutzers vom 29. Oktober.
//
//  Wer richtig liegt, bekommt die Karte in seine Reihe, egal was gefragt
//  war. So waechst die Reihe bei jeder Frage, und das Einsortieren bleibt
//  trotzdem jede Runde moeglich, weil die Reihe dafuer da liegt.
//
//  Joker (die Tokens von Hitster) gibt es bewusst noch nicht – Entscheidung
//  des Nutzers vom 29. Oktober: "erstmal ohne, vielleicht spaeter".
//

import Foundation

/// Was in einer Runde gefragt wird.
enum HitQuestion: String, CaseIterable, Identifiable {
    case placement
    case title
    case artist
    case yearWithinThree
    case yearWithinOne

    var id: String { rawValue }

    var title: String {
        switch self {
        case .placement: return "Einsortieren"
        case .title: return "Titel"
        case .artist: return "Interpret"
        case .yearWithinThree: return "Jahr ± 3"
        case .yearWithinOne: return "Jahr ± 1"
        }
    }

    /// Was auf dem Aufkleber steht, waehrend das Lied laeuft.
    var prompt: String {
        switch self {
        case .placement: return "Wohin gehört es in deine Reihe?"
        case .title: return "Wie heißt das Lied?"
        case .artist: return "Wer singt das?"
        case .yearWithinThree: return "Aus welchem Jahr? Drei Jahre daneben zählen noch."
        case .yearWithinOne: return "Aus welchem Jahr? Nur ein Jahr daneben zählt noch."
        }
    }

    var symbol: String {
        switch self {
        case .placement: return "rectangle.stack.fill"
        case .title: return "textformat"
        case .artist: return "music.mic"
        case .yearWithinThree, .yearWithinOne: return "calendar"
        }
    }

    /// Wie viele Jahre daneben noch zaehlen – nur bei den Jahresfragen.
    var tolerance: Int? {
        switch self {
        case .yearWithinThree: return 3
        case .yearWithinOne: return 1
        case .placement, .title, .artist: return nil
        }
    }

    /// Titel und Interpret prueft die Runde, nicht die App. Getippt wird
    /// bewusst nicht: Am Tisch dauert das zu lange, und an Schreibweisen
    /// wie "feat." oder "The" wuerde eine richtige Antwort scheitern.
    var isJudgedByTable: Bool {
        switch self {
        case .title, .artist: return true
        case .placement, .yearWithinThree, .yearWithinOne: return false
        }
    }
}

/// Eine Antwort, so wie sie am Tisch gegeben wird.
enum HitAnswer: Equatable {
    /// Eine Luecke in der eigenen Reihe.
    case gap(Int)
    /// Ein Jahr, am Zaehlwerk eingestellt.
    case year(Int)
    /// Die Runde hat entschieden.
    case judged(Bool)
}

struct HitparadeGame: Equatable {

    /// Wie oft die Frage von eben noch dran kommt, verglichen mit den
    /// anderen. Nicht null – sonst wechselten sich zwei angehakte Fragen
    /// stur ab, und das ist kein Losen mehr. Aber selten genug, dass nicht
    /// dreimal hintereinander "Titel" kommt, waehrend vier andere Fragen
    /// angehakt sind.
    static let repeatWeight = 0.25

    let playerCount: Int
    let target: Int
    /// Die angehakten Fragen, in der Reihenfolge des Katalogs.
    let questions: [HitQuestion]

    private(set) var timelines: [SongTimeline]
    private(set) var player = 0
    private(set) var current: SongCard?
    private(set) var question: HitQuestion
    /// Ist die Karte von eben in eine Reihe gewandert?
    private(set) var currentWasKept = false

    private var deck: [SongCard]
    private let pool: [SongCard]

    /// Eine neue Partie: Jeder bekommt eine offene Karte, dann ist der
    /// Erste dran. Ohne offene Karte waere der erste Zug jeder Person eine
    /// Luecke ohne Nachbarn – immer richtig, und damit kein Zug.
    init<G: RandomNumberGenerator>(
        playerCount: Int,
        target: Int,
        questions: Set<HitQuestion>,
        songs: [SongCard],
        using generator: inout G
    ) {
        self.playerCount = max(1, playerCount)
        self.target = max(1, target)
        let gewaehlt = HitQuestion.allCases.filter { questions.contains($0) }
        self.questions = gewaehlt.isEmpty ? [.placement] : gewaehlt
        self.pool = songs
        self.deck = songs.shuffled(using: &generator)
        self.timelines = Array(repeating: SongTimeline(), count: max(1, playerCount))
        self.question = self.questions[0]

        for index in timelines.indices {
            if let karte = nextCard(using: &generator) { timelines[index].insert(karte) }
        }
        current = nextCard(using: &generator)
        question = drawQuestion(after: nil, using: &generator)
    }

    // MARK: - Lesen

    var timeline: SongTimeline { timelines[player] }

    /// Das Lied nach diesem – damit seine Hoerprobe schon laedt, waehrend
    /// noch geraten wird. Ist der Stapel gleich leer, weiss das niemand.
    var upcoming: SongCard? { deck.last }

    /// Wer die Zielzahl erreicht hat – geprueft wird nur, wer gerade dran
    /// war: Karten bekommt man nur im eigenen Zug.
    var winner: Int? {
        timelines[player].count >= target ? player : nil
    }

    /// Ist die Antwort richtig? Eine Antwort der falschen Art (ein Jahr bei
    /// der Titelfrage) ist nie richtig.
    func isCorrect(_ answer: HitAnswer) -> Bool {
        guard let karte = current else { return false }
        switch (question, answer) {
        case (.placement, .gap(let luecke)):
            return timeline.isCorrect(karte, at: luecke)
        case (.yearWithinThree, .year(let jahr)), (.yearWithinOne, .year(let jahr)):
            return abs(jahr - karte.year) <= (question.tolerance ?? 0)
        case (.title, .judged(let richtig)), (.artist, .judged(let richtig)):
            return richtig
        default:
            return false
        }
    }

    // MARK: - Spielen

    /// Wertet die Antwort aus: Richtig, und die Karte wandert in die Reihe
    /// dessen, der dran ist. Falsch, und sie ist weg.
    @discardableResult
    mutating func answer(_ answer: HitAnswer) -> Bool {
        let richtig = isCorrect(answer)
        if richtig, let karte = current {
            timelines[player].insert(karte)
        }
        currentWasKept = richtig
        return richtig
    }

    /// Die Runde haelt das Jahr der Karte fuer falsch: Sie verschwindet
    /// wieder aus der Reihe, als waere sie nie gezogen worden.
    mutating func discardCurrent() {
        guard let karte = current else { return }
        if currentWasKept { timelines[player].remove(karte) }
        currentWasKept = false
    }

    /// Der Naechste ist dran, mit neuem Lied und neuer Frage.
    mutating func advance<G: RandomNumberGenerator>(using generator: inout G) {
        player = (player + 1) % playerCount
        currentWasKept = false
        current = nextCard(using: &generator)
        question = drawQuestion(after: question, using: &generator)
    }

    /// Ein anderes Lied fuer denselben Zug, dieselbe Frage – wenn sich die
    /// Hoerprobe nicht laden laesst. Dafuer zahlt niemand.
    mutating func replaceSong<G: RandomNumberGenerator>(using generator: inout G) {
        current = nextCard(using: &generator)
    }

    // MARK: - Intern

    /// Die naechste Karte. Ist der Stapel leer, wird neu gemischt – aber
    /// nur, was nicht schon in einer Reihe liegt.
    private mutating func nextCard<G: RandomNumberGenerator>(using generator: inout G) -> SongCard? {
        if deck.isEmpty {
            let liegend = Set(timelines.flatMap { $0.cards.map(\.id) })
            deck = pool.filter { !liegend.contains($0.id) && $0.id != current?.id }.shuffled(using: &generator)
        }
        return deck.popLast()
    }

    private func drawQuestion<G: RandomNumberGenerator>(after vorher: HitQuestion?, using generator: inout G) -> HitQuestion {
        guard questions.count > 1 else { return questions[0] }
        let gewichte = questions.map { $0 == vorher ? Self.repeatWeight : 1.0 }
        var wurf = Double.random(in: 0..<gewichte.reduce(0, +), using: &generator)
        for (frage, gewicht) in zip(questions, gewichte) {
            if wurf < gewicht { return frage }
            wurf -= gewicht
        }
        return questions[questions.count - 1]
    }
}
