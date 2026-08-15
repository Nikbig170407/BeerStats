//
//  HouseRulesView.swift
//  BeerStats
//
//  Die Sonderregeln an- und abschalten.
//
//  Liegt hinter einer Zeile im Neues-Spiel-Screen und nicht darin: Die
//  Hausregeln werden einmal eingestellt und dann monatelang nicht mehr
//  angefasst. Sechs Schalter dauerhaft ueber der Aufstellung waeren sechs
//  Zeilen Weg zu der Entscheidung, die man tatsaechlich jedes Mal trifft –
//  wer mitspielt.
//
//  Was hier umgestellt wird, gilt ab der naechsten Partie. Eine laufende
//  aendert sich nicht: Ihr Regelwerk steht in ihrem eigenen Dokument, und
//  der Wurf-Log wird damit nachgespielt. Regeln mitten im Spiel zu wechseln
//  hiesse, dass derselbe Log vor und nach der Aenderung zwei verschiedene
//  Spielstaende ergibt.
//

import SwiftUI

struct HouseRulesView: View {

    @Binding var format: GameFormat
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    ForEach(HouseRule.allCases) { rule in
                        ruleRow(rule)
                    }

                    // Nur sichtbar, solange die Regel ueberhaupt gilt – eine
                    // Schwelle fuer eine abgeschaltete Regel einzustellen
                    // waere eine Einstellung ohne Wirkung.
                    if format.onFireEnabled {
                        onFireThreshold
                    }

                    if !format.isStandardRuleset {
                        resetButton
                    }

                    footer
                }
                .padding(20)
            }
            .background(GridBackdrop(glow: BeerStatsColor.accent))
            .navigationTitle("Hausregeln")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.accent)
                }
            }
        }
    }

    // MARK: - Bausteine

    private var header: some View {
        Text("Was hier aus ist, gibt es in eurer Partie nicht – die App bietet es dann gar nicht erst an und erklaert es auch nicht mehr in den Regeln.")
            .font(BeerStatsFont.caption)
            .foregroundStyle(BeerStatsColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func ruleRow(_ rule: HouseRule) -> some View {
        let isOn = format[keyPath: rule.keyPath]

        return Toggle(isOn: binding(for: rule)) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 9) {
                    Text(rule.emoji).font(.system(size: 20))
                    Text(rule.title)
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                }
                Text(rule.detail)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(BeerStatsColor.accent)
        .padding(14)
        .glassPanel(cornerRadius: 16)
        .neonEdge(BeerStatsColor.accent, cornerRadius: 16, intensity: isOn ? 0.35 : 0.1)
        .animation(AppAnimation.standard, value: isOn)
    }

    /// Schreibt den Schalter zurueck und gibt dabei Rueckmeldung. Ein
    /// eigenes Binding, weil `didSet` an einem `@Binding` nicht existiert.
    private func binding(for rule: HouseRule) -> Binding<Bool> {
        Binding(
            get: { format[keyPath: rule.keyPath] },
            set: { neu in
                format[keyPath: rule.keyPath] = neu
                HapticManager.lightImpact()
            }
        )
    }

    private var onFireThreshold: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TREFFER IN FOLGE FÜR ON FIRE")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .kerning(1.6)
                .foregroundStyle(BeerStatsColor.textSecondary)

            // Dieselbe Komponente wie bei den Partyspielen. Sie heisst nach
            // ihrem ersten Einsatzzweck, kann aber jede kleine Zahl – und
            // ihre grossen Trefferflaechen sind hier genauso richtig.
            PlayerCountStepper(
                count: $format.onFireStreakThreshold,
                range: AppConstants.GameDefaults.onFireStreakRange,
                tint: BeerStatsColor.warning
            )
            .frame(maxWidth: .infinity)

            Text("Ab dem \(format.onFireStreakThreshold). Treffer in Folge behaelt derselbe Spieler den Ball.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassPanel(cornerRadius: 16)
    }

    private var resetButton: some View {
        Button {
            withAnimation(AppAnimation.standard) {
                // Die Becherzahl bleibt: Sie steht im Screen davor und ist
                // keine Sonderregel, die man hier "zuruecksetzt".
                let becher = format.cupCount
                format = GameFormat()
                format.cupCount = becher
            }
            HapticManager.success()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.counterclockwise")
                Text("Auf Standard zurücksetzen")
                    .font(BeerStatsFont.headline)
                Spacer()
            }
            .foregroundStyle(BeerStatsColor.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassPanel(cornerRadius: 15)
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var footer: some View {
        Text("Gilt ab der nächsten Partie und bleibt gespeichert. Laufende Spiele behalten die Regeln, mit denen sie gestartet sind.")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(BeerStatsColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }
}
