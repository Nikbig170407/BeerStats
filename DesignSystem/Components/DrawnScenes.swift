//
//  DrawnScenes.swift
//  BeerStats
//
//  Gezeichnete Szenen: jede mit ihrer EIGENEN Bewegung.
//
//  Bis zum 27. Oktober war fast jede Szene im Projekt dasselbe Rezept aus
//  vier Bausteinen – Strahlen, Druckwelle, fliegende Emoji, ein Emoji, das
//  einschlaegt. Allein `RingCardFlourish` setzte sie 41-mal ein. Der Nutzer
//  hat es am Tisch auf den Punkt gebracht: "Die sehen alle gleich aus, nur
//  mit anderen Emojis." Ein anderes Zeichen auf derselben Flugbahn ist keine
//  andere Szene.
//
//  Deshalb hier keine Teilchen mit wechselndem Zeichen, sondern Szenen, die
//  sich in ihrer BEWEGUNG unterscheiden – Bier steigt, Stroeme fallen,
//  Scheinwerfer schwenken, ein Stempel knallt auf. Die Pruefung: Jede
//  Szene laesst sich in einem Satz beschreiben, ohne ein Emoji zu nennen,
//  und kein Satz kommt zweimal vor. Die Tabelle steht in
//  `RingCardFlourish`.
//
//  Gezeichnet wird mit fuenf Werkzeugen (Kreis, Schein, Flaeche,
//  Flaeche mit Verlauf, Linie) – mehr braucht keine Szene, und je weniger
//  verschiedene Aufrufe, desto weniger kann beim Uebertragen schiefgehen.
//  Alle Szenen sind vorher im Browser mit derselben Rechnung gezeichnet und
//  abgestimmt worden. Gerechnet wird in `Double`; erst die Werkzeuge machen
//  daraus Punkte.
//
//  Es gelten die Regeln aus `VisualEffects`: hinter dem Text, keine Tipps,
//  fuer VoiceOver unsichtbar, gerechneter statt gewuerfelter Zufall. Die
//  Zeitleiste laeuft nur, solange die Szene im Bild ist; mit "Bewegung
//  reduzieren" steht ein einzelnes Bild still da – nicht nichts.
//

import SwiftUI

// MARK: - Die Leinwand

/// Zeichnet eine Szene ueber die Zeit seit ihrem Erscheinen.
struct EffectCanvas: View {

    /// Die Szene: Leinwand, Groesse, Sekunden seit dem Erscheinen.
    let draw: (inout GraphicsContext, CGSize, Double) -> Void
    /// Welcher Augenblick stehen bleibt, wenn Bewegung reduziert ist – einer,
    /// in dem schon alles da ist.
    var stillAt: Double = 1.8
    /// Einmalige Szenen (die Explosion) sind nach dieser Zeit vorbei; dann
    /// wird die Zeitleiste abgebaut und das letzte Bild bleibt stehen. Ohne
    /// Angabe laeuft die Szene, solange sie im Bild ist.
    var lasts: Double?
    /// So lange steht das erste Bild, bevor die Szene loslaeuft – fuer
    /// Screens, die selbst erst hereinfahren. Ihr Anfang liefe sonst in
    /// der Bewegung des ganzen Screens unter.
    var delay: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var over = false

