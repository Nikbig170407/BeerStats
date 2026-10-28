//
//  VisualEffects.swift
//  BeerStats
//
//  Was von den Bausteinen fuer Bewegung geblieben ist: gerechneter Zufall,
//  Konfetti, Blitz und Flammen. Die Szenen selbst stehen seit dem
//  27. Oktober in `DrawnScenes.swift`.
//
//  Hier lagen vorher sechs Bausteine – Teilchen, Druckwelle, Strahlen,
//  Einschlag, Konfetti, Blitz –, und eine Szene war eine Schichtung daraus.
//  Das war die Antwort auf die EINE Animation davor und hat ihr Problem nur
//  verschoben: Wird jede Szene aus denselben vier Bausteinen gestapelt,
//  bewegt sich jede gleich, und was sich unterscheidet, ist das Emoji. Der
//  Nutzer am Tisch: "Die sehen alle gleich aus, nur mit anderen Emojis."
//
//  Teilchen, Druckwelle, Strahlen und Einschlag sind deshalb ENTFERNT und
//  nicht bloss unbenutzt. Ein Baustein, der nur Gleichheit erzeugen kann,
//  wird beim naechsten Mal wieder genommen, weil er so bequem daliegt.
//  Geblieben ist, was eine eigene Bewegung hat: Konfetti faellt, der Blitz
//  haengt an einem Ereignis, die Flammen schlagen von den Raendern herein.
//
//  Vier Regeln gelten fuer diese Bausteine und fuer die Szenen in
//  `DrawnScenes.swift`, und jede hat einen Grund:
//
//  1. **Zierde, kein Inhalt.** Alles liegt HINTER dem Text, nimmt keine
//     Tipps an (`allowsHitTesting(false)`) und ist fuer VoiceOver
//     unsichtbar. Was zu tun ist, steht geschrieben da. (Die Flammen sind
//     die eine begruendete Ausnahme, siehe dort.)
//  2. **Gerechneter Zufall, nicht gewuerfelter.** `EffectNoise` ist eine
//     Funktion des Index. Mit `Double.random` springt alles bei jedem
//     Neuzeichnen an eine andere Stelle – und SwiftUI zeichnet oefter neu,
//     als man denkt.
//  3. **Nichts laeuft weiter, wenn der Screen weg ist.** Konfetti und Blitz
//     tragen ihre Bewegung in den Modifiern, ausgeloest von einem Zustand,
//     der einmal umkippt. Flammen und Szenen zeichnen auf einer Zeitleiste,
//     die mit der Ansicht verschwindet. Kein Timer, keine Task-Schleife.
//  4. **Bewegung reduzieren wird beachtet.** Wer die Systemeinstellung an
//     hat, bekommt ein stilles Bild – nicht nichts, sonst fehlt die Farbe,
//     die zum Moment gehoert.
//
//  **Zur Lautstaerke** (26. Oktober, auf Wunsch des Nutzers): Am Tisch
//  liegt das Handy in der Mitte und wird aus anderthalb Metern angeschaut.
//  Was dort "nicht stoert", sieht niemand. Deshalb "faellt auf" – mit
//  derselben Grenze wie vorher, nur weiter hinten: **Der Text muss lesbar
//  bleiben.** Kraeftig darf sein, was am Rand oder unten liegt; was durch
//  die Mitte geht, bleibt blass.
//

import SwiftUI

// MARK: - Gerechneter Zufall

enum EffectNoise {

    /// Immer derselbe Wert zwischen -1 und 1 fuer denselben Index.
    ///
    /// Gerechnet statt gewuerfelt: sonst springen die Teilchen bei jedem
    /// Neuzeichnen woanders hin.
    static func scatter(_ index: Int, seed: Int = 0) -> CGFloat {
        let wert = sin(Double(index * 127 + seed) * 12.9898) * 43758.5453
        return CGFloat(wert - wert.rounded(.down)) * 2 - 1
    }

