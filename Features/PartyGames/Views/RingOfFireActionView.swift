//
//  RingOfFireActionView.swift
//  BeerStats
//
//  Der zweite Screen von Ring of Fire: die gezogene Karte, gross.
//
//  Vorher stand die Karte als Panel unter dem Ring. Das hiess: kleine
//  Spielkarte, kleiner Text, und daneben lenkte der ganze Ring ab – obwohl
//  in diesem Moment nur eine Frage zaehlt, naemlich was jetzt zu tun ist.
//
//  Deshalb Vollbild und nur ein Knopf. Die Karte ist gross genug, dass man
//  sie quer ueber den Tisch erkennt, und unter dem Text stehen dieselben
//  zwei Zeilen wie auf den Extreme-Karten: wie lange es gilt und was es
//  kostet, wenn man verliert.
//
//  Hat der Zug den Ring gerissen, steht das GANZ OBEN und nicht unten bei
//  den Zeilen: Der Shot ist in dem Moment die Nachricht, die Karte nur noch
//  der Anlass.
//
//  Hinter der Karte laeuft seit dem 24. Oktober eine Bewegung, die zum Rang
//  gehoert (`RingCardFlourish`) – bei der Dame schwenken Scheinwerfer
//  herein, beim Buben leuchtet der Rand im Herzschlag. Sie liegt bewusst
//  HINTER dem Text: Wer quer ueber den Tisch schaut, erkennt die Karte
//  daran, bevor er sie liest; wer sie liest, soll dabei nicht gestoert
//  werden.
//
//  Seit dem 28. Oktober hat auch die Karte selbst einen Auftritt je Rang
//  (`RingCardEntrance`): Die Zwei schiesst wie ein Pfeil herein, die Zehn
//  knallt auf wie ein Stempel, der Koenig wirbelt wie eine Muenze. Vorher
//  kam sie jedes Mal gleich, federnd aus 70 Prozent Groesse – das Groesste
//  auf dem Screen sah bei allen dreizehn Raengen gleich aus.
//
//  Szene, Auftritt und Rangklang beginnen erst, wenn der Screen fast steht
//  (`settle`). Er faehrt als Vollbild von unten herein, und was in dieser
//  Bewegung anfaengt, sieht niemand: ausgerechnet der Anfang, an dem man
//  den Rang erkennt. Der Text steht dagegen sofort da.
//

import SwiftUI

struct RingOfFireActionView: View {

    let card: PlayingCard
    let rule: RingOfFireRule
    /// Hat dieser Zug den Ring gerissen? Dann kostet er zusaetzlich einen
    /// Shot – unabhaengig davon, was auf der Karte steht.
    var tore = false
    /// Was nach dem Riss passiert: neu legen, oder war es der letzte?
    ///
    /// Steht im Banner und nicht nur im Ring dahinter: Wer gerade einen
    /// Shot bekommt, schaut auf diesen Screen – und die Frage "kommt das
    /// noch mal?" stellt sich genau jetzt.
    var tornNote: String?
    let onDone: () -> Void

    /// Wie lange der Screen zum Hereinfahren braucht, bis er fast steht.
    /// Erst dann beginnen Szene, Auftritt und Klang.
    static let settle = 0.3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Sekunden seit Beginn des Auftritts. Laeuft ueber das Ende hinaus,
    /// damit Glanz, Licht und Beben nach dem Schlag auslaufen.
    @State private var cardTime = 0.0

    private var entrance: RingCardEntrance { RingCardEntrance(rank: card.rank) }
    private var scene: RingScene { RingScene(rank: card.rank) }

    /// So weit laeuft die Zeit; mit "Bewegung reduzieren" steht sie gleich dort.
    private var endTime: Double { entrance.playbackDuration + RingCardEntering.afterglow }

