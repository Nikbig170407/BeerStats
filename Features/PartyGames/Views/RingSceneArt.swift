//
//  RingSceneArt.swift
//  BeerStats
//
//  Die dreizehn Szenen hinter der gezogenen Karte – Fassung vom 4. November.
//
//  Der Nutzer zu den Szenen vom 27. Oktober: "Die Richtung stimmt, aber es
//  soll noch deutlich aufwendiger und imposanter werden." Seitdem ist jeder
//  Kartenscreen ein kleiner Trailer in drei Akten:
//
//  1. **Aufbau** – die Szene baut sich auf, waehrend die Karte unterwegs ist.
//  2. **Schlag** – wenn die Karte landet (`RingCardEntrance.landing`),
//     reagiert die Szene: Der Stempel knallt, die Lichter klirren, die
//     Stichflamme schiesst hoch. Licht, Klang und Ruetteln kommen im selben
//     Augenblick (Kartenscreen).
//  3. **Nachhall** – die Szene laeuft weiter, aber jede Runde ein wenig
//     anders (`zyklus` plus EffectNoise), sonst sieht man nach drei Karten
//     dieselbe Schleife.
//
//  Jede Szene hat drei Tiefen – hinten weich und langsam, in der Mitte der
//  Stoff, vorne scharf und schnell – und echte Stoffe statt flacher Flaechen:
//  Bier mit Glanzkante und Schaum, nasse Farbe mit Borsten, Tinte, die ins
//  Papier zieht. Abgestimmt wurde alles im Browser mit derselben Rechnung
//  (Vorschau "Ring of Fire Auftritte"), auf einem iPhone-13-Screen.
//
//  Drei Regeln, die in jeder Szene stecken:
//
//  - **Die Szene weiss, wo Karte und Text liegen** (`RingStage`). Gemessen
//    wird auf dem Kartenscreen; der Stempel liegt um die Karte, die Lichter
//    der Acht klirren UNTER dem Text. Vorher stand die Karte in den Szenen
//    als Anteil der Hoehe – auf einem anderen iPhone zielte der Pfeil daneben.
//  - **Im Textband bleibt alles blass** (`RingStage.faint`). Kraeftig darf
//    sein, was am Rand oder unten liegt. Im Browser lief das Bier ueber den
//    Text, die Kaertchen flogen hindurch – genau dafuer gibt es die Regel.
//  - **Gleiches wird zusammen gezeichnet** (`SceneBrush`). Hundert Funken
//    gleicher Farbe sind EIN Pfad und ein Aufruf. So kostet ein Bild im
//    Mittel nicht mehr als die alten Szenen, obwohl viel mehr darin ist.
//
//  Die Saetze der Satz-Regel stehen in `RingScene.motion`.
//

import SwiftUI

// MARK: - Die Buehne

/// Wo Karte und Text auf dem Kartenscreen liegen, in Punkten der Szene –
/// und wann der Schlag kommt.
struct RingStage {

    let w: Double
    let h: Double
    /// Der Schlag: Sekunden nach dem Start der Szene, in denen die Karte landet.
    let hit: Double
    /// Die Karte auf ihrem Platz.
    let card: CGRect
    /// Von hier bis dort steht Text.
    let textTop: Double
    let textBottom: Double

    /// `layout` ist in Punkten der Ansicht gemessen; die Szene zeichnet auf
    /// einer um `scale` kleineren Leinwand (`EffectCanvas.scale`).
    init(size: CGSize, hit: Double, layout: RingCardLayout, scale: Double) {
        w = Double(size.width)
        h = Double(size.height)
        self.hit = hit
        let k = CGFloat(max(scale, 0.0001))
        if let karte = layout.card {
            card = CGRect(x: karte.minX / k, y: karte.minY / k, width: karte.width / k, height: karte.height / k)
        } else {
            // Bevor gemessen ist: so, wie die Karte auf einem iPhone 13 liegt
            let breite = min(150, w * 0.56)
            let hoehe = breite * Double(PlayingCardView.aspect)
            card = CGRect(x: (w - breite) / 2, y: h * 0.3 - hoehe / 2, width: breite, height: hoehe)
        }
        if let text = layout.text {
            textTop = Double(text.minY / k) - 8
            textBottom = Double(text.maxY / k) + 4
        } else {
            textTop = Double(card.maxY) + 8
            textBottom = Double(card.maxY) + 128
        }
    }

    var cardMidX: Double { Double(card.midX) }
    var cardMidY: Double { Double(card.midY) }

    /// Wie viel einer Deckkraft auf der Hoehe `y` bleibt: ausserhalb des
    /// Textes alles, darin `rest` – mit weichen Kanten.
    func faint(_ y: Double, rest: Double = 0.22) -> Double {
        let oben = SceneArt.clamp((y - (textTop - 18)) / 18)
        let unten = SceneArt.clamp(((textBottom + 18) - y) / 18)
        return 1 - (1 - rest) * min(oben, unten)
    }
}

/// Wo Karte und Text liegen, gemessen in Punkten der Ansicht. Unbekannt,
/// solange noch nicht gemessen ist – dann rechnet `RingStage` mit der Lage
/// auf einem iPhone 13.
struct RingCardLayout: Equatable {
    var card: CGRect?
    var text: CGRect?
}

// MARK: - Der Pinsel

/// Zeichnet wie `SceneArt`, sammelt aber gleichartige Formen – gleiche
/// Farbe, Deckkraft und Strichbreite – und zeichnet sie in einem Aufruf.
///
/// Schein, Verlauf und Flammen leeren den Stapel vorher, damit die
/// Reihenfolge stimmt: Was vor einem Schein gezeichnet wurde, liegt auch
/// darunter. Die Deckkraft wird dafuer auf Sechzehntel gerundet – das sieht
/// niemand, und erst so landen hundert Funken in einem Pfad.
struct SceneBrush {

    /// Die Leinwand. Eine Kopie zeichnet auf dieselbe Flaeche; nur Zustand
    /// wie die Mischart gehoert ihr allein.
    var g: GraphicsContext

    private struct Batch {
        let stroke: Bool
        let color: Color
        let level: Int
        let width: Int
        var path: Path
    }

    private var batches: [Batch] = []

    init(_ g: GraphicsContext) {
        self.g = g
    }

    private mutating func add(stroke: Bool, _ color: Color, _ alpha: Double, width: Double = 0, _ shape: (inout Path) -> Void) {
        let level = Int((min(1, alpha) * 16).rounded())
        guard level > 0 else { return }
        let w = stroke ? max(1, Int((width * 2).rounded())) : 0
        if let i = batches.firstIndex(where: { $0.stroke == stroke && $0.level == level && $0.width == w && $0.color == color }) {
            shape(&batches[i].path)
        } else {
            var path = Path()
            shape(&path)
            batches.append(Batch(stroke: stroke, color: color, level: level, width: w, path: path))
        }
    }

    /// Zeichnet, was sich gesammelt hat.
    mutating func flush() {
        for batch in batches {
            let farbe = batch.color.opacity(Double(batch.level) / 16)
            if batch.stroke {
                let stil = StrokeStyle(lineWidth: CGFloat(batch.width) / 2, lineCap: .round, lineJoin: .round)
                g.stroke(batch.path, with: .color(farbe), style: stil)
            } else {
                g.fill(batch.path, with: .color(farbe))
            }
        }
        batches.removeAll(keepingCapacity: true)
    }

    mutating func circle(_ x: Double, _ y: Double, _ r: Double, _ color: Color, _ alpha: Double) {
        guard r > 0, alpha > 0.001 else { return }
        add(stroke: false, color, alpha) { $0.addEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)) }
    }

    mutating func fill(_ points: [SceneArt.Point], _ color: Color, _ alpha: Double) {
        guard points.count > 2, alpha > 0.001 else { return }
        add(stroke: false, color, alpha) { path in
            path.move(to: CGPoint(x: points[0].x, y: points[0].y))
            for p in points.dropFirst() { path.addLine(to: CGPoint(x: p.x, y: p.y)) }
            path.closeSubpath()
        }
    }

    mutating func stroke(_ points: [SceneArt.Point], _ color: Color, _ alpha: Double, _ width: Double) {
        guard points.count > 1, alpha > 0.001 else { return }
        add(stroke: true, color, alpha, width: width) { path in
            path.move(to: CGPoint(x: points[0].x, y: points[0].y))
            for p in points.dropFirst() { path.addLine(to: CGPoint(x: p.x, y: p.y)) }
        }
    }

    /// Ein Stern mit vier Zacken.
    mutating func sparkle(_ x: Double, _ y: Double, _ r: Double, _ turn: Double, _ color: Color, _ alpha: Double) {
        guard r > 0 else { return }
        var zacken: [SceneArt.Point] = []
        for k in 0..<8 {
            let winkel = turn + Double(k) * .pi / 4
            let weite = k % 2 == 0 ? r : r * 0.28
            zacken.append((x + cos(winkel) * weite, y + sin(winkel) * weite))
        }
        fill(zacken, color, alpha)
    }

    mutating func glow(_ x: Double, _ y: Double, _ r: Double, _ color: Color, _ alpha: Double) {
        flush()
        SceneArt.glow(&g, x, y, r, color, alpha)
    }

    /// Flaeche mit Verlauf. Die Orte der Stopps werden in 0...1 und in
    /// aufsteigende Reihenfolge gebracht – manche Szene rechnet sie aus
    /// Hoehen, die ueber den Rand hinausgehen.
    mutating func fill(_ points: [SceneArt.Point], from: SceneArt.Point, to: SceneArt.Point, _ stops: [(Double, Color, Double)]) {
        flush()
        var bisher = 0.0
        let geordnet: [(Double, Color, Double)] = stops.map { stopp in
            bisher = max(bisher, SceneArt.clamp(stopp.0))
            return (bisher, stopp.1, max(0, min(1, stopp.2)))
        }
        SceneArt.fill(&g, points, from: from, to: to, geordnet)
    }

    /// Ein beliebiger Pfad mit Verlauf – etwa alle Saeulen eines Equalizers
    /// in einem Aufruf.
    mutating func fill(_ path: Path, from: SceneArt.Point, to: SceneArt.Point, _ colors: [Color]) {
        flush()
        g.fill(path, with: .linearGradient(Gradient(colors: colors), startPoint: CGPoint(x: from.x, y: from.y), endPoint: CGPoint(x: to.x, y: to.y)))
    }

    /// Eine Flammenzunge, dieselbe wie beim Riss und im Kranz.
    mutating func tongue(_ p: SceneArt.Point, _ richtung: Double, _ laenge: Double, _ breite: Double, _ alpha: Double, _ t: Double, _ k: Int) {
        flush()
        RingTearArt.tongue(&g, p, richtung, laenge, breite, alpha, t, k)
    }

    /// Ab hier wird hell auf hell addiert – fuer Feuer. Der Stapel wird
    /// vorher geleert, sonst bekaeme er die Mischart mit.
    mutating func blend(_ mode: GraphicsContext.BlendMode) {
        flush()
        g.blendMode = mode
    }
}

