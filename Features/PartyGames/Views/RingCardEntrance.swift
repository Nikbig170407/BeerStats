//
//  RingCardEntrance.swift
//  BeerStats
//
//  Wie die gezogene Karte auf den Kartenscreen kommt – fuer jeden Rang anders.
//
//  Hinter der Karte lief schon je Rang eine eigene Szene
//  (`RingCardFlourish`). Die Karte selbst, das Groesste auf dem Screen, kam
//  aber jedes Mal gleich: aus 70 Prozent Groesse, federnd. Der Nutzer am
//  28. Oktober: "änder noch die animation der einzelnen karten … noch mehr
//  voneinander ab, sodass es abwechslungsreicher gestaltet ist."
//
//  Deshalb hat jetzt auch die Karte einen Auftritt je Rang, und es gilt
//  dieselbe Satz-Regel wie bei den Szenen: Jeder Auftritt laesst sich in
//  einem Satz sagen, ohne Emoji, und kein Satz kommt zweimal vor. Wo es
//  passt, erzaehlt der Auftritt die Karte mit – die Zwei steckt wie ein
//  Pfeil, die Zehn knallt auf wie ein Stempel, der Koenig wirbelt wie eine
//  Muenze. Abgestimmt wurde im Browser mit derselben Rechnung.
//
//  Rechnung und Ansicht sind getrennt: `pose(at:)` ist eine reine Funktion
//  des Fortschritts (0 bis 1) und deshalb ohne Geraet pruefbar
//  (`RingCardEntranceTests`) – dass jeder Auftritt auf dem Platz endet,
//  ohne zu springen, dass keiner sich bewegt wie ein anderer und dass die
//  Karte nach gut einer halben Sekunde lesbar steht. `RingCardEntering`
//  zeigt die Pose nur an.
//
//  Gerechnet wird in Punkten und Grad, nicht in Anteilen des Screens: Was
//  von aussen kommt, startet so weit draussen, dass es auf jedem iPhone
//  draussen liegt, und der Rest bewegt sich um die Karte herum.
//

import SwiftUI

/// Wo die Karte in einem Augenblick ihres Auftritts steht.
struct CardPose: Equatable {

    var x = 0.0
    var y = 0.0
    var scaleX = 1.0
    var scaleY = 1.0
    /// Drehung in der Ebene, in Grad.
    var rotation = 0.0
    /// Ueberschlag um die waagrechte Achse, in Grad.
    var flipX = 0.0
    /// Drehung um die senkrechte Achse wie bei einer Muenze, in Grad.
    var flipY = 0.0
    var opacity = 1.0
    /// Wie viel der Karte schon zu sehen ist, von oben gezaehlt – nur der
    /// Wasserfall laesst sie so ins Bild laufen.
    var reveal = 1.0

    /// Die Karte auf ihrem Platz.
    static let rest = CardPose()

    /// Zeigt die Karte gerade ihre Rueckseite?
    ///
    /// Ohne das stuende eine Karte, die sich ueberschlaegt, zur Haelfte
    /// spiegelverkehrt da – eine echte Karte zeigt in dem Moment ihren
    /// Ruecken.
    var showsBack: Bool {
        cos(flipX * .pi / 180) * cos(flipY * .pi / 180) < 0
    }
}

/// Die dreizehn Auftritte von Ring of Fire, je Rang einer.
///
/// Eine Aufzaehlung wie `RingScene`: Nur so laesst sich pruefen, dass zwei
/// Raenge nie denselben Auftritt bekommen.
enum RingCardEntrance: CaseIterable {

    case arrow, drop, pour, pump, twirl, rise, pair
    case hop, stamp, flick, standUp, coin, slam

    /// 2 bis 13 wie auf der Karte; alles andere ist das Ass (14).
    init(rank: Int) {
        switch rank {
        case 2: self = .arrow
        case 3: self = .drop
        case 4: self = .pour
        case 5: self = .pump
        case 6: self = .twirl
        case 7: self = .rise
        case 8: self = .pair
        case 9: self = .hop
        case 10: self = .stamp
        case 11: self = .flick
        case 12: self = .standUp
        case 13: self = .coin
        default: self = .slam
        }
    }

