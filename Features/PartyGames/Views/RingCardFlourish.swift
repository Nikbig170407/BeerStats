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
//  (`RingSceneArt.swift`, seit dem 4. November in drei Akten: Aufbau,
//  Schlag beim Landen der Karte, Nachhall). Die Pruefung ist ein Satz je Rang, der ohne Emoji
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
//  Und die Szene waechst mit der Karte (3. November: "mach die Szenen auch
//  groesser"). Abgestimmt sind alle dreizehn auf eine Karte von 150
//  Punkten; seit die Karte sich die Hoehe des Screens nimmt, ist sie auf
//  einem iPhone 13 fast anderthalbmal so breit – und dieselbe Szene sah
//  dahinter kleiner aus als vorher. Jetzt werden Striche, Kreise und Wege
//  im selben Verhaeltnis groesser (`RingScene.scale`). Die Deckkraft
//  bleibt, wie sie abgestimmt ist.
//

import SwiftUI

struct RingCardFlourish: View {

    let rank: Int
    /// So lange wartet die Szene, bevor sie loslaeuft – der Kartenscreen
    /// faehrt erst herein.
    var delay: Double = 0
    /// Wie gross sie gezeichnet wird – `RingScene.scale(forCardWidth:)`.
    var scale: Double = 1
    /// Wo Karte und Text liegen, in Punkten dieser Ansicht. Die Szene zielt
    /// auf die Karte und bleibt blass, wo Text steht (`RingStage`).
    var layout = RingCardLayout()