// MARK: - Die Szenen

enum RingSceneArt {

    typealias Point = SceneArt.Point

    private static let tau = 2 * Double.pi

    // Dinge mit eigener Farbe – Bier ist bernstein, egal welches Schema gilt
    private static let wet = SceneArt.rgb(255, 236, 200)
    private static let paintShadow = SceneArt.rgb(30, 16, 4)
    private static let bristleLight = SceneArt.rgb(255, 190, 90)
    private static let bristleDark = SceneArt.rgb(200, 120, 30)
    private static let beerTop = SceneArt.rgb(250, 190, 80)
    private static let beerDark = SceneArt.rgb(90, 50, 10)
    private static let foamShade = SceneArt.rgb(200, 170, 120)
    private static let white = Color.white
    private static let streamEdge = SceneArt.rgb(255, 220, 150)
    private static let thunderCloud = SceneArt.rgb(48, 54, 78)
    private static let heavenCloud = SceneArt.rgb(50, 46, 60)
    private static let inkWet = SceneArt.rgb(255, 210, 140)
    private static let pulseLight = SceneArt.rgb(200, 255, 190)
    private static let pulseCore = SceneArt.rgb(230, 255, 220)
    private static let curtainDark = SceneArt.rgb(70, 8, 16)
    private static let curtainMid = SceneArt.rgb(140, 24, 34)
    private static let curtainDeep = SceneArt.rgb(50, 4, 10)
    private static let cardFar = SceneArt.rgb(120, 110, 100)
    private static let ink = Color(red: 0.11, green: 0.1, blue: 0.1)

    // MARK: Werkzeug

    private static func clamp(_ x: Double) -> Double { SceneArt.clamp(x) }
    private static func easeOut(_ x: Double) -> Double { SceneArt.easeOut(x) }
    private static func easeIn(_ x: Double) -> Double { SceneArt.easeIn(x) }
    private static func fract(_ x: Double) -> Double { SceneArt.fract(x) }
    private static func unit(_ i: Int, _ seed: Int) -> Double { SceneArt.unit(i, seed) }
    private static func noise(_ i: Int, _ seed: Int) -> Double { SceneArt.noise(i, seed) }

    private static func smooth(_ x: Double) -> Double {
        let c = clamp(x)
        return c * c * (3 - 2 * c)
    }

    private static func bell(_ s: Double, _ breite: Double) -> Double {
        let q = s / breite
        return exp(-q * q)
    }

    /// Wie nah der Augenblick am Schlag liegt: 1 genau dort, weich abfallend.
    private static func hitPulse(_ t: Double, _ hit: Double, _ breite: Double = 0.18) -> Double {
        bell(t - hit, breite)
    }

    /// Ein Zyklus des Nachhalls: seine Nummer (-1 vor dem Start) und die
    /// Zeit darin. Die Nummer geht in EffectNoise – so variiert jede Runde.
    private static func zyklus(_ t: Double, _ start: Double, _ laenge: Double) -> (n: Int, z: Double) {
        let s = t - start
        guard s >= 0 else { return (-1, s) }
        let n = Int((s / laenge).rounded(.down))
        return (n, s - Double(n) * laenge)
    }

    private static func sign(_ x: Double) -> Double {
        x > 0 ? 1 : (x < 0 ? -1 : 0)
    }

    // MARK: 2

    /// Pinsel: holt am Rand aus, zieht einen Pfeil zur Karte, spritzt beim Schlag.
    static func pointAt(_ b: inout SceneBrush, _ s: RingStage, _ t: Double) {
        let w = s.w, h = s.h, hit = s.hit
        let akzent = BeerStatsColor.accent
        let ersteRunde = t < hit + 3.2
        let zyk = zyklus(t, hit + 3.2, 3.4)
        let runde = ersteRunde ? 0 : zyk.n + 1
        let z = ersteRunde ? t : zyk.z
        let zielZeit = runde == 0 ? hit : 0.45
        let links = runde % 2 == 0
        let biege = 0.8 + 0.5 * unit(runde, 120)
        let ziel: Point = (Double(s.card.minX) - 4, s.cardMidY + 4 + 30 * noise(runde, 121))
        let start: Point = (-30, h * (0.98 - 0.12 * unit(runde, 122)))
        let knick: Point = (w * 0.03 * biege, h * (0.12 + 0.1 * unit(runde, 123)))
        func bahn(_ p: Double) -> Point {
            let u = 1 - p
            let x: Double = u * u * start.x + 2 * u * p * knick.x + p * p * ziel.x
            let y: Double = u * u * start.y + 2 * u * p * knick.y + p * p * ziel.y
            return (links ? x : w - x, y)
        }
        let weg = runde == 0 ? 1 : 1 - clamp((z - 2.4) / 0.9)

        // Auftakt: Farbe sammelt sich am Rand, glaenzend
        let lade = runde == 0 ? clamp(z / (hit * 0.5)) * (1 - clamp((z - hit * 0.5) / 0.15)) : 0
        if lade > 0 {
            let q = bahn(0.02)
            b.circle(q.x, q.y, 30 * lade, akzent, 0.6)
            b.circle(q.x - 8, q.y - 10, 8 * lade, wet, 0.5)
        }
        let vorlauf = runde == 0 ? hit * 0.5 : 0
        let strichDauer = zielZeit * (runde == 0 ? 0.5 : 1)
        let fort = easeOut(clamp((z - vorlauf) / strichDauer))
        guard fort > 0, weg > 0 else { return }
        let punkte: [Point] = (0...30).map { bahn(Double($0) / 30 * fort) }

        // Hinten: ein weicher Schleier und der Schatten des Strichs
        b.stroke(punkte, akzent, 0.1 * weg, 96)
        b.stroke(punkte.map { ($0.x + 4, $0.y + 12) }, paintShadow, 0.3 * weg, 60)
        // Mitte: der Strich mit Borsten, die zum Ende hin ausfransen
        b.stroke(punkte, akzent, 0.5 * weg, 40)
        for k in 0..<7 {
            let versatz = Double(k - 3) * 5.6
            var borste: [Point] = []
            for i in 0..<punkte.count {
                let vor = punkte[min(i + 1, punkte.count - 1)], nach = punkte[max(i - 1, 0)]
                let dx = vor.x - nach.x, dy = vor.y - nach.y
                let laenge = hypot(dx, dy)
                let l = laenge > 0 ? laenge : 1
                let franse = Double(i) > Double(punkte.count) * 0.75 ? 1 + 0.6 * noise(k * 9 + i, 124) : 1
                borste.append((punkte[i].x - dy / l * versatz * franse, punkte[i].y + dx / l * versatz * franse))
            }
            b.stroke(borste, k % 2 == 1 ? bristleLight : bristleDark, 0.55 * weg, k % 2 == 1 ? 1.6 : 3)
        }
        b.stroke(punkte.map { ($0.x - 3, $0.y - 9) }, wet, 0.45 * weg, 3)

        // Die Spitze stoesst beim Schlag nach und zittert
        let spitze = punkte[punkte.count - 1], davor = punkte[max(0, punkte.count - 3)]
        let winkel = atan2(spitze.y - davor.y, spitze.x - davor.x)
        let seit = z - zielZeit
        let stoss = seit > 0 ? 11 * exp(-seit * 9) * sin(seit * 40) : 0
        let kopf: Point = (spitze.x + cos(winkel) * stoss, spitze.y + sin(winkel) * stoss)
        func seite(_ d: Double, _ a: Double) -> Point { (kopf.x + cos(winkel + a) * d, kopf.y + sin(winkel + a) * d) }
        if fort > 0.6 {
            b.fill([seite(6, 0), seite(42, 2.5), seite(12, .pi), seite(42, -2.5)], akzent, 0.92 * weg)
            b.stroke([seite(36, 2.5), seite(8, 0)], wet, 0.5 * weg, 2)
        }
        guard seit > 0 else { return }

        // Vorne: Spritzer nach oben und zur Seite, die liegen bleiben und
        // dann herablaufen – nie bis in den Text
        let neigung: Double = links ? 0.25 : -0.25
        for i in 0..<12 {
            let u = min(seit, 0.42)
            let wink = -Double.pi / 2 + neigung + (unit(i + runde * 13, 11) - 0.5) * 2.2
            let weit = (150 + 170 * unit(i, 12)) * easeOut(u / 0.42) * 0.55
            let x = kopf.x + cos(wink) * weit
            let y = kopf.y + sin(wink) * weit + 90 * u * u
            let r = 2.5 + 4.5 * unit(i, 13)
            let lauf = min(26 * easeOut((seit - 0.5) / 1.6) * unit(i, 14), max(0, s.textTop - 24 - y))
            let bl = s.faint(y + lauf, rest: 0)
            if lauf > 0 { b.stroke([(x, y), (x, y + lauf)], akzent, 0.55 * weg * bl, r * 0.8) }
            b.circle(x, y + lauf, r, akzent, 0.85 * weg * bl)
            b.circle(x - r * 0.3, y + lauf - r * 0.35, r * 0.35, wet, 0.7 * weg * bl)
        }
        for i in 0..<5 {
            let q = punkte[6 + i * 4]
            let grenze = q.y < s.textTop ? s.textTop - 30 - q.y : 80
            let lang = min(80 * easeOut((seit - 0.15 * Double(i)) / 1.9), grenze)
            let imText = q.y > s.textTop - 30 && q.y < s.textBottom + 10 && abs(q.x - w / 2) < w * 0.42
            if lang <= 0 || imText { continue }
            b.stroke([(q.x, q.y + 12), (q.x, q.y + 12 + lang)], akzent, 0.5 * weg, 4.5)
            b.circle(q.x, q.y + 14 + lang, 5, akzent, 0.7 * weg)
            b.circle(q.x - 1.5, q.y + 12 + lang, 1.6, wet, 0.7 * weg)
        }
    }

