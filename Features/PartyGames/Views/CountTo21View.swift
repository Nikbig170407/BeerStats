//
//  CountTo21View.swift
//  BeerStats
//
//  21: Reihum wird von 1 bis 21 gezaehlt. Wer 21 sagt, trinkt und ersetzt
//  eine Zahl durch eine eigene Regel. Danach geht es von vorne los – mit
//  einer Regel mehr.
//
//  Gezaehlt wird laut am Tisch, nicht in der App. Der Reiz ist ja gerade,
//  dass man sich verhaspelt; ein Knopf, der die Zahl hochzaehlt, waere das
//  Gegenteil davon.
//
//  Was die App uebernimmt, ist das Einzige, was am Tisch wirklich schwerfaellt:
//  sich zu merken, was aus der 4 geworden ist, nachdem die 7 schon geklatscht
//  und die 12 rueckwaerts gesagt wird. Nach der fuenften Regel weiss das
//  niemand mehr – und genau dann faengt das Spiel an, Spass zu machen.
//

import SwiftUI

struct CountTo21View: View {

    /// Regeln je Zahl. Was nicht drinsteht, wird normal gesagt.
    @State private var rules: [Int: String] = [:]
    @State private var editingNumber: Int?
    @State private var draft = ""

    private let mistakePenalty = DrinkAmount.sips(2)
    private let finishPenalty = DrinkAmount.sips(3)

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.accent)

            ScrollView {
                VStack(spacing: 18) {
                    header
                    numberGrid
                    penaltyButtons
                    if !rules.isEmpty { ruleList }
                }
                .padding(20)
            }
        }
        .navigationTitle("21")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding(
            get: { editingNumber.map { EditTarget(number: $0) } },
            set: { if $0 == nil { editingNumber = nil } }
        )) { target in
            ruleEditor(for: target.number)
        }
    }

    /// Kleiner Umweg, weil `sheet(item:)` etwas Identifizierbares braucht und
    /// ein blanker Int das nicht ist.
    private struct EditTarget: Identifiable {
        let number: Int
        var id: Int { number }
    }

    // MARK: - Kopf

    private var header: some View {
        VStack(spacing: 6) {
            Text("Reihum von 1 bis 21 zählen")
                .font(BeerStatsFont.headline)
                .foregroundStyle(BeerStatsColor.textPrimary)
            Text("Wer 21 sagt, trinkt und ersetzt eine Zahl durch eine eigene Regel. Dann von vorne.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassPanel(cornerRadius: 18)
    }

    // MARK: - Zahlen

    private var numberGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...21, id: \.self) { number in
                numberTile(number)
            }
        }
    }

    private func numberTile(_ number: Int) -> some View {
        let rule = rules[number]
        let isFinal = number == 21

        return Button {
            draft = rule ?? ""
            editingNumber = number
            HapticManager.lightImpact()
        } label: {
            VStack(spacing: 2) {
                Text("\(number)")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(tileColor(hasRule: rule != nil, isFinal: isFinal))
                if let rule {
                    Text(rule)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .padding(.horizontal, 4)
            .glassPanel(cornerRadius: 12)
            .neonEdge(
                tileColor(hasRule: rule != nil, isFinal: isFinal),
                cornerRadius: 12,
                intensity: rule != nil ? 0.7 : (isFinal ? 0.5 : 0.12)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func tileColor(hasRule: Bool, isFinal: Bool) -> Color {
        if hasRule { return BeerStatsColor.accent }
        if isFinal { return BeerStatsColor.error }
        return BeerStatsColor.textSecondary
    }

    // MARK: - Strafen

    private var penaltyButtons: some View {
        VStack(spacing: 10) {
            penaltyButton(
                title: "Vertan",
                detail: "trinkt \(mistakePenalty.text)",
                tint: BeerStatsColor.error,
                sound: .miss
            )
            penaltyButton(
                title: "21 erreicht",
                detail: "trinkt \(finishPenalty.text), dann Zahl antippen und Regel schreiben",
                tint: BeerStatsColor.accent,
                sound: .victory
            )
        }
    }

    private func penaltyButton(title: String, detail: String, tint: Color, sound: GameSound) -> some View {
        Button {
            HapticManager.error()
            SoundManager.play(sound)
        } label: {
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                Text(detail)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassPanel(cornerRadius: 18)
            .neonEdge(tint, cornerRadius: 18, intensity: 0.55)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Regelliste

    private var ruleList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AKTIVE REGELN")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .kerning(1.8)
                .foregroundStyle(BeerStatsColor.textSecondary)

            ForEach(rules.keys.sorted(), id: \.self) { number in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(number)")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(BeerStatsColor.accent)
                        .frame(minWidth: 26, alignment: .leading)
                    Text(rules[number] ?? "")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button {
                        rules[number] = nil
                        HapticManager.lightImpact()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(BeerStatsColor.textSecondary)
                    }
                }
            }

            Button("Alle Regeln löschen") {
                rules.removeAll()
                HapticManager.success()
            }
            .font(BeerStatsFont.caption)
            .foregroundStyle(BeerStatsColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassPanel(cornerRadius: 18)
    }

    // MARK: - Regel schreiben

    private func ruleEditor(for number: Int) -> some View {
        VStack(spacing: 18) {
            Text("\(number)")
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.accent)

            Text("Was passiert statt der Zahl?")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)

            TextField("z. B. klatschen statt sagen", text: $draft)
                .textFieldStyle(.plain)
                .padding(14)
                .glassPanel(cornerRadius: 14)
                .submitLabel(.done)
                .onSubmit { saveRule(for: number) }

            PrimaryButton(title: "Regel merken", systemImage: "checkmark") { saveRule(for: number) }
                .disabled(trimmedDraft.isEmpty)
                .opacity(trimmedDraft.isEmpty ? 0.4 : 1)

            if rules[number] != nil {
                Button("Regel löschen") {
                    rules[number] = nil
                    editingNumber = nil
                    HapticManager.lightImpact()
                }
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.error)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveRule(for number: Int) {
        let text = trimmedDraft
        guard !text.isEmpty else { return }
        rules[number] = text
        editingNumber = nil
        HapticManager.success()
        SoundManager.play(.reRack)
    }
}
