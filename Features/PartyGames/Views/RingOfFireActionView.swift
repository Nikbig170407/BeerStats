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
    /// Wie weit der Auftritt der Karte ist, von 0 bis 1.
    @State private var entranceProgress = 0.0

    private var entrance: RingCardEntrance { RingCardEntrance(rank: card.rank) }

    /// Rollen-Karten faerben rot, der Rest bernstein – dieselbe Zuordnung
    /// wie vorher im Panel.
    private var tint: Color {
        rule.role == nil ? BeerStatsColor.accent : BeerStatsColor.error
    }

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: tint)

            // Hinter allem und ueber dem Hintergrund: die Bewegung, die zu
            // dieser Karte gehoert. Sie liegt NICHT ueber der Karte – was
            // zu tun ist, darf nichts verdecken.
            //
            // Auch nach einem Riss: Das Feuer hat seit dem 28. Oktober seinen
            // eigenen Moment auf dem Ring, bevor dieser Screen kommt. Hier
            // ist danach wieder die Karte dran.
            RingCardFlourish(rank: card.rank, delay: Self.settle)

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
                        width: 150,
                        progress: reduceMotion ? 1 : entranceProgress
                    )
                    .shadow(color: tint.opacity(0.4), radius: 24)
                    .padding(.top, 12)

                    Text(rule.nickname)
                        .font(.scaled(11, weight: .heavy, design: .rounded))
                        .kerning(2)
                        .foregroundStyle(BeerStatsColor.textSecondary)

                    HStack(spacing: 10) {
                        Text(rule.emoji).font(.system(size: 30))
                        Text(rule.title)
                            .font(.scaled(30, weight: .heavy, design: .rounded))
                            .foregroundStyle(tint)
                            .multilineTextAlignment(.center)
                    }

                    Text(rule.text)
                        .font(BeerStatsFont.body)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)

                    terms
                        .padding(.top, 4)
                }
                .padding(24)
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
            withAnimation(.linear(duration: entrance.duration).delay(Self.settle)) {
                entranceProgress = 1
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
