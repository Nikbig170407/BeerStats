//
//  RecordShelf.swift
//  BeerStats
//
//  Die Welt des Zeitstrahls: ein Plattenregal. Lieder stecken in Huellen,
//  und die Farbe einer Huelle verraet ihr Jahrzehnt – ueberall im Spiel
//  gleich, auf dem Ruecken im Regal wie auf dem Etikett der Platte.
//
//  Eine Ausnahme ist Absicht: Solange geraten wird, ist die Huelle schwarz.
//  Die Farbe waere sonst die halbe Antwort, und der Nachbar, der das Lied
//  abspielt, haette sie die ganze Zeit vor Augen.
//

import SwiftUI

enum RecordShelf {

    static let vinyl = SceneArt.rgb(14, 14, 16)
    static let groove = SceneArt.rgb(60, 60, 66)
    static let blankSleeve = SceneArt.rgb(28, 26, 26)
    static let ink = SceneArt.rgb(28, 26, 26)

    /// Die Farbe eines Jahrzehnts. Benachbarte Jahrzehnte sind deutlich
    /// verschieden – sonst liesse sich die Reihe im Regal nicht lesen.
    static func color(forYear year: Int) -> Color {
        switch year / 10 * 10 {
        case ..<1960: return SceneArt.rgb(110, 200, 170)
        case 1960: return SceneArt.rgb(240, 130, 40)
        case 1970: return SceneArt.rgb(205, 160, 40)
        case 1980: return SceneArt.rgb(236, 72, 153)
        case 1990: return SceneArt.rgb(40, 170, 170)
        case 2000: return SceneArt.rgb(150, 170, 205)
        case 2010: return SceneArt.rgb(150, 100, 230)
        default: return SceneArt.rgb(170, 220, 60)
        }
    }

    /// Das Jahrzehnt als Wort – fuer VoiceOver, das keine Farbe sieht.
    static func decade(ofYear year: Int) -> String {
        let jahrzehnt = year / 10 * 10
        return jahrzehnt < 2000 ? "\(jahrzehnt % 100)er" : "\(jahrzehnt)er"
    }
}

// MARK: - Huelle und Platte

/// Eine Plattenhuelle mit Titel und Interpret. Ohne Jahr bleibt sie
/// schwarz – siehe oben.
struct RecordSleeve: View {

    let title: String
    let artist: String
    let year: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.scaled(22, weight: .heavy, design: .default, width: .expanded))
                .foregroundStyle(Color.white)
                .minimumScaleFactor(0.6)
                .lineLimit(3)
            Text(artist)
                .font(.scaled(15, weight: .medium, design: .default, width: .expanded))
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background { SleeveArt(color: year.map(RecordShelf.color(forYear:)) ?? RecordShelf.blankSleeve) }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Die Huelle selbst: Farbe des Jahrzehnts und ein paar Zacken darueber.
private struct SleeveArt: View {

    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = Double(size.width), h = Double(size.height)
            let rahmen = CGRect(origin: .zero, size: size)
            context.clip(to: Path(roundedRect: rahmen, cornerRadius: 4))
            context.fill(Path(rahmen), with: .color(color))
            for k in 0..<7 {
                let x = Double(k) * w / 6.5
                let links: SceneArt.Point = (x - w * 0.18, h)
                let spitze: SceneArt.Point = (x + w * 0.09, h * 0.35)
                let rechts: SceneArt.Point = (x + w * 0.36, h)
                SceneArt.fill(&context, [links, spitze, rechts], k % 2 == 0 ? .black : .white, 0.12)
            }
        }
        .shadow(color: .black.opacity(0.55), radius: 14, y: 8)
        .accessibilityHidden(true)
    }
}

/// Die Platte: Rillen, ein Lichtkeil, der sich dreht, und das Etikett in
/// der Farbe des Jahrzehnts. Das Jahr dreht nicht mit – es muss lesbar sein.
struct SpinningRecord: View {

    let year: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        ZStack {
            if reduceMotion {
                Canvas { context, size in Self.draw(&context, size, angle: 0, year: year) }
            } else {
                SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                    Canvas { context, size in
                        Self.draw(&context, size, angle: timeline.date.timeIntervalSince(start) * 3.4, year: year)
                    }
                }
            }

        }
        .aspectRatio(1, contentMode: .fit)
        .overlay {
            // Das Jahr bleibt auf dem Etikett, auch mit grosser Schrift –
            // daneben stuende dunkle Tinte auf schwarzem Vinyl
            GeometryReader { geometry in
                Text(String(year))
                    .font(.scaled(17, weight: .heavy, design: .default, width: .expanded))
                    .foregroundStyle(RecordShelf.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(width: min(geometry.size.width, geometry.size.height) * 0.3)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(year), \(RecordShelf.decade(ofYear: year))")
    }

    private static func draw(_ g: inout GraphicsContext, _ size: CGSize, angle: Double, year: Int) {
        let s = Double(min(size.width, size.height))
        let cx = Double(size.width) / 2, cy = Double(size.height) / 2
        SceneArt.circle(&g, cx, cy, s * 0.47, RecordShelf.vinyl, 1)
        var rillen = Path()
        for k in 0..<12 {
            let r = s * (0.2 + 0.022 * Double(k))
            rillen.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
        }
        g.stroke(rillen, with: .color(RecordShelf.groove.opacity(0.35)), lineWidth: 1)

        // Der Lichtkeil verraet die Drehung
        var c = g
        c.translateBy(x: cx, y: cy)
        c.rotate(by: .radians(angle))
        var keil: [SceneArt.Point] = [(0, 0)]
        keil += SceneArt.arc(0, 0, s * 0.45, -0.3, 0.3, 10)
        SceneArt.fill(&c, keil, .white, 0.07)

        SceneArt.circle(&g, cx, cy, s * 0.17, RecordShelf.color(forYear: year), 1)
        SceneArt.circle(&g, cx, cy, 3.5, RecordShelf.vinyl, 1)
    }
}

/// Huelle und Platte zusammen: Die Platte rutscht beim Erscheinen aus der
/// Huelle. Erst dann, beim Aufloesen, bekommt die Huelle ihre Farbe.
struct RecordReveal: View {

    let title: String
    let artist: String
    let year: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var out = false

    var body: some View {
        GeometryReader { geometry in
            let seite = min(geometry.size.height, geometry.size.width / 1.62)
            ZStack(alignment: .leading) {
                SpinningRecord(year: year)
                    .frame(width: seite * 0.96, height: seite * 0.96)
                    .offset(x: out ? seite * 0.62 : seite * 0.02)
                RecordSleeve(title: title, artist: artist, year: year)
                    .frame(width: seite, height: seite)
            }
            .frame(width: seite * 1.6, height: seite, alignment: .leading)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            guard !reduceMotion else {
                out = true
                return
            }
            withAnimation(.easeOut(duration: 0.45).delay(0.05)) { out = true }
        }
    }
}

/// Ein Liedruecken im Regal: Farbe des Jahrzehnts, Jahr in dunkler Tinte.
struct RecordSpine: View {

    let year: Int

    var body: some View {
        Text(String(year))
            .font(.scaled(15, weight: .heavy, design: .default, width: .expanded))
            .foregroundStyle(RecordShelf.ink)
            .monospacedDigit()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RecordShelf.color(forYear: year), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            .accessibilityLabel("\(year)")
    }
}
