//
//  VisualEffects.swift
//  BeerStats
//
//  Die Bausteine fuer Bewegung: Teilchen, Druckwellen, Strahlen, Einschlag,
//  Konfetti, Blitz.
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
    var count: Int = 8
    var flight: EffectFlight = .rise
    var tint: Color = BeerStatsColor.accent
    /// Wie lange ein Zeichen unterwegs ist.
    var duration: Double = 2.2
    /// Abstand zwischen zwei Zeichen.
    var stagger: Double = 0.17
    var sizeRange: ClosedRange<CGFloat> = 24...44
    var opacity: Double = 0.75
    /// Seed trennt zwei Teilchenfelder in derselben Szene. Ohne ihn liegen
    /// Funken und Rauch genau uebereinander.
    var seed: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var running = false

    /// Mehr als das bringt kein Bild, kostet aber Bilder pro Sekunde.
    private static let maximum = 24

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
            return running ? richtung(index).dx * width * 0.48 : 0
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
            return running ? -height * 0.55 : height * 0.55
        case .fall:
            return running ? height * 0.55 : -height * 0.55
        case .burst:
            return running ? richtung(index).dy * height * 0.48 : 0
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
        default: return Double(EffectNoise.scatter(index, seed: seed + 23)) * 28
        }
    }

    private func skalierung(_ index: Int) -> CGFloat {
        guard !reduceMotion else { return 1 }
        switch flight {
        case .burst: return running ? 1.6 : 0.5
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
    var lineWidth: CGFloat = 3
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
                        .frame(width: seite * 0.3, height: seite * 0.3)
                        .scaleEffect(running ? 2.6 : 0.2)
                        .opacity(running ? 0 : 0.7)
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
    var duration: Double = 14
    var opacity: Double = 0.22

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
                        .frame(width: seite * 0.045, height: seite / 2)
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
    var size: CGFloat = 150
    var opacity: Double = 0.3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    var body: some View {
        Text(symbol)
            .font(.system(size: size))
            .foregroundStyle(tint)
            .opacity(landed || reduceMotion ? opacity : 0)
            .scaleEffect(landed || reduceMotion ? 1 : 2.2)
            .offset(
                x: landed || reduceMotion ? 0 : start.x,
                y: landed || reduceMotion ? 0 : start.y
            )
            .rotationEffect(.degrees(landed || reduceMotion ? 0 : -18))
            // Wenig Daempfung: Das Zeichen schiesst ueber und federt zurueck.
            // Genau das macht aus einem Einblenden einen Einschlag.
            .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.42), value: landed)
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

    var count: Int = 22
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

    private static let maximum = 40

    private var anzahl: Int { min(max(count, 1), Self.maximum) }

    var body: some View {
        GeometryReader { geometry in
            let breite = geometry.size.width
            let hoehe = geometry.size.height

            ZStack(alignment: .top) {
                ForEach(0..<anzahl, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(colors[index % max(colors.count, 1)])
                        .frame(width: 7, height: 16 + EffectNoise.unit(index, seed: 5) * 12)
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
                                    .delay(Double(index) * 0.09),
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
            .opacity(bright ? 0.5 : 0)
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .onChange(of: trigger) { neu in
                guard !reduceMotion, neu != shown else { return }
                shown = neu
                bright = true
                withAnimation(.easeOut(duration: 0.45)) { bright = false }
            }
    }
}
