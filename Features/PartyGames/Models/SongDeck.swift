//
//  SongDeck.swift
//  BeerStats
//
//  Songs mit ihrem Erscheinungsjahr – der Stapel fuer den Zeitstrahl.
//
//  Hier gilt eine Regel, die fuer keinen anderen Stapel im Projekt gilt:
//  **Der Inhalt muss stimmen.** Eine erfundene Frage bei "Ich hab noch nie"
//  ist eine Frage; ein falsches Jahr hier ist eine falsche Entscheidung,
//  fuer die jemand trinkt, ohne dass es auffaellt. Deshalb stehen hier nur
//  Lieder, deren Jahr bekannt ist – lieber hundertvierzig sichere als
//  dreihundert geschaetzte.
//
//  Zweite Regel: Das Lied muss am Tisch erkannt werden. Ein Song, den
//  niemand kennt, ist keine schwere Aufgabe, sondern eine unloesbare – man
//  raet dann nicht das Jahr, sondern wuerfelt. Deshalb Charthits und keine
//  Albumtiefen.
//
//  Das Jahr ist das der **Veroeffentlichung der Single**. Bei Liedern, bei
//  denen Album und Single oder Original und Remix auseinanderliegen, ist
//  die Auswahl bewusst duenn: Wo zwei Jahreszahlen vertretbar waeren,
//  steht das Lied gar nicht erst im Stapel.
//

import Foundation

struct SongCard: Equatable, Identifiable {
    let title: String
    let artist: String
    let year: Int

    var id: String { "\(artist) – \(title)" }
}

enum SongDeck {

    static var count: Int { all.count }

    static func shuffled() -> [SongCard] { all.shuffled() }

    /// Das frueheste und spaeteste Jahr im Stapel – fuer die Beschriftung
    /// der Raender des Zeitstrahls.
    static var span: ClosedRange<Int> {
        let jahre = all.map(\.year)
        return (jahre.min() ?? 1960)...(jahre.max() ?? 2024)
    }

    static let all: [SongCard] = sixties + seventies + eighties + nineties + twothousands + tens + twenties

    // MARK: - 1960er

    private static let sixties: [SongCard] = [
        SongCard(title: "(I Can't Get No) Satisfaction", artist: "The Rolling Stones", year: 1965),
        SongCard(title: "Hey Jude", artist: "The Beatles", year: 1968),
        SongCard(title: "Respect", artist: "Aretha Franklin", year: 1967),
        SongCard(title: "Born to Be Wild", artist: "Steppenwolf", year: 1968),
        SongCard(title: "Sunshine of Your Love", artist: "Cream", year: 1967),
        SongCard(title: "I Want to Hold Your Hand", artist: "The Beatles", year: 1963),
        SongCard(title: "Good Vibrations", artist: "The Beach Boys", year: 1966),
        SongCard(title: "Space Oddity", artist: "David Bowie", year: 1969)
    ]

    // MARK: - 1970er

    private static let seventies: [SongCard] = [
        SongCard(title: "Imagine", artist: "John Lennon", year: 1971),
        SongCard(title: "Stairway to Heaven", artist: "Led Zeppelin", year: 1971),
        SongCard(title: "Baba O'Riley", artist: "The Who", year: 1971),
        SongCard(title: "Smoke on the Water", artist: "Deep Purple", year: 1972),
        SongCard(title: "Rocket Man", artist: "Elton John", year: 1972),
        SongCard(title: "Superstition", artist: "Stevie Wonder", year: 1972),
        SongCard(title: "Let's Get It On", artist: "Marvin Gaye", year: 1973),
        SongCard(title: "Griechischer Wein", artist: "Udo Jürgens", year: 1974),
        SongCard(title: "Bohemian Rhapsody", artist: "Queen", year: 1975),
        SongCard(title: "Hotel California", artist: "Eagles", year: 1976),
        SongCard(title: "Dancing Queen", artist: "ABBA", year: 1976),
        SongCard(title: "Blitzkrieg Bop", artist: "Ramones", year: 1976),
        SongCard(title: "Anarchy in the U.K.", artist: "Sex Pistols", year: 1976),
        SongCard(title: "Stayin' Alive", artist: "Bee Gees", year: 1977),
        SongCard(title: "I Feel Love", artist: "Donna Summer", year: 1977),
        SongCard(title: "Heroes", artist: "David Bowie", year: 1977),
        SongCard(title: "Y.M.C.A.", artist: "Village People", year: 1978),
        SongCard(title: "Rasputin", artist: "Boney M.", year: 1978),
        SongCard(title: "I Will Survive", artist: "Gloria Gaynor", year: 1978),
        SongCard(title: "Le Freak", artist: "Chic", year: 1978),
        SongCard(title: "Another Brick in the Wall", artist: "Pink Floyd", year: 1979),
        SongCard(title: "Heart of Glass", artist: "Blondie", year: 1979)
    ]