    /// Der Auftritt in einem Satz – ohne Emoji, und keiner kommt zweimal vor.
    var motion: String {
        switch self {
        case .arrow: return "Die Karte schießt von links herein und zittert nach wie ein Pfeil, der steckt."
        case .drop: return "Die Karte fällt von oben herab und springt zweimal auf."
        case .pour: return "Die Karte fließt von oben nach unten ins Bild, mit einer Welle als Kante, und schwappt nach."
        case .pump: return "Die Karte liegt flach und pumpt sich in zwei Stößen auf."
        case .twirl: return "Die Karte dreht eine Pirouette und wächst dabei aus der Mitte."
        case .rise: return "Die Karte schnellt von unten hoch, schießt über ihren Platz hinaus und sinkt zurück."
        case .pair: return "Zwei Karten gleiten von links und rechts heran und werden eine."
        case .hop: return "Die Karte hüpft im Takt von rechts herein, drei Sprünge bis zur Mitte."
        case .stamp: return "Die Karte saust aus der Nähe herab und knallt auf wie ein Stempel."
        case .flick: return "Die Karte wird von unten hochgeschnippt, überschlägt sich und landet."
        case .standUp: return "Die Karte richtet sich langsam aus dem Liegen auf, wie eine Figur auf der Bühne."
        case .coin: return "Die Karte wirbelt wie eine geworfene Münze um ihre Längsachse und kommt zum Stehen."
        case .slam: return "Die Karte rast aus der Tiefe heran, wird übergroß und bebt nach."
        }
    }

    /// Wie lange der Auftritt dauert, in Sekunden. Das Wesentliche ist nach
    /// gut einer halben Sekunde vorbei; was danach kommt, ist Nachschwingen.
    var duration: Double {
        switch self {
        case .arrow, .slam: return 0.7
        case .drop, .pump, .flick: return 0.85
        case .pour, .rise: return 0.75
        case .twirl, .pair, .standUp: return 0.8
        case .hop, .coin: return 0.9
        case .stamp: return 0.62
        }
    }

    /// Um welchen Punkt der Karte sich alles dreht und staucht: Was landet,
    /// staucht an der Unterkante; der Pfeil zittert um seine Spitze; das
    /// Wasser laeuft von der Oberkante.
    var pivot: UnitPoint {
        switch self {
        case .arrow: return .trailing
        case .drop, .pump, .hop, .standUp: return .bottom
        case .pour: return .top
        case .twirl, .rise, .pair, .stamp, .flick, .coin, .slam: return .center
        }
    }

    /// Wo die Karte bei diesem Fortschritt steht. Ab 1 steht sie auf ihrem
    /// Platz.
    func pose(at progress: Double) -> CardPose {
        guard progress < 1 else { return .rest }
        let p = max(0, progress)
        switch self {
        case .arrow: return arrow(p)
        case .drop: return drop(p)
        case .pour: return pour(p)
        case .pump: return pump(p)
        case .twirl: return twirl(p)
        case .rise: return rise(p)
        case .pair: return pair(p, side: -1)
        case .hop: return hop(p)
        case .stamp: return stamp(p)
        case .flick: return flick(p)
        case .standUp: return standUp(p)
        case .coin: return coin(p)
        case .slam: return slam(p)
        }
    }

    /// Die zweite Karte, die beim Trink-Duo mitkommt und in der ersten
    /// aufgeht. `nil` bei allen anderen.
    func ghostPose(at progress: Double) -> CardPose? {
        guard self == .pair else { return nil }
        guard progress < 1 else {
            var weg = CardPose.rest
            weg.opacity = 0
            return weg
        }
        return pair(max(0, progress), side: 1)
    }

    // MARK: - Die Auftritte

    /// 2: fliegt gerade herein, staucht beim Einschlag und zittert um die
    /// Spitze nach.
    private func arrow(_ p: Double) -> CardPose {
        var pose = CardPose()
        let hit = 0.38
        guard p >= hit else {
            pose.x = -420 * pow(1 - p / hit, 1.4)
            pose.scaleX = 1.07
            pose.scaleY = 0.96
            return pose
        }
        let s = (p - hit) * duration
        let squash = Self.bell(s, 0.05)
        pose.scaleX = 1 - 0.13 * squash
        pose.scaleY = 1 + 0.05 * squash
        pose.rotation = Self.ring(s, 10, 6, 8) * Self.fadeOut(p)
        return pose
    }

