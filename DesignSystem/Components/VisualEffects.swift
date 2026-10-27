//
//  VisualEffects.swift
//  BeerStats
//
//  Die Bausteine fuer Bewegung: Teilchen, Druckwellen, Strahlen, Einschlag,
//  Konfetti, Blitz – und seit dem 27. Oktober Flammen, der erste
//  gezeichnete Baustein (`EffectFlames`, siehe dort).
//
//  Bis zum 25. Oktober gab es im Projekt genau EINE Animation
//  (`RingCardFlourish`) – eine Bewegung mit dreizehn Einstellungen. Das war
//  als Sparmassnahme richtig gedacht und als Ergebnis falsch: Dreizehn Mal
//  dieselbe Flugbahn mit anderem Emoji sieht dreizehn Mal gleich aus, egal
//  wie verschieden die Emoji sind. Praechtig wird es nicht durch mehr
//  Zeichen, sondern durch SCHICHTEN – ein Einschlag, der eine Druckwelle
//  wirft, waehrend dahinter Strahlen drehen und Funken steigen.
//
//  Deshalb hier nicht dreizehn Animationen, sondern sechs Bausteine, die
//  sich stapeln lassen. Eine neue Szene ist eine Kombination und kein neuer
//  Entwurf – das war der richtige Teil am alten Ansatz und bleibt.
//
//  Vier Regeln gelten fuer alle Bausteine, und jede hat einen Grund:
//
//  1. **Zierde, kein Inhalt.** Alles liegt HINTER dem Text, nimmt keine
//     Tipps an (`allowsHitTesting(false)`) und ist fuer VoiceOver
//     unsichtbar. Was zu tun ist, steht geschrieben da.
//  2. **Gerechneter Zufall, nicht gewuerfelter.** `scatter` ist eine
//     Funktion des Index. Mit `Double.random` springen die Teilchen bei
//     jedem Neuzeichnen an eine andere Stelle – und SwiftUI zeichnet
//     oefter neu, als man denkt.
//  3. **Ein Zustand, der in `onAppear` umkippt.** Die Bewegung steckt in
//     den Modifiern, nicht im `body`. Kein Timer, keine Task-Schleife:
//     Beides laeuft weiter, wenn der Screen schon weg ist.
//  4. **Bewegung reduzieren wird beachtet.** Wer die Systemeinstellung an
//     hat, bekommt das Bild ohne Flug – nicht nichts, sonst fehlt die
//     Farbe, die zur Szene gehoert.
//
//  **Zur Lautstaerke** (26. Oktober, auf Wunsch des Nutzers): Die
//  Vorgabewerte hier waren auf "stoert nicht" eingestellt – Strahlen um
//  0,2, Einschlaege um 0,3, acht Teilchen. Am Tisch, auf einem Handy in
//  der Mitte und aus anderthalb Metern, war davon fast nichts zu sehen.
//  Jetzt liegen sie auf "faellt auf": Strahlen um 0,34, Einschlaege um
//  0,42, zwoelf Teilchen, und die Druckwelle hat einen Schein.
//
//  Die Grenze bleibt dieselbe, nur weiter hinten: **Der Text muss lesbar
//  bleiben.** Deshalb liegt weiter alles HINTER dem Text, und die
//  Reihenfolge der Schichten ist nicht beliebig – Strahlen am tiefsten,
//  dann Einschlag, dann Teilchen, dann Konfetti. Wer eine Schicht
//  hochdreht, bis der Text leidet, hat eine zu viel: Praechtig wird es
//  durch VERSCHIEDENE Bewegungen, nicht durch mehr vom Gleichen.
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

// MARK: - Teilchen

/// Wie ein Teilchen fliegt.
enum EffectFlight {
    /// Steigt auf – was von dir ausgeht.
    case rise
    /// Faellt herab – was auf dich zukommt.
    case fall
    /// Platzt aus der Mitte – was alle gleichzeitig trifft.
    case burst
    /// Zieht quer – was auf jemanden zeigt.
    case sweep
    /// Kreist um die Mitte – was bleibt und wirkt.
    case orbit
}

/// Fliegende Zeichen. Der Grundbaustein jeder Szene.
struct EffectParticles: View {

    let symbol: String
    var count: Int = 12
    var flight: EffectFlight = .rise
    var tint: Color = BeerStatsColor.accent
    /// Wie lange ein Zeichen unterwegs ist.
    var duration: Double = 2.2
    /// Abstand zwischen zwei Zeichen.
    var stagger: Double = 0.14
    var sizeRange: ClosedRange<CGFloat> = 30...56
    var opacity: Double = 0.92
    /// Seed trennt zwei Teilchenfelder in derselben Szene. Ohne ihn liegen
    /// Funken und Rauch genau uebereinander.
    var seed: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var running = false

