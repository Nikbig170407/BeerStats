//
//  DrinkRouletteView.swift
//  BeerStats
//
//  Ein Rad: drehen, warten, trinken.
//
//  Die alte Fassung liess Namen eintippen und war danach nur ein
//  Zufallsgenerator. Beides ist weg. Wer trinkt, entscheidet das Feld selbst
//  – ueber die Sitzordnung ("dein linker Nachbar") oder ueber die Runde
//  ("wer zuletzt gelacht hat").
//
//  Seit dem 25. Oktober waehlt man vorher das Rad (`RouletteWheel`). Vorher
//  gab es genau eines mit acht festen Feldern, und das ist beim zweiten Abend
//  dasselbe Rad – ab dem dritten weiss jeder, was draufsteht. Jetzt gibt es
//  drei fertige und ein eigenes, das sich hier auch bearbeiten laesst: Die
//  besten Felder sind die, die nur diese Runde versteht.
//
//  Das Zielfeld wird VOR der Drehung ausgelost und die noetige Umdrehung
//  daraus berechnet. Andersherum – drehen und hinterher ablesen, wo der
//  Zeiger steht – haengt das Ergebnis an Rundungsfehlern im Winkel.
//

import SwiftUI

struct DrinkRouletteView: View {

    /// Welches Rad zuletzt gewaehlt war. Bleibt gespeichert – wer sein
    /// eigenes Rad gebaut hat, will nicht jedes Mal umstellen.
    @AppStorage("drinkRoulette.wheel") private var wheelRaw = RouletteWheel.classic.rawValue

    @State private var hasStarted = false
    /// Die Felder als Schnappschuss vom Start. Das eigene Rad liegt in
    /// UserDefaults; waehrend einer Runde soll es sich nicht unter der Hand
    /// aendern.
    @State private var wedges: [RouletteWedge] = []
    @State private var isEditing = false

    @State private var rotation: Double = 0
    @State private var result: RouletteWedge?
    @State private var isSpinning = false
    @State private var spinTask: Task<Void, Never>?

    @Environment(\.gameWorld) private var world

    private static let spinDuration: Double = 3.0
    private static let fullTurns: Double = 4

    /// Fuenf Farben fuer bis zu zehn Felder. Welche wohin kommt, rechnet
    /// `color(at:of:)` – von Hand zugewiesene Farben muessten bei jedem
    /// neuen Feld nachgepflegt werden.
    private static let palette: [Color] = [
        BeerStatsColor.accent,
        BeerStatsColor.accentSecondary,
        BeerStatsColor.warning,
        BeerStatsColor.error,
        BeerStatsColor.success
    ]

    private var selectedWheel: RouletteWheel {
        RouletteWheel(rawValue: wheelRaw) ?? .classic
    }

    private var step: Double { 360.0 / Double(max(wedges.count, 1)) }

    var body: some View {
        Group {
            if hasStarted {
                table
            } else {
                setup
            }
        }
        .navigationTitle("Trink-Roulette")
        .navigationBarTitleDisplayMode(.inline)
        .roundSettings(for: .drinkRoulette, isAvailable: hasStarted && !isSpinning)
        .onDisappear { spinTask?.cancel() }
        .sheet(isPresented: $isEditing) {
            RouletteWedgeEditor()
        }
    }

    // MARK: - Vorbereitung

