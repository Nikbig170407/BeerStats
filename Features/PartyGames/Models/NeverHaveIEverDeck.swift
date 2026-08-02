//
//  NeverHaveIEverDeck.swift
//  BeerStats
//
//  Karteninhalt fuer Ich hab noch nie.
//
//  Bewusst als eigene Datei getrennt von der Ansicht: Der Inhalt ist das,
//  was sich am haeufigsten aendert. Eine Karte zu ergaenzen soll heissen,
//  eine Zeile in eine Liste zu schreiben – nicht eine View anzufassen.
//
//  Strafen sind keine eigene Stufe, sondern Zwischenkarten: rund 20 von
//  100 Karten, an zufaelliger Stelle. Ein fester Abstand waere nach zwei
//  Strafen durchschaut, ein eigener Block wuerde den Rhythmus zerlegen.
//

import Foundation

/// Stufe einer Frage. Strafen tauchen hier bewusst nicht auf – sie sind
/// keine Frage und werden nicht gewaehlt, sondern eingestreut.
enum NeverHaveIEverLevel: String, CaseIterable, Identifiable, Codable {
    case kids
    case spicy
    case extreme

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kids: return "Kinder"
        case .spicy: return "Spicy"
        case .extreme: return "Extrem"
        }
    }

    var subtitle: String {
        switch self {
        case .kids: return "Jugendfrei, geht mit jedem"
        case .spicy: return "Fuer spaeter am Abend"
        case .extreme: return "Nur mit Leuten, die sich gut kennen"
        }
    }

    var emoji: String {
        switch self {
        case .kids: return "🧒"
        case .spicy: return "🔥"
        case .extreme: return "😈"
        }
    }
}

struct NeverHaveIEverCard: Identifiable, Equatable {

    enum Kind: Equatable {
        case statement(NeverHaveIEverLevel)
        case penalty
    }

    let id = UUID()
    let text: String
    let kind: Kind

    var isPenalty: Bool {
        if case .penalty = kind { return true }
        return false
    }

    var level: NeverHaveIEverLevel? {
        if case .statement(let level) = kind { return level }
        return nil
    }
}

enum NeverHaveIEverDeck {

    /// Anteil der Strafen am fertigen Stapel: rund 20 von 100 Karten.
    private static let penaltyShare = 0.2

    static let statements: [NeverHaveIEverCard] = kids + spicy + extreme

    /// Baut den Stapel fuer eine Runde: Fragen der gewaehlten Stufen,
    /// gemischt, mit eingestreuten Strafen.
    static func shuffled(
        levels: Set<NeverHaveIEverLevel>,
        includePenalties: Bool
    ) -> [NeverHaveIEverCard] {

        let questions = statements
            .filter { card in card.level.map { levels.contains($0) } ?? false }
            .shuffled()

        guard includePenalties, !penalties.isEmpty, questions.count > 2 else { return questions }

        // Der Anteil bezieht sich auf den fertigen Stapel, in dem die Strafen
        // ja mitzaehlen. Auf 100 Karten sollen 20 Strafen kommen, also 20 auf
        // 80 Fragen – deshalb die Umrechnung statt einer glatten Multiplikation.
        let wanted = Int((Double(questions.count) * penaltyShare / (1 - penaltyShare)).rounded())
        let slots = penaltySlots(count: wanted, questionCount: questions.count)

        // Aus einem gemischten Vorrat ziehen statt jedes Mal frei zu greifen:
        // So kommt keine Strafe ein zweites Mal, bevor die anderen dran
        // waren. Ist der Vorrat leer, wird neu gemischt.
        var pool = penalties.shuffled()
        var deck: [NeverHaveIEverCard] = []

        for (position, question) in questions.enumerated() {
            deck.append(question)
            guard slots.contains(position) else { continue }
            if pool.isEmpty { pool = penalties.shuffled() }
            deck.append(pool.removeLast())
        }

        return deck
    }

