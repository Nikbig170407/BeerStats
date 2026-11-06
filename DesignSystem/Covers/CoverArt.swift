//
//  CoverArt.swift
//  BeerStats
//
//  Die gezeichneten Cover der Spielauswahl.
//
//  Entscheidung des Nutzers vom 4. November: Die Spielauswahl wird ein
//  Raster aus Covern wie in einem App-Store, und auf den Covern sollen
//  Bilder stehen statt eines Emoji auf einem Farbverlauf – gezeichnet, im
//  Stil eines Siebdruck-Plakats. Flache, kraeftige Formen in wenigen
//  Farben, eine dunkle Kontur, Rasterpunkte im Grund.
//
//  Gezeichnet und nicht als Bilddatei: Das Repository ist oeffentlich, eine
//  Zeichnung hat keine Lizenzfrage, bleibt auf jedem Geraet scharf und laesst
//  sich Strich fuer Strich nachbessern. Dieselbe Regel wie bei den Klaengen.
//
//  Jedes Cover ist ein Fall dieser Aufzaehlung, und welches Spiel welches
//  traegt, steht im Katalog (`PartyGame.coverArt`). Es gilt die Satz-Regel
//  der Szenen: Jedes Cover laesst sich in einem Satz sagen, ohne ein Emoji
//  zu nennen, und kein Satz kommt doppelt vor (`CoverArtTests`).
//

import SwiftUI

enum CoverArt: CaseIterable {

    /// Ring of Fire.
    case bottleCap
    /// Pferderennen.
    case raceAce
    /// Bussfahrer.
    case nightBus
    /// Wahrheit oder Pflicht.
    case splitBolt
    /// Ich hab noch nie.
    case neonHand
    /// Hitparade.
    case vinyl
    /// Schocken.
    case diceCup
    /// Maexchen.
    case liarsDice
    /// Zwei Wahrheiten.
    case clothesline
    /// Der Spion.
    case dossier
    /// 21.
    case twentyOne

    /// Gezeichnet wird in diesem Rahmen; die Ansicht zieht ihn auf das Cover
    /// auf. Die unteren 74 Einheiten liegen unter dem Titelbalken – dort
    /// steht nur Grund, nie Motiv.
    static let width: CGFloat = 300
    static let height: CGFloat = 370
    static var aspect: CGFloat { width / height }

    /// Was auf dem Cover zu sehen ist, in einem Satz.
    var sentence: String {
        switch self {
        case .bottleCap:
            return "Von oben gesehen liegt ein Kranz aus Kartenrücken um einen Kronkorken mit Flamme, oben klafft eine Lücke mit Glut."
        case .raceAce:
            return "Ein Pferdekopf springt aus einem Pik-Ass, rechts weht eine karierte Zielflagge über der Bahn."
        case .nightBus:
            return "Ein Nachtbus kommt frontal mit Lichtkegeln auf der Straße, auf der Zielanzeige leuchten die vier Kartenfarben."
        case .splitBolt:
            return "Diagonal geteilt: links eine Sprechblase mit Fragezeichen auf Blau, rechts ein Ausrufezeichen im Zackenstern auf Rot, dazwischen ein Blitz."
        case .neonHand:
            return "Eine pinke Neonhand zeigt drei Finger auf dunklem Backstein, der kleine ist eingeknickt, ein blauer Rahmen leuchtet in den Ecken."
        case .vinyl:
            return "Eine Schallplatte rutscht vor einem Strahlenkranz aus ihrer gestreiften Hülle, ein Tonarm liegt auf, Noten fliegen heraus."
        case .diceCup:
            return "Ein Lederbecher hebt sich von drei Einsen, daneben liegt ein Stapel Bierdeckel im Lampenlicht."
        case .liarsDice:
            return "Zwei Würfel zeigen Zwei und Eins, darüber schlägt die rote Nadel eines Lügendetektors auf Millimeterpapier aus."
        case .clothesline:
            return "An einer Leine hängen drei Zettel, zwei mit grünem Haken, der mittlere mit rotem Kreuz und Fingerabdruck."
        case .dossier:
            return "Über eine Akte mit rotem Stempel späht ein Hut mit zwei Augen, eine Lupe zeigt einen Fingerabdruck."
        case .twentyOne:
            return "Kärtchen mit achtzehn, neunzehn und zwanzig laufen im Bogen auf eine große rote Einundzwanzig zu, die in einem Stern explodiert."
        }
    }

