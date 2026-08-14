//
//  CustomCardsView.swift
//  BeerStats
//
//  Eigene Karten eintippen, ansehen, wieder loeschen.
//
//  Ein Screen fuer alle Stapel statt drei fast gleiche – dieselbe
//  Entscheidung wie beim Zaehler und beim Weitergabe-Ablauf. Was sich nur im
//  Titel unterscheidet, gehoert nicht dreimal ins Projekt.
//
//  Das Beispiel im Eingabefeld ist kein Beiwerk: Bei "Ich hab noch nie"
//  tippt man ohne Vorlage den Nachsatz statt des ganzen Satzes, und die
//  Karte passt dann grammatisch nicht zum Rest des Stapels. Genau daran ist
//  der Stapel schon einmal gescheitert.
//

import SwiftUI

struct CustomCardsView: View {

    @State private var deck: CustomCardDeck = .neverHaveIEver
    @State private var entwurf = ""
    @State private var karten: [String] = []

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.accentSecondary)

            ScrollView {
                VStack(spacing: 18) {
                    header
                    deckPicker
                    eingabe

                    if karten.isEmpty {
                        Text("Noch keine eigenen Karten in diesem Stapel.")
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                            .padding(.top, 8)
                    } else {
                        liste
                    }
                }
                .padding(22)
            }
        }
        .navigationTitle("Eigene Karten")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { karten = CustomCards.cards(for: deck) }
    }

    // MARK: - Bausteine

    private var header: some View {
        VStack(spacing: 8) {
            Text("✍️").font(.system(size: 48))

            Text("Eure Karten")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Werden unter die vorhandenen gemischt, nicht vorne angestellt – so tauchen sie über den Abend verteilt auf.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var deckPicker: some View {
        HStack(spacing: 8) {
            ForEach(CustomCardDeck.allCases) { kandidat in
                Button {
                    deck = kandidat
                    karten = CustomCards.cards(for: kandidat)
                    entwurf = ""
                    HapticManager.lightImpact()
                } label: {
                    VStack(spacing: 3) {
                        Text(kandidat.emoji).font(.system(size: 20))
                        Text(kandidat.title)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(
                        deck == kandidat ? BeerStatsColor.textOnAccent : BeerStatsColor.textSecondary
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        deck == kandidat
                            ? BeerStatsColor.accentSecondary
                            : BeerStatsColor.surfaceElevated.opacity(0.6),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private var eingabe: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(deck.placeholder, text: $entwurf, axis: .vertical)
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .lineLimit(1...4)
                .padding(14)
                .glassPanel(cornerRadius: 15)

            Text(deck.hint)
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryButton(title: "Karte hinzufügen", systemImage: "plus") {
                CustomCards.add(entwurf, to: deck)
                karten = CustomCards.cards(for: deck)
                entwurf = ""
                HapticManager.success()
                SoundManager.play(.tap)
            }
            .disabled(entwurf.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(entwurf.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
    }

    private var liste: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(karten.count) EIGENE \(karten.count == 1 ? "KARTE" : "KARTEN")")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .kerning(1.6)
                .foregroundStyle(BeerStatsColor.textSecondary)

            ForEach(karten, id: \.self) { karte in
                HStack(alignment: .top, spacing: 10) {
                    Text(karte)
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 4)

                    Button {
                        CustomCards.remove(karte, from: deck)
                        karten = CustomCards.cards(for: deck)
                        HapticManager.lightImpact()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(BeerStatsColor.error)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassPanel(cornerRadius: 14)
            }
        }
    }
}