    /// 3: faellt mit der Schwerkraft, zwei Spruenge, jeder kleiner.
    private func drop(_ p: Double) -> CardPose {
        var pose = CardPose()
        if p < 0.42 {
            let u = p / 0.42
            pose.y = -400 * (1 - u * u)
            pose.rotation = -7 * (1 - u)
        } else if p < 0.66 {
            let u = Self.seg(p, 0.42, 0.66)
            pose.y = -64 * 4 * u * (1 - u)
            pose.rotation = 2.5 * sin(.pi * u)
        } else if p < 0.82 {
            let u = Self.seg(p, 0.66, 0.82)
            pose.y = -20 * 4 * u * (1 - u)
            pose.rotation = -1.2 * sin(.pi * u)
        }
        let erste: Double = 0.18 * Self.bell((p - 0.42) * duration, 0.04)
        let zweite: Double = 0.09 * Self.bell((p - 0.66) * duration, 0.035)
        let dritte: Double = 0.04 * Self.bell((p - 0.82) * duration, 0.03)
        let squash = erste + zweite + dritte
        pose.scaleY = 1 - squash
        pose.scaleX = 1 + 0.8 * squash
        // Bei einem Banner darueber steht die Karte tiefer – der Anfang
        // koennte sonst schon oben hereinragen
        pose.opacity = Self.seg(p, 0, 0.05)
        return pose
    }

    /// 4: laeuft von der Oberkante her ins Bild und schwappt dann.
    private func pour(_ p: Double) -> CardPose {
        var pose = CardPose()
        let flow = Self.seg(p, 0, 0.62)
        pose.reveal = Self.smooth(flow)
        pose.y = -14 * (1 - SceneArt.easeOut(flow))
        pose.scaleY = 1 + 0.05 * (1 - pose.reveal)
        pose.rotation = Self.ring((p - 0.5) * duration, 4, 5, 2.4) * Self.fadeOut(p)
        return pose
    }

    /// 5: flach, ein Stoss auf gut die halbe Hoehe, kurz nachgeben, der
    /// zweite Stoss ueber das Mass hinaus – und dann bebt sie vor Kraft.
    private func pump(_ p: Double) -> CardPose {
        var pose = CardPose()
        let height: Double
        if p < 0.22 {
            height = 0.06 + 0.54 * SceneArt.easeOut(p / 0.22)
        } else if p < 0.36 {
            height = 0.6 - 0.05 * sin(.pi / 2 * Self.seg(p, 0.22, 0.36))
        } else {
            height = 0.55 + 0.45 * Self.backOut(Self.seg(p, 0.36, 0.62), 3)
        }
        pose.scaleY = height
        // Flach heisst breit; aufgepumpt waechst sie in beide Richtungen
        pose.scaleX = height < 1 ? 1 + 0.5 * (1 - height) : height
        pose.rotation = Self.ring((p - 0.62) * duration, 2.2, 5, 11) * Self.fadeOut(p)
        pose.opacity = Self.seg(p, 0, 0.06)
        return pose
    }

    /// 6: anderthalb Drehungen, waehrend sie aus der Mitte waechst und
    /// sich dabei ein wenig hebt.
    private func twirl(_ p: Double) -> CardPose {
        var pose = CardPose()
        let spin = Self.seg(p, 0, 0.72)
        let grow = Self.seg(p, 0, 0.6)
        let size = 0.15 + 0.85 * Self.backOut(grow, 1.7)
        pose.rotation = -540 * pow(1 - spin, 3)
        pose.scaleX = size
        pose.scaleY = size
        pose.y = -34 * 4 * grow * (1 - grow)
        pose.opacity = Self.seg(p, 0, 0.12)
        return pose
    }

    /// 7: von unten nach oben, gestreckt vor Tempo, ueber den Platz hinaus.
    private func rise(_ p: Double) -> CardPose {
        var pose = CardPose()
        guard p >= 0.42 else {
            let u = p / 0.42
            pose.y = 760 - 806 * SceneArt.easeOut(u)
            pose.scaleY = 1 + 0.14 * (1 - u)
            pose.scaleX = 1 - 0.07 * (1 - u)
            return pose
        }
        let v = Self.seg(p, 0.42, 0.88)
        pose.y = -46 * (1 - Self.smooth(v))
        pose.rotation = 2.5 * sin(2 * .pi * v) * (1 - v)
        return pose
    }