    // MARK: 3

    /// Bier schiesst hoch, kraeuselt sich beim Aufprall der Karte.
    static func drinkSelf(_ b: inout SceneBrush, _ s: RingStage, _ t: Double) {
        let w = s.w, h = s.h, hit = s.hit
        let ds = t - hit
        // So hoch steigt das Bier: bis knapp unter den Text, nie darueber
        let ziel = min(h * 0.17, max(h * 0.06, h - s.textBottom - 10))
        let steig = easeOut(t / hit)
        let schwapp = ds > 0 ? 14 * exp(-ds * 2.6) * cos(ds * 9) : 0
        let hub = t < hit ? 16 * easeIn(t / hit) : 16 * exp(-ds * 4)
        let pegel = h - ziel * steig - schwapp - hub
        let boe = zyklus(t, hit + 1.5, 2.8).n
        let gust = boe >= 0 ? 0.5 + unit(boe, 130) : 1
        let amp = 5 + 9 * exp(-max(0, ds) * 2) * gust

        // Kraeuseln: ein Wellenpaket laeuft beim Schlag von der Mitte nach aussen
        func kraeusel(_ x: Double) -> Double {
            guard ds >= 0, ds <= 2 else { return 0 }
            let d = abs(x - w / 2), front = ds * 160
            let paket = (d - front) / 26
            return 9 * exp(-ds * 1.6) * exp(-paket * paket) * sin(d * 0.3 - ds * 18)
        }
        func oben(_ x: Double) -> Double {
            let welle: Double = amp * sin(x * 0.035 + t * 2.6) + 3.5 * sin(x * 0.09 - t * 3.7)
            return pegel + welle + kraeusel(x)
        }
        func hinten(_ x: Double) -> Double {
            pegel - 14 + 0.6 * amp * sin(x * 0.028 - t * 1.6 + 1)
        }

        // Hinten: dunkle zweite Schicht mit feinen Perlen
        var rueck: [Point] = (0...30).map { i in
            let x = w * Double(i) / 30
            return (x, hinten(x))
        }
        rueck.append((w, h + 10))
        rueck.append((0, h + 10))
        b.fill(rueck, from: (0, pegel - 20), to: (0, h), [(0, SceneArt.beerDeep, 0.32), (1, beerDark, 0.4)])
        for i in 0..<30 {
            let z = fract(t * (0.12 + 0.1 * unit(i, 131)) + unit(i, 132)), x = w * unit(i, 133)
            let y = h - (h - pegel) * z
            if y > hinten(x) + 4 { b.circle(x, y, 0.9 + unit(i, 134), SceneArt.foam, 0.25) }
        }

        // Mitte: der Koerper mit Glanzkante wie an einem Glas
        var koerper: [Point] = (0...40).map { i in
            let x = w * Double(i) / 40
            return (x, oben(x))
        }
        koerper.append((w, h + 10))
        koerper.append((0, h + 10))
        b.fill(koerper, from: (0, pegel), to: (0, h), [(0, beerTop, 0.62), (0.4, SceneArt.beer, 0.6), (1, SceneArt.beerDeep, 0.7)])
        b.fill([(w * 0.08, pegel + 12), (w * 0.13, pegel + 12), (w * 0.11, h), (w * 0.06, h)], from: (0, pegel), to: (0, h),
               [(0, SceneArt.foam, 0.35), (1, SceneArt.foam, 0)])
        b.glow(w / 2, pegel, w * 0.75, SceneArt.beer, 0.16 + 0.2 * hitPulse(t, hit))

        // Schaumkrone mit Schatten unten und Licht oben
        for reihe in 0..<2 {
            let rf = Double(reihe)
            for i in 0..<18 {
                let di = Double(i)
                let x = (di + 0.5 + rf * 0.5) / 18 * w + noise(i + reihe * 40, 2) * 8
                let platzt = fract(t * (0.4 + 0.3 * unit(i, 21 + reihe)) + unit(i, 22))
                let basis: Double = reihe == 1 ? 6 : 9
                let r = (basis + 5 * unit(i, 3) + 1.5 * sin(t * 3 + di)) * (platzt < 0.08 ? platzt / 0.08 : 1)
                let y = oben(x) - 2 - rf * 7
                b.circle(x, y + r * 0.25, r, foamShade, reihe == 1 ? 0.35 : 0.5)
                b.circle(x, y, r * 0.92, SceneArt.foam, reihe == 1 ? 0.42 : 0.58)
                if reihe == 0 { b.circle(x - r * 0.3, y - r * 0.35, r * 0.25, white, 0.6) }
            }
        }

        // Vorne: grosse Blasen mit Lichtpunkt, die an der Oberflaeche zerplatzen
        for i in 0..<12 {
            let z = fract(t * (0.3 + 0.2 * unit(i, 135)) + unit(i, 136))
            let x = w * unit(i, 137) + 8 * sin(t * 3 + Double(i))
            let y = h - (h - pegel - 8) * z
            let r = 3 + 3.5 * unit(i, 138)
            if y > oben(x) + 8 {
                b.circle(x, y, r, SceneArt.foam, 0.28)
                b.stroke(SceneArt.arc(x, y, r, 0, tau, 14), SceneArt.foam, 0.5, 1)
                b.circle(x - r * 0.35, y - r * 0.35, r * 0.3, white, 0.8)
            } else if z > 0.95 {
                b.stroke(SceneArt.arc(x, oben(x), r * (1 + (z - 0.95) * 30), .pi, tau, 10), SceneArt.foam, 0.5 * (1 - (z - 0.95) * 20), 1.2)
            }
        }

        // Schwall beim Schlag: Tropfen an den Raendern, nie in den Text
        guard ds > 0, ds < 0.9 else { return }
        let rest = 1 - ds / 0.9
        for i in 0..<14 {
            let rand = unit(i, 34) < 0.5
            let x0 = w * (rand ? 0.01 + 0.15 * unit(i, 30) : 0.84 + 0.15 * unit(i, 30))
            let v = 220 + 140 * unit(i, 31)
            let y = oben(x0) - v * ds + 560 * ds * ds
            guard y < oben(x0) else { continue }
            let r = 2.5 + 2.5 * unit(i, 33)
            let richtung: Double = rand ? 1 : -1
            let x = x0 + richtung * 30 * ds * unit(i, 32)
            b.circle(x, y, r, SceneArt.beer, 0.85 * rest)
            b.circle(x - r * 0.3, y - r * 0.3, r * 0.35, SceneArt.foam, 0.8 * rest)
        }
    }

    // MARK: 4

