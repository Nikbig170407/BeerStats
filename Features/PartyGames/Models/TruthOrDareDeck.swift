//
//  TruthOrDareDeck.swift
//  BeerStats
//
//  Karteninhalt fuer "Wahrheit oder Pflicht".
//
//  Die Trinkregel ist hier nicht Beiwerk, sondern das Rueckgrat: Verweigern
//  ist erlaubt und kostet vier Schluecke. Ohne diesen Ausweg endet das
//  Spiel entweder in Ueberrumpelung oder in endlosen Diskussionen – mit ihm
//  hat jeder jederzeit eine Wahl, die nichts erklaeren muss.
//
//  Aufgaben spielen sich alle am Tisch ab. Nichts, wofuer jemand die
//  Wohnung verlassen, etwas kaputt machen oder Fremde einbeziehen muesste.
//

import Foundation

enum TruthOrDareKind: String, CaseIterable, Identifiable {
    case truth
    case dare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .truth: return "Wahrheit"
        case .dare: return "Pflicht"
        }
    }

    var emoji: String {
        switch self {
        case .truth: return "🗣️"
        case .dare: return "🎯"
        }
    }
}

struct TruthOrDareCard: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let kind: TruthOrDareKind
}

enum TruthOrDareDeck {

    /// Was Verweigern kostet. An einer Stelle, damit die Regel in der
    /// Ansicht und im Kartentext nicht auseinanderlaufen kann.
    static let refusal = DrinkAmount.sips(4)

    static func shuffled(_ kind: TruthOrDareKind) -> [TruthOrDareCard] {
        let source = kind == .truth ? truths : dares

        // Eigene Karten landen bei den Pflichten: Wer selbst etwas eintippt,
        // schreibt fast immer eine Aufgabe und keine Frage.
        let eigene = kind == .dare
            ? CustomCards.cards(for: .truthOrDare).map { TruthOrDareCard(text: $0, kind: .dare) }
            : []

        // Erst hier ausformuliert, weil erst hier feststeht, welche Härte
        // gewählt ist. Die Platzhalter tragen die Grundmenge im Namen.
        return (source.map { TruthOrDareCard(text: resolve($0.text), kind: $0.kind) } + eigene)
            .shuffled()
    }

    private static func resolve(_ text: String) -> String {
        text
            .replacingOccurrences(of: "{3}", with: DrinkAmount.sips(3).text)
            .replacingOccurrences(of: "{4}", with: DrinkAmount.sips(4).text)
    }

    static func count(_ kind: TruthOrDareKind) -> Int {
        switch kind {
        case .truth: return truths.count
        case .dare: return dares.count
        }
    }

    // MARK: - Wahrheit

    private static let truths: [TruthOrDareCard] = [
        "Wen in dieser Runde würdest du daten?",
        "Was war dein peinlichster Moment beim Flirten?",
        "Wie viele Leute hast du schon geküsst?",
        "Wann hast du das letzte Mal geweint und warum?",
        "Was ist die größte Lüge, die du deinen Eltern erzählt hast?",
        "Wen hast du zuletzt im Internet hinterhergestalkt?",
        "Was ist dein absoluter Dealbreaker in einer Beziehung?",
        "Was war dein schlimmstes Date?",
        "Was ist das Peinlichste in deinem Suchverlauf?",
        "Hast du jemals jemanden aus dieser Runde attraktiv gefunden?",
        "Was war dein dümmster Moment im Suff?",
        "Welches Gerücht über dich stimmt tatsächlich?",
        "Was würdest du einem Partner niemals erzählen?",
        "Wen aus deinem Umfeld kannst du eigentlich nicht ausstehen?",
        "Was ist dein ungewöhnlichster Turn-on?",
        "Hast du schon mal jemandem hinterhertelefoniert, der nicht rangehen wollte?",
        "Was ist das Teuerste, das du betrunken gekauft hast?",
        "Was ist die längste Zeit, die du nicht geduscht hast?",
        "Welche App auf deinem Handy würdest du niemandem zeigen?",
        "Wen hast du zuletzt geghostet?",
        "Was hast du schon mal geklaut?",
        "Was ist die peinlichste Nachricht, die du je verschickt hast?",
        "Wen aus dieser Runde würdest du bei einer Zombie-Apokalypse zurücklassen?",
        "Was war dein größter Fehltritt in einer Beziehung?",
        "Hast du schon mal so getan, als wärst du betrunkener, als du warst?",
        "Was ist dein peinlichstes Lieblingslied?",
        "Wem hast du zuletzt etwas Wichtiges verschwiegen?",
        "Was war die dümmste Ausrede, die du je benutzt hast?",
        "Wie viele Leute aus dieser Runde hast du schon gegoogelt?",
        "Was würdest du tun, wenn du einen Tag unsichtbar wärst?",
        "Was ist das Schlimmste, das du je über einen Freund gedacht hast?",
        "Hast du schon mal fremde Nachrichten gelesen?",
        "Was ist dein größtes Talent, von dem keiner weiß?",
        "Wen aus dieser Runde würdest du küssen, wenn du müsstest?",
        "Was war dein peinlichster Moment in der Schule?",
        "Was ist das Verrückteste, das du für Geld tun würdest?",
        "Wann hast du zuletzt gelogen und warum?",
        "Was ist deine größte Unsicherheit?",
        "Wen hast du zuletzt heimlich beneidet?",
        "Was war dein schlimmster Kater?",
        "Hast du jemals jemandem den Partner ausgespannt?",
        "Was ist das Peinlichste, das deine Eltern von dir wissen?",
        "Wen aus dieser Runde kennst du eigentlich am schlechtesten?",
        "Was war die schlechteste Entscheidung deines Lebens?",
        "Worauf bist du insgeheim richtig stolz?"
    ].map { TruthOrDareCard(text: $0, kind: .truth) }

