//
//  SongDeck.swift
//  BeerStats
//
//  Songs mit ihrem Erscheinungsjahr – der Stapel fuer die Hitparade.
//
//  Hier gilt eine Regel, die fuer keinen anderen Stapel im Projekt gilt:
//  **Der Inhalt muss stimmen.** Eine erfundene Frage bei "Ich hab noch nie"
//  ist eine Frage; ein falsches Jahr hier ist eine falsche Entscheidung,
//  fuer die jemand trinkt, ohne dass es auffaellt. Deshalb stehen hier nur
//  Lieder, deren Jahr bekannt ist – lieber weniger sichere als mehr
//  geschaetzte.
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
//  Dritte Regel: Jedes Lied traegt Apples Nummer (`appleId`), damit die App
//  die Hoerprobe abspielen kann. Eingetragen wird sie von
//  `scripts/find_song_ids.py`, nie geraten – eine falsche Nummer spielt ein
//  anderes Lied, und die Runde raet dann das Jahr des falschen.
//

import Foundation

struct SongCard: Equatable, Identifiable {
    let title: String
    let artist: String
    let year: Int
    /// Apples Nummer fuer die Hoerprobe. Null heisst "keine" – im Stapel
    /// verbietet das ein Test; die Vorgabe gibt es nur, damit Tests Karten
    /// bauen koennen, ohne eine Nummer zu erfinden.
    var appleId = 0

    var id: String { "\(artist) – \(title)" }
}

enum SongDeck {

    static var count: Int { all.count }

    static func shuffled() -> [SongCard] { all.shuffled() }

    /// Das frueheste und spaeteste Jahr im Stapel – fuer die Beschriftung
    /// der Raender der Reihe und den Anfang des Zaehlwerks.
    static var span: ClosedRange<Int> {
        let jahre = all.map(\.year)
        return (jahre.min() ?? 1960)...(jahre.max() ?? 2024)
    }

    static let all: [SongCard] = sixties + seventies + eighties + nineties + twothousands + tens + twenties

    // MARK: - 1960er

    private static let sixties: [SongCard] = [
        SongCard(title: "I Want to Hold Your Hand", artist: "The Beatles", year: 1963, appleId: 1468023761),
        SongCard(title: "(I Can't Get No) Satisfaction", artist: "The Rolling Stones", year: 1965, appleId: 1440743544),
        SongCard(title: "Yellow Submarine", artist: "The Beatles", year: 1966),
        SongCard(title: "Respect", artist: "Aretha Franklin", year: 1967, appleId: 266602664),
        SongCard(title: "Hey Jude", artist: "The Beatles", year: 1968, appleId: 1441134371),
        SongCard(title: "Born to Be Wild", artist: "Steppenwolf", year: 1968, appleId: 1440860171),
        SongCard(title: "Space Oddity", artist: "David Bowie", year: 1969, appleId: 1090471540),
        SongCard(title: "Sweet Caroline", artist: "Neil Diamond", year: 1969)
    ]

    // MARK: - 1970er

    private static let seventies: [SongCard] = [
        SongCard(title: "Imagine", artist: "John Lennon", year: 1971, appleId: 721275427),
        SongCard(title: "Stairway to Heaven", artist: "Led Zeppelin", year: 1971, appleId: 902620521),
        SongCard(title: "Smoke on the Water", artist: "Deep Purple", year: 1972, appleId: 1440787908),
        SongCard(title: "Rocket Man", artist: "Elton John", year: 1972, appleId: 1440910931),
        SongCard(title: "Superstition", artist: "Stevie Wonder", year: 1972, appleId: 1440808985),
        SongCard(title: "Griechischer Wein", artist: "Udo Jürgens", year: 1974, appleId: 1721226578),
        SongCard(title: "Waterloo", artist: "ABBA", year: 1974),
        SongCard(title: "Bohemian Rhapsody", artist: "Queen", year: 1975, appleId: 6781027645),
        SongCard(title: "Hotel California", artist: "Eagles", year: 1976, appleId: 635770202),
        SongCard(title: "Dancing Queen", artist: "ABBA", year: 1976, appleId: 1440820267),
        SongCard(title: "Ein Bett im Kornfeld", artist: "Jürgen Drews", year: 1976),
        SongCard(title: "Daddy Cool", artist: "Boney M.", year: 1976),
        SongCard(title: "Stayin' Alive", artist: "Bee Gees", year: 1977, appleId: 1452909755),
        SongCard(title: "Heroes", artist: "David Bowie", year: 1977, appleId: 929304293),
        SongCard(title: "We Will Rock You", artist: "Queen", year: 1977),
        SongCard(title: "Y.M.C.A.", artist: "Village People", year: 1978, appleId: 504994461),
        SongCard(title: "Rasputin", artist: "Boney M.", year: 1978, appleId: 824394483),
        SongCard(title: "I Will Survive", artist: "Gloria Gaynor", year: 1978, appleId: 1475006475),
        SongCard(title: "Another Brick in the Wall", artist: "Pink Floyd", year: 1979, appleId: 1065975638),
        SongCard(title: "Highway to Hell", artist: "AC/DC", year: 1979)
    ]