    /// Fuenf Stroeme stuerzen nacheinander herab; der mittlere trifft mit der Karte.
    static func waterfall(_ b: inout SceneBrush, _ s: RingStage, _ t: Double) {
        let w = s.w, h = s.h, hit = s.hit
        let boden = h - 30, takt = hit / 5

        // Hinten: Spruehnebel, der langsam zieht
        for i in 0..<7 {
            let richtung: Double = i % 2 == 1 ? 1 : -1
            let x = fract(Double(i) / 7 + t * 0.02 * richtung) * w
            let y = h * (0.12 + 0.12 * unit(i, 140))
            b.glow(x, y, 80 + 40 * unit(i, 141), SceneArt.foam, 0.05 * easeOut(t / hit))
        }
        var angekommen = 0
        let nachhall = zyklus(t, hit + 1, 2.6).n
        for i in 0..<5 {
            let di = Double(i)
            let tt = t - di * takt
            guard tt > 0 else { continue }
            let mitte = i >= 1 && i <= 3
            let staerke: Double = mitte ? 0.42 : 1
            let x = w * (0.1 + 0.2 * di) + noise(i, 1) * 14
            let grund: Double = (i == 0 || i == 4) ? 15 : 9
            let schwank = nachhall >= 0 ? 0.85 + 0.3 * unit(nachhall * 5 + i, 142) : 1
            let breite = (grund + 7 * unit(i, 2)) * schwank
            let ende = min(boden, h * 1.15 * easeOut(tt / 0.42))
            func welle(_ y: Double) -> Double { 3 * sin(y * 0.05 - t * 10 + di) }
            var links: [Point] = [], rechts: [Point] = []
            for k in 0...24 {
                let y = -10 + (ende + 10) * Double(k) / 24
                let schmal = 1 - 0.3 * Double(k) / 24
                links.append((x - breite / 2 * schmal + welle(y), y))
                rechts.append((x + breite / 2 * schmal + welle(y), y))
            }
            // Mitte: dunkler Kern, helle Raender im Gegenlicht – im Textband blass
            let lo = s.textTop / max(ende, 1), lu = s.textBottom / max(ende, 1)
            let band: Double = mitte ? 0.18 : 0.6
            b.fill(links + rechts.reversed(), from: (x, 0), to: (x, ende), [
                (0, SceneArt.beerDeep, 0.25 * staerke),
                (lo - 0.05, SceneArt.beer, 0.45 * staerke),
                (lo, SceneArt.beer, 0.45 * staerke * band),
                (lu, SceneArt.beer, 0.55 * staerke * band),
                (lu + 0.05, SceneArt.beer, 0.6 * staerke),
                (1, SceneArt.beer, 0.6 * staerke)
            ])
            // Die Kanten der mittleren Stroeme setzen im Text aus – als zwei
            // Stuecke, nicht als eine Linie, die quer durch den Text springt
            let teile: [[Point]] = mitte
                ? [links.filter { $0.y < s.textTop - 10 }, links.filter { $0.y > s.textBottom + 10 },
                   rechts.filter { $0.y < s.textTop - 10 }, rechts.filter { $0.y > s.textBottom + 10 }]
                : [links, rechts]
            for (n, teil) in teile.enumerated() {
                let istLinks = mitte ? n < 2 : n == 0
                b.stroke(teil, istLinks ? SceneArt.foam : streamEdge, (istLinks ? 0.4 : 0.3) * staerke, istLinks ? 1.6 : 1.2)
            }
            for k in 0..<4 {
                let y = fract(t * 2.2 + Double(k) / 4 + unit(i, 4)) * ende
                let blass = mitte ? s.faint(y + 13, rest: 0.1) : 1
                b.stroke([(x + welle(y), y), (x + welle(y + 26), y + 26)], SceneArt.foam, 0.55 * staerke * blass, 2.4)
            }
            if ende < boden {
                b.circle(x + welle(ende), ende, breite * 0.7, SceneArt.foam, 0.6 * staerke)
                continue
            }
            angekommen += 1
            let auf = tt - 0.42
            let platscher = auf < 0.5 ? 1 - auf / 0.5 : 0
            b.glow(x, boden, 46 + 24 * platscher, SceneArt.foam, 0.08 + 0.14 * platscher)
            // Vorne: Spritzer in Boegen, scharf
            for k in 0..<8 {
                let z = fract(t * 2.4 + Double(k) / 8 + unit(i, 5))
                let seite: Double = k % 2 == 1 ? 1 : -1
                let weite = seite * (18 + 30 * unit(k + i, 6))
                let sprung = (300 + 300 * platscher) * z * (1 - z) * (0.6 + 0.4 * unit(k, 7))
                let x2 = x + weite * z, y2 = boden - sprung
                b.circle(x2, y2, 2 + 1.8 * unit(k, 8), SceneArt.foam, 0.65 * (1 - z))
                b.circle(x2 - 0.6, y2 - 0.8, 0.8, white, 0.8 * (1 - z))
            }
        }
        let da = Double(angekommen) / 5
        b.fill([(0, boden), (w, boden), (w, h + 5), (0, h + 5)], from: (0, boden), to: (0, h),
               [(0, SceneArt.beer, 0.5 * da), (1, SceneArt.beerDeep, 0.55 * da)])
        b.stroke([(0, boden), (w, boden)], SceneArt.foam, 0.4 * da, 2)
        for i in 0..<8 {
            let richtung: Double = i % 2 == 1 ? 1 : -1
            let x = fract(Double(i) / 8 + t * 0.03 * richtung) * w
            b.glow(x, boden - 8, 80, SceneArt.foam, (0.12 + 0.25 * hitPulse(t, hit, 0.3)) * da)
        }
    }

    // MARK: 5

    /// Gewitter: Wolken, beim Schlag zwei Blitze an den Raendern bis zum Boden.
    static func lightning(_ b: inout SceneBrush, _ s: RingStage, _ t: Double) {
        let w = s.w, h = s.h, hit = s.hit
        let wolke = easeOut(t / (hit * 0.8)), wetter = clamp((t - hit * 0.5) / 0.6)

        // Hinten: Wolkenberge, von innen kurz erhellt
        for i in 0..<8 {
            let di = Double(i)
            let x = w * (di / 7) + 26 * sin(t * 0.25 + di), y = -26 + 30 * unit(i, 40)
            b.glow(x, y, 120 + 50 * unit(i, 41), thunderCloud, 0.95 * wolke)
            let flackern = sin(t * (5 + 3 * unit(i, 43)) + di * 2) * sin(t * 2.1 + di)
            let innen = max(0, flackern) * (t > hit ? 0.7 : 0.35)
            b.glow(x, y + 20, 80, SceneArt.bolt, (0.06 + 0.4 * innen) * wolke)
        }
        // Regen, schraeg – fein, damit die Mitte lesbar bleibt
        for i in 0..<40 {
            let z = fract(t * (1.6 + unit(i, 150)) + unit(i, 151))
            let x = w * unit(i, 152) - 40 * z + 20, y = -20 + (h + 40) * z
            b.stroke([(x, y), (x - 6, y + 22)], SceneArt.boltCore, 0.12 * wetter, 1)
        }
        if t >= hit && t < hit + 0.55 {
            let z = t - hit
            for links in [true, false] {
                b.glow(links ? 0 : w, h * 0.45, 240, SceneArt.bolt, 0.5 * exp(-z * 4))
                strike(&b, w, from: w * (links ? 0.08 : 0.92), seed: links ? 1 : 2, z: z, length: h - 26, left: links, strength: 1.25, grounded: true)
            }
        }
        let nach = zyklus(t, hit + 0.7, 1.3)
        if nach.n >= 0 && nach.z < 0.36 {
            let nr = nach.n + 10, links = unit(nach.n, 155) > 0.5
            let x0 = w * ((links ? 0.04 : 0.78) + 0.18 * unit(nr, 1))
            b.glow(x0, 0, 170, SceneArt.bolt, 0.28 * exp(-nach.z * 3))
            strike(&b, w, from: x0, seed: nr, z: nach.z, length: h * (0.32 + 0.3 * unit(nr, 2)), left: links, strength: 0.8, grounded: false)
        }
    }

    /// Ein Blitz am Rand: zuckt alle 0,07 Sekunden auf einen neuen Weg und
    /// bleibt in seinem Streifen – Aeste, die zur Mitte wollen, brechen ab.
    private static func strike(_ b: inout SceneBrush, _ w: Double, from x0: Double, seed nr: Int, z: Double,
                               length laenge: Double, left links: Bool, strength staerke: Double, grounded boden: Bool) {
        let schlag = Int((z / 0.07).rounded(.down))
        let hell = (0.75 + 0.25 * sin(z * 90)) * exp(-z * 5) * staerke
        let zug: Double = links ? -1.5 : 1.5
        var punkte: [Point] = [(x0, 10)]
        var x = x0
        for i in 1...12 {
            x += noise(nr * 31 + i + schlag * 7, 3) * 26 + zug
            x = links ? min(max(x, 6), w * 0.17) : max(min(x, w - 6), w * 0.83)
            punkte.append((x, 10 + laenge * Double(i) / 12))
        }
        b.stroke(punkte, SceneArt.bolt, 0.22 * hell, 26)
        b.stroke(punkte, SceneArt.bolt, 0.6 * hell, 8)
        b.stroke(punkte, SceneArt.boltCore, hell, 2.8)
        for a in 0..<3 {
            let ab = 2 + a * 3 + Int(unit(nr + a, 4) * 2)
            let aussen: Double = links ? 1 : -1
            let seite: Double = aussen * (a % 2 == 1 ? -1 : 1)
            var ast: [Point] = [punkte[ab]]
            var ax = punkte[ab].x
            for i in 1...4 {
                ax += seite * (8 + 10 * unit(nr + i + a * 5 + schlag, 5))
                ax = min(max(ax, 2), w - 2)
                if ax > w * 0.24 && ax < w * 0.76 { break }
                ast.append((ax, punkte[ab].y + laenge * 0.05 * Double(i)))
            }
            b.stroke(ast, SceneArt.bolt, 0.45 * hell, 4)
            b.stroke(ast, SceneArt.boltCore, 0.85 * hell, 1.4)
        }
        guard boden else { return }
        let e = punkte[punkte.count - 1]
        b.glow(e.x, e.y, 70, SceneArt.bolt, 0.8 * hell)
        for k in 0..<10 {
            let wk = -Double.pi / 2 + (unit(k + nr, 153) - 0.5) * 2.4
            let v = 60 + 90 * unit(k, 154), sz = min(z, 0.4)
            b.circle(e.x + cos(wk) * v * sz, e.y + sin(wk) * v * sz + 200 * sz * sz, 1.6, SceneArt.boltCore, hell)
        }
    }

    // MARK: 6