    /// Die Farbe des Titelbalkens – das Dunkelste des Plakats, damit der
    /// Balken zum Bild gehoert und nicht daraufgeklebt aussieht.
    var band: Color {
        switch self {
        case .bottleCap: return PosterInk.night
        case .raceAce: return SceneArt.rgb(11, 42, 20)
        case .nightBus: return SceneArt.rgb(7, 11, 30)
        case .splitBolt: return SceneArt.rgb(42, 9, 7)
        case .neonHand: return SceneArt.rgb(13, 6, 12)
        case .vinyl: return SceneArt.rgb(6, 23, 30)
        case .diceCup: return SceneArt.rgb(23, 13, 6)
        case .liarsDice: return SceneArt.rgb(6, 23, 26)
        case .clothesline: return SceneArt.rgb(20, 8, 34)
        case .dossier: return SceneArt.rgb(23, 14, 7)
        case .twentyOne: return SceneArt.rgb(8, 31, 24)
        }
    }

    func draw(_ g: inout GraphicsContext, _ size: CGSize) {
        var bild = g
        bild.scaleBy(x: size.width / Self.width, y: size.height / Self.height)
        switch self {
        case .bottleCap: Self.drawBottleCap(&bild)
        case .raceAce: Self.drawRaceAce(&bild)
        case .nightBus: Self.drawNightBus(&bild)
        case .splitBolt: Self.drawSplitBolt(&bild)
        case .neonHand: Self.drawNeonHand(&bild)
        case .vinyl: Self.drawVinyl(&bild)
        case .diceCup: Self.drawDiceCup(&bild)
        case .liarsDice: Self.drawLiarsDice(&bild)
        case .clothesline: Self.drawClothesline(&bild)
        case .dossier: Self.drawDossier(&bild)
        case .twentyOne: Self.drawTwentyOne(&bild)
        }
    }

    // MARK: - Ring of Fire

    /// Der Kranz liegt geschuppt wie im Spiel, und oben fehlt ein Stueck: Dort
    /// glueht der Faden und schlaegt eine Flamme heraus – der Riss, der dem
    /// Spiel den Namen gibt. In der Mitte der Kronkorken, weil um ihn herum
    /// gespielt wird.
    private static func drawBottleCap(_ g: inout GraphicsContext) {
        let mitte = CGPoint(x: 150, y: 166)
        let radius: CGFloat = 100

        PosterInk.ground(&g, inner: SceneArt.rgb(143, 36, 20), outer: SceneArt.rgb(74, 15, 8), center: CGPoint(x: 150, y: 170))
        g.fill(PosterInk.circle(mitte, 130), with: .color(SceneArt.rgb(122, 29, 18)))

        // Der Glutfaden unter den Karten – sichtbar nur in der Luecke
        var faden = Path()
        for grad in stride(from: 14.0, through: 346.0, by: 2.0) {
            let punkt = PosterInk.point(mitte, radius, grad)
            if grad == 14 { faden.move(to: punkt) } else { faden.addLine(to: punkt) }
        }
        g.stroke(faden, with: .color(PosterInk.ember), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))

        // Die Flamme in der Luecke, hinter den Karten, damit ihr Fuss darunter liegt
        PosterInk.flame(&g, at: CGPoint(x: 150, y: 78), scale: 0.7, fill: PosterInk.orange, outlined: true)
        PosterInk.flame(&g, at: CGPoint(x: 150, y: 84), scale: 0.4, fill: PosterInk.yellow, outlined: false)