    /// Waehlt die Positionen, hinter denen eine Strafe eingeschoben wird.
    ///
    /// Rein zufaellig gezogen, aber mit zwei Einschraenkungen: Zwei Strafen
    /// direkt hintereinander waeren keine zwei Momente, sondern eine doppelte
    /// Strafe. Und hinter die letzte Frage kommt keine – der Stapel soll mit
    /// einer Frage enden, nicht mit einer Anweisung.
    private static func penaltySlots(count: Int, questionCount: Int) -> Set<Int> {
        var candidates = Array(0..<(questionCount - 1)).shuffled()
        var chosen: Set<Int> = []

        while chosen.count < count, let slot = candidates.popLast() {
            guard !chosen.contains(slot - 1), !chosen.contains(slot + 1) else { continue }
            chosen.insert(slot)
        }

        return chosen
    }

    static func questionCount(for level: NeverHaveIEverLevel) -> Int {
        statements.filter { $0.level == level }.count
    }

    // MARK: - Kinder

    private static let kids: [NeverHaveIEverCard] = [
        "einen ganzen Tag im Schlafanzug verbracht",
        "beim Karaoke gesungen",
        "eine Serie an einem Tag durchgeschaut",
        "auf einer Beerdigung gelacht",
        "meinen eigenen Namen gegoogelt",
        "einen Tanz vor dem Spiegel geübt",
        "ein Buch gekauft und nie gelesen",
        "eine Woche lang dieselbe Hose getragen",
        "meinem Haustier eine ganze Geschichte erzählt",
        "einen Film geschaut, nur weil das Plakat gut aussah",
        "eine Pflanze zu Tode gepflegt",
        "die Fernbedienung im Kühlschrank gefunden",
        "im Zug in der falschen Richtung gesessen",
        "einen Wecker gestellt und trotzdem verschlafen",
        "beim Puzzeln ein Teil versteckt, um es zuletzt zu legen",
        "mich beim Kochen so verschnitten, dass ich aufgeben musste",
        "im Supermarkt jemanden gegrüßt, den ich gar nicht kannte",
        "beim Wandern die Karte falsch gelesen und mich verlaufen",
        "so getan, als hätte ich einen Podcast gehört",
        "an einem Feiertag gearbeitet, obwohl ich frei hatte",
        "eine Achterbahn mit geschlossenen Augen gefahren",
        "mich vor einem Gewitter unter der Decke versteckt",
        "beim Monopoly heimlich Geld aus der Bank genommen",
        "ein Lied mitgesungen, obwohl ich den Text nicht kann",
        "einen Schneemann gebaut und ihm einen Namen gegeben",
        "mich im eigenen Zuhause ausgesperrt",
        "ein Selfie mehr als zehnmal wiederholt",
        "beim Zahnarzt so getan, als würde es nicht wehtun",
        "einen Regenschirm irgendwo liegen lassen",
        "mit vollem Mund geredet und dabei etwas verschüttet",
        "eine Türklingel gedrückt und bin weggerannt",
        "Hausaufgaben in der Pause abgeschrieben",
        "behauptet, ich hätte das Buch gelesen, obwohl ich nur den Film kenne",
        "mich beim Fangenspielen absichtlich fangen lassen",
        "auf einer Rolltreppe gegen die Laufrichtung gelaufen",
        "mich beim Filmschauen selbst erschreckt",
        "einen ganzen Kuchen alleine gegessen",
        "beim Kartenspiel absichtlich verloren, damit jemand anderes gewinnt",
        "mich in einem Einkaufswagen schieben lassen",
        "eine Sandburg verteidigt, bis die Flut kam",
        "beim Frisör etwas ganz anderes bekommen, als ich wollte",
        "einen Kaugummi verschluckt und mir Sorgen gemacht",
        "beim Wichteln mein eigenes Geschenk zurückbekommen",
        "mich verlaufen und aus Stolz niemanden gefragt",
        "einen ganzen Tag lang kaum ein Wort gesagt",
        "eine Suppe so lange gepustet, bis sie kalt war",
        "beim Sport ins eigene Tor getroffen",
        "auf einem Konzert gewesen, ohne die Band zu kennen",
        "beim Fotografieren mich selbst im Spiegel erwischt",
        "beim Aufräumen etwas weggeworfen, das ich später vermisst habe"
    ].map { NeverHaveIEverCard(text: $0, kind: .statement(.kids)) }

    // MARK: - Spicy

