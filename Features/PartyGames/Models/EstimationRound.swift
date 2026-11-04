//
//  EstimationRound.swift
//  BeerStats
//
//  Schaetzmeister mit Aufschreiben: Jeder tippt seine Zahl geheim ins Handy,
//  am Ende deckt die App auf, wer wie weit daneben lag (Wunsch des Nutzers
//  vom 4. November). Hier steht die Rechnung dazu – Eingabe, Reihenfolge,
//  Auswertung –, ohne Ansicht und deshalb mit Tests.
//
//  Gerechnet wird in ZEHNTELN als ganze Zahl, nicht in Double: 7,2 und 7,4
//  liegen bei 7,3 gleich weit daneben, in Double aber nicht (0,0999… gegen
//  0,1000…05). Am Tisch waere das ein Schluck fuer einen Rundungsfehler.
//

import Foundation

/// Wie geschaetzt wird.
enum EstimationMode: String, CaseIterable {
    /// Alle sagen ihre Zahl laut – die App stellt nur Frage und Antwort.
    case callOut
    /// Jeder tippt geheim ein, die App deckt auf und kennt den Verlierer.
    case writeDown
}

/// Eine abgegebene Schaetzung. `player` ist die Position am Tisch – dieselbe
/// Zaehlung wie `PlayerNames` und die Bilanz des Abends.
struct EstimationGuess: Equatable {
    let player: Int
    /// In Zehnteln: 7,3 ist 73.
    let tenths: Int
}

/// Was am Ende aufgedeckt wird.
struct EstimationVerdict: Equatable {

    enum Place: Equatable {
        /// Am weitesten daneben – trinkt.
        case farthest
        /// Am naechsten dran – verteilt.
        case nearest
        case between
    }

    struct Row: Equatable {
        let player: Int
        let tenths: Int
        /// Abstand zur Antwort, in Zehnteln.
        let distance: Int
        let place: Place
    }

    /// Von ganz daneben bis am naechsten dran – in dieser Reihenfolge wird
    /// aufgedeckt, damit die Spannung bis zum Schluss bleibt. Bei gleichem
    /// Abstand nach Platz am Tisch.
    let rows: [Row]

    var farthest: [Int] { rows.filter { $0.place == .farthest }.map(\.player) }
    var nearest: [Int] { rows.filter { $0.place == .nearest }.map(\.player) }

    /// Liegen alle gleich weit daneben, trinkt keiner und keiner verteilt:
    /// Es gibt niemanden, der schlechter oder besser war.
    var isDraw: Bool { rows.count > 1 && farthest.isEmpty }

    init(answer: Double, guesses: [EstimationGuess]) {
        let antwort = EstimationEntry.tenths(of: answer)
        let abstaende = guesses.map { (guess: $0, distance: abs($0.tenths - antwort)) }
        let weitester = abstaende.map(\.distance).max()
        let naechster = abstaende.map(\.distance).min()
        let alleGleich = weitester == naechster

        rows = abstaende
            .sorted { a, b in
                a.distance != b.distance ? a.distance > b.distance : a.guess.player < b.guess.player
            }
            .map { eintrag in
                let platz: Place
                if alleGleich || guesses.count < 2 {
                    platz = .between
                } else if eintrag.distance == weitester {
                    platz = .farthest
                } else if eintrag.distance == naechster {
                    platz = .nearest
                } else {
                    platz = .between
                }
                return Row(player: eintrag.guess.player, tenths: eintrag.guess.tenths,
                           distance: eintrag.distance, place: platz)
            }
    }
}

enum EstimationRound {

    /// Wer in welcher Reihenfolge das Handy bekommt. Der Anfang wandert mit
    /// jeder Frage weiter – sonst stuende immer dieselbe Person als Erste
    /// mit dem Handy da, waehrend die anderen noch nachdenken duerfen.
    static func order(playerCount: Int, question: Int) -> [Int] {
        guard playerCount > 0 else { return [] }
        let start = question % playerCount
        return (0..<playerCount).map { (start + $0) % playerCount }
    }
}

/// Was gerade in den Ziffernblock getippt ist.
struct EstimationEntry: Equatable {

    /// Mehr Stellen hat keine Antwort im Stapel – und eine Zahl, die nicht
    /// mehr in die Anzeige passt, ist am Tisch ohnehin ein Witz.
    static let maxDigits = 9

    /// Ob es ein Komma gibt. Haengt an der Frage (`EstimationQuestion.
    /// allowsDecimals`): Bei "Wie viele Sitze hat der Bundestag?" waere ein
    /// Komma ein unfairer Vorteil – wer 630,5 sagt, schneidet zwischen zwei
    /// anderen hindurch.
    let allowsDecimals: Bool
    private(set) var integerPart = ""
    /// `nil`: kein Komma getippt. Leer: Komma getippt, noch keine Ziffer.
    private(set) var decimalPart: String?

    init(allowsDecimals: Bool) {
        self.allowsDecimals = allowsDecimals
    }

    var isEmpty: Bool { integerPart.isEmpty && decimalPart == nil }

    /// Die Schaetzung in Zehnteln – `nil`, solange nichts Gueltiges dasteht.
    var tenths: Int? {
        guard !integerPart.isEmpty, let ganz = Int(integerPart) else { return nil }
        let zehntel = decimalPart.flatMap { Int($0) } ?? 0
        return ganz * 10 + zehntel
    }

    /// Fuer die Anzeige: mit Tausenderpunkten, damit 86400 lesbar bleibt.
    var display: String {
        guard !isEmpty else { return "" }
        let ganz = Self.grouped(integerPart.isEmpty ? "0" : integerPart)
        guard let nachkomma = decimalPart else { return ganz }
        return "\(ganz),\(nachkomma)"
    }

    mutating func type(_ digit: Int) {
        guard (0...9).contains(digit) else { return }
        if let nachkomma = decimalPart {
            // Eine Stelle nach dem Komma – genauer ist keine Antwort
            guard nachkomma.isEmpty else { return }
            decimalPart = String(digit)
        } else {
            guard integerPart.count < Self.maxDigits else { return }
            // Keine fuehrenden Nullen: "007" ist 7
            integerPart = integerPart == "0" ? String(digit) : integerPart + String(digit)
        }
    }

    mutating func typeComma() {
        guard allowsDecimals, decimalPart == nil else { return }
        if integerPart.isEmpty { integerPart = "0" }
        decimalPart = ""
    }

    mutating func delete() {
        if let nachkomma = decimalPart {
            decimalPart = nachkomma.isEmpty ? nil : ""
        } else if !integerPart.isEmpty {
            integerPart.removeLast()
        }
    }

    /// Zehntel als Text wie am Tisch: 86.400, 7,3 – ohne ",0".
    static func format(tenths: Int) -> String {
        let ganz = grouped(String(tenths / 10))
        let rest = tenths % 10
        return rest == 0 ? ganz : "\(ganz),\(rest)"
    }

    static func tenths(of value: Double) -> Int {
        Int((value * 10).rounded())
    }

    private static func grouped(_ ziffern: String) -> String {
        var ergebnis = ""
        for (stelle, zeichen) in ziffern.reversed().enumerated() {
            if stelle > 0, stelle % 3 == 0 { ergebnis.append(".") }
            ergebnis.append(zeichen)
        }
        return String(ergebnis.reversed())
    }
}
