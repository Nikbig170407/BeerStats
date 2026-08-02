//
//  NeverHaveIEverDeck.swift
//  BeerStats
//
//  Karteninhalt fuer Ich hab noch nie.
//
//  Jede Karte traegt den VOLLSTAENDIGEN Satz, nicht nur den Nachsatz.
//  Vorher stand ein festes "Ich hab noch nie" in der Ansicht davor – das
//  kann grammatisch gar nicht aufgehen: Viele Saetze brauchen "Ich bin"
//  (aufgewacht, gefahren, gegangen) oder "Ich hatte" (einen Dreier, eine
//  Affaere). Mit dem ganzen Satz auf der Karte ist jede Zeile fuer sich
//  richtig, und beim Ergaenzen muss niemand die Hilfsverben im Kopf haben.
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
        "Ich hab noch nie einen ganzen Tag im Schlafanzug verbracht",
        "Ich hab noch nie beim Karaoke gesungen",
        "Ich hab noch nie eine Serie an einem einzigen Tag durchgeschaut",
        "Ich hab noch nie auf einer Beerdigung gelacht",
        "Ich hab noch nie meinen eigenen Namen gegoogelt",
        "Ich hab noch nie einen Tanz vor dem Spiegel geübt",
        "Ich hab noch nie ein Buch gekauft und dann nie gelesen",
        "Ich hab noch nie eine ganze Woche dieselbe Hose getragen",
        "Ich hab noch nie meinem Haustier eine ganze Geschichte erzählt",
        "Ich hab noch nie einen Film geschaut, nur weil das Plakat gut aussah",
        "Ich hab noch nie eine Pflanze zu Tode gepflegt",
        "Ich hab noch nie die Fernbedienung im Kühlschrank gefunden",
        "Ich bin noch nie im Zug in die falsche Richtung gefahren",
        "Ich hab noch nie einen Wecker gestellt und trotzdem verschlafen",
        "Ich hab noch nie beim Puzzeln ein Teil versteckt, um es zuletzt zu legen",
        "Ich hab noch nie beim Kochen so danebengegriffen, dass ich aufgeben musste",
        "Ich hab noch nie im Supermarkt jemanden gegrüßt, den ich gar nicht kannte",
        "Ich hab noch nie beim Wandern die Karte falsch gelesen",
        "Ich hab noch nie so getan, als hätte ich einen Podcast gehört",
        "Ich hab noch nie an einem freien Feiertag gearbeitet",
        "Ich bin noch nie eine Achterbahn mit geschlossenen Augen gefahren",
        "Ich hab noch nie bei Gewitter unter der Decke gelegen",
        "Ich hab noch nie beim Monopoly heimlich Geld aus der Bank genommen",
        "Ich hab noch nie ein Lied mitgesungen, dessen Text ich nicht kann",
        "Ich hab noch nie einen Schneemann gebaut und ihm einen Namen gegeben",
        "Ich hab mich noch nie aus meiner eigenen Wohnung ausgesperrt",
        "Ich hab noch nie ein Selfie mehr als zehnmal wiederholt",
        "Ich hab noch nie beim Zahnarzt so getan, als würde es nicht wehtun",
        "Ich hab noch nie einen Regenschirm irgendwo liegen lassen",
        "Ich hab noch nie mit vollem Mund geredet und dabei etwas verschüttet",
        "Ich hab noch nie irgendwo geklingelt und mich dann versteckt",
        "Ich hab noch nie Hausaufgaben in der Pause abgeschrieben",
        "Ich hab noch nie behauptet, ein Buch gelesen zu haben, das ich nur als Film kenne",
        "Ich hab mich noch nie beim Fangenspielen absichtlich fangen lassen",
        "Ich bin noch nie auf einer Rolltreppe gegen die Laufrichtung gelaufen",
        "Ich hab mich noch nie beim Filmschauen selbst erschreckt",
        "Ich hab noch nie einen ganzen Kuchen alleine gegessen",
        "Ich hab noch nie absichtlich verloren, damit jemand anderes gewinnt",
        "Ich hab mich noch nie in einem Einkaufswagen schieben lassen",
        "Ich hab noch nie eine Sandburg gegen die Flut verteidigt",
        "Ich hab noch nie beim Frisör etwas ganz anderes bekommen, als ich wollte",
        "Ich hab noch nie einen Kaugummi verschluckt und mir Sorgen gemacht",
        "Ich hab noch nie beim Wichteln mein eigenes Geschenk zurückbekommen",
        "Ich hab mich noch nie verlaufen und aus Stolz niemanden gefragt",
        "Ich hab noch nie einen ganzen Tag lang kaum ein Wort gesagt",
        "Ich hab noch nie eine Suppe so lange gepustet, bis sie kalt war",
        "Ich hab noch nie ins eigene Tor getroffen",
        "Ich war noch nie auf einem Konzert, ohne die Band zu kennen",
        "Ich hab mich noch nie beim Fotografieren im Spiegel selbst erwischt",
        "Ich hab noch nie etwas weggeworfen, das ich später vermisst habe"
    ].map { NeverHaveIEverCard(text: $0, kind: .statement(.kids)) }

    // MARK: - Spicy

    private static let spicy: [NeverHaveIEverCard] = [
        "Ich hab noch nie jemanden geküsst, den ich am selben Abend erst kennengelernt habe",
        "Ich bin noch nie in einem fremden Bett aufgewacht",
        "Ich hab noch nie mit jemandem aus dieser Runde geflirtet",
        "Ich hab noch nie ein Date mit nach Hause genommen",
        "Ich hab noch nie geküsst, während jemand anderes zugeschaut hat",
        "Ich hab noch nie an einem sehr öffentlichen Ort rumgemacht",
        "Ich hab noch nie im Auto rumgemacht",
        "Ich hab noch nie jemanden geküsst, der vergeben war",
        "Ich hab noch nie mit jemandem geschlafen und mich danach nie wieder gemeldet",
        "Ich hab noch nie jemanden aus dieser Runde attraktiv gefunden",
        "Ich hab noch nie mit zwei Leuten gleichzeitig geschrieben",
        "Ich hab noch nie behauptet, vergeben zu sein, um jemanden loszuwerden",
        "Ich hab noch nie ein Foto verschickt, das ich am nächsten Tag bereut habe",
        "Ich hab noch nie geflirtet, um etwas zu bekommen",
        "Ich hab noch nie mein Dating-Profil geschönt",
        "Ich hab noch nie jemanden geküsst, dessen Namen ich nicht wusste",
        "Ich hab noch nie einen Korb gegeben und es später bereut",
        "Ich hab noch nie beim ersten Date schon geküsst",
        "Ich hatte noch nie etwas mit jemandem aus meinem Freundeskreis",
        "Ich hab noch nie eine Affäre für mich behalten",
        "Ich bin noch nie morgens heimlich gegangen, bevor der andere wach war",
        "Ich hab noch nie jemanden nach einer Nacht wieder heimgeschickt",
        "Ich hab noch nie beim Rummachen lachen müssen",
        "Ich hab noch nie so getan, als wäre es gut gewesen",
        "Ich hab noch nie etwas im Nachttisch gehabt, das ich niemandem zeigen würde",
        "Ich hab noch nie jemanden geküsst und danach so getan, als wäre nichts gewesen",
        "Ich hab noch nie beim Rummachen den falschen Namen gesagt",
        "Ich hab noch nie ein Date abgebrochen, weil es zu peinlich wurde",
        "Ich hab noch nie jemandem hinterhergeschaut, während mein Date geredet hat",
        "Ich hab mich noch nie in jemanden aus dieser Runde verguckt",
        "Ich bin noch nie fast erwischt worden",
        "Ich hab noch nie jemandem zurückgeschrieben, den ich eigentlich gelöscht hatte",
        "Ich bin noch nie jemandem beim Tanzen sehr nahe gekommen",
        "Ich hab mich noch nie für ein Date aufgebrezelt, ohne dass es etwas gebracht hat",
        "Ich hab noch nie jemanden geküsst, um jemand anderen eifersüchtig zu machen",
        "Ich bin noch nie auf einer Party mit jemandem verschwunden",
        "Ich hab noch nie Nachrichten gelöscht, bevor sie jemand sehen konnte",
        "Ich hab noch nie behauptet, so etwas noch nie gemacht zu haben",
        "Ich hab noch nie mit jemandem geschrieben, den ich nie treffen wollte",
        "Ich hab noch nie jemanden aus dem Bett geschickt, weil er geschnarcht hat",
        "Ich hab noch nie ein ganzes Wochenende im Bett verbracht",
        "Ich hab mich noch nie bei jemandem gemeldet, nur weil ich einsam war",
        "Ich bin noch nie beim Kuscheln eingeschlafen und hab den Film verpasst",
        "Ich hab noch nie mit jemandem geflirtet, der deutlich älter war",
        "Ich hab noch nie ein Foto von mir mehrfach bearbeitet, bevor ich es verschickt habe",
        "Ich hab noch nie jemanden blockiert und wieder entblockt",
        "Ich hab noch nie so getan, als hätte ich die Nachricht nicht gesehen",
        "Ich hab noch nie jemandem einen Spitznamen im Handy gegeben, den er nicht kennt",
        "Ich hatte noch nie nach der Trennung nochmal etwas mit meinem Ex",
        "Ich hab noch nie jemanden geküsst, obwohl ich vergeben war"
    ].map { NeverHaveIEverCard(text: $0, kind: .statement(.spicy)) }

    // MARK: - Extrem

    private static let extreme: [NeverHaveIEverCard] = [
        "Ich hab noch nie keinen hochbekommen",
        "Ich hab mich noch nie auf Geschlechtskrankheiten testen lassen",
        "Ich hatte noch nie einen Dreier",
        "Ich hab noch nie beim Sex an jemand anderen gedacht",
        "Ich hab noch nie beim Sex den falschen Namen gesagt",
        "Ich hab noch nie mit jemandem geschlafen, dessen Namen ich nie erfahren habe",
        "Ich hatte noch nie Sex an einem öffentlichen Ort",
        "Ich bin noch nie beim Sex erwischt worden",
        "Ich hatte noch nie Sex im Auto",
        "Ich hab noch nie ein Sexspielzeug gekauft",
        "Ich hatte noch nie einen One-Night-Stand",
        "Ich hab noch nie mit jemandem geschlafen, der vergeben war",
        "Ich hatte noch nie etwas mit einem Kollegen",
        "Ich hab noch nie mittendrin aufgehört, weil es zu peinlich wurde",
        "Ich hab noch nie einen Orgasmus vorgetäuscht",
        "Ich hab noch nie mit jemandem geschlafen, den ich am selben Tag kennengelernt habe",
        "Ich hab noch nie nach der Trennung nochmal mit meinem Ex geschlafen",
        "Ich hab noch nie ein Nacktfoto verschickt",
        "Ich hab noch nie ein Nacktfoto bekommen, das ich nicht wollte",
        "Ich hab noch nie eine Nacht mit zwei verschiedenen Leuten verbracht",
        "Ich hab noch nie mit dem besten Freund meines Partners geflirtet",
        "Ich hab noch nie beim Sex so gelacht, dass es nicht weiterging",
        "Ich hatte noch nie Sex, während jemand im Nebenzimmer war",
        "Ich hatte noch nie eine Affäre",
        "Ich hab noch nie jemanden betrogen",
        "Ich hab noch nie erst viel später erfahren, dass ich betrogen wurde",
        "Ich hab noch nie mit jemandem geschlafen, um etwas zu bekommen",
        "Ich hatte noch nie etwas mit jemandem aus dieser Runde",
        "Ich hab noch nie mit jemandem geschlafen und es sofort bereut",
        "Ich hab noch nie gemeinsam mit jemandem einen Porno geschaut",
        "Ich war noch nie ohne Unterwäsche unter Leuten",
        "Ich hab noch nie eine Dating-App aus reiner Langeweile installiert",
        "Ich hab noch nie mit jemandem geschlafen, der viel älter war",
        "Ich hab noch nie einen Korb bekommen, als schon alles klar schien",
        "Ich hab noch nie beim ersten Mal so getan, als wäre es nicht das erste Mal",
        "Ich hatte noch nie Sex im Haus meiner Eltern",
        "Ich hab noch nie jemanden nach einer gemeinsamen Nacht einfach ignoriert",
        "Ich hab noch nie per Nachricht Schluss gemacht",
        "Ich hab mich noch nie heimlich in einen Freund verliebt",
        "Ich hab noch nie jemandem gesagt, ich liebe ihn, ohne es zu meinen",
        "Ich hab noch nie am nächsten Tag den Namen googeln müssen",
        "Ich hab mich noch nie wegen der Nachbarn zusammenreißen müssen",
        "Ich hab noch nie eine Nacht durchgemacht und danach gearbeitet",
        "Ich hab noch nie jemanden angerufen, um über Sex zu reden",
        "Ich bin noch nie beim Fremdgehen fast erwischt worden",
        "Ich hab noch nie mit jemandem geschlafen, den ich vorher gar nicht attraktiv fand",
        "Ich hab noch nie gesagt, es sei das Beste gewesen, obwohl es nicht stimmte",
        "Ich hatte noch nie Sex, von dem niemand erfahren durfte",
        "Ich hab noch nie einen Schwangerschaftstest gekauft",
        "Ich hab noch nie verschwiegen, wie viele es vor jemandem waren"
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