    /// 8: die Karte von links (`side` -1) und eine zweite von rechts (+1).
    /// Wo sie sich treffen, pulsiert es einmal, und die zweite geht in der
    /// ersten auf.
    private func pair(_ p: Double, side: Double) -> CardPose {
        var pose = CardPose()
        let approach = SceneArt.easeOut(Self.seg(p, 0, 0.58))
        let pulse = 0.09 * Self.bell((p - 0.6) * duration, 0.05)
        pose.x = side * 230 * (1 - approach)
        pose.rotation = side * 16 * (1 - approach)
        pose.scaleX = 1 + pulse
        pose.scaleY = 1 + pulse
        let fadeIn = Self.seg(p, 0, 0.1)
        pose.opacity = side > 0 ? 0.8 * fadeIn * (1 - Self.seg(p, 0.5, 0.66)) : fadeIn
        return pose
    }

    /// 9: drei gleich lange Spruenge – der Takt ist der Reim. Jede Landung
    /// staucht, die letzte am meisten.
    private func hop(_ p: Double) -> CardPose {
        var pose = CardPose()
        var air = 0.0
        if p < 0.75 {
            let k = min(2, Int(p / 0.25))
            let u = (p - 0.25 * Double(k)) / 0.25
            let heights: [Double] = [74, 58, 42]
            pose.x = 300 * (1 - (Double(k) + u) / 3)
            pose.y = -heights[k] * 4 * u * (1 - u)
            pose.rotation = -9 * sin(.pi * u)
            air = 0.06 * sin(.pi * u)
        }
        let erste: Double = 0.11 * Self.bell((p - 0.25) * duration, 0.035)
        let zweite: Double = 0.1 * Self.bell((p - 0.5) * duration, 0.035)
        let dritte: Double = 0.14 * Self.bell((p - 0.75) * duration, 0.035)
        let squash = erste + zweite + dritte
        pose.scaleY = 1 + air - squash
        pose.scaleX = 1 - 0.5 * air + 0.8 * squash
        return pose
    }

    /// 10: aus der Naehe auf den Tisch, immer schneller, dann der Schlag.
    /// Er sitzt kurz nach dem Aufschlag des Stempels in der Szene.
    private func stamp(_ p: Double) -> CardPose {
        var pose = CardPose()
        let impact = 0.42
        guard p >= impact else {
            let u = p / impact
            let fall = u * u
            pose.scaleX = 2.7 - 1.7 * fall
            pose.scaleY = 2.7 - 1.7 * fall
            pose.rotation = -14 * (1 - fall)
            pose.opacity = Self.smooth(Self.seg(p, 0, 0.22))
            return pose
        }
        let s = (p - impact) * duration
        let squash = Self.bell(s, 0.045)
        pose.scaleX = 1 + 0.05 * squash
        pose.scaleY = 1 - 0.08 * squash
        pose.x = Self.ring(s, 5, 9, 14) * Self.fadeOut(p)
        return pose
    }

    /// Bube: mit dem Daumen hochgeschnippt – eine Wurfparabel mit einem
    /// Ueberschlag, unterwegs sieht man den Ruecken.
    private func flick(_ p: Double) -> CardPose {
        var pose = CardPose()
        let landing = 0.66
        guard p >= landing else {
            let u = p / landing
            pose.x = -70 * (1 - u)
            // Von unten hoch, ueber den Platz hinaus und zurueck auf ihn
            pose.y = 300 - 1500 * u + 1200 * u * u
            pose.flipX = -360 * (1 - u)
            pose.scaleX = 0.8 + 0.2 * u
            pose.scaleY = 0.8 + 0.2 * u
            pose.opacity = Self.seg(p, 0, 0.08)
            return pose
        }
        let s = (p - landing) * duration
        let squash = Self.bell(s, 0.04)
        pose.scaleY = 1 - 0.12 * squash
        pose.scaleX = 1 + 0.08 * squash
        pose.rotation = Self.ring(s, 3, 7, 4) * Self.fadeOut(p)
        return pose
    }

    /// Dame: liegt flach und richtet sich an der Unterkante auf, waehrend
    /// die Scheinwerfer der Szene hereinschwenken.
    private func standUp(_ p: Double) -> CardPose {
        var pose = CardPose()
        pose.flipX = 84 * (1 - Self.backOut(Self.seg(p, 0, 0.78), 1.4))
        pose.opacity = SceneArt.easeOut(Self.seg(p, 0, 0.3))
        return pose
    }