    // MARK: - 1980er

    private static let eighties: [SongCard] = [
        SongCard(title: "Another One Bites the Dust", artist: "Queen", year: 1980, appleId: 6781027662),
        SongCard(title: "Back in Black", artist: "AC/DC", year: 1980, appleId: 574050602),
        SongCard(title: "Billie Jean", artist: "Michael Jackson", year: 1982, appleId: 269573364),
        SongCard(title: "Africa", artist: "Toto", year: 1982, appleId: 185717604),
        SongCard(title: "Eye of the Tiger", artist: "Survivor", year: 1982, appleId: 254685026),
        SongCard(title: "Da Da Da", artist: "Trio", year: 1982, appleId: 1444111893),
        SongCard(title: "99 Luftballons", artist: "Nena", year: 1983, appleId: 1446014714),
        SongCard(title: "Sweet Dreams (Are Made of This)", artist: "Eurythmics", year: 1983, appleId: 255966421),
        SongCard(title: "Every Breath You Take", artist: "The Police", year: 1983, appleId: 1440805336),
        SongCard(title: "Girls Just Want to Have Fun", artist: "Cyndi Lauper", year: 1983, appleId: 795192833),
        SongCard(title: "Purple Rain", artist: "Prince", year: 1984, appleId: 1229320478),
        SongCard(title: "Last Christmas", artist: "Wham!", year: 1984, appleId: 282658482),
        SongCard(title: "Do They Know It's Christmas?", artist: "Band Aid", year: 1984, appleId: 1445666233),
        SongCard(title: "Born in the U.S.A.", artist: "Bruce Springsteen", year: 1984, appleId: 203708455),
        SongCard(title: "Männer", artist: "Herbert Grönemeyer", year: 1984, appleId: 1440941213),
        SongCard(title: "You're My Heart, You're My Soul", artist: "Modern Talking", year: 1984, appleId: 348891988),
        SongCard(title: "Wake Me Up Before You Go-Go", artist: "Wham!", year: 1984),
        SongCard(title: "Like a Virgin", artist: "Madonna", year: 1984),
        SongCard(title: "Ghostbusters", artist: "Ray Parker Jr.", year: 1984),
        SongCard(title: "Take On Me", artist: "a-ha", year: 1985, appleId: 380907765),
        SongCard(title: "Rock Me Amadeus", artist: "Falco", year: 1985, appleId: 1826810978),
        SongCard(title: "We Are the World", artist: "USA for Africa", year: 1985, appleId: 41737859),
        SongCard(title: "The Final Countdown", artist: "Europe", year: 1986, appleId: 196480329),
        SongCard(title: "Livin' on a Prayer", artist: "Bon Jovi", year: 1986, appleId: 1794889306),
        SongCard(title: "Brother Louie", artist: "Modern Talking", year: 1986),
        SongCard(title: "Never Gonna Give You Up", artist: "Rick Astley", year: 1987, appleId: 1559523359),
        SongCard(title: "Sweet Child o' Mine", artist: "Guns N' Roses", year: 1987, appleId: 1377813701),
        SongCard(title: "I Wanna Dance with Somebody", artist: "Whitney Houston", year: 1987, appleId: 840431935),
        SongCard(title: "Westerland", artist: "Die Ärzte", year: 1988, appleId: 1533955574),
        SongCard(title: "Hier kommt Alex", artist: "Die Toten Hosen", year: 1988, appleId: 1615227445),
        SongCard(title: "Don't Worry, Be Happy", artist: "Bobby McFerrin", year: 1988),
        SongCard(title: "Personal Jesus", artist: "Depeche Mode", year: 1989, appleId: 1332108181),
        SongCard(title: "Like a Prayer", artist: "Madonna", year: 1989, appleId: 1874757282)
    ]

