//
//  WorldGrounds.swift
//  BeerStats
//
//  Der Grund jeder Spielwelt – Holz, Rasen, Backstein, Beton, Filmkorn.
//
//  Gezeichnet mit demselben Werkzeug wie die Szenen (`SceneArt`) und mit
//  derselben Rechnung wie in der Vorschau, in der jede Welt vorher im
//  Browser abgestimmt wurde. Texturen sind gerechnet, nicht geladen: keine
//  Bilddatei, keine Lizenzfrage, und der Zufall ist gerechneter Zufall
//  (`EffectNoise`) – sonst spraenge die Maserung bei jedem Neuzeichnen.
//
//  Zwei Dinge fuer die Leistung: Korn, Raster und Maserung landen jeweils in
//  EINEM Pfad (tausend Punkte sind ein Zeichenbefehl), und gezeichnet wird
//  einmal – `WorldGround` ist gleichsetzbar, ein Tastendruck im Spiel rechnet
//  den Grund nicht neu. Nur drei Welten bewegen sich leise (Glut, Lampe,
//  Filmkorn), und das nur, wenn die Einstellung "Hintergrund" es zulaesst.
//

import SwiftUI

// MARK: - Die Ansicht

/// Der Grund einer Welt, ueber die ganze Flaeche.
///
/// Die Einstellung "Hintergrund" gilt in jeder Welt: Schlicht zeigt nur die
/// Grundfarbe, Ruhig die Textur, Blasen dazu die leise Bewegung der Welt.
struct WorldGround: View, Equatable {

    let world: GameWorld
    let plain: Bool
    let moves: Bool

    var body: some View {
        Group {
            if moves {
                // Leise Bewegung braucht keine 60 Bilder je Sekunde
                SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                    Canvas { context, size in
                        let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
                        SceneArt.ground(world, &context, size, t, plain: plain)
                    }
                }
            } else {
                Canvas { context, size in
                    SceneArt.ground(world, &context, size, 0, plain: plain)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

// MARK: - Werkzeug fuer Flaechen

extension SceneArt {

    static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r / 255, green: g / 255, blue: b / 255)
    }

    static func box(_ g: inout GraphicsContext, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: Color, _ alpha: Double) {
        guard alpha > 0.001, w > 0, h > 0 else { return }
        g.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(color.opacity(alpha)))
    }

    static func roundBox(_ g: inout GraphicsContext, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double, _ color: Color, _ alpha: Double) {
        guard alpha > 0.001, w > 0, h > 0 else { return }
        g.fill(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r), with: .color(color.opacity(alpha)))
    }

    static func roundBoxStroke(_ g: inout GraphicsContext, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double, _ color: Color, _ alpha: Double, _ width: Double) {
        guard alpha > 0.001, w > 0, h > 0 else { return }
        g.stroke(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r), with: .color(color.opacity(alpha)), lineWidth: width)
    }

    /// Ein Verlauf ueber die ganze Flaeche.
    static func wash(_ g: inout GraphicsContext, _ size: CGSize, from: Point, to: Point, _ stops: [(Double, Color, Double)]) {
        let gradient = Gradient(stops: stops.map { Gradient.Stop(color: $0.1.opacity($0.2), location: $0.0) })
        g.fill(Path(CGRect(origin: .zero, size: size)),
               with: .linearGradient(gradient, startPoint: CGPoint(x: from.x, y: from.y), endPoint: CGPoint(x: to.x, y: to.y)))
    }

    static func vignette(_ g: inout GraphicsContext, _ size: CGSize, _ alpha: Double, inner: Double) {
        let w = Double(size.width), h = Double(size.height)
        g.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [Color.black.opacity(0), Color.black.opacity(alpha)]),
            center: CGPoint(x: w / 2, y: h / 2), startRadius: h * inner, endRadius: h * 0.75))
    }

    /// Feines Korn: viele kleine Punkte, fest verteilt – in EINEM Pfad.
    static func grain(_ g: inout GraphicsContext, _ count: Int, _ color: Color, _ alpha: Double, seed: Int, _ rect: CGRect, dot: Double) {
        guard alpha > 0.001 else { return }
        var path = Path()
        let x0 = Double(rect.minX), y0 = Double(rect.minY), w = Double(rect.width), h = Double(rect.height)
        for i in 0..<count {
            let s = dot * (0.5 + unit(i, seed + 3))
            path.addRect(CGRect(x: x0 + unit(i, seed) * w, y: y0 + unit(i, seed + 1) * h, width: s, height: s))
        }
        g.fill(path, with: .color(color.opacity(alpha)))
    }

    /// Viele gerade Linien in einem Strich – Raster, Strahlen, Naehte.
    static func lines(_ g: inout GraphicsContext, _ segments: [(Point, Point)], _ color: Color, _ alpha: Double, _ width: Double) {
        guard alpha > 0.001, !segments.isEmpty else { return }
        var path = Path()
        for (a, b) in segments {
            path.move(to: CGPoint(x: a.x, y: a.y))
            path.addLine(to: CGPoint(x: b.x, y: b.y))
        }
        g.stroke(path, with: .color(color.opacity(alpha)), lineWidth: width)
    }

    /// Schrift auf der Leinwand – nur fuer Zierde. Was gelesen werden muss,
    /// steht als echter Text in der Ansicht (VoiceOver, Systemgroesse).
    static func label(_ g: inout GraphicsContext, _ string: String, _ x: Double, _ y: Double, _ font: Font, _ color: Color, _ alpha: Double) {
        guard alpha > 0.001 else { return }
        g.draw(Text(string).font(font).foregroundColor(color.opacity(alpha)), at: CGPoint(x: x, y: y), anchor: .center)
    }

    /// Schwarz-gelbe Warnstreifen in einem Band.
    static func hazard(_ g: inout GraphicsContext, _ band: [Point], stripe: Double) {
        var c = g
        var umriss = Path()
        umriss.move(to: CGPoint(x: band[0].x, y: band[0].y))
        for p in band.dropFirst() { umriss.addLine(to: CGPoint(x: p.x, y: p.y)) }
        umriss.closeSubpath()
        c.clip(to: umriss)
        c.fill(umriss, with: .color(Color.black.opacity(0.85)))
        var streifen = Path()
        for i in -80..<80 {
            let x = Double(i) * stripe * 2
            streifen.move(to: CGPoint(x: x, y: -40))
            streifen.addLine(to: CGPoint(x: x + stripe, y: -40))
            streifen.addLine(to: CGPoint(x: x + stripe + 1400, y: 1400))
            streifen.addLine(to: CGPoint(x: x + 1400, y: 1400))
            streifen.closeSubpath()
        }
        c.fill(streifen, with: .color(rgb(240, 196, 40).opacity(0.9)))
    }
}

