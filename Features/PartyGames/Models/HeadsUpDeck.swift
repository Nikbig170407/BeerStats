//
//  HeadsUpDeck.swift
//  BeerStats
//
//  Begriffe fuer "Wer bin ich?".
//
//  In Kategorien getrennt, weil die Runde vorher wissen muss, worum es geht.
//  Ohne Kategorie ist jeder Begriff moeglich, und dann beschreiben alle
//  aneinander vorbei – "es ist gross" hilft niemandem, wenn es ein Tier,
//  ein Film oder ein Promi sein koennte.
//
//  Bewusst nichts, was man nur kennt, wenn man dabei war: keine Insider,
//  keine Nischenserien. Wer den Begriff nicht kennt, kann ihn nicht
//  beschreiben, und dann steht die Runde.
//

import Foundation

enum HeadsUpCategory: String, CaseIterable, Identifiable {
    case people
    case screen
    case animals
    case everyday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .people: return "Berühmte Leute"
        case .screen: return "Film & Serie"
        case .animals: return "Tiere"
        case .everyday: return "Alltag"
        }
    }

    var emoji: String {
        switch self {
        case .people: return "🌟"
        case .screen: return "🎬"
        case .animals: return "🐘"
        case .everyday: return "🪑"
        }
    }
}

enum HeadsUpDeck {

    static func shuffled(_ category: HeadsUpCategory) -> [String] {
        terms(category).shuffled()
    }

    static func count(_ category: HeadsUpCategory) -> Int { terms(category).count }

    private static func terms(_ category: HeadsUpCategory) -> [String] {
        switch category {
        case .people: return people
        case .screen: return screen
        case .animals: return animals
        case .everyday: return everyday
        }
    }

    private static let people = [
        "Albert Einstein", "Angela Merkel", "Michael Jackson", "Cristiano Ronaldo", "Lionel Messi",
        "Elon Musk", "Beyoncé", "Mozart", "Beethoven", "Johann Sebastian Bach",
        "Napoleon", "Kleopatra", "Julius Cäsar", "Leonardo da Vinci", "Vincent van Gogh",
        "Marilyn Monroe", "Charlie Chaplin", "Elvis Presley", "Steve Jobs", "Bill Gates",
        "Barack Obama", "Queen Elizabeth", "Lady Gaga", "Taylor Swift", "Ed Sheeran",
        "Rihanna", "Dwayne Johnson", "Leonardo DiCaprio", "Brad Pitt", "Til Schweiger",
        "Dieter Bohlen", "Helene Fischer", "Toni Kroos", "Manuel Neuer", "Usain Bolt",
        "Michael Schumacher", "Muhammad Ali", "Michael Jordan", "Serena Williams", "Roger Federer",
        "Franz Beckenbauer", "Boris Becker", "Dirk Nowitzki", "Jürgen Klopp", "Thomas Müller",
        "Stefan Raab", "Thomas Gottschalk", "Günther Jauch", "Mark Forster", "Nena",
        "Udo Lindenberg", "Herbert Grönemeyer", "Rammstein", "Sido", "Capital Bra",
        "Karl Lagerfeld", "Heidi Klum", "Arnold Schwarzenegger", "Tom Cruise", "Johnny Depp",
        "Angelina Jolie", "Jennifer Lopez", "Madonna", "Freddie Mercury", "John Lennon",
        "Mahatma Gandhi", "Martin Luther King", "Nelson Mandela", "Mutter Teresa", "Marie Curie"
    ]

