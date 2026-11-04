//
//  RingEmbers.swift
//  BeerStats
//
//  Der Glutfaden unter den Karten und der Moment, in dem er reisst.
//
//  Seit dem 28. Oktober zaehlt ein Riss erst ab einer halben Karte Luecke.
//  Darunter entstehen Luecken, die NICHT zaehlen – und ohne Faden saehe der
//  Tisch dort ein Loch, fuer das niemand zahlt. Der Faden ueberbrueckt sie
//  sichtbar: Er wird duenner und unruhiger, je weiter die Luecke ist, und an
//  der Schwelle reisst er. Er rechnet nicht selbst, sondern zeigt
//  `RingLayout.links` – dieselben Zahlen wie die Regel.
//
//  Der Riss selbst bekommt einen eigenen Moment, bevor die Karte kommt
//  (Wunsch des Nutzers vom 28. Oktober: erst eine Animation, die zeigt,
//  dass und WO der Kreis gerissen ist). Vorher schob sich der Kartenscreen
//  sofort ueber den Ring, die Flammen schlugen am Bildschirmrand herein,
//  und die Stelle sah niemand. Jetzt reisst der Faden an der Luecke, eine
//  Stichflamme schlaegt heraus, der Rest wird dunkel, und ueber der Luecke
//  steht "RISS". Erst danach kommt die Karte.
//
//  Der Moment liegt ueber dem GANZEN Screen, nicht nur ueber dem Ring – das
//  Abdunkeln soll den Blick auf die Stelle ziehen, auch weg vom Knopf.
//  Deshalb meldet der Ring seine Lage als Anker nach oben
//  (`RingTearSpotKey`), und der Screen zeichnet den Moment darueber.
//

import SwiftUI

// MARK: - Was der Ring nach oben meldet

/// Der Riss, der gerade passiert. Eigener Wert mit eigener Kennung, damit
/// jeder Riss seinen Moment von vorn beginnt.
struct RingTearMoment {
    let id = UUID()
    /// Die Verbindung, die gerissen ist.
    let link: RingLayout.Link
}

/// Eine Stelle, die gerade knapp gehalten hat – der Faden leuchtet dort auf.
struct RingHeld {
    let from: Int
    let to: Int
    let since: Date
}

/// Wo der Ring gerade reisst, damit der Screen den Moment ueber sich legen
/// kann.
struct RingTearSpot {
    /// Das Quadrat des Rings, aufzuloesen im Koordinatenraum des Screens.
    let ring: Anchor<CGRect>
    let radius: CGFloat
    let cardHeight: CGFloat
    let moment: RingTearMoment
}

struct RingTearSpotKey: PreferenceKey {
    static let defaultValue: RingTearSpot? = nil

    static func reduce(value: inout RingTearSpot?, nextValue: () -> RingTearSpot?) {
        value = value ?? nextValue()
    }
}

// MARK: - Der Glutfaden

/// Der Glutfaden. Liegt UNTER den Karten: Wo sie sich ueberlappen, ist er
/// verdeckt, in einer Luecke sieht man ihn.
struct RingEmbers: View {

    let links: [RingLayout.Link]
    /// Auf diesem Radius liegen die Kartenmitten – und der Faden.
    let radius: CGFloat
    /// Nach dem dritten Riss ist die Glut aus: Asche statt Faden.
    let isSpent: Bool
    /// Die Stelle, die gerade reisst. Die zeichnet der Moment selbst.
    var tearing: RingLayout.Link?
    var held: RingHeld?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Ab dieser Spannung wird der Faden unruhig – kurz vor dem Reissen.
    private static let restlessFrom = 0.55

    /// Bewegung braucht es nur, wenn ein Faden flackert oder gerade
    /// aufleuchtet. Sonst steht das Bild – kein Grund, dreissigmal je
    /// Sekunde dasselbe zu zeichnen.
    private var moves: Bool {
        guard !reduceMotion, !isSpent else { return false }
        return held != nil || links.contains { $0.isVisible && !$0.isOpen && $0.tension > Self.restlessFrom }
    }

