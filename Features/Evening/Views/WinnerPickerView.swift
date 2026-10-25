//
//  WinnerPickerView.swift
//  BeerStats
//
//  „Wer hat gewonnen?" – für ein gespieltes Spiel im laufenden Abend.
//
//  Der Grund, warum es diesen Screen gibt: Die Partyspiele sind fast alle
//  **Verlierer-Spiele**. Schocken rechnet aus, wer alle Deckel hat, die
//  Bombe, wer draufsitzt, Mäxchen, wer gelogen hat. Keines davon weiss,
//  wer gewonnen hat – der Tisch weiss es.
//
//  Also wird es dort angetippt, wo der Abend ohnehin steht. Das ist nicht
//  der bequemste Weg (bequem waere es direkt nach dem Spiel), aber der
//  einzige, der fuer ALLE Spiele gilt und keines davon anfasst. Spiele,
//  die ihren Sieger selbst kennen – Beerpong, Zeitstrahl – melden ihn
//  weiterhin von allein; hier laesst er sich nur korrigieren.
//
//  Mehrere Namen sind erlaubt, weil ein Sieg zu zweit einer bleibt: Die
//  Punkte bekommen dann beide, nicht jeder die Haelfte. Ein geteilter Sieg
//  ist kein halber.
//

import SwiftUI

struct WinnerPickerView: View {

    let entry: EveningEntry
    let participants: [EveningParticipant]
    /// Wird mit den gewaehlten IDs aufgerufen – leer heisst: zuruecknehmen.
    let onPick: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdrop(glow: BeerStatsColor.warning)

                FillingScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        kopf

                        ForEach(participants) { person in
                            OptionRow(
                                emoji: person.emoji,
                                title: person.name,
                                isOn: selected.contains(person.id),
                                tint: BeerStatsColor.warning
                            ) {
                                toggle(person.id)
                            }
                        }

                        Text("Mehrere antippen, wenn zu zweit gewonnen wurde – die Punkte bekommen dann beide. Ein geteilter Sieg ist kein halber.")
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        PrimaryButton(title: "Übernehmen", systemImage: "checkmark") {
                            onPick(Array(selected))
                            dismiss()
                        }

                        if entry.winnerIds != nil {
                            QuietButton(title: "Sieger zurücknehmen") {
                                onPick([])
                                dismiss()
                            }
                        }
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Wer hat gewonnen?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
            }
        }
        .onAppear { selected = Set(entry.winnerIds ?? []) }
    }

    private var kopf: some View {
        HStack(spacing: 12) {
            Text(entry.emoji).font(.system(size: 30))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text(punkteHinweis)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassPanel(cornerRadius: 16)
    }

    /// Was dieser Sieg wert ist – damit vorher dasteht, worum gespielt
    /// wurde, und nicht erst in der Tabelle.
    private var punkteHinweis: String {
        let punkte = entry.gameId
            .flatMap(PartyGame.init(rawValue:))?
            .length.points ?? PartyGame.Length.round.points
        return "\(punkte) \(punkte == 1 ? "Punkt" : "Punkte") für den Pokal"
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }
}
