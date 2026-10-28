//
//  NeonSign.swift
//  BeerStats
//
//  Die Welt von "Ich hab noch nie": Leuchtreklame auf Backstein. Jeder Satz
//  zuendet wie eine Neonroehre – kurz flackernd, dann ruhig. Strafkarten
//  brummen rot und hoeren nicht ganz auf zu zucken.
//
//  Hier – und nur hier – ist Neon die Welt. Die App hatte Neonkanten
//  ueberall; in den anderen Spielen sind sie deshalb der Welt gewichen.
//
//  Das Flackern ist gerechnet, nicht gewuerfelt: Sonst zuendete derselbe
//  Satz bei jedem Neuzeichnen anders. Und es ist kurz – nach einer knappen
//  halben Sekunde steht der Satz ruhig da (Regel aus der Vorschau).
//
//  Seit dem 28. Oktober leuchtet jede Karte anders (`Look`). Vorher war
//  jedes Schild pink mit tuerkiser Zeile im selben Rahmen, und der Nutzer
//  wollte "mehr Abwechslung, ändere zum Beispiel die Farben der LEDs".
//  Jetzt wechseln Farbe, Rahmen und Schrift von Karte zu Karte – mit zwei
//  Grenzen: Rot gehoert den Strafen, und die bleiben, wie sie sind.
//

import SwiftUI

enum NeonSign {

    /// Die Farbe einer Roehre als Anteile, damit sich Kern und Schein
    /// mischen lassen.
    struct Tube: Equatable {
        let r: Double
        let g: Double
        let b: Double

        init(_ r: Double, _ g: Double, _ b: Double) {
            self.r = r
            self.g = g
            self.b = b
        }
    }

    static let pink = Tube(255, 72, 170)
    static let red = Tube(255, 64, 52)
    static let cyan = Tube(80, 226, 255)
    static let amber = Tube(255, 190, 60)
    static let violet = Tube(175, 110, 255)
    static let lime = Tube(150, 255, 90)
    static let blue = Tube(70, 140, 255)
    static let warmWhite = Tube(255, 240, 215)

    /// Die Farben der Aussagen. Rot fehlt mit Absicht: Ein rotes Schild ist
    /// eine Strafe, und das soll man sehen, bevor man liest.
    static let statementTubes: [Tube] = [pink, cyan, amber, violet, lime, blue, warmWhite]

    /// Wie oft die Gluehbirnen eines Rahmens weiterlaufen – leise Bewegung,
    /// weit unter den 30 Bildern, die eine Welt hoechstens zeichnet.
    static let chaseInterval = 0.16

    /// Der Schein einer Roehre.
    static func glow(_ tube: Tube) -> Color {
        SceneArt.rgb(tube.r, tube.g, tube.b)
    }

    /// Der helle Kern – Roehrenfarbe, Richtung Weiss gemischt.
    static func core(_ tube: Tube, _ white: Double) -> Color {
        SceneArt.rgb(tube.r + (255 - tube.r) * white, tube.g + (255 - tube.g) * white, tube.b + (255 - tube.b) * white)
    }

    /// So lange zuendet eine Roehre.
    static let ignition: Double = 0.45

    // MARK: - Das Aussehen einer Karte

    /// Die Bauart eines Rahmens.
    enum Frame: CaseIterable {
        /// Eine Roehre rundum – das Schild von frueher.
        case tube
        /// Zwei Roehren ineinander, die innere in der Farbe der Kopfzeile.
        case double
        /// Stark gerundet, fast eine Pille.
        case pill
        /// Gluehbirnen rundum, die im Kreis laufen.
        case bulbs
        /// Nur die vier Ecken leuchten.
        case corners
    }

    /// Die Schrift eines Satzes – alles Systemschriften.
    enum Lettering: CaseIterable {
        case rounded
        /// Kursiv mit Serifen – wie eine geschwungene Roehre.
        case script
        case condensed

        func font(_ size: CGFloat) -> Font {
            switch self {
            case .rounded: return .scaled(size, weight: .semibold)
            case .script: return .scaled(size, weight: .semibold, design: .serif).italic()
            case .condensed: return .scaled(size, weight: .bold, design: .default, width: .condensed)
            }
        }
    }

    /// Wie ein Schild aussieht: Farbe des Satzes, Farbe der Kopfzeile,
    /// Rahmen und Schrift.
    struct Look: Equatable {
        let tube: Tube
        let headerTube: Tube
        let frame: Frame
        let lettering: Lettering

