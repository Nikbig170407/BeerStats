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
//  Seit dem 28. Oktober gibt es Kategorien in zwei Richtungen. Der Nutzer:
//  "wir brauchen mehr Kategorien. Noch härter und auch noch welche, die in
//  andere Richtungen gehen." Die Haerte geht jetzt eine Stufe weiter
//  (Tabulos), und daneben stehen Themen, die nicht haerter sind, sondern
//  anders – peinlich, Party, verboten, Tiefgang, Abenteuer. Gemischt wird
//  alles, was gewaehlt ist; die Gruppen sind nur fuer den Vorspann da.
//  Die Themen stehen in `NeverHaveIEverThemes.swift`.
//

import Foundation

/// Kategorie einer Frage: eine Haertestufe oder ein Thema. Strafen tauchen
/// hier bewusst nicht auf – sie sind keine Frage und werden nicht gewaehlt,
/// sondern eingestreut.
enum NeverHaveIEverCategory: String, CaseIterable, Identifiable, Codable {
    // Wie hart
    case kids
    case spicy
    case extreme
    case taboo
    // Worum es geht
    case awkward
    case party
    case forbidden
    case deep
    case adventure

    /// Die beiden Richtungen, in die eine Kategorie gehen kann.
    enum Direction: CaseIterable {
        /// Von harmlos bis tabulos – jede Stufe haerter als die davor.
        case intensity
        /// Nicht haerter, sondern anders.
        case theme

        var title: String {
            switch self {
            case .intensity: return "Wie hart?"
            case .theme: return "Worum geht's?"
            }
        }
    }

    var id: String { rawValue }

    var direction: Direction {
        switch self {
        case .kids, .spicy, .extreme, .taboo: return .intensity
        case .awkward, .party, .forbidden, .deep, .adventure: return .theme
        }
    }

    var title: String {
        switch self {
        case .kids: return "Kinder"
        case .spicy: return "Spicy"
        case .extreme: return "Extrem"
        case .taboo: return "Tabulos"
        case .awkward: return "Peinlich"
        case .party: return "Party"
        case .forbidden: return "Verboten"
        case .deep: return "Tiefgang"
        case .adventure: return "Abenteuer"
        }
    }

    var subtitle: String {
        switch self {
        case .kids: return "Jugendfrei, geht mit jedem"
        case .spicy: return "Für später am Abend"
        case .extreme: return "Nur mit Leuten, die sich gut kennen"
        case .taboo: return "Noch härter – nur, wenn wirklich alle wollen"
        case .awkward: return "Momente, über die man heute lacht"
        case .party: return "Was nachts um drei passiert"
        case .forbidden: return "Kleine und größere Regelbrüche"
        case .deep: return "Ehrlich statt anzüglich – über Gefühle"
        case .adventure: return "Reisen, Mutproben, draußen"
        }
    }

    var emoji: String {
        switch self {
        case .kids: return "🧒"
        case .spicy: return "🔥"
        case .extreme: return "😈"
        case .taboo: return "🔞"
        case .awkward: return "😳"
        case .party: return "🍾"
        case .forbidden: return "🚨"
        case .deep: return "💭"
        case .adventure: return "🧭"
        }
    }
}

struct NeverHaveIEverCard: Identifiable, Equatable {

    enum Kind: Equatable {
        case statement(NeverHaveIEverCategory)
        case penalty
        /// Selbst eingetippt. Bewusst ein eigener Fall statt einer erfundenen
        /// Kategorie: `category` bleibt damit `nil`, und die Ansicht zeigt
        /// dann "Eigene Karte". Eine zugewiesene Kategorie wuerde dagegen
        /// behaupten, die Karte sei zahm oder extrem – eine Einordnung, die
        /// niemand getroffen hat.
        case custom
    }

    let id = UUID()
    let text: String
    let kind: Kind

    var isPenalty: Bool {
        if case .penalty = kind { return true }
        return false
    }