    // MARK: - 1990er

    private static let nineties: [SongCard] = [
        SongCard(title: "Verdammt, ich lieb' dich", artist: "Matthias Reim", year: 1990),
        SongCard(title: "U Can't Touch This", artist: "MC Hammer", year: 1990),
        SongCard(title: "Smells Like Teen Spirit", artist: "Nirvana", year: 1991, appleId: 1586895442),
        SongCard(title: "Losing My Religion", artist: "R.E.M.", year: 1991),
        SongCard(title: "Rhythm Is a Dancer", artist: "Snap!", year: 1992, appleId: 1437353056),
        SongCard(title: "It's My Life", artist: "Dr. Alban", year: 1992, appleId: 1614485758),
        SongCard(title: "All That She Wants", artist: "Ace of Base", year: 1992, appleId: 1682504883),
        SongCard(title: "I Will Always Love You", artist: "Whitney Houston", year: 1992, appleId: 388151901),
        SongCard(title: "Die da!?", artist: "Die Fantastischen Vier", year: 1992, appleId: 948650760),
        SongCard(title: "Friday I'm in Love", artist: "The Cure", year: 1992, appleId: 1440932817),
        SongCard(title: "What Is Love", artist: "Haddaway", year: 1993, appleId: 1731434189),
        SongCard(title: "Mr. Vain", artist: "Culture Beat", year: 1993),
        SongCard(title: "Hyper Hyper", artist: "Scooter", year: 1994, appleId: 1720167502),
        SongCard(title: "Zombie", artist: "The Cranberries", year: 1994),
        SongCard(title: "Wonderwall", artist: "Oasis", year: 1995, appleId: 1517520101),
        SongCard(title: "Gangsta's Paradise", artist: "Coolio", year: 1995, appleId: 1206676136),
        SongCard(title: "Wannabe", artist: "Spice Girls", year: 1996, appleId: 1573849255),
        SongCard(title: "Jein", artist: "Fettes Brot", year: 1996, appleId: 1840884443),
        SongCard(title: "Du hast", artist: "Rammstein", year: 1997, appleId: 1390562691),
        SongCard(title: "Barbie Girl", artist: "Aqua", year: 1997, appleId: 1443758761),
        SongCard(title: "MMMBop", artist: "Hanson", year: 1997, appleId: 1440790544),
        SongCard(title: "Angels", artist: "Robbie Williams", year: 1997, appleId: 727506102),
        SongCard(title: "Men in Black", artist: "Will Smith", year: 1997, appleId: 279366591),
        SongCard(title: "Bitter Sweet Symphony", artist: "The Verve", year: 1997, appleId: 725844999),
        SongCard(title: "Tubthumping", artist: "Chumbawamba", year: 1997, appleId: 713773457),
        SongCard(title: "My Heart Will Go On", artist: "Céline Dion", year: 1997, appleId: 250478333),
        SongCard(title: "Everybody (Backstreet's Back)", artist: "Backstreet Boys", year: 1997, appleId: 533020725),
        SongCard(title: "...Baby One More Time", artist: "Britney Spears", year: 1998, appleId: 273143820),
        SongCard(title: "Believe", artist: "Cher", year: 1998, appleId: 73273491),
        SongCard(title: "Mambo No. 5", artist: "Lou Bega", year: 1999, appleId: 1750462267),
        SongCard(title: "Californication", artist: "Red Hot Chili Peppers", year: 1999, appleId: 948446135),
        SongCard(title: "My Name Is", artist: "Eminem", year: 1999, appleId: 1440836185),
        SongCard(title: "Smooth", artist: "Santana", year: 1999, appleId: 354579303),
        SongCard(title: "Livin' la Vida Loca", artist: "Ricky Martin", year: 1999)
    ]

    // MARK: - 2000er

