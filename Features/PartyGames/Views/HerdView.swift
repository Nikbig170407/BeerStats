//
//  HerdView.swift
//  BeerStats
//
//  Die Herde: Eine Frage, alle antworten gleichzeitig – wer allein
//  dasteht, trinkt.
//
//  Das Spiel fuer spaet am Abend. Es gibt nichts zu merken, nichts
//  weiterzureichen und nichts falsch zu machen: Die App stellt die Frage,
//  zaehlt herunter, und danach weiss die Runde selbst, wer in der
//  Mehrheit war. Genau dort hoert die App auch auf zu rechnen – sie kann
//  nicht hoeren, was gesagt wurde, und soll nicht so tun.
//
//  Angetippt wird deshalb nur, WER allein stand. Das ist eine Information,
//  die ohnehin ausgesprochen wird, und es ist die einzige, die in die
//  Trinkbilanz gehoert.
//
//  Die Kuh ist die Eskalation, die das Spiel braucht: Wer zweimal
//  hintereinander allein steht, zahlt mehr. Ohne sie kostet jede Runde
//  dasselbe, und nach einer halben Stunde zaehlt niemand mehr mit.
//

import SwiftUI

struct HerdView: View {

    private enum Phase: Equatable {
        case setup
        /// Die Frage steht, alle denken nach.
        case asking
        /// Wer stand allein?
        case picking
        case result(alone: [Int], cow: [Int])
    }

    @State private var phase: Phase = .setup
    @State private var playerCount = 5
    @State private var deck: [String] = []
    @State private var question = ""
    @State private var selected: Set<Int> = []
    /// Wer in der Runde davor allein stand – fuer die Kuh.
    @State private var previousAlone: Set<Int> = []
    @State private var round = 0

    private let penalty = DrinkAmount.sips(2)
    private let cowPenalty = DrinkAmount.shot

    @Environment(\.gameWorld) private var world

    var body: some View {
        Group {
            switch phase {
            case .setup: setupView
            case .asking: askingView
            case .picking: pickingView
            case .result(let alone, let cow): resultView(alone: alone, cow: cow)
            }
        }
        .navigationTitle("Die Herde")
        .navigationBarTitleDisplayMode(.inline)
        .roundSettings(for: .herd, isAvailable: phase != .setup)
        .onAppear(perform: adoptTableCount)
    }

    // MARK: - Vorbereitung

    private var setupView: some View {
        GameSetupScreen(
            emoji: "🐄",
            title: "Die Herde",
            subtitle: "Alle antworten gleichzeitig. Wer nicht in der Mehrheit ist, trinkt.",
            tint: BeerStatsColor.success,
            startTitle: "Erste Frage",
            onStart: start
        ) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("WIE VIELE SPIELT IHR?")
                        .font(.scaled(11, weight: .heavy, design: .rounded))
                        .kerning(1.6)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                    PlayerCountStepper(count: $playerCount, range: 3...PartyGame.manyPlayers, tint: BeerStatsColor.success)
                }