        // Der Kranz: zweiundzwanzig Plaetze, die oberen drei frei
        let plaetze = 22
        for stelle in 3...20 {
            var karte = g
            karte.translateBy(x: mitte.x, y: mitte.y)
            karte.rotate(by: .degrees(Double(stelle) * 360 / Double(plaetze)))
            karte.translateBy(x: -mitte.x, y: -mitte.y)
            cardBack(&karte, top: mitte.y - radius - 25, centerX: mitte.x)
        }

        // Der Kronkorken mit seinem Schatten
        let zacken = PosterInk.star(mitte, outer: 52, inner: 45, points: 21)
        g.fill(zacken.offsetBy(dx: 4, dy: 6), with: .color(Color.black.opacity(0.35)))
        g.fill(zacken, with: .color(PosterInk.orange))
        g.stroke(zacken, with: .color(PosterInk.ink), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        let deckel = PosterInk.circle(mitte, 38)
        g.fill(deckel, with: .color(PosterInk.glow))
        g.stroke(deckel, with: .color(PosterInk.ink), lineWidth: 2.6)
        PosterInk.flame(&g, at: CGPoint(x: mitte.x, y: mitte.y + 4), scale: 0.5, fill: PosterInk.yellow, outlined: true)
        PosterInk.flame(&g, at: CGPoint(x: mitte.x, y: mitte.y + 10), scale: 0.26, fill: PosterInk.cream, outlined: false)

        PosterInk.sparkle(&g, CGPoint(x: 64, y: 46), 8)
        PosterInk.sparkle(&g, CGPoint(x: 244, y: 40), 6)
        PosterInk.sparkle(&g, CGPoint(x: 262, y: 238), 6)
    }

    /// Eine Kartenrueckseite, aufrecht ueber der Mitte des Kranzes.
    private static func cardBack(_ g: inout GraphicsContext, top: CGFloat, centerX: CGFloat) {
        let rahmen = CGRect(x: centerX - 18, y: top, width: 36, height: 50)
        let karte = Path(roundedRect: rahmen, cornerRadius: 5, style: .continuous)
        g.fill(karte, with: .color(SceneArt.rgb(143, 36, 20)))
        g.stroke(karte, with: .color(PosterInk.cream), lineWidth: 2.6)
        let innen = Path(roundedRect: rahmen.insetBy(dx: 6, dy: 6), cornerRadius: 3, style: .continuous)
        g.stroke(innen, with: .color(PosterInk.cream.opacity(0.8)), lineWidth: 1.2)
        let y = rahmen.midY
        var raute = Path()
        raute.move(to: CGPoint(x: centerX, y: y - 7))
        raute.addLine(to: CGPoint(x: centerX + 5, y: y))
        raute.addLine(to: CGPoint(x: centerX, y: y + 7))
        raute.addLine(to: CGPoint(x: centerX - 5, y: y))
        raute.closeSubpath()
        g.fill(raute, with: .color(PosterInk.cream))
    }
}

// MARK: - Druckfarben und Werkzeug

/// Was alle Plakate teilen: Papier, Druckfarbe, das Feuer und die Handgriffe
/// des Siebdrucks. Die Farben eines einzelnen Motivs stehen bei ihm.
enum PosterInk {

    static let cream = SceneArt.rgb(246, 236, 217)
    static let ink = SceneArt.rgb(42, 12, 7)
    static let night = SceneArt.rgb(29, 8, 5)
    static let orange = SceneArt.rgb(242, 169, 59)
    static let yellow = SceneArt.rgb(255, 210, 122)
    static let ember = SceneArt.rgb(255, 154, 60)
    static let glow = SceneArt.rgb(217, 83, 31)