    private static let spicy: [NeverHaveIEverCard] = [
        "jemanden geküsst, den ich am selben Abend erst kennengelernt habe",
        "in einem fremden Bett aufgewacht",
        "mit jemandem aus dieser Runde geflirtet",
        "ein Date mit nach Hause genommen",
        "geküsst, während jemand anderes zugeschaut hat",
        "an einem sehr öffentlichen Ort rumgemacht",
        "im Auto rumgemacht",
        "jemanden geküsst, der vergeben war",
        "mit jemandem geschlafen und danach nie wieder geschrieben",
        "jemanden aus dieser Runde attraktiv gefunden",
        "mit zwei Leuten gleichzeitig geschrieben",
        "behauptet, ich sei vergeben, um jemanden loszuwerden",
        "ein Foto verschickt, das ich am nächsten Tag bereut habe",
        "mit jemandem geflirtet, um etwas zu bekommen",
        "ein Dating-Profil geschönt",
        "jemanden geküsst, dessen Namen ich nicht wusste",
        "jemandem einen Korb gegeben und es später bereut",
        "beim ersten Date schon geküsst",
        "mit jemandem aus dem Freundeskreis etwas gehabt",
        "eine Affäre für mich behalten",
        "morgens heimlich gegangen, bevor der andere wach war",
        "jemanden nach einer Nacht wieder heimgeschickt",
        "beim Sex lachen müssen",
        "so getan, als wäre es gut gewesen",
        "etwas im Nachttisch, das ich niemandem zeigen würde",
        "jemanden geküsst und danach so getan, als wäre nichts",
        "beim Rummachen den falschen Namen gesagt",
        "ein Date abgebrochen, weil es zu peinlich wurde",
        "jemandem hinterhergeschaut, während mein Date sprach",
        "mich in jemanden aus dieser Runde mal verguckt",
        "fast erwischt worden",
        "jemanden zurückgeschrieben, den ich eigentlich gelöscht hatte",
        "jemandem beim Tanzen sehr nahe gekommen",
        "mich für ein Date aufgebrezelt und es hat nichts gebracht",
        "jemanden geküsst, um jemand anderen eifersüchtig zu machen",
        "auf einer Party mit jemandem verschwunden",
        "Nachrichten gelöscht, bevor sie jemand sehen konnte",
        "behauptet, ich hätte so etwas noch nie gemacht",
        "mit jemandem geschrieben, den ich nie treffen wollte",
        "jemanden aus dem Bett geschickt, weil er geschnarcht hat",
        "ein ganzes Wochenende im Bett verbracht",
        "mich bei jemandem gemeldet, nur weil ich einsam war",
        "beim Kuscheln eingeschlafen und den Film verpasst",
        "mit jemandem geflirtet, der deutlich älter war",
        "ein Foto von mir mehrfach bearbeitet, bevor ich es verschickt habe",
        "jemanden blockiert und wieder entblockt",
        "so getan, als hätte ich die Nachricht nicht gesehen",
        "jemandem einen Spitznamen im Handy gegeben, den er nicht kennt",
        "mit meinem Ex nach der Trennung noch etwas gehabt",
        "jemanden geküsst, obwohl ich vergeben war"
    ].map { NeverHaveIEverCard(text: $0, kind: .statement(.spicy)) }

    // MARK: - Extrem