    var body: some View {
        Group {
            if reduceMotion {
                Canvas { context, size in draw(&context, size, stillAt) }
            } else if over, let lasts {
                Canvas { context, size in draw(&context, size, lasts) }
            } else {
                // Voll ausgeschrieben: `TimelineView` allein ist im Projekt der
                // Screen des Zeitstrahl-Spiels und verdeckt den von SwiftUI.
                SwiftUI.TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        draw(&context, size, max(0, timeline.date.timeIntervalSince(start) - delay))
                    }
                }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onAppear { start = Date() }
        // Bricht mit der Ansicht ab – nichts laeuft weiter, wenn sie weg ist
        .task {
            guard let lasts else { return }
            try? await Task.sleep(nanoseconds: UInt64((delay + lasts) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            over = true
        }
    }
}

// MARK: - Werkzeug

enum SceneArt {

    typealias Point = (x: Double, y: Double)

    // Dinge, die ihre eigene Farbe haben – Bier ist bernstein, egal welches
    // Farbschema gewaehlt ist. Alles andere kommt aus der Palette.
    static let beer = Color(red: 0.95, green: 0.66, blue: 0.23)
    static let beerDeep = Color(red: 0.78, green: 0.47, blue: 0.1)
    static let foam = Color(red: 1, green: 0.97, blue: 0.91)
    static let light = Color(red: 1, green: 0.96, blue: 0.84)
    static let bolt = Color(red: 0.47, green: 0.75, blue: 1)
    static let boltCore = Color(red: 0.92, green: 0.96, blue: 1)
    static let pink = Color(red: 0.91, green: 0.36, blue: 0.6)
    static let glitterCore = Color(red: 1, green: 0.94, blue: 0.97)
    static let violet = Color(red: 0.61, green: 0.48, blue: 1)
    static let ember = Color(red: 1, green: 0.59, blue: 0.16)
    static let emberCore = Color(red: 1, green: 0.86, blue: 0.55)
    static let card = Color(red: 0.96, green: 0.95, blue: 0.92)

    // Gerechneter Zufall in Double, damit die Szenen ohne Umrechnung rechnen
    static func noise(_ i: Int, _ seed: Int) -> Double { Double(EffectNoise.scatter(i, seed: seed)) }
    static func unit(_ i: Int, _ seed: Int) -> Double { Double(EffectNoise.unit(i, seed: seed)) }
    static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
    static func easeOut(_ x: Double) -> Double { 1 - pow(1 - clamp(x), 3) }
    static func easeIn(_ x: Double) -> Double { pow(clamp(x), 2) }
    static func fract(_ x: Double) -> Double { x - x.rounded(.down) }

    private static func cg(_ p: Point) -> CGPoint { CGPoint(x: p.x, y: p.y) }

    private static func polygon(_ points: [Point]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: cg(first))
        for p in points.dropFirst() { path.addLine(to: cg(p)) }
        path.closeSubpath()
        return path
    }

    static func circle(_ g: inout GraphicsContext, _ x: Double, _ y: Double, _ r: Double, _ color: Color, _ alpha: Double) {
        guard r > 0, alpha > 0.001 else { return }
        g.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(color.opacity(alpha)))
    }