    // MARK: - 1980er

    private static let eighties: [SongCard] = [
        SongCard(title: "Another One Bites the Dust", artist: "Queen", year: 1980),
        SongCard(title: "Back in Black", artist: "AC/DC", year: 1980),
        SongCard(title: "Love Will Tear Us Apart", artist: "Joy Division", year: 1980),
        SongCard(title: "Der Kommissar", artist: "Falco", year: 1981),
        SongCard(title: "Billie Jean", artist: "Michael Jackson", year: 1982),
        SongCard(title: "Africa", artist: "Toto", year: 1982),
        SongCard(title: "Eye of the Tiger", artist: "Survivor", year: 1982),
        SongCard(title: "Da Da Da", artist: "Trio", year: 1982),
        SongCard(title: "99 Luftballons", artist: "Nena", year: 1983),
        SongCard(title: "Sweet Dreams (Are Made of This)", artist: "Eurythmics", year: 1983),
        SongCard(title: "Every Breath You Take", artist: "The Police", year: 1983),
        SongCard(title: "Girls Just Want to Have Fun", artist: "Cyndi Lauper", year: 1983),
        SongCard(title: "Blue Monday", artist: "New Order", year: 1983),
        SongCard(title: "Purple Rain", artist: "Prince", year: 1984),
        SongCard(title: "Last Christmas", artist: "Wham!", year: 1984),
        SongCard(title: "Do They Know It's Christmas?", artist: "Band Aid", year: 1984),
        SongCard(title: "Born in the U.S.A.", artist: "Bruce Springsteen", year: 1984),
        SongCard(title: "Männer", artist: "Herbert Grönemeyer", year: 1984),
        SongCard(title: "You're My Heart, You're My Soul", artist: "Modern Talking", year: 1984),
        SongCard(title: "Take On Me", artist: "a-ha", year: 1985),
        SongCard(title: "Rock Me Amadeus", artist: "Falco", year: 1985),
        SongCard(title: "Money for Nothing", artist: "Dire Straits", year: 1985),
        SongCard(title: "We Are the World", artist: "USA for Africa", year: 1985),
        SongCard(title: "The Final Countdown", artist: "Europe", year: 1986),
        SongCard(title: "Livin' on a Prayer", artist: "Bon Jovi", year: 1986),
        SongCard(title: "Never Gonna Give You Up", artist: "Rick Astley", year: 1987),
        SongCard(title: "Sweet Child o' Mine", artist: "Guns N' Roses", year: 1987),
        SongCard(title: "I Wanna Dance with Somebody", artist: "Whitney Houston", year: 1987),
        SongCard(title: "Smooth Criminal", artist: "Michael Jackson", year: 1988),
        SongCard(title: "Westerland", artist: "Die Ärzte", year: 1988),
        SongCard(title: "Hier kommt Alex", artist: "Die Toten Hosen", year: 1988),
        SongCard(title: "Personal Jesus", artist: "Depeche Mode", year: 1989),
        SongCard(title: "Like a Prayer", artist: "Madonna", year: 1989),
        SongCard(title: "The Look", artist: "Roxette", year: 1989)
    ]

    // MARK: - 1990er