    private var setup: some View {
        GameSetupScreen(
            emoji: "🎡",
            title: "Trink-Roulette",
            subtitle: "Welches Rad soll es sein?",
            tint: BeerStatsColor.error,
            isStartDisabled: !selectedWheel.isPlayable,
            onStart: start
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("DAS RAD")
                    .font(.scaled(11, weight: .heavy, design: .rounded))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                // Eine Zeile je Rad und keine `ChoiceRow`: Vier Titel
                // nebeneinander waeren schmal, und was ein Rad ausmacht,
                // steht in der zweiten Zeile.
                ForEach(RouletteWheel.allCases) { rad in
                    OptionRow(
                        emoji: rad.emoji,
                        title: rad.title,
                        detail: rad.detail,
                        isOn: rad == selectedWheel,
                        tint: BeerStatsColor.error
                    ) {
                        wheelRaw = rad.rawValue
                    }
                }

                if selectedWheel == .custom {
                    QuietButton(title: "Eigene Felder bearbeiten") { isEditing = true }

                    if !selectedWheel.isPlayable {
                        Text("Ab \(RouletteWedges.minimum) Feldern lässt sich drehen. Mit zwei ist es eine Münze und kein Rad.")
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            DrinkIntensityPicker(game: .drinkRoulette)
        }
    }

    // MARK: - Tisch

    private var table: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.error)

            // Was das Feld bedeutet, sagt auch die Szene dahinter: Beim
            // Shot steigt Glut, beim Freilos atmet es in Gruen auf. Erst
            // NACH der Drehung – waehrend sie laeuft, soll man aufs Rad
            // schauen.
            if let result, !isSpinning {
                resultScene(for: result)
            }

            VStack(spacing: 22) {
                wheelView
                resultPanel
                Spacer(minLength: 0)
                PrimaryButton(
                    title: isSpinning ? "Dreht …" : "Drehen",
                    systemImage: "arrow.triangle.2.circlepath"
                ) { spin() }
                .disabled(isSpinning)
                .opacity(isSpinning ? 0.5 : 1)

                QuietButton(title: "Anderes Rad") {
                    spinTask?.cancel()
                    isSpinning = false
                    result = nil
                    hasStarted = false
                }
            }
            .padding(24)
        }
    }

    // MARK: - Szene zum Ergebnis

    /// Die Szene haengt an der KOSTENART und nicht am Text: Ein eigenes
    /// Feld hat keinen Katalogeintrag, aber immer eine Menge – damit
    /// bekommt auch ein selbst gebautes Rad die passende Bewegung.
    ///
    /// Und dieselbe Kostenart sieht in der ganzen App gleich aus: Ein Shot
    /// glueht wie das Ass in Ring of Fire, Schluecke steigen als Bier wie
    /// bei "Ich", wer nichts trinkt, atmet auf. So lernt man die Sprache
    /// einmal und nicht je Spiel.
    private func resultScene(for wedge: RouletteWedge) -> AnyView {
        switch wedge.cost {
        case .nothing:
            return AnyView(EffectCanvas(draw: SceneArt.relief).id(wedge.id))
        case .shot:
            return AnyView(EffectCanvas(draw: SceneArt.ace).id(wedge.id))
        default:
            return AnyView(EffectCanvas(draw: SceneArt.drinkSelf).id(wedge.id))
        }
    }

    // MARK: - Rad

    /// Das letzte Feld grenzt an das erste. Treffen beide dieselbe Farbe,
    /// sehen sie wie EIN Stueck aus – bei sechs Feldern und fuenf Farben
    /// passiert genau das.
    private func color(at index: Int, of count: Int) -> Color {
        var gewaehlt = index % Self.palette.count
        if index == count - 1, gewaehlt == 0 { gewaehlt = 1 % Self.palette.count }
        return Self.palette[gewaehlt]
    }

    private var wheelView: some View {
        GeometryReader { geometry in
            // Platz fuer den Kranz lassen, sonst ragt er ueber den Rahmen
            let size = min(geometry.size.width, geometry.size.height) - 30

            ZStack {
                // Der Kranz aus Holz und Gold; seine Lichter drehen sich mit
                CasinoRim(size: size, rotation: rotation)

                ZStack {
                    ForEach(Array(wedges.enumerated()), id: \.element.id) { index, wedge in
                        let farbe = color(at: index, of: wedges.count)

                        PieSlice(index: index, total: wedges.count)
                            .fill(farbe.opacity(0.85))

                        PieSlice(index: index, total: wedges.count)
                            .stroke(BeerStatsColor.backgroundPrimary.opacity(0.6), lineWidth: 2)

                        Text(wedge.label)
                            .font(.system(size: size * 0.055, weight: .heavy, design: .rounded))
                            .foregroundStyle(BeerStatsColor.textOnAccent)
                            .lineLimit(1)
                            // Erst nach außen schieben, dann um die Mitte
                            // drehen – in dieser Reihenfolge landet die
                            // Beschriftung mittig auf ihrem Feld.
                            .offset(y: -size * 0.32)
                            .rotationEffect(.degrees(Double(index) * step + step / 2))
                    }
                }
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation))

                // Die Nabe: Gold auf Holz
                Circle()
                    .fill(CasinoArt.wood)
                    .frame(width: size * 0.22, height: size * 0.22)
                    .overlay(
                        Circle()
                            .fill(RadialGradient(colors: [Color.white.opacity(0.5), CasinoArt.gold],
                                                 center: .topLeading, startRadius: 2, endRadius: size * 0.1))
                            .padding(size * 0.025)
                    )

                // Zeiger oben, fest stehend.
                Triangle()
                    .fill(CasinoArt.gold)
                    .frame(width: size * 0.08, height: size * 0.07)
                    .offset(y: -size * 0.5)
                    .shadow(color: .black.opacity(0.6), radius: 4)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(height: 300)
    }

    @ViewBuilder
    private var resultPanel: some View {
        if let result, !isSpinning {
            Text(result.resolved)
                .font(Font.world(world, 24, weight: .bold))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(18)
                .glassPanel(cornerRadius: 20)
                .neonEdge(BeerStatsColor.error, cornerRadius: 20, intensity: 0.8)
                .transition(.scale.combined(with: .opacity))
        } else {
            Text("Reihum drehen. Was der Zeiger trifft, gilt.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .frame(height: 62)
        }
    }

    // MARK: - Ablauf

    private func start() {
        let gewaehlt = selectedWheel.wedges
        guard gewaehlt.count >= 2 else { return }

        // Gemischt, damit auch ein fertiges Rad nicht jedes Mal gleich
        // aussieht – gelost wird ohnehin, aber wer die Reihenfolge kennt,
        // sieht beim Auslaufen schon, was kommt.
        wedges = gewaehlt.shuffled()
        rotation = 0
        result = nil
        isSpinning = false
        hasStarted = true
        HapticManager.success()
        SoundManager.play(.reRack)
    }

    private func spin() {
        guard !isSpinning, !wedges.isEmpty else { return }
        spinTask?.cancel()
        isSpinning = true
        withAnimation(AppAnimation.smoothFade) { result = nil }

        // Ziel zuerst auslosen, Drehung daraus berechnen.
        let target = Int.random(in: 0..<wedges.count)
        let targetCenter = Double(target) * step + step / 2
        let current = rotation.truncatingRemainder(dividingBy: 360)
        var delta = (360 - targetCenter - current).truncatingRemainder(dividingBy: 360)
        if delta < 0 { delta += 360 }

        withAnimation(.easeOut(duration: Self.spinDuration)) {
            rotation += Self.fullTurns * 360 + delta
        }

        spinTask = Task { @MainActor in
            // Das Ticken wird langsamer, passend zum Auslaufen des Rades.
            var elapsed: Double = 0
            var interval: Double = 0.07

            while elapsed < Self.spinDuration, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                elapsed += interval
                interval *= 1.22
                HapticManager.lightImpact()
                SoundManager.play(.tap)
            }

            guard !Task.isCancelled else { return }
            withAnimation(AppAnimation.standard) {
                result = wedges[target]
                isSpinning = false
            }
            HapticManager.error()
            SoundManager.play(.bombe)
        }
    }
}