    /// Dasselbe, aber zwischen 0 und 1.
    static func unit(_ index: Int, seed: Int = 0) -> CGFloat {
        (scatter(index, seed: seed) + 1) / 2
    }
}

// MARK: - Konfetti

/// Fallende Streifen in mehreren Farben – fuer die Stellen, an denen jemand
/// gewonnen hat.
///
/// Bewusst Streifen und keine Emoji: Ein Emoji traegt Bedeutung, und ein
/// Sieg hat schon genug davon. Streifen sind reine Freude.
struct EffectConfetti: View {

    var count: Int = 32
    var duration: Double = 2.8
    var colors: [Color] = [
        BeerStatsColor.accent,
        BeerStatsColor.accentSecondary,
        BeerStatsColor.warning,
        BeerStatsColor.success,
        BeerStatsColor.error
    ]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var running = false

    private static let maximum = 52

    private var anzahl: Int { min(max(count, 1), Self.maximum) }

    var body: some View {
        GeometryReader { geometry in
            let breite = geometry.size.width
            let hoehe = geometry.size.height

            ZStack(alignment: .top) {
                ForEach(0..<anzahl, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(colors[index % max(colors.count, 1)])
                        .frame(width: 9, height: 20 + EffectNoise.unit(index, seed: 5) * 16)
                        .rotationEffect(.degrees(running ? 540 + Double(EffectNoise.scatter(index, seed: 9)) * 360 : 0))
                        .offset(
                            x: EffectNoise.scatter(index, seed: 2) * breite * 0.48,
                            y: running ? hoehe * 1.1 : -40
                        )
                        .opacity(reduceMotion ? 0.8 : (running ? 0.1 : 1))
                        .animation(
                            reduceMotion
                                ? nil
                                : .easeIn(duration: duration + Double(EffectNoise.unit(index, seed: 4)) * 1.4)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(index) * 0.06),
                            value: running
                        )
                }
            }
            .frame(width: breite, height: hoehe, alignment: .top)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onAppear { running = true }
    }
}

// MARK: - Blitz

/// Ein einzelner heller Schlag ueber den ganzen Screen.
///
/// Haengt an einem Wert von draussen und nicht an `onAppear`: Ein Blitz
/// gehoert zu einem Ereignis (ein Riss, ein Treffer), nicht zum Erscheinen
/// einer Ansicht. Nach Lessons Learned Nr. 11 merkt er sich DEN WERT und
/// nicht ein Ja/Nein – sonst blitzt er genau einmal pro Screen.
struct EffectFlash<Trigger: Equatable>: View {

    let trigger: Trigger
    var tint: Color = BeerStatsColor.warning
    /// Wie hell der Blitz aufleuchtet. Kraeftig, wenn er ein Ereignis
    /// meldet; blasser, wenn er nur einen Schnitt markiert.
    var peak: Double = 0.8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Trigger?
    @State private var bright = false

    var body: some View {
        Rectangle()
            .fill(tint)
            .opacity(bright ? peak : 0)
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .onChange(of: trigger) { neu in
                guard !reduceMotion, neu != shown else { return }
                shown = neu
                bright = true
                // Erst den hellen Zustand zeigen, dann ausblenden – im selben
                // Durchlauf gesetzt, saehe SwiftUI nur den Endwert, und der
                // Blitz kaeme nie an.
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.65)) { bright = false }
                }
            }
    }
}

// MARK: - Flammen

