//
//  RecordShelf.swift
//  BeerStats
//
//  Die Welt der Hitparade: ein Plattenregal. Lieder stecken in Huellen,
//  und die Farbe einer Huelle verraet ihr Jahrzehnt – ueberall im Spiel
//  gleich, auf dem Ruecken im Regal wie auf dem Etikett der Platte.
//
//  Eine Ausnahme ist Absicht: Solange geraten wird, sind Huelle und Etikett
//  schwarz. Die Farbe waere sonst die halbe Antwort. Deshalb dreht sich auf
//  dem Plattenspieler eine Platte ohne Farbe, und das Cover kommt erst beim
//  Aufdecken.
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
///
/// Mit Cover (`artwork`, erst nach dem Aufdecken) liegt das Bild auf der
/// Huelle, und Titel und Interpret stehen unten auf einem Streifen in der
/// Farbe des Jahrzehnts – die Farbe bleibt, auch wenn das Cover sie
/// verdeckt, denn an ihr liest man das Regal.
struct RecordSleeve: View {

    let title: String
    let artist: String
    let year: Int?
    var artwork: URL? = nil

    var body: some View {
        let farbe = year.map(RecordShelf.color(forYear:)) ?? RecordShelf.blankSleeve
        let mitCover = artwork != nil && year != nil

        ZStack(alignment: mitCover ? .bottomLeading : .topLeading) {
            if mitCover, let artwork {
                AsyncImage(url: artwork) { bild in
                    bild.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.scaled(mitCover ? 18 : 22, weight: .heavy, design: .default, width: .expanded))
                    .foregroundStyle(Color.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(mitCover ? 2 : 3)
                Text(artist)
                    .font(.scaled(mitCover ? 13 : 15, weight: .medium, design: .default, width: .expanded))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(2)
            }
            .padding(mitCover ? 12 : 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if mitCover {
                    UnevenRoundedBottom()
                        .fill(farbe)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background { SleeveArt(color: farbe) }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Der Streifen unter dem Cover: unten so rund wie die Huelle, oben gerade.
/// Eigene Form, weil `UnevenRoundedRectangle` erst ab iOS 17 da ist.
private struct UnevenRoundedBottom: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(4, rect.height / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
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
    var artwork: URL? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var out = false

    var body: some View {
        GeometryReader { geometry in
            let seite = min(geometry.size.height, geometry.size.width / 1.62)
            ZStack(alignment: .leading) {
                SpinningRecord(year: year)
                    .frame(width: seite * 0.96, height: seite * 0.96)
                    .offset(x: out ? seite * 0.62 : seite * 0.02)
                RecordSleeve(title: title, artist: artist, year: year, artwork: artwork)
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

// MARK: - Plattenspieler

/// Der Plattenspieler der Hitparade: Die Platte dreht sich, solange das Lied
/// laeuft, der Tonarm liegt auf und wandert langsam nach innen, und aussen
/// zeigt ein Ring, wie viel der 30-Sekunden-Hoerprobe vorbei ist.
///
/// Das Etikett bleibt schwarz – es ist die Platte, die geraten wird, und die
/// Farbe ihres Jahrzehnts waere die halbe Antwort.
struct Turntable: View {

    let isPlaying: Bool
    /// Wie viel der Hoerprobe gelaufen ist, 0 bis 1.
    let progress: Double
    var isLoading = false
    var tint: Color = BeerStatsColor.accent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Wie weit die Platte schon gedreht war, als sie zuletzt anhielt – so
    /// springt sie beim Weiterspielen nicht zurueck.
    @State private var spinBase = 0.0
    @State private var spinSince: Date?

    /// 33 Umdrehungen je Minute, im Bogenmass je Sekunde.
    private static let speed = 33.333 / 60 * 2 * Double.pi

    var body: some View {
        GeometryReader { geometry in
            let s = min(geometry.size.width, geometry.size.height)
            ZStack(alignment: .topLeading) {
                SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isPlaying || reduceMotion)) { timeline in
                    Canvas { context, size in
                        Self.draw(&context, size, angle: angle(at: timeline.date), progress: progress, tint: tint)
                    }
                }

                arm(s)

                if isLoading {
                    ProgressView()
                        .tint(Color.white)
                        .position(x: s * Self.center.x, y: s * Self.center.y)
                }
            }
            .frame(width: s, height: s)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
        .onChange(of: isPlaying) { spielt in
            let jetzt = Date()
            if spielt {
                spinSince = jetzt
            } else {
                spinBase = angle(at: jetzt)
                spinSince = nil
            }
        }
    }

    private func angle(at date: Date) -> Double {
        guard !reduceMotion, let seit = spinSince else { return spinBase }
        return spinBase + date.timeIntervalSince(seit) * Self.speed
    }

    // MARK: Zeichnen

    /// Lage des Tellers im Quadrat, als Anteil der Seite.
    private static let center = CGPoint(x: 0.45, y: 0.52)
    private static let platter = 0.40
    private static let walnut = SceneArt.rgb(60, 38, 24)
    private static let walnutDark = SceneArt.rgb(32, 20, 12)

    private static func draw(_ g: inout GraphicsContext, _ size: CGSize, angle: Double, progress: Double, tint: Color) {
        let s = Double(min(size.width, size.height))
        let cx = s * Double(center.x), cy = s * Double(center.y), r = s * platter

        // Die Zarge: dunkles Holz
        let zarge = Path(roundedRect: CGRect(x: 0, y: s * 0.04, width: s, height: s * 0.92), cornerRadius: s * 0.06)
        g.fill(zarge, with: .linearGradient(Gradient(colors: [walnut, walnutDark]),
                                            startPoint: .zero, endPoint: CGPoint(x: s, y: s)))
        g.stroke(zarge, with: .color(Color.white.opacity(0.08)), lineWidth: 1)

        // Fortschritt: ein Ring um den Teller, der sich schliesst
        SceneArt.stroke(&g, SceneArt.arc(cx, cy, r + s * 0.035, 0, 2 * .pi, 72), Color.white, 0.08, 3)
        if progress > 0 {
            let bis = -Double.pi / 2 + 2 * .pi * min(1, progress)
            SceneArt.stroke(&g, SceneArt.arc(cx, cy, r + s * 0.035, -Double.pi / 2, bis, 72), tint, 0.95, 3.5)
        }

        // Die Platte mit Rillen
        SceneArt.circle(&g, cx, cy, r, RecordShelf.vinyl, 1)
        var rillen = Path()
        for k in 0..<14 {
            let rr = r * (0.38 + 0.044 * Double(k))
            rillen.addEllipse(in: CGRect(x: cx - rr, y: cy - rr, width: 2 * rr, height: 2 * rr))
        }
        g.stroke(rillen, with: .color(RecordShelf.groove.opacity(0.35)), lineWidth: 1)

        // Zwei Lichtkeile drehen mit – daran sieht man, dass sie laeuft
        var c = g
        c.translateBy(x: cx, y: cy)
        c.rotate(by: .radians(angle))
        for versatz in [0, Double.pi] {
            var keil: [SceneArt.Point] = [(0, 0)]
            keil += SceneArt.arc(0, 0, r * 0.97, versatz - 0.28, versatz + 0.28, 12)
            SceneArt.fill(&c, keil, .white, 0.07)
        }
        // Ein Strich auf dem Etikett, damit auch die Mitte sichtbar dreht
        SceneArt.stroke(&c, [(r * 0.05, 0), (r * 0.26, 0)], .white, 0.18, 2)

        // Das Etikett: schwarz, bis aufgedeckt ist
        SceneArt.circle(&g, cx, cy, r * 0.3, RecordShelf.blankSleeve, 1)
        SceneArt.stroke(&g, SceneArt.arc(cx, cy, r * 0.3, 0, 2 * .pi, 48), .white, 0.12, 1)
        SceneArt.circle(&g, cx, cy, s * 0.012, SceneArt.rgb(200, 200, 205), 1)
    }

    /// Der Tonarm: liegt in Ruhe neben der Platte, beim Abspielen auf ihr und
    /// wandert mit dem Lied nach innen. Als eigene Ansicht und nicht im
    /// Canvas, damit SwiftUI das Aufsetzen animiert.
    private func arm(_ s: CGFloat) -> some View {
        let lager = CGPoint(x: s * 0.88, y: s * 0.17)
        let laenge = s * 0.55
        let winkel: Double = isPlaying || progress > 0 ? 101 + 8 * progress : 82

        return ZStack {
            HStack(spacing: 0) {
                Capsule()
                    .fill(LinearGradient(colors: [Color.white.opacity(0.85), Color.white.opacity(0.55)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: s * 0.022)
                RoundedRectangle(cornerRadius: s * 0.01, style: .continuous)
                    .fill(Color.white.opacity(0.9))
                    .frame(width: s * 0.07, height: s * 0.045)
            }
            .frame(width: laenge)
            .rotationEffect(.degrees(winkel), anchor: .leading)
            .offset(x: laenge / 2)
            .position(lager)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: isPlaying)
            .animation(.linear(duration: 0.1), value: progress)

            Circle()
                .fill(Color.white.opacity(0.75))
                .frame(width: s * 0.09, height: s * 0.09)
                .overlay(Circle().fill(RecordShelf.vinyl).frame(width: s * 0.035, height: s * 0.035))
                .position(lager)
        }
        .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
    }
}

// MARK: - Die Frage der Runde

/// Die Frage der Runde als Aufkleber, wie ein Preisschild im Plattenladen.
/// Papier mit fester Tinte – ein Gegenstand, der hell sein darf.
struct QuestionSticker: View {

    let question: HitQuestion

    private static let paper = SceneArt.rgb(244, 236, 214)

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: question.symbol)
                .font(.scaled(18, weight: .heavy, design: .default))
            Text("FRAGE")
                .font(.scaled(10, weight: .heavy, design: .default, width: .expanded))
                .kerning(1.6)
                .opacity(0.65)
            Text(question.title)
                .font(.scaled(19, weight: .heavy, design: .default, width: .expanded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(RecordShelf.ink)
        .padding(18)
        .frame(width: 150, height: 150)
        .background {
            Circle()
                .fill(Self.paper)
                .overlay(
                    Circle()
                        .strokeBorder(RecordShelf.ink.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .padding(7)
                )
                .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
        }
        .rotationEffect(.degrees(-6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Frage: \(question.title)")
    }
}

// MARK: - Zaehlwerk

/// Das Jahr einstellen wie an einem Zaehlwerk: vier Ziffernrollen, darunter
/// Knoepfe fuer ein Jahr und ein Jahrzehnt. Ziehen auf den Rollen geht auch –
/// nach oben mehr, nach unten weniger.
///
/// Kein Rad zum Drehen (`Picker`): Das spult mit einem Wisch zwanzig Jahre
/// weiter, und wer am Tisch "1994" ansagt, will genau dort landen.
struct YearCounter: View {

    @Binding var year: Int
    let range: ClosedRange<Int>
    var tint: Color = BeerStatsColor.accent

    @State private var dragStart: Int?
    /// So viele Punkte Ziehen sind ein Jahr.
    private static let pointsPerYear: CGFloat = 14

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(Array(String(year).enumerated()), id: \.offset) { _, ziffer in
                    Text(String(ziffer))
                        .font(.scaled(40, weight: .heavy, design: .monospaced))
                        .foregroundStyle(SceneArt.rgb(244, 236, 214))
                        .contentTransition(.numericText())
                        .frame(width: 52, height: 70)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(LinearGradient(colors: [SceneArt.rgb(46, 42, 40), SceneArt.rgb(14, 13, 12), SceneArt.rgb(46, 42, 40)],
                                                     startPoint: .top, endPoint: .bottom))
                                .overlay(Rectangle().fill(Color.black.opacity(0.55)).frame(height: 1))
                        }
                }
            }
            .animation(.easeOut(duration: 0.18), value: year)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { zug in
                        let anfang = dragStart ?? year
                        dragStart = anfang
                        setze(anfang - Int((zug.translation.height / Self.pointsPerYear).rounded()))
                    }
                    .onEnded { _ in dragStart = nil }
            )

            HStack(spacing: 8) {
                schritt(-10, "−10")
                schritt(-1, "−1")
                schritt(1, "+1")
                schritt(10, "+10")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Jahr")
        .accessibilityValue(String(year))
        .accessibilityAdjustableAction { richtung in
            switch richtung {
            case .increment: setze(year + 1)
            case .decrement: setze(year - 1)
            @unknown default: break
            }
        }
    }

    private func schritt(_ jahre: Int, _ titel: String) -> some View {
        Button {
            setze(year + jahre)
        } label: {
            Text(titel)
                .font(.scaled(15, weight: .heavy, design: .monospaced))
                .foregroundStyle(tint)
                .frame(minWidth: 58, minHeight: 44)
                .background(tint.opacity(0.14), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func setze(_ jahr: Int) {
        let neu = min(range.upperBound, max(range.lowerBound, jahr))
        guard neu != year else { return }
        year = neu
        HapticManager.lightImpact()
    }
}