    private static let extreme: [NeverHaveIEverCard] = [
        "keinen hochbekommen",
        "mich auf Geschlechtskrankheiten testen lassen",
        "einen Dreier gehabt",
        "beim Sex an jemand anderen gedacht",
        "beim Sex den falschen Namen gesagt",
        "mit jemandem geschlafen, dessen Namen ich nie erfahren habe",
        "Sex an einem öffentlichen Ort gehabt",
        "beim Sex erwischt worden",
        "im Auto Sex gehabt",
        "ein Sexspielzeug gekauft",
        "einen One-Night-Stand gehabt",
        "mit jemandem geschlafen, der vergeben war",
        "etwas mit einem Kollegen gehabt",
        "mittendrin aufgehört, weil es zu peinlich wurde",
        "einen Orgasmus vorgetäuscht",
        "mit jemandem geschlafen, den ich am selben Tag kennengelernt habe",
        "nach der Trennung nochmal mit dem Ex geschlafen",
        "ein Nacktfoto verschickt",
        "ein Nacktfoto bekommen, das ich nicht wollte",
        "eine Nacht mit zwei verschiedenen Leuten verbracht",
        "mit dem besten Freund meines Partners geflirtet",
        "beim Sex so gelacht, dass es nicht weiterging",
        "Sex gehabt, während jemand im Nebenzimmer war",
        "eine Affäre gehabt",
        "jemanden betrogen",
        "erst viel später erfahren, dass ich betrogen wurde",
        "mit jemandem geschlafen, um etwas zu bekommen",
        "etwas mit jemandem aus dieser Runde gehabt",
        "mit jemandem geschlafen und es sofort bereut",
        "gemeinsam mit jemandem einen Porno geschaut",
        "ohne Unterwäsche unter Leuten gewesen",
        "eine Dating-App aus reiner Langeweile installiert",
        "mit jemandem geschlafen, der viel älter war",
        "einen Korb bekommen, als schon alles klar schien",
        "beim ersten Mal so getan, als wäre es nicht das erste Mal",
        "im Haus meiner Eltern Sex gehabt",
        "jemanden nach der Nacht nie wieder gesehen",
        "per Nachricht Schluss gemacht",
        "mich in einen Freund verliebt und es nie gesagt",
        "jemandem gesagt, ich liebe ihn, ohne es zu meinen",
        "den Namen am nächsten Tag googeln müssen",
        "mir wegen der Nachbarn Mühe gegeben, leise zu sein",
        "eine Nacht durchgemacht und bin danach zur Arbeit",
        "jemanden angerufen, um über Sex zu reden",
        "mich beim Fremdgehen fast erwischen lassen",
        "mit jemandem geschlafen, den ich vorher gar nicht attraktiv fand",
        "gesagt, es sei das Beste gewesen, obwohl es nicht stimmte",
        "Sex gehabt, von dem niemand erfahren durfte",
        "einen Schwangerschaftstest gekauft",
        "jemandem verschwiegen, wie viele es vor ihm waren"
    ].map { NeverHaveIEverCard(text: $0, kind: .statement(.extreme)) }

    // MARK: - Strafen

    private static let penalties: [NeverHaveIEverCard] = [
        "Trink einen Shot",
        "Trink 5 Schlücke",
        "Trink 3 Schlücke",
        "Verteile 5 Schlücke",
        "Alle trinken 2 Schlücke",
        "Bestimme jemanden, der einen Shot trinkt",
        "Dein linker Nachbar trinkt 3 Schlücke",
        "Dein rechter Nachbar trinkt einen Shot",
        "Trink so viele Schlücke, wie du Geschwister hast",
        "Der Jüngste in der Runde trinkt 3 Schlücke",
        "Der Älteste in der Runde trinkt 3 Schlücke",
        "Wer zuletzt gelacht hat, trinkt 2 Schlücke",
        "Wer als Letztes die Hand hebt, trinkt einen Shot",
        "Trink 4 Schlücke und verteile 4",
        "Wer heute am weitesten angereist ist, trinkt 3 Schlücke",
        "Der Gastgeber trinkt 2 Schlücke",
        "Alle, die gerade stehen, trinken 3 Schlücke",
        "Reihum ein Schluck, bis jemand lacht",
        "Alle Singles trinken 3 Schlücke",
        "Alle Vergebenen trinken 3 Schlücke",
        "Trink einen Shot mit deinem linken Nachbarn",
        "Wer zuletzt auf Toilette war, trinkt 4 Schlücke",
        "Verteile 3 Schlücke an eine Person",
        "Alle trinken einen Shot",
        "Trink 6 Schlücke",
        "Wer als Erstes lacht, trinkt einen Shot",
        "Wer vorliest, trinkt 3 Schlücke",
        "Wer gerade am lautesten ist, trinkt 3 Schlücke",
        "Trink so viele Schlücke, wie du heute Kaffee getrunken hast",
        "Wer das älteste Handy hat, trinkt 3 Schlücke"
    ].map { NeverHaveIEverCard(text: $0, kind: .penalty) }
}