/// Eine Wand aus Feuer, die von beiden Bildschirmraendern hereinschlaegt,
/// kurz ueberschiesst, flackert und sich wieder zurueckzieht.
///
/// Gebaut fuer den Riss in Ring of Fire (27. Oktober, auf Wunsch des
/// Nutzers: "Flammen von der Seite, maechtig – und keine Stimme mehr").
/// Gezeichnet und nicht aus Zeichen: Ein Feuer aus 🔥 waere nur eine
/// weitere Szene, die aussieht wie alle anderen mit anderem Emoji.
///
/// Flammen flackern, und Flackern ist keine Bewegung von A nach B, die ein
/// Modifier tragen koennte – deshalb eine Zeitleiste. Sie steht nur in der
/// Ansicht, solange es brennt; das Ende setzt eine `.task`, die mit der
/// Ansicht abgebrochen wird (Regel 3).
///
/// Die Ausnahme von Regel 1: Die Flammen liegen UEBER allem, sonst
/// verdeckt der Inhalt das Feuer. Dafuer nur an den Raendern (`reach`) und
/// nur anderthalb Sekunden – die Mitte mit Text und Knopf bleibt frei.
///
/// Die Formen sind im Browser vorgezeichnet und abgestimmt worden; Zahlen
/// hier nur zusammen anfassen und dann wieder ansehen.
struct EffectFlames<Trigger: Equatable>: View {

    let trigger: Trigger
    /// Zuenden, sobald die Ansicht erscheint – fuer einen Screen, der selbst
    /// das Ereignis IST (der Aktionsscreen nach dem Riss).
    var startsOnAppear = false
    /// Wie weit die Wand je Seite hereinschlaegt, als Anteil der Breite.
    var reach: CGFloat = 0.36
    var duration: Double = 1.6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Trigger?
    @State private var start: Date?
    @State private var glowing = false

