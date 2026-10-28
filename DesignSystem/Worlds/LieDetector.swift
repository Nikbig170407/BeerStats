//
//  LieDetector.swift
//  BeerStats
//
//  Die Welt von "Zwei Wahrheiten": ein Luegendetektor. Millimeterpapier,
//  ein Schreiber, dessen Nadel ruhig zittert, solange erzaehlt wird – und
//  ausschlaegt, wenn aufgeloest ist, wie gut gelogen wurde.
//
//  Das Thema haengt als Beweisstueck da, mit Nummer und Schnur. Die drei
//  Saetze kennt die App nicht – die werden gesprochen, nicht getippt.
//

import SwiftUI

enum LieDetector {
    static let paper = SceneArt.rgb(241, 233, 214)
    static let ink = SceneArt.rgb(28, 26, 26)
    static let seal = SceneArt.rgb(150, 40, 30)
    static let string = SceneArt.rgb(200, 190, 160)
    static let chart = SceneArt.rgb(230, 234, 226)
    static let chartGrid = SceneArt.rgb(120, 160, 200)
    static let trace = SceneArt.rgb(30, 40, 130)
    static let arm = SceneArt.rgb(60, 60, 66)
}

// MARK: - Beweisstueck

/// Ein Anhaenger aus Papier mit roter Nummer, Loch und Schnur.
struct EvidenceTag<Content: View>: View {

    let number: Int
    private let content: Content

    init(number: Int, @ViewBuilder content: () -> Content) {
        self.number = number
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("\(number)")
                .font(.scaled(18, weight: .heavy, design: .monospaced))
                .foregroundStyle(LieDetector.paper)
                .frame(width: 38, height: 38)
                .background(Circle().fill(LieDetector.seal.opacity(0.9)))

            VStack(alignment: .leading, spacing: 6) { content }
                .foregroundStyle(LieDetector.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 34)
        .padding(.trailing, 18)
        .padding(.vertical, 18)
        .background(LieDetector.paper, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(alignment: .leading) {
            // Loch und Schnur – das Stueck haengt irgendwo dran
            ZStack {
                Capsule()
                    .fill(LieDetector.string)
                    .frame(width: 44, height: 1.5)
                    .rotationEffect(.degrees(35))
                    .offset(x: -16, y: -12)
                Circle()
                    .fill(Color.black.opacity(0.75))
                    .frame(width: 11, height: 11)
            }
            .offset(x: 12)
            .accessibilityHidden(true)
        }
        .rotationEffect(.degrees(-1))
        .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
    }
}

// MARK: - Schreiber

/// Der Papierstreifen des Luegendetektors. Die Kurve laeuft nach links weg,
/// die Nadel steht rechts. `level` sagt, wie stark sie ausschlaegt: ruhig,
/// solange erzaehlt wird, heftig, wenn die Luege aufflog.
struct Polygraph: View {

    let level: Double

    /// So viele Punkte rueckt die Kurve je Sekunde nach links.
    private static let speed: Double = 90

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var origin = Date()
    @State private var previous: Double?
    @State private var changedAt = Date.distantPast

    var body: some View {
        Group {
            if reduceMotion {
                Canvas { context, size in draw(&context, size, now: 0) }
            } else {
                SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                    Canvas { context, size in
                        draw(&context, size, now: timeline.date.timeIntervalSince(origin))
                    }
                }
            }
        }
        .frame(height: 128)
        .onChange(of: level) { [level] _ in
            previous = level
            changedAt = Date()
        }
        .accessibilityHidden(true)
    }

    private func draw(_ g: inout GraphicsContext, _ size: CGSize, now: Double) {
        let w = Double(size.width), h = Double(size.height)
        g.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 6), with: .color(LieDetector.chart))

        var raster: [(SceneArt.Point, SceneArt.Point)] = []
        for x in stride(from: 6.0, to: w - 4, by: 12) {
            let oben: SceneArt.Point = (x, 4)
            let unten: SceneArt.Point = (x, h - 4)
            raster.append((oben, unten))
        }
        for y in stride(from: 15.0, to: h, by: 15) {
            let links: SceneArt.Point = (4, y)
            let rechts: SceneArt.Point = (w - 4, y)
            raster.append((links, rechts))
        }
        SceneArt.lines(&g, raster, LieDetector.chartGrid, 0.25, 1)

        let nadel = w - 40
        let wechsel = changedAt.timeIntervalSince(origin)
        let skala = h / 150
        var kurve: [SceneArt.Point] = []
        for x in stride(from: 6.0, through: nadel, by: 2) {
            let tau = now - (nadel - x) / Self.speed
            kurve.append((x, h / 2 + amplitude(tau, wechsel: wechsel) * skala))
        }
        SceneArt.stroke(&g, kurve, LieDetector.trace, 0.9, 2)

        let spitze = h / 2 + amplitude(now, wechsel: wechsel) * skala
        let lager: SceneArt.Point = (w - 6, -10)
        let ende: SceneArt.Point = (nadel, spitze)
        SceneArt.stroke(&g, [ende, lager], LieDetector.arm, 1, 3)
        SceneArt.circle(&g, nadel, spitze, 4, LieDetector.trace, 1)
    }

    /// Wie weit die Nadel zum Zeitpunkt `tau` ausschlaegt. Vor dem Wechsel
    /// gilt der alte Pegel – die Kurve auf dem Papier aendert sich nicht
    /// rueckwirkend.
    private func amplitude(_ tau: Double, wechsel: Double) -> Double {
        let pegel = tau < wechsel ? (previous ?? level) : level
        let welle = 7 * sin(tau * 7) + 4 * sin(tau * 13.7 + 1)
        let zittern = 3 * SceneArt.noise(Int((tau * 22).rounded(.down)), 5)
        var ausschlag = 0.0
        if tau >= wechsel, tau < wechsel + 0.9 {
            ausschlag = 46 * level * sin((tau - wechsel) / 0.9 * .pi) * sin(tau * 46)
        }
        return (welle + zittern) * (0.3 + pegel) + ausschlag
    }
}