        /// Die Strafe sieht immer gleich aus – rot, mit Warndreieck. Sie
        /// soll man erkennen, nicht bestaunen.
        static let penalty = Look(tube: NeonSign.red, headerTube: NeonSign.cyan, frame: .tube, lettering: .rounded)

        /// Das Schild fuer die Karte an dieser Stelle im Stapel.
        ///
        /// Gerechnet aus der Stelle und nicht gewuerfelt: Zwei Karten
        /// hintereinander haben so nie dieselbe Farbe, denselben Rahmen oder
        /// dieselbe Schrift – auch nicht, wenn eine Strafe dazwischenliegt –,
        /// und ein Neuzeichnen aendert nichts. Die drei Zyklen sind
        /// teilerfremd lang; eine ganze Kombination kehrt erst nach ihrem
        /// Produkt wieder.
        static func forCard(at position: Int) -> Look {
            let farben = NeonSign.statementTubes
            let rahmen = NeonSign.Frame.allCases
            let schriften = NeonSign.Lettering.allCases
            // Die Kopfzeile steht ein paar Farben weiter – nie dieselbe wie
            // der Satz, und auch sie wechselt von Karte zu Karte
            let kopfAbstand = farben.count / 2
            return Look(
                tube: farben[wrapped(position, farben.count)],
                headerTube: farben[wrapped(position + kopfAbstand, farben.count)],
                frame: rahmen[wrapped(position, rahmen.count)],
                lettering: schriften[wrapped(position, schriften.count)]
            )
        }

        private static func wrapped(_ i: Int, _ n: Int) -> Int {
            ((i % n) + n) % n
        }
    }

    /// Wo die Gluehbirnen auf einem gerundeten Rahmen sitzen – im
    /// Uhrzeigersinn, oben links beginnend, in gleichen Abstaenden.
    ///
    /// Gerechnet und nicht aus dem Pfad abgegriffen: So laesst sich pruefen,
    /// dass sie auf dem Rahmen liegen, und die Lauflichter wissen, welche
    /// Birne die naechste ist.
    static func bulbPositions(in size: CGSize, radius: Double, spacing: Double) -> [SceneArt.Point] {
        let w = Double(size.width), h = Double(size.height)
        let r = min(radius, w / 2, h / 2)
        guard w > 0, h > 0, spacing > 0 else { return [] }

        let oben = w - 2 * r, seite = h - 2 * r, bogen = Double.pi * r / 2
        let umfang = 2 * oben + 2 * seite + 4 * bogen
        let anzahl = max(4, Int(umfang / spacing))

        return (0..<anzahl).map { i in
            point(at: Double(i) * umfang / Double(anzahl), w: w, h: h, r: r)
        }
    }

    /// Der Punkt `strecke` Punkte weit auf dem Rahmen, ab der oberen Kante
    /// gleich nach der Ecke oben links. Der Rahmen besteht aus acht
    /// Stuecken: Kante, Ecke, Kante, Ecke und so weiter.
    private static func point(at strecke: Double, w: Double, h: Double, r: Double) -> SceneArt.Point {
        let oben = w - 2 * r, seite = h - 2 * r, bogen = Double.pi * r / 2
        var rest = strecke

        if rest <= oben { return (r + rest, 0) }
        rest -= oben
        if rest <= bogen { return corner(w - r, r, r, -Double.pi / 2 + rest / max(r, 1)) }
        rest -= bogen
        if rest <= seite { return (w, r + rest) }
        rest -= seite
        if rest <= bogen { return corner(w - r, h - r, r, rest / max(r, 1)) }
        rest -= bogen
        if rest <= oben { return (w - r - rest, h) }
        rest -= oben
        if rest <= bogen { return corner(r, h - r, r, Double.pi / 2 + rest / max(r, 1)) }
        rest -= bogen
        if rest <= seite { return (0, h - r - rest) }
        rest -= seite
        return corner(r, r, r, Double.pi + min(rest, bogen) / max(r, 1))
    }

    /// Ein Punkt auf dem Viertelkreis einer Ecke.
    private static func corner(_ cx: Double, _ cy: Double, _ r: Double, _ winkel: Double) -> SceneArt.Point {
        (cx + cos(winkel) * r, cy + sin(winkel) * r)
    }