    /// Koenig: drei Umdrehungen, immer langsamer, und ein kurzes
    /// Ausschaukeln wie bei einer Muenze auf dem Tisch.
    private func coin(_ p: Double) -> CardPose {
        var pose = CardPose()
        let spin = Self.seg(p, 0, 0.8)
        let size = 0.55 + 0.45 * SceneArt.easeOut(Self.seg(p, 0, 0.5))
        pose.flipY = 1080 * pow(1 - spin, 4)
        pose.scaleX = size
        pose.scaleY = size
        pose.y = -50 * (1 - SceneArt.easeOut(Self.seg(p, 0, 0.6)))
        pose.flipX = Self.ring((p - 0.8) * duration, 8, 6, 3) * Self.fadeOut(p)
        pose.opacity = Self.seg(p, 0, 0.1)
        return pose
    }

    /// Ass: winzig aus der Tiefe, immer schneller, ueber das Mass hinaus –
    /// und dann bebt sie nach.
    private func slam(_ p: Double) -> CardPose {
        var pose = CardPose()
        let peak = 0.36
        guard p >= peak else {
            let u = p / peak
            let near = u * u * u
            pose.scaleX = 0.04 + 1.28 * near
            pose.scaleY = 0.04 + 1.28 * near
            pose.rotation = 28 * (1 - SceneArt.easeOut(u))
            pose.opacity = Self.seg(p, 0, 0.15)
            return pose
        }
        let s = (p - peak) * duration
        let size = 1.32 - 0.32 * Self.backOut(Self.seg(p, peak, 0.72), 2)
        pose.scaleX = size
        pose.scaleY = size
        pose.x = Self.ring(s, 7, 7, 17) * Self.fadeOut(p)
        pose.y = Self.ring(s, 4, 7, 13) * Self.fadeOut(p)
        return pose
    }

    // MARK: - Werkzeug

    /// Der Anteil von `p` zwischen `a` und `b`, begrenzt auf 0 bis 1.
    private static func seg(_ p: Double, _ a: Double, _ b: Double) -> Double {
        SceneArt.clamp((p - a) / (b - a))
    }

    private static func smooth(_ x: Double) -> Double {
        let c = SceneArt.clamp(x)
        return c * c * (3 - 2 * c)
    }

    /// Kommt an und schiesst dabei etwas ueber das Ziel hinaus; `s` sagt,
    /// wie weit.
    private static func backOut(_ x: Double, _ s: Double) -> Double {
        let u = SceneArt.clamp(x) - 1
        return 1 + (s + 1) * u * u * u + s * u * u
    }

    /// Eine Glocke um den Augenblick 0 – fuer das Stauchen beim Landen.
    private static func bell(_ s: Double, _ width: Double) -> Double {
        let q = s / width
        return exp(-q * q)
    }

    /// Nachschwingen ab `s` = 0 Sekunden: Ausschlag, Abklingen je Sekunde,
    /// Schwingungen je Sekunde.
    private static func ring(_ s: Double, _ amplitude: Double, _ decay: Double, _ hertz: Double) -> Double {
        guard s > 0 else { return 0 }
        return amplitude * exp(-decay * s) * sin(2 * .pi * hertz * s)
    }

    /// Im letzten Siebtel klingt jedes Nachschwingen ganz aus – sonst
    /// rueckte die Karte im letzten Bild sichtbar auf ihren Platz.
    private static func fadeOut(_ p: Double) -> Double {
        1 - smooth(seg(p, 0.85, 1))
    }
}

// MARK: - Die Karte im Auftritt

/// Die gezogene Karte im Auftritt. Sie rechnet nichts, sie zeigt die Pose,
/// die `RingCardEntrance` fuer den Fortschritt liefert – SwiftUI rechnet
/// die Zwischenwerte des Fortschritts.
struct RingCardEntering: View, Animatable {