    // MARK: - Pflicht

    private static let dares: [TruthOrDareCard] = [
        "Sing der Runde 30 Sekunden lang etwas vor, ohne zu lachen",
        "Zeig der Runde deinen Startbildschirm",
        "Mach 15 Liegestütze",
        "Imitiere jemanden aus der Runde, bis er sich erkennt",
        "Sprich die nächsten drei Runden nur im Flüsterton",
        "Lass deinen rechten Nachbarn dir die Haare machen",
        "Tanz 20 Sekunden lang ohne Musik",
        "Erzähl einen Witz – lacht niemand, trink {3}",
        "Sag jedem in der Runde etwas Nettes",
        "Lass jemanden deinen nächsten Satz vorgeben",
        "Halte 30 Sekunden die Planke",
        "Trink, was die Runde dir mischt – aus dem, was auf dem Tisch steht",
        "Tausche für zwei Runden ein Kleidungsstück mit deinem Nachbarn",
        "Sprich bis zur nächsten Pflicht nur in der dritten Person",
        "Mach das hässlichste Gesicht, das du kannst, und halte es 20 Sekunden",
        "Buchstabiere deinen Namen rückwärts – sonst {3}",
        "Lass deinen linken Nachbarn {3} verteilen",
        "Rede eine Minute lang über ein Thema, das die Runde vorgibt",
        "Setz dich für zwei Runden auf den Boden",
        "Umarme jeden in der Runde",
        "Mach deinem Nachbarn ein Kompliment, das ihm peinlich ist",
        "Lauf einmal um den Tisch wie auf einem Laufsteg",
        "Mach die Bewegungen deines Nachbarn nach, bis er es merkt",
        "Lass die Runde entscheiden, wie du bis zur nächsten Karte angesprochen wirst",
        "Erzähl eine Geschichte, die mit jedem Satz unglaubwürdiger wird",
        "Trink deinen nächsten Schluck ohne Hände",
        "Halte 20 Sekunden lang die Luft an",
        "Sprich bis zur nächsten Karte mit Akzent",
        "Küss die Person rechts von dir auf die Wange – nur wenn beide wollen, sonst {4}",
        "Lass jemanden dir etwas ins Gesicht malen",
        "Sag das Alphabet rückwärts bis zum M",
        "Mach 20 Kniebeugen",
        "Wähle jemanden, der bis zur nächsten Pflicht alles für dich holt",
        "Erzähl von deinem letzten Traum",
        "Lass die Runde deine Playlist bewerten",
        "Iss etwas, das die Runde für dich aussucht",
        "Sprich bis zur nächsten Karte nur in Fragen",
        "Mach ein Geräusch, bis jemand errät, was es sein soll",
        "Zeig der Runde deinen besten Flirtspruch",
        "Lass jemanden dir die Haare durcheinanderbringen",
        "Halte die nächsten zwei Runden die Augen geschlossen",
        "Führe ein 30-Sekunden-Gespräch mit deiner leeren Hand",
        "Lass die Runde raten, was du gerade denkst – und sag die Wahrheit",
        "Wechsle für zwei Runden den Platz mit deinem Gegenüber",
        "Gib jedem in der Runde einen neuen Spitznamen"
    ].map { TruthOrDareCard(text: $0, kind: .dare) }
}