    var category: NeverHaveIEverCategory? {
        if case .statement(let category) = kind { return category }
        return nil
    }
}

enum NeverHaveIEverDeck {

    /// Anteil der Strafen am fertigen Stapel: rund 20 von 100 Karten.
    private static let penaltyShare = 0.2

    static let statements: [NeverHaveIEverCard] = Array([
        kids, spicy, extreme, taboo,
        awkward, party, forbidden, deep, adventure
    ].joined())

    /// Baut den Stapel fuer eine Runde: Fragen der gewaehlten Kategorien,
    /// gemischt, mit eingestreuten Strafen.
    ///
    /// `played` sind Fragen, die in dieser Runde schon dran waren. Wer
    /// mitten im Spiel umstellt, bekommt sie nicht noch einmal – sie fallen
    /// heraus, BEVOR die Strafen verteilt werden, sonst laegen dort, wo eine
    /// Frage fehlt, zwei Strafen hintereinander.
    static func shuffled(
        categories: Set<NeverHaveIEverCategory>,
        includePenalties: Bool,
        excluding played: Set<String> = []
    ) -> [NeverHaveIEverCard] {

        // Eigene Karten kommen ohne Stufe dazu und gelten deshalb in jeder
        // Auswahl. Wer sie eintippt, hat sich fuer seine Runde schon
        // entschieden - eine Einordnung in eine der Kategorien waere eine
        // Frage, die niemand beantworten will.
        let eigene = CustomCards.cards(for: .neverHaveIEver)
            .map { NeverHaveIEverCard(text: $0, kind: .custom) }

        // Weggedaumte Aussagen fallen raus. Der Text der Aussagen ist roh,
        // also stabil – anders als bei den Strafen, die ihre Menge erst beim
        // Anzeigen bekommen. Strafen lassen sich deshalb nicht ausblenden,
        // was auch niemand braucht: "Trink einen Shot" ist keine Karte, die
        // am Tisch nervt.
        let versteckt = HiddenCards.keys(for: .neverHaveIEver)

        let questions = (statements
            .filter { card in card.category.map { categories.contains($0) } ?? false } + eigene)
            .filter { !versteckt.contains($0.text) && !played.contains($0.text) }
            .shuffled()

        guard includePenalties, !penaltyTemplates.isEmpty, questions.count > 2 else { return questions }

        // Die Strafen werden erst hier ausformuliert, weil erst hier
        // feststeht, welche Härte gewählt ist. Wer sie mitten im Stapel
        // umstellt, ändert damit bewusst nur die nächste Runde.
        let penalties = penaltyCards()

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

    static func questionCount(for category: NeverHaveIEverCategory) -> Int {
        statements.filter { $0.category == category }.count
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
        "Ich hab noch nie etwas weggeworfen, das ich später vermisst habe",
        "Ich hab noch nie ein Paket für einen Nachbarn angenommen und vergessen, es abzugeben",
        "Ich bin noch nie in die falsche Bahn gestiegen und erst spät aufgefallen",
        "Ich hab noch nie Pfand gesammelt und nie eingelöst",
        "Ich hab noch nie eine Pflanze vertrocknen lassen",
        "Ich hab noch nie den Wecker gestellt und wieder ausgemacht, ohne aufzuwachen",
        "Ich hab noch nie eine Serie weitergeschaut, obwohl ich sie langweilig fand",
        "Ich hab noch nie etwas gekocht und am Ende bestellt",
        "Ich bin noch nie gegen eine Glastür gelaufen",
        "Ich hab noch nie meinen eigenen Namen falsch geschrieben",
        "Ich hab noch nie beim Einkaufen etwas vergessen, obwohl es auf dem Zettel stand",
        "Ich hab noch nie einem Kind beim Spielen absichtlich verloren",
        "Ich hab noch nie mit Absicht die langsamere Kasse gewählt, weil sie leerer aussah",
        "Ich hab noch nie ein Buch nach dreißig Seiten aufgegeben",
        "Ich hab noch nie laut im Auto gesungen und gemerkt, dass jemand zusieht",
        "Ich hab noch nie eine Mahnung bekommen, weil ich es vergessen hatte",
        "Ich hab noch nie etwas gegessen, das abgelaufen war, und nichts gesagt",
        "Ich war noch nie bei einem Termin eine Stunde zu früh",
        "Ich hab noch nie den Hausschlüssel innen stecken lassen",
        "Ich hab noch nie jemandem zugewinkt, der jemand anderen meinte",
        "Ich hab noch nie meinen Einkaufswagen im Parkhaus stehen gelassen",
        "Ich hab noch nie eine Anleitung ignoriert und alles zweimal gebaut",
        "Ich hab noch nie ein Lied falsch mitgesungen, jahrelang",
        "Ich hab noch nie eine Treppe hochgezählt und mich verzählt",
        "Ich hab noch nie den Müll rausgebracht und die Tüte im Flur vergessen",
        "Ich hab noch nie einen Zug genommen, ohne zu wissen, wohin er fährt"
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
        "Ich hab noch nie jemanden geküsst, obwohl ich vergeben war",
        "Ich hab noch nie eine Verabredung abgesagt und bin dann woanders hingegangen",
        "Ich hab noch nie heimlich die Nachrichten von jemandem gelesen",
        "Ich hab noch nie ein Date nur wegen des Essens zugesagt",
        "Ich hab noch nie jemandem gesagt, ich sei auf dem Weg, obwohl ich noch im Bett lag",
        "Ich hab noch nie den Namen von jemandem vergessen, mit dem ich schon ausgegangen war",
        "Ich hab noch nie jemanden eifersüchtig gemacht, weil ich es wollte",
        "Ich hab noch nie ein Gerücht über mich selbst in Umlauf gebracht",
        "Ich hab noch nie betrunken etwas verschickt, das ich morgens gelöscht habe",
        "Ich hab noch nie einem Freund gesagt, dass sein Partner in Ordnung ist, obwohl ich das nicht fand",
        "Ich hab noch nie eine Einladung abgelehnt und behauptet, ich sei krank",
        "Ich hab noch nie beim ersten Treffen mehr über mich erzählt, als ich wollte",
        "Ich hab noch nie jemanden nach einer Nacht nicht mehr geschrieben",
        "Ich hab noch nie eine Beziehung länger geführt, als ich es wollte",
        "Ich hab noch nie etwas aus dem Bad eines anderen mitgenommen",
        "Ich hab noch nie heimlich das Profil eines Ex angesehen",
        "Ich hab noch nie jemanden geküsst, dessen Nachnamen ich nicht kannte",
        "Ich hab noch nie auf einer Feier den Raum gewechselt, um jemandem auszuweichen",
        "Ich hab noch nie geflunkert, wie viel ich getrunken habe",
        "Ich hab noch nie jemanden belogen, um ein Kompliment zu bekommen",
        "Ich hab noch nie etwas Peinliches über einen Freund erzählt, um besser dazustehen",
        "Ich hab noch nie am Morgen danach den Weg nach Hause nicht gewusst",
        "Ich hab noch nie ein Geschenk weiterverschenkt",
        "Ich hab noch nie jemandem geschrieben, dessen Nummer ich gar nicht haben sollte",
        "Ich hab noch nie in einer fremden Wohnung übernachtet, ohne zu wissen, wem sie gehört",
        "Ich hab noch nie einen Streit angefangen, nur weil ich schlechte Laune hatte"
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
        "Ich hab noch nie verschwiegen, wie viele es vor jemandem waren",
        "Ich hab noch nie etwas getan, das ich niemandem in dieser Runde erzählen würde",
        "Ich hab noch nie jemanden aus Rache verletzt",
        "Ich hab noch nie Geld genommen, das mir nicht gehörte",
        "Ich hab noch nie etwas gestohlen, das mehr als ein Getränk wert war",
        "Ich bin noch nie gefahren, obwohl ich es nicht mehr hätte tun dürfen",
        "Ich hab noch nie jemanden im Stich gelassen, als es wirklich darauf ankam",
        "Ich hab noch nie etwas unterschrieben, ohne es zu lesen, und es später bereut",
        "Ich hab noch nie eine Freundschaft beendet, ohne es zu erklären",
        "Ich hab noch nie jemandem gegenüber behauptet, über etwas hinweg zu sein",
        "Ich hab noch nie einen Menschen vermisst, von dem niemand weiß",
        "Ich hab noch nie etwas geglaubt, was ich mir selbst eingeredet habe",
        "Ich hab noch nie jemanden mit Absicht vor anderen blamiert",
        "Ich hab noch nie eine Grenze überschritten, die mir jemand gesetzt hat",
        "Ich hab noch nie heimlich geweint und am Telefon behauptet, alles sei gut",
        "Ich hab noch nie etwas getan, nur weil alle anderen zusahen",
        "Ich hab noch nie jemanden geküsst, der mit jemandem aus dieser Runde zu tun hatte",
        "Ich hab noch nie etwas über jemanden gesagt, das ihn Freundschaften gekostet hat",
        "Ich hab noch nie eine ganze Nacht durchgemacht und am nächsten Tag gelogen",
        "Ich hab noch nie Sex an einem Ort gehabt, an dem es verboten war",
        "Ich hab noch nie die Wahrheit gesagt, nur um jemandem wehzutun",
        "Ich hab noch nie jemandem versprochen, zurückzukommen, und es nicht vorgehabt",
        "Ich hab noch nie etwas getan, was meine Eltern nie erfahren dürfen",
        "Ich hab noch nie jemanden benutzt, um über jemand anderen hinwegzukommen",
        "Ich hab noch nie eine Nacht verbracht, an die ich mich gar nicht erinnere",
        "Ich hab noch nie etwas in diesem Spiel falsch beantwortet, um nicht trinken zu müssen"
    ].map { NeverHaveIEverCard(text: $0, kind: .statement(.extreme)) }

    // MARK: - Tabulos

    /// Eine Stufe ueber Extrem, auf Wunsch vom 28. Oktober: "Noch härter."
    /// Haerter heisst hier deutlicher und persoenlicher, nicht derber –
    /// und nie auf Kosten von jemandem, der nicht gefragt wurde.
    private static let taboo: [NeverHaveIEverCard] = [
        "Ich war noch nie in einem Swingerclub",
        "Ich hab noch nie ein Sexvideo von mir gedreht",
        "Ich war noch nie bei einer Orgie dabei",
        "Ich hab noch nie Fesselspiele ausprobiert",
        "Ich hab noch nie ein Rollenspiel im Bett gespielt",
        "Ich hatte noch nie Sex am Arbeitsplatz",
        "Ich hatte noch nie etwas mit meinem Chef",
        "Ich hatte noch nie Sex in einer Umkleidekabine",
        "Ich hatte noch nie Sex in einem Zelt auf einem Festival",
        "Ich hatte noch nie Sex am Strand",
        "Ich hatte noch nie Sex in einem Flugzeug",
        "Ich bin noch nie von meinen Eltern beim Sex erwischt worden",
        "Ich hab noch nie jemanden beim Sex erwischt",
        "Ich hab noch nie Telefonsex gehabt",
        "Ich hab mich noch nie nur für Sex verabredet",
        "Ich hab noch nie für Sex bezahlt",
        "Ich hab noch nie Geld für Nacktbilder bekommen",
        "Ich hab noch nie für Erotikinhalte im Internet bezahlt",
        "Ich hab noch nie während des Sex telefoniert",
        "Ich hatte noch nie Sex, während im Fernsehen Fußball lief",
        "Ich hab noch nie eine Pille danach gebraucht",
        "Ich hatte noch nie eine Geschlechtskrankheit",
        "Ich hab noch nie jemanden aus dieser Runde nackt gesehen",
        "Ich hab noch nie von jemandem aus dieser Runde geträumt, und zwar nicht jugendfrei",
        "Ich hab noch nie beim Sex an jemanden aus dieser Runde gedacht",
        "Ich hab noch nie den Partner eines Freundes geküsst",
        "Ich hab noch nie jemanden betrogen und es bis heute nicht gestanden",
        "Ich hab noch nie Schluss gemacht, weil der Sex schlecht war",
        "Ich hab noch nie jemanden nur wegen seines Körpers gedatet",
        "Ich hab noch nie in einer offenen Beziehung gelebt",
        "Ich hatte noch nie zwei Beziehungen gleichzeitig",
        "Ich hatte noch nie etwas mit dem Bruder oder der Schwester eines Ex",
        "Ich hab noch nie Pornos auf einem fremden Gerät geschaut",
        "Ich war noch nie in einem Stripclub",
        "Ich hab noch nie für jemanden gestrippt",
        "Ich hab noch nie einen Lapdance bekommen",
        "Ich hatte noch nie Sex, bei dem etwas kaputtgegangen ist",
        "Ich hab mich noch nie beim Sex verletzt",
        "Ich war noch nie an einem FKK-Strand",
        "Ich hab noch nie nackt die Tür aufgemacht",
        "Ich hab noch nie einem Freund den Partner ausgespannt",
        "Ich hab noch nie eine Beziehung mit einer Lüge angefangen",
        "Ich hab noch nie ein Sexspielzeug mit auf Reisen genommen",
        "Ich hab noch nie mitten in der Nacht jemandem geschrieben, nur um Sex zu bekommen",
        "Ich hatte noch nie Sex mit jemandem, den ich auf einer Hochzeit kennengelernt hab",
        "Ich musste noch nie in fremder Unterwäsche nach Hause gehen",
        "Ich hab noch nie mit jemandem geschlafen, um es einem anderen heimzuzahlen",
        "Ich hab noch nie einem Fremden Nacktbilder geschickt",
        "Ich hab noch nie in einer Nacht mit mehr als zwei Leuten rumgemacht",
        "Ich hatte noch nie Sex, der so laut war, dass sich jemand beschwert hat"
    ].map { NeverHaveIEverCard(text: $0, kind: .statement(.taboo)) }

    // MARK: - Strafen

    /// Eine Strafe als Vorlage: Der Text traegt eine Luecke, die Menge wird
    /// erst beim Mischen in der gewaehlten Haerte eingesetzt.
    ///
    /// Ohne diese Trennung braeuchte jede Strafe drei Fassungen, und die
    /// drei liefen mit der Zeit auseinander.
    private struct PenaltyTemplate {
        let format: String
        var amount: DrinkAmount?

        var resolved: String {
            guard let amount else { return format }
            return format.replacingOccurrences(of: "{}", with: amount.text)
        }
    }

    private static func penaltyCards() -> [NeverHaveIEverCard] {
        penaltyTemplates.map { NeverHaveIEverCard(text: $0.resolved, kind: .penalty) }
    }

    private static let penaltyTemplates: [PenaltyTemplate] = [
        PenaltyTemplate(format: "Trink {}", amount: .shot),
        PenaltyTemplate(format: "Trink {}", amount: .sips(5)),
        PenaltyTemplate(format: "Trink {}", amount: .sips(3)),
        PenaltyTemplate(format: "Trink {}", amount: .sips(6)),
        PenaltyTemplate(format: "Verteile {}", amount: .sips(5)),
        PenaltyTemplate(format: "Verteile {} an eine Person", amount: .sips(3)),
        PenaltyTemplate(format: "Alle trinken {}", amount: .sips(2)),
        PenaltyTemplate(format: "Alle trinken {}", amount: .shot),
        PenaltyTemplate(format: "Bestimme jemanden, der {} trinkt", amount: .shot),
        PenaltyTemplate(format: "Dein linker Nachbar trinkt {}", amount: .sips(3)),
        PenaltyTemplate(format: "Dein rechter Nachbar trinkt {}", amount: .shot),
        PenaltyTemplate(format: "Trink {} mit deinem linken Nachbarn", amount: .shot),
        PenaltyTemplate(format: "Trink {} und verteile genauso viele", amount: .sips(4)),
        PenaltyTemplate(format: "Der Jüngste in der Runde trinkt {}", amount: .sips(3)),
        PenaltyTemplate(format: "Der Älteste in der Runde trinkt {}", amount: .sips(3)),
        PenaltyTemplate(format: "Wer zuletzt gelacht hat, trinkt {}", amount: .sips(2)),
        PenaltyTemplate(format: "Wer als Letztes die Hand hebt, trinkt {}", amount: .shot),
        PenaltyTemplate(format: "Wer als Erstes lacht, trinkt {}", amount: .shot),
        PenaltyTemplate(format: "Wer heute am weitesten angereist ist, trinkt {}", amount: .sips(3)),
        PenaltyTemplate(format: "Der Gastgeber trinkt {}", amount: .sips(2)),
        PenaltyTemplate(format: "Alle, die gerade stehen, trinken {}", amount: .sips(3)),
        PenaltyTemplate(format: "Alle Singles trinken {}", amount: .sips(3)),
        PenaltyTemplate(format: "Alle Vergebenen trinken {}", amount: .sips(3)),
        PenaltyTemplate(format: "Wer zuletzt auf Toilette war, trinkt {}", amount: .sips(4)),
        PenaltyTemplate(format: "Wer vorliest, trinkt {}", amount: .sips(3)),
        PenaltyTemplate(format: "Wer gerade am lautesten ist, trinkt {}", amount: .sips(3)),
        PenaltyTemplate(format: "Wer das älteste Handy hat, trinkt {}", amount: .sips(3)),
        // Ohne Lücke: Die Menge steht hier nicht fest, sondern ergibt sich
        // aus der Runde selbst.
        PenaltyTemplate(format: "Trink so viele Schlücke, wie du Geschwister hast"),
        PenaltyTemplate(format: "Trink so viele Schlücke, wie du heute Kaffee getrunken hast"),
        PenaltyTemplate(format: "Reihum ein Schluck, bis jemand lacht"),
        PenaltyTemplate(format: "Dein Gegenüber trinkt {}", amount: .sips(4)),
        PenaltyTemplate(format: "Die beiden neben dir trinken {}", amount: .sips(2)),
        PenaltyTemplate(format: "Wer zuerst spricht, trinkt {}", amount: .shot),
        PenaltyTemplate(format: "Wer als Letztes gekommen ist, trinkt {}", amount: .sips(4)),
        PenaltyTemplate(format: "Wer am nächsten am Fenster sitzt, trinkt {}", amount: .sips(3)),
        PenaltyTemplate(format: "Wer die hellste Kleidung trägt, trinkt {}", amount: .sips(3)),
        PenaltyTemplate(format: "Wer zuletzt etwas gegessen hat, trinkt {}", amount: .sips(3)),
        PenaltyTemplate(format: "Alle, die ein Handy in der Hand haben, trinken {}", amount: .sips(4)),
        PenaltyTemplate(format: "Alle außer dir trinken {}", amount: .sips(2)),
        PenaltyTemplate(format: "Trink {} und bestimme, wer als Nächstes vorliest", amount: .sips(3)),
        PenaltyTemplate(format: "Stoß mit allen an und trink {}", amount: .sips(3)),
        PenaltyTemplate(format: "Du und die Person mit dem längsten Namen trinken {}", amount: .sips(3)),
        // Wieder ohne Luecke: Die Menge kommt aus der Runde.
        PenaltyTemplate(format: "Trink so viele Schlücke, wie du Buchstaben im Vornamen hast"),
        PenaltyTemplate(format: "Trink so viele Schlücke, wie heute Leute am Tisch sitzen"),
        PenaltyTemplate(format: "Reihum ein Schluck, bis jemand sein Glas abstellt")
    ]
}