                Text("Die App liest die Frage vor, zählt herunter, und alle sagen ihre Antwort gleichzeitig. Danach tippt ihr an, wer allein dastand – und nur das. Wer zweimal hintereinander allein ist, bekommt die Kuh und zahlt mehr.")
                    .font(BeerStatsFont.body)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(HerdDeck.count) Fragen im Stapel.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                DrinkIntensityPicker(game: .herd)
            }
        }
    }

    // MARK: - Die Frage

    private var askingView: some View {
        screen {
            Text("Runde \(round)")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)

            Text(question)
                .font(Font.world(world, 32, weight: .heavy))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Auf drei sagen alle gleichzeitig ihre Antwort.")
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Die Herde rueckt zusammen – ein Schaf je Mitspieler
            HerdField(count: playerCount, alone: [], cows: [])
                .id(round)
        } buttons: {
            PrimaryButton(title: "Gesagt – wer stand allein?", systemImage: "arrow.right") {
                selected = []
                withAnimation(AppAnimation.standard) { phase = .picking }
                HapticManager.lightImpact()
            }

            QuietButton(title: "Andere Frage") { nextQuestion() }
        }
    }

    // MARK: - Wer stand allein?

    private var pickingView: some View {
        screen {
            Text("Wer war allein?")
                .font(Font.world(world, 28, weight: .heavy))
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Antippen, wer eine Antwort hatte, die sonst niemand hatte. Waren alle einer Meinung, tippt niemanden an.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(Array(0..<playerCount), id: \.self) { index in
                    playerChip(index)
                }
            }
        } buttons: {
            PrimaryButton(title: selected.isEmpty ? "Alle einig" : "Übernehmen", systemImage: "checkmark") {
                settle()
            }
        }
    }

    private func playerChip(_ index: Int) -> some View {
        let isOn = selected.contains(index)

        return Button {
            if isOn { selected.remove(index) } else { selected.insert(index) }
            HapticManager.lightImpact()
        } label: {
            HStack(spacing: 8) {
                // Die Kuh steht neben dem, der sie bekommen kann – sonst
                // faellt die Verschaerfung erst auf, wenn sie zuschlaegt.
                if previousAlone.contains(index) { Text("🐄") }

                Text(PlayerNames.name(for: index))
                    .font(BeerStatsFont.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isOn ? BeerStatsColor.textOnAccent : BeerStatsColor.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isOn ? BeerStatsColor.error : BeerStatsColor.surfaceElevated.opacity(0.6),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Auflösung

    private func resultView(alone: [Int], cow: [Int]) -> some View {
        screen {
            // Wer allein stand, trottet an den Rand; wer zweimal allein
            // stand, ist jetzt eine Kuh mit Glocke
            HerdField(
                count: playerCount,
                alone: Set(alone),
                cows: Set(cow),
                names: Dictionary(uniqueKeysWithValues: alone.map { ($0, PlayerNames.plainName(for: $0)) }),
                startsGathered: true
            )
            .id("ergebnis-\(round)")

            if alone.isEmpty {
                Text("Alle einer Meinung")
                    .font(Font.world(world, 28, weight: .heavy))
                    .foregroundStyle(BeerStatsColor.success)
                    .multilineTextAlignment(.center)

                Text("Niemand trinkt. Die Herde steht.")
                    .font(BeerStatsFont.body)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(namesText(alone))
                    .font(Font.world(world, 28, weight: .heavy))
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("trinkt \(penalty.text)")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.error)

                if !cow.isEmpty {
                    Text("🐄 \(namesText(cow)) \(cow.count == 1 ? "steht" : "stehen") zum zweiten Mal allein – \(cowPenalty.text) statt der Schlücke.")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.warning)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } buttons: {
            PrimaryButton(title: "Nächste Frage", systemImage: "arrow.right") { nextQuestion() }
        }
    }

    private func namesText(_ indices: [Int]) -> String {
        let namen = indices.sorted().map { PlayerNames.name(for: $0) }
        guard namen.count > 1 else { return namen.first ?? "" }
        return namen.dropLast().joined(separator: ", ") + " & " + (namen.last ?? "")
    }

    /// Inhalt mittig, Knoepfe unten. Heisst bewusst nicht `frame` –
    /// SwiftUI hat einen Modifier dieses Namens, und zwei gleich benannte
    /// Dinge in derselben Ansicht sind eine Einladung an den Compiler,
    /// sich das falsche auszusuchen.
    private func screen<Content: View, Buttons: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder buttons: () -> Buttons
    ) -> some View {
        // Die beiden Closures werden HIER ausgewertet und nicht erst im
        // GeometryReader: Der ist escaping, und ein nicht-escaping
        // ViewBuilder darf dort nicht hinein. Fertige Ansichten sind
        // dagegen Werte und duerfen ueberall mit.
        let inhalt = content()
        let knoepfe = buttons()

        return ZStack {
            AmbientBackdrop(glow: BeerStatsColor.success)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 16) {
                        Spacer(minLength: 0)
                        inhalt
                        Spacer(minLength: 0)
                        knoepfe
                    }
                    .padding(24)
                    .frame(minHeight: geometry.size.height)
                }
                .verticalScrollOnly()
            }
        }
    }

    // MARK: - Ablauf

    private func adoptTableCount() {
        guard phase == .setup, let vorschlag = PlayerNames.suggestedCount(atLeast: 3) else { return }
        playerCount = min(vorschlag, PartyGame.manyPlayers)
    }

    private func start() {
        deck = HerdDeck.shuffled()
        previousAlone = []
        round = 0
        nextQuestion()
        HapticManager.success()
    }

    private func nextQuestion() {
        if deck.isEmpty { deck = HerdDeck.shuffled() }
        question = deck.popLast() ?? HerdDeck.all[0]
        round += 1
        withAnimation(AppAnimation.standard) { phase = .asking }
    }

    private func settle() {
        let allein = selected.sorted()
        // Die Kuh trifft nur, wer schon in der Runde davor allein stand.
        let kuh = allein.filter { previousAlone.contains($0) }

        for index in allein {
            EveningLog.record(kuh.contains(index) ? cowPenalty : penalty, forPlayer: index)
        }

        previousAlone = Set(allein)

        withAnimation(AppAnimation.standard) { phase = .result(alone: allein, cow: kuh) }

        if allein.isEmpty {
            HapticManager.success()
            SoundManager.play(.victory)
        } else {
            HapticManager.error()
            SoundManager.play(kuh.isEmpty ? .miss : .bombe)
        }
    }
}
