//
//  RingOfFireView.swift
//  BeerStats
//
//  Ring of Fire: 52 verdeckte Karten liegen im Kreis um die Flasche. Wer
//  dran ist, zieht eine und tut, was darauf steht.
//
//  Der Ring ist nicht Deko, sondern spielt mit. Die Karten liegen zufaellig
//  verteilt und GESCHUPPT – jede ein Stueck unter der naechsten, wie am
//  echten Tisch. Daraus kommt die Regel, die dem Spiel seinen Namen gibt:
//  Wer den Ring reisst, trinkt einen Shot. Gerissen ist er, wenn zwischen
//  den beiden naechsten noch liegenden Nachbarinnen danach eine SICHTBARE
//  Luecke klafft (`RingLayout.tearsRing`).
//
//  Das Wort sichtbar ist die Lehre vom 26. Oktober und steht nicht aus
//  Geschmack da: Vorher reichte "beruehren sich nicht mehr", und damit
//  feuerte die Regel bei einer Luecke von genau null. Der Shot kam, der
//  Ring sah aus wie vorher, und am Tisch war das nicht von Willkuer zu
//  unterscheiden. Jetzt muss eine Viertelkarte Luft sein, und die Luecke
//  wird GEZEICHNET – aus denselben Zahlen, mit denen gerechnet wird
//  (`gapMarker`).
//
//  Vorher lagen die Karten in gleichen Abstaenden mit Luft dazwischen, und
//  die Regel gab es gar nicht – es war ein Stapel, den jemand im Kreis
//  angeordnet hatte. Der Ring sah aus wie der Ring und tat nichts.
//
//  Die Karten behalten ihren Platz, auch wenn sie gezogen sind – deshalb ein
//  Feld fester Laenge mit Luecken statt eines schrumpfenden Stapels. Fuer
//  dieselbe Luecke zahlt niemand zweimal; die Karte NEBEN einer Luecke
//  reisst dagegen umso leichter, weil dort zwei Kartenbreiten frei werden.
//  Beides steht als Markierung auf dem Schirm.
//
//  Drei Risse kostet eine Runde, dann ist die Regel durch (24. Oktober).
//  Nach jedem der ersten beiden wird eingesammelt und neu gelegt – wie am
//  Tisch. Das muss begrenzt sein: Solange der Ring ganz daliegt, reisst
//  jeder fuenfte Zug, und ein Spiel, das dreissig Shots verteilt, spielt
//  niemand zu Ende. Nach dem dritten bleibt der Ring liegen, wie er liegt,
//  und die Luecken sind nur noch Spielstand.
//
//  Vier Raenge wirken weiter, nachdem die Karte gezogen wurde. Sie landen in
//  der Merkliste unter dem Ring, weil sie sonst mit der naechsten Karte aus
//  dem Blick und aus dem Sinn waeren.
//

import SwiftUI

struct RingOfFireView: View {

    /// Wie viele Karten im Ring liegen. Bleibt gespeichert – wer kurze
    /// Runden mag, mag sie auch naechste Woche.
    @AppStorage("ringOfFire.cardCount") private var cardCount = PlayingCardDeck.fullSize

    /// Vor dem Start steht die Vorbereitung, danach der Tisch.
    @State private var hasStarted = false

    /// `nil` bedeutet: Platz im Ring, Karte schon gezogen.
    @State private var ring: [PlayingCard?] = []
    /// Wo die Karten liegen – zufaellig gestreut, teils ueberlappend.
    @State private var layout = RingLayout.random(count: PlayingCardDeck.fullSize)
    @State private var current: PlayingCard?

    /// Die Stelle, an der der Ring gerade gerissen ist – fuer das
    /// Aufblitzen im Ring. Verblasst von selbst.
    @State private var tornAt: Int?
    /// Hat der ZULETZT gezogene Zug gerissen? Steht getrennt, weil der
    /// Aktionsscreen laenger offen ist als das Aufblitzen dauert.
    @State private var currentTore = false
    @State private var tearPulse = false
    @State private var tearTask: Task<Void, Never>?

    /// Wie oft der Ring in dieser Runde schon gerissen ist.
    ///
    /// Drei Shots hat eine Runde – danach ist die Regel durch. Ohne diese
    /// Grenze waere der Riss eine Steuer, die den ganzen Abend mitlaeuft:
    /// Am Anfang reisst jeder fuenfte Zug, und wer das dreissigmal zahlt,
    /// spielt nicht mehr mit.
    @State private var tears = 0
    /// Steht das Neulegen noch aus? Es passiert erst, wenn der
    /// Aktionsscreen zu ist – sonst waere der Ring schon anders, waehrend
    /// man noch die Karte liest, und niemand saehe, wo es gerissen hat.
    @State private var needsRelayout = false

    /// So viele Risse kostet eine Runde. Danach sind Luecken egal.
    private static let shotsPerRound = 3