    var body: some View {
        ZStack {
            if reduceMotion {
                calmGlow
            } else if let start {
                // Voll ausgeschrieben: `TimelineView` allein ist im Projekt der
                // Screen des Zeitstrahl-Spiels und verdeckt den von SwiftUI.
                SwiftUI.TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        FlameArt.draw(in: &context, size: size, reach: reach, duration: duration,
                                      t: timeline.date.timeIntervalSince(start))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onAppear {
            guard startsOnAppear else { return }
            ignite()
        }
        .onChange(of: trigger) { neu in
            guard neu != shown else { return }
            shown = neu
            ignite()
        }
        // Nimmt die Zeitleiste wieder weg, wenn das Feuer aus ist. Bricht
        // mit der Ansicht ab – und startet neu, wenn es erneut brennt.
        .task(id: start) {
            guard start != nil else { return }
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            start = nil
        }
    }

    private func ignite() {
        if reduceMotion {
            glowing = true
            withAnimation(.easeOut(duration: 1.2)) { glowing = false }
        } else {
            start = Date()
        }
    }

    /// Bewegung reduziert: dieselbe Farbe an den Raendern, ruhig, und sie
    /// erlischt. Still, aber nicht leer.
    private var calmGlow: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [FlameArt.ember.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing)
            Color.clear
            LinearGradient(colors: [.clear, FlameArt.ember.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
        }
        .opacity(glowing ? 1 : 0)
    }
}

/// Das Zeichnen der Flammen. Ein eigener Typ, weil `EffectFlames` generisch
/// ist (der Ausloeser) – und generische Typen keine statischen
/// gespeicherten Werte haben duerfen.
private enum FlameArt {

    /// Glut an den Raendern und die Grundfarbe beim reduzierten Bild.
    static let ember = Color(red: 0.78, green: 0.2, blue: 0.08)
    static let sparkCount = 22

    /// Eine Lage Flammenzungen. Hinten lang, dunkel und langsam, vorn kurz,
    /// hell und schneller – erst die zwei Lagen machen aus Formen Feuer.
    private struct Layer {
        let count: Int
        let length: CGFloat
        let thickness: CGFloat
        /// Wie schnell die Zungen nach oben stroemen, in Punkten je Sekunde.
        let rise: CGFloat
        /// Basis, Mitte, Spitze – jeweils mit eigener Deckkraft.
        let colors: [(r: Double, g: Double, b: Double, a: Double)]
        let hasCore: Bool
        let seed: Int
    }

    private static let layers = [
        Layer(count: 9, length: 1.0, thickness: 1.5, rise: 120,
              colors: [(0.59, 0.1, 0.03, 0.6), (0.9, 0.27, 0.06, 0.55), (1, 0.59, 0.16, 0.35)], hasCore: false, seed: 0),
        Layer(count: 13, length: 0.72, thickness: 1.0, rise: 190,
              colors: [(0.75, 0.16, 0.04, 0.7), (1, 0.43, 0.1, 0.7), (1, 0.8, 0.27, 0.5)], hasCore: true, seed: 50)
    ]

    private static func color(_ c: (r: Double, g: Double, b: Double, a: Double), alpha: Double) -> Color {
        Color(red: c.r, green: c.g, blue: c.b, opacity: alpha)
    }

    static func draw(in context: inout GraphicsContext, size: CGSize, reach: CGFloat, duration: Double, t: Double) {
        // Hereinschlagen mit kurzem Ueberschiessen, ab 0,75 s zurueckziehen
        let surge = min(1.12, backOut(t / 0.28))
        let retreat = t < 0.75 ? 0 : easeIn((t - 0.75) / (duration - 0.75))
        let strength = CGFloat(surge * (1 - retreat))
        guard strength > 0.001 else { return }

        let w = size.width, h = size.height
        let whole = Path(CGRect(origin: .zero, size: size))

        // 1. Abdunkeln zu den Raendern: Feuer leuchtet nur vor Dunklem
        context.fill(whole, with: .radialGradient(
            Gradient(colors: [.clear, .black.opacity(0.55 * strength)]),
            center: CGPoint(x: w / 2, y: h / 2), startRadius: w * 0.25, endRadius: h * 0.7))

        // 2. Glut an beiden Raendern
        for right in [false, true] {
            let edge: CGFloat = right ? w : 0
            let inner = right ? w - w * reach * 1.1 : w * reach * 1.1
            context.fill(whole, with: .linearGradient(
                Gradient(colors: [ember.opacity(0.55 * strength), ember.opacity(0)]),
                startPoint: CGPoint(x: edge, y: 0), endPoint: CGPoint(x: inner, y: 0)))
        }

        // 3. Flammenzungen, additiv. Jede stroemt nach oben (Feuer steigt)
        //    und kommt unten wieder herein.
        context.blendMode = .plusLighter
        for layer in layers {
            for right in [false, true] {
                for i in 0..<layer.count {
                    drawTongue(in: &context, layer: layer, index: i, right: right,
                               width: w, height: h, reach: reach, strength: strength, t: t)
                }
            }
        }

        // 4. Funken steigen aus der Wand
        for k in 0..<sparkCount {
            let birth = 0.08 + Double(EffectNoise.unit(k, seed: 7)) * 0.7
            let age = (t - birth) / 0.7
            guard age >= 0, age <= 1 else { continue }
            let right = k % 2 == 1
            let start = w * reach * (0.4 + 0.6 * EffectNoise.unit(k, seed: 8))
            let x = start + EffectNoise.scatter(k, seed: 9) * 30 * CGFloat(age)
            let y = h * (0.15 + 0.75 * EffectNoise.unit(k, seed: 10)) - 260 * CGFloat(age)
            let r = 2 + 2.5 * EffectNoise.unit(k, seed: 11)
            let center = CGPoint(x: right ? w - x : x, y: y)
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)),
                with: .color(Color(red: 1, green: 0.7 + 0.24 * Double(EffectNoise.unit(k, seed: 12)), blue: 0.31,
                                   opacity: (1 - age) * 0.9)))
        }
    }

    private static func drawTongue(in context: inout GraphicsContext, layer: Layer, index i: Int, right: Bool,
                                   width w: CGFloat, height h: CGFloat, reach: CGFloat, strength: CGFloat, t: Double) {
        let k = i + (right ? 200 : 0) + layer.seed
        let spacing = h / CGFloat(layer.count)
        let span = h + spacing
        var y = (CGFloat(i) + 0.5 + EffectNoise.scatter(k, seed: 1) * 0.35) * spacing - layer.rise * CGFloat(t)
        y = (y.truncatingRemainder(dividingBy: span) + span).truncatingRemainder(dividingBy: span) - spacing / 2

        let thick = spacing * 0.5 * layer.thickness * (0.9 + 0.5 * EffectNoise.unit(k, seed: 2))
        let flicker = 0.72 + 0.28 * CGFloat(sin(t * (9 + 5 * Double(EffectNoise.unit(k, seed: 3)))
                                                 + Double(EffectNoise.unit(k, seed: 4)) * 2 * .pi))
        let length = w * reach * strength * layer.length * (0.55 + 0.45 * EffectNoise.unit(k, seed: 5)) * flicker
        let wobble = thick * 0.7 * CGFloat(sin(t * 13 + Double(EffectNoise.unit(k, seed: 6)) * 2 * .pi))
        let base = layer.colors[0], mid = layer.colors[1], tip = layer.colors[2]

        // Schein: dieselbe Zunge breiter und blass – ein weicher Rand ohne
        // Unschaerfe-Filter, der jedes Bild teuer machen wuerde
        let glow = tongue(baseX: -12, y: y, thickness: thick * 1.6, length: length * 1.15,
                          rise: length * 0.5, wobble: wobble, right: right, width: w)
        context.fill(glow.path, with: .linearGradient(
            Gradient(stops: [.init(color: color(base, alpha: base.a * 0.35), location: 0),
                             .init(color: color(mid, alpha: mid.a * 0.25), location: 0.6),
                             .init(color: color(mid, alpha: 0), location: 1)]),
            startPoint: glow.base, endPoint: glow.tip))

        let flame = tongue(baseX: -12, y: y, thickness: thick, length: length,
                           rise: length * 0.45, wobble: wobble, right: right, width: w)
        context.fill(flame.path, with: .linearGradient(
            Gradient(stops: [.init(color: color(base, alpha: base.a), location: 0),
                             .init(color: color(mid, alpha: mid.a), location: 0.38),
                             .init(color: color(tip, alpha: tip.a), location: 0.75),
                             .init(color: color(tip, alpha: 0), location: 1)]),
            startPoint: flame.base, endPoint: flame.tip))

        guard layer.hasCore else { return }
        let core = tongue(baseX: -12, y: y, thickness: thick * 0.42, length: length * 0.58,
                          rise: length * 0.58 * 0.45, wobble: wobble * 0.6, right: right, width: w)
        context.fill(core.path, with: .linearGradient(
            Gradient(stops: [.init(color: Color(red: 1, green: 0.96, blue: 0.78, opacity: 0.7), location: 0),
                             .init(color: Color(red: 1, green: 0.84, blue: 0.39, opacity: 0.35), location: 0.6),
                             .init(color: Color(red: 1, green: 0.84, blue: 0.39, opacity: 0), location: 1)]),
            startPoint: core.base, endPoint: core.tip))
    }

    /// Eine Flammenzunge vom Rand nach innen und oben; `right` spiegelt sie
    /// an die andere Seite.
    private static func tongue(baseX x0: CGFloat, y: CGFloat, thickness th: CGFloat, length l: CGFloat,
                               rise: CGFloat, wobble: CGFloat, right: Bool, width w: CGFloat)
        -> (path: Path, base: CGPoint, tip: CGPoint) {
        func p(_ x: CGFloat, _ yy: CGFloat) -> CGPoint { CGPoint(x: right ? w - x : x, y: yy) }
        let tipY = y - rise + wobble
        var path = Path()
        path.move(to: p(x0, y - th))
        path.addCurve(to: p(x0 + l, tipY), control1: p(x0 + l * 0.30, y - th * 1.15), control2: p(x0 + l * 0.72, tipY - th * 0.15))
        path.addCurve(to: p(x0, y + th), control1: p(x0 + l * 0.62, tipY + th * 0.55), control2: p(x0 + l * 0.28, y + th * 1.1))
        path.closeSubpath()
        return (path, p(x0, y), p(x0 + l, tipY))
    }

    private static func backOut(_ x: Double) -> Double {
        let x = min(1, max(0, x)), c1 = 1.4, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }

    private static func easeIn(_ x: Double) -> Double {
        let x = min(1, max(0, x))
        return x * x
    }
}