    private static let nineties: [SongCard] = [
        SongCard(title: "Smells Like Teen Spirit", artist: "Nirvana", year: 1991),
        SongCard(title: "Rhythm Is a Dancer", artist: "Snap!", year: 1992),
        SongCard(title: "It's My Life", artist: "Dr. Alban", year: 1992),
        SongCard(title: "All That She Wants", artist: "Ace of Base", year: 1992),
        SongCard(title: "I Will Always Love You", artist: "Whitney Houston", year: 1992),
        SongCard(title: "Creep", artist: "Radiohead", year: 1992),
        SongCard(title: "Die da!?", artist: "Die Fantastischen Vier", year: 1992),
        SongCard(title: "Friday I'm in Love", artist: "The Cure", year: 1992),
        SongCard(title: "What Is Love", artist: "Haddaway", year: 1993),
        SongCard(title: "What's Up?", artist: "4 Non Blondes", year: 1993),
        SongCard(title: "Hyper Hyper", artist: "Scooter", year: 1994),
        SongCard(title: "Wonderwall", artist: "Oasis", year: 1995),
        SongCard(title: "Gangsta's Paradise", artist: "Coolio", year: 1995),
        SongCard(title: "Wannabe", artist: "Spice Girls", year: 1996),
        SongCard(title: "Jein", artist: "Fettes Brot", year: 1996),
        SongCard(title: "Du hast", artist: "Rammstein", year: 1997),
        SongCard(title: "Barbie Girl", artist: "Aqua", year: 1997),
        SongCard(title: "MMMBop", artist: "Hanson", year: 1997),
        SongCard(title: "Angels", artist: "Robbie Williams", year: 1997),
        SongCard(title: "Men in Black", artist: "Will Smith", year: 1997),
        SongCard(title: "Bitter Sweet Symphony", artist: "The Verve", year: 1997),
        SongCard(title: "Tubthumping", artist: "Chumbawamba", year: 1997),
        SongCard(title: "My Heart Will Go On", artist: "Céline Dion", year: 1997),
        SongCard(title: "Everybody (Backstreet's Back)", artist: "Backstreet Boys", year: 1997),
        SongCard(title: "...Baby One More Time", artist: "Britney Spears", year: 1998),
        SongCard(title: "Believe", artist: "Cher", year: 1998),
        SongCard(title: "Blue (Da Ba Dee)", artist: "Eiffel 65", year: 1999),
        SongCard(title: "Mambo No. 5", artist: "Lou Bega", year: 1999),
        SongCard(title: "Californication", artist: "Red Hot Chili Peppers", year: 1999),
        SongCard(title: "My Name Is", artist: "Eminem", year: 1999),
        SongCard(title: "Smooth", artist: "Santana", year: 1999),
        SongCard(title: "No Scrubs", artist: "TLC", year: 1999)
    ]

    // MARK: - 2000er

    private static let twothousands: [SongCard] = [
        SongCard(title: "One More Time", artist: "Daft Punk", year: 2000),
        SongCard(title: "In the End", artist: "Linkin Park", year: 2001),
        SongCard(title: "How You Remind Me", artist: "Nickelback", year: 2001),
        SongCard(title: "Dickes B", artist: "Seeed", year: 2001),
        SongCard(title: "Lose Yourself", artist: "Eminem", year: 2002),
        SongCard(title: "Hot in Herre", artist: "Nelly", year: 2002),
        SongCard(title: "Complicated", artist: "Avril Lavigne", year: 2002),
        SongCard(title: "Hey Ya!", artist: "OutKast", year: 2003),
        SongCard(title: "Crazy in Love", artist: "Beyoncé", year: 2003),
        SongCard(title: "In da Club", artist: "50 Cent", year: 2003),
        SongCard(title: "Mr. Brightside", artist: "The Killers", year: 2004),
        SongCard(title: "Mein Block", artist: "Sido", year: 2004),
        SongCard(title: "Perfekte Welle", artist: "Juli", year: 2004),
        SongCard(title: "Feel Good Inc.", artist: "Gorillaz", year: 2005),
        SongCard(title: "Nur ein Wort", artist: "Wir sind Helden", year: 2005),
        SongCard(title: "Hips Don't Lie", artist: "Shakira", year: 2006),
        SongCard(title: "Rehab", artist: "Amy Winehouse", year: 2006),
        SongCard(title: "Das Beste", artist: "Silbermond", year: 2006),
        SongCard(title: "Umbrella", artist: "Rihanna", year: 2007),
        SongCard(title: "Stronger", artist: "Kanye West", year: 2007),
        SongCard(title: "Low", artist: "Flo Rida", year: 2007),
        SongCard(title: "Poker Face", artist: "Lady Gaga", year: 2008),
        SongCard(title: "Viva la Vida", artist: "Coldplay", year: 2008),
        SongCard(title: "Sex on Fire", artist: "Kings of Leon", year: 2008),
        SongCard(title: "Kids", artist: "MGMT", year: 2008),
        SongCard(title: "I Kissed a Girl", artist: "Katy Perry", year: 2008),
        SongCard(title: "Haus am See", artist: "Peter Fox", year: 2008),
        SongCard(title: "I Gotta Feeling", artist: "The Black Eyed Peas", year: 2009)
    ]

    // MARK: - 2010er