    private static let twothousands: [SongCard] = [
        SongCard(title: "One More Time", artist: "Daft Punk", year: 2000, appleId: 697195462),
        SongCard(title: "How You Remind Me", artist: "Nickelback", year: 2001, appleId: 1380050282),
        SongCard(title: "Lose Yourself", artist: "Eminem", year: 2002, appleId: 1440903439),
        SongCard(title: "Hot in Herre", artist: "Nelly", year: 2002, appleId: 1440735156),
        SongCard(title: "Complicated", artist: "Avril Lavigne", year: 2002, appleId: 315025823),
        SongCard(title: "Hey Ya!", artist: "OutKast", year: 2003, appleId: 1774799818),
        SongCard(title: "Crazy in Love", artist: "Beyoncé", year: 2003, appleId: 250776858),
        SongCard(title: "In da Club", artist: "50 Cent", year: 2003, appleId: 1440907550),
        SongCard(title: "Seven Nation Army", artist: "The White Stripes", year: 2003),
        SongCard(title: "Perfekte Welle", artist: "Juli", year: 2004, appleId: 1442684499),
        SongCard(title: "Yeah!", artist: "Usher", year: 2004),
        SongCard(title: "Feel Good Inc.", artist: "Gorillaz", year: 2005, appleId: 850583586),
        SongCard(title: "Nur ein Wort", artist: "Wir sind Helden", year: 2005, appleId: 715689465),
        SongCard(title: "Rehab", artist: "Amy Winehouse", year: 2006, appleId: 1440856220),
        SongCard(title: "Das Beste", artist: "Silbermond", year: 2006, appleId: 1105987739),
        SongCard(title: "Crazy", artist: "Gnarls Barkley", year: 2006),
        SongCard(title: "SexyBack", artist: "Justin Timberlake", year: 2006),
        SongCard(title: "Umbrella", artist: "Rihanna", year: 2007, appleId: 1441154437),
        SongCard(title: "Stronger", artist: "Kanye West", year: 2007, appleId: 1442846328),
        SongCard(title: "Low", artist: "Flo Rida", year: 2007, appleId: 275504060),
        SongCard(title: "Vom selben Stern", artist: "Ich + Ich", year: 2007),
        SongCard(title: "Poker Face", artist: "Lady Gaga", year: 2008, appleId: 1443286882),
        SongCard(title: "Viva la Vida", artist: "Coldplay", year: 2008, appleId: 1122773680),
        SongCard(title: "Sex on Fire", artist: "Kings of Leon", year: 2008, appleId: 290303003),
        SongCard(title: "I Kissed a Girl", artist: "Katy Perry", year: 2008, appleId: 716036187),
        SongCard(title: "Haus am See", artist: "Peter Fox", year: 2008, appleId: 312318468),
        SongCard(title: "Single Ladies (Put a Ring on It)", artist: "Beyoncé", year: 2008),
        SongCard(title: "I Gotta Feeling", artist: "The Black Eyed Peas", year: 2009, appleId: 1446016735),
        SongCard(title: "Bad Romance", artist: "Lady Gaga", year: 2009)
    ]

    // MARK: - 2010er

