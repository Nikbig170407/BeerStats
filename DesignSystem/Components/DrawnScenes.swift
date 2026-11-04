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
//  `RingCardFlourish`, die Szenen von Ring of Fire selbst seit dem
//  4. November in `RingSceneArt`.
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
    /// Hoechstens so oft wird neu gezeichnet, in Sekunden je Bild. Ohne
    /// Angabe so oft wie der Bildschirm – fuer Szenen, die lange stehen
    /// bleiben, reichen dreissig Bilder je Sekunde.
    var minimumInterval: Double?
    /// Wie gross die Dinge der Szene gezeichnet werden. Die ORTE bleiben, wo
    /// sie sind – jede Szene rechnet in Bruchteilen von Breite und Hoehe –,
    /// nur Striche, Kreise, Scheine und Wege wachsen. Dafuer zeichnet die
    /// Szene auf einer kleineren Leinwand, die auf die volle Groesse gezogen
    /// wird; keine Szene muss davon wissen.
    var scale: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var over = false

    var body: some View {
        Group {
            if reduceMotion {
                Canvas { context, size in paint(&context, size, stillAt) }
            } else if over, let lasts {
                Canvas { context, size in paint(&context, size, lasts) }
            } else {
                // Voll ausgeschrieben: Bis zum 29. Oktober hiess ein eigener
                // Screen `TimelineView` und verdeckte den von SwiftUI
                // (Lessons Learned Nr. 15).
                SwiftUI.TimelineView(.animation(minimumInterval: minimumInterval)) { timeline in
                    Canvas { context, size in
                        paint(&context, size, max(0, timeline.date.timeIntervalSince(start) - delay))
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

    /// Zeichnet die Szene in ihrer Groesse – siehe `scale`.
    private func paint(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        guard scale != 1 else {
            draw(&context, size, t)
            return
        }
        let k = CGFloat(scale)
        context.scaleBy(x: k, y: k)
        draw(&context, CGSize(width: size.width / k, height: size.height / k), t)
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
    /// Weich hinein und weich hinaus, von 0 bis 1.
    static func smooth(_ x: Double) -> Double {
        let c = clamp(x)
        return c * c * (3 - 2 * c)
    }

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

// MARK: - Die Kostenarten im Trink-Roulette

extension SceneArt {

    // Bis zum 4. November waren das die Szenen der Drei und des Asses in
    // Ring of Fire. Dort sind seitdem neue, aufwendigere Szenen dran
    // (`RingSceneArt`), die um eine landende Karte herum gebaut sind – mit
    // einem Schlag, wenn sie ankommt. Im Trink-Roulette landet keine Karte;
    // hier bleiben die ruhigen Fassungen. Die Sprache bleibt dieselbe:
    // Schluecke steigen als Bier, ein Shot glueht.

    /// Schluecke: Bier steigt von unten, schwappt und traegt eine Schaumkrone.
    static func beerRising(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
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

    /// Shot: Glut steigt wie aus einem Lagerfeuer, unten atmet der Schein.
    static func embersRising(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double) {
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

    /// Sieg in der Hitparade: eine Schallplatte dreht sich hinter dem Pokal.
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