    private static let tens: [SongCard] = [
        SongCard(title: "Rolling in the Deep", artist: "Adele", year: 2010),
        SongCard(title: "Somebody That I Used to Know", artist: "Gotye", year: 2011),
        SongCard(title: "Gangnam Style", artist: "PSY", year: 2012),
        SongCard(title: "Thrift Shop", artist: "Macklemore & Ryan Lewis", year: 2012),
        SongCard(title: "Radioactive", artist: "Imagine Dragons", year: 2012),
        SongCard(title: "Easy", artist: "Cro", year: 2012),
        SongCard(title: "Tage wie diese", artist: "Die Toten Hosen", year: 2012),
        SongCard(title: "Get Lucky", artist: "Daft Punk", year: 2013),
        SongCard(title: "Wake Me Up", artist: "Avicii", year: 2013),
        SongCard(title: "Happy", artist: "Pharrell Williams", year: 2013),
        SongCard(title: "Royals", artist: "Lorde", year: 2013),
        SongCard(title: "Atemlos durch die Nacht", artist: "Helene Fischer", year: 2013),
        SongCard(title: "Uptown Funk", artist: "Mark Ronson feat. Bruno Mars", year: 2014),
        SongCard(title: "Chandelier", artist: "Sia", year: 2014),
        SongCard(title: "Prayer in C", artist: "Lilly Wood & Robin Schulz", year: 2014),
        SongCard(title: "Auf uns", artist: "Andreas Bourani", year: 2014),
        SongCard(title: "Au revoir", artist: "Mark Forster", year: 2014),
        SongCard(title: "Lean On", artist: "Major Lazer", year: 2015),
        SongCard(title: "Sorry", artist: "Justin Bieber", year: 2015),
        SongCard(title: "Hello", artist: "Adele", year: 2015),
        SongCard(title: "See You Again", artist: "Wiz Khalifa", year: 2015),
        SongCard(title: "Lieblingsmensch", artist: "Namika", year: 2015),
        SongCard(title: "One Dance", artist: "Drake", year: 2016),
        SongCard(title: "Barfuß am Klavier", artist: "AnnenMayKantereit", year: 2016),
        SongCard(title: "Shape of You", artist: "Ed Sheeran", year: 2017),
        SongCard(title: "Despacito", artist: "Luis Fonsi", year: 2017),
        SongCard(title: "Havana", artist: "Camila Cabello", year: 2017),
        SongCard(title: "New Rules", artist: "Dua Lipa", year: 2017),
        SongCard(title: "Rockstar", artist: "Post Malone", year: 2017),
        SongCard(title: "Was du Liebe nennst", artist: "Bausa", year: 2017),
        SongCard(title: "Dance Monkey", artist: "Tones and I", year: 2019),
        SongCard(title: "Bad Guy", artist: "Billie Eilish", year: 2019),
        SongCard(title: "Old Town Road", artist: "Lil Nas X", year: 2019),
        SongCard(title: "Blinding Lights", artist: "The Weeknd", year: 2019),
        SongCard(title: "Roller", artist: "Apache 207", year: 2019)
    ]

    // MARK: - 2020er

    private static let twenties: [SongCard] = [
        SongCard(title: "Levitating", artist: "Dua Lipa", year: 2020),
        SongCard(title: "Watermelon Sugar", artist: "Harry Styles", year: 2020),
        SongCard(title: "Heat Waves", artist: "Glass Animals", year: 2020),
        SongCard(title: "Save Your Tears", artist: "The Weeknd", year: 2020),
        SongCard(title: "Drivers License", artist: "Olivia Rodrigo", year: 2021),
        SongCard(title: "Montero (Call Me by Your Name)", artist: "Lil Nas X", year: 2021),
        SongCard(title: "Bauch Beine Po", artist: "Shirin David", year: 2021),
        SongCard(title: "As It Was", artist: "Harry Styles", year: 2022),
        SongCard(title: "Anti-Hero", artist: "Taylor Swift", year: 2022),
        SongCard(title: "Kill Bill", artist: "SZA", year: 2022),
        SongCard(title: "Wildberry Lillet", artist: "Nina Chuba", year: 2022),
        SongCard(title: "Stick Season", artist: "Noah Kahan", year: 2022),
        SongCard(title: "Flowers", artist: "Miley Cyrus", year: 2023),
        SongCard(title: "Komet", artist: "Udo Lindenberg & Apache 207", year: 2023),
        SongCard(title: "What Was I Made For?", artist: "Billie Eilish", year: 2023)
    ]
}
