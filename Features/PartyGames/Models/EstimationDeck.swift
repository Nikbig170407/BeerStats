//
//  EstimationDeck.swift
//  BeerStats
//
//  Schaetzfragen mit einer Zahl als Antwort.
//
//  Absichtlich Fragen, die niemand genau weiss, aber jeder eingrenzen kann.
//  Reines Wissen waere ein Quiz – wer es weiss, gewinnt, alle anderen
//  langweilen sich. Beim Schaetzen ist jeder dabei, und der Abstand zur
//  Wahrheit entscheidet statt richtig oder falsch.
//
//  Die Antworten sind gerundet und auf Werte beschraenkt, die sich nicht
//  jaehrlich aendern. Eine Frage, deren Antwort naechstes Jahr falsch ist,
//  waere schlimmer als gar keine.
//

import Foundation

struct EstimationQuestion: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let answer: Double
    let unit: String

    /// Die Zahl ohne unnoetige Nachkommastelle: 206 statt 206,0.
    var numberText: String {
        let rounded = answer.rounded()
        return abs(answer - rounded) < 0.05
            ? String(Int(rounded))
            : String(format: "%.1f", answer).replacingOccurrences(of: ".", with: ",")
    }

    /// Zahl mit Einheit, so wie sie am Tisch vorgelesen wird.
    var answerText: String {
        unit.isEmpty ? numberText : "\(numberText) \(unit)"
    }
}

enum EstimationDeck {

    static func shuffled() -> [EstimationQuestion] { all.shuffled() }

    static var count: Int { all.count }

