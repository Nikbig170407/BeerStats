//
//  RingTable.swift
//  BeerStats
//
//  Der Tisch von Ring of Fire in Bewegung: austeilen, losen, herausheben.
//
//  Vorschlag 2 vom 4. November, in der Vorschau "Ring of Fire – Auftritte"
//  abgestimmt: Die Karten wirbeln in Boegen mit Drall auf ihre Plaetze und
//  setzen mit einem Funken auf, das Licht zieht einen Funkenschweif hinter
//  sich her, beim Halt geht ein Ruck durch den Ring, und die gezogene Karte
//  steigt verdeckt in einer Lichtsaeule auf.
//
//  Zwei Regeln von vorher gelten weiter. Der Tisch VERRAET NICHTS: Die
//  Lichtsaeule ist fuer jede Karte gleich warm, ihre Farbe kaeme erst mit
//  dem Kartenscreen. Und jede Rechnung steht einmal da – wann eine Karte
//  landet (`RingMotion.dealDelay`), wann das Licht wo steht
//  (`RingSpotlightPlan`), wo die gehobene Karte ist (`liftPose`) –, und
//  die Karten und die Funken lesen dieselbe.
//
//  Bewegungen haengen an einem Fortschritt, den SwiftUI animiert, und die
//  Kurve rechnet der Effekt selbst (`RingDealFlight`, `RingLiftFlight`):
//  Ein Bogen mit Drall ist keine gerade Strecke, und `offset` oder
//  `scaleEffect` allein laufen nur gerade vom Anfangs- zum Endwert – ein
//  `sin` dazwischen saehe nie jemand.
//

import SwiftUI

/// Wie sich der Ring bewegt. Einsammeln und Herausheben sind zuerst in der
/// Vorschau "Riss im Ring" gezeichnet worden, mit denselben Zahlen.
enum RingMotion {
    /// So lange faehrt der Kartenscreen nach unten weg, bevor nach einem
    /// Riss eingesammelt wird.
    static let coverAway = 0.3
    /// Einsammeln zur Mitte, alle zugleich.
    static let gather = 0.28
    /// So lange fliegt eine einzelne Karte beim Austeilen.
    static let dealDuration = 0.34
    /// Ueber so viel Zeit verteilt sich das Austeilen um den Ring – die
    /// letzte Karte startet so viel spaeter als die erste.
    static let dealSpread = 0.55
    /// Vor dem ersten Austeilen: der Wechsel vom Vorspann zum Tisch.
    static let beforeFirstDeal = 0.25
    /// Eine kurze Pause zwischen Setzen und Animieren.
    static let pause = 0.05
    /// Der Stapel in der Mitte: kleiner als die Karten im Ring und etwas
    /// gegen den Uhrzeigersinn verdreht, damit er nach Stapel aussieht.
    static let pileScale: CGFloat = 0.6
    static let pileTwist = 40.0
    /// Die gezogene Karte hebt sich heraus: so lange, so weit nach innen,
    /// und so viel kleiner wird sie dabei – am Ende so gross wie eine
    /// Karte im Stapel.
    static let lift = 0.38
    static let liftInward: CGFloat = 0.75
    static let liftShrink: CGFloat = 0.62
    /// Der Kartenscreen kommt, wenn die Karte aus dem Ring ist.
    static let actionDelay = 0.42
    /// So lange glimmt das Lauflicht auf einer Karte nach. In der schnellen
    /// Phase wird daraus ein langer Schweif, im Auslaufen einer ueber wenige
    /// Karten.
    static let afterglow = 0.35
    /// So lange dauert der Ruck, der beim Halt durch den Ring geht.
    static let nod = 0.35

    /// Wann die Karte an dieser Stelle losfliegt, nachdem ausgeteilt wird –
    /// Karte fuer Karte im Uhrzeigersinn.
    static func dealDelay(at position: Int, of count: Int) -> Double {
        Double(position) / Double(max(1, count)) * dealSpread
    }
}

// MARK: - Was gerade am Tisch passiert

/// Ein Augenblick am Tisch, den die Leinwand ueber dem Ring begleitet.
struct RingTableBeat: Identifiable {

    enum Kind {
        /// Ausgeteilt wird – die Winkel aller Plaetze, in Ringfolge.
        case deal(angles: [Double])
        /// Das Licht laeuft und haelt, die Karte hebt sich heraus. Die
        /// Winkel gehoeren zu den Schritten des Plans und laufen ueber 360
        /// hinaus weiter, damit der Schweif an der Naht nicht abreisst.
        case draw(plan: RingSpotlightPlan, stepAngles: [Double])
    }