    /// Glitzer: ein Schwall ueber die Karte, Lichtkugeln dahinter, Sterne am Rand.
    static func glitter(_ b: inout SceneBrush, _ s: RingStage, _ t: Double) {
        let w = s.w, h = s.h, hit = s.hit
        let da = easeOut(t / hit)

        // Hinten: weiche Lichtkugeln, die langsam treiben
        for i in 0..<8 {
            let di = Double(i)
            let x = w * unit(i, 50) + 34 * sin(t * 0.35 + di)
            let y = h * fract((h * unit(i, 51) - 10 * t) / h)
            b.glow(x, y, 46 + 34 * unit(i, 52), i % 3 != 0 ? SceneArt.pink : SceneArt.violet, (0.1 + 0.06 * sin(t + di)) * da)
        }
        // Mitte: der Schwall zum Schlag, im Textband blass
        if t > hit * 0.6 && t < hit + 1.6 {
            for i in 0..<30 {
                let di = Double(i)
                let ss = t - hit * 0.6 - 0.012 * di
                guard ss > 0 else { continue }
                let wk = (unit(i, 60) - 0.5) * 1.2, v = 220 + 230 * unit(i, 61)
                let x = w / 2 + sin(wk) * v * ss * 0.8
                let y = -10 + cos(wk) * v * ss + 120 * ss * ss
                let a = min(1, ss * 6) * (1 - clamp((ss - 1) / 0.7))
                let funkeln = pow(max(0, sin(t * 9 + di)), 4)
                let bl = s.faint(y, rest: 0.15)
                b.sparkle(x, y, 4 + 4 * unit(i, 62) + 6 * funkeln, t + di, SceneArt.pink, 0.85 * a * bl)
                b.circle(x, y, 1.4 + funkeln * 2, SceneArt.glitterCore, a * bl)
            }
        }
        // Danach rieselt es an den Raendern – mal dichter, mal duenner
        let nachhall = zyklus(t, hit + 1.2, 3).n
        let dichte = nachhall >= 0 ? 0.6 + 0.6 * unit(nachhall, 160) : 1
        let nach = easeOut((t - hit * 0.6) / 0.8)
        for i in 0..<36 {
            let di = Double(i)
            let z = fract(t * (0.07 + 0.08 * unit(i, 1)) + unit(i, 2))
            let x = w * unit(i, 3) + 16 * sin(t * (0.8 + unit(i, 4)) + di), y = -20 + (h + 40) * z
            let funkeln = pow(max(0, sin(t * (2.4 + 2 * unit(i, 5)) + di * 1.7)), 6)
            let rand = min(1, abs(x / w - 0.5) * 2.6)
            let ein = min(1, z * 8) * min(1, (1 - z) * 6)
            let a = nach * min(1, dichte) * (0.4 + 0.6 * funkeln) * (0.2 + 0.8 * rand) * ein
            b.sparkle(x, y, 4 + 3 * unit(i, 6) + 10 * funkeln, t * 0.6 + di, SceneArt.pink, a)
            b.circle(x, y, 1.2 + funkeln * 2, SceneArt.glitterCore, a)
        }
        // Vorne: grosse Sterne am Rand, scharf, drehen sich langsam und blitzen
        for i in 0..<5 {
            let di = Double(i)
            let x = i % 2 == 1 ? w * (0.9 + 0.06 * unit(i, 161)) : w * (0.05 + 0.06 * unit(i, 161))
            let y = h * (0.1 + 0.8 * unit(i, 162))
            let funkeln = pow(max(0, sin(t * (1.2 + unit(i, 163)) + di * 2)), 3) * da
            b.glow(x, y, 40 * funkeln, SceneArt.pink, 0.45 * funkeln)
            b.sparkle(x, y, 10 + 12 * funkeln, t * 0.4 + di, SceneArt.glitterCore, 0.9 * funkeln)
        }
    }

    // MARK: 7

    /// Himmel: Wolken reissen auf, Lichtsaeulen fallen, oben oeffnet sich ein Schein.
    static func heaven(_ b: inout SceneBrush, _ s: RingStage, _ t: Double) {
        let w = s.w, h = s.h, hit = s.hit
        let auf = easeOut(t / hit)
        let nachhall = zyklus(t, hit + 1, 3.2).n
        let hell = nachhall >= 0 ? 0.85 + 0.3 * unit(nachhall, 170) : 1
        for seite in [-1.0, 1.0] {
            let x = w / 2 + seite * (16 + w * 0.56 * auf)
            for k in 0..<3 {
                let dk = Double(k)
                b.glow(x + seite * dk * 40, 8 + 18 * dk, 120 - 18 * dk, heavenCloud, 0.85 * (1 - 0.35 * auf))
                // Silberrand an der Kante, die aufreisst
                b.glow(x - seite * 50 + seite * dk * 40, 20 + 18 * dk, 50, SceneArt.light, 0.25 * auf * (1 - 0.3 * dk))
            }
        }
        b.glow(w / 2, -30, w * 0.75 * (0.4 + 0.6 * auf), SceneArt.light, (0.4 + 0.35 * hitPulse(t, hit, 0.25)) * auf * hell)
        for i in 0..<5 {
            let di = Double(i)
            let offen = easeOut((t - abs(di - 2) * hit * 0.25) / 0.5)
            guard offen > 0 else { continue }
            let x = w * (0.12 + 0.19 * di), neigung = 0.1 * sin(t * 0.6 + di * 1.7)
            let oben = 8 + 10 * unit(i, 1), unten = (60 + 50 * unit(i, 2)) * offen, ux = x + sin(neigung) * h
            let m: Double = i == 2 ? 0.5 : 1
            let weit: [Point] = [(x - oben * 2, -10), (x + oben * 2, -10), (ux + unten * 1.4, h), (ux - unten * 1.4, h)]
            b.fill(weit, from: (x, 0), to: (x, h),
                   [(0, SceneArt.light, 0.1 * offen * m * hell), (0.7, SceneArt.light, 0.03 * offen * m), (1, SceneArt.light, 0)])
            let kern: [Point] = [(x - oben * 0.6, -10), (x + oben * 0.6, -10), (ux + unten * 0.5, h), (ux - unten * 0.5, h)]
            let kernHell = (0.32 + 0.12 * sin(t * 1.3 + di)) * offen * m * hell
            b.fill(kern, from: (x, 0), to: (x, h),
                   [(0, SceneArt.light, kernHell), (0.6, SceneArt.light, 0.06 * offen * m), (1, SceneArt.light, 0)])
        }
        for i in 0..<28 {
            let di = Double(i)
            let z = fract(t * 0.07 + unit(i, 3))
            let x = w * unit(i, 4) + 20 * sin(t * 0.8 + di), y = h * (0.95 - 0.85 * z)
            let glanz = pow(max(0, sin(t * 3 + di * 2)), 8)
            b.circle(x, y, 1.1 + unit(i, 5) * 1.8, SceneArt.light, 0.6 * auf * sin(z * .pi))
            if glanz > 0.4 { b.sparkle(x, y, 5 * glanz, t + di, SceneArt.light, 0.7 * glanz * auf) }
        }
    }

    // MARK: 8

    /// Zwei Lichter: klirren unter dem Text, umrunden dann Karte und Text.
    static func drinkingMates(_ b: inout SceneBrush, _ s: RingStage, _ t: Double) {
        let w = s.w, h = s.h, hit = s.hit
        let akzent = BeerStatsColor.accent, gruen = BeerStatsColor.success
        let cx = w / 2
        // Die Schleife: ein Quadratkreis um Karte und Text. Ihre Seiten laufen
        // am Rand entlang, nie durch den Text; unten liegt sie im freien Platz
        // unter dem Text, oben knapp ueber der Karte.
        let obenY = max(8, Double(s.card.minY) - 10)
        let untenY = min(h - 12, s.textBottom + 0.3 * (h - s.textBottom))
        let mitteY = (obenY + untenY) / 2, ry = (untenY - obenY) / 2, rx = w * 0.47
        func bahn(_ a: Double) -> Point {
            let c = cos(a), sn = sin(a)
            return (cx + rx * sign(c) * sqrt(abs(c)), mitteY + ry * sign(sn) * sqrt(abs(sn)))
        }
        let unten = bahn(.pi / 2), oben = bahn(-.pi / 2)
        // Jede halbe Runde in eigenem Tempo, langsamer dort, wo sie sich treffen
        func halbe(_ n: Int) -> Double { 1.5 * (0.85 + 0.3 * unit(n, 180)) }
        func lage(_ zeit: Double) -> Double {
            var n = 0, z = zeit
            while n < 40 && z >= halbe(n) {
                z -= halbe(n)
                n += 1
            }
            let f = z / halbe(n)
            return .pi * (Double(n) + 0.5 * (f + smooth(f)))
        }
        var treffen: [(zeit: Double, n: Int)] = []
        var naechstes = hit
        for n in 0..<40 {
            guard naechstes <= t + 0.01 else { break }
            treffen.append((naechstes, n))
            naechstes += halbe(n)
        }
        func ort(_ tt: Double, _ k: Int) -> Point {
            let seite: Double = k == 1 ? 1 : -1
            guard tt >= hit else {
                let u = easeOut(tt / hit), sx = cx + seite * w * 0.62, sy = h + 40
                let x = sx + (unten.x - sx) * u, y = sy + (unten.y - sy) * u
                return (x + seite * sin(u * tau) * 16 * (1 - u), y - sin(u * .pi) * 26)
            }
            return bahn(.pi / 2 + seite * lage(tt - hit))
        }

        // Hinten: die Schleife als feiner Lichtfaden
        let da = clamp((t - hit) / 0.6)
        if da > 0 {
            let pfad: [Point] = (0...64).map { bahn(Double($0) / 64 * tau) }
            b.stroke(pfad, SceneArt.foam, 0.07 * da, 2)
        }
        // Mitte: die Lichter mit Schweif
        for (k, farbe) in [(0, gruen), (1, akzent)] {
            let schweif: [Point] = (0...10).map { ort(max(0, t - Double($0) * 0.045), k) }
            b.stroke(schweif, farbe, 0.25, 12)
            b.stroke(Array(schweif.prefix(6)), SceneArt.foam, 0.4, 3)
            for j in 1..<6 {
                let q = schweif[min(j * 2, schweif.count - 1)]
                b.sparkle(q.x, q.y, 4 * pow(max(0, sin(t * 8 + Double(j + k))), 3), t + Double(j), SceneArt.foam, 0.6)
            }
            let p = ort(t, k)
            b.glow(p.x, p.y, 55, farbe, 0.5)
            b.circle(p.x, p.y, 14, farbe, 0.75)
            b.circle(p.x, p.y, 6, SceneArt.foam, 0.9)
            b.circle(p.x - 3.5, p.y - 3.5, 2.6, white, 0.9)
        }
        // Vorne: das Klirren – das erste unter dem Text, kraeftig; danach oben
        // und unten leiser
        for treffer in treffen {
            let ss = t - treffer.zeit
            guard ss >= -0.02, ss <= 0.7 else { continue }
            let n = treffer.n
            let wo = n % 2 == 0 ? unten : oben
            let st: Double = n == 0 ? 1 : 0.5
            let a = exp(-max(0, ss) * 4.5) * st
            b.glow(wo.x, wo.y, 110 * st + 20, SceneArt.foam, 0.55 * a)
            b.sparkle(wo.x, wo.y, 40 * st * (0.6 + 0.4 * easeOut(max(0, ss) / 0.15)), 0.3, SceneArt.foam, 0.9 * a)
            let fall: Double = n % 2 == 1 ? 30 : 40
            for i in 0..<8 {
                let seite: Double = i % 2 == 1 ? 1 : -1
                let wk = (unit(i + n * 8, 181) - 0.5) * 0.7
                let d = 24 + 90 * easeOut(max(0, ss) / 0.6) * (0.5 + 0.5 * unit(i, 182)) * st
                let x = wo.x + seite * cos(wk) * d, y = wo.y + sin(wk) * d * 0.5 + fall * ss * ss
                let r = (3 + 3 * unit(i, 183)) * (0.6 + 0.4 * st)
                b.fill([(x, y - r * 1.6), (x + r, y), (x, y + r * 1.6), (x - r, y)], SceneArt.foam, 0.8 * a)
            }
        }
    }