    /// Mehr als das bringt kein Bild, kostet aber Bilder pro Sekunde.
    private static let maximum = 28

    private var anzahl: Int { min(max(count, 1), Self.maximum) }

    var body: some View {
        GeometryReader { geometry in
            let breite = geometry.size.width
            let hoehe = geometry.size.height

            ZStack {
                ForEach(0..<anzahl, id: \.self) { index in
                    Text(symbol)
                        .font(.system(size: size(index)))
                        .foregroundStyle(tint)
                        .rotationEffect(.degrees(drehung(index)))
                        .opacity(reduceMotion ? opacity * 0.5 : (running ? 0 : opacity))
                        .offset(
                            x: offsetX(index, width: breite),
                            y: offsetY(index, height: hoehe)
                        )
                        .scaleEffect(skalierung(index))
                        .animation(
                            reduceMotion
                                ? nil
                                : .easeOut(duration: duration)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(index) * stagger),
                            value: running
                        )
                }
            }
            .frame(width: breite, height: hoehe)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onAppear { running = true }
    }

    // MARK: Flugbahn

    private func offsetX(_ index: Int, width: CGFloat) -> CGFloat {
        let start = EffectNoise.scatter(index, seed: seed) * width * 0.42

        switch flight {
        case .rise, .fall:
            // Leicht ausfaechern, damit nicht alles auf einer Linie liegt.
            return start + (running ? EffectNoise.scatter(index, seed: seed + 7) * width * 0.14 : 0)
        case .burst:
            return running ? richtung(index).dx * width * 0.56 : 0
        case .sweep:
            return running ? width * 0.5 : -width * 0.5
        case .orbit:
            // Der Kreis entsteht aus zwei Phasen: Start und Ziel liegen auf
            // demselben Ring, nur um ein Stueck versetzt.
            return running ? richtung(index + 2).dx * width * 0.34 : richtung(index).dx * width * 0.34
        }
    }

    private func offsetY(_ index: Int, height: CGFloat) -> CGFloat {
        switch flight {
        case .rise:
            return running ? -height * 0.62 : height * 0.62
        case .fall:
            return running ? height * 0.62 : -height * 0.62
        case .burst:
            return running ? richtung(index).dy * height * 0.56 : 0
        case .sweep:
            return EffectNoise.scatter(index, seed: seed + 3) * height * 0.34
        case .orbit:
            return running ? richtung(index + 2).dy * height * 0.34 : richtung(index).dy * height * 0.34
        }
    }

    /// Gleichmaessig im Kreis verteilt – nach allen Seiten statt nach
    /// Zufall.
    private func richtung(_ index: Int) -> (dx: CGFloat, dy: CGFloat) {
        let winkel = Double(index) / Double(anzahl) * 2 * .pi
        return (CGFloat(cos(winkel)), CGFloat(sin(winkel)))
    }

    private func size(_ index: Int) -> CGFloat {
        let spanne = sizeRange.upperBound - sizeRange.lowerBound
        return sizeRange.lowerBound + EffectNoise.unit(index, seed: seed + 11) * spanne
    }

    private func drehung(_ index: Int) -> Double {
        switch flight {
        case .sweep, .orbit: return 0
        default: return Double(EffectNoise.scatter(index, seed: seed + 23)) * 40
        }
    }

    private func skalierung(_ index: Int) -> CGFloat {
        guard !reduceMotion else { return 1 }
        switch flight {
        case .burst: return running ? 2.0 : 0.4
        case .orbit: return running ? 1.1 : 0.9
        default: return running ? 1.15 : 0.8
        }
    }
}

// MARK: - Druckwelle

/// Ringe, die aus der Mitte nach aussen laufen. Der Baustein, der einem
/// Einschlag Gewicht gibt.
struct EffectShockwave: View {

    var tint: Color = BeerStatsColor.warning
    var rings: Int = 3
    var duration: Double = 1.6
    var lineWidth: CGFloat = 5
    /// Wartet, bevor der erste Ring laeuft – fuer den Einschlag, der ihn
    /// ausloest.
    var delay: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var running = false