    /// Ein weicher Schein, der nach aussen ins Nichts laeuft.
    static func glow(_ g: inout GraphicsContext, _ x: Double, _ y: Double, _ r: Double, _ color: Color, _ alpha: Double) {
        guard r > 1, alpha > 0.001 else { return }
        g.fill(Path(CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .radialGradient(
            Gradient(colors: [color.opacity(alpha), color.opacity(0)]),
            center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
    }

    static func fill(_ g: inout GraphicsContext, _ points: [Point], _ color: Color, _ alpha: Double) {
        guard points.count > 2, alpha > 0.001 else { return }
        g.fill(polygon(points), with: .color(color.opacity(alpha)))
    }

    /// Flaeche mit Verlauf von `from` nach `to`; Stopps als (Ort, Farbe, Deckkraft).
    static func fill(_ g: inout GraphicsContext, _ points: [Point], from: Point, to: Point, _ stops: [(Double, Color, Double)]) {
        guard points.count > 2 else { return }
        let gradient = Gradient(stops: stops.map { Gradient.Stop(color: $0.1.opacity($0.2), location: $0.0) })
        g.fill(polygon(points), with: .linearGradient(gradient, startPoint: cg(from), endPoint: cg(to)))
    }

    static func stroke(_ g: inout GraphicsContext, _ points: [Point], _ color: Color, _ alpha: Double, _ width: Double) {
        guard points.count > 1, alpha > 0.001 else { return }
        var path = Path()
        path.move(to: cg(points[0]))
        for p in points.dropFirst() { path.addLine(to: cg(p)) }
        g.stroke(path, with: .color(color.opacity(alpha)), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    /// Punkte auf einem Kreisbogen – Winkel im Bogenmass, im Uhrzeigersinn
    /// auf dem Bildschirm (y waechst nach unten).
    static func arc(_ cx: Double, _ cy: Double, _ r: Double, _ a0: Double, _ a1: Double, _ n: Int = 40) -> [Point] {
        (0...n).map { i in
            let a = a0 + (a1 - a0) * Double(i) / Double(n)
            return (cx + cos(a) * r, cy + sin(a) * r)
        }
    }
}

// MARK: - Die Szenen von Ring of Fire

extension SceneArt {

    /// 2 – Du: Ein Pinselstrich schiesst quer ueber den Screen und endet als
    /// Pfeil. Abwechselnd von links und von rechts.
    static func pointAt(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = Double(size.width), h = Double(size.height)
        // Einmal je Bild lesen, nicht je Strich: Die Akzentfarbe kommt aus
        // den Einstellungen.
        let akzent = BeerStatsColor.accent
        for k in 0..<2 {
            let lauf = (t + Double(k) * 1.2) / 2.4
            let zyklus = Int(lauf.rounded(.down)), z = fract(lauf) * 2.4
            let vonLinks = zyklus % 2 == 0, y0 = h * (0.28 + 0.44 * unit(zyklus, 3))
            let fort = easeOut(z / 0.45), weg = 1 - clamp((z - 0.9) / 0.8)
            guard weg > 0 else { continue }
            let punkte: [Point] = (0...30).map { i in
                let p = Double(i) / 30 * fort, x = -40 + (w + 80) * p
                return (vonLinks ? x : w - x, y0 - sin(p * .pi) * 60)
            }
            stroke(&g, punkte, akzent, 0.18 * weg, 44)
            stroke(&g, punkte, akzent, 0.35 * weg, 24)
            stroke(&g, punkte, foam, 0.5 * weg, 6)
            let spitze = punkte[punkte.count - 1], davor = punkte[punkte.count - 2]
            let winkel = atan2(spitze.y - davor.y, spitze.x - davor.x)
            func seite(_ d: Double, _ a: Double) -> Point { (spitze.x + cos(winkel + a) * d, spitze.y + sin(winkel + a) * d) }
            fill(&g, [seite(44, 0), seite(48, 2.5), seite(14, .pi), seite(48, -2.5)], akzent, 0.7 * weg)
        }
    }

    /// 3 – Ich: Bier steigt von unten, schwappt und traegt eine Schaumkrone.
    static func drinkSelf(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = Double(size.width), h = Double(size.height)
        let pegel = h - h * 0.3 * easeOut(t / 1.4)
        func oben(_ x: Double) -> Double { pegel + 7 * sin(x * 0.035 + t * 2.6) + 4 * sin(x * 0.09 - t * 3.7) }
        var flaeche: [Point] = (0...40).map { i in let x = w * Double(i) / 40; return (x, oben(x)) }
        flaeche.append((w, h + 10))
        flaeche.append((0, h + 10))
        fill(&g, flaeche, from: (0, pegel), to: (0, h), [(0, beer, 0.42), (1, beerDeep, 0.5)])
        for i in 0..<22 {
            let x = (Double(i) + 0.5) / 22 * w + noise(i, 2) * 8
            circle(&g, x, oben(x) - 2, 7 + 5 * unit(i, 3) + 1.5 * sin(t * 3 + Double(i)), foam, 0.55)
        }
        for i in 0..<18 {
            let z = fract(t * (0.25 + 0.2 * unit(i, 5)) + unit(i, 6))
            let x = w * unit(i, 7) + 6 * sin(t * 4 + Double(i)), y = h - (h - pegel - 14) * z
            if y > oben(x) + 6 { circle(&g, x, y, 1.5 + 2.5 * unit(i, 8), foam, 0.45 * (1 - z * 0.5)) }
        }
    }

    /// 4 – Wasserfall: Wellige Stroeme fallen von oben und spritzen unten auf.
    static func waterfall(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = Double(size.width), h = Double(size.height)
        let da = easeOut(t / 0.6), boden = h - 26
        for i in 0..<5 {
            let di = Double(i)
            let x = w * (0.1 + 0.2 * di) + noise(i, 1) * 14, b = 9 + 7 * unit(i, 2)
            let ende = min(boden, h * 1.1 * easeOut(t / (0.5 + 0.2 * unit(i, 3))))
            func welle(_ y: Double) -> Double { 2.5 * sin(y * 0.05 - t * 9 + di) }
            var links: [Point] = [], rechts: [Point] = []
            for k in 0...24 {
                let y = -10 + (ende + 10) * Double(k) / 24, schmal = 1 - 0.35 * Double(k) / 24
                links.append((x - b / 2 * schmal + welle(y), y))
                rechts.append((x + b / 2 * schmal + welle(y), y))
            }
            fill(&g, links + rechts.reversed(), from: (x, 0), to: (x, ende), [(0, beer, 0.2), (1, beer, 0.5)])
            for k in 0..<5 {
                let y = fract(t * 1.8 + Double(k) / 5 + unit(i, 4)) * ende
                stroke(&g, [(x + welle(y), y), (x + welle(y + 22), y + 22)], foam, 0.45, 2.5)
            }
            guard ende >= boden else { continue }
            for k in 0..<7 {
                let z = fract(t * 2.2 + Double(k) / 7 + unit(i, 5))
                let seite: Double = k % 2 == 1 ? 1 : -1
                let weite = seite * (16 + 22 * unit(k + i, 6))
                let sprung = 280 * z * (1 - z) * (0.6 + 0.4 * unit(k, 7))
                circle(&g, x + weite * z, boden - sprung, 2 + 1.5 * unit(k, 8), foam, 0.55 * (1 - z))
            }
        }
        fill(&g, [(0, boden), (w, boden), (w, h + 5), (0, h + 5)], from: (0, boden), to: (0, h),
             [(0, beer, 0.4 * da), (1, beerDeep, 0.45 * da)])
    }

    /// 5 – Jungs: Blitze zucken im Zickzack an den Seiten herab.
    ///
    /// Bis zum 28. Oktober waren Jungs und Maedels ein Spiegelpaar –
    /// Blaeschen aus der linken und aus der rechten Ecke. Gemeint war "die
    /// beiden gehoeren zusammen"; am Tisch hiess es "die sehen gleich aus".
    /// Jetzt hat jede der beiden ihre eigene Bewegung.
    ///
    /// Die Blitze bleiben an den Raendern, weil in der Mitte der Text steht,
    /// und sie flackern, ohne ganz auszugehen: ein Zucken, kein Blinken.
    static func lightning(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = Double(size.width), h = Double(size.height)
        let takt = 1.4, leben = 0.36
        for k in 0..<2 {
            let lauf = (t + Double(k) * takt / 2) / takt
            let zyklus = Int(lauf.rounded(.down)), z = fract(lauf) * takt
            let n = zyklus * 2 + k, links = n % 2 == 0
            let streifen: Double = links ? 0.05 : 0.77
            let x0 = w * (streifen + 0.18 * unit(n, 1))
            // Die Kante glueht nach, auch wenn der Blitz schon weg ist
            glow(&g, x0, 0, 170, bolt, 0.28 * exp(-z * 3))
            guard z <= leben else { continue }

            // Alle 0,09 Sekunden ein neuer Weg – das ist das Zucken
            let schlag = Int(z / 0.09)
            let aus = clamp((z - leben * 0.55) / (leben * 0.45))
            let flackern = 0.75 + 0.25 * sin(z * 90)
            let hell = flackern * (1 - aus * aus * (3 - 2 * aus))
            let laenge = h * (0.34 + 0.22 * unit(n, 2))
            let zug: Double = links ? 3 : -3
            var punkte: [Point] = [(x0, -10)]
            var x = x0
            for i in 1...9 {
                x += noise(n * 31 + i + schlag * 7, 3) * 24 + zug
                punkte.append((x, -10 + laenge * Double(i) / 9))
            }
            stroke(&g, punkte, bolt, 0.2 * hell, 18)
            stroke(&g, punkte, bolt, 0.55 * hell, 6)
            stroke(&g, punkte, boltCore, 0.95 * hell, 2.2)

            // Ein Ast zweigt nach aussen ab
            let ab = 3 + Int(unit(n, 4) * 4)
            let seite: Double = links ? 1 : -1
            var ast: [Point] = [punkte[ab]]
            var ax = punkte[ab].x
            for i in 1...3 {
                ax += seite * (9 + 9 * unit(n + i + schlag, 5))
                ast.append((ax, punkte[ab].y + laenge * 0.075 * Double(i)))
            }
            stroke(&g, ast, bolt, 0.4 * hell, 4)
            stroke(&g, ast, boltCore, 0.8 * hell, 1.4)
        }
    }

    /// 6 – Maedels: Glitzer rieselt von oben und funkelt auf. In der Mitte
    /// blasser, dort steht der Text.
    static func glitter(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = Double(size.width), h = Double(size.height)
        for i in 0..<36 {
            let di = Double(i)
            let z = fract(t * (0.06 + 0.07 * unit(i, 1)) + unit(i, 2))
            let x = w * unit(i, 3) + 16 * sin(t * (0.8 + unit(i, 4)) + di)
            let y = -20 + (h + 40) * z
            // Jedes Korn blitzt in seinem eigenen Takt kurz auf
            let funkeln = pow(max(0, sin(t * (2.2 + 2 * unit(i, 5)) + di * 1.7)), 6)
            let rand = min(1, abs(x / w - 0.5) * 2.6)
            let hell = 0.4 + 0.6 * funkeln, aussen = 0.35 + 0.65 * rand
            let a = hell * aussen * min(1, z * 8) * min(1, (1 - z) * 6)
            let r = 4 + 3 * unit(i, 6) + 10 * funkeln
            if funkeln > 0.2 { glow(&g, x, y, r * 3.2, pink, 0.45 * funkeln * a) }
            sparkle(&g, x, y, r, t * 0.6 + di, pink, a)
            circle(&g, x, y, 1.2 + funkeln * 1.8, glitterCore, a)
        }
    }

    /// Ein Stern mit vier Zacken.
    private static func sparkle(_ g: inout GraphicsContext, _ x: Double, _ y: Double, _ r: Double, _ turn: Double, _ color: Color, _ alpha: Double) {
        let zacken: [Point] = (0..<8).map { k in
            let winkel = turn + Double(k) * .pi / 4
            let weite = k % 2 == 0 ? r : r * 0.28
            return (x + cos(winkel) * weite, y + sin(winkel) * weite)
        }
        fill(&g, zacken, color, alpha)
    }

    /// 7 – Himmel: Lichtsaeulen fallen von oben und wiegen sich langsam.
    static func heaven(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = Double(size.width), h = Double(size.height)
        let da = easeOut(t / 0.8)
        for i in 0..<5 {
            let di = Double(i)
            let x = w * (0.12 + 0.19 * di), neigung = 0.1 * sin(t * 0.6 + di * 1.7)
            let oben = 8 + 10 * unit(i, 1), unten = 60 + 50 * unit(i, 2), ux = x + sin(neigung) * h
            fill(&g, [(x - oben, -10), (x + oben, -10), (ux + unten, h), (ux - unten, h)], from: (x, 0), to: (x, h),
                 [(0, light, (0.22 + 0.1 * sin(t * 1.3 + di)) * da), (0.75, light, 0.06 * da), (1, light, 0)])
        }
        for i in 0..<20 {
            let z = fract(t * 0.08 + unit(i, 3))
            circle(&g, w * unit(i, 4) + 20 * sin(t + Double(i)), h * (0.1 + 0.8 * z), 1.5 + unit(i, 5) * 1.5, light, 0.5 * da * sin(z * .pi))
        }
    }

    /// 8 – Trink-Duo: Zwei Lichter kreisen umeinander, durch ein Band verbunden.
    static func drinkingMates(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = Double(size.width), h = Double(size.height)
        let da = easeOut(t / 0.7), cx = w / 2, cy = h * 0.42, r = 120 * da, a = t * 1.9
        let eins: Point = (cx + cos(a) * r, cy + sin(a) * r * 0.55)
        let zwei: Point = (cx - cos(a) * r, cy - sin(a) * r * 0.55)
        let band: [Point] = (0...20).map { i in
            let s = Double(i) / 20
            return (eins.x + (zwei.x - eins.x) * s, eins.y + (zwei.y - eins.y) * s + sin(s * .pi) * 18 * sin(t * 3))
        }
        stroke(&g, band, BeerStatsColor.success, 0.22 * da, 14)
        stroke(&g, band, foam, 0.3 * da, 3)
        for (p, farbe) in [(eins, BeerStatsColor.success), (zwei, BeerStatsColor.accent)] {
            glow(&g, p.x, p.y, 90, farbe, 0.35 * da)
            circle(&g, p.x, p.y, 16, farbe, 0.6 * da)
            circle(&g, p.x, p.y, 7, foam, 0.7 * da)
        }
    }

    /// 9 – Reim: Schallwellen laufen im Takt von unten herauf.
    static func rhyme(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = Double(size.width), h = Double(size.height)
        for k in 0..<6 {
            let z = fract(t / 2.4 + Double(k) / 6), r = 40 + h * 0.95 * z
            stroke(&g, arc(w / 2, h + 40, r, .pi * 1.08, .pi * 1.92), violet, 0.45 * (1 - z) * min(1, z * 8), 7 * (1 - z * 0.6))
        }
        glow(&g, w / 2, h + 20, 160, violet, 0.3 + 0.1 * sin(t * 2 * .pi / 0.6))
    }

    /// 10 – Regel: Ein Stempel knallt auf und hinterlaesst seinen Abdruck,
    /// ringsum spritzt Tinte.
    static func rule(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = Double(size.width), h = Double(size.height)
        guard t >= 0.15 else { return }
        let cx = w / 2, cy = h * 0.4
        let s = t < 0.33 ? 2.2 - 1.2 * easeIn((t - 0.15) / 0.18) : 1
        let a = min(1, (t - 0.15) / 0.1), r = 118 * s, dreh = 0.15 + t * 0.05
        let farbe = BeerStatsColor.warning
        stroke(&g, arc(cx, cy, r, 0, 2 * .pi, 60), farbe, 0.5 * a, 9)
        stroke(&g, arc(cx, cy, r * 0.82, 0, 2 * .pi, 60), farbe, 0.4 * a, 3)
        for i in 0..<24 {
            let wi = dreh + Double(i) / 24 * 2 * .pi
            let dx = cos(wi) * r, dy = sin(wi) * r
            stroke(&g, [(cx + dx * 0.87, cy + dy * 0.87), (cx + dx * 0.95, cy + dy * 0.95)], farbe, 0.45 * a, 4)
        }
        guard t > 0.33 else { return }
        let z = clamp((t - 0.33) / 0.5)
        stroke(&g, arc(cx, cy, 118 + 120 * easeOut(z), 0, 2 * .pi, 60), farbe, 0.3 * (1 - z), 3)
        for i in 0..<9 {
            let wi = unit(i, 1) * 2 * .pi, d = 130 + 60 * unit(i, 2) * easeOut(z * 2)
            circle(&g, cx + cos(wi) * d, cy + sin(wi) * d, 4 + 7 * unit(i, 3), farbe, 0.4)
        }
    }

    /// 11 – Daumenmeister: Der Bildschirmrand leuchtet im Herzschlag.
    static func thumbMaster(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = Double(size.width), h = Double(size.height)
        // Zwei Schlaege kurz hintereinander, der zweite leiser – ein Herz,
        // kein Blinker
        let z = fract(t / 1.1)
        let erster = (z - 0.1) / 0.05, zweiter = (z - 0.3) / 0.06
        let puls = max(exp(-erster * erster), 0.7 * exp(-zweiter * zweiter))
        let a = 0.15 + 0.45 * puls, d = 70 + 40 * puls
        let farbe = BeerStatsColor.success
        let verlauf: [(Double, Color, Double)] = [(0, farbe, a), (1, farbe, 0)]
        fill(&g, [(0, 0), (w, 0), (w, d), (0, d)], from: (0, 0), to: (0, d), verlauf)
        fill(&g, [(0, h - d), (w, h - d), (w, h), (0, h)], from: (0, h), to: (0, h - d), verlauf)
        fill(&g, [(0, 0), (d, 0), (d, h), (0, h)], from: (0, 0), to: (d, 0), verlauf)
        fill(&g, [(w - d, 0), (w, 0), (w, h), (w - d, h)], from: (w, 0), to: (w - d, 0), verlauf)
    }

    /// 12 – Dame: Zwei Scheinwerfer schwenken aus den oberen Ecken herein und
    /// treffen sich auf der Karte.
    static func queen(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = Double(size.width), h = Double(size.height)
        let ziel: Point = (w / 2, h * 0.38), da = easeOut(t / 0.4)
        for vonRechts in [false, true] {
            // Beide Kegel zeigen zuerst an ihrem Rand entlang nach unten und
            // schwenken gegenlaeufig zur Mitte; danach wiegen sie sich
            // leicht versetzt
            let seite: Double = vonRechts ? -1 : 1, versatz: Double = vonRechts ? 1 : 0
            let ox = vonRechts ? w + 30 : -30, oy = -40.0
            let schwenk = (1 - easeOut(t / 1.3)) * 0.6 * seite + 0.05 * sin(t * 1.1 + versatz)
            let winkel = atan2(ziel.y - oy, ziel.x - ox) + schwenk, l = h * 1.1, b = 0.16
            let ende: Point = (ox + cos(winkel) * l, oy + sin(winkel) * l)
            let kanteA: Point = (ox + cos(winkel - b) * l, oy + sin(winkel - b) * l)
            let kanteB: Point = (ox + cos(winkel + b) * l, oy + sin(winkel + b) * l)
            fill(&g, [(ox, oy), kanteA, kanteB], from: (ox, oy), to: ende,
                 [(0, light, 0.3 * da), (0.5, light, 0.12 * da), (1, light, 0)])
        }
        glow(&g, ziel.x, ziel.y + 10, 160, BeerStatsColor.warning, 0.25 * easeOut((t - 0.9) / 0.6))
    }

    /// 13 – Kategorie: Kaertchen fliegen aus der Mitte nach allen Seiten und
    /// drehen sich dabei.
    static func category(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = Double(size.width), h = Double(size.height)
        let akzent = BeerStatsColor.accent
        for welle in 0..<2 {
            let z = fract((t + Double(welle) * 1.3) / 2.6) * 2.6
            for i in 0..<12 {
                let wi = (Double(i) + 0.5 * Double(welle)) / 12 * 2 * .pi + noise(i, 1) * 0.2
                let d = (230 + 60 * unit(i, 2)) * easeOut(z / 1.2)
                let x = w / 2 + cos(wi) * d, y = h * 0.42 + sin(wi) * d + 40 * z * z
                let dreh = wi + z * (2 + 2 * unit(i, 3))
                let a = 0.55 * min(1, z * 6) * (1 - clamp((z - 1.6) / 1))
                guard a > 0 else { continue }
                let c = cos(dreh), s = sin(dreh)
                func ecke(_ dx: Double, _ dy: Double) -> Point {
                    (x + c * dx - s * dy, y + s * dx + c * dy)
                }
                let rahmen = [ecke(-13, -18), ecke(13, -18), ecke(13, 18), ecke(-13, 18)]
                fill(&g, rahmen, card, a * 0.7)
                stroke(&g, rahmen + [rahmen[0]], akzent, a, 2)
            }
        }
    }

    /// Ass: Glut steigt wie aus einem Lagerfeuer, unten atmet der Schein.
    static func ace(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = Double(size.width), h = Double(size.height)
        glow(&g, w / 2, h + 60, w * 0.9, BeerStatsColor.error, 0.35 + 0.08 * sin(t * 7) + 0.05 * sin(t * 11))
        for i in 0..<34 {
            let z = fract(t * (0.22 + 0.2 * unit(i, 1)) + unit(i, 2))
            let x = w * unit(i, 3) + 30 * sin(t * 1.7 + Double(i)) * z, y = h + 10 - h * 0.85 * z
            let flackern = 0.6 + 0.4 * sin(t * 15 + Double(i) * 3), r = 1.5 + 3 * unit(i, 4)
            glow(&g, x, y, r * 4, ember, 0.35 * (1 - z) * flackern)
            circle(&g, x, y, r, emberCore, 0.9 * (1 - z) * flackern)
        }
    }
}

// MARK: - Die Szenen der anderen Spiele

extension SceneArt {

    static let smoke = Color(red: 0.5, green: 0.44, blue: 0.39)
    static let smokeLit = Color(red: 1, green: 0.63, blue: 0.27)
    static let shard = Color(red: 0.67, green: 0.59, blue: 0.51)
    static let vinyl = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let groove = Color(red: 0.27, green: 0.27, blue: 0.3)
    static let gold = Color(red: 1, green: 0.84, blue: 0.47)

    /// Sieger-Screen: Raketen steigen und platzen als Feuerwerk.
    static func fireworks(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = Double(size.width), h = Double(size.height)
        let farben = [BeerStatsColor.accent, BeerStatsColor.warning, BeerStatsColor.success, BeerStatsColor.error, light]
        for k in 0..<3 {
            let lauf = (t + Double(k) * 0.8) / 2.4
            let zyklus = Int(lauf.rounded(.down)), z = fract(lauf) * 2.4, n = zyklus * 3 + k
            let x = w * (0.2 + 0.6 * unit(n, 1)), hoehe = h * (0.18 + 0.22 * unit(n, 2)), farbe = farben[n % farben.count]
            if z < 0.6 {
                // Die Rakete steigt, mit einem kurzen Schweif
                let p = easeOut(z / 0.6), y = h + 20 - (h + 20 - hoehe) * p
                stroke(&g, [(x, y), (x, y + 40 * (1 - p) + 8)], light, 0.6, 3)
                circle(&g, x, y, 3, light, 0.9)
                continue
            }
            let s = z - 0.6
            guard s <= 1.2 else { continue }
            glow(&g, x, hoehe, 170 * easeOut(s / 0.3), farbe, 0.35 * (1 - clamp(s / 0.5)))
            for i in 0..<26 {
                let wi = Double(i) / 26 * 2 * .pi + unit(n, 3), v = 190 * (0.7 + 0.3 * unit(i + n, 4))
                let px = x + cos(wi) * v * easeOut(s / 0.9), py = hoehe + sin(wi) * v * easeOut(s / 0.9) + 60 * s * s
                let a = 0.9 * (1 - clamp(s / 1.2))
                glow(&g, px, py, 9, farbe, a * 0.5)
                stroke(&g, [(px, py), (px - cos(wi) * 14, py - sin(wi) * 14 - 5)], farbe, a, 4)
                circle(&g, px, py, 2.5, light, a)
            }
        }
    }

    /// Bombe: ein Blitz, dann quillt Rauch auf, Splitter fliegen, Funken
    /// fallen. Einmalig – die Leinwand haelt danach an.
    static func explosion(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = Double(size.width), h = Double(size.height)
        let cx = w / 2, cy = h / 2
        if t < 0.3 { glow(&g, cx, cy, 60 + 400 * easeOut(t / 0.3), light, 0.8 * (1 - t / 0.3)) }
        for i in 0..<10 {
            let wi = Double(i) / 10 * 2 * .pi + noise(i, 1) * 0.3, z = clamp((t - 0.05) / 2.4)
            let d = 60 + 170 * easeOut(z) * (0.7 + 0.3 * unit(i, 2))
            let x = cx + cos(wi) * d, y = cy + sin(wi) * d - 90 * z, r = 40 + 70 * easeOut(z) * (0.7 + 0.5 * unit(i, 3))
            glow(&g, x, y, r, smoke, 0.5 * (1 - z) * min(1, t * 8))
            glow(&g, x, y + r * 0.2, r * 0.6, smokeLit, 0.35 * (1 - clamp(t / 0.7)))
        }
        for i in 0..<16 {
            let wi = unit(i, 4) * 2 * .pi, v = 260 + 200 * unit(i, 5), z = clamp(t / 1.4)
            let x = cx + cos(wi) * v * easeOut(z), y = cy + sin(wi) * v * easeOut(z) + 260 * z * z
            let dreh = z * 8 * noise(i, 6), groesse = 8 + 10 * unit(i, 7)
            let c = cos(dreh), s = sin(dreh)
            func ecke(_ dx: Double, _ dy: Double) -> Point {
                (x + c * dx - s * dy, y + s * dx + c * dy)
            }
            fill(&g, [ecke(-groesse, -groesse * 0.4), ecke(groesse, 0), ecke(-groesse * 0.3, groesse * 0.6)], shard, 0.95 * (1 - z))
        }
        for i in 0..<20 {
            let wi = unit(i, 8) * 2 * .pi, z = clamp(t / 0.9), d = 240 * easeOut(z) * (0.5 + 0.5 * unit(i, 9))
            let x = cx + cos(wi) * d, y = cy + sin(wi) * d + 80 * z * z
            glow(&g, x, y, 10, ember, 0.5 * (1 - z))
            circle(&g, x, y, 2.5, light, 0.9 * (1 - z))
        }
    }

    /// Roulette, nichts zu trinken: ein weiches Aufatmen in Gruen.
    static func relief(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = Double(size.width), h = Double(size.height)
        let cx = w / 2, cy = h * 0.4, atem = 0.5 - 0.5 * cos(min(t, 6) * .pi * 2 / 3)
        glow(&g, cx, cy, 220 + 90 * atem, BeerStatsColor.success, 0.18 + 0.12 * atem)
        for k in 0..<2 {
            let z = fract(t / 3 + Double(k) / 2)
            stroke(&g, arc(cx, cy, 80 + 260 * easeOut(z), 0, 2 * .pi, 60), BeerStatsColor.success, 0.3 * (1 - z), 2)
        }
    }

    /// Zeitstrahl-Sieg: eine Schallplatte dreht sich hinter dem Pokal.
    static func record(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = Double(size.width), h = Double(size.height)
        let cx = w / 2, cy = h / 2, r = min(w, h) * 0.48 * easeOut(t / 0.5), dreh = t * 3.5
        circle(&g, cx, cy, r, vinyl, 0.9)
        for k in 0..<9 {
            stroke(&g, arc(cx, cy, r * (0.42 + 0.055 * Double(k)), 0, 2 * .pi, 60), groove, 0.35, 1.2)
        }
        // Der Glanz auf der Platte dreht sich mit – daran sieht man, dass sie laeuft
        for versatz in [0, Double.pi] {
            let mitte = dreh + versatz
            var faecher: [Point] = [(cx, cy)]
            faecher += arc(cx, cy, r, mitte - 0.35, mitte + 0.35, 12)
            fill(&g, faecher, from: (cx, cy), to: (cx + cos(mitte) * r, cy + sin(mitte) * r),
                 [(0, light, 0), (0.6, light, 0.12), (1, light, 0.02)])
        }
        circle(&g, cx, cy, r * 0.3, BeerStatsColor.warning, 0.9)
        circle(&g, cx, cy, r * 0.05, vinyl, 1)
    }

    /// Pokal des Abends: ein Goldglanz zieht ueber die Zeile, dazu ein paar
    /// funkelnde Kreuze. Leise – die Zeile steht in einer Liste.
    static func shine(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = Double(size.width), h = Double(size.height)
        let z = fract(t / 2.6), x = -w * 0.3 + w * 1.6 * easeOut(z / 0.7)
        fill(&g, [(x - 60, 0), (x, 0), (x - 40, h), (x - 100, h)], from: (x - 100, 0), to: (x, 0),
             [(0, gold, 0), (0.5, gold, 0.35 * (1 - z)), (1, gold, 0)])
        for i in 0..<6 {
            let z2 = fract(t / 1.7 + unit(i, 1)), a = sin(z2 * .pi) * 0.8
            let x2 = w * unit(i, 2), y2 = h * unit(i, 3), r = 6 * a
            stroke(&g, [(x2 - r, y2), (x2 + r, y2)], gold, a, 2)
            stroke(&g, [(x2, y2 - r), (x2, y2 + r)], gold, a, 2)
        }
    }
}
