//
//  Racetrack.swift
//  BeerStats
//
//  Die Welt des Pferderennens: Rasen, weisse Bahnlinien, ein Zielstrich im
//  Schachbrett – und die Pferde sind die vier Asse selbst.
//
//  Die Asse waren bisher ein 🐎 in einem grauen Kaestchen, viermal dasselbe
//  Zeichen. Am Tisch liegen aber Karten auf der Bahn, und genau das
//  unterscheidet die Pferde: die Farbe auf dem Ass. Vorwaerts huepft das
//  Ass mit einer Staubwolke, zurueckgeschickt rutscht es rueckwaerts – zwei
//  Bewegungen, die man aus dem Augenwinkel auseinanderhaelt.
//
//  Gewinnt eines, friert die Bahn ein und wird schwarzweiss: das Zielfoto.
//

import SwiftUI

enum Racetrack {
    static let turf = SceneArt.rgb(24, 66, 38)
    static let turfDark = SceneArt.rgb(18, 52, 30)
    static let chalk = Color(white: 0.96)
    static let dust = SceneArt.rgb(190, 160, 110)
}

// MARK: - Eine Bahn

/// Eine Bahn mit ihrem Ass. Die Bewegung zwischen zwei Feldern wird
/// gerechnet und nicht animiert, damit Sprung und Staub zum Weg passen.
struct RaceLane: View {

    let suit: PlayingCard.Suit
    let position: Int
    let finish: Int

    static let height: CGFloat = 46
    /// So lange dauert ein Zug – danach ist die Zeitleiste wieder weg.
    private static let moveDuration: Double = 0.55

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var move: (from: Int, at: Date)?

    var body: some View {
        Group {
            if let move, !reduceMotion {
                SwiftUI.TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let u = SceneArt.clamp(timeline.date.timeIntervalSince(move.at) / Self.moveDuration)
                        draw(&context, size, from: move.from, u: u)
                    }
                }
            } else {
                Canvas { context, size in draw(&context, size, from: position, u: 1) }
            }
        }
        .frame(height: Self.height)
        .onChange(of: position) { [position] neu in
            guard neu != position else { return }
            move = (position, Date())
            let zug = move?.at
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.moveDuration) {
                // Nur den eigenen Zug beenden – ein schneller zweiter hat
                // seine eigene Uhr.
                if move?.at == zug { move = nil }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(suit.name): Feld \(position) von \(finish)")
    }

    private func draw(_ g: inout GraphicsContext, _ size: CGSize, from: Int, u: Double) {
        let w = Double(size.width), h = Double(size.height)
        let felder = Double(finish + 1)
        let feld = w / felder

        // Rasen in Maehstreifen, Feld fuer Feld
        for k in 0...finish {
            SceneArt.box(&g, Double(k) * feld, 0, feld, h, k % 2 == 0 ? Racetrack.turf : Racetrack.turfDark, 1)
        }
        // Das Zielfeld im Schachbrett
        let kachel = h / 6
        let zielX = Double(finish) * feld
        var schwarz = Path()
        var weiss = Path()
        for zeile in 0..<6 {
            for spalte in 0..<Int(feld / kachel + 1) {
                let r = CGRect(x: zielX + Double(spalte) * kachel, y: Double(zeile) * kachel, width: kachel, height: kachel)
                if (zeile + spalte) % 2 == 0 { schwarz.addRect(r) } else { weiss.addRect(r) }
            }
        }
        var ziel = g
        ziel.clip(to: Path(CGRect(x: zielX, y: 0, width: feld, height: h)))
        ziel.fill(schwarz, with: .color(.black.opacity(0.75)))
        ziel.fill(weiss, with: .color(Racetrack.chalk.opacity(0.75)))

        // Kreide: Feldstriche fein, Bahnkanten kraeftig
        var striche: [(SceneArt.Point, SceneArt.Point)] = []
        for k in stride(from: 1, through: finish, by: 1) {
            let x = Double(k) * feld
            let oben: SceneArt.Point = (x, h * 0.2)
            let unten: SceneArt.Point = (x, h * 0.8)
            striche.append((oben, unten))
        }
        SceneArt.lines(&g, striche, Racetrack.chalk, 0.28, 1)
        let linksOben: SceneArt.Point = (0, 0.5)
        let rechtsOben: SceneArt.Point = (w, 0.5)
        let linksUnten: SceneArt.Point = (0, h - 0.5)
        let rechtsUnten: SceneArt.Point = (w, h - 0.5)
        SceneArt.lines(&g, [(linksOben, rechtsOben), (linksUnten, rechtsUnten)], Racetrack.chalk, 0.55, 1.5)

        // Das Ass: vorwaerts in Spruengen, zurueck als Rutschen
        let vor = position > from
        let weg = vor ? SceneArt.easeOut(u) : u * u * (3 - 2 * u)
        let stelle = Double(from) + (Double(position) - Double(from)) * weg
        let x = (stelle + 0.5) * feld
        let sprung = vor ? abs(sin(u * .pi * 2)) * h * 0.22 * (1 - u * 0.4) : 0

        if vor, u < 1 {
            // Staub bleibt hinter dem Ass liegen und verweht
            for d in 0..<3 {
                let dx = SceneArt.noise(d, 8) * 8 - feld * 0.3
                SceneArt.circle(&g, x + dx, h * 0.72 - Double(d) * 3, 5 + 9 * u, Racetrack.dust, 0.38 * (1 - u))
            }
        }

        let kw = min(feld * 0.72, h * 0.6), kh = kw * 1.4
        let mitte: SceneArt.Point = (x, h / 2 - sprung)
        SceneArt.glow(&g, x + 2, h / 2 + 4, kw * 0.9, .black, 0.4)
        let karte = CGRect(x: mitte.x - kw / 2, y: mitte.y - kh / 2, width: kw, height: kh)
        g.fill(Path(roundedRect: karte, cornerRadius: kw * 0.12), with: .color(Color(white: 0.97)))
        let tinte = suit.color
        g.draw(Text("A").font(.system(size: kw * 0.36, weight: .bold, design: .rounded)).foregroundColor(tinte),
               at: CGPoint(x: mitte.x - kw * 0.2, y: mitte.y - kh * 0.27), anchor: .center)
        g.draw(Text(suit.symbol).font(.system(size: kw * 0.62)).foregroundColor(tinte),
               at: CGPoint(x: mitte.x + kw * 0.04, y: mitte.y + kh * 0.1), anchor: .center)
    }
}

// MARK: - Zielfoto

/// Das Zielfoto: Im Moment des Sieges blitzt es, die Bahn wird
/// schwarzweiss und steht still.
struct PhotoFinish: ViewModifier {

    let isFinished: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flash: Double = 0

    func body(content: Content) -> some View {
        content
            .grayscale(isFinished ? 1 : 0)
            .overlay {
                Color.white
                    .opacity(flash)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .topTrailing) {
                if isFinished {
                    Text("ZIELFOTO")
                        .font(GameWorld.racetrack.font(12, weight: .heavy))
                        .kerning(2)
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Racetrack.chalk, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .rotationEffect(.degrees(-4))
                        .padding(8)
                        .transition(.scale(scale: 1.6).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.35), value: isFinished)
            .onChange(of: isFinished) { fertig in
                guard fertig, !reduceMotion else { return }
                flash = 0.8
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.5)) { flash = 0 }
                }
            }
    }
}
