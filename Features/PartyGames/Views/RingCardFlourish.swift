//
//  RingCardFlourish.swift
//  BeerStats
//
//  Die Szene hinter der gezogenen Karte – für jeden Rang eine andere.
//
//  Dreizehn Karten sahen beim Aufdecken gleich aus: dieselbe Karte, derselbe
//  Aufbau, nur ein anderer Text. Am Tisch heisst das, dass die Runde den
//  Text lesen muss, um zu wissen, was los ist. Eine Bewegung, die zur Karte
//  gehoert, sagt es schon vorher – und sie sagt es ueber den Tisch hinweg,
//  wo niemand mitliest.
//
//  Zweimal ist das schon gescheitert, beide Male an derselben Stelle: Bis
//  zum 25. Oktober war es EINE Flugbahn mit dreizehn Emoji, danach dreizehn
//  Schichtungen aus denselben vier Bausteinen – wieder mit dreizehn Emoji.
//  Der Nutzer am 27. Oktober: "Die sehen alle gleich aus, nur mit anderen
//  Emojis." Ein anderes Zeichen auf derselben Bahn ist keine andere Szene.
//
//  Seitdem hat jeder Rang eine eigene, gezeichnete BEWEGUNG
//  (`DrawnScenes.swift`). Die Pruefung ist ein Satz je Rang, der ohne Emoji
//  auskommt – und kein Satz darf zweimal vorkommen. Die Saetze stehen in
//  `RingScene.motion` und nicht in diesem Kommentar: Dort haelt ein Test
//  fest, dass kein Rang seine Bewegung mit einem anderen teilt
//  (`RingSceneTests`). Ein Kommentar haette es nur behauptet.
//
//  Jungs und Maedels waren bis zum 28. Oktober ein Spiegelpaar –
//  dieselben Blaeschen, einmal links, einmal rechts. Gedacht als "die
//  beiden gehoeren zusammen", war es das aehnlichste Paar im ganzen Spiel.
//  Jetzt zucken bei den Jungs Blitze, bei den Maedels rieselt Glitzer.
//
//  Die Karte selbst hat seit demselben Tag ebenfalls einen eigenen Auftritt
//  je Rang (`RingCardEntrance`) – Szene und Auftritt zusammen machen den
//  Rang erkennbar, bevor jemand liest.
//
//  Deckkraft ist hier kein Detail, sondern die Bedingung: Die Szene liegt
//  HINTER dem Text, und der muss lesbar bleiben. Was kraeftig sein darf,
//  liegt am Rand oder unten (Bier, Glut, Rand im Herzschlag); was durch die
//  Mitte geht, bleibt blass (Lichtsaeulen, Scheinwerfer).
//

import SwiftUI

struct RingCardFlourish: View {

    let rank: Int
    /// So lange wartet die Szene, bevor sie loslaeuft – der Kartenscreen
    /// faehrt erst herein.
    var delay: Double = 0

    var body: some View {
        EffectCanvas(draw: RingScene(rank: rank).drawing, delay: delay)
            // Die ganze Szene haengt an der Karte: Ein neuer Rang baut sie
            // neu auf, statt die alte Bewegung weiterlaufen zu lassen.
            // Steht HIER und nicht an der Aufrufstelle – die eine Stelle,
            // die es vergessen koennte, ist dann keine (Lessons Learned
            // Nr. 11).
            .id(rank)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

/// Die dreizehn Bewegungen von Ring of Fire, je Rang eine.
///
/// Eine Aufzaehlung und nicht eine Funktion, die gleich die Leinwand
/// liefert: Nur so laesst sich pruefen, dass zwei Raenge nie dieselbe Szene
/// bekommen – genau der Fehler, den der Nutzer zweimal gesehen hat.
enum RingScene: CaseIterable {

    case pointAt, drinkSelf, waterfall, guys, chicks, heaven
    case mates, rhyme, rule, thumbMaster, queen, category, ace

    /// 2 bis 13 wie auf der Karte; alles andere ist das Ass (14).
    init(rank: Int) {
        switch rank {
        case 2: self = .pointAt
        case 3: self = .drinkSelf
        case 4: self = .waterfall
        case 5: self = .guys
        case 6: self = .chicks
        case 7: self = .heaven
        case 8: self = .mates
        case 9: self = .rhyme
        case 10: self = .rule
        case 11: self = .thumbMaster
        case 12: self = .queen
        case 13: self = .category
        default: self = .ace
        }
    }

    /// Die Bewegung in einem Satz – ohne Emoji, und keiner kommt zweimal
    /// vor. Faellt einem fuer eine neue Szene kein eigener Satz ein, ist es
    /// keine neue Szene.
    var motion: String {
        switch self {
        case .pointAt: return "Ein Pinselstrich schießt quer über den Screen und endet als Pfeil."
        case .drinkSelf: return "Bier steigt von unten, schwappt und trägt eine Schaumkrone."
        case .waterfall: return "Wellige Ströme fallen von oben und spritzen unten auf."
        case .guys: return "Blitze zucken im Zickzack an den Seiten herab."
        case .chicks: return "Glitzer rieselt von oben und funkelt auf."
        case .heaven: return "Lichtsäulen fallen von oben und wiegen sich langsam."
        case .mates: return "Zwei Lichter kreisen umeinander, durch ein Band verbunden."
        case .rhyme: return "Schallwellen laufen im Takt von unten herauf."
        case .rule: return "Ein Stempel knallt auf und hinterlässt seinen Abdruck."
        case .thumbMaster: return "Der Bildschirmrand leuchtet im Herzschlag."
        case .queen: return "Zwei Scheinwerfer schwenken herein und treffen sich auf der Karte."
        case .category: return "Kärtchen fliegen aus der Mitte nach allen Seiten und drehen sich."
        case .ace: return "Glut steigt auf wie aus einem Lagerfeuer."
        }
    }

    /// Die Zeichnung der Szene. Alle dreizehn haben dieselbe Form –
    /// Leinwand, Groesse, Zeit –, und `EffectCanvas` zeigt sie. Die
    /// `AnyView` von frueher ist damit ueberfluessig: Sie war noetig, weil
    /// dreizehn verschiedene Schichtungen dreizehn verschiedene Typen
    /// ergaben, an denen der Compiler Minuten rechnete.
    var drawing: (inout GraphicsContext, CGSize, Double) -> Void {
        switch self {
        case .pointAt: return SceneArt.pointAt
        case .drinkSelf: return SceneArt.drinkSelf
        case .waterfall: return SceneArt.waterfall
        case .guys: return SceneArt.lightning
        case .chicks: return SceneArt.glitter
        case .heaven: return SceneArt.heaven
        case .mates: return SceneArt.drinkingMates
        case .rhyme: return SceneArt.rhyme
        case .rule: return SceneArt.rule
        case .thumbMaster: return SceneArt.thumbMaster
        case .queen: return SceneArt.queen
        case .category: return SceneArt.category
        case .ace: return SceneArt.ace
        }
    }
}