    // MARK: 9

    /// Equalizer: pumpt am unteren Rand, Schallwellen laufen mit jedem Schlag hoch.
    static func rhyme(_ b: inout SceneBrush, _ s: RingStage, _ t: Double) {
        let w = s.w, h = s.h, hit = s.hit
        let akzent = BeerStatsColor.accent, violett = SceneArt.violet
        // Drei Spruenge der Karte, dann ein Takt alle halbe Sekunde
        let schlaege = [hit / 3, 2 * hit / 3, hit]
        var letzter = -1.0, beat = -1
        for i in 0..<3 where t >= schlaege[i] {
            letzter = schlaege[i]
            beat = i
        }
        if t > hit {
            let n = Int(((t - hit) / 0.5).rounded(.down))
            letzter = hit + Double(n) * 0.5
            beat = 3 + n
        }
        let seit = letzter >= 0 ? t - letzter : 9
        let puls = exp(-seit * 6), drop = hitPulse(t, hit, 0.2)

        // Hinten: Lautsprecherringe in den unteren Ecken
        for x0 in [0, w] {
            for k in 0..<4 {
                let dk = Double(k)
                let r = 30 + dk * 22 + 6 * puls
                b.stroke(SceneArt.arc(x0, h - 20, r, 0, tau, 40), violett, (0.18 - dk * 0.035) * (0.5 + puls), 3)
            }
        }
        // Mitte: Schallwellen, ueber dem Text nur an den Seiten kraeftig
        for k in 0..<7 {
            let nr = beat - k
            guard nr >= 0 else { continue }
            let start = nr < 3 ? schlaege[nr] : hit + Double(nr - 3) * 0.5
            let z = (t - start) / 2.2
            guard z <= 1 else { continue }
            let r = 40 + h * 0.95 * easeOut(z)
            let farbe = nr % 4 == 0 ? akzent : violett
            let mitteBlass = s.faint(h + 40 - r, rest: 0.2)
            let stuecke: [(Double, Double, Double)] = [(1.08, 1.3, 1), (1.3, 1.7, mitteBlass), (1.7, 1.92, 1)]
            for (a0, a1, f) in stuecke {
                let bogen = SceneArt.arc(w / 2, h + 40, r, .pi * a0, .pi * a1, 14)
                b.stroke(bogen, farbe, 0.25 * (1 - z) * f, 18 * (1 - z * 0.6))
                b.stroke(bogen, farbe, 0.55 * (1 - z) * f, 5 * (1 - z * 0.6))
            }
        }
        b.glow(w / 2, h + 20, 220, violett, 0.3 + 0.3 * puls + 0.3 * drop)

        // Vorne: Saeulen mit glaenzender Kappe und einer Spitzenmarke, die langsam faellt
        let anzahl = 15, bw = w / 15
        let wachs = easeOut(t / (hit / 3 + 0.01))
        var saeulen = Path()
        var kappen: [(x: Double, x2: Double, oben: Double, spitze: Double)] = []
        for i in 0..<anzahl {
            let di = Double(i)
            let lauf = 0.35 + 0.35 * abs(sin(t * (3 + 2 * unit(i, 70)) + di))
            let kraft = 0.5 + 0.8 * puls + 0.6 * drop
            let roh = 22 + 70 * lauf * kraft * (0.6 + 0.4 * unit(i, 71))
            let hoehe = min(84, roh) * wachs
            let x = di * bw + bw * 0.18, breite = bw * 0.64
            saeulen.addRect(CGRect(x: x, y: h - hoehe, width: breite, height: hoehe))
            kappen.append((x, x + breite, h - hoehe, min(84, hoehe + 8 + 18 * exp(-seit * 2))))
        }
        // Alle Saeulen in einem Aufruf, mit einem Verlauf ueber die ganze Hoehe
        b.fill(saeulen, from: (0, h), to: (0, h - 84), [violett.opacity(0.7), akzent.opacity(0.55)])
        for k in kappen {
            b.fill([(k.x, k.oben), (k.x2, k.oben), (k.x2, k.oben + 3), (k.x, k.oben + 3)], SceneArt.foam, 0.7)
            b.fill([(k.x, h - k.spitze), (k.x2, h - k.spitze), (k.x2, h - k.spitze + 2), (k.x, h - k.spitze + 2)], akzent, 0.6)
        }
    }

    // MARK: 10

    /// Stempel: senkt sich mit Schatten, knallt um die Karte, Tinte spritzt nach oben.
    static func rule(_ b: inout SceneBrush, _ s: RingStage, _ t: Double) {
        let hit = s.hit
        let cx = s.cardMidX, cy = s.cardMidY, farbe = BeerStatsColor.warning
        // Der Abdruck liegt knapp um die Karte
        let rand = Double(s.card.height) / 2 + 5
        if t < hit {
            let u = t / hit, gross = 1 - easeIn(u)
            b.glow(cx, cy, 120 + 240 * gross, .black, 0.6 * easeOut(u))
            // Die Stempelflaeche kommt von oben, gross und unscharf
            b.stroke(SceneArt.arc(cx, cy, rand * (1 + 2.2 * gross), 0, tau, 60), farbe, 0.3 * u, 12 * (1 + gross))
            b.stroke(SceneArt.arc(cx, cy, (rand - 22) * (1 + 2.2 * gross), 0, tau, 60), farbe, 0.2 * u, 5 * (1 + gross))
            return
        }
        let ds = t - hit, blass = 0.72 + 0.28 * exp(-ds * 1.2)
        // Hinten: die Tinte zieht ins Papier, ein weicher Hof
        b.glow(cx, cy, rand + 56 + 30 * easeOut(ds / 3), farbe, 0.12 * blass)
        func rauh(_ r: Double, _ n: Int, _ seed: Int) -> [Point] {
            (0...n).map { i in
                let a = Double(i) / Double(n) * tau, rr = r + 4 * noise(i, seed)
                return (cx + cos(a) * rr, cy + sin(a) * rr)
            }
        }
        b.stroke(rauh(rand, 72, 80), farbe, 0.65 * blass, 11)
        b.stroke(rauh(rand - 22, 60, 81), farbe, 0.5 * blass, 4)
        for i in 0..<24 {
            let wi = 0.15 + Double(i) / 24 * tau, dx = cos(wi), dy = sin(wi)
            b.stroke([(cx + dx * (rand - 17), cy + dy * (rand - 17)), (cx + dx * (rand - 7), cy + dy * (rand - 7))], farbe, 0.55 * blass, 4)
        }
        // Nasser Glanz, der einmal ueber den Abdruck wandert und dann trocknet
        let glanz = clamp((ds - 0.15) / 1.4)
        if glanz < 1 {
            let a1 = -Double.pi / 2 + glanz * tau
            b.stroke(SceneArt.arc(cx, cy, rand, a1 - 0.5, a1, 16), inkWet, 0.6 * (1 - glanz), 3)
        }
        // Vorne: Tintenfaeden und Kleckse, nach oben und zur Seite – nie in den Text
        let z = easeOut(min(ds, 0.35) / 0.35)
        for i in 0..<16 {
            let wi = -Double.pi * 0.05 - unit(i, 1) * .pi * 1.1
            let d = rand + 10 + 100 * unit(i, 2) * z
            let x = cx + cos(wi) * d, y = cy + sin(wi) * d
            let r = (4 + 8 * unit(i, 3)) * (0.6 + 0.4 * z)
            let faden: Point = (cx + cos(wi) * (rand + 2), cy + sin(wi) * (rand + 2))
            b.stroke([faden, (x, y)], farbe, (ds < 0.35 ? 0.5 : 0.25) * blass, 2.2 * (1 - 0.5 * z))
            b.circle(x, y, r, farbe, 0.6 * blass)
            b.circle(x - r * 0.3, y - r * 0.35, r * 0.3, inkWet, 0.55 * blass)
        }
        b.glow(cx, cy, rand + 106, farbe, 0.45 * exp(-ds * 7))
        // Nachhall: ab und zu laeuft ein feiner Ring vom Abdruck weg
        let nach = zyklus(t, hit + 0.8, 2.6)
        if nach.n >= 0 {
            let q = nach.z / 2.6
            b.stroke(SceneArt.arc(cx, cy, rand + 10 + 50 * easeOut(q), 0, tau, 60), farbe, 0.16 * (1 - q) * (0.7 + 0.6 * unit(nach.n, 190)), 2)
        }
    }