    private static let tens: [SongCard] = [
        SongCard(title: "Rolling in the Deep", artist: "Adele", year: 2010, appleId: 413623677),
        SongCard(title: "Waka Waka (This Time for Africa)", artist: "Shakira", year: 2010),
        SongCard(title: "We No Speak Americano", artist: "Yolanda Be Cool", year: 2010),
        SongCard(title: "Somebody That I Used to Know", artist: "Gotye", year: 2011, appleId: 1442387291),
        SongCard(title: "Party Rock Anthem", artist: "LMFAO", year: 2011),
        SongCard(title: "Gangnam Style", artist: "PSY", year: 2012, appleId: 1452862511),
        SongCard(title: "Radioactive", artist: "Imagine Dragons", year: 2012, appleId: 1440830119),
        SongCard(title: "Tage wie diese", artist: "Die Toten Hosen", year: 2012, appleId: 512313000),
        SongCard(title: "Get Lucky", artist: "Daft Punk", year: 2013, appleId: 1673536443),
        SongCard(title: "Wake Me Up", artist: "Avicii", year: 2013, appleId: 1440872929),
        SongCard(title: "Happy", artist: "Pharrell Williams", year: 2013, appleId: 863835363),
        SongCard(title: "Royals", artist: "Lorde", year: 2013, appleId: 1440818664),
        SongCard(title: "Atemlos durch die Nacht", artist: "Helene Fischer", year: 2013, appleId: 1544490669),
        SongCard(title: "Applaus, Applaus", artist: "Sportfreunde Stiller", year: 2013),
        SongCard(title: "Uptown Funk", artist: "Mark Ronson feat. Bruno Mars", year: 2014, appleId: 1739304006),
        SongCard(title: "Chandelier", artist: "Sia", year: 2014, appleId: 882945383),
        SongCard(title: "Prayer in C", artist: "Lilly Wood & Robin Schulz", year: 2014, appleId: 1465751570),
        SongCard(title: "Auf uns", artist: "Andreas Bourani", year: 2014, appleId: 1440860869),
        SongCard(title: "Au revoir", artist: "Mark Forster", year: 2014, appleId: 936705161),
        SongCard(title: "Lean On", artist: "Major Lazer", year: 2015, appleId: 1330576869),
        SongCard(title: "Sorry", artist: "Justin Bieber", year: 2015, appleId: 1440829610),
        SongCard(title: "Hello", artist: "Adele", year: 2015, appleId: 1051333148),
        SongCard(title: "See You Again", artist: "Wiz Khalifa", year: 2015, appleId: 966411602),
        SongCard(title: "Lieblingsmensch", artist: "Namika", year: 2015, appleId: 1069413346),
        SongCard(title: "Hulapalu", artist: "Andreas Gabalier", year: 2015),
        SongCard(title: "One Dance", artist: "Drake", year: 2016, appleId: 1440841384),
        SongCard(title: "Barfuß am Klavier", artist: "AnnenMayKantereit", year: 2016, appleId: 1440842648),
        SongCard(title: "Can't Stop the Feeling!", artist: "Justin Timberlake", year: 2016),
        SongCard(title: "Shape of You", artist: "Ed Sheeran", year: 2017, appleId: 1193700923),
        SongCard(title: "Despacito", artist: "Luis Fonsi", year: 2017, appleId: 1447401620),
        SongCard(title: "Havana", artist: "Camila Cabello", year: 2017, appleId: 1321217032),
        SongCard(title: "New Rules", artist: "Dua Lipa", year: 2017, appleId: 1528951575),
        SongCard(title: "Rockstar", artist: "Post Malone", year: 2017, appleId: 1373506170),
        SongCard(title: "Was du Liebe nennst", artist: "Bausa", year: 2017, appleId: 1283042763),
        SongCard(title: "Shallow", artist: "Lady Gaga & Bradley Cooper", year: 2018),
        SongCard(title: "Dance Monkey", artist: "Tones and I", year: 2019, appleId: 1475546088),
        SongCard(title: "Bad Guy", artist: "Billie Eilish", year: 2019, appleId: 1450695739),
        SongCard(title: "Blinding Lights", artist: "The Weeknd", year: 2019, appleId: 1499386265),
        SongCard(title: "Señorita", artist: "Shawn Mendes & Camila Cabello", year: 2019)
    ]

    // MARK: - 2020er

    private static let twenties: [SongCard] = [
        SongCard(title: "Levitating", artist: "Dua Lipa", year: 2020, appleId: 1551800727),
        SongCard(title: "Heat Waves", artist: "Glass Animals", year: 2020, appleId: 1508562516),
        SongCard(title: "Save Your Tears", artist: "The Weeknd", year: 2020, appleId: 1499386369),
        SongCard(title: "Drivers License", artist: "Olivia Rodrigo", year: 2021, appleId: 1560735480),
        SongCard(title: "Montero (Call Me by Your Name)", artist: "Lil Nas X", year: 2021, appleId: 1559318719),
        SongCard(title: "Bad Habits", artist: "Ed Sheeran", year: 2021),
        SongCard(title: "As It Was", artist: "Harry Styles", year: 2022, appleId: 1615585008),
        SongCard(title: "Anti-Hero", artist: "Taylor Swift", year: 2022, appleId: 1645937758),
        SongCard(title: "Kill Bill", artist: "SZA", year: 2022, appleId: 1657869393),
        SongCard(title: "Wildberry Lillet", artist: "Nina Chuba", year: 2022, appleId: 1636729980),
        SongCard(title: "Flowers", artist: "Miley Cyrus", year: 2023, appleId: 1702906535),
        SongCard(title: "Komet", artist: "Udo Lindenberg & Apache 207", year: 2023, appleId: 1663920336),
        SongCard(title: "What Was I Made For?", artist: "Billie Eilish", year: 2023, appleId: 1689239800),
        SongCard(title: "Tattoo", artist: "Loreen", year: 2023)
    ]
}