    /// Helligkeit einer Roehre `elapsed` Sekunden nach dem Einschalten.
    ///
    /// Beim Zuenden springt sie zwischen fast aus und an, mit wachsender
    /// Chance auf an. Danach brennt sie ruhig – oder, wenn sie `restless`
    /// ist, zuckt sie ab und zu kurz ab, wie eine Roehre kurz vor dem Ende.
    static func brightness(_ elapsed: Double, restless: Bool) -> Double {
        guard elapsed >= 0 else { return 0.06 }
        if elapsed < ignition {
            let bild = Int(elapsed * 28)
            return SceneArt.unit(bild, restless ? 23 : 17) > 0.75 - elapsed * 1.5 ? 1 : 0.06
        }
        guard restless else { return 1 }
        // Das Zucken bleibt lesbar: nie dunkler als drei Viertel
        return SceneArt.unit(Int(elapsed * 11), 29) > 0.1 ? 1 : 0.75
    }
}

// MARK: - Roehrentext

/// Ein Text als Neonroehre: heller Kern, farbiger Schein.
struct NeonText: View {

    let text: String
    let tube: NeonSign.Tube
    let font: Font
    var brightness: Double = 1

    var body: some View {
        let an = brightness > 0.5

        Text(text)
            .font(font)
            .foregroundStyle(NeonSign.core(tube, 0.55).opacity(0.18 + 0.82 * brightness))
            .shadow(color: NeonSign.glow(tube).opacity(an ? 0.95 : 0), radius: 6)
            .shadow(color: NeonSign.glow(tube).opacity(an ? 0.6 : 0), radius: 16)
    }
}

// MARK: - Das Schild

/// Eine Karte als Leuchtschild: oben die Zeile, darunter der Satz in einem
/// Rahmen. Farbe, Rahmen und Schrift kommen aus `look`; eine Strafe sieht
/// immer gleich aus. Zuendet bei jedem neuen `id`.
struct NeonCard: View {

    let id: String
    let header: String
    let text: String
    let isPenalty: Bool
    var look: NeonSign.Look = NeonSign.Look.forCard(at: 0)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var litAt = Date()
    @State private var igniting = true

    /// Was gilt: bei einer Strafe immer ihr eigenes Aussehen.
    private var shown: NeonSign.Look { isPenalty ? .penalty : look }