    // MARK: 11

    /// Herzschlag: der Rand pulst, Boegen laufen aus den Ecken, unten eine Herzkurve.
    static func thumbMaster(_ b: inout SceneBrush, _ s: RingStage, _ t: Double) {
        let w = s.w, h = s.h, hit = s.hit
        let gruen = BeerStatsColor.success
        let nachhall = zyklus(t, hit, 1.1).n
        let periode = 1.1 * (nachhall >= 1 ? 0.92 + 0.16 * unit(nachhall, 200) : 1)
        let z = fract((t - hit + 0.1 * periode) / periode)
        let erster = (z - 0.1) / 0.05, zweiter = (z - 0.3) / 0.06
        let staerker: Double = (t > hit - 0.15 && t < hit + 0.5) ? 1.15 : 1
        let auftakt: Double = t < hit - 0.15 ? 0.4 : staerker
        let puls = max(exp(-erster * erster), 0.7 * exp(-zweiter * zweiter)) * auftakt
        // Begrenzt: Im Browser flutete das Gruen beim Schlag den ganzen Screen
        let a = min(0.45, 0.12 + 0.33 * puls), d = 40 + 18 * min(1.2, puls)
        let verlauf: [(Double, Color, Double)] = [(0, gruen, a), (1, gruen, 0)]
        b.fill([(0, 0), (w, 0), (w, d), (0, d)], from: (0, 0), to: (0, d), verlauf)
        b.fill([(0, h - d), (w, h - d), (w, h), (0, h)], from: (0, h), to: (0, h - d), verlauf)
        b.fill([(0, 0), (d, 0), (d, h), (0, h)], from: (0, 0), to: (d, 0), verlauf)
        b.fill([(w - d, 0), (w, 0), (w, h), (w - d, h)], from: (w, 0), to: (w - d, 0), verlauf)
        // Mitte: aus den Ecken laeuft je Schlag ein Bogen nach innen
        if t > hit - 0.15 {
            let ecken: [Point] = [(0, 0), (w, 0), (0, h), (w, h)]
            for e in ecken {
                let r = 20 + 140 * z, al = 0.35 * (1 - z) * min(1, puls * 2 + 0.2)
                let a0 = atan2(h / 2 - e.y, w / 2 - e.x) - 0.6
                b.stroke(SceneArt.arc(e.x, e.y, r, a0, a0 + 1.2, 16), gruen, al, 3)
            }
        }
        // Vorne: eine Herzkurve, die unten mitlaeuft
        let basis = h - 40, kopf = fract(t / 2.2) * (w + 60) - 30
        func kurve(_ x: Double) -> Double {
            let zeit = t - (kopf - x) / ((w + 60) / 2.2)
            let zz = fract((zeit - hit + 0.1 * periode) / periode)
            let q = (zz - 0.1) / 0.018, r = (zz - 0.3) / 0.02, m = (zz - 0.13) / 0.015
            let zacke: Double = 34 * exp(-q * q) - 12 * exp(-m * m) + 20 * exp(-r * r)
            return basis - zacke
        }
        var punkte: [Point] = []
        var x = max(0, kopf - 220)
        while x <= kopf {
            punkte.append((x, kurve(x)))
            x += 3
        }
        if punkte.count > 1 {
            b.stroke(punkte, gruen, 0.22, 9)
            b.stroke(punkte, pulseLight, 0.9, 2.2)
        }
        b.glow(kopf, kurve(kopf), 20, gruen, 0.85)
        b.circle(kopf, kurve(kopf), 3, pulseCore, 1)
    }

    // MARK: 12

