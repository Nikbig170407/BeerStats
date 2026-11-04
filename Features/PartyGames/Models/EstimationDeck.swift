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

    /// Ob beim Aufschreiben ein Komma getippt werden darf.
    ///
    /// Haengt an der EINHEIT, nicht an der Antwort: Gaebe es das Komma genau
    /// dann, wenn die Antwort eins hat, verriete schon der Ziffernblock,
    /// dass sie keine ganze Zahl ist. Und bei allem, was man zaehlt (Sitze,
    /// Knochen, Laender), waere es ein unfairer Vorteil – wer 630,5 sagt,
    /// schneidet zwischen zwei anderen hindurch.
    var allowsDecimals: Bool {
        EstimationDeck.decimalUnits.contains(unit)
    }
}

enum EstimationDeck {

    static func shuffled() -> [EstimationQuestion] { all.shuffled() }

    /// Masse, die man am Tisch auch mit Komma sagt. Alles andere wird
    /// gezaehlt und hat keins. Jede Antwort mit Nachkommastelle muss eine
    /// dieser Einheiten tragen – sonst liesse sie sich nicht genau treffen
    /// (`EstimationRoundTests`).
    static let decimalUnits: Set<String> = [
        "Meter", "Kilometer", "Zentimeter",
        "Gramm", "Kilogramm", "Liter",
        "Millionen", "Millionen km", "Tausend", "Tausend km", "Tausend km²",
        "Promille", "Grad", "Tage"
    ]

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
        EstimationQuestion(text: "Wie viele Punkte in Flensburg kosten den Führerschein?", answer: 8, unit: "Punkte"),

