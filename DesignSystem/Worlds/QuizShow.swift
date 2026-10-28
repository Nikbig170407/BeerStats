//
//  QuizShow.swift
//  BeerStats
//
//  Die Welt des Schaetzmeisters: eine Quizshow. Lauflichter umrahmen die
//  Frage, und die Loesung rollt auf Zahlenwalzen ein, Ziffer fuer Ziffer
//  von links.
//
//  Die Walzen sind schnell: Die letzte Ziffer liegt nach einer knappen
//  halben Sekunde. Spannung darf es geben, aber niemand wartet aufs Lesen
//  (Rueckmeldung zur Vorschau der Spielwelten).
//

import SwiftUI

enum QuizShow {
    static let bulb = SceneArt.rgb(255, 214, 120)
    static let bulbCore = SceneArt.rgb(255, 240, 200)
    static let bulbOff = SceneArt.rgb(120, 96, 60)
    static let reel = SceneArt.rgb(8, 6, 20)
}

// MARK: - Lauflichter

/// Gluehbirnen rund um eine Flaeche; jede dritte brennt, und das Muster
/// laeuft zehnmal je Sekunde weiter.
struct MarqueeLights: View {

    var cornerInset: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                Canvas { context, size in Self.draw(&context, size, step: 0) }
            } else {
                SwiftUI.TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
                    Canvas { context, size in
                        Self.draw(&context, size, step: Int(timeline.date.timeIntervalSinceReferenceDate * 10))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func draw(_ g: inout GraphicsContext, _ size: CGSize, step: Int) {
        let w = Double(size.width) - 12, h = Double(size.height) - 12
        let abstand = 22.0
        var punkte: [SceneArt.Point] = []
        for k in stride(from: 0.0, through: w, by: abstand) { punkte.append((6 + k, 6)) }
        for k in stride(from: abstand, through: h, by: abstand) { punkte.append((6 + w, 6 + k)) }
        for k in stride(from: abstand, through: w, by: abstand) { punkte.append((6 + w - k, 6 + h)) }
        for k in stride(from: abstand, to: h, by: abstand) { punkte.append((6, 6 + h - k)) }

        var an = Path()
        var aus = Path()
        for (i, p) in punkte.enumerated() {
            let kreis = CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)
            if (i + step) % 3 == 0 { an.addEllipse(in: kreis) } else { aus.addEllipse(in: kreis) }
        }
        g.drawLayer { schein in
            schein.addFilter(.blur(radius: 6))
            schein.fill(an, with: .color(QuizShow.bulb.opacity(0.9)))
        }
        g.fill(an, with: .color(QuizShow.bulbCore))
        g.fill(aus, with: .color(QuizShow.bulbOff))
    }
}

// MARK: - Zahlenwalzen

/// Eine Zahl auf Walzen. Ziffern rollen ein, alles andere (Komma) steht.
struct DigitReels: View {

    let text: String
    var size: CGFloat = 44

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(text.enumerated()), id: \.offset) { eintrag in
                if let ziffer = eintrag.element.wholeNumberValue {
                    DigitReel(digit: ziffer, order: eintrag.offset, size: size)
                } else {
                    Text(String(eintrag.element))
                        .font(.scaled(size, weight: .heavy, design: .default, width: .expanded))
                        .foregroundStyle(Color.white)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// Eine einzelne Walze. Sie dreht schnell, wird langsamer und rastet ein.
struct DigitReel: View {

    let digit: Int
    let order: Int
    let size: CGFloat

    /// Wann diese Walze liegt – von links nach rechts, alle vor einer
    /// halben Sekunde.
    static func landing(_ order: Int) -> Double { 0.24 + 0.05 * Double(min(order, 4)) }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var spinning = true

    private var font: Font { .scaled(size, weight: .heavy, design: .default, width: .expanded) }

    var body: some View {
        // Die Groesse gibt eine unsichtbare Ziffer vor – so passt die Walze
        // zur Schrift, auch wenn die Systemschrift groesser ist
        Text("0")
            .font(font)
            .hidden()
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .overlay {
                if spinning, !reduceMotion {
                    SwiftUI.TimelineView(.animation) { timeline in
                        Canvas { context, canvas in
                            strip(&context, canvas, position: position(at: timeline.date.timeIntervalSince(start)))
                        }
                    }
                } else {
                    Canvas { context, canvas in strip(&context, canvas, position: Double(digit)) }
                }
            }
            .background(QuizShow.reel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                // Oben und unten verschwindet die Walze im Dunkel
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.7), location: 0),
                    .init(color: .black.opacity(0), location: 0.3),
                    .init(color: .black.opacity(0), location: 0.7),
                    .init(color: .black.opacity(0.7), location: 1),
                ], startPoint: .top, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .allowsHitTesting(false)
            }
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(QuizShow.bulb.opacity(0.5), lineWidth: 2))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .task {
                start = Date()
                try? await Task.sleep(nanoseconds: UInt64((Self.landing(order) + 0.05) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                spinning = false
            }
    }

    /// Wo die Walze steht: von zwanzig Ziffern Vorlauf hinunter auf die
    /// richtige, zum Schluss langsamer.
    private func position(at t: Double) -> Double {
        let u = SceneArt.clamp(t / Self.landing(order))
        return Double(digit) + 20 * (1 - SceneArt.easeOut(u))
    }

    private func strip(_ g: inout GraphicsContext, _ canvas: CGSize, position p: Double) {
        let w = Double(canvas.width), h = Double(canvas.height)
        let basis = p.rounded(.down)
        let versatz = (p - basis) * h
        for d in -1...1 {
            let ziffer = ((Int(basis) + d) % 10 + 10) % 10
            g.draw(Text("\(ziffer)").font(font).foregroundColor(.white),
                   at: CGPoint(x: w / 2, y: h / 2 + versatz - Double(d) * h), anchor: .center)
        }
    }
}