    /// Rollen-Karten faerben rot, der Rest bernstein – dieselbe Zuordnung
    /// wie vorher im Panel.
    private var tint: Color {
        rule.role == nil ? BeerStatsColor.accent : BeerStatsColor.error
    }

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: tint)

            GeometryReader { geometry in
                let breite = cardWidth(forHeight: geometry.size.height)

                FillingScrollView {
                    VStack(spacing: 16) {
                        if tore {
                            tornBanner
                        }

                        // Mit "Bewegung reduzieren" steht die Karte sofort
                        // auf ihrem Platz – ein stilles Bild, nicht keins
                        RingCardEntering(
                            card: card,
                            entrance: entrance,
                            width: breite,
                            light: scene.light,
                            time: reduceMotion ? endTime : cardTime
                        )
                        .anchorPreference(key: RingCardAnchorKey.self, value: .bounds) { RingCardAnchors(card: $0) }
                        .padding(.top, 12)

                        // Klein die deutsche Anweisung, gross der Name, unter
                        // dem die Karte am Tisch bekannt ist
                        Text(rule.title)
                            .textCase(.uppercase)
                            .font(.scaled(11, weight: .heavy, design: .rounded))
                            .kerning(2)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                            .anchorPreference(key: RingCardAnchorKey.self, value: .bounds) { RingCardAnchors(text: [$0]) }

                        HStack(spacing: 10) {
                            Text(rule.emoji).font(.system(size: 30))
                            Text(rule.nickname)
                                .font(.scaled(30, weight: .heavy, design: .rounded))
                                .foregroundStyle(tint)
                                .multilineTextAlignment(.center)
                                .keepsWordsWhole(rule.nickname)
                        }
                        .anchorPreference(key: RingCardAnchorKey.self, value: .bounds) { RingCardAnchors(text: [$0]) }

                        Text(rule.text)
                            .font(BeerStatsFont.body)
                            .foregroundStyle(BeerStatsColor.textPrimary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                            .anchorPreference(key: RingCardAnchorKey.self, value: .bounds) { RingCardAnchors(text: [$0]) }

                        terms
                            .padding(.top, 4)
                            .anchorPreference(key: RingCardAnchorKey.self, value: .bounds) { RingCardAnchors(text: [$0]) }
                    }
                    .padding(24)
                }
                // Hinter allem und ueber dem Hintergrund: die Bewegung, die
                // zu dieser Karte gehoert. Sie liegt NICHT ueber der Karte –
                // was zu tun ist, darf nichts verdecken. Und sie waechst mit
                // der Karte – deshalb im GeometryReader und nicht daneben.
                //
                // Sie bekommt gemessen, wo Karte und Text liegen: Der Stempel
                // liegt um die Karte, die Lichter der Acht klirren unter dem
                // Text, und wo Text steht, bleibt sie blass (`RingStage`).
                //
                // Auch nach einem Riss: Das Feuer hat seit dem 28. Oktober
                // seinen eigenen Moment auf dem Ring, bevor dieser Screen
                // kommt. Hier ist danach wieder die Karte dran.
                .backgroundPreferenceValue(RingCardAnchorKey.self) { anker in
                    GeometryReader { flaeche in
                        RingCardFlourish(
                            rank: card.rank,
                            delay: Self.settle,
                            scale: RingScene.scale(forCardWidth: breite),
                            layout: anker.layout(in: flaeche)
                        )
                    }
                }
                // Beim Schlag rueckt der Screen kurz heran und bebt – Szene,
                // Karte und Text zusammen. Der Knopf darunter steht still.
                .modifier(RingHitShake(
                    time: reduceMotion ? endTime : cardTime,
                    hit: entrance.hitTime,
                    zooms: scene.zoomsOnHit,
                    quake: scene.quake
                ))
            }
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Verstanden", systemImage: "checkmark") {
                onDone()
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [
                        BeerStatsColor.backgroundPrimary.opacity(0),
                        BeerStatsColor.backgroundPrimary
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .onAppear {
            guard !reduceMotion else { return }
            // Linear: Wie schnell die Karte wann ist, rechnet der Auftritt
            // selbst – eine zweite Kurve darueber verbiege seine Rechnung
            withAnimation(.linear(duration: endTime).delay(Self.settle)) {
                cardTime = endTime
            }
        }
        // Jeder Rang klingt anders – man hoert, welche Karte kam, bevor man
        // sie liest. Mit dem Auftritt, nicht mit dem Hereinfahren; und
        // bricht ab, wenn der Screen vorher wieder zu ist.
        .task {
            try? await Task.sleep(nanoseconds: UInt64(Self.settle * 1_000_000_000))
            guard !Task.isCancelled else { return }
            SoundManager.play(.ringRank(card.rank))
        }
    }

    /// Die Karte so gross, wie der Screen es hergibt (3. November: "noch
    /// groesser"). Gerechnet aus der Hoehe: Was um die Karte herum steht,
    /// braucht seinen Platz, der Rest gehoert ihr. Mit grosser Schrift wird
    /// deshalb die Karte kleiner, nie der Text – aber nie kleiner als vorher.
    private func cardWidth(forHeight hoehe: CGFloat) -> CGFloat {
        let frei = hoehe - Self.textAllowance - (tore ? Self.tornAllowance : 0)
        return min(Self.cardWidths.upperBound, max(Self.cardWidths.lowerBound, frei / PlayingCardView.aspect))
    }

    /// Von der Breite, die die Karte bis zum 3. November hatte, bis zu der,
    /// ab der sie den Text unter sich aus dem Bild schoebe.
    private static let cardWidths: ClosedRange<CGFloat> = 150...220
    /// Was ueber und unter der Karte steht – Name, Titel, Regel, Dauer und
    /// Strafe samt Abstaenden –, in normaler Schriftgroesse.
    private static let textAllowance: CGFloat = 330
    /// Dazu der Riss-Hinweis, wenn der Ring gerissen ist.
    private static let tornAllowance: CGFloat = 170

    /// Der Riss. Steht ueber der Karte, weil er die groessere Nachricht ist.
    ///
    /// Die Menge kommt aus `DrinkAmount`, nicht aus dem Text: Der Riss
    /// kostet einen Shot, und wer ohne Shots spielt, trinkt die
    /// entsprechenden Schluecke – dieselbe Regel wie ueberall.
    private var tornBanner: some View {
        VStack(spacing: 6) {
            Text("🔥").font(.system(size: 44))

            Text("Ring gerissen")
                .font(.scaled(26, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.warning)

            Text("Du hast die Lücke gemacht – \(DrinkAmount.shot.text).")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let tornNote {
                Text(tornNote)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.warning)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .glassPanel(cornerRadius: 20)
        .neonEdge(BeerStatsColor.warning, cornerRadius: 20, intensity: 1)
    }

    /// Wie lange und was es kostet.
    ///
    /// Die Dauer steht IMMER da, auch wenn sie „Sofort" lautet – dieselbe
    /// Entscheidung wie bei den Extreme-Karten. Die Strafe fehlt dagegen bei
    /// Karten, die einfach eine Menge ansagen: Dort ist das Trinken die
    /// Handlung, es gibt nichts zu verlieren.
    private var terms: some View {
        VStack(spacing: 6) {
            TermRow(
                systemImage: "clock",
                label: "Wie lange",
                value: rule.duration ?? "Sofort"
            )

            if let penalty = rule.penalty {
                TermRow(
                    systemImage: "drop.fill",
                    label: "Strafe",
                    value: penalty,
                    tint: BeerStatsColor.error
                )
            }
        }
    }
}

// MARK: - Wo Karte und Text liegen

/// Karte und Textzeilen melden ihre Lage als Anker nach oben; aufgeloest
/// werden sie dort, wo die Szene liegt – im Hintergrund des Screens.
struct RingCardAnchors {
    var card: Anchor<CGRect>?
    var text: [Anchor<CGRect>] = []

    /// Die Lage in Punkten der Flaeche, auf der die Szene liegt. Die
    /// Textzeilen werden zu einem Band zusammengefasst.
    func layout(in proxy: GeometryProxy) -> RingCardLayout {
        let zeilen = text.map { proxy[$0] }
        var band = zeilen.first
        for zeile in zeilen.dropFirst() { band = band?.union(zeile) }
        return RingCardLayout(card: card.map { proxy[$0] }, text: band)
    }
}

struct RingCardAnchorKey: PreferenceKey {
    static let defaultValue = RingCardAnchors()

    static func reduce(value: inout RingCardAnchors, nextValue: () -> RingCardAnchors) {
        let neu = nextValue()
        value.card = value.card ?? neu.card
        value.text += neu.text
    }
}

// MARK: - Der Schlag auf dem ganzen Screen

/// Beim Schlag rueckt der Screen kurz heran (die grossen Momente) und bebt
/// (Blitz, Stempel, Shot). Davor holt er kaum merklich Anlauf. Eine reine
/// Verschiebung beim Zeichnen: Das Layout bleibt, wo es ist.
private struct RingHitShake: GeometryEffect {

    var time: Double
    let hit: Double
    let zooms: Bool
    let quake: Double

    var animatableData: Double {
        get { time }
        set { time = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let s = time - hit
        var zoom = 1.0
        if zooms {
            if s < 0 {
                let q = (s + 0.09) / 0.08
                zoom = 1 - 0.012 * exp(-q * q)
            } else {
                zoom = 1 + 0.035 * exp(-s * 6.5) * SceneArt.clamp(s / 0.035)
            }
        }
        var dx = 0.0, dy = 0.0
        if quake > 0, s > 0, s < 0.5 {
            let a = quake * exp(-s * 11)
            dx = a * sin(s * 2 * .pi * 21)
            dy = a * 0.7 * cos(s * 2 * .pi * 15)
        }
        // Herangerueckt wird auf die Karte zu – sie steht im oberen Drittel
        let ax = size.width * 0.5, ay = size.height * 0.33
        let k = CGFloat(zoom)
        let verschiebung = CGAffineTransform(translationX: ax + CGFloat(dx), y: ay + CGFloat(dy))
            .scaledBy(x: k, y: k)
            .translatedBy(x: -ax, y: -ay)
        return ProjectionTransform(verschiebung)
    }
}
