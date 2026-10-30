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
//  unterscheiden. Seit dem 28. Oktober muss eine halbe Karte Luft sein,
//  und was darunter liegt, haelt sichtbar ein Glutfaden zusammen
//  (`RingEmbers`) – aus denselben Zahlen, mit denen gerechnet wird.
//
//  Reisst er, gehoert der Moment erst dem Ring: Der Faden reisst an der
//  Stelle, eine Stichflamme schlaegt heraus, und "RISS" steht ueber der
//  Luecke. Erst danach kommt die Karte. Vorher schob sie sich sofort
//  darueber, und wo es gerissen war, sah niemand.
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
//  Tisch. Das muss begrenzt sein: Jede Luecke macht die naechste
//  wahrscheinlicher, und ein Spiel, das dreissig Shots verteilt, spielt
//  niemand zu Ende. Nach dem dritten bleibt der Ring liegen, wie er liegt,
//  die Glut ist aus, und die Luecken sind nur noch Spielstand.
//
//  Vier Raenge wirken weiter, nachdem die Karte gezogen wurde. Sie landen in
//  der Merkliste unter dem Ring, weil sie sonst mit der naechsten Karte aus
//  dem Blick und aus dem Sinn waeren – und zwar erst, wenn die Karte
//  gelesen ist, sonst verriete die Liste sie vorher.
//
//  Der Ring bewegt sich wie am Tisch (28. Oktober, auf Wunsch: "noch mehr
//  Animationen"). Zu Beginn und nach jedem Riss wird aus einem Stapel in der
//  Mitte ausgeteilt, Karte fuer Karte im Uhrzeigersinn – so SIEHT man, dass
//  neu gemischt wurde. Die gezogene Karte hebt sich aus dem Ring, bevor der
//  Kartenscreen kommt, das Lauflicht zieht einen Schweif, und wenn nichts
//  mehr liegt, brennt ein Kranz (`RingFinale`).
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

    /// Der Riss, der gerade seinen Moment hat – vom Reissen, bis der
    /// Aktionsscreen wieder zu ist.
    @State private var tearMoment: RingTearMoment?
    /// Hat der ZULETZT gezogene Zug gerissen? Steht getrennt, weil der
    /// Aktionsscreen laenger offen ist als der Moment dauert.
    @State private var currentTore = false
    /// Die beiden Nachbarinnen zucken beim Riss weg – von 1 federnd auf 0.
    @State private var tearJolt = 0.0
    @State private var tearTask: Task<Void, Never>?
    /// Eine Stelle, die gerade knapp gehalten hat: Dort leuchtet der Faden
    /// kurz auf.
    @State private var held: RingHeld?
    @State private var heldTask: Task<Void, Never>?

    /// Wie oft der Ring in dieser Runde schon gerissen ist.
    ///
    /// Drei Shots hat eine Runde – danach ist die Regel durch. Ohne diese
    /// Grenze waere der Riss eine Steuer, die den ganzen Abend mitlaeuft:
    /// Jede Luecke macht die naechste wahrscheinlicher, und wer das
    /// dreissigmal zahlt, spielt nicht mehr mit.
    @State private var tears = 0
    /// Steht das Neulegen noch aus? Es passiert erst, wenn der
    /// Aktionsscreen zu ist – sonst waere der Ring schon anders, waehrend
    /// man noch die Karte liest, und niemand saehe, wo es gerissen hat.
    @State private var needsRelayout = false

    /// So viele Risse kostet eine Runde. Danach sind Luecken egal.
    private static let shotsPerRound = 3

    /// Der zweite Screen – die gezogene Karte in Gross.
    @State private var showsAction = false
    /// Ist das Zahnrad offen? Dann wartet der Kartenscreen (`actionIsWaiting`),
    /// bis es zu ist – zwei Blaetter zugleich zeigt SwiftUI nicht.
    @State private var isAdjusting = false
    @State private var actionIsWaiting = false
    /// Steht die Hausregel-Frage noch aus? Sie kommt erst NACH dem
    /// Aktionsscreen: Erst liest man die Karte zu Ende, dann tippt man.
    @State private var needsRulePrompt = false

    /// Die Karte, auf der das Licht gerade steht, waehrend gezogen wird.
    @State private var spotlight: Int?
    /// Die Raenge der letzten Zuege, juengster zuletzt – damit derselbe
    /// Rang nicht gleich wiederkommt (`RingDraw`).
    @State private var recentRanks: [Int] = []
    @State private var isDrawing = false
    @State private var drawTask: Task<Void, Never>?

    /// Liegen die Karten ausgeteilt im Kreis – oder als Stapel in der Mitte?
    /// Beim Start und nach jedem Riss wird aus dem Stapel ausgeteilt.
    @State private var dealt = true
    /// Solange ausgeteilt oder eingesammelt wird, zieht niemand.
    @State private var isDealing = false
    @State private var dealTask: Task<Void, Never>?
    /// Die Karte, die gerade aus dem Ring gehoben wird, und wie weit.
    @State private var lifting: RingLift?
    @State private var liftProgress = 0.0
    /// Der Kartenscreen kommt erst, wenn die Karte aus dem Ring ist.
    @State private var actionTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    /// Die Rolle der Karte, die gerade gelesen wird. In die Merkliste kommt
    /// sie erst, wenn der Kartenscreen zu ist: Die Karte hebt sich zuerst
    /// aus dem Ring, und eine Zeile "Daumenmeister", die in dieser Zeit
    /// unter dem Ring auftaucht, verriete die Karte, bevor man sie sieht.
    @State private var pendingRole: RingRoleHolder?
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
        // Das Zahnrad bleibt stehen, auch waehrend gezogen und ausgeteilt
        // wird. Bis zum 30. Oktober verschwand es dabei, damit es dem
        // Kartenscreen nicht in die Quere kommt – und tauchte so bei jedem
        // Zug neu auf ("das Zahnrad kommt immer wieder"). Jetzt wartet
        // stattdessen der Kartenscreen, bis das Blatt zu ist.
        .roundSettings(
            for: .ringOfFire,
            isAvailable: hasStarted,
            note: "Die Kartenzahl gilt ab der nächsten Runde, die Härte ab der nächsten Karte.",
            onOpen: { isAdjusting = true },
            onClose: settingsClosed
        ) {
            cardCountChoice
        }
        .onDisappear {
            drawTask?.cancel()
            tearTask?.cancel()
            heldTask?.cancel()
            dealTask?.cancel()
            actionTask?.cancel()
            // Abgebrochen darf der Ring nicht halb ausgeteilt liegen bleiben,
            // und ein Aufleuchten, das niemand mehr zuruecknimmt, liesse den
            // Faden ewig neu zeichnen
            dealt = true
            isDealing = false
            held = nil
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
                cardCountChoice

                Text("Die Karten liegen geschuppt im Kreis, jede ein Stück unter der nächsten. Darunter glüht ein Faden: Kleine Lücken hält er, und je weiter sie werden, desto dünner glüht er. Reißt er nach deinem Zug, ist der Ring gerissen. Das kostet dich \(DrinkAmount.shot.text), und der Ring wird neu gelegt. Für dieselbe Lücke zahlt niemand zweimal, aber die Karte NEBEN einer Lücke reißt umso leichter. Drei Risse hat die Runde; danach ist die Glut aus.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DrinkIntensityPicker(game: .ringOfFire)
        }
    }

    /// Im Vorspann und im Zahnrad dieselbe Auswahl. Gelesen wird die Zahl
    /// nur beim Auslegen (`start`) – der Ring, der gerade liegt, bleibt.
    private var cardCountChoice: some View {
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
        }
    }

    /// Der Kartenscreen – aber nicht ueber dem Zahnrad. Waehrend das Blatt
    /// offen ist, faende er keinen Platz und fiele stillschweigend weg; die
    /// Karte waere gezogen, ohne dass sie jemand gesehen hat.
    private func presentAction() {
        if isAdjusting {
            actionIsWaiting = true
        } else {
            showsAction = true
        }
    }

    /// Das Zahnrad ist zu: Kam inzwischen eine Karte, zeigt sie sich jetzt.
    private func settingsClosed() {
        isAdjusting = false
        guard actionIsWaiting else { return }
        actionIsWaiting = false
        showsAction = true
    }

    // MARK: - Tisch

    private var table: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.error)

            FillingScrollView {
                VStack(spacing: 18) {
                    // Der Ring darf naeher an den Rand als der Rest: Die
                    // Karten werden mit ihm groesser (27. Oktober, "Karten
                    // groesser"). Die negative Polsterung gibt ihm 24 pt
                    // mehr Breite, ohne die Zeilen darunter zu verschieben.
                    ringOfCards
                        .padding(.horizontal, -12)
                    tearStatus
                    emptyRingPanel
                    TurnRow(turn: turn, tint: BeerStatsColor.error)
                    drawButton
                    roleBoard
                }
                .padding(20)
            }
        }
        // Der Riss-Moment liegt ueber dem ganzen Screen: Er dunkelt alles
        // ab bis auf die Stelle, und dort brennt es. Der Ring meldet von
        // innen, wo er liegt. Ein Blitz ueber den ganzen Schirm kommt nicht
        // mehr – er nahm der Stelle die Aufmerksamkeit, die sie haben soll.
        .overlayPreferenceValue(RingTearSpotKey.self) { spot in
            Group {
                if let spot {
                    RingTearOverlay(spot: spot)
                        .id(spot.moment.id)
                }
            }
        }
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

            // Der Moment ist vorbei, sobald die Karte gelesen ist
            tearMoment = nil
            // Der dritte Riss: Die Glut geht aus, und das hoert man
            if currentTore, ruleIsSpent { SoundManager.play(.ringOut) }

            // Die Rolle der gelesenen Karte rutscht jetzt in die Merkliste –
            // sichtbar, waehrend der Kartenscreen nach unten wegfaehrt
            if let neu = pendingRole {
                pendingRole = nil
                withAnimation(AppAnimation.standard) { roleHolders.append(neu) }
            }

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
                // Ring durch: Wo die Karten lagen, brennt jetzt ein Kranz
                // (`RingFinale`). Hinter der Zahl, damit sie lesbar bleibt.
                if showsFinale {
                    RingFinale(radius: radius)
                }

                VStack(spacing: 2) {
                    if innen > 56 {
                        Text("🍾").font(.system(size: innen * 0.5))
                    }
                    Text("\(remaining)")
                        .font(.system(size: innen * 0.45, weight: .heavy, design: .rounded))
                        .foregroundStyle(BeerStatsColor.error)
                        .monospacedDigit()
                        // Die Zahl rollt herunter, statt zu springen
                        .contentTransition(.numericText())
                    if innen > 56 {
                        Text("übrig")
                            .font(BeerStatsFont.statLabel)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                    }
                }

                // Der Glutfaden liegt UNTER den Karten: Wo sie sich
                // ueberlappen, verdecken sie ihn, in einer Luecke sieht man
                // ihn – gehalten oder gerissen.
                RingEmbers(
                    links: layout.links(present: ring.map { $0 != nil }),
                    radius: radius,
                    isSpent: ruleIsSpent,
                    tearing: tearMoment?.link,
                    held: held
                )
                // Liegen die Karten als Stapel in der Mitte, liegt auch kein
                // Faden im Kreis – er gluehte sonst unter Karten, die gar
                // nicht da sind
                .opacity(dealt ? 1 : 0)
                .animation(embersAnimation, value: dealt)

                ForEach(ring.indices, id: \.self) { position in
                    ringCard(
                        width: cardWidth,
                        height: cardHeight,
                        isLit: spotlight == position,
                        isEmpty: ring[position] == nil
                    )
                        // Als Stapel in der Mitte kleiner und leicht verdreht
                        .scaleEffect(dealt ? 1 : RingMotion.pileScale)
                        // Erst nach aussen schieben, dann um die Mitte
                        // drehen: `offset` verschiebt nur die Darstellung,
                        // nicht den Rahmen – der Drehpunkt bleibt also die
                        // Mitte des Rings.
                        .offset(y: dealt ? -radius : 0)
                        .rotationEffect(.degrees(angle(for: position) + jolt(for: position) - (dealt ? 0 : RingMotion.pileTwist)))
                        .animation(dealAnimation(at: position), value: dealt)
                        // Muss sein, seit die Karten sich ueberlappen: Der
                        // Lichtpunkt laege sonst unter der naechsten Karte,
                        // weil ein ZStack in Reihenfolge zeichnet.
                        .zIndex(spotlight == position ? 1 : 0)
                }

                // Die gezogene Karte hebt sich aus dem Ring und verschwindet
                // zur Mitte – man sieht, woher sie kam, bevor der
                // Kartenscreen sie zeigt
                if let lift = lifting {
                    liftedCard(lift, radius: radius, width: cardWidth, height: cardHeight)
                        .zIndex(2)
                        .allowsHitTesting(false)
                        // Ohne Einblenden: Sie steht sofort genau da, wo die
                        // Karte lag. Mit dem ueblichen Einblenden liefe sie
                        // gleichzeitig hinein und hinaus und waere kaum zu
                        // sehen – die Zahl in der Mitte aendert sich im selben
                        // Moment, und deren Animation gilt fuer den ganzen Ring.
                        .transition(.identity)
                        .onAppear {
                            withAnimation(.easeInOut(duration: RingMotion.lift)) { liftProgress = 1 }
                        }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            // Der Riss meldet sich nach oben: Sein Moment liegt ueber dem
            // ganzen Screen und muss wissen, wo der Ring steht.
            .anchorPreference(key: RingTearSpotKey.self, value: .bounds) { rahmen in
                tearMoment.map { RingTearSpot(ring: rahmen, radius: radius, cardHeight: cardHeight, moment: $0) }
            }
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

    /// Wie weit eine Nachbarin beim Riss wegzuckt, in Grad – die linke
    /// gegen, die rechte mit dem Uhrzeigersinn.
    private func jolt(for position: Int) -> Double {
        guard let link = tearMoment?.link else { return 0 }
        if position == link.from { return -4 * tearJolt }
        if position == link.to { return 4 * tearJolt }
        return 0
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
    /// Gezeigt wird stattdessen die LUECKE selbst, ueber den Glutfaden
    /// darunter – das ist die Stelle, um die es in der Regel geht.
    ///
    /// `isLit` ist der Lichtpunkt, der beim Ziehen herumwandert. Die Karten
    /// sind nicht antippbar: Gezogen wird ausgelost.
    ///
    /// Gerissen wird nicht an der Karte, sondern zwischen den Nachbarinnen –
    /// das zeigt der Glutfaden und der Moment darueber (`RingEmbers`).
    private func ringCard(
        width: CGFloat,
        height: CGFloat,
        isLit: Bool,
        isEmpty: Bool
    ) -> some View {
        let form = RoundedRectangle(cornerRadius: max(2, width * 0.18), style: .continuous)
        let licht = LinearGradient(
            colors: [BeerStatsColor.error, BeerStatsColor.warning],
            startPoint: .top,
            endPoint: .bottom
        )

        return form
            .fill(
                isEmpty
                    ? LinearGradient(
                        colors: [Color.clear, Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    : (isLit
                        ? licht
                        : LinearGradient(
                            colors: [BeerStatsColor.surfaceElevated, BeerStatsColor.backgroundPrimary],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
            )
            // Das Licht glimmt nach: eine eigene Schicht, die beim Ausgehen
            // langsam verblasst. So zieht es beim Losen einen Schweif hinter
            // sich her, statt von Karte zu Karte zu springen. Nur die Farbe –
            // Groesse und Schein springen wie vorher, sonst stuenden in der
            // schnellen Phase dreissig aufgeblaehte Karten im Ring.
            .overlay(
                form
                    .fill(licht)
                    .opacity(isLit ? 1 : 0)
                    .animation(afterglow(isLit), value: isLit)
            )
            .overlay(
                form
                    .strokeBorder(
                        BeerStatsColor.error.opacity(isEmpty ? 0 : (isLit ? 1 : 0.7)),
                        lineWidth: isLit ? 1.8 : 1.1
                    )
            )
            .shadow(color: BeerStatsColor.error.opacity(isLit ? 0.9 : 0), radius: 10)
            .frame(width: width, height: height)
            .scaleEffect(isLit ? 1.45 : 1)
            // Der leere Platz ist unsichtbar: Mit einem Platzhalter saehe
            // jeder Zug gleich aus.
            .opacity(isEmpty ? 0 : 1)
    }

    /// Das Licht springt an und verblasst langsam.
    private func afterglow(_ isLit: Bool) -> Animation? {
        guard !isLit else { return nil }
        return .easeOut(duration: RingMotion.afterglow)
    }

    /// Die gezogene Karte auf dem Weg aus dem Ring: Sie hebt sich von ihrem
    /// Platz, wird kleiner und verschwindet zur Mitte.
    private func liftedCard(_ lift: RingLift, radius: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        let weg = CGFloat(liftProgress)
        return ringCard(width: width, height: height, isLit: true, isEmpty: false)
            .scaleEffect(1 - RingMotion.liftShrink * weg)
            .offset(y: -radius * (1 - RingMotion.liftInward * weg))
            .rotationEffect(.degrees(lift.angle))
            .opacity(1 - liftProgress)
    }

    /// Der Faden kommt, wenn die Karten ausgeteilt sind, und geht mit dem
    /// Einsammeln.
    private var embersAnimation: Animation? {
        guard !reduceMotion else { return nil }
        guard dealt else { return .easeOut(duration: RingMotion.gather) }
        return .easeIn(duration: RingMotion.dealDuration).delay(RingMotion.dealSpread)
    }

    /// Der Kranz brennt, wenn nichts mehr liegt UND die letzte Karte gelesen
    /// ist – sonst liefe sein Anfang unter dem Kartenscreen.
    private var showsFinale: Bool {
        remaining == 0 && !isDrawing && !showsAction
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
                title: isBusy ? "Läuft …" : "Karte ziehen",
                systemImage: isBusy ? "hourglass" : "hand.tap.fill"
            ) {
                drawRandom()
            }
            .opacity(isBusy ? 0.5 : 1)
            .disabled(isBusy)
        }
    }

    /// Gezogen wird nicht, solange das Licht laeuft, ein Moment laeuft oder
    /// ausgeteilt wird.
    private var isBusy: Bool { isDrawing || isDealing }

    /// Austeilen: Karte fuer Karte im Uhrzeigersinn, aus dem Stapel in der
    /// Mitte nach aussen. Einsammeln: alle zugleich, nach innen.
    private func dealAnimation(at position: Int) -> Animation? {
        guard !reduceMotion else { return nil }
        guard dealt else { return .easeIn(duration: RingMotion.gather) }
        let reihe = Double(position) / Double(max(1, ring.count))
        return .easeOut(duration: RingMotion.dealDuration).delay(reihe * RingMotion.dealSpread)
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
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                ForEach(houseRules) { regel in
                    houseRuleRow(regel)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                QuietButton(title: "Alles zurücksetzen") { clearRoles() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassPanel(cornerRadius: 18)
            .transition(.opacity)
        }
    }

    private func houseRuleRow(_ regel: RingHouseRule) -> some View {
        // Eine Regel, die jemand mit der Zehn aufgestellt hat – samt Knopf,
        // der sie wieder streicht.
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
                withAnimation(AppAnimation.standard) {
                    houseRules.removeAll { $0.id == regel.id }
                }
                HapticManager.lightImpact()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
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
        withAnimation(AppAnimation.standard) {
            houseRules.append(RingHouseRule(author: ruleAuthor, text: text))
        }
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

        // Die Karte verlaesst den Ring als eigene Ansicht, die sich heraushebt
        // und zur Mitte verschwindet (`liftedCard`) – ihr Platz ist sofort
        // leer, damit sie nicht zweimal zu sehen ist
        if !reduceMotion {
            lifting = RingLift(angle: angle(for: position))
            liftProgress = 0
        }
        withAnimation(AppAnimation.standard) { ring[position] = nil }
        SoundManager.play(.ringDraw)

        // Mehr als die gedaempften Raenge braucht die Auslosung nicht
        recentRanks = Array((recentRanks + [card.rank]).suffix(RingDraw.recentDamping.count))

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
        apply(regel, holder: halter)

        // Die Verbindung, die ueber der gezogenen Karte entstanden ist – sie
        // reisst oder haelt
        let ueber = layout.link(over: position, present: ring.map { $0 != nil })

        if reisst, let riss = ueber {
            beginTear(riss)
            return
        }

        if !ruleIsSpent, let ueber, ueber.isVisible {
            // Knapp gehalten: Die Luecke ist da, aber der Faden traegt sie
            hold(ueber)
        }
        if remaining == 0 {
            // Die letzte Karte ohne Riss: Der Ring ist heil durchgespielt,
            // und das ist am Tisch eine Meldung wert.
            SoundManager.play(.victory)
        }

        // Der Kartenscreen kommt, wenn die Karte aus dem Ring ist – sonst
        // faehrt er ueber ihren Weg hinweg, und man saehe nicht, woher sie kam
        openAction(after: reduceMotion ? 0 : RingMotion.actionDelay)
    }

    private func openAction(after pause: Double) {
        actionTask?.cancel()
        actionTask = Task { @MainActor in
            if pause > 0 {
                try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            lifting = nil
            isDrawing = false
            presentAction()
        }
    }

    /// Der Ring ist gerissen, und der Moment gehoert erst ihm: Der Faden
    /// reisst an der Stelle, eine Stichflamme schlaegt heraus, der Rest wird
    /// dunkel, "RISS" steht ueber der Luecke (`RingTearOverlay`). Erst
    /// danach kommt die Karte mit dem Shot.
    ///
    /// Vorher kam der Aktionsscreen sofort, und die Flammen schlugen an
    /// seinem Rand herein. Wo es gerissen war, sah niemand – genau das hat
    /// der Nutzer am 28. Oktober gewollt: nachvollziehen koennen, wo.
    ///
    /// Keine Sprachansage (27. Oktober, auf Wunsch des Nutzers): Das "Ring
    /// gerissen" in der Stimme nahm dem Moment die Wucht, statt sie zu
    /// tragen. Gesagt wird es vom Bild.
    private func beginTear(_ link: RingLayout.Link) {
        tearTask?.cancel()
        tearMoment = RingTearMoment(link: link)

        // Erst der harte Stoss, dann die Fehler-Rueckmeldung hinterher – zwei
        // Schlaege, die man in der Hand unterscheidet
        HapticManager.heavyImpact()
        SoundManager.play(.ringTear)

        // Die Nachbarinnen zucken weg und federn zurueck. Erst setzen, dann
        // im naechsten Durchgang animieren – im selben gesetzt, saehe
        // SwiftUI nur den Endwert (Lessons Learned Nr. 17).
        tearJolt = 1
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.3)) { tearJolt = 0 }
        }

        tearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            HapticManager.error()
            try? await Task.sleep(nanoseconds: UInt64((RingTearArt.duration - 0.18) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            lifting = nil
            isDrawing = false
            presentAction()
        }
    }

    /// Eine Luecke, die der Faden noch traegt: Er leuchtet dort kurz auf,
    /// und die Glut knistert – ein Durchatmen am Tisch.
    private func hold(_ link: RingLayout.Link) {
        heldTask?.cancel()
        held = RingHeld(from: link.from, to: link.to, since: Date())
        SoundManager.play(.ringHolds)
        heldTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            held = nil
        }
    }

    /// Legt die uebrigen Karten neu aus.
    ///
    /// Wie am Tisch: Nach einem Riss sammelt man ein, was noch da ist, und
    /// legt es neu im Kreis. Gemischt wird dabei auch – laegen dieselben
    /// Karten in derselben Reihenfolge, waere nur der Abstand neu, und wer
    /// die Reihenfolge gemerkt hat, wuesste weiter, was kommt.
    ///
    /// Und man SIEHT es: Die Karten werden zur Mitte eingesammelt, dort neu
    /// gemischt und dann Karte fuer Karte im Uhrzeigersinn ausgeteilt. Vorher
    /// rutschten sie nur an neue Plaetze, und ob gemischt wurde, musste man
    /// glauben.
    private func relayout() {
        needsRelayout = false

        let uebrig = ring.compactMap { $0 }
        guard !uebrig.isEmpty else { return }

        tearTask?.cancel()
        dealTask?.cancel()
        spotlight = nil
        tearMoment = nil
        held = nil
        lifting = nil

        // Mit "Bewegung reduzieren" liegt der Ring einfach neu
        guard !reduceMotion else {
            HapticManager.mediumImpact()
            SoundManager.play(.ringShuffle)
            ring = uebrig.shuffled().map { Optional($0) }
            layout = RingLayout.random(count: ring.count)
            return
        }

        isDealing = true
        dealTask = Task { @MainActor in
            // Erst muss der Kartenscreen weg sein: Er faehrt nach unten aus
            // dem Bild, und darunter saehe man vom Einsammeln nur das Ende.
            // So steht der Ring noch einen Augenblick mit seiner Luecke da.
            try? await Task.sleep(nanoseconds: UInt64(RingMotion.coverAway * 1_000_000_000))
            guard !Task.isCancelled else { return }
            HapticManager.mediumImpact()
            SoundManager.play(.ringShuffle)
            // Einsammeln – jede Karte animiert sich selbst (`dealAnimation`)
            dealt = false
            try? await Task.sleep(nanoseconds: UInt64(RingMotion.gather * 1_000_000_000))
            guard !Task.isCancelled else { return }
            // Im Stapel neu mischen und neu legen – man sieht es nicht, weil
            // gerade alles in der Mitte liegt
            ring = uebrig.shuffled().map { Optional($0) }
            layout = RingLayout.random(count: ring.count)
            await dealOut()
        }
    }

    /// Teilt aus dem Stapel in der Mitte aus und gibt den Knopf danach
    /// wieder frei.
    private func dealOut() async {
        // Eine kurze Pause, damit der Stapel mit den neuen Karten gezeichnet
        // ist, bevor er sich aufloest (Lessons Learned Nr. 17)
        try? await Task.sleep(nanoseconds: UInt64(RingMotion.pause * 1_000_000_000))
        guard !Task.isCancelled else { return }
        dealt = true
        try? await Task.sleep(nanoseconds: UInt64((RingMotion.dealSpread + RingMotion.dealDuration) * 1_000_000_000))
        guard !Task.isCancelled else { return }
        isDealing = false
    }

    private func apply(_ rule: RingOfFireRule, holder: String?) {
        HapticManager.mediumImpact()

        // Der Klang des Rangs kommt nicht hier, sondern mit der Karte auf
        // dem Kartenscreen (`RingOfFireActionView`): Er gehoert zu dem
        // Moment, in dem man sie sieht.
        switch rule.role {
        case .thumbMaster, .questionQueen, .drinkingMate:
            // Erst gemerkt, in die Liste kommt sie nach dem Kartenscreen
            // (`pendingRole`)
            if let rolle = rule.role {
                pendingRole = RingRoleHolder(role: rolle, name: holder)
            }
        case .houseRule:
            // Nicht sofort: Erst liest man die Karte zu Ende, dann tippt
            // man. Ausgeloest wird die Frage beim Schliessen des
            // Aktionsscreens.
            ruleAuthor = holder
            needsRulePrompt = true
        case .none:
            break
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
        recentRanks = []
        turn = 0
        spotlight = nil
        tearMoment = nil
        held = nil
        lifting = nil
        pendingRole = nil
        isDrawing = false
        clearRoles()
        hasStarted = true
        HapticManager.success()
        SoundManager.play(.ringShuffle)

        // Die Karten liegen erst als Stapel in der Mitte und werden dann
        // ausgeteilt – wie am Tisch. Mit "Bewegung reduzieren" liegen sie
        // gleich im Kreis.
        dealTask?.cancel()
        dealt = reduceMotion
        isDealing = !reduceMotion
        guard !reduceMotion else { return }
        dealTask = Task { @MainActor in
            // Erst den Wechsel vom Vorspann zum Tisch abwarten
            try? await Task.sleep(nanoseconds: UInt64(RingMotion.beforeFirstDeal * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await dealOut()
        }
    }

    private func restart() {
        drawTask?.cancel()
        tearTask?.cancel()
        heldTask?.cancel()
        dealTask?.cancel()
        actionTask?.cancel()
        isDealing = false
        lifting = nil
        isDrawing = false
        spotlight = nil
        tearMoment = nil
        held = nil
        needsRelayout = false
        hasStarted = false
    }

    /// Lost eine der noch liegenden Karten aus und laesst das Licht dorthin
    /// laufen. Gelost wird vorher und nicht ganz gleich verteilt: Der Rang
    /// von eben kommt nicht gleich wieder (`RingDraw`).
    private func drawRandom() {
        guard !isBusy else { return }

        let liegende = ring.indices.filter { ring[$0] != nil }
        guard let ziel = RingDraw.pick(ring: ring, recentRanks: recentRanks) else { return }

        isDrawing = true
        // Sofort beim Druck, nicht erst beim ersten Tick: Der Knopf muss
        // antworten, bevor das Licht ueberhaupt losgelaufen ist.
        HapticManager.mediumImpact()
        SoundManager.play(.ringTick)
        drawTask?.cancel()
        drawTask = Task { @MainActor in
            await runSpotlight(to: ziel, over: liegende)
            guard !Task.isCancelled else { return }
            spotlight = nil
            // `isDrawing` nimmt erst `draw(at:)` zurueck: Reisst der Ring,
            // laeuft noch sein Moment, und so lange darf niemand ziehen.
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
                if schritt % 4 == 0 { SoundManager.play(.ringTick) }
            } else {
                dauer = 0.05 + 0.25 * (Double(14 - restlich) / 14)
                HapticManager.lightImpact()
                // Das Ticken des Auslaufens, jetzt auf jedem Schritt: Hier
                // sind die Abstaende lang genug, dass man einzelne Schlaege
                // hoert statt eines Rauschens.
                SoundManager.play(.ringTick)
            }

            try? await Task.sleep(nanoseconds: UInt64(dauer * 1_000_000_000))
        }
        // Das Licht steht: ein satter Schlag statt eines weiteren Ticks
        guard !Task.isCancelled else { return }
        SoundManager.play(.ringStop)
    }

    private func clearRoles() {
        withAnimation(AppAnimation.standard) {
            roleHolders.removeAll()
            houseRules.removeAll()
        }
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

/// Die Karte, die gerade aus dem Ring gehoben wird.
private struct RingLift {
    /// Wo sie lag – von dort hebt sie sich heraus.
    let angle: Double
}

/// Wie sich der Ring bewegt. Einsammeln und Herausheben sind zuerst in der
/// Vorschau "Riss im Ring" gezeichnet worden, mit denselben Zahlen.
private enum RingMotion {
    /// So lange faehrt der Kartenscreen nach unten weg, bevor nach einem
    /// Riss eingesammelt wird.
    static let coverAway = 0.3
    /// Einsammeln zur Mitte, alle zugleich.
    static let gather = 0.28
    /// So lange fliegt eine einzelne Karte beim Austeilen.
    static let dealDuration = 0.34
    /// Ueber so viel Zeit verteilt sich das Austeilen um den Ring – die
    /// letzte Karte startet so viel spaeter als die erste.
    static let dealSpread = 0.55
    /// Vor dem ersten Austeilen: der Wechsel vom Vorspann zum Tisch.
    static let beforeFirstDeal = 0.25
    /// Eine kurze Pause zwischen Setzen und Animieren.
    static let pause = 0.05
    /// Der Stapel in der Mitte: kleiner als die Karten im Ring und etwas
    /// gegen den Uhrzeigersinn verdreht, damit er nach Stapel aussieht.
    static let pileScale: CGFloat = 0.6
    static let pileTwist = 40.0
    /// Die gezogene Karte hebt sich heraus: so lange, so weit nach innen,
    /// und so viel kleiner wird sie dabei – am Ende so gross wie eine
    /// Karte im Stapel.
    static let lift = 0.38
    static let liftInward: CGFloat = 0.75
    static let liftShrink: CGFloat = 0.62
    /// Der Kartenscreen kommt, wenn die Karte aus dem Ring ist.
    static let actionDelay = 0.42
    /// So lange glimmt das Lauflicht auf einer Karte nach. In der schnellen
    /// Phase wird daraus ein langer Schweif, im Auslaufen einer ueber wenige
    /// Karten.
    static let afterglow = 0.35
}