// MARK: - Eigene Felder

/// Der Editor fuer das eigene Rad.
///
/// Die Menge wird ausgewaehlt und nicht eingetippt: Eine Zahl im Satz
/// ignoriert die eingestellte Haerte stillschweigend (siehe `DrinkAmount`).
/// Deshalb gibt es hier eine feste Auswahl und kein Zahlenfeld.
private struct RouletteWedgeEditor: View {

    @Environment(\.dismiss) private var dismiss

    @State private var wedges: [RouletteWedge] = RouletteWedges.stored()
    @State private var label = ""
    @State private var text = ""
    @State private var cost: RouletteCost = .threeSips

    private var canAdd: Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && wedges.count < RouletteWedges.maximum
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdrop(glow: BeerStatsColor.error)

                FillingScrollView(alignment: .top) {
                    VStack(alignment: .leading, spacing: 20) {
                        form
                        liste
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Eigenes Rad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NEUES FELD")
                .font(.scaled(11, weight: .heavy, design: .rounded))
                .kerning(1.8)
                .foregroundStyle(BeerStatsColor.textSecondary)

            TextField("Kurz aufs Rad – z. B. „Chef“", text: $label)
                .textFieldStyle(.plain)
                .padding(14)
                .glassPanel(cornerRadius: 14)

            TextField("Der ganze Satz – z. B. „Der Gastgeber trinkt“", text: $text)
                .textFieldStyle(.plain)
                .padding(14)
                .glassPanel(cornerRadius: 14)

            Text("WIE VIEL")
                .font(.scaled(11, weight: .heavy, design: .rounded))
                .kerning(1.8)
                .foregroundStyle(BeerStatsColor.textSecondary)

            // Zwei Zeilen statt sechs Knoepfen nebeneinander: "Niemand
            // trinkt" passt nicht in ein Sechstel der Breite.
            ChoiceRow(
                options: [
                    ChoiceOption(value: RouletteCost.oneSip, title: "1"),
                    ChoiceOption(value: RouletteCost.twoSips, title: "2"),
                    ChoiceOption(value: RouletteCost.threeSips, title: "3"),
                    ChoiceOption(value: RouletteCost.fourSips, title: "4")
                ],
                selection: $cost,
                tint: BeerStatsColor.error
            )

            ChoiceRow(
                options: [
                    ChoiceOption(value: RouletteCost.shot, title: "Shot"),
                    ChoiceOption(value: RouletteCost.nothing, title: "Niemand")
                ],
                selection: $cost,
                tint: BeerStatsColor.error
            )

            Text("Zeigt später: „\(vorschau)“")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryButton(title: "Feld anlegen", systemImage: "plus") { anlegen() }
                .disabled(!canAdd)
                .opacity(canAdd ? 1 : 0.4)

            if wedges.count >= RouletteWedges.maximum {
                Text("Zehn Felder sind das Maximum – mehr ist auf dem Rad nicht mehr zu lesen.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Was nach der Drehung dastehen wird. Steht hier, damit niemand ein
    /// Feld anlegt und erst am Tisch merkt, dass der Satz nicht aufgeht.
    private var vorschau: String {
        let satz = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let beispiel = satz.isEmpty ? "Der Gastgeber trinkt" : satz
        return RouletteWedge(label: "", text: beispiel, cost: cost).resolved
    }

    @ViewBuilder
    private var liste: some View {
        if wedges.isEmpty {
            Text("Noch keine eigenen Felder. Ab \(RouletteWedges.minimum) lässt sich drehen.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("DEINE FELDER (\(wedges.count))")
                    .font(.scaled(11, weight: .heavy, design: .rounded))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                ForEach(wedges) { feld in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feld.label)
                                .font(BeerStatsFont.headline)
                                .foregroundStyle(BeerStatsColor.textPrimary)
                            Text(feld.resolved)
                                .font(BeerStatsFont.caption)
                                .foregroundStyle(BeerStatsColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Button {
                            RouletteWedges.remove(id: feld.id)
                            wedges = RouletteWedges.stored()
                            HapticManager.lightImpact()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(BeerStatsColor.textSecondary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassPanel(cornerRadius: 14)
                }
            }
        }
    }

    private func anlegen() {
        guard RouletteWedges.add(label: label, text: text, cost: cost) else { return }
        wedges = RouletteWedges.stored()
        label = ""
        text = ""
        HapticManager.success()
    }
}

// MARK: - Formen

/// Ein Tortenstück, gemessen ab oben und im Uhrzeigersinn.
private struct PieSlice: Shape {
    let index: Int
    let total: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let step = 360.0 / Double(max(total, 1))

        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(Double(index) * step - 90),
            endAngle: .degrees(Double(index + 1) * step - 90),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

/// Zeiger über dem Rad, Spitze nach unten.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