    var body: some View {
        let szene = RingScene(rank: rank)
        let lage = layout, k = scale
        EffectCanvas(
            draw: { g, size, t in szene.draw(&g, size, t, layout: lage, scale: k) },
            delay: delay,
            scale: scale
        )
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
    /// keine neue Szene. Seit dem 4. November in drei Akten erzaehlt:
    /// Aufbau, Schlag beim Landen der Karte, Nachhall.
    var motion: String {
        switch self {
        case .pointAt: return "Ein breiter Pinsel holt am Rand aus, zieht mit nassen Borsten einen Pfeil zur Karte, Farbe spritzt und läuft herab, und im Nachhall malt er abwechselnd von beiden Seiten."
        case .drinkSelf: return "Bier schießt in einem Schwall hoch und kräuselt sich beim Aufprall der Karte, hinten steigen feine Perlen, vorne platzen große Blasen."
        case .waterfall: return "Ströme stürzen nacheinander von links nach rechts herab, prallen in einer Gischtwolke auf, und hinten hängt Sprühnebel in der Luft."
        case .guys: return "Gewitterwolken türmen sich oben auf und leuchten von innen, beim Schlag fahren zwei Blitze an beiden Rändern bis zum Boden, und Regen peitscht schräg herab."
        case .chicks: return "Glitzer ergießt sich in einem Schwall über die Karte, große Lichtkugeln schweben dahinter, und vorne funkeln langsam drehende Sterne."
        case .heaven: return "Die Wolken reißen von der Mitte her auf und leuchten an den Kanten, Lichtsäulen fallen nacheinander, Staub glitzert im Licht, und beim Schlag öffnet sich oben ein heller Schein."
        case .mates: return "Zwei Lichter jagen sich von unten heran, stoßen unter dem Text klirrend an und umrunden dann Karte und Text in einer Schleife, auf der sie sich oben und unten wieder treffen."
        case .rhyme: return "Ein Equalizer mit glänzenden Kappen pumpt am unteren Rand, hinten pulsieren Lautsprecherringe, und mit jedem Schlag läuft eine Schallwelle nach oben."
        case .rule: return "Ein riesiger Stempel senkt sich mit wachsendem Schatten, knallt auf, dass der Screen bebt, Tinte spritzt in Fäden, und der nasse Abdruck zieht langsam ins Papier."
        case .thumbMaster: return "Der Rand schlägt im Herzrhythmus, mit jedem Schlag läuft ein Puls aus den Ecken nach innen, und unten zieht eine Herzkurve mit."
        case .queen: return "Vor dunklem Vorhang flammen zwei Scheinwerfer nacheinander auf, schwenken auf die Karte, Staub tanzt im Licht, und beim Schlag glüht unten die Rampe auf."
        case .category: return "Kärtchen wirbeln in einer Spirale aus der Mitte, in drei Schichten von fern und unscharf bis nah und groß, ziehen Schlieren und kehren in jeder Welle anders herum."
        case .ace: return "Flammen in zwei Reihen schlagen am unteren Rand hoch, beim Aufprall schießt eine Stichflamme empor, Glut stiebt mit Schweif, und die Luft darüber flimmert."
        }
    }

    /// Der Rang dieser Szene – die Umkehrung von `init(rank:)`.
    var rank: Int {
        switch self {
        case .pointAt: return 2
        case .drinkSelf: return 3
        case .waterfall: return 4
        case .guys: return 5
        case .chicks: return 6
        case .heaven: return 7
        case .mates: return 8
        case .rhyme: return 9
        case .rule: return 10
        case .thumbMaster: return 11
        case .queen: return 12
        case .category: return 13
        case .ace: return 14
        }
    }

    /// Das Licht der Szene: In diese Farbe wandert beim Schlag das Licht
    /// hinter der Karte, und in ihr leuchten Rand und Schein der Karte.
    var light: Color {
        switch self {
        case .pointAt, .category: return BeerStatsColor.accent
        case .drinkSelf, .waterfall: return SceneArt.beer
        case .guys: return SceneArt.bolt
        case .chicks: return SceneArt.pink
        case .heaven, .queen: return SceneArt.light
        case .mates, .thumbMaster: return BeerStatsColor.success
        case .rhyme: return SceneArt.violet
        case .rule: return BeerStatsColor.warning
        case .ace: return SceneArt.ember
        }
    }

    /// Die grossen Momente: Dort rueckt der Screen beim Schlag kurz heran.
    var zoomsOnHit: Bool {
        switch self {
        case .drinkSelf, .guys, .heaven, .rule, .queen, .ace: return true
        default: return false
        }
    }

    /// Wie stark der Screen beim Schlag bebt, in Punkten. Nur dort, wo
    /// etwas einschlaegt – Blitz, Stempel, Shot –, sonst nutzt sich das
    /// Beben ab.
    var quake: Double {
        switch self {
        case .guys: return 4.5
        case .rule: return 7
        case .ace: return 8
        default: return 0
        }
    }

    /// Was beim Schlag klingt, in Sekunden um ihn herum: der Rangklang und
    /// die Schichten, die zur Szene gehoeren. Manches kommt vorher – der
    /// Luftzug vor dem Stempel, die Scheinwerfer der Dame, die Spruenge der
    /// Neun –, damit der Schlag selbst auf die Landung faellt. Beim Stempel
    /// liegt der laute zweite Hammerschlag 0,2 Sekunden im Rangklang; der
    /// beginnt deshalb so viel frueher.
    var hitSounds: [(at: Double, sound: GameSound)] {
        let rang = GameSound.ringRank(rank)
        switch self {
        case .pointAt: return [(0, rang), (0.02, .ringSplat)]
        case .drinkSelf: return [(-0.3, .ringGush), (0, rang)]
        case .waterfall:
            return [(-0.3, rang), (-0.28, .ringStream), (-0.14, .ringStream), (0, .ringStream), (0.14, .ringStream), (0.28, .ringStream)]
        case .guys: return [(0, rang), (0.05, .ringThunder)]
        case .chicks: return [(0, rang), (0, .ringShimmer)]
        case .heaven: return [(-0.45, .ringChoir), (0, rang)]
        case .mates: return [(0, rang)]
        case .rhyme: return [(-0.68, .ringBeat), (-0.34, .ringBeat), (0, rang)]
        case .rule: return [(-0.3, .ringWhoosh), (-0.2, rang)]
        case .thumbMaster: return [(0, rang), (0, .ringHeartbeat)]
        case .queen: return [(-0.84, .ringSpotlight), (-0.66, .ringSpotlight), (0, rang)]
        case .category: return [(-0.1, .ringFlutter), (0, rang)]
        case .ace: return [(0, rang)]
        }
    }

    /// Was beim Schlag ruettelt, in Sekunden um ihn herum – im Takt dessen,
    /// was die Szene tut: fuenf Stroeme, drei Spruenge, zwei Herzschlaege.
    /// Der staerkste Stoss liegt immer auf dem Schlag.
    var hitTaps: [HapticManager.Tap] {
        func tap(_ t: Double, _ staerke: Double, _ haerte: Double) -> HapticManager.Tap {
            HapticManager.Tap(time: t, intensity: staerke, sharpness: haerte)
        }
        switch self {
        case .pointAt: return [tap(0, 0.8, 0.5)]
        case .drinkSelf: return [tap(0, 0.9, 0.4), tap(0.31, 0.5, 0.4), tap(0.51, 0.35, 0.4)]
        case .waterfall: return [tap(-0.28, 0.4, 0.3), tap(-0.14, 0.5, 0.3), tap(0, 0.9, 0.3), tap(0.14, 0.5, 0.3), tap(0.28, 0.4, 0.3)]
        case .guys: return [tap(0, 1, 0.9), tap(0.06, 0.7, 0.6)]
        case .chicks: return [tap(0, 0.6, 1), tap(0.12, 0.4, 1), tap(0.24, 0.3, 1)]
        case .heaven: return [tap(0, 0.7, 0.3)]
        case .mates: return [tap(0, 0.8, 1), tap(0.11, 0.6, 1)]
        case .rhyme: return [tap(-0.68, 0.5, 0.2), tap(-0.34, 0.6, 0.2), tap(0, 0.9, 0.3)]
        case .rule: return [tap(0, 1, 0.4)]
        case .thumbMaster: return [tap(0, 0.8, 0.2), tap(0.22, 0.55, 0.2)]
        case .queen: return [tap(-0.84, 0.5, 0.7), tap(-0.66, 0.5, 0.7), tap(0, 0.7, 0.5)]
        case .category: return [tap(0, 0.4, 0.8), tap(0.05, 0.4, 0.8), tap(0.1, 0.4, 0.8), tap(0.15, 0.4, 0.8)]
        case .ace: return [tap(0, 1, 0.6), tap(0.08, 0.8, 0.5)]
        }
    }

    /// Der Schlag: wann die Karte landet, in Sekunden ab dem Start der
    /// Szene. Szene und Auftritt beginnen gemeinsam (`settle`), also ist
    /// es dieselbe Zeit wie im Auftritt.
    var hitTime: Double { RingCardEntrance(rank: rank).hitTime }

    /// Wie gross die Szene hinter einer Karte dieser Breite gezeichnet
    /// wird: so viel groesser, wie die Karte breiter ist als die, auf die
    /// alle Szenen abgestimmt sind. Dieselbe Bezugsbreite wie bei den Wegen
    /// des Auftritts – Karte, Auftritt und Szene wachsen zusammen. Kleiner
    /// als abgestimmt wird sie nie.
    static func scale(forCardWidth width: CGFloat) -> Double {
        max(1, Double(width / RingCardEntrance.referenceWidth))
    }

    /// Zeichnet die Szene. `size` ist die Leinwand in Punkten der Szene
    /// (`EffectCanvas.scale` hat schon verkleinert), `layout` die gemessene
    /// Lage von Karte und Text in Punkten der Ansicht.
    func draw(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double, layout: RingCardLayout, scale: Double) {
        let stage = RingStage(size: size, hit: hitTime, layout: layout, scale: scale)
        var pinsel = SceneBrush(g)
        RingSceneArt.hitLightUnder(&pinsel, stage, t, light)
        switch self {
        case .pointAt: RingSceneArt.pointAt(&pinsel, stage, t)
        case .drinkSelf: RingSceneArt.drinkSelf(&pinsel, stage, t)
        case .waterfall: RingSceneArt.waterfall(&pinsel, stage, t)
        case .guys: RingSceneArt.lightning(&pinsel, stage, t)
        case .chicks: RingSceneArt.glitter(&pinsel, stage, t)
        case .heaven: RingSceneArt.heaven(&pinsel, stage, t)
        case .mates: RingSceneArt.drinkingMates(&pinsel, stage, t)
        case .rhyme: RingSceneArt.rhyme(&pinsel, stage, t)
        case .rule: RingSceneArt.rule(&pinsel, stage, t)
        case .thumbMaster: RingSceneArt.thumbMaster(&pinsel, stage, t)
        case .queen: RingSceneArt.queen(&pinsel, stage, t)
        case .category: RingSceneArt.category(&pinsel, stage, t)
        case .ace: RingSceneArt.ace(&pinsel, stage, t)
        }
        RingSceneArt.hitLightOver(&pinsel, stage, t, light)
        pinsel.flush()
    }
}