        // Nachgelegt am 3. November ("mehr Fragen"): nur Antworten, die
        // feststehen und sich nicht jaehrlich aendern
        EstimationQuestion(text: "Wie hoch ist die Zugspitze?", answer: 2962, unit: "Meter"),
        EstimationQuestion(text: "Wie lang ist die Donau?", answer: 2850, unit: "Kilometer"),
        EstimationQuestion(text: "Wie hoch ist das Brandenburger Tor?", answer: 26, unit: "Meter"),
        EstimationQuestion(text: "Wie hoch ist die Freiheitsstatue samt Sockel?", answer: 93, unit: "Meter"),
        EstimationQuestion(text: "Wie hoch ist der Burj Khalifa?", answer: 828, unit: "Meter"),
        EstimationQuestion(text: "Wie viele Stockwerke hat der Burj Khalifa?", answer: 163, unit: ""),
        EstimationQuestion(text: "Wie viele Stufen hat der Eiffelturm bis zur Spitze?", answer: 1665, unit: ""),
        EstimationQuestion(text: "Wie tief ist der Marianengraben an der tiefsten Stelle?", answer: 11, unit: "Kilometer"),
        EstimationQuestion(text: "Wie viele Menschen leben in München?", answer: 1.5, unit: "Millionen"),
        EstimationQuestion(text: "Wie lang ist die Elbe?", answer: 1094, unit: "Kilometer"),
        EstimationQuestion(text: "Wie groß ist Deutschland?", answer: 357, unit: "Tausend km²"),
        EstimationQuestion(text: "Wie hoch ist der Kilimandscharo?", answer: 5895, unit: "Meter"),
        EstimationQuestion(text: "Wie lang ist der Nil?", answer: 6650, unit: "Kilometer"),
        EstimationQuestion(text: "Wie weit ist die Sonne von der Erde entfernt?", answer: 150, unit: "Millionen km"),
        EstimationQuestion(text: "Wie viele Minuten braucht das Licht von der Sonne bis zur Erde?", answer: 8, unit: "Minuten"),
        EstimationQuestion(text: "Wie viele Kilometer schafft das Licht in einer Sekunde?", answer: 300, unit: "Tausend km"),
        EstimationQuestion(text: "Wie viele Monde hat der Mars?", answer: 2, unit: ""),
        EstimationQuestion(text: "Wie viele Tage liegen zwischen zwei Vollmonden?", answer: 29.5, unit: "Tage"),
        EstimationQuestion(text: "Wie lang ist ein Fußballfeld nach FIFA-Standard?", answer: 105, unit: "Meter"),
        EstimationQuestion(text: "Wie hoch hängt ein Tennisnetz in der Mitte?", answer: 91.4, unit: "Zentimeter"),
        EstimationQuestion(text: "Wie lang ist ein olympisches Schwimmbecken?", answer: 50, unit: "Meter"),
        EstimationQuestion(text: "Wie viele Spieler hat eine Rugby-Union-Mannschaft auf dem Feld?", answer: 15, unit: ""),
        EstimationQuestion(text: "Wie viele Pins stehen beim Bowling?", answer: 10, unit: ""),
        EstimationQuestion(text: "Wie viele Kugeln liegen beim Poolbillard zu Beginn auf dem Tisch, die weiße mitgezählt?", answer: 16, unit: ""),
        EstimationQuestion(text: "Wie viele Felder hat die Laufbahn bei Mensch ärgere dich nicht?", answer: 40, unit: ""),
        EstimationQuestion(text: "Wie viele Figuren hat jeder Spieler beim Schach zu Beginn?", answer: 16, unit: ""),
        EstimationQuestion(text: "Wie viele Augen hat ein Spielwürfel zusammengezählt?", answer: 21, unit: ""),
        EstimationQuestion(text: "Wie viele Karten bekommt beim Skat jeder Spieler?", answer: 10, unit: ""),
        EstimationQuestion(text: "Wie viele Sekunden hat eine Stunde?", answer: 3600, unit: ""),
        EstimationQuestion(text: "Wie viele Wochen hat ein Jahr?", answer: 52, unit: ""),
        EstimationQuestion(text: "Wie viele Muskeln hat der Mensch ungefähr?", answer: 650, unit: ""),
        EstimationQuestion(text: "Wie viel Prozent des Körpers eines Erwachsenen sind Wasser?", answer: 60, unit: "Prozent"),
        EstimationQuestion(text: "Wie viele Rippen hat ein Mensch?", answer: 24, unit: ""),
        EstimationQuestion(text: "Wie viele Halswirbel hat eine Giraffe?", answer: 7, unit: ""),
        EstimationQuestion(text: "Wie viele Herzen hat ein Oktopus?", answer: 3, unit: ""),
        EstimationQuestion(text: "Wie viele Monate ist ein Elefant schwanger?", answer: 22, unit: "Monate"),
        EstimationQuestion(text: "Wie viele Zehen hat eine Katze insgesamt?", answer: 18, unit: ""),
        EstimationQuestion(text: "Wie viele Beine hat ein Insekt?", answer: 6, unit: ""),
        EstimationQuestion(text: "Wie alt wurde Goethe?", answer: 82, unit: "Jahre"),
        EstimationQuestion(text: "In welchem Jahr wurde Deutschland wiedervereinigt?", answer: 1990, unit: ""),
        EstimationQuestion(text: "In welchem Jahr sank die Titanic?", answer: 1912, unit: ""),
        EstimationQuestion(text: "In welchem Jahr begann der Erste Weltkrieg?", answer: 1914, unit: ""),
        EstimationQuestion(text: "In welchem Jahr kam der Euro als Bargeld?", answer: 2002, unit: ""),
        EstimationQuestion(text: "In welchem Jahr wurde Facebook gegründet?", answer: 2004, unit: ""),
        EstimationQuestion(text: "In welchem Jahr wurde Google gegründet?", answer: 1998, unit: ""),
        EstimationQuestion(text: "In welchem Jahr wurde YouTube gegründet?", answer: 2005, unit: ""),
        EstimationQuestion(text: "In welchem Jahr kam der erste Harry-Potter-Film ins Kino?", answer: 2001, unit: ""),
        EstimationQuestion(text: "In welchem Jahr war das Sommermärchen, die Fußball-WM in Deutschland?", answer: 2006, unit: ""),
        EstimationQuestion(text: "In welchem Jahr kam der erste Star-Wars-Film ins Kino?", answer: 1977, unit: ""),
        EstimationQuestion(text: "In welchem Jahr erschien das Videospiel Super Mario Bros.?", answer: 1985, unit: ""),
        EstimationQuestion(text: "In welchem Jahr wurde Coca-Cola erfunden?", answer: 1886, unit: ""),
        EstimationQuestion(text: "Wie viele Bundesliga-Tore hat Gerd Müller geschossen?", answer: 365, unit: ""),
        EstimationQuestion(text: "Wie viele Punkte bringt ein Touchdown im American Football?", answer: 6, unit: ""),
        EstimationQuestion(text: "Wie lang ist ein Halbmarathon?", answer: 21.1, unit: "Kilometer"),
        EstimationQuestion(text: "Wie viele Zeichen durfte ein Tweet ursprünglich haben?", answer: 140, unit: ""),
        EstimationQuestion(text: "Wie viele Folgen hat die Serie „Friends“?", answer: 236, unit: ""),
        EstimationQuestion(text: "Wie viele Oscars hat die Herr-der-Ringe-Trilogie zusammen gewonnen?", answer: 17, unit: ""),
        EstimationQuestion(text: "Wie viele Minuten dauert der Film Titanic?", answer: 194, unit: "Minuten"),
        EstimationQuestion(text: "Wie viele Liter passen in eine Maß?", answer: 1, unit: "Liter"),
        EstimationQuestion(text: "Ab wie viel Promille gilt man beim Autofahren als absolut fahruntüchtig?", answer: 1.1, unit: "Promille"),
        EstimationQuestion(text: "Ab wie viel Promille gibt es beim Autofahren ein Bußgeld?", answer: 0.5, unit: "Promille"),
        EstimationQuestion(text: "Wie viele Nullen hat eine Milliarde?", answer: 9, unit: ""),
        EstimationQuestion(text: "Wie viel wiegt ein 1-Euro-Stück?", answer: 7.5, unit: "Gramm"),
        EstimationQuestion(text: "Wie viele verschiedene Euro-Münzen gibt es?", answer: 8, unit: ""),
        EstimationQuestion(text: "Wie viele Ecken hat ein Würfel?", answer: 8, unit: ""),
        EstimationQuestion(text: "Wie viele Spieler hat eine Eishockeymannschaft gleichzeitig auf dem Eis, den Torwart mitgezählt?", answer: 6, unit: ""),
        EstimationQuestion(text: "Wie viele Becher stehen beim Beerpong klassisch auf jeder Seite?", answer: 10, unit: ""),
        EstimationQuestion(text: "Wie viele Saiten hat eine Geige?", answer: 4, unit: ""),
        EstimationQuestion(text: "Wie viele Sinfonien hat Beethoven geschrieben?", answer: 9, unit: ""),
        EstimationQuestion(text: "Wie lang ist der Eurotunnel unter dem Ärmelkanal?", answer: 50, unit: "Kilometer"),
        EstimationQuestion(text: "Wie viele Zeitzonen hat Russland?", answer: 11, unit: ""),
        EstimationQuestion(text: "Wie viele Brücken hat Hamburg ungefähr?", answer: 2500, unit: ""),
        EstimationQuestion(text: "Wie schwer ist eine olympische Hantelstange der Männer?", answer: 20, unit: "Kilogramm"),
    ]
}
