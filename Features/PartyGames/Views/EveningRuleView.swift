//
//  EveningRuleView.swift
//  BeerStats
//
//  Regel des Abends: eine Karte, die ab jetzt fuer alle gilt.
//
//  Das zweite Spiel, das NEBEN allen anderen laeuft – und das einzige, das
//  sich dabei etwas merken muss. Verbotene Woerter verteilt einmal und ist
//  fertig; hier kommt alle paar Runden eine Regel dazu, und die alten
//  gelten weiter. Deshalb liegen die geltenden Regeln in UserDefaults
//  (`ActiveEveningRules`) und nicht im `@State`: Wer eine Regel zieht,
//  weiterspielt und spaeter wiederkommt, findet sie noch vor. Am Tisch galt
//  sie ja auch die ganze Zeit.
//
//  Die Regeln STAPELN sich bewusst. Eine Regel allein ist eine Marotte –
//  drei gleichzeitig sind der Abend. Dass man dabei den Ueberblick
//  verliert, ist Teil des Spiels und zugleich der Grund, warum jede Regel
//  einzeln aufgehoben werden kann: Was keiner mehr befolgt, soll
//  verschwinden, statt die Liste zu verstopfen.
//
//  Eine Strafe fuer alle Regeln, nicht eine je Karte. Am Tisch ist der Satz
//  "wer die Regel bricht, trinkt" einer, den sich jeder merkt; haette jede
//  Karte ihren eigenen Preis, muesste man bei jedem Verstoss nachschlagen.
//  Nebenbei macht es die Sicherung einfach: gespeichert wird der Text, und
//  der Preis steht hier.
//

import SwiftUI

struct EveningRuleView: View {

    private enum Phase: Equatable { case setup, running }

    @State private var phase: Phase = .setup
    @State private var rules: [String] = []

    private let penalty = DrinkAmount.sips(2)

    @Environment(\.gameWorld) private var world

    private var current: String? { rules.first }
    private var older: [String] { Array(rules.dropFirst()) }

    var body: some View {
        Group {
            switch phase {
            case .setup: setupView
            case .running: runningView
            }
        }
        .navigationTitle("Regel des Abends")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: restore)
    }

    // MARK: - Vorbereitung

    private var setupView: some View {
        GameSetupScreen(
            emoji: "📜",
            title: "Regel des Abends",
            subtitle: "Eine Regel gilt ab dem Ziehen für alle – bis ihr sie aufhebt.",
            tint: BeerStatsColor.accentSecondary,
            startTitle: "Erste Regel ziehen",
            onStart: drawRule
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("SO LÄUFT ES")
                    .font(.scaled(11, weight: .heavy, design: .rounded))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                Text("Ihr zieht eine Regel und legt das Handy weg. Wer sie bricht, trinkt \(penalty.text) – das entscheidet die Runde, nicht die App. Wenn es langweilig wird, zieht ihr die nächste; die alten gelten weiter.")
                    .font(BeerStatsFont.body)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(EveningRuleDeck.count) Regeln im Stapel. Gezogen wird nur, was noch nicht gilt.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                DrinkIntensityPicker(game: .eveningRule)
            }
        }
    }

    // MARK: - Es gilt

    private var runningView: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.accentSecondary)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 16) {
                        currentCard

                        if !older.isEmpty { olderSection }

                        Spacer(minLength: 8)

                        PrimaryButton(title: "Nächste Regel ziehen", systemImage: "plus.circle.fill") {
                            drawRule()
                        }

                        QuietButton(title: "Alle Regeln aufheben") { clearAll() }
                    }
                    .padding(22)
                    .frame(minHeight: geometry.size.height)
                }
                .verticalScrollOnly()
            }
        }
    }

    /// Die zuletzt gezogene Regel als Erlass: Das Pergament entrollt sich,
    /// dann wird es versiegelt. Jede neue Regel ist ein neues Pergament
    /// (`id`), deshalb entrollt jede sich neu.
    private var currentCard: some View {
        Parchment {
            Text("ERLASS")
                .font(Font.world(world, 16, weight: .bold))
                .kerning(5)
                .foregroundStyle(Decree.red)

            Text("Ab sofort gilt für alle:")
                .font(Font.world(world, 15, weight: .regular).italic())
                .foregroundStyle(Decree.inkSoft)

            Text(current ?? "–")
                .font(Font.world(world, 26, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6)

            Text("Wer sie bricht, trinkt \(penalty.text).")
                .font(Font.world(world, 15, weight: .regular).italic())
                .foregroundStyle(Decree.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            WaxSeal()
                .padding(.top, 4)
        }
        .id(current)
    }

    private var olderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AUCH NOCH IN KRAFT")
                    .font(Font.world(world, 13, weight: .bold))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                Spacer(minLength: 0)

                // Ab der fuenften Regel merkt sich niemand mehr alles. Die
                // App sagt es, statt die Runde raten zu lassen, ob sie
                // gerade zu dumm oder zu betrunken ist.
                if rules.count >= 5 {
                    Text("das sind viele")
                        .font(.scaled(11, weight: .bold, design: .rounded))
                        .foregroundStyle(BeerStatsColor.warning)
                }
            }

            ForEach(older, id: \.self) { rule in
                olderRow(rule)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Aeltere Regeln als schmale Pergamentstreifen mit kleinem Siegel.
    private func olderRow(_ rule: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(Decree.seal)
                .frame(width: 14, height: 14)
                .accessibilityHidden(true)

            Text(rule)
                .font(Font.world(world, 15, weight: .regular).italic())
                .foregroundStyle(Decree.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                retire(rule)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Decree.inkSoft.opacity(0.7))
                    // Nr. 4 und Nr. 12 der Lessons Learned: Ein Symbol von
                    // achtzehn Punkten ist keine Trefferflaeche.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Regel aufheben")
        }
        .padding(.leading, 14)
        .padding(.vertical, 2)
        .background(
            LinearGradient(colors: [Decree.rollerLight, Decree.parchment], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
    }

    // MARK: - Ablauf

    /// Beim Erscheinen gilt, was gespeichert ist – nicht der Vorspann.
    ///
    /// Sonst stuende nach dem Zurueckkommen wieder "Erste Regel ziehen"
    /// ueber einem Tisch, an dem laengst drei Regeln gelten.
    private func restore() {
        rules = ActiveEveningRules.all
        phase = rules.isEmpty ? .setup : .running
    }

    private func drawRule() {
        guard let neu = EveningRuleDeck.draw(excluding: rules) else { return }
        ActiveEveningRules.add(neu)
        withAnimation(AppAnimation.standard) {
            rules = ActiveEveningRules.all
            phase = .running
        }
        HapticManager.success()
        SoundManager.play(.cardFlip)
    }

    private func retire(_ rule: String) {
        ActiveEveningRules.remove(rule)
        withAnimation(AppAnimation.standard) { rules = ActiveEveningRules.all }
        HapticManager.lightImpact()
    }

    private func clearAll() {
        ActiveEveningRules.clear()
        withAnimation(AppAnimation.standard) {
            rules = []
            phase = .setup
        }
        HapticManager.mediumImpact()
    }
}