    var body: some View {
        GeometryReader { geometry in
            let seite = max(geometry.size.width, geometry.size.height)

            ZStack {
                ForEach(0..<max(rings, 1), id: \.self) { index in
                    Circle()
                        .strokeBorder(tint, lineWidth: lineWidth)
                        // Der Schein hinter dem Ring. Ein nackter Strich
                        // wird beim Groesserwerden optisch duenner; der
                        // weiche Rand haelt die Welle sichtbar, bis sie
                        // aus dem Bild laeuft.
                        .background(
                            Circle()
                                .strokeBorder(tint, lineWidth: lineWidth * 2.4)
                                .blur(radius: lineWidth * 2)
                                .opacity(0.8)
                        )
                        .frame(width: seite * 0.3, height: seite * 0.3)
                        .scaleEffect(running ? 3.2 : 0.18)
                        .opacity(running ? 0 : 1)
                        .animation(
                            reduceMotion
                                ? nil
                                : .easeOut(duration: duration)
                                    .repeatForever(autoreverses: false)
                                    .delay(delay + Double(index) * duration / Double(max(rings, 1))),
                            value: running
                        )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onAppear { running = true }
    }
}

// MARK: - Strahlen

/// Langsam drehende Lichtstrahlen. Liegt am tiefsten in der Szene und macht
/// den Hintergrund lebendig, ohne vom Text abzulenken.
struct EffectRays: View {

    var tint: Color = BeerStatsColor.warning
    var spokes: Int = 12
    var duration: Double = 10
    var opacity: Double = 0.34

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var running = false

    var body: some View {
        GeometryReader { geometry in
            let seite = max(geometry.size.width, geometry.size.height) * 1.6

            ZStack {
                ForEach(0..<max(spokes, 1), id: \.self) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.9), tint.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: seite * 0.062, height: seite / 2)
                        .offset(y: -seite / 4)
                        .rotationEffect(.degrees(Double(index) / Double(max(spokes, 1)) * 360))
                }
            }
            .frame(width: seite, height: seite)
            .rotationEffect(.degrees(running ? 360 : 0))
            .animation(
                reduceMotion ? nil : .linear(duration: duration).repeatForever(autoreverses: false),
                value: running
            )
            .opacity(opacity)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onAppear { running = true }
    }
}

// MARK: - Einschlag

/// Ein grosses Zeichen, das von einer Seite hereinschlaegt und nachfedert.
///
/// Schlaegt EINMAL ein und bleibt dann stehen – eine Dauerschleife waere
/// nach dem dritten Mal nur noch Zappeln. Was weiterlaufen soll, legt man
/// als Teilchenfeld dahinter.
struct EffectSlam: View {

    let symbol: String
    var from: Edge = .top
    var tint: Color = BeerStatsColor.warning
    var size: CGFloat = 190
    var opacity: Double = 0.42

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    var body: some View {
        Text(symbol)
            .font(.system(size: size))
            .foregroundStyle(tint)
            .opacity(landed || reduceMotion ? opacity : 0)
            .scaleEffect(landed || reduceMotion ? 1 : 2.6)
            .offset(
                x: landed || reduceMotion ? 0 : start.x,
                y: landed || reduceMotion ? 0 : start.y
            )
            .rotationEffect(.degrees(landed || reduceMotion ? 0 : -26))
            // Wenig Daempfung: Das Zeichen schiesst ueber und federt zurueck.
            // Genau das macht aus einem Einblenden einen Einschlag.
            .animation(reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.36), value: landed)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .onAppear { landed = true }
    }

    private var start: CGPoint {
        switch from {
        case .top: return CGPoint(x: 0, y: -420)
        case .bottom: return CGPoint(x: 0, y: 420)
        case .leading: return CGPoint(x: -420, y: 0)
        case .trailing: return CGPoint(x: 420, y: 0)
        }
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Trigger?
    @State private var bright = false

    var body: some View {
        Rectangle()
            .fill(tint)
            .opacity(bright ? 0.8 : 0)
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .onChange(of: trigger) { neu in
                guard !reduceMotion, neu != shown else { return }
                shown = neu
                bright = true
                withAnimation(.easeOut(duration: 0.65)) { bright = false }
            }
    }
}

// MARK: - Flammen

/// Eine Wand aus Feuer, die von beiden Bildschirmraendern hereinschlaegt,
/// kurz ueberschiesst, flackert und sich wieder zurueckzieht.
///
/// Gebaut fuer den Riss in Ring of Fire (27. Oktober, auf Wunsch des
/// Nutzers: "Flammen von der Seite, maechtig – und keine Stimme mehr").
/// Der erste Baustein, der nicht aus Zeichen besteht, sondern GEZEICHNET
/// wird: Ein Feuer aus 🔥 waere nur eine weitere Szene, die aussieht wie
/// alle anderen mit anderem Emoji.
///
/// Auch der einzige mit Zeitleiste – Flammen flackern, und Flackern ist
/// keine Bewegung von A nach B, die ein Modifier tragen koennte. Regel 3
/// gilt trotzdem im Sinn: Die `TimelineView` steht nur in der Ansicht,
/// solange es brennt; das Ende setzt eine `.task`, die mit der Ansicht
/// abgebrochen wird. Nichts laeuft weiter, wenn der Screen weg ist.
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
                TimelineView(.animation) { timeline in
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