// MARK: - Die Gruende

extension SceneArt {

    /// Der Grund einer Welt. `plain` ist "Hintergrund: Schlicht" – nur die
    /// Grundfarbe, ohne Textur.
    static func ground(_ world: GameWorld, _ g: inout GraphicsContext, _ size: CGSize, _ t: Double, plain: Bool) {
        let w = Double(size.width), h = Double(size.height)
        switch world {
        case .campfire: campfireGround(&g, w, h, t, plain)
        case .racetrack: racetrackGround(&g, w, h, plain)
        case .nightBus: nightBusGround(&g, w, h, plain)
        case .twoPiles: twoPilesGround(&g, w, h, plain)
        case .neonSign: brickGround(&g, w, h, plain)
        case .recordShelf: recordShelfGround(&g, w, h, plain)
        case .regularsTable: tableGround(&g, w, h, plain)
        case .underTheCup: backroomGround(&g, w, h, t, plain)
        case .lieDetector: graphPaperGround(&g, w, h, plain)
        case .secretFile: desktopGround(&g, w, h, plain)
        case .foreheadCard: spotlightGround(&g, w, h, plain)
        case .boardGame: boardGround(&g, w, h, plain)
        case .quizShow: studioGround(&g, w, h, plain)
        case .hourglass: sandGround(&g, w, h, plain)
        case .showOfHands: raysGround(&g, w, h, plain)
        case .trumpCards: graphiteGround(&g, w, h, plain)
        case .silentFilm: filmGround(&g, w, h, t, plain)
        case .wavelength: dialGround(&g, w, h, plain)
        case .bunker: concreteGround(&g, w, h, plain)
        case .highNoon: desertGround(&g, w, h, plain)
        case .casino: baizeGround(&g, w, h, plain)
        case .pasture: meadowGround(&g, w, h, plain)
        case .gafferTape: corkGround(&g, w, h, plain)
        case .bingoHall: bingoGround(&g, w, h, plain)
        case .decree: velvetGround(&g, w, h, plain)
        case .departureBoard: boardRoomGround(&g, w, h, plain)
        case .stadium: stadiumGround(&g, w, h, plain)
        }
    }

    private static func full(_ w: Double, _ h: Double) -> CGSize { CGSize(width: w, height: h) }