    let card: PlayingCard
    let entrance: RingCardEntrance
    let width: CGFloat
    /// 0 bis 1.
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        ZStack {
            // Hinter der Karte: die zweite des Trink-Duos. Fuer jeden
            // anderen Rang gibt es sie nicht, und das aendert sich waehrend
            // des Auftritts nicht – der Aufbau bleibt derselbe.
            if let ghost = entrance.ghostPose(at: progress) {
                posed(ghost)
            }
            posed(entrance.pose(at: progress))
        }
    }

    private func posed(_ pose: CardPose) -> some View {
        sides(showingBack: pose.showsBack)
            .modifier(RingCardCurtainEffect(isOn: entrance == .pour, reveal: pose.reveal))
            .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: entrance.pivot)
            .rotation3DEffect(.degrees(pose.flipX), axis: (x: 1, y: 0, z: 0), anchor: entrance.pivot, perspective: 0.5)
            .rotation3DEffect(.degrees(pose.flipY), axis: (x: 0, y: 1, z: 0), anchor: entrance.pivot, perspective: 0.5)
            .rotationEffect(.degrees(pose.rotation), anchor: entrance.pivot)
            .offset(x: pose.x, y: pose.y)
            .opacity(pose.opacity)
    }

    /// Vorder- und Rueckseite liegen beide da, nur eine ist zu sehen.
    /// Ein Wechsel ueber `if` baute die Karte mitten in der Drehung neu.
    private func sides(showingBack: Bool) -> some View {
        ZStack {
            PlayingCardView(card: nil, width: width)
                .opacity(showingBack ? 1 : 0)
            PlayingCardView(card: card, width: width)
                .opacity(showingBack ? 0 : 1)
        }
    }
}

// MARK: - Wasserfall

/// Laesst die Karte beim Wasserfall von oben ins Bild laufen: eine Welle
/// als Kante, darauf ein Streifen Schaum.
///
/// Haengt an jedem Rang, ist aber nur beim Wasserfall an – der Aufbau der
/// Karte ist so fuer alle Raenge derselbe.
private struct RingCardCurtainEffect: ViewModifier {

    let isOn: Bool
    let reveal: Double

    @ViewBuilder
    func body(content: Content) -> some View {
        if isOn {
            content
                .mask { RingCardCurtain(reveal: reveal) }
                .overlay {
                    RingCardCurtain(reveal: reveal, edgeOnly: true)
                        .stroke(SceneArt.foam.opacity(RingCardCurtain.foamOpacity(reveal: reveal)), lineWidth: 3)
                }
        } else {
            content
        }
    }
}

/// Die Flaeche ueber der Welle – was dort liegt, ist schon zu sehen.
struct RingCardCurtain: Shape {

    var reveal: Double
    /// Nur die Kante, fuer den Schaum.
    var edgeOnly = false

    static let wave = 7.0
    static let wavelength = 60.0
    /// So weit reicht die Flaeche ueber die Karte hinaus. Am Ende muss sie
    /// auch den Schatten unter der Karte freigeben, sonst fehlte er nur
    /// beim Wasserfall.
    static let margin = 40.0

    /// Wo die Welle im Mittel steht: bei 0 knapp ueber der Karte, bei 1
    /// unter ihrem Schatten.
    static func level(reveal: Double, height: Double) -> Double {
        -(wave + 2) + reveal * (height + margin + wave + 2)
    }

    /// Der Schaum gehoert auf die Karte – ueber oder unter ihr waere er
    /// ein Strich im Nichts.
    static func foamOpacity(reveal: Double) -> Double {
        guard reveal > 0, reveal < 1 else { return 0 }
        return 0.85 * sin(.pi * reveal)
    }

    func path(in rect: CGRect) -> Path {
        let w = Double(rect.width), h = Double(rect.height)
        let mitte = Self.level(reveal: reveal, height: h)
        let phase = reveal * 12
        func kante(_ x: Double) -> Double {
            mitte + Self.wave * sin(x / Self.wavelength * 2 * .pi + phase)
        }

        var path = Path()
        if edgeOnly {
            // Nur solange die Kante ueber die Karte laeuft
            guard mitte > -Self.wave, mitte < h + Self.wave else { return path }
            for i in 0...24 {
                let x = w * Double(i) / 24
                let punkt = CGPoint(x: x, y: kante(x))
                if i == 0 { path.move(to: punkt) } else { path.addLine(to: punkt) }
            }
            return path
        }
        let m = Self.margin
        path.move(to: CGPoint(x: -m, y: -m))
        path.addLine(to: CGPoint(x: w + m, y: -m))
        for i in stride(from: 24, through: 0, by: -1) {
            let x = -m + (w + 2 * m) * Double(i) / 24
            path.addLine(to: CGPoint(x: x, y: kante(x)))
        }
        path.closeSubpath()
        return path
    }
}