    var body: some View {
        Group {
            if moves {
                SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                    Canvas { context, size in draw(&context, size, now: timeline.date) }
                }
            } else {
                Canvas { context, size in draw(&context, size, now: nil) }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ g: inout GraphicsContext, _ size: CGSize, now: Date?) {
        let cx = Double(size.width) / 2, cy = Double(size.height) / 2
        let r = Double(radius)
        let t = now.map { $0.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600) } ?? 0

        for (nr, link) in links.enumerated() {
            // Knapp ueberlappende Paare auch: Die Karten sind Rechtecke, ihre
            // Ecken lassen am Radius schon einen Spalt, bevor die Regel ihn
            // zaehlt. Der Rest des Fadens liegt verdeckt unter den Karten.
            guard link.free > -RingTearArt.underlap else { continue }
            if let tearing, tearing.from == link.from, tearing.to == link.to { continue }

            if isSpent {
                RingTearArt.ash(&g, cx, cy, r, link)
            } else if link.isOpen {
                RingTearArt.brokenEnds(&g, cx, cy, r, link.start, link.end, heat: 1)
            } else {
                var aufleuchten = 0.0
                if let held, let now, held.from == link.from, held.to == link.to {
                    aufleuchten = max(0, 1 - now.timeIntervalSince(held.since) / 0.9)
                }
                var unruhe = 0.0
                if moves, link.tension > Self.restlessFrom {
                    let naehe = (link.tension - Self.restlessFrom) / (1 - Self.restlessFrom)
                    let takt = 19 + Double(nr % 7) * 3
                    unruhe = naehe * (0.5 + 0.5 * sin(t * takt + Double(nr)))
                }
                RingTearArt.thread(&g, cx, cy, r, link.start, link.end,
                                   tension: max(0, link.tension), flicker: unruhe, flare: aufleuchten)
            }
        }
    }
}

// MARK: - Der Moment des Risses

/// Der Moment ueber dem ganzen Screen. Der Ring meldet, wo er liegt; hier
/// wird es in Punkte des Screens uebersetzt.
struct RingTearOverlay: View {

    let spot: RingTearSpot