    /// Der zweite Screen – die gezogene Karte in Gross.
    @State private var showsAction = false
    /// Steht die Hausregel-Frage noch aus? Sie kommt erst NACH dem
    /// Aktionsscreen: Erst liest man die Karte zu Ende, dann tippt man.
    @State private var needsRulePrompt = false

    /// Die Karte, auf der das Licht gerade steht, waehrend gezogen wird.
    @State private var spotlight: Int?
    @State private var isDrawing = false
    @State private var drawTask: Task<Void, Never>?

    // Laufende Rollen – ein Eintrag je vergebener Karte, weil jede weitere
    // Karte desselben Rangs eine weitere Person in dieselbe Rolle bringt:
    // Am Tisch liegen dann eben zwei Buben vor zwei Leuten.
    //
    // Hier standen bis zum 25. Oktober drei Zaehler. Die Merkliste sagte
    // damit "Daumenmeister ×2", aber nicht WER – und am echten Tisch liegt
    // die Karte sichtbar vor der Person. Die App weiss es: Wer gezogen hat,
    // rechnet `PlayerNames`.
    //
    // Gespeichert wird der NAME und nicht der Zaehlerstand des Zuges. Kommt
    // jemand dazu, verschiebt `position(forTurn:)` sich – und die Rolle
    // saesse ploetzlich bei jemand anderem, ohne dass es auffiele.
    @State private var roleHolders: [RingRoleHolder] = []
    @State private var houseRules: [RingHouseRule] = []
    /// Wer die Regel aufstellt, die gleich eingetippt wird. Muss beim Ziehen
    /// gemerkt werden: Gefragt wird erst, wenn der Aktionsscreen zu ist, und
    /// bis dahin ist `turn` schon weiter.
    @State private var ruleAuthor: String?

    /// Wie oft gezogen wurde. Wer dran ist, rechnet `TurnRow`.
    @State private var turn = 0

    @State private var isAskingForRule = false
    @State private var ruleDraft = ""

    private var remaining: Int { ring.compactMap { $0 }.count }