    let kind: Kind
    /// Ab hier zaehlt die Zeit – derselbe Augenblick, an dem die Karten
    /// losfliegen oder das Licht loslaeuft.
    let start: Date

    var id: Date { start }

    /// Nach so vielen Sekunden ist nichts mehr zu zeichnen.
    var ends: Double {
        switch kind {
        case .deal(let angles):
            return RingMotion.dealDelay(at: angles.count - 1, of: angles.count)
                + RingMotion.dealDuration + RingTableArt.landing
        case .draw(let plan, _):
            return plan.halt + RingTableArt.columnEnd
        }
    }
}

/// Die Leinwand ueber dem Ring: Funken beim Aufsetzen, Schweif des Lichts,
/// Ruck beim Halt, Lichtsaeule. Haelt an, wenn der Augenblick vorbei ist –
/// danach laeuft keine Zeitleiste mehr mit.
struct RingTableEffects: View {

    let beat: RingTableBeat
    let radius: CGFloat
    let cardHeight: CGFloat

    @State private var over = false

    var body: some View {
        Group {
            if !over {
                // Voll ausgeschrieben (Lessons Learned Nr. 15)
                SwiftUI.TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        RingTableArt.draw(
                            &context,
                            size,
                            beat: beat,
                            radius: Double(radius),
                            cardHeight: Double(cardHeight),
                            t: timeline.date.timeIntervalSince(beat.start)
                        )
                    }
                }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .task {
            let rest = beat.ends - Date().timeIntervalSince(beat.start)
            if rest > 0 {
                try? await Task.sleep(nanoseconds: UInt64(rest * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            over = true
        }
    }
}

// MARK: - Die Rechnung

enum RingTableArt {

    /// So lange glimmt der Funke, mit dem eine Karte aufsetzt.
    static let landing = 0.3
    /// So lange fliegt ein Funke, den das Licht hinter sich laesst.
    static let sparkLife = 0.6
    /// So weit reicht der Schweif zurueck, in Sekunden.
    static let trailLength = 0.16
    /// So lange verglimmt der Schweif nach dem Halt.
    static let trailFade = 0.5
    /// So lange laeuft die Welle des Halts.
    static let ripple = 0.45
    /// Bis hier steht die Lichtsaeule – sie verlischt unter dem
    /// Kartenscreen.
    static let columnEnd = 0.95
    /// So hoch schwebt die gehobene Karte auf ihrem Weg, als Anteil ihrer
    /// Hoehe.
    static let hoverShare = 0.22
    /// So stark ist der Ruck beim Halt.
    static let nodDepth = 0.04

    /// Die Kartenhoehe der Vorschau. Alle Weiten unten sind dort gerechnet
    /// und wachsen mit der Karte – bei 52 Karten ist sie halb so gross.
    private static let referenceHeight = 72.0

    private static let sparkHot = SceneArt.rgb(255, 240, 180)
    private static let sparkWarm = SceneArt.rgb(255, 150, 50)
    private static let sparkCool = SceneArt.rgb(220, 70, 30)

    // MARK: Bewegungen

    /// Die Karte auf dem Weg aus dem Stapel an ihren Platz: ein Bogen ueber
    /// einen Punkt, der gegen den Uhrzeigersinn versetzt liegt, eine volle
    /// Drehung um sich selbst, und beim Ankommen federt sie kurz ueber ihre
    /// Groesse hinaus. Bei 0 liegt sie im Stapel, bei 1 genau auf ihrem
    /// Platz – ohne Ruck, denn der Drall endet bei 1 auf null.
    ///
    /// Orte relativ zur Mitte des Rings, Winkel in Grad im Uhrzeigersinn.
    static func dealPose(_ progress: Double, angle: Double, radius: Double) -> (x: Double, y: Double, turn: Double, scale: Double) {
        let u = SceneArt.clamp(progress)
        let e = SceneArt.easeOut(u)
        let q = 1 - e
        let ziel = RingTearArt.point(0, 0, radius, angle)
        let knick = RingTearArt.point(0, 0, radius * 0.9, angle - 55)
        let x = 2 * q * e * knick.x + e * e * ziel.x
        let y = 2 * q * e * knick.y + e * e * ziel.y
        // Der kurze Weg zur Endlage: Rechts liegende Karten drehen
        // rechtsherum dorthin, links liegende linksherum
        let endlage = angle > 160 ? angle - 360 : angle
        let drehung = -RingMotion.pileTwist + (endlage + RingMotion.pileTwist) * e - 360 * q
        let stapel = Double(RingMotion.pileScale)
        let groesse = stapel + (1 - stapel) * backOut(u, 1.8) + 0.22 * sin(.pi * u)
        return (x, y, drehung, groesse)
    }

    /// Die gezogene Karte auf dem Weg aus dem Ring: Sie hebt sich, schwebt
    /// kurz, dreht sich in die Lage des Stapels und wird klein. Erst am
    /// Ende verblasst sie – vorher sieht man, woher sie kommt.
    struct LiftPose {
        /// Wie weit draussen sie liegt, als Anteil des Radius.
        let reach: Double
        let scale: Double
        /// Eigene Drehung gegenueber ihrer Lage im Ring, in Grad.
        let turn: Double
        /// Wie hoch sie schwebt, 0 bis 1 von `hoverShare`.
        let hover: Double
        let opacity: Double
    }

    static func liftPose(_ progress: Double, angle: Double) -> LiftPose {
        let u = SceneArt.clamp(progress)
        let e = SceneArt.easeOut(u)
        let bogen = sin(.pi * e)
        let lage = angle > 180 ? angle - 360 : angle
        return LiftPose(
            reach: 1 - Double(RingMotion.liftInward) * e,
            scale: (1 - Double(RingMotion.liftShrink) * e) * (1 + 0.12 * bogen),
            turn: -(lage + RingMotion.pileTwist) * e,
            hover: bogen,
            opacity: 1 - SceneArt.smooth((u - 0.6) / 0.4)
        )
    }

    /// Der Ruck beim Halt: schnell hinaus, langsam zurueck, und nach
    /// `RingMotion.nod` genau null.
    static func nod(_ s: Double) -> Double {
        guard s > 0, s < RingMotion.nod else { return 0 }
        let x = s / 0.05
        return x * exp(1 - x) * (1 - s / RingMotion.nod)
    }

    private static func backOut(_ x: Double, _ s: Double) -> Double {
        let u = SceneArt.clamp(x) - 1
        return 1 + (s + 1) * u * u * u + s * u * u
    }

    // MARK: Zeichnen

    /// Was die Leinwand vom Ring wissen muss.
    private struct Ring {
        let cx: Double
        let cy: Double
        let radius: Double
        let cardHeight: Double
        /// Wie gross die Dinge gezeichnet werden.
        let k: Double
    }

    static func draw(_ g: inout GraphicsContext, _ size: CGSize, beat: RingTableBeat, radius: Double, cardHeight: Double, t: Double) {
        let ring = Ring(
            cx: Double(size.width) / 2,
            cy: Double(size.height) / 2,
            radius: radius,
            cardHeight: cardHeight,
            k: min(1.4, max(0.5, cardHeight / referenceHeight))
        )
        var b = SceneBrush(g)
        switch beat.kind {
        case .deal(let angles):
            deal(&b, ring, angles, t)
        case .draw(let plan, let stepAngles):
            spotlight(&b, ring, plan, stepAngles, t)
        }
        b.flush()
    }

    /// Der Stapel glimmt, solange noch Karten darin liegen, und jede Karte
    /// setzt mit einem Funken auf.
    private static func deal(_ b: inout SceneBrush, _ c: Ring, _ angles: [Double], _ t: Double) {
        let n = angles.count
        guard n > 0 else { return }

        let letzte = RingMotion.dealDelay(at: n - 1, of: n)
        let stapel = 1 - SceneArt.smooth((t - letzte) / 0.2)
        if stapel > 0 {
            b.glow(c.cx, c.cy, 70 * c.k, RingTearArt.hot, (0.12 + 0.06 * sin(t * 6)) * stapel)
        }

        for (stelle, winkel) in angles.enumerated() {
            let seit = t - (RingMotion.dealDelay(at: stelle, of: n) + RingMotion.dealDuration)
            guard seit >= 0, seit < landing else { continue }
            let s = seit / landing
            let platz = RingTearArt.point(c.cx, c.cy, c.radius, winkel)
            let welle = SceneArt.arc(platz.x, platz.y, (18 + 26 * SceneArt.easeOut(s)) * c.k, 0, 2 * .pi, 24)
            b.stroke(welle, RingTearArt.hot, 0.35 * (1 - s), 2 * c.k)
            let rand = RingTearArt.point(c.cx, c.cy, c.radius + c.cardHeight / 2, winkel)
            b.sparkle(rand.x, rand.y, 6 * c.k * (1 - s), s * 2, RingTearArt.core, 0.9 * (1 - s))
        }
    }

    /// Schweif und Funken des Lichts, die Welle beim Halt und die
    /// Lichtsaeule der gehobenen Karte.
    private static func spotlight(_ b: inout SceneBrush, _ c: Ring, _ plan: RingSpotlightPlan, _ winkel: [Double], _ t: Double) {
        guard winkel.count == plan.times.count, let ziel = winkel.last, t >= 0 else { return }
        let nachHalt = t - plan.halt

        var jetzt = 0
        while jetzt + 1 < plan.times.count, plan.times[jetzt + 1] <= t { jetzt += 1 }

        // Der Schweif: ein Bogen aussen am Ring, von dort, wo das Licht vor
        // einem Augenblick war, bis zu ihm
        if nachHalt < trailFade {
            var alt = jetzt
            while alt > 0, plan.times[alt - 1] > t - trailLength { alt -= 1 }
            let von = winkel[alt] - 10
            let bis = winkel[jetzt]
            let da = 1 - SceneArt.clamp(nachHalt / trailFade)
            if bis - von > 2 {
                let bogen = RingTearArt.ringArc(c.cx, c.cy, c.radius + c.cardHeight * 0.61, von, bis, max(4, Int((bis - von) / 6)))
                b.stroke(bogen, RingTearArt.hot, 0.18 * da, 16 * c.k)
                b.stroke(bogen, RingTearArt.core, 0.55 * da, 3 * c.k)
            }
        }

        // Funken, die das Licht hinter sich laesst – je Schritt drei, nach
        // aussen geworfen, und dann faellt die Schwerkraft
        for schritt in 0...jetzt {
            let alter = t - plan.times[schritt]
            guard alter >= 0, alter < sparkLife else { continue }
            let w = winkel[schritt]
            let basis = RingTearArt.point(c.cx, c.cy, c.radius + c.cardHeight / 2, w)
            let aus = (w - 90) * .pi / 180
            let rest = 1 - alter / sparkLife
            let farbe = rest > 0.66 ? sparkHot : (rest > 0.33 ? sparkWarm : sparkCool)
            let deckkraft = rest > 0.66 ? 1 : (rest > 0.33 ? 0.85 : 0.6)
            let strich = rest > 0.66 ? 2.2 : 1.6
            for j in 0..<3 {
                let i = schritt * 3 + j
                let richtung = aus + (SceneArt.unit(i, 400) - 0.5) * 1.4
                let tempo = (70 + 90 * SceneArt.unit(i, 401)) * c.k
                let x = basis.x + cos(richtung) * tempo * alter
                let y = basis.y + sin(richtung) * tempo * alter + 160 * c.k * alter * alter
                let kopf: SceneArt.Point = (x, y)
                let ende: SceneArt.Point = (x - cos(richtung) * tempo * 0.025, y - (sin(richtung) * tempo + 320 * c.k * alter) * 0.025)
                b.stroke([kopf, ende], farbe, deckkraft * 0.6, strich * c.k)
                b.circle(x, y, (1.1 + 1.2 * rest) * c.k, farbe, deckkraft)
            }
        }

        guard nachHalt >= 0 else { return }

        // Der Ruck beim Halt: eine Welle von der gezogenen Karte aus
        if nachHalt < ripple {
            let s = nachHalt / ripple
            let platz = RingTearArt.point(c.cx, c.cy, c.radius, ziel)
            let welle = SceneArt.arc(platz.x, platz.y, (12 + 80 * SceneArt.easeOut(s)) * c.k, 0, 2 * .pi, 36)
            b.stroke(welle, RingTearArt.hot, 0.5 * (1 - s), (3 * (1 - s) + 1) * c.k)
            b.glow(platz.x, platz.y, 70 * c.k, RingTearArt.hot, 0.5 * (1 - s))
        }

        // Die Lichtsaeule ueber der gehobenen Karte – fuer jede Karte gleich
        // warm, sie verraet nichts
        let kraft = SceneArt.easeOut(nachHalt / 0.15) * (1 - SceneArt.smooth((nachHalt - 0.55) / 0.4))
        guard kraft > 0.01 else { return }
        let lage = liftPose(nachHalt / RingMotion.lift, angle: ziel)
        let fuss = RingTearArt.point(c.cx, c.cy, c.radius * lage.reach, ziel)
        let px = fuss.x
        let py = fuss.y - c.cardHeight * hoverShare * lage.hover
        let unten = 22 * c.k
        let weit = 64 * c.k
        let saeule: [SceneArt.Point] = [(px - unten, py), (px + unten, py), (px + weit, 0), (px - weit, 0)]
        let schein: [(Double, Color, Double)] = [(0, SceneArt.light, 0.42 * kraft), (0.5, SceneArt.light, 0.14 * kraft), (1, SceneArt.light, 0)]
        b.fill(saeule, from: (0, py), to: (0, 0), schein)
        let kern: [SceneArt.Point] = [(px - 7 * c.k, py), (px + 7 * c.k, py), (px + 16 * c.k, 0), (px - 16 * c.k, 0)]
        let kernSchein: [(Double, Color, Double)] = [(0, Color.white, 0.6 * kraft), (1, SceneArt.light, 0)]
        b.fill(kern, from: (0, py), to: (0, 0), kernSchein)
        for i in 0..<14 {
            let z = SceneArt.fract(nachHalt * (0.5 + 0.4 * SceneArt.unit(i, 410)) + SceneArt.unit(i, 411))
            let breite = unten + (weit - unten) * z
            b.circle(px + (SceneArt.unit(i, 412) - 0.5) * breite * 1.4, py * (1 - z), (1 + SceneArt.unit(i, 413)) * c.k, SceneArt.light, 0.7 * kraft)
        }
    }
}

// MARK: - Die Effekte an den Karten

/// Eine Karte zwischen Stapel und Platz – siehe `RingTableArt.dealPose`.
/// Ersetzt Verschieben und Drehen um die Mitte: Der Bogen mit Drall liesse
/// sich daraus nicht bauen.
struct RingDealFlight: GeometryEffect {

    /// 0 im Stapel, 1 auf dem Platz.
    var progress: Double
    let angle: Double
    let radius: CGFloat
    /// Im Stapel liegen die Karten nicht deckungsgleich, sondern leicht
    /// versetzt – sonst saehe er aus wie eine einzige Karte.
    let pileShift: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let lage = RingTableArt.dealPose(progress, angle: angle, radius: Double(radius))
        let cx = size.width / 2
        let cy = size.height / 2
        let stapel = pileShift * CGFloat(1 - SceneArt.clamp(progress))
        let groesse = CGFloat(lage.scale)
        let t = CGAffineTransform(translationX: cx + CGFloat(lage.x) + stapel * 0.5, y: cy + CGFloat(lage.y) - stapel)
            .rotated(by: CGFloat(lage.turn * .pi / 180))
            .scaledBy(x: groesse, y: groesse)
            .translatedBy(x: -cx, y: -cy)
        return ProjectionTransform(t)
    }
}

/// Die gezogene Karte auf dem Weg aus dem Ring – siehe
/// `RingTableArt.liftPose`. Ein eigener Modifier statt eines
/// `GeometryEffect`, weil sie auch verblasst.
struct RingLiftFlight: ViewModifier, Animatable {

    var progress: Double
    /// Wo sie lag, in Grad.
    let angle: Double
    let radius: CGFloat
    let cardHeight: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let lage = RingTableArt.liftPose(progress, angle: angle)
        // Erst um sich selbst drehen, dann nach aussen schieben und um die
        // Mitte drehen – wie die Karten im Ring. Das Schweben ist
        // bildschirm-oben, deshalb zuletzt.
        return content
            .scaleEffect(CGFloat(lage.scale))
            .rotationEffect(.degrees(lage.turn))
            .offset(y: -radius * CGFloat(lage.reach))
            .rotationEffect(.degrees(angle))
            .offset(y: -cardHeight * CGFloat(RingTableArt.hoverShare * lage.hover))
            .opacity(lage.opacity)
    }
}

/// Der Ruck, der beim Halt des Lichts durch den Ring geht.
struct RingHaltNod: GeometryEffect {

    /// Sekunden seit dem Halt.
    var time: Double

    var animatableData: Double {
        get { time }
        set { time = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let ruck = RingTableArt.nod(time)
        guard ruck > 0 else { return ProjectionTransform() }
        let k = CGFloat(1 + RingTableArt.nodDepth * ruck)
        let cx = size.width / 2
        let cy = size.height / 2
        let t = CGAffineTransform(translationX: cx, y: cy)
            .scaledBy(x: k, y: k)
            .translatedBy(x: -cx, y: -cy)
        return ProjectionTransform(t)
    }
}