    var body: some View {
        Group {
            if reduceMotion {
                sign(header: 1, body: 1)
            } else if igniting || isPenalty {
                // Strafkarten zucken weiter; sonst steht die Zeitleiste nach
                // dem Zuenden still
                SwiftUI.TimelineView(.animation(minimumInterval: isPenalty && !igniting ? 1.0 / 11 : nil)) { timeline in
                    let t = timeline.date.timeIntervalSince(litAt)
                    sign(header: NeonSign.brightness(t + 5, restless: false),
                         body: NeonSign.brightness(t - 0.15, restless: isPenalty))
                }
            } else {
                sign(header: 1, body: 1)
            }
        }
        .task(id: id) {
            litAt = Date()
            igniting = true
            try? await Task.sleep(nanoseconds: UInt64((NeonSign.ignition + 0.2) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            igniting = false
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(header): \(text)")
    }

    private func sign(header kopf: Double, body hell: Double) -> some View {
        let aussehen = shown

        return VStack(spacing: 18) {
            NeonText(text: header, tube: aussehen.headerTube, font: .scaled(19, weight: .semibold), brightness: kopf)
                .kerning(3)

            VStack(spacing: 16) {
                if isPenalty {
                    WarningTriangle(tube: aussehen.tube, brightness: hell)
                        .frame(width: 64, height: 56)
                }

                NeonText(text: text, tube: aussehen.tube, font: aussehen.lettering.font(isPenalty ? 27 : 30), brightness: hell)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Die Pille ist an den Enden stark gerundet – dort braucht der
            // Satz mehr Abstand zum Rahmen
            .padding(.horizontal, aussehen.frame == .pill ? 34 : 24)
            .padding(.vertical, aussehen.frame == .pill ? 44 : 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                NeonFrame(style: aussehen.frame, tube: aussehen.tube, accent: aussehen.headerTube, brightness: hell)
            }
            // Der Schein faellt auf die Wand – in der Farbe des Schilds
            .background {
                RadialGradient(colors: [NeonSign.glow(aussehen.tube).opacity(0.22 * hell), .clear],
                               center: .center, startRadius: 10, endRadius: 300)
                    .padding(-60)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Rahmen

/// Der Rahmen eines Schilds – fuenf Bauarten, alle aus Roehre oder
/// Gluehbirnen. Zierde: nimmt keine Tipps an und ist fuer VoiceOver
/// unsichtbar, der Satz steht als Text daneben.
struct NeonFrame: View {

    let style: NeonSign.Frame
    let tube: NeonSign.Tube
    /// Zweite Farbe, die nur der Doppelrahmen braucht.
    let accent: NeonSign.Tube
    var brightness: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let cornerRadius: CGFloat = 30
    static let pillRadius: CGFloat = 64

    var body: some View {
        content
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .tube:
            glowing(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous), tube, 5)
        case .pill:
            glowing(RoundedRectangle(cornerRadius: Self.pillRadius, style: .continuous), tube, 5)
        case .double:
            ZStack {
                glowing(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous), tube, 3.5)
                glowing(RoundedRectangle(cornerRadius: Self.cornerRadius - 9, style: .continuous), accent, 2)
                    .padding(9)
            }
        case .corners:
            glowing(NeonCorners(), tube, 5)
        case .bulbs:
            if reduceMotion {
                NeonBulbs(tube: tube, brightness: brightness, step: 0)
            } else {
                SwiftUI.TimelineView(.periodic(from: Date(), by: NeonSign.chaseInterval)) { zeit in
                    NeonBulbs(
                        tube: tube,
                        brightness: brightness,
                        step: Int(zeit.date.timeIntervalSinceReferenceDate / NeonSign.chaseInterval)
                    )
                }
            }
        }
    }

    private func glowing<S: Shape>(_ shape: S, _ farbe: NeonSign.Tube, _ breite: CGFloat) -> some View {
        shape
            .stroke(
                NeonSign.core(farbe, 0.3).opacity(0.15 + 0.85 * brightness),
                style: StrokeStyle(lineWidth: breite, lineCap: .round, lineJoin: .round)
            )
            .shadow(color: NeonSign.glow(farbe).opacity(brightness > 0.5 ? 0.95 : 0), radius: 11)
    }
}

/// Nur die vier Ecken eines Rahmens, jede ein Winkel aus Roehre.
private struct NeonCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let schenkel = min(rect.width, rect.height) * 0.22
        var p = Path()
        let ecken: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1),
            (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1),
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1)
        ]
        for (ecke, dx, dy) in ecken {
            p.move(to: CGPoint(x: ecke.x, y: ecke.y + dy * schenkel))
            p.addLine(to: ecke)
            p.addLine(to: CGPoint(x: ecke.x + dx * schenkel, y: ecke.y))
        }
        return p
    }
}

/// Gluehbirnen rundum, jede dritte an – und das Muster laeuft weiter.
private struct NeonBulbs: View {

    let tube: NeonSign.Tube
    let brightness: Double
    let step: Int

    static let spacing = 21.0

    var body: some View {
        Canvas { g, size in
            let birnen = NeonSign.bulbPositions(in: size, radius: Double(NeonFrame.cornerRadius), spacing: Self.spacing)
            let schein = NeonSign.glow(tube)
            let kern = NeonSign.core(tube, 0.75)
            for (i, birne) in birnen.enumerated() {
                let an = (i + step) % 3 == 0
                let hell = brightness * (an ? 1 : 0.38)
                if an { SceneArt.glow(&g, birne.x, birne.y, 11, schein, 0.75 * brightness) }
                SceneArt.circle(&g, birne.x, birne.y, an ? 3.4 : 2.8, an ? kern : schein, hell)
            }
        }
    }
}

/// Ein Warndreieck aus Roehre, mit Ausrufezeichen.
struct WarningTriangle: View {

    let tube: NeonSign.Tube
    var brightness: Double = 1

    var body: some View {
        ZStack {
            Triangle()
                .stroke(NeonSign.core(tube, 0.3).opacity(0.15 + 0.85 * brightness), style: StrokeStyle(lineWidth: 4, lineJoin: .round))
                .shadow(color: NeonSign.glow(tube).opacity(brightness > 0.5 ? 0.9 : 0), radius: 8)
            NeonText(text: "!", tube: tube, font: .scaled(30, weight: .heavy), brightness: brightness)
                .offset(y: 6)
        }
        .accessibilityHidden(true)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