    /// Der Grund: ein Verlauf von innen nach aussen und darueber Rasterpunkte
    /// wie im Siebdruck – nur ueber dem Bild, nicht unter dem Titelbalken.
    static func ground(
        _ g: inout GraphicsContext,
        inner: Color,
        outer: Color,
        center: CGPoint,
        size: CGSize = CGSize(width: CoverArt.width, height: CoverArt.height),
        dotsUntil: CGFloat = CoverArt.height - 74
    ) {
        g.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [inner, outer]),
            center: center, startRadius: 0, endRadius: 260))
        dots(&g, width: size.width, until: dotsUntil)
    }

    /// Die Rasterpunkte allein – fuer einen Grund, der kein Kreisverlauf ist.
    static func dots(_ g: inout GraphicsContext, width: CGFloat, until bottom: CGFloat, opacity: Double = 0.09) {
        var punkte = Path()
        for x in stride(from: CGFloat(5), to: width, by: 10) {
            for y in stride(from: CGFloat(5), to: bottom, by: 10) {
                punkte.addEllipse(in: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3))
            }
        }
        g.fill(punkte, with: .color(Color.white.opacity(opacity)))
    }

    static func circle(_ center: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
    }

    /// Ein Punkt auf einem Kreis: 0 Grad oben, im Uhrzeigersinn – wie im Ring.
    static func point(_ center: CGPoint, _ r: CGFloat, _ grad: Double) -> CGPoint {
        let w = grad * .pi / 180
        return CGPoint(x: center.x + r * CGFloat(sin(w)), y: center.y - r * CGFloat(cos(w)))
    }

    /// Ein Stern mit Spitzen abwechselnd aussen und innen – Kronkorken,
    /// Funke, Abzeichen.
    static func star(_ center: CGPoint, outer: CGFloat, inner: CGFloat, points: Int) -> Path {
        var path = Path()
        for k in 0..<(points * 2) {
            let winkel = Double.pi * Double(k) / Double(points) - Double.pi / 2
            let r = k % 2 == 0 ? outer : inner
            let punkt = CGPoint(x: center.x + r * CGFloat(cos(winkel)), y: center.y + r * CGFloat(sin(winkel)))
            if k == 0 { path.move(to: punkt) } else { path.addLine(to: punkt) }
        }
        path.closeSubpath()
        return path
    }

    /// Ein kleiner Funke mit vier Spitzen.
    static func sparkle(_ g: inout GraphicsContext, _ center: CGPoint, _ r: CGFloat, color: Color = PosterInk.yellow) {
        g.fill(star(center, outer: r, inner: r * 0.3, points: 4), with: .color(color))
    }

    /// Eine Flamme, Spitze oben, Fuss unten – im Rahmen gut 100 Einheiten
    /// hoch, bevor sie skaliert wird. Mit Kontur, wo sie vor etwas steht;
    /// ohne, wo sie als Kern in einer anderen liegt.
    static func flame(_ g: inout GraphicsContext, at center: CGPoint, scale: CGFloat, fill: Color, outlined: Bool) {
        let lage = CGAffineTransform(translationX: center.x, y: center.y).scaledBy(x: scale, y: scale)
        let form = flameShape.applying(lage)
        g.fill(form, with: .color(fill))
        if outlined {
            g.stroke(form, with: .color(ink), style: StrokeStyle(lineWidth: 2.4 * scale, lineJoin: .round))
        }
    }

    private static let flameShape: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -55))
        p.addCurve(to: CGPoint(x: 34, y: 20), control1: CGPoint(x: 22, y: -28), control2: CGPoint(x: 40, y: -8))
        p.addCurve(to: CGPoint(x: 0, y: 52), control1: CGPoint(x: 30, y: 40), control2: CGPoint(x: 14, y: 52))
        p.addCurve(to: CGPoint(x: -34, y: 20), control1: CGPoint(x: -16, y: 52), control2: CGPoint(x: -32, y: 40))
        p.addCurve(to: CGPoint(x: -12, y: -32), control1: CGPoint(x: -37, y: -2), control2: CGPoint(x: -18, y: -10))
        p.addCurve(to: CGPoint(x: 0, y: -55), control1: CGPoint(x: -9, y: -42), control2: CGPoint(x: -4, y: -50))
        p.closeSubpath()
        return p
    }()
}