    var body: some View {
        Group {
            if hasStarted {
                table
            } else {
                setup
            }
        }
        .navigationTitle("Ring of Fire")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            drawTask?.cancel()
            tearTask?.cancel()
        }
        .sheet(isPresented: $isAskingForRule) {
            rulePrompt
        }
    }

    // MARK: - Vorbereitung

    private var setup: some View {
        GameSetupScreen(
            emoji: "🔥",
            title: "Ring of Fire",
            subtitle: "Wie lang soll die Runde werden?",
            tint: BeerStatsColor.error,
            onStart: start
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("KARTEN IM RING")
                    .font(.scaled(11, weight: .heavy, design: .rounded))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                ChoiceRow(
                    options: [
                        ChoiceOption(value: 20, title: "20", detail: "kurz"),
                        ChoiceOption(value: 32, title: "32", detail: "mittel"),
                        ChoiceOption(value: PlayingCardDeck.fullSize, title: "52", detail: "ganzer Stapel")
                    ],
                    selection: $cardCount,
                    tint: BeerStatsColor.error
                )

                Text(stapelHinweis)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Die Karten liegen geschuppt im Kreis, jede ein Stück unter der nächsten. Klafft nach deinem Zug zwischen den Nachbarn eine Lücke, ist der Ring gerissen: Das kostet dich \(DrinkAmount.shot.text), und der Ring wird neu gelegt. Die Lücke leuchtet auf – du siehst also, wofür du trinkst. Für dieselbe Lücke zahlt niemand zweimal, aber die Karte NEBEN einer Lücke reißt umso leichter. Drei Risse hat die Runde; danach sind Lücken egal.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DrinkIntensityPicker(game: .ringOfFire)
        }
    }

    // MARK: - Tisch

    private var table: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.error)

            FillingScrollView {
                VStack(spacing: 18) {
                    ringOfCards
                    tearStatus
                    emptyRingPanel
                    TurnRow(turn: turn, tint: BeerStatsColor.error)
                    drawButton
                    roleBoard
                }
                .padding(20)
            }
        }
        // Der Blitz liegt UEBER allem und haengt am Zaehler, nicht an einem
        // Ja/Nein: Ein `Bool` blitzte genau einmal pro Screen (Lessons
        // Learned Nr. 11). Er nimmt keine Tipps an, liegt also auch nicht
        // auf dem Knopf.
        .overlay(EffectFlash(trigger: tears, tint: BeerStatsColor.warning))
        // Vollbild statt Blatt: In dem Moment zaehlt nur, was auf der Karte
        // steht. Der Ring darunter wuerde nur ablenken.
        .fullScreenCover(isPresented: $showsAction) {
            if let current {
                RingOfFireActionView(
                    card: current,
                    rule: RingOfFireRules.rule(for: current.rank),
                    tore: currentTore,
                    tornNote: currentTore ? tearNote : nil
                ) {
                    showsAction = false
                }
            }
        }
        // Die Hausregel wird erst danach eingetippt – ein Textfeld ueber der
        // Karte haette man gelesen, bevor man die Karte gelesen hat.
        .onChange(of: showsAction) { istOffen in
            guard !istOffen else { return }

            // Erst neu legen, dann die Hausregel fragen: Das Textfeld legt
            // sich ueber den Ring, und man soll vorher gesehen haben, dass
            // er neu liegt.
            if needsRelayout { relayout() }

            guard needsRulePrompt else { return }
            needsRulePrompt = false
            isAskingForRule = true
        }
    }

    // MARK: - Der Ring

    private var ringOfCards: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)

            // Die Kartenbreite folgt dem Layout, nicht umgekehrt: Wie viel
            // Platz eine Karte im Kreis einnimmt, steht in `cardSpan`, und
            // genau damit wird auch gerechnet, ob der Ring reisst. Waere die
            // Breite frei gewaehlt, sehe man eine Ueberlappung und es gaelte
            // eine andere – ein Bild, das luegt.
            //
            // Radius und Hoehe haengen voneinander ab (die Karten ragen nach
            // innen, der Radius muss das lassen). Einmal aufgeloest:
            //   r = (side/2) / (1 + 2 * 1.45 * 0.75 * sin(span/2))
            let halbeSpanne = CGFloat(sin(layout.cardSpan / 2 * .pi / 180))
            let radius = (side / 2) / (1 + 2.175 * halbeSpanne)
            let cardWidth = 2 * radius * halbeSpanne
            let cardHeight = cardWidth * 1.45
            // Was in der Mitte frei bleibt. Bei zwanzig Karten liegt der Ring
            // als dichter Kranz und das Loch ist klein – dann steht dort nur
            // noch die Zahl.
            let innen = radius - cardHeight / 2

            ZStack {
                VStack(spacing: 2) {
                    if innen > 56 {
                        Text("🍾").font(.system(size: innen * 0.5))
                    }
                    Text("\(remaining)")
                        .font(.system(size: innen * 0.45, weight: .heavy, design: .rounded))
                        .foregroundStyle(BeerStatsColor.error)
                        .monospacedDigit()
                    if innen > 56 {
                        Text("übrig")
                            .font(BeerStatsFont.statLabel)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                    }
                }

                ForEach(ring.indices, id: \.self) { position in
                    ringCard(
                        width: cardWidth,
                        height: cardHeight,
                        isLit: spotlight == position,
                        isEmpty: ring[position] == nil,
                        isTorn: tornAt == position
                    )
                        // Erst nach aussen schieben, dann um die Mitte
                        // drehen: `offset` verschiebt nur die Darstellung,
                        // nicht den Rahmen – der Drehpunkt bleibt also die
                        // Mitte des Rings.
                        .offset(y: -radius)
                        .rotationEffect(.degrees(angle(for: position)))
                        // Muss sein, seit die Karten sich ueberlappen: Der
                        // Lichtpunkt und der Riss liegen sonst unter der
                        // naechsten Karte, weil ein ZStack in
                        // Reihenfolge zeichnet – und genau die beiden sind
                        // das, was man sehen soll.
                        .zIndex(spotlight == position || tornAt == position ? 1 : 0)
                }

                // Die offenen Stellen. Sie liegen ueber den Karten, damit
                // eine Nachbarkante den Schein nicht verdeckt – und sie
                // kommen aus demselben Layout, mit dem gerechnet wird.
                ForEach(layout.openings(present: ring.map { $0 != nil }), id: \.from) { opening in
                    gapMarker(
                        width: chord(degrees: opening.width, radius: radius),
                        height: cardHeight
                    )
                        .offset(y: -radius)
                        .rotationEffect(.degrees(opening.centerAngle))
                        .zIndex(2)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            // Die Druckwelle geht von der Mitte aus und nicht von der
            // Luecke: Gerissen ist der RING, nicht die Karte – und die
            // Stelle zeigt ohnehin schon der Blitz dort.
            .overlay {
                if tornAt != nil {
                    // Drei Schichten uebereinander, und das ist hier
                    // richtig: Der Riss ist der lauteste Moment des Spiels
                    // – er kostet einen Shot und hat die Regel im Namen.
                    // Mit einer Druckwelle allein sah er aus wie jede
                    // andere Rueckmeldung.
                    EffectShockwave(tint: BeerStatsColor.warning, rings: 3, duration: 1.0)
                    EffectParticles(
                        symbol: "💥", count: 14, flight: .burst,
                        tint: BeerStatsColor.warning, duration: 1.1,
                        stagger: 0.04, sizeRange: 26...52, opacity: 0.95
                    )
                    EffectSlam(symbol: "💥", from: .top, tint: BeerStatsColor.error, size: 200, opacity: 0.32)
                }
            }
            // Der Ruck beim Reissen. Kurz und klein – der Ring soll zucken,
            // nicht wegfliegen.
            .scaleEffect(tearPulse ? 1.04 : 1)
            .rotationEffect(.degrees(tearPulse ? 1.5 : 0))
        }
        // Nimmt sich die volle Breite und bleibt quadratisch: Der Ring ist
        // der Screen, nicht eine Zeile darin.
        .aspectRatio(1, contentMode: .fit)
        .animation(AppAnimation.standard, value: remaining)
    }

    /// Wie viele Risse die Runde noch kostet.
    ///
    /// Steht erst da, wenn der erste passiert ist: Vorher waere es eine
    /// Regel ohne Anlass, und der Vorspann erklaert sie ohnehin. Ab dem
    /// ersten Riss ist es dagegen die Zahl, die am Tisch zaehlt.
    @ViewBuilder
    private var tearStatus: some View {
        if hasStarted, tears > 0 {
            HStack(spacing: 8) {
                Text("💥")
                Text(tearStatusText)
                    .font(.scaled(12, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(ruleIsSpent ? BeerStatsColor.textSecondary : BeerStatsColor.warning)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                (ruleIsSpent ? BeerStatsColor.textSecondary : BeerStatsColor.warning).opacity(0.14),
                in: Capsule()
            )
        }
    }

    /// Die Regel ist aufgebraucht – ab jetzt sind Luecken egal.
    private var ruleIsSpent: Bool { tears >= Self.shotsPerRound }

    private var tearStatusText: String {
        ruleIsSpent
            ? "\(Self.shotsPerRound) von \(Self.shotsPerRound) – Lücken sind jetzt egal"
            : "\(tears) von \(Self.shotsPerRound) Rissen"
    }

    /// Was auf dem Aktionsscreen unter dem Riss steht.
    private var tearNote: String {
        if ruleIsSpent {
            return "Das war der dritte Riss. Ab jetzt sind Lücken egal – der Ring bleibt liegen, wie er liegt."
        }
        let offen = Self.shotsPerRound - tears
        return offen == 1
            ? "Der Ring wird neu gelegt. Der nächste Riss ist der letzte."
            : "Der Ring wird neu gelegt. Danach kosten noch \(offen) Risse einen Shot."
    }

    /// Welche Karten bei dieser Einstellung im Ring liegen.
    ///
    /// Gerechnet und nicht getippt: Die Auswahl steht in
    /// `PlayingCardDeck.highestRanks` – staende sie hier als Satz, waere
    /// sie nach der naechsten Aenderung falsch.
    private var stapelHinweis: String {
        let raenge = PlayingCardDeck.highestRanks(count: cardCount)
            .map(\.rank)
            .reduce(into: Set<Int>()) { $0.insert($1) }
            .sorted()

        guard let kleinster = raenge.first else { return "" }
        let name = PlayingCard(rank: kleinster, suit: .hearts).rankName

        if raenge.count == PlayingCardDeck.ranks.count {
            return "Das ganze Blatt: alle dreizehn Ränge, von jedem alle vier Karten."
        }
        return "Die \(raenge.count) höchsten Ränge – ab \(name) aufwärts, von jedem alle vier Karten. Die kleinen Karten sagen nur Mengen an; was den Tisch beschäftigt, steht oben."
    }

    /// Die Markierung einer offenen Stelle – das, was am 26. Oktober
    /// gefehlt hat.
    ///
    /// Der Riss war vorher eine Rechnung ohne Bild: Der freie Platz der
    /// gezogenen Karte ist bewusst unsichtbar (sonst sieht jeder Zug gleich
    /// aus), die LUECKE zwischen den Nachbarinnen war es aber auch – und
    /// damit gab es nichts, worauf man am Tisch zeigen konnte. Der Shot kam
    /// aus dem Nichts.
    ///
    /// Gezeichnet wird deshalb genau die Strecke, mit der die Regel
    /// rechnet: Was hier leuchtet, ist die Luecke, die den Shot gekostet
    /// hat. Sie bleibt liegen, bis neu gelegt wird – nach dem
    /// Aktionsscreen soll man die Stelle wiederfinden, ohne zu suchen.
    private func gapMarker(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Der Schein. Breiter als die Luecke selbst, sonst ist eine
            // schmale kaum zu sehen.
            Capsule()
                .fill(BeerStatsColor.warning)
                .frame(width: max(width, 6), height: height * 0.92)
                .blur(radius: max(width, 10) * 0.9)
                .opacity(0.75)

            // Der Spalt: heller Kern, nach aussen auslaufend. Kein Rahmen –
            // eine Luecke hat keine Kante, sie ist das Fehlen einer.
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            BeerStatsColor.warning.opacity(0.35),
                            BeerStatsColor.warning,
                            BeerStatsColor.warning.opacity(0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: max(width * 0.5, 3), height: height * 0.86)
        }
        .frame(width: max(width, 6), height: height)
        // Zierde-Regeln wie bei den Effekten: nimmt keine Tipps an und
        // steht VoiceOver nicht im Weg. Was offen ist, sagt die Zeile unter
        // dem Ring.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Die Sehne zu einem Winkel – so wird aus einer Luecke in Grad eine
    /// Breite in Punkten.
    ///
    /// Dieselbe Rechnung wie bei der Kartenbreite, und das ist Pflicht:
    /// Wuerde die Markierung anders gerechnet, zeigte das Bild eine andere
    /// Luecke als die, fuer die jemand getrunken hat.
    private func chord(degrees: Double, radius: CGFloat) -> CGFloat {
        2 * radius * CGFloat(sin(max(degrees, 0) / 2 * .pi / 180))
    }

    /// Kommt aus dem Layout, nicht aus der Position: Die Karten liegen
    /// gestreut, nicht in gleichen Abstaenden.
    private func angle(for position: Int) -> Double {
        layout.angles.indices.contains(position) ? layout.angles[position] : 0
    }

    /// Eine Karte im Ring.
    ///
    /// `isEmpty` ist der freie Platz einer gezogenen Karte – und der ist
    /// seit dem 23. Oktober LEER, nicht gestrichelt umrandet.
    ///
    /// Der gestrichelte Platz stammte aus der Zeit, als die Karten in
    /// gleichen Abstaenden mit Luft dazwischen lagen; dort war er die
    /// Anzeige des Spielstands. Im geschuppten Ring hat er die Regel
    /// unsichtbar gemacht, die das Spiel ausmacht: Gerissen ist der Ring
    /// zwischen den NACHBARN, nicht an der gezogenen Karte. Mit einem
    /// Platzhalter an der Stelle der gezogenen Karte sieht aber jeder Zug
    /// gleich aus – mal kommt eine Strafe, mal nicht, und am Tisch wirkt
    /// das wie Willkuer. Wie viel noch liegt, steht ohnehin in der Mitte.
    ///
    /// Gezeigt wird stattdessen die LUECKE selbst (`gapMarker`) – das ist
    /// die Stelle, um die es in der Regel geht.
    ///
    /// `isLit` ist der Lichtpunkt, der beim Ziehen herumwandert. Die Karten
    /// sind nicht antippbar: Gezogen wird ausgelost.
    ///
    /// `isTorn` ist die Stelle, an der der Ring gerade gerissen ist. Sie
    /// leuchtet kurz auf – die Luecke selbst bleibt danach als normale
    /// Luecke stehen, denn gerissen wird sie nur einmal.
    private func ringCard(
        width: CGFloat,
        height: CGFloat,
        isLit: Bool,
        isEmpty: Bool,
        isTorn: Bool
    ) -> some View {
        RoundedRectangle(cornerRadius: max(2, width * 0.18), style: .continuous)
            .fill(
                isEmpty
                    ? LinearGradient(
                        colors: [Color.clear, Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    : (isLit
                        ? LinearGradient(
                            colors: [BeerStatsColor.error, BeerStatsColor.warning],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        : LinearGradient(
                            colors: [BeerStatsColor.surfaceElevated, BeerStatsColor.backgroundPrimary],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: max(2, width * 0.18), style: .continuous)
                    .strokeBorder(
                        BeerStatsColor.error.opacity(isEmpty ? 0 : (isLit ? 1 : 0.7)),
                        lineWidth: isLit ? 1.8 : 1.1
                    )
            )
            .overlay(
                // Der Riss: ein kurzer heller Blitz genau dort, wo die Karte
                // lag. Die Luecke selbst ist unsichtbar – der Blitz ist
                // das Einzige, was die Stelle zeigt, und man soll sie
                // finden, ohne zu suchen.
                RoundedRectangle(cornerRadius: max(2, width * 0.18), style: .continuous)
                    .fill(BeerStatsColor.warning)
                    .blur(radius: width * 0.3)
                    .opacity(isTorn ? 0.9 : 0)
            )
            .shadow(
                color: isTorn
                    ? BeerStatsColor.warning.opacity(0.95)
                    : BeerStatsColor.error.opacity(isLit ? 0.9 : 0),
                radius: isTorn ? 18 : 10
            )
            .frame(width: width, height: height)
            .scaleEffect(isLit ? 1.45 : 1)
            // Der leere Platz ist unsichtbar – ausser im Moment des Risses,
            // damit man die Stelle findet, an der es gerade gekracht hat.
            .opacity(isEmpty && !isTorn ? 0 : 1)
    }

    // MARK: - Ring durch

    /// Steht nur da, wenn nichts mehr liegt. Alles andere zur gezogenen
    /// Karte passiert auf dem zweiten Screen.
    @ViewBuilder
    private var emptyRingPanel: some View {
        if remaining == 0 {
            VStack(spacing: 14) {
                Text("🔥").font(.system(size: 54))
                Text("Ring durch")
                    .font(BeerStatsFont.title)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                // Zurueck in die Vorbereitung statt sofort neu: Nach einer
                // durchgespielten Runde ist genau der Moment, in dem jemand
                // "diesmal kuerzer" sagt.
                PrimaryButton(title: "Neuer Ring", systemImage: "shuffle") { restart() }
            }
            .frame(maxWidth: .infinity)
            .padding(22)
            .glassPanel(cornerRadius: 22)
        }
    }

    @ViewBuilder
    private var drawButton: some View {
        if remaining > 0 {
            PrimaryButton(
                title: isDrawing ? "Läuft …" : "Karte ziehen",
                systemImage: isDrawing ? "hourglass" : "hand.tap.fill"
            ) {
                drawRandom()
            }
            .opacity(isDrawing ? 0.5 : 1)
            .disabled(isDrawing)
        }
    }

    // MARK: - Merkliste

    @ViewBuilder
    private var roleBoard: some View {
        if !roleHolders.isEmpty || !houseRules.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("LÄUFT NOCH")
                    .font(.scaled(11, weight: .heavy, design: .rounded))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                // Eine Zeile je Rolle, in der Reihenfolge der Aufzaehlung und
                // nicht in der des Ziehens: Sonst springt die Liste bei jeder
                // neuen Karte um. Untereinander statt nebeneinander, weil mit
                // Namen ("Trink-Duo · Lena, Jan") keine drei Kapseln mehr in
                // eine Zeile passen.
                //
                // Die Hausregel-Rolle fehlt hier mit Absicht: Sie steht
                // ausgeschrieben darunter, und eine Kapsel "Regeln · Lena"
                // ueber dem Text der Regel waere dieselbe Auskunft zweimal.
                ForEach(RingOfFireRole.allCases.filter { $0 != .houseRule }) { role in
                    let halter = roleHolders.filter { $0.role == role }
                    if !halter.isEmpty {
                        roleChip(role, holders: halter.map(\.name))
                    }
                }

                ForEach(houseRules) { regel in
                    HStack(alignment: .top, spacing: 8) {
                        Text("📜")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(regel.text)
                                .font(BeerStatsFont.caption)
                                .foregroundStyle(BeerStatsColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let author = regel.author {
                                Text("von \(author)")
                                    .font(BeerStatsFont.statLabel)
                                    .foregroundStyle(BeerStatsColor.textSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                        // Ueber die ID und nicht ueber den Platz in der
                        // Liste: Mit dem Index trifft ein zweiter Druck,
                        // bevor die Ansicht neu gezeichnet ist, die falsche
                        // Regel.
                        Button {
                            houseRules.removeAll { $0.id == regel.id }
                            HapticManager.lightImpact()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(BeerStatsColor.textSecondary)
                        }
                    }
                }

                QuietButton(title: "Alles zurücksetzen") { clearRoles() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassPanel(cornerRadius: 18)
        }
    }

    /// Eine Zeile der Merkliste. Was darauf steht, rechnet
    /// `RingOfFireRoleBoard` – reine Zeichenarbeit, ohne Ansicht pruefbar.
    private func roleChip(_ role: RingOfFireRole, holders: [String?]) -> some View {
        HStack(spacing: 5) {
            Text(role.emoji)
            Text(RingOfFireRoleBoard.label(for: role, holders: holders))
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            BeerStatsColor.error.opacity(0.16),
            in: Capsule()
        )
    }

    // MARK: - Regel notieren

    private var rulePrompt: some View {
        VStack(spacing: 18) {
            Text("📜").font(.system(size: 48))

            Text("Welche Regel gilt ab jetzt?")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)

            TextField("z. B. Niemand darf Namen sagen", text: $ruleDraft)
                .textFieldStyle(.plain)
                .padding(14)
                .glassPanel(cornerRadius: 14)
                .submitLabel(.done)
                .onSubmit { saveRule() }

            PrimaryButton(title: "Merken", systemImage: "checkmark") { saveRule() }
                .disabled(ruleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(ruleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)

            // Aufschreiben ist freiwillig: Am Tisch wird die Regel ohnehin
            // ausgesprochen, und ein Pflichtfeld haelt das Spiel auf.
            QuietButton(title: "Ohne Notiz weiter") {
                ruleDraft = ""
                isAskingForRule = false
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    private func saveRule() {
        let text = ruleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        houseRules.append(RingHouseRule(author: ruleAuthor, text: text))
        ruleDraft = ""
        ruleAuthor = nil
        isAskingForRule = false
        HapticManager.success()
    }

    // MARK: - Ablauf

    private func draw(at position: Int) {
        guard let card = ring[position] else { return }

        // Wer zieht, steht VOR dem Hochzaehlen fest – danach ist `turn`
        // schon der Naechste, und der Shot landete bei der falschen Person.
        let zieher = turn

        // Vor dem Entfernen fragen: Danach liegt die Karte nicht mehr, und
        // die Frage "reisst das den Ring?" waere nicht mehr zu stellen.
        // Nach dem dritten Riss gar nicht mehr fragen – die Regel ist durch.
        let reisst = !ruleIsSpent
            && layout.tearsRing(at: position, present: ring.map { $0 != nil })

        withAnimation(AppAnimation.standard) { ring[position] = nil }

        current = card
        currentTore = reisst

        let regel = RingOfFireRules.rule(for: card.rank)

        if reisst {
            tears += 1
            // Erst neu legen, wenn noch Risse offen sind. Nach dem dritten
            // bleibt der Ring liegen, wie er liegt.
            needsRelayout = !ruleIsSpent
        }

        // Beides kann denselben Zug treffen: Ein Ass, das den Ring reisst,
        // kostet zwei Shots – einen fuer die Karte, einen fuer die Luecke.
        // Das ist am Tisch auch so und darf sich nicht zu einem verrechnen.
        if let platz = PlayerNames.position(forTurn: zieher) {
            if reisst { EveningLog.record(.shot, forPlayer: platz) }
            if let menge = regel.drawerDrinks { EveningLog.record(menge, forPlayer: platz) }
        }

        // Noch mit `zieher` gerechnet, nicht mit dem schon erhoehten Zaehler:
        // Die Rolle bekommt der, der die Karte gezogen hat.
        let halter = holderName(forTurn: zieher)
        turn += 1
        apply(regel, rank: card.rank, holder: halter)

        if reisst {
            tear(at: position)
        } else if remaining == 0 {
            // Die letzte Karte ohne Riss: Der Ring ist heil durchgespielt,
            // und das ist am Tisch eine Meldung wert.
            SoundManager.play(.victory)
        }

        showsAction = true
    }

    /// Der Ring ist gerissen: Blitz, Ruck, Knall – und der Shot steht
    /// danach auf dem Aktionsscreen.
    ///
    /// Der Klang kommt hier und nicht in `apply`: Ein Riss schlaegt jeden
    /// Kartenklang, und zwei Toene gleichzeitig sind einer zu viel.
    private func tear(at position: Int) {
        tearTask?.cancel()
        tornAt = position

        HapticManager.error()
        SoundManager.play(.bombe)
        SpeechAnnouncer.announce("Ring gerissen")

        tearTask = Task { @MainActor in
            withAnimation(.spring(response: 0.18, dampingFraction: 0.35)) { tearPulse = true }
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.6)) { tearPulse = false }

            // Der Blitz bleibt laenger als der Ruck: Er muss den
            // Aktionsscreen ueberleben, damit man die Stelle beim
            // Zurueckkommen noch findet.
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(AppAnimation.standard) { tornAt = nil }
        }
    }

    /// Legt die uebrigen Karten neu aus.
    ///
    /// Wie am Tisch: Nach einem Riss sammelt man ein, was noch da ist, und
    /// legt es neu im Kreis. Gemischt wird dabei auch – laegen dieselben
    /// Karten in derselben Reihenfolge, waere nur der Abstand neu, und wer
    /// die Reihenfolge gemerkt hat, wuesste weiter, was kommt.
    private func relayout() {
        needsRelayout = false

        let uebrig = ring.compactMap { $0 }
        guard !uebrig.isEmpty else { return }

        tearTask?.cancel()
        withAnimation(AppAnimation.standard) {
            ring = uebrig.shuffled().map { Optional($0) }
            layout = RingLayout.random(count: ring.count)
        }
        spotlight = nil
        tornAt = nil
        tearPulse = false

        HapticManager.mediumImpact()
        SoundManager.play(.reRack)
    }

    private func apply(_ rule: RingOfFireRule, rank: Int, holder: String?) {
        HapticManager.mediumImpact()

        switch rule.role {
        case .thumbMaster:
            roleHolders.append(RingRoleHolder(role: .thumbMaster, name: holder))
            SoundManager.play(.onFire)
        case .questionQueen:
            roleHolders.append(RingRoleHolder(role: .questionQueen, name: holder))
            SoundManager.play(.onFire)
        case .drinkingMate:
            roleHolders.append(RingRoleHolder(role: .drinkingMate, name: holder))
            SoundManager.play(.ballsBack)
        case .houseRule:
            SoundManager.play(.reRack)
            // Nicht sofort: Erst liest man die Karte zu Ende, dann tippt
            // man. Ausgeloest wird die Frage beim Schliessen des
            // Aktionsscreens.
            ruleAuthor = holder
            needsRulePrompt = true
        case .none:
            // Das Ass ist der einzige Rang mit einem Shot – dafür der harte
            // Ton, alles andere bleibt der leise Kartenklang. Am Rang und
            // nicht am Emoji festgemacht, damit eine Umbenennung den Klang
            // nicht stillschweigend mitnimmt.
            SoundManager.play(rank == 14 ? .bombe : .cardFlip)
        }
    }

    private func start() {
        drawTask?.cancel()
        tearTask?.cancel()
        ring = PlayingCardDeck.highestRanks(count: cardCount).map { Optional($0) }
        // Jede Runde wird neu ausgelegt: Dieselben Karten an denselben
        // Stellen hiesse, dass auch dieselben Stellen reissen – und nach
        // zwei Abenden wuesste man, wo.
        layout = RingLayout.random(count: ring.count)
        current = nil
        currentTore = false
        tears = 0
        needsRelayout = false
        turn = 0
        spotlight = nil
        tornAt = nil
        tearPulse = false
        isDrawing = false
        clearRoles()
        hasStarted = true
        HapticManager.success()
        SoundManager.play(.reRack)
    }

    private func restart() {
        drawTask?.cancel()
        tearTask?.cancel()
        isDrawing = false
        spotlight = nil
        tornAt = nil
        tearPulse = false
        needsRelayout = false
        hasStarted = false
    }

    /// Lost eine der noch liegenden Karten aus und laesst das Licht dorthin
    /// laufen.
    private func drawRandom() {
        guard !isDrawing else { return }

        let liegende = ring.indices.filter { ring[$0] != nil }
        guard let ziel = liegende.randomElement() else { return }

        isDrawing = true
        // Sofort beim Druck, nicht erst beim ersten Tick: Der Knopf muss
        // antworten, bevor das Licht ueberhaupt losgelaufen ist.
        HapticManager.mediumImpact()
        SoundManager.play(.cardFlip)
        drawTask?.cancel()
        drawTask = Task { @MainActor in
            await runSpotlight(to: ziel, over: liegende)
            guard !Task.isCancelled else { return }
            spotlight = nil
            isDrawing = false
            draw(at: ziel)
        }
    }

    /// Der Lichtpunkt laeuft im Uhrzeigersinn ueber die liegenden Karten und
    /// wird zum Schluss langsamer, bis er auf der gezogenen stehen bleibt.
    ///
    /// Die Schrittzahl ist so gewaehlt, dass der letzte Schritt genau auf der
    /// Zielkarte landet – das Licht haelt also dort an, wo die Karte
    /// tatsaechlich herkommt. Es sieht nicht nur nach Auslosung aus, es ist
    /// die Auslosung.
    private func runSpotlight(to target: Int, over positions: [Int]) async {
        guard let zielIndex = positions.firstIndex(of: target) else {
            spotlight = target
            return
        }

        // Eine volle Runde plus der Weg zum Ziel. Bei wenigen Karten waere das
        // ein Zucken statt einer Drehung – deshalb so lange weitere Runden
        // dazu, bis es nach etwas aussieht. Vielfache der Rundenlaenge
        // erhalten dabei, dass der letzte Schritt auf dem Ziel landet.
        var schritte = positions.count + zielIndex
        while schritte < 16 { schritte += positions.count }

        for schritt in 0...schritte {
            guard !Task.isCancelled else { return }

            spotlight = positions[schritt % positions.count]

            // Die letzten Schritte bremsen spuerbar ab – das ist der ganze
            // Trick am Gluecksrad. Davor laeuft es gleichmaessig schnell.
            let restlich = schritte - schritt
            let dauer: Double
            if restlich > 14 {
                dauer = 0.012
                // Auch die schnelle Phase tickt – nur jeden vierten
                // Schritt. Auf jedem waere es bei 12 Millisekunden ein
                // Rauschen, auf keinem war das Rad die erste Sekunde lang
                // STUMM: Man druckt, es dreht sich, und man hoert nichts.
                // Genau das ist am 25. Oktober am Tisch aufgefallen.
                if schritt % 4 == 0 { SoundManager.play(.tap) }
            } else {
                dauer = 0.05 + 0.25 * (Double(14 - restlich) / 14)
                HapticManager.lightImpact()
                // Das Ticken des Auslaufens, jetzt auf jedem Schritt: Hier
                // sind die Abstaende lang genug, dass man einzelne Schlaege
                // hoert statt eines Rauschens.
                SoundManager.play(.tap)
            }

            try? await Task.sleep(nanoseconds: UInt64(dauer * 1_000_000_000))
        }
    }

    private func clearRoles() {
        roleHolders.removeAll()
        houseRules.removeAll()
        ruleAuthor = nil
    }

    /// Der Name dessen, der bei Zaehlerstand `turn` gezogen hat – oder
    /// `nil`, wenn die App niemanden kennt.
    ///
    /// Ohne Emoji: In der Merkliste steht schon das Symbol der Rolle davor,
    /// und zwei Zeichen vor einem Namen sind eins zu viel. Der Rueckfall
    /// laeuft ueber `position(forTurn:)`, weil nur der `nil` liefert –
    /// `plainName` wuerde "Spieler 3" zurueckgeben, und das hilft in einer
    /// Merkliste niemandem.
    private func holderName(forTurn turn: Int) -> String? {
        guard let position = PlayerNames.position(forTurn: turn) else { return nil }
        return PlayerNames.plainName(for: position)
    }
}

/// Eine vergebene Rolle. Eigener Typ und nicht nur ein Name, weil dieselbe
/// Rolle mehrfach im Spiel sein kann und jeder Eintrag seine eigene Identitaet
/// braucht – sonst fasst `ForEach` zwei gleich benannte Halter zusammen.
private struct RingRoleHolder: Identifiable {
    let id = UUID()
    let role: RingOfFireRole
    /// `nil`, wenn die App zu dieser Karte niemanden kennt.
    let name: String?
}

/// Eine Regel, die jemand mit der Zehn aufgestellt hat.
private struct RingHouseRule: Identifiable {
    let id = UUID()
    let author: String?
    let text: String
}