    /// Buehne: Vorhang, zwei Scheinwerfer flammen auf, beim Schlag glueht die Rampe.
    static func queen(_ b: inout SceneBrush, _ s: RingStage, _ t: Double) {
        let w = s.w, h = s.h, hit = s.hit
        let ziel: Point = (s.cardMidX, s.cardMidY), dunkel = easeOut(t / 0.3)
        let warn = BeerStatsColor.warning
        // Die Buehne wird dunkel bis auf die Karte
        b.flush()
        b.g.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .radialGradient(
            Gradient(colors: [Color.black.opacity(0), Color.black.opacity(0.6 * dunkel)]),
            center: CGPoint(x: ziel.x, y: ziel.y), startRadius: 60, endRadius: h * 0.9))
        // Hinten: Vorhaenge an beiden Seiten, Falten als Verlauf – schmal, der Text beginnt dahinter
        for seite in [-1.0, 1.0] {
            for k in 0..<3 {
                let dk = Double(k)
                let x0 = seite < 0 ? dk * 9 : w - dk * 9, breite = 11.0, wiegt = 2 * sin(t * 0.8 + dk)
                b.fill([(x0, -5), (x0 - seite * breite, -5), (x0 - seite * breite + wiegt, h + 5), (x0 + wiegt, h + 5)],
                       from: (x0 - seite * breite, 0), to: (x0, 0),
                       [(0, curtainDark, 0.85 * dunkel), (0.5, curtainMid, 0.75 * dunkel), (1, curtainDeep, 0.85 * dunkel)])
            }
        }
        // Mitte: zwei Scheinwerfer, nacheinander, mit kurzem Flackern beim Zuenden
        for vonRechts in [false, true] {
            let an = t - (vonRechts ? 0.28 : 0.1)
            guard an > 0 else { continue }
            let flackern: Double = an < 0.12 ? (sin(an * 120) > 0 ? 1 : 0.3) : 1
            let da = easeOut(an / 0.15) * flackern
            let seite: Double = vonRechts ? -1 : 1, versatz: Double = vonRechts ? 1 : 0
            let ox = vonRechts ? w + 30 : -30, oy = -40.0
            let nachhall = zyklus(t, hit + 0.5, 3).n
            let wahl = max(0, nachhall) * 2 + (vonRechts ? 1 : 0)
            let wiegen = (0.04 + 0.04 * unit(wahl, 210)) * sin(t * 1.1 + versatz)
            let schwenk = (1 - easeOut(t / hit)) * 0.7 * seite + wiegen
            let winkel = atan2(ziel.y - oy, ziel.x - ox) + schwenk, l = h * 1.15, kegel = 0.15
            func kante(_ a: Double) -> Point { (ox + cos(a) * l, oy + sin(a) * l) }
            let ende = kante(winkel)
            b.fill([(ox, oy), kante(winkel - kegel * 1.5), kante(winkel + kegel * 1.5)], from: (ox, oy), to: ende,
                   [(0, SceneArt.light, 0.14 * da), (1, SceneArt.light, 0)])
            b.fill([(ox, oy), kante(winkel - kegel), kante(winkel + kegel)], from: (ox, oy), to: ende,
                   [(0, SceneArt.light, 0.38 * da), (0.5, SceneArt.light, 0.12 * da), (1, SceneArt.light, 0)])
            b.glow(ox + 30 * seite, oy + 50, 70, SceneArt.light, 0.7 * da)
            // Staub tanzt im Licht
            for i in 0..<12 {
                let q = fract(t * 0.05 * (1 + unit(i, 90)) + unit(i, 91))
                let quer = (unit(i, 92) - 0.5) * 2 * kegel * 0.8, weg = l * (0.15 + 0.6 * q)
                let x = ox + cos(winkel + quer) * weg, y = oy + sin(winkel + quer) * weg
                let glanz = pow(max(0, sin(t * 4 + Double(i))), 6)
                b.circle(x, y, 1.2 + 1.5 * unit(i, 93), SceneArt.light, 0.7 * da * sin(q * .pi))
                if glanz > 0.5 { b.sparkle(x, y, 4 * glanz, t, SceneArt.light, 0.7 * glanz * da) }
            }
        }
        b.glow(ziel.x, ziel.y, 190, warn, 0.3 * easeOut((t - hit + 0.1) / 0.4) + 0.2 * hitPulse(t, hit))
        // Vorne: die Rampe – kleine Lampen am unteren Rand, die beim Schlag aufgluehen
        let rampe = easeOut((t - hit + 0.05) / 0.25)
        for i in 0..<9 {
            let di = Double(i)
            let x = w * (di + 0.5) / 9, an = rampe * (0.75 + 0.25 * sin(t * 2 + di))
            b.glow(x, h - 4, 50, warn, 0.35 * an)
            b.circle(x, h - 6, 4, SceneArt.light, 0.9 * an)
        }
        b.glow(w / 2, h, w * 0.55, SceneArt.light, 0.16 * rampe)
    }

    // MARK: 13

    /// Kaertchen wirbeln in drei Schichten aus der Mitte, jede Welle anders herum.
    static func category(_ b: inout SceneBrush, _ s: RingStage, _ t: Double) {
        let hit = s.hit
        let cx = s.cardMidX, cy = s.cardMidY
        let akzent = BeerStatsColor.accent, warn = BeerStatsColor.warning
        // Drei Schichten: fern und blass, mittel, nah und gross
        let anzahl = [14, 10, 7]
        let groesse = [0.55, 0.95, 1.45]
        let tempo = [0.55, 0.85, 1.15]
        let deckkraft = [0.22, 0.45, 0.7]
        let weite: [Double] = [180, 230, 300]
        for welle in 0..<3 {
            let start = hit - 0.6 + Double(welle) * 1.2, zr = t - start
            guard zr >= 0 else { continue }
            let nr = Int((zr / 3.6).rounded(.down)), z = zr - Double(nr) * 3.6
            let dreh: Double = unit(nr * 3 + welle, 220) > 0.5 ? 1 : -1
            let a0Welle = min(1, z * 6) * (1 - clamp((z - 1.8) / 0.9))
            guard a0Welle > 0 else { continue }
            for schicht in 0..<3 {
                let n = anzahl[schicht], gross = groesse[schicht]
                for i in 0..<n {
                    func spur(_ zz: Double) -> (x: Double, y: Double, r: Double) {
                        let grund = (Double(i) + 0.4 * Double(welle)) / Double(n) * tau
                        let wi = grund + noise(i + schicht * 20, 1) * 0.2 + dreh * 2.4 * (1 - easeOut(zz / 1.1))
                        let d = (40 + weite[schicht] * unit(i + schicht * 9, 2)) * easeOut(zz * tempo[schicht] / 1.1)
                        let drehung = wi + zz * (2 + 2 * unit(i, 3)) * dreh
                        return (cx + cos(wi) * d, cy + sin(wi) * d + 40 * zz * zz, drehung)
                    }
                    let vorher = spur(max(0, z - 0.09)), jetzt = spur(z)
                    let a = deckkraft[schicht] * a0Welle * s.faint(jetzt.y, rest: 0.12)
                    if schicht > 0 { b.stroke([(vorher.x, vorher.y), (jetzt.x, jetzt.y)], akzent, a * 0.35, 10 * gross) }
                    let c = cos(jetzt.r), sn = sin(jetzt.r)
                    func ecke(_ dx: Double, _ dy: Double) -> Point {
                        (jetzt.x + (c * dx - sn * dy) * gross, jetzt.y + (sn * dx + c * dy) * gross)
                    }
                    let rahmen = [ecke(-13, -18), ecke(13, -18), ecke(13, 18), ecke(-13, 18)]
                    b.fill(rahmen, schicht == 0 ? cardFar : SceneArt.card, a * 0.8)
                    b.stroke(rahmen + [rahmen[0]], i % 3 == 0 ? warn : akzent, a, schicht == 2 ? 2.4 : 1.4)
                    if schicht > 0 {
                        b.fill([ecke(-9, -12), ecke(9, -12), ecke(9, -6), ecke(-9, -6)], i % 2 == 1 ? akzent : SceneArt.violet, a * 0.75)
                        b.stroke([ecke(-9, 0), ecke(9, 0)], ink, a * 0.4, 1.5)
                        b.stroke([ecke(-9, 5), ecke(4, 5)], ink, a * 0.3, 1.5)
                    }
                }
            }
        }
    }

    // MARK: Ass

    /// Feuer: zwei Reihen Flammen unten, beim Aufprall Stichflammen an den Raendern.
    static func ace(_ b: inout SceneBrush, _ s: RingStage, _ t: Double) {
        let w = s.w, h = s.h, hit = s.hit
        let wachs = easeOut(t / hit)
        let auf = t > hit ? exp(-(t - hit) * 3) : 0
        let nach = zyklus(t, hit + 1, 2.4)
        let boe = nach.n >= 0 ? 1 + 0.35 * unit(nach.n, 230) * sin(.pi * clamp(nach.z / 1.2)) : 1
        let flackern = 0.35 + 0.08 * sin(t * 7) + 0.05 * sin(t * 11)
        b.glow(w / 2, h + 60, w * 0.95, BeerStatsColor.error, flackern * (0.6 + 0.4 * wachs) + 0.35 * auf)
        // Die Luft ueber dem Feuer flimmert
        for k in 0..<4 {
            let dk = Double(k)
            let zz = fract(t * 0.35 + dk / 4), y = h - 90 - h * 0.45 * zz
            var linie: [Point] = []
            var x = 0.0
            while x <= w {
                linie.append((x, y + 5 * sin(x * 0.05 + t * 5 + dk)))
                x += 12
            }
            b.stroke(linie, SceneArt.emberCore, 0.07 * sin(zz * .pi) * wachs, 2)
        }

        // Feuer addiert sich hell auf hell
        b.blend(.plusLighter)
        // Hinten: hohe, dunklere Zungen; vorne: kurze, helle
        for reihe in 0..<2 {
            let menge = reihe == 1 ? 13 : 9
            for k in 0..<menge {
                let dk = Double(k)
                let x = w * (dk + 0.5) / Double(menge) + noise(k + reihe * 30, 95) * 8
                let grund = reihe == 1 ? 45 + 60 * unit(k, 96) : 80 + 70 * unit(k, 97)
                let lang = grund * wachs * (0.75 + 0.25 * sin(t * (8 + dk) + dk)) * (1 + 0.8 * auf) * boe
                let breite = (reihe == 1 ? 12 : 17) + 6 * unit(k, 98)
                let richtung = -Double.pi / 2 + 0.15 * sin(t * 2 + dk + Double(reihe))
                b.tongue((x, h + 8), richtung, lang, breite, reihe == 1 ? 0.9 : 0.45, t, k + reihe * 40)
            }
        }
        // Die Stichflammen beim Aufprall: hoch an den Raendern, in der Mitte
        // nur bis unter den Text
        if t > hit - 0.05 && t < hit + 0.8 {
            let ss = max(0, t - hit), kraft = easeOut(ss / 0.1) * (1 - easeIn(ss / 0.8))
            for k in 0..<6 {
                let amRand = k < 2 || k > 3
                let x: Double
                if amRand {
                    x = k < 2 ? w * (0.06 + 0.07 * Double(k)) : w * (0.81 + 0.07 * Double(k - 4))
                } else {
                    x = w / 2 + (Double(k) - 2.5) * 30
                }
                let neigung: Double = amRand ? (k < 2 ? 0.06 : -0.06) : 0
                let hoehe = amRand ? h * 0.5 : (h - s.textBottom) * 0.95
                b.tongue((x, h + 8), -Double.pi / 2 + neigung, hoehe * kraft * (0.85 + 0.15 * unit(k, 99)), amRand ? 20 : 24, kraft, t, k + 80)
            }
        }
        b.blend(.normal)

        // Vorne: Glut stiebt mit Schweif, beim Schlag ein ganzer Schwarm
        let schwarm = t > hit && t < hit + 1.3
        let menge = 30 + (schwarm ? 26 : 0)
        for i in 0..<menge {
            let di = Double(i)
            let imSchwarm = i >= 30
            let zz = imSchwarm ? clamp((t - hit) / 1.3) : fract(t * (0.22 + 0.2 * unit(i, 1)) + unit(i, 2))
            let basisX = imSchwarm ? w / 2 + (unit(i, 3) - 0.5) * w * 0.8 * easeOut(zz) : w * unit(i, 3)
            let x = basisX + 30 * sin(t * 1.7 + di) * zz
            let y = h + 10 - h * (imSchwarm ? 1.05 * easeOut(zz) : 0.85 * zz)
            let funkeln = 0.6 + 0.4 * sin(t * 15 + di * 3)
            let r = (imSchwarm ? 2.4 : 1.5) + 2.6 * unit(i, 4), rest = (1 - zz) * funkeln
            let bl = s.faint(y, rest: 0.12)
            b.stroke([(x, y), (x - 3 * sin(t + di), y + 10 + 8 * r)], SceneArt.ember, 0.35 * rest * bl, r)
            b.circle(x, y, r, SceneArt.emberCore, 0.95 * rest * bl)
        }
    }
}

// MARK: - Das Licht beim Schlag

extension RingSceneArt {

    /// Unter der Szene: Das Licht oben wandert beim Schlag in die Farbe der
    /// Szene. Vorher traegt der Screen die Farbe der Karte (Rolle rot,
    /// sonst bernstein), danach die des Moments.
    static func hitLightUnder(_ b: inout SceneBrush, _ s: RingStage, _ t: Double, _ light: Color) {
        let ds = t - s.hit
        let wechsel = smooth((ds + 0.05) / 0.45)
        b.glow(s.w / 2, s.h * 0.25, s.w * 0.9, light, 0.16 * wechsel + 0.06 * bell(ds, 0.3))
    }

    /// Ueber der Szene, unter Karte und Text: ein Schein hinter der Karte,
    /// der beim Schlag aufflammt, und eine Vignette. Sie zieht sich im
    /// Aufbau zu, reisst beim Schlag auf und atmet danach leise.
    static func hitLightOver(_ b: inout SceneBrush, _ s: RingStage, _ t: Double, _ light: Color) {
        let ds = t - s.hit
        let wechsel = smooth((ds + 0.05) / 0.45)
        b.glow(s.cardMidX, s.cardMidY, s.w * 0.62, light, 0.07 * wechsel + 0.18 * bell(ds, 0.2))
        let dunkel: Double
        if ds < 0 {
            dunkel = 0.3 + 0.25 * easeIn(t / max(0.01, s.hit))
        } else {
            dunkel = 0.36 - 0.24 * exp(-ds * 3) + 0.04 * sin(t * 2.2)
        }
        b.flush()
        let verlauf = Gradient(stops: [
            .init(color: Color.black.opacity(0), location: 0),
            .init(color: Color.black.opacity(0), location: 0.55),
            .init(color: Color.black.opacity(dunkel), location: 1)
        ])
        let flaeche = Path(CGRect(x: -10, y: -10, width: s.w + 20, height: s.h + 20))
        b.g.fill(flaeche, with: .radialGradient(verlauf, center: CGPoint(x: s.cardMidX, y: s.cardMidY), startRadius: 0, endRadius: s.w * 1.8))
    }
}