    private static let screen = [
        "Titanic", "Der Pate", "Star Wars", "Herr der Ringe", "Harry Potter",
        "Jurassic Park", "Der König der Löwen", "Findet Nemo", "Shrek", "Frozen",
        "Breaking Bad", "Game of Thrones", "Stranger Things", "The Office", "Friends",
        "How I Met Your Mother", "Die Simpsons", "SpongeBob", "Tatort", "Der Tatortreiniger",
        "Fluch der Karibik", "Matrix", "Inception", "Avatar", "Joker",
        "Forrest Gump", "Pulp Fiction", "Zurück in die Zukunft", "E.T.", "Rocky",
        "James Bond", "Mission Impossible", "Fast and Furious", "Ice Age", "Minions",
        "Avengers", "Spider-Man", "Batman", "Superman", "Deadpool",
        "Der Grinch", "Kevin allein zu Haus", "Sister Act", "Dirty Dancing", "Grease",
        "Der Zauberer von Oz", "Mary Poppins", "Cinderella", "Die Eiskönigin", "Bambi",
        "Dschungelbuch", "Aladdin", "Toy Story", "Oben", "Alles steht Kopf",
        "Dark", "Haus des Geldes", "Squid Game", "The Walking Dead", "Sherlock",
        "Dr. House", "Scrubs", "Big Bang Theory", "Two and a Half Men", "Türkisch für Anfänger",
        "Stromberg", "Pastewka", "Die Schlümpfe", "Tom und Jerry", "Looney Tunes"
    ]

    private static let animals = [
        "Elefant", "Giraffe", "Pinguin", "Krokodil", "Känguru",
        "Faultier", "Nashorn", "Flusspferd", "Erdmännchen", "Waschbär",
        "Igel", "Fledermaus", "Eichhörnchen", "Fuchs", "Wolf",
        "Adler", "Eule", "Papagei", "Flamingo", "Storch",
        "Hai", "Delfin", "Wal", "Qualle", "Oktopus",
        "Schildkröte", "Chamäleon", "Schlange", "Frosch", "Biene",
        "Ameise", "Spinne", "Schmetterling", "Marienkäfer", "Regenwurm",
        "Löwe", "Tiger", "Leopard", "Gepard", "Bär",
        "Eisbär", "Panda", "Koala", "Affe", "Gorilla",
        "Zebra", "Kamel", "Lama", "Esel", "Pferd",
        "Kuh", "Schwein", "Schaf", "Ziege", "Huhn",
        "Ente", "Gans", "Truthahn", "Taube", "Spatz",
        "Hummer", "Krabbe", "Seestern", "Seepferdchen", "Rochen",
        "Maulwurf", "Hamster", "Meerschweinchen", "Kaninchen", "Ratte"
    ]

    private static let everyday = [
        "Zahnbürste", "Kaffeemaschine", "Waschmaschine", "Staubsauger", "Bügeleisen",
        "Regenschirm", "Sonnenbrille", "Rucksack", "Schlüsselbund", "Geldbeutel",
        "Fernbedienung", "Ladekabel", "Kopfhörer", "Wecker", "Spiegel",
        "Kühlschrank", "Mikrowelle", "Toaster", "Wasserkocher", "Pfanne",
        "Besen", "Leiter", "Hammer", "Schraubenzieher", "Taschenlampe",
        "Fahrrad", "Skateboard", "Kinderwagen", "Einkaufswagen", "Koffer",
        "Bierdeckel", "Flaschenöffner", "Korkenzieher", "Strohhalm", "Kronkorken",
        "Nagelfeile", "Haartrockner", "Rasierer", "Zahnseide", "Pflaster",
        "Bettdecke", "Kopfkissen", "Handtuch", "Duschvorhang", "Klobürste",
        "Mülltonne", "Gießkanne", "Blumentopf", "Rasenmäher", "Gartenschlauch",
        "Türklingel", "Briefkasten", "Fußmatte", "Garderobe", "Bügel",
        "Topflappen", "Käsereibe", "Dosenöffner", "Nudelsieb", "Schneebesen",
        "Eiswürfelform", "Thermoskanne", "Brotkasten", "Kaffeefilter", "Teebeutel",
        "Taschenrechner", "Lineal", "Tacker", "Radiergummi", "Textmarker"
    ]
}