    var body: some View {
        GeometryReader { proxy in
            let ring = proxy[spot.ring]
            EffectCanvas(
                draw: { g, size, t in
                    RingTearArt.moment(&g, size, t, ring: ring, radius: Double(spot.radius),
                                       cardHeight: Double(spot.cardHeight), link: spot.moment.link)
                },
                stillAt: RingTearArt.still,
                lasts: RingTearArt.duration
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Zeichnen

/// Alles Zeichnen fuer Faden und Riss. Reine Rechnung auf der Leinwand,
/// abgestimmt in der Vorschau "Riss im Ring" mit denselben Zahlen.
enum RingTearArt {

    /// So lange gehoert der Moment dem Ring; dann kommt die Karte.
    static let duration = 1.6

    /// Das stille Bild bei "Bewegung reduzieren": Die Stelle ist markiert,
    /// die Flamme steht – nicht nichts, sonst fehlt der Moment ganz.
    static let still = 0.55

    /// So weit reicht der Faden unter die Karten, in Grad.
    static let underlap = 4.0

    static let hot = SceneArt.rgb(255, 214, 120)
    static let strained = SceneArt.rgb(236, 74, 32)
    static let core = SceneArt.rgb(255, 246, 214)
    static let ember = SceneArt.rgb(235, 80, 30)
    static let ashColor = SceneArt.rgb(70, 64, 60)
    static let mark = SceneArt.rgb(224, 144, 46)

    // MARK: Werkzeug

    /// Ein Punkt auf dem Ring: 0 Grad oben, im Uhrzeigersinn – wie die Karten.
    static func point(_ cx: Double, _ cy: Double, _ r: Double, _ grad: Double) -> SceneArt.Point {
        let w = grad * .pi / 180
        return (cx + sin(w) * r, cy - cos(w) * r)
    }

    static func ringArc(_ cx: Double, _ cy: Double, _ r: Double, _ von: Double, _ bis: Double, _ n: Int = 24) -> [SceneArt.Point] {
        SceneArt.arc(cx, cy, r, (von - 90) * .pi / 180, (bis - 90) * .pi / 180, n)
    }

    /// Ein Strich mit Schein: erst weich und breit, dann der Kern.
    private static func glowingStroke(_ g: inout GraphicsContext, _ punkte: [SceneArt.Point], _ farbe: Color,
                                      _ alpha: Double, _ breite: Double, schein: Double) {
        g.drawLayer { layer in
            layer.addFilter(.blur(radius: CGFloat(schein)))
            SceneArt.stroke(&layer, punkte, farbe, alpha, breite * 2.2)
        }
        SceneArt.stroke(&g, punkte, farbe, alpha, breite)
    }

    // MARK: Der Faden

    /// Ein gehaltener Faden. `tension` 0 heisst dick und hell, 1 heisst
    /// duenn, dunkelrot – kurz vor dem Reissen.
    static func thread(_ g: inout GraphicsContext, _ cx: Double, _ cy: Double, _ r: Double,
                       _ von: Double, _ bis: Double, tension: Double, flicker: Double, flare: Double) {
        let s = min(tension, 1)
        let breite = 4.6 - 3.3 * s
        let farbe = s < 0.6 ? hot : strained
        let alpha = min(1, (0.9 + 0.5 * flare) * (1 - 0.5 * flicker))
        let punkte = ringArc(cx, cy, r, von - underlap, bis + underlap, 28)
        glowingStroke(&g, punkte, farbe, alpha, breite + 2 * flare, schein: 7 + 6 * (1 - s) + 10 * flare)
        SceneArt.stroke(&g, punkte, core, alpha * 0.85 * (1 - s * 0.55), max(0.6, breite * 0.38))
    }

    /// Eine offene Stelle: zwei glimmende Enden, dazwischen nur Schein.
    static func brokenEnds(_ g: inout GraphicsContext, _ cx: Double, _ cy: Double, _ r: Double,
                           _ von: Double, _ bis: Double, heat: Double) {
        let stummel = min((bis - von) * 0.14, 5)
        let mitte = point(cx, cy, r, (von + bis) / 2)
        SceneArt.glow(&g, mitte.x, mitte.y, (bis - von) * 0.9 + 10, ember, 0.18 * heat)
        for (a, b) in [(von - underlap, von + stummel), (bis + underlap, bis - stummel)] {
            glowingStroke(&g, ringArc(cx, cy, r, a, b, 8), ember, 0.9 * heat, 2.4, schein: 5)
            let ende = point(cx, cy, r, b)
            SceneArt.circle(&g, ende.x, ende.y, 2.2, hot, 0.9 * heat)
        }
    }

    /// Nach dem dritten Riss ist die Glut aus.
    static func ash(_ g: inout GraphicsContext, _ cx: Double, _ cy: Double, _ r: Double, _ link: RingLayout.Link) {
        SceneArt.stroke(&g, ringArc(cx, cy, r, link.start - underlap, link.end + underlap, 20), ashColor, 0.7, 1.6)
    }

    // MARK: Der Riss

    /// Der ganze Moment, in dieser Reihenfolge: dunkel bis auf die Stelle,
    /// ein Brandfleck, der Faden reisst, ein heisser Ring, Blitz, Rauchsaeule,
    /// Stichflamme, Funkenregen – und zuletzt der Stempel, damit kein Feuer
    /// ueber der Schrift liegt.
    ///
    /// Seit dem 4. November (Vorschlag 2) bebt dabei der ganze Ring, und der
    /// Blick rueckt an die Luecke heran. Die Karten darunter beben mit
    /// derselben Rechnung (`quake`), sonst brennte das Feuer neben der Stelle.
    static func moment(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double,
                       ring: CGRect, radius r: Double, cardHeight: Double, link: RingLayout.Link) {
        let cx = Double(ring.midX), cy = Double(ring.midY)
        let mitte = link.start + link.free / 2
        let p = point(cx, cy, r, mitte)
        let aussen = (mitte - 90) * .pi / 180

        dim(&g, size, p, t)
        var b = g
        let q = quake(t)
        b.translateBy(x: p.x, y: p.y)
        b.scaleBy(x: q.zoom, y: q.zoom)
        b.translateBy(x: -p.x + q.dx, y: -p.y + q.dy)
        b.translateBy(x: cx, y: cy)
        b.rotate(by: .degrees(q.turn))
        b.translateBy(x: -cx, y: -cy)

        burnMark(&b, p, aussen, t, cardHeight: cardHeight)
        snap(&b, cx, cy, r, link, t)
        heatRing(&b, p, t, cardHeight: cardHeight)
        flash(&b, p, t)
        smokeColumn(&b, p, t)
        flames(&b, p, aussen, t)
        sparkRain(&b, p, aussen, t)
        stamp(&b, cx, cy, r, cardHeight, link, t)
    }

    /// Wie der Ring beim Riss bebt und an die Luecke heranrueckt: Versatz,
    /// Drehung um die Mitte in Grad, Vergroesserung um die Luecke. Ein
    /// zweiter, kleiner Stoss, wenn der Stempel aufschlaegt.
    static func quake(_ t: Double) -> (dx: Double, dy: Double, turn: Double, zoom: Double) {
        let ran = SceneArt.smooth(phase(t, 0.05, 0.4)) * (1 - SceneArt.smooth(phase(t, 1.5, 2.3)))
        guard t > 0.07 else { return (0, 0, 0, 1 + 0.06 * ran) }
        let s = t - 0.07, a = 10 * exp(-s * 7)
        var dx = a * sin(s * 120), dy = a * 0.6 * cos(s * 95)
        let turn = 1.8 * exp(-s * 5) * sin(s * 34)
        let st = t - 0.36
        if st > 0 {
            let b = 3.5 * exp(-st * 16)
            dx += b * sin(st * 150)
            dy += b * cos(st * 120)
        }
        return (dx, dy, turn, 1 + 0.06 * ran)
    }

    /// Wie hoch eine Nachbarin der Luecke geschleudert ist, von 0 bis 1:
    /// hoch und zurueck, dann ein kleiner Nachhuepfer.
    static func throwHeight(_ s: Double) -> Double {
        if s < 0 { return 0 }
        if s < 0.5 {
            let u = s / 0.5
            return 4 * u * (1 - u)
        }
        if s < 0.72 {
            let v = (s - 0.5) / 0.22
            return 0.8 * v * (1 - v)
        }
        return 0
    }

    private static func phase(_ t: Double, _ a: Double, _ b: Double) -> Double {
        SceneArt.clamp((t - a) / (b - a))
    }

    /// Alles wird dunkel, nur um die Stelle herum nicht.
    private static func dim(_ g: inout GraphicsContext, _ size: CGSize, _ p: SceneArt.Point, _ t: Double) {
        let dunkel = SceneArt.easeOut(phase(t, 0.18, 0.42))
        guard dunkel > 0 else { return }
        g.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [Color.black.opacity(0), Color.black.opacity(0.6 * dunkel)]),
            center: CGPoint(x: p.x, y: p.y), startRadius: 40, endRadius: 190))
    }

    /// Der Faden: einen Augenblick lang gespannt, dann reisst er und zieht
    /// sich zu beiden Seiten zurueck.
    private static func snap(_ g: inout GraphicsContext, _ cx: Double, _ cy: Double, _ r: Double,
                             _ link: RingLayout.Link, _ t: Double) {
        if t < 0.07 {
            thread(&g, cx, cy, r, link.start, link.end, tension: 0.97, flicker: 0, flare: 1)
            return
        }
        let halb = link.free / 2
        let zurueck = SceneArt.easeOut(phase(t, 0.07, 0.42))
        let stummel = min(halb * 0.28, 5)
        let laenge = halb + (stummel - halb) * zurueck
        let hitze = 1 - 0.45 * phase(t, 0.4, 1.2)
        for (kante, richtung) in [(link.start, 1.0), (link.end, -1.0)] {
            let ende = kante + richtung * laenge
            glowingStroke(&g, ringArc(cx, cy, r, kante - richtung * underlap, ende, 16),
                          zurueck < 0.5 ? core : ember, hitze, 3.2 - 0.8 * zurueck, schein: 7)
            let e = point(cx, cy, r, ende)
            SceneArt.glow(&g, e.x, e.y, 12, SceneArt.rgb(255, 160, 60), 0.8 * hitze)
            SceneArt.circle(&g, e.x, e.y, 2.4, SceneArt.rgb(255, 235, 180), hitze)
        }
        let m = point(cx, cy, r, link.start + halb)
        SceneArt.glow(&g, m.x, m.y, halb * 2 + 16, ember, 0.25 * hitze)
    }

    private static func flash(_ g: inout GraphicsContext, _ p: SceneArt.Point, _ t: Double) {
        let a = (1 - SceneArt.easeOut(phase(t, 0.07, 0.6))) * phase(t, 0.05, 0.08)
        SceneArt.glow(&g, p.x, p.y, 170, SceneArt.rgb(255, 236, 190), a)
    }

    /// Die Stichflamme: Zungen nach aussen, zwei lecken am Ring entlang,
    /// dazu ein heller Kern.
    private static func flames(_ g: inout GraphicsContext, _ p: SceneArt.Point, _ aussen: Double, _ t: Double) {
        let groesse = 1.2
        let kraft = phase(t, 0.06, 0.14) * (1 - SceneArt.easeIn(phase(t, 0.6 * groesse, 1.35 * groesse)))
        guard kraft > 0 else { return }
        SceneArt.glow(&g, p.x + cos(aussen) * 46, p.y + sin(aussen) * 46, 150 * groesse, SceneArt.rgb(255, 112, 28), 0.5 * kraft)

        var feuer = g
        feuer.blendMode = .plusLighter
        let viele = 17
        for k in 0..<viele {
            // Die letzten beiden lecken am Ring entlang, die anderen nach aussen
            let seitlich = k >= viele - 2
            let kk = Double(k)
            let faecher: Double = seitlich ? (k == viele - 2 ? -1.3 : 1.3) : (kk - Double(viele - 2) / 2) * 0.11 + 0.08 * sin(t * (6 + kk) + kk)
            let basis: Double = (seitlich ? 38 : 74 + 86 * SceneArt.unit(k, 3)) * groesse
            let flackern = 0.78 + 0.22 * sin(t * (13 + 2.3 * kk) + kk * 1.7)
            let dicke: Double = seitlich ? 9 : 12 + 7 * SceneArt.unit(k, 4)
            tongue(&feuer, p, aussen + faecher, basis * kraft * flackern, dicke * min(1, kraft * 1.4),
                   min(1, kraft * 1.2), t, k)
        }
        for k in 0..<7 {
            let richtung = aussen + Double(k - 3) * 0.1 + 0.06 * sin(t * Double(11 + k) + Double(2 * k))
            tongue(&feuer, p, richtung, (40 + 30 * SceneArt.unit(k, 9)) * kraft * groesse, 7 * min(1, kraft * 1.4),
                   0.9 * min(1, kraft * 1.3), t, k + 20)
        }
    }

    /// Eine Flammenzunge: unten breit und hell, oben spitz und rot. Auch der
    /// Flammenkranz am Ende der Runde brennt mit ihr (`RingFinaleArt`).
    static func tongue(_ g: inout GraphicsContext, _ p: SceneArt.Point, _ richtung: Double,
                               _ laenge: Double, _ breite: Double, _ alpha: Double, _ t: Double, _ k: Int) {
        guard laenge > 2, alpha > 0 else { return }
        let nx = cos(richtung), ny = sin(richtung)
        let qx = -ny, qy = nx
        let wanken = sin(t * Double(9 + k) + Double(k)) * breite * 0.7
        let spitze = CGPoint(x: p.x + nx * laenge + qx * wanken, y: p.y + ny * laenge + qy * wanken)
        let bauch = laenge * 0.5

        var zunge = Path()
        zunge.move(to: CGPoint(x: p.x + qx * breite, y: p.y + qy * breite))
        zunge.addQuadCurve(to: spitze, control: CGPoint(x: p.x + nx * bauch + qx * breite * 1.15,
                                                        y: p.y + ny * bauch + qy * breite * 1.15))
        zunge.addQuadCurve(to: CGPoint(x: p.x - qx * breite, y: p.y - qy * breite),
                           control: CGPoint(x: p.x + nx * bauch - qx * breite * 1.15,
                                            y: p.y + ny * bauch - qy * breite * 1.15))
        zunge.closeSubpath()

        let verlauf = Gradient(stops: [
            .init(color: SceneArt.rgb(255, 250, 225).opacity(alpha), location: 0),
            .init(color: SceneArt.rgb(255, 204, 86).opacity(alpha), location: 0.25),
            .init(color: SceneArt.rgb(242, 92, 30).opacity(alpha * 0.85), location: 0.65),
            .init(color: SceneArt.rgb(170, 28, 18).opacity(0), location: 1),
        ])
        g.fill(zunge, with: .linearGradient(verlauf, startPoint: CGPoint(x: p.x, y: p.y), endPoint: spitze))
    }

    /// Funken schiessen hoch und regnen ueber den Tisch – je Farbstufe ein
    /// Aufruf, wie in den Szenen (`SceneBrush`).
    private static func sparkRain(_ g: inout GraphicsContext, _ p: SceneArt.Point, _ aussen: Double, _ t: Double) {
        var b = SceneBrush(g)
        let basis = atan2(sin(aussen) * 0.4 - 1, cos(aussen) * 0.6)
        let farben: [Color] = [SceneArt.rgb(255, 240, 180), SceneArt.rgb(255, 150, 50), SceneArt.rgb(220, 70, 30)]
        let deckkraft: [Double] = [1, 0.85, 0.6]
        for i in 0..<64 {
            let alter = t - (0.06 + 0.2 * SceneArt.unit(i, 310))
            guard alter >= 0, alter <= 1.9 else { continue }
            let winkel = basis + (SceneArt.unit(i, 311) - 0.5) * 1.7
            let tempo = 240 + 280 * SceneArt.unit(i, 312)
            let x = p.x + cos(winkel) * tempo * alter
            let y = p.y + sin(winkel) * tempo * alter + 310 * alter * alter
            let vx = cos(winkel) * tempo, vy = sin(winkel) * tempo + 620 * alter
            let rest = 1 - alter / 1.9
            let stufe = rest > 0.66 ? 0 : (rest > 0.33 ? 1 : 2)
            b.stroke([(x, y), (x - vx * 0.03, y - vy * 0.03)], farben[stufe], deckkraft[stufe] * 0.6, stufe == 0 ? 2.2 : 1.6)
            b.circle(x, y, 1 + 1.6 * rest, farben[stufe], deckkraft[stufe])
        }
        b.flush()
    }

    /// Eine Rauchsaeule steigt aus der Luecke, unten noch vom Feuer erhellt.
    private static func smokeColumn(_ g: inout GraphicsContext, _ p: SceneArt.Point, _ t: Double) {
        for i in 0..<14 {
            let alter = t - (0.18 + 0.09 * Double(i))
            guard alter >= 0, alter <= 2.4 else { continue }
            let x = p.x + 10 * SceneArt.noise(i, 301) + 18 * sin(alter * 1.8 + Double(i)) * min(1, alter) + 26 * alter * SceneArt.noise(i, 302)
            let y = p.y - 14 - (150 * alter + 20 * alter * alter)
            let hitze = SceneArt.clamp(1 - alter / 0.7)
            let farbe = hitze > 0.5 ? SceneArt.rgb(230, 140, 80) : SceneArt.rgb(130, 120, 114)
            let a = 0.37 * min(1, alter * 5) * (1 - alter / 2.4)
            SceneArt.glow(&g, x, y, 16 + 32 * alter, farbe, a)
        }
    }

    /// Ein Brandfleck auf dem Tisch, dessen glimmender Rand langsam abkuehlt.
    private static func burnMark(_ g: inout GraphicsContext, _ p: SceneArt.Point, _ aussen: Double, _ t: Double, cardHeight: Double) {
        let wachs = SceneArt.easeOut(phase(t, 0.25, 0.9))
        guard wachs > 0 else { return }
        let k = cardHeight / 72
        let c: SceneArt.Point = (p.x + cos(aussen) * 8 * k, p.y + sin(aussen) * 8 * k)
        SceneArt.glow(&g, c.x, c.y, 74 * k * wachs, SceneArt.rgb(14, 6, 3), 0.85 * wachs)
        let kuehl = SceneArt.clamp((t - 0.5) / 2.2)
        var rand: [SceneArt.Point] = []
        for n in 0...28 {
            let a = Double(n) / 28 * 2 * .pi
            let rr = (34 + 6 * SceneArt.noise(n % 28, 320)) * k * wachs
            rand.append((c.x + cos(a) * rr * 1.25, c.y + sin(a) * rr))
        }
        let glut = kuehl < 0.5 ? SceneArt.rgb(255, 140, 50) : SceneArt.rgb(150, 60, 24)
        SceneArt.stroke(&g, rand, glut, (0.6 - 0.32 * kuehl) * wachs, 3)
        SceneArt.glow(&g, c.x, c.y, 40 * k * wachs, SceneArt.rgb(255, 110, 40), 0.18 * (1 - kuehl) * wachs)
    }

    /// Ein heisser Ring, der sich beim Reissen um die Luecke weitet.
    private static func heatRing(_ g: inout GraphicsContext, _ p: SceneArt.Point, _ t: Double, cardHeight: Double) {
        let k = phase(t, 0.06, 0.6)
        guard k > 0, k < 1 else { return }
        let r = (14 + 90 * SceneArt.easeOut(k)) * cardHeight / 72
        SceneArt.stroke(&g, SceneArt.arc(p.x, p.y, r, 0, 2 * .pi, 40), SceneArt.rgb(255, 190, 90), 0.6 * (1 - k), 5 * (1 - k) + 1)
    }

    /// Die Klammer am Ring markiert die Luecke, und "RISS" knallt wie ein
    /// Stempel daneben – innen im Ring, wo kein Feuer hinschlaegt. Aussen
    /// stand das Wort genau in der Stichflamme.
    private static func stamp(_ g: inout GraphicsContext, _ cx: Double, _ cy: Double, _ r: Double,
                              _ cardHeight: Double, _ link: RingLayout.Link, _ t: Double) {
        let fall = phase(t, 0.22, 0.36)
        guard fall > 0 else { return }
        let aufschlag = SceneArt.clamp((t - 0.36) / 0.05)
        if aufschlag > 0 {
            var klammer = g
            klammer.opacity = aufschlag
            let aussenR = r + cardHeight / 2 + 10
            glowingStroke(&klammer, ringArc(cx, cy, aussenR, link.start, link.end, 16), mark, 1, 3, schein: 6)
            for kante in [link.start, link.end] {
                SceneArt.stroke(&klammer, [point(cx, cy, aussenR - 7, kante), point(cx, cy, aussenR + 1, kante)], mark, 1, 3)
            }
        }
        let mitte = link.start + link.free / 2
        let innen = r - cardHeight / 2 - cardHeight * 0.36 + cardHeight * 0.25 * abs(sin(mitte * .pi / 180))
        let ort = point(cx, cy, innen, mitte)
        let gross = 2.8 - 1.8 * SceneArt.easeIn(fall)

        var stempel = g
        stempel.translateBy(x: ort.x, y: ort.y)
        stempel.rotate(by: .degrees(-7))
        var kopf = stempel
        kopf.scaleBy(x: gross * 0.82, y: gross * 0.82)
        kopf.opacity = min(1, fall * 2.5) * (aufschlag > 0 ? 1 : 0.55)
        let wort = Text("RISS")
            .font(.scaled(22, weight: .black, design: .rounded, maximumScale: 1.3))
            .kerning(3)
            .foregroundColor(mark)
        let geloest = kopf.resolve(wort)
        let masse = geloest.measure(in: CGSize(width: 400, height: 200))
        let rahmen = CGRect(x: -masse.width / 2 - 16, y: -masse.height / 2 - 8, width: masse.width + 32, height: masse.height + 16)
        kopf.drawLayer { schein in
            schein.addFilter(.blur(radius: aufschlag > 0 ? 7 : 15))
            schein.stroke(Path(roundedRect: rahmen, cornerRadius: 6), with: .color(mark), lineWidth: 3.2)
            schein.draw(geloest, at: .zero, anchor: .center)
        }
        kopf.stroke(Path(roundedRect: rahmen, cornerRadius: 6), with: .color(mark), lineWidth: 3.2)
        kopf.stroke(Path(roundedRect: rahmen.insetBy(dx: 6, dy: 6), cornerRadius: 4), with: .color(mark), lineWidth: 1.2)
        kopf.draw(geloest, at: .zero, anchor: .center)

        // Der Aufschlag: eine Druckwelle um den Stempel und ein paar Kruemel
        let s = t - 0.36
        guard s >= 0, s < 0.5 else { return }
        let k = s / 0.5, w = 1 + 0.7 * SceneArt.easeOut(k)
        let welle = CGRect(x: rahmen.minX * w, y: rahmen.minY * w, width: rahmen.width * w, height: rahmen.height * w)
        var druck = stempel
        druck.scaleBy(x: 0.82, y: 0.82)
        druck.stroke(Path(roundedRect: welle, cornerRadius: 6 * w), with: .color(mark.opacity(0.6 * (1 - k))), lineWidth: 2.5 * (1 - k) + 0.5)
        for i in 0..<10 {
            let wi = SceneArt.unit(i, 330) * 2 * .pi
            let d = Double(rahmen.width) / 2 + 50 * SceneArt.easeOut(k) * SceneArt.unit(i, 331)
            SceneArt.circle(&druck, cos(wi) * d * 1.1, sin(wi) * d * 0.5, 1.6 * (1 - k), mark, 0.8)
        }
    }
}