    static let all: [EstimationQuestion] = [
        EstimationQuestion(text: "Wie viele Knochen hat ein erwachsener Mensch?", answer: 206, unit: ""),
        EstimationQuestion(text: "Wie viele Länder sind in der EU?", answer: 27, unit: ""),
        EstimationQuestion(text: "Wie viele Tasten hat ein Klavier?", answer: 88, unit: ""),
        EstimationQuestion(text: "Wie viele Spieler stehen bei einem Fußballspiel insgesamt auf dem Feld?", answer: 22, unit: ""),
        EstimationQuestion(text: "Wie hoch ist der Eiffelturm?", answer: 330, unit: "Meter"),
        EstimationQuestion(text: "Wie viele Bundesländer hat Deutschland?", answer: 16, unit: ""),
        EstimationQuestion(text: "Wie viele Karten hat ein Skatblatt?", answer: 32, unit: ""),
        EstimationQuestion(text: "Wie viele Karten hat ein französisches Blatt ohne Joker?", answer: 52, unit: ""),
        EstimationQuestion(text: "Wie viele Felder hat ein Schachbrett?", answer: 64, unit: ""),
        EstimationQuestion(text: "Wie viele Sekunden hat ein Tag?", answer: 86400, unit: ""),
        EstimationQuestion(text: "Wie viele Zähne hat ein Erwachsener mit Weisheitszähnen?", answer: 32, unit: ""),
        EstimationQuestion(text: "Wie viele Streifen hat die US-Flagge?", answer: 13, unit: ""),
        EstimationQuestion(text: "Wie viele Sterne hat die EU-Flagge?", answer: 12, unit: ""),
        EstimationQuestion(text: "Wie viele Buchstaben hat das Alphabet ohne Umlaute?", answer: 26, unit: ""),
        EstimationQuestion(text: "Wie viele Tage hat ein Schaltjahr?", answer: 366, unit: ""),
        EstimationQuestion(text: "Wie viele Grad hat ein Kreis?", answer: 360, unit: ""),
        EstimationQuestion(text: "Wie viele Planeten hat unser Sonnensystem?", answer: 8, unit: ""),
        EstimationQuestion(text: "Wie hoch ist der Mount Everest?", answer: 8849, unit: "Meter"),
        EstimationQuestion(text: "Wie viele Menschen leben in Deutschland?", answer: 83, unit: "Millionen"),
        EstimationQuestion(text: "Wie weit ist der Mond im Schnitt von der Erde entfernt?", answer: 384, unit: "Tausend km"),
        EstimationQuestion(text: "Wie viele Saiten hat eine normale Gitarre?", answer: 6, unit: ""),
        EstimationQuestion(text: "Wie viele Basketballspieler stehen pro Team auf dem Feld?", answer: 5, unit: ""),
        EstimationQuestion(text: "Wie lang ist ein Marathon?", answer: 42, unit: "Kilometer"),
        EstimationQuestion(text: "Wie viele Löcher hat eine volle Golfrunde?", answer: 18, unit: ""),
        EstimationQuestion(text: "Bei wie viel Grad kocht Wasser auf Meereshöhe?", answer: 100, unit: "Grad"),
        EstimationQuestion(text: "Wie viele Herzkammern hat ein Mensch?", answer: 4, unit: ""),
        EstimationQuestion(text: "Wie viele Beine hat eine Spinne?", answer: 8, unit: ""),
        EstimationQuestion(text: "Wie viele Vereine spielen in der 1. Bundesliga?", answer: 18, unit: ""),
        EstimationQuestion(text: "Wie viele Spiele hat ein Bundesliga-Team pro Saison?", answer: 34, unit: ""),
        EstimationQuestion(text: "Wie viele Tage hat der Februar in einem normalen Jahr?", answer: 28, unit: ""),
        EstimationQuestion(text: "Wie viele Fußball-Weltmeistertitel hat Deutschland bei den Männern?", answer: 4, unit: ""),
        EstimationQuestion(text: "Wie viele Farben hat ein Regenbogen in der klassischen Zählung?", answer: 7, unit: ""),
        EstimationQuestion(text: "Wie viele Zwerge hat Schneewittchen?", answer: 7, unit: ""),
        EstimationQuestion(text: "Wie viele Harry-Potter-Bücher gibt es?", answer: 7, unit: ""),
        EstimationQuestion(text: "Wie viele Staffeln hat Game of Thrones?", answer: 8, unit: ""),
        EstimationQuestion(text: "Wie viele Oscars hat Titanic gewonnen?", answer: 11, unit: ""),
        EstimationQuestion(text: "In welchem Jahr fiel die Berliner Mauer?", answer: 1989, unit: ""),
        EstimationQuestion(text: "In welchem Jahr wurde das erste iPhone vorgestellt?", answer: 2007, unit: ""),
        EstimationQuestion(text: "Wie viel Prozent Alkohol hat Wodka üblicherweise?", answer: 40, unit: "Prozent"),
        EstimationQuestion(text: "Wie viele Milliliter hat eine normale Bierflasche?", answer: 500, unit: "Milliliter"),
        EstimationQuestion(text: "Wie viele Kalorien hat ein halber Liter Bier ungefähr?", answer: 200, unit: "Kalorien"),
        EstimationQuestion(text: "Wie viel Prozent Alkohol hat normales Pils?", answer: 5, unit: "Prozent"),
        EstimationQuestion(text: "Wie viele Meter hat eine Meile?", answer: 1609, unit: "Meter"),
        EstimationQuestion(text: "Wie viele Zentimeter hat ein Fuß als Maßeinheit?", answer: 30, unit: "Zentimeter"),
        EstimationQuestion(text: "Wie groß ist der Erdumfang am Äquator?", answer: 40, unit: "Tausend km"),
        EstimationQuestion(text: "Wie viele Minuten dauert ein Eishockeyspiel netto?", answer: 60, unit: "Minuten"),
        EstimationQuestion(text: "Wie viele Jahre dauert ein Bachelorstudium normalerweise?", answer: 3, unit: "Jahre"),
        EstimationQuestion(text: "Wie viele Ringe hat das Olympia-Symbol?", answer: 5, unit: ""),
        EstimationQuestion(text: "Wie viele Menschen leben in Berlin?", answer: 3.8, unit: "Millionen"),
        EstimationQuestion(text: "Wie viele Millisekunden hat eine Sekunde?", answer: 1000, unit: ""),
        EstimationQuestion(text: "Wie viele Buchstaben hat das deutsche Alphabet mit Umlauten und ß?", answer: 30, unit: ""),
        EstimationQuestion(text: "Wie viele Spieler stehen beim Volleyball pro Team auf dem Feld?", answer: 6, unit: ""),
        EstimationQuestion(text: "Wie viele Spieler hat eine Handballmannschaft auf dem Feld?", answer: 7, unit: ""),
        EstimationQuestion(text: "Wie viele Zahlenfelder hat eine Dartscheibe?", answer: 20, unit: ""),
        EstimationQuestion(text: "Wie hoch hängt ein Basketballkorb?", answer: 3.05, unit: "Meter"),
        EstimationQuestion(text: "Wie breit ist ein Fußballtor?", answer: 7.3, unit: "Meter"),
        EstimationQuestion(text: "Wie viele Steine hat ein Domino-Spiel?", answer: 28, unit: ""),
        EstimationQuestion(text: "Wie viele Minuten dauert ein NBA-Spiel?", answer: 48, unit: "Minuten"),
        EstimationQuestion(text: "Wie viele Runden hat ein WM-Boxkampf maximal?", answer: 12, unit: "Runden"),
        EstimationQuestion(text: "Wie viele Liter Blut hat ein Erwachsener etwa?", answer: 5, unit: "Liter"),
        EstimationQuestion(text: "Wie oft schlägt ein Herz in Ruhe pro Minute?", answer: 70, unit: "Mal"),
        EstimationQuestion(text: "Wie viele Haare hat ein Mensch auf dem Kopf?", answer: 100, unit: "Tausend"),
        EstimationQuestion(text: "Wie viele Chromosomen hat ein Mensch?", answer: 46, unit: ""),
        EstimationQuestion(text: "Wie viele Milchzähne hat ein Kind?", answer: 20, unit: ""),
        EstimationQuestion(text: "Wie viele Kontinente gibt es?", answer: 7, unit: ""),
        EstimationQuestion(text: "Wie viele Bundesstaaten hat die USA?", answer: 50, unit: ""),
        EstimationQuestion(text: "Wie viele Mitgliedsstaaten hat die UNO?", answer: 193, unit: ""),
        EstimationQuestion(text: "Wie hoch ist der Kölner Dom?", answer: 157, unit: "Meter"),
        EstimationQuestion(text: "Wie hoch ist der Berliner Fernsehturm?", answer: 368, unit: "Meter"),
        EstimationQuestion(text: "Wie lang ist der Rhein?", answer: 1230, unit: "Kilometer"),
        EstimationQuestion(text: "Wie viele Menschen leben in Hamburg?", answer: 1.9, unit: "Millionen"),
        EstimationQuestion(text: "Wie tief ist der Bodensee an der tiefsten Stelle?", answer: 254, unit: "Meter"),
        EstimationQuestion(text: "In welchem Jahr landete der erste Mensch auf dem Mond?", answer: 1969, unit: ""),
        EstimationQuestion(text: "In welchem Jahr wurde die Bundesrepublik gegründet?", answer: 1949, unit: ""),
        EstimationQuestion(text: "Wie viele Milliliter hat ein Schnapsglas?", answer: 20, unit: "Milliliter"),
        EstimationQuestion(text: "Wie viele Flaschen hat ein Bierkasten?", answer: 20, unit: "Flaschen"),
        EstimationQuestion(text: "Wie viel Prozent Alkohol hat Jägermeister?", answer: 35, unit: "Prozent"),
        EstimationQuestion(text: "Wie viele Gramm hat eine Tafel Schokolade?", answer: 100, unit: "Gramm"),
        EstimationQuestion(text: "Wie viele Stunden hat eine Woche?", answer: 168, unit: "Stunden"),
        EstimationQuestion(text: "Wie viele Punkte in Flensburg kosten den Führerschein?", answer: 8, unit: "Punkte")
    ]
}