    // Ring of Fire: dunkle Dielen, aus der Mitte glimmt es
    private static func campfireGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ t: Double, _ plain: Bool) {
        box(&g, 0, 0, w, h, rgb(22, 15, 10), 1)
        if !plain {
            var naehte: [(Point, Point)] = []
            for b in 0...Int(w / 60) + 1 {
                let x0 = Double(b) * 60 - 10
                box(&g, x0, 0, 60, h, rgb(44, 30, 19), unit(b, 6) * 0.8)
                for k in 0..<5 {
                    let xx = x0 + 8 + Double(k) * 11 + noise(k + b * 9, 3) * 3
                    var punkte: [Point] = []
                    for y in stride(from: -10.0, through: h + 10, by: 24) {
                        let welle = 1.8 * sin(y * 0.018 + Double(k + b))
                        punkte.append((xx + welle, y))
                    }
                    stroke(&g, punkte, rgb(8, 5, 3), 0.25, 1)
                }
                naehte.append(((x0, 0), (x0, h)))
            }
            lines(&g, naehte, rgb(6, 4, 2), 0.8, 2)
        }
        let atem = 0.5 + 0.5 * sin(t * 1.7) * sin(t * 2.9)
        glow(&g, w / 2, h * 0.47, 280, rgb(255, 110, 30), 0.2 + 0.06 * atem)
        vignette(&g, full(w, h), 0.7, inner: 0.25)
    }

    // Pferderennen: gemaehter Rasen in Streifen
    private static func racetrackGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        box(&g, 0, 0, w, h, rgb(17, 50, 29), 1)
        if !plain {
            for s in 0...Int(w / 42) where s % 2 == 1 { box(&g, Double(s) * 42, 0, 42, h, rgb(24, 62, 37), 1) }
            grain(&g, 900, rgb(8, 30, 16), 0.35, seed: 61, CGRect(x: 0, y: 0, width: w, height: h), dot: 1.6)
        }
        vignette(&g, full(w, h), 0.55, inner: 0.3)
    }

    // Bussfahrer: Nachtblau, an den Raendern der Bezug eines Bussitzes
    private static func nightBusGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        wash(&g, full(w, h), from: (0, 0), to: (0, h), [(0, rgb(16, 22, 42), 1), (1, rgb(8, 11, 22), 1)])
        if !plain {
            let farben = [rgb(40, 170, 170), rgb(190, 60, 130), rgb(230, 180, 60)]
            for seite in 0..<2 {
                let x0 = seite == 0 ? 0 : w - 30
                box(&g, x0, 0, 30, h, rgb(26, 30, 70), 1)
                var muster = [Path(), Path(), Path()]
                for r in 0..<Int(h / 15) + 1 {
                    for s in 0..<2 {
                        let cx = x0 + 8 + Double(s) * 13 + Double(r % 2) * 6, cy = Double(r) * 15
                        let k = (r + s) % 3
                        muster[k].move(to: CGPoint(x: cx, y: cy - 5))
                        muster[k].addLine(to: CGPoint(x: cx + 4, y: cy))
                        muster[k].addLine(to: CGPoint(x: cx, y: cy + 5))
                        muster[k].addLine(to: CGPoint(x: cx - 4, y: cy))
                        muster[k].closeSubpath()
                    }
                }
                for k in 0..<3 { g.fill(muster[k], with: .color(farben[k].opacity(0.5))) }
            }
            lines(&g, [((31, 0), (31, h)), ((w - 31, 0), (w - 31, h))], rgb(190, 196, 210), 0.35, 2)
        }
        vignette(&g, full(w, h), 0.5, inner: 0.32)
    }

    // Wahrheit oder Pflicht: diagonal geteilt, Warnstreifen auf der Naht
    private static func twoPilesGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        let rechts = h * 0.36, links = h * 0.73
        fill(&g, [(0, 0), (w, 0), (w, rechts), (0, links)], rgb(12, 24, 46), 1)
        fill(&g, [(w, rechts), (w, h), (0, h), (0, links)], rgb(44, 11, 15), 1)
        if !plain {
            for i in 0..<9 {
                label(&g, "?", 30 + unit(i, 4) * (w - 60), h * 0.14 + unit(i, 5) * h * 0.4,
                      .system(size: 40 + 50 * unit(i, 6), design: .serif).italic(), .white, 0.045)
            }
            hazard(&g, [(w, rechts - 8), (w, rechts + 8), (0, links + 8), (0, links - 8)], stripe: 9)
        }
        vignette(&g, full(w, h), 0.5, inner: 0.3)
    }

    // Ich hab noch nie: Backsteinwand, auf die das Neon faellt
    private static func brickGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        box(&g, 0, 0, w, h, rgb(26, 14, 12), 1)
        if !plain {
            var hell = Path(), dunkel = Path()
            for r in 0..<Int(h / 26) + 1 {
                for s in -1..<Int(w / 60) + 1 {
                    let x = Double(s) * 60 + Double(r % 2) * 30, y = Double(r) * 26
                    let ziegel = Path(roundedRect: CGRect(x: x + 2, y: y + 2, width: 56, height: 22), cornerRadius: 3)
                    if unit(r * 9 + s, 5) > 0.5 { hell.addPath(ziegel) } else { dunkel.addPath(ziegel) }
                }
            }
            g.fill(dunkel, with: .color(rgb(58, 26, 20)))
            g.fill(hell, with: .color(rgb(80, 36, 27)))
            grain(&g, 1400, .black, 0.25, seed: 77, CGRect(x: 0, y: 0, width: w, height: h), dot: 1.4)
        }
        wash(&g, full(w, h), from: (0, 0), to: (0, h), [(0, .black, 0.35), (0.5, .black, 0.12), (1, .black, 0.55)])
        glow(&g, w / 2, h * 0.45, 300, rgb(255, 72, 170), 0.1)
    }

    // Zeitstrahl: Wand aus dunklem Nussbaum
    private static func recordShelfGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        wash(&g, full(w, h), from: (0, 0), to: (0, h), [(0, rgb(30, 21, 14), 1), (1, rgb(16, 11, 8), 1)])
        if !plain {
            var paneele: [(Point, Point)] = []
            for k in 0...Int(w / 48) {
                let x = Double(k) * 48 + 10
                let oben: Point = (x, 0)
                let unten: Point = (x, h)
                paneele.append((oben, unten))
            }
            lines(&g, paneele, rgb(10, 6, 4), 0.4, 2)
        }
        vignette(&g, full(w, h), 0.55, inner: 0.3)
    }

    // Schocken: Bretter eines Kneipentischs, darueber die Lampe
    private static func tableGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        box(&g, 0, 0, w, h, rgb(46, 29, 17), 1)
        if !plain {
            var fugen: [(Point, Point)] = []
            for b in 0...Int(h / 150) + 1 {
                let y0 = Double(b) * 150 - 20
                box(&g, 0, y0, w, 150, rgb(70, 45, 26), unit(b, 4) * 0.6)
                for k in 0..<13 {
                    let yy = y0 + 8 + Double(k) * 11 + noise(k + b * 20, 2) * 3
                    var punkte: [Point] = []
                    for x in stride(from: -10.0, through: w + 10, by: 18) {
                        let welle = 2.2 * sin(x * 0.021 + Double(k + b))
                        let kraeuseln = 1.2 * sin(x * 0.08 + Double(b) * 3)
                        punkte.append((x, yy + welle + kraeuseln))
                    }
                    stroke(&g, punkte, k % 3 == 0 ? rgb(110, 74, 44) : rgb(20, 12, 7), k % 3 == 0 ? 0.1 : 0.18, k % 4 == 0 ? 2 : 1)
                }
                fugen.append(((0, y0), (w, y0)))
            }
            lines(&g, fugen, rgb(12, 7, 4), 0.7, 2)
        }
        glow(&g, w / 2, h * 0.13, 460, rgb(255, 196, 128), 0.11)
        vignette(&g, full(w, h), 0.62, inner: 0.28)
    }

    // Maexchen: Hinterzimmer, eine Lampe schwingt ueber dem Tisch
    private static func backroomGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ t: Double, _ plain: Bool) {
        wash(&g, full(w, h), from: (0, 0), to: (0, h), [(0, rgb(16, 12, 10), 1), (1, rgb(9, 7, 6), 1)])
        let schwung = 0.045 * sin(t * 1.3), ax = w / 2, ly = h * 0.16, boden = h * 0.74
        var c = g
        c.translateBy(x: ax, y: 0)
        c.rotate(by: .radians(schwung))
        c.translateBy(x: -ax, y: 0)
        if !plain {
            fill(&c, [(ax - 40, ly + 40), (ax + 40, ly + 40), (ax + 240, boden), (ax - 240, boden)], from: (ax, ly), to: (ax, boden),
                 [(0, rgb(255, 222, 160), 0.2), (1, rgb(255, 222, 160), 0)])
            for i in 0..<18 {
                let z = fract(t * 0.05 + unit(i, 3))
                circle(&c, ax + noise(i, 4) * 120 * (0.3 + z), ly + 60 + z * (boden - ly - 80), 1.2, rgb(255, 230, 190), 0.35 * sin(z * .pi))
            }
        }
        // Die Lampe selbst: Kabel, gruener Emailleschirm, Gluehbirne
        stroke(&c, [(ax, 0), (ax, ly - 20)], rgb(40, 36, 32), 1, 2)
        fill(&c, [(ax - 16, ly - 22), (ax + 16, ly - 22), (ax + 56, ly + 34), (ax - 56, ly + 34)], from: (ax, ly - 22), to: (ax, ly + 34),
             [(0, rgb(30, 74, 52), 1), (1, rgb(18, 50, 34), 1)])
        glow(&c, ax, ly + 34, 46, rgb(255, 236, 190), 0.9)
        circle(&c, ax, ly + 34, 10, rgb(255, 244, 214), 1)
        glow(&g, ax + sin(schwung) * 150, boden - 20, 240, rgb(255, 210, 150), 0.12)
        vignette(&g, full(w, h), 0.7, inner: 0.25)
    }

    // Zwei Wahrheiten: Millimeterpapier
    private static func graphPaperGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        box(&g, 0, 0, w, h, rgb(13, 21, 19), 1)
        if !plain {
            var fein: [(Point, Point)] = [], grob: [(Point, Point)] = []
            for k in 0...Int(w / 6) { let x = Double(k) * 6; if k % 5 == 0 { grob.append(((x, 0), (x, h))) } else { fein.append(((x, 0), (x, h))) } }
            for k in 0...Int(h / 6) { let y = Double(k) * 6; if k % 5 == 0 { grob.append(((0, y), (w, y))) } else { fein.append(((0, y), (w, y))) } }
            lines(&g, fein, rgb(90, 170, 150), 0.045, 1)
            lines(&g, grob, rgb(90, 170, 150), 0.12, 1)
        }
        vignette(&g, full(w, h), 0.55, inner: 0.3)
    }

    // Der Spion: Schreibtisch eines Agenten, darunter eine Weltkarte
    private static func desktopGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        wash(&g, full(w, h), from: (0, 0), to: (0, h), [(0, rgb(26, 25, 21), 1), (1, rgb(11, 11, 10), 1)])
        if !plain {
            let cx = w / 2, cy = h * 0.56, rx = w * 0.85, ry = h * 0.3
            var netz: [(Point, Point)] = []
            for lat in stride(from: -75.0, through: 75, by: 15) {
                let la = lat * .pi / 180, y = cy - ry * sin(la), hb = rx * cos(la)
                netz.append(((cx - hb, y), (cx + hb, y)))
            }
            lines(&g, netz, rgb(150, 175, 160), 0.075, 1)
            for lon in stride(from: -180.0, through: 180, by: 20) {
                let punkte: [Point] = stride(from: -90.0, through: 90, by: 6).map { lat in
                    let la = lat * .pi / 180
                    return (cx + rx * (lon / 180) * cos(la), cy - ry * sin(la))
                }
                stroke(&g, punkte, rgb(150, 175, 160), 0.075, 1)
            }
            label(&g, "52°31′N  13°24′E", 80, h - 150, .system(size: 10, design: .monospaced), rgb(166, 156, 141), 0.4)
        }
        glow(&g, w * 0.1, h * 0.14, 420, rgb(255, 214, 150), 0.09)
        vignette(&g, full(w, h), 0.6, inner: 0.3)
    }

    // Wer bin ich?: dunkel, ein Licht von oben auf die Karte
    private static func spotlightGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        box(&g, 0, 0, w, h, rgb(10, 12, 22), 1)
        if !plain {
            fill(&g, [(w / 2 - 30, 0), (w / 2 + 30, 0), (w / 2 + 230, h), (w / 2 - 230, h)], from: (0, 0), to: (0, h),
                 [(0, .white, 0.06), (1, .white, 0)])
        }
        vignette(&g, full(w, h), 0.5, inner: 0.3)
    }

    // 21: bedruckter Karton eines Brettspiels
    private static func boardGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        box(&g, 0, 0, w, h, rgb(12, 40, 44), 1)
        if !plain {
            var leinen: [(Point, Point)] = []
            for i in -Int(h / 14)...Int(w / 14) {
                let x = Double(i) * 14
                leinen.append(((x, 0), (x + h, h)))
                leinen.append(((x + h, 0), (x, h)))
            }
            lines(&g, leinen, .white, 0.022, 1)
            roundBoxStroke(&g, 12, 12, w - 24, h - 24, 34, rgb(120, 200, 190), 0.25, 2)
            roundBoxStroke(&g, 18, 18, w - 36, h - 36, 30, rgb(120, 200, 190), 0.15, 1)
        }
        vignette(&g, full(w, h), 0.5, inner: 0.3)
    }

    // Schaetzmeister: Studio, Licht von oben, Buehne unten
    private static func studioGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        wash(&g, full(w, h), from: (0, 0), to: (0, h), [(0, rgb(22, 14, 52), 1), (1, rgb(10, 6, 24), 1)])
        if !plain {
            fill(&g, [(w / 2 - 20, 0), (w / 2 + 20, 0), (w / 2 + 200, h), (w / 2 - 200, h)], from: (0, 0), to: (0, h),
                 [(0, .white, 0.07), (1, .white, 0)])
        }
        glow(&g, w / 2, h, 360, rgb(180, 60, 220), 0.2)
        vignette(&g, full(w, h), 0.5, inner: 0.3)
    }

    // Kategorien: Petrol, warmes Licht wie Sand
    private static func sandGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        wash(&g, full(w, h), from: (0, 0), to: (0, h), [(0, rgb(10, 28, 32), 1), (1, rgb(6, 14, 16), 1)])
        glow(&g, w / 2, h * 0.56, 260, rgb(226, 186, 120), 0.1)
        if !plain { grain(&g, 700, .white, 0.025, seed: 81, CGRect(x: 0, y: 0, width: w, height: h), dot: 1.2) }
        vignette(&g, full(w, h), 0.55, inner: 0.3)
    }

    // Wer wuerde eher?: Strahlen zur Mitte, wo alle hinzeigen
    private static func raysGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        box(&g, 0, 0, w, h, rgb(28, 14, 48), 1)
        let cx = w / 2, cy = h * 0.56
        if !plain {
            for i in stride(from: 0, to: 24, by: 2) {
                var keil: [Point] = [(cx, cy)]
                keil += arc(cx, cy, 1400, Double(i) / 24 * 2 * .pi, Double(i + 1) / 24 * 2 * .pi, 4)
                fill(&g, keil, .white, 0.035)
            }
        }
        glow(&g, cx, cy, 260, rgb(180, 90, 255), 0.16)
        vignette(&g, full(w, h), 0.55, inner: 0.3)
    }

    // Kennst du deine Leute?: Graphit mit feinen Schraegen
    private static func graphiteGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        box(&g, 0, 0, w, h, rgb(16, 18, 22), 1)
        if !plain {
            var schraegen: [(Point, Point)] = []
            for i in -Int(h / 16)...Int(w / 16) {
                let x = Double(i) * 16
                let oben: Point = (x, 0)
                let unten: Point = (x + h * 0.6, h)
                schraegen.append((oben, unten))
            }
            lines(&g, schraegen, .white, 0.025, 1)
        }
        glow(&g, w / 2, h * 0.45, 300, .white, 0.05)
        vignette(&g, full(w, h), 0.5, inner: 0.3)
    }

    // Pantomime: Stummfilm – Korn, Kratzer, Staub, flackerndes Licht
    private static func filmGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ t: Double, _ plain: Bool) {
        wash(&g, full(w, h), from: (0, 0), to: (0, h), [(0, rgb(52, 52, 50), 1), (0.55, rgb(36, 36, 35), 1), (1, rgb(20, 20, 20), 1)])
        if !plain {
            // 18 Bilder je Sekunde, wie damals – das Korn ist je Bild ein anderes
            let bild = Int(t * 18)
            let alles = CGRect(x: 0, y: 0, width: w, height: h)
            grain(&g, 700, .white, 0.06, seed: bild * 17, alles, dot: 1.3)
            grain(&g, 500, .black, 0.14, seed: bild * 17 + 500, alles, dot: 1.6)
            var kratzer: [(Point, Point)] = []
            for k in 0..<3 {
                let s = Int(t * 3) * 3 + k
                guard unit(s, 41) >= 0.45 else { continue }
                let x = w * unit(s, 42)
                kratzer.append(((x, -10), (x + 4 * noise(s, 43), h + 10)))
            }
            lines(&g, kratzer, .white, 0.14, 1)
            for k in 0..<4 where unit(bild + k * 11, 51) > 0.9 {
                circle(&g, w * unit(bild + k, 52), h * unit(bild + k, 53), 1.5 + 3 * unit(bild + k, 54), .black, 0.5)
            }
        }
        vignette(&g, full(w, h), 0.78, inner: 0.22)
        if !plain {
            let flackern = 0.05 * noise(Int(t * 18), 3) + 0.02 * sin(t * 9)
            box(&g, 0, 0, w, h, flackern > 0 ? .white : .black, abs(flackern))
        }
    }

    // Die Skala: Nachtblau, feine Strahlen vom Rad aus
    private static func dialGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        box(&g, 0, 0, w, h, rgb(10, 24, 34), 1)
        let cx = w / 2, cy = h * 0.57
        if !plain {
            let strahlen: [(Point, Point)] = (0..<36).map { i in
                let a = Double(i) / 36 * 2 * .pi
                return ((cx, cy), (cx + cos(a) * 1400, cy + sin(a) * 1400))
            }
            lines(&g, strahlen, .white, 0.02, 1)
        }
        glow(&g, cx, cy, 260, rgb(60, 200, 220), 0.12)
        vignette(&g, full(w, h), 0.55, inner: 0.3)
    }

    // Bombe: Beton mit Rissen, Warnstreifen oben und unten
    private static func concreteGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        box(&g, 0, 0, w, h, rgb(32, 32, 34), 1)
        if !plain {
            let alles = CGRect(x: 0, y: 0, width: w, height: h)
            grain(&g, 1300, .black, 0.3, seed: 91, alles, dot: 1.8)
            grain(&g, 800, rgb(120, 120, 124), 0.18, seed: 92, alles, dot: 1.4)
            for k in 0..<3 {
                var x = w * unit(k, 93), y = h * unit(k, 94)
                var riss: [Point] = [(x, y)]
                for i in 0..<14 { x += noise(i + k * 20, 95) * 14; y += 10 + unit(i + k * 20, 96) * 8; riss.append((x, y)) }
                stroke(&g, riss, .black, 0.35, 1.5)
            }
            hazard(&g, [(0, 100), (w, 100), (w, 114), (0, 114)], stripe: 12)
            hazard(&g, [(0, h - 150), (w, h - 150), (w, h - 136), (0, h - 136)], stripe: 12)
        }
        vignette(&g, full(w, h), 0.6, inner: 0.28)
    }

    // Reaktionsduell: Wueste in der Daemmerung
    private static func desertGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        let horizont = h * 0.62
        wash(&g, full(w, h), from: (0, 0), to: (0, horizont), [(0, rgb(58, 26, 70), 1), (1, rgb(236, 120, 60), 1)])
        glow(&g, w * 0.68, horizont - 10, 120, rgb(255, 210, 120), 0.6)
        circle(&g, w * 0.68, horizont - 10, 40, rgb(255, 214, 140), 0.95)
        fill(&g, [(-10, horizont + 6), (w * 0.15, horizont - 10), (w * 0.3, horizont - 4), (w * 0.38, horizont - 40), (w * 0.54, horizont - 40),
                  (w * 0.62, horizont), (w + 10, horizont - 6), (w + 10, h + 10), (-10, h + 10)], rgb(52, 24, 22), 1)
        fill(&g, [(-10, horizont + 40), (w + 10, horizont + 30), (w + 10, h + 10), (-10, h + 10)], rgb(34, 16, 14), 1)
        if !plain {
            for (cx, s) in [(w * 0.16, 1.0), (w * 0.8, 0.7)] {
                let by = horizont + 44, kaktus = rgb(26, 12, 12)
                roundBox(&g, cx - 7 * s, by - 70 * s, 14 * s, 70 * s, 7 * s, kaktus, 1)
                roundBox(&g, cx - 26 * s, by - 52 * s, 10 * s, 26 * s, 5 * s, kaktus, 1)
                roundBox(&g, cx - 26 * s, by - 34 * s, 22 * s, 9 * s, 4 * s, kaktus, 1)
                roundBox(&g, cx + 16 * s, by - 60 * s, 10 * s, 30 * s, 5 * s, kaktus, 1)
                roundBox(&g, cx + 6 * s, by - 38 * s, 20 * s, 9 * s, 4 * s, kaktus, 1)
            }
        }
        vignette(&g, full(w, h), 0.5, inner: 0.3)
    }

    // Trink-Roulette: gruener Spieltischfilz mit Goldrand
    private static func baizeGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        box(&g, 0, 0, w, h, rgb(12, 58, 38), 1)
        if !plain {
            let alles = CGRect(x: 0, y: 0, width: w, height: h)
            grain(&g, 1300, .black, 0.22, seed: 71, alles, dot: 1.5)
            grain(&g, 800, rgb(60, 130, 90), 0.14, seed: 72, alles, dot: 1.2)
            roundBoxStroke(&g, 10, 10, w - 20, h - 20, 40, rgb(212, 175, 90), 0.6, 1.5)
            roundBoxStroke(&g, 16, 16, w - 32, h - 32, 35, rgb(212, 175, 90), 0.35, 1)
        }
        vignette(&g, full(w, h), 0.6, inner: 0.28)
    }

    // Die Herde: Weide in der Daemmerung, Zaun, Gras
    private static func meadowGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        let horizont = h * 0.64
        wash(&g, full(w, h), from: (0, 0), to: (0, horizont), [(0, rgb(26, 32, 70), 1), (0.75, rgb(150, 90, 100), 1), (1, rgb(230, 140, 90), 1)])
        fill(&g, [(-10, horizont), (w * 0.2, horizont - 34), (w * 0.44, horizont - 20), (w * 0.67, horizont - 44), (w + 10, horizont - 20),
                  (w + 10, h + 10), (-10, h + 10)], rgb(22, 52, 32), 1)
        fill(&g, [(-10, horizont + 60), (w * 0.3, horizont + 45), (w * 0.66, horizont + 56), (w + 10, horizont + 40), (w + 10, h + 10), (-10, h + 10)],
             rgb(18, 44, 27), 1)
        if !plain {
            let zaun = horizont + 12
            for k in 0...Int(w / 44) { roundBox(&g, Double(k) * 44 + 10, zaun, 7, 44, 2, rgb(80, 56, 36), 1) }
            lines(&g, [((0, zaun + 12), (w, zaun + 10)), ((0, zaun + 30), (w, zaun + 28))], rgb(96, 68, 44), 1, 4)
            grain(&g, 500, rgb(40, 90, 50), 0.4, seed: 101, CGRect(x: 0, y: horizont + 50, width: w, height: h - horizont - 50), dot: 2)
        }
        vignette(&g, full(w, h), 0.45, inner: 0.32)
    }

    // Verbotene Woerter: dunkle Korkwand
    private static func corkGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        box(&g, 0, 0, w, h, rgb(58, 41, 28), 1)
        if !plain {
            let alles = CGRect(x: 0, y: 0, width: w, height: h)
            grain(&g, 1500, rgb(30, 20, 12), 0.55, seed: 111, alles, dot: 2.2)
            grain(&g, 1100, rgb(110, 80, 54), 0.45, seed: 112, alles, dot: 1.8)
        }
        vignette(&g, full(w, h), 0.6, inner: 0.28)
    }

    // Trinkbingo: Bingohalle mit verstreuten Kugeln
    private static func bingoGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        box(&g, 0, 0, w, h, rgb(24, 14, 30), 1)
        if !plain {
            let farben = [rgb(230, 60, 60), rgb(60, 140, 230), rgb(240, 190, 50), rgb(80, 190, 110)]
            for i in 0..<16 {
                let x = unit(i, 121) * w, y = unit(i, 122) * h, r = 16 + 18 * unit(i, 123)
                circle(&g, x, y, r, farben[i % 4], 0.14)
                circle(&g, x, y, r * 0.55, .white, 0.1)
            }
        }
        vignette(&g, full(w, h), 0.55, inner: 0.3)
    }

    // Regel des Abends: roter Samt, Licht von oben
    private static func velvetGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        box(&g, 0, 0, w, h, rgb(42, 10, 16), 1)
        if !plain {
            var dunkel: [(Point, Point)] = [], hell: [(Point, Point)] = []
            for k in 0...Int(w / 5) {
                let x = Double(k) * 5
                if k % 2 == 0 { hell.append(((x, 0), (x, h))) } else { dunkel.append(((x, 0), (x, h))) }
            }
            lines(&g, dunkel, .black, 0.12, 2)
            lines(&g, hell, rgb(90, 20, 30), 0.12, 2)
        }
        glow(&g, w / 2, 0, 520, rgb(255, 210, 150), 0.12)
        vignette(&g, full(w, h), 0.65, inner: 0.25)
    }

    // Was spielen wir?: der Raum hinter der Abfahrtstafel
    private static func boardRoomGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        box(&g, 0, 0, w, h, rgb(12, 12, 13), 1)
        if !plain {
            var zeilen: [(Point, Point)] = []
            for k in 0...Int(h / 4) {
                let y = Double(k) * 4
                let links: Point = (0, y)
                let rechts: Point = (w, y)
                zeilen.append((links, rechts))
            }
            lines(&g, zeilen, .white, 0.014, 1)
        }
        vignette(&g, full(w, h), 0.5, inner: 0.3)
    }

    // Turnier: Stadion bei Nacht, Flutlicht, Ränge
    private static func stadiumGround(_ g: inout GraphicsContext, _ w: Double, _ h: Double, _ plain: Bool) {
        box(&g, 0, 0, w, h, rgb(8, 10, 18), 1)
        if !plain {
            for links in [true, false] {
                let x = links ? 0.0 : w, richtung = links ? 1.0 : -1.0
                fill(&g, [(x, 0), (x + 60 * richtung, 0), (w / 2 - 40 * richtung, h), (w / 2 - 140 * richtung, h)],
                     from: (x, 0), to: (w / 2, h), [(0, .white, 0.1), (1, .white, 0)])
                glow(&g, x, 40, 160, rgb(230, 240, 255), 0.3)
            }
            var raenge = Path()
            for i in 0..<240 {
                let r = 2 + unit(i, 153) * 2
                raenge.addEllipse(in: CGRect(x: unit(i, 151) * w - r, y: h * 0.77 + unit(i, 152) * h * 0.07 - r, width: 2 * r, height: 2 * r))
            }
            g.fill(raenge, with: .color(rgb(40, 44, 60).opacity(0.9)))
        }
        vignette(&g, full(w, h), 0.5, inner: 0.3)
    }
}
