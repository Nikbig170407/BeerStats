//
//  DrinkIntensityPicker.swift
//  BeerStats
//
//  Die Haerte-Wahl als eigene Komponente.
//
//  Sie stand bis Oktober 2026 EINMAL ueber den Partyspielen im Hauptmenue
//  und galt fuer alle. Das klang sparsam ("derselbe Schalter nicht an
//  sechzehn Stellen") und war am Tisch falsch: Mäxchen wird anders
//  getrunken als Trink-Roulette, und wer umstellen wollte, musste raus aus
//  dem Spiel, eine Ebene hoch, umstellen und wieder rein. Eine Einstellung,
//  die man nur weit weg vom Spiel erreicht, wird nicht benutzt.
//
//  Jetzt steht dieselbe Komponente im Vorspann jedes Spiels, das Mengen
//  ausspricht – und einmal in den Einstellungen. Dort ohne Spiel: Das ist
//  die Vorgabe, mit der ein Spiel anfaengt, das noch nie eingestellt wurde.
//

import SwiftUI

struct DrinkIntensityPicker: View {

    /// Das Spiel, dessen Haerte hier eingestellt wird – oder `nil` fuer die
    /// Vorgabe. Zwei Bedeutungen in einem Baustein, weil die Zeile dieselbe
    /// ist: drei Knoepfe und ein Satz dazu.
    let game: PartyGame?

    /// Eigener Zustand, weil die Haerte in UserDefaults liegt und SwiftUI
    /// Aenderungen dort nicht von sich aus bemerkt.
    @State private var selection: DrinkIntensity

    init(game: PartyGame? = nil) {
        self.game = game
        if let game {
            _selection = State(initialValue: DrinkIntensity.stored(for: game))
        } else {
            _selection = State(initialValue: DrinkIntensity.standard)
        }
    }

    private var label: String {
        game == nil ? "HÄRTE – VORGABE FÜR NEUE SPIELE" : "HÄRTE"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.scaled(11, weight: .heavy, design: .rounded))
                .kerning(1.8)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(DrinkIntensity.allCases) { intensity in
                    option(intensity)
                }
            }

            Text(detail)
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .animation(AppAnimation.standard, value: selection)
        }
    }

    private var detail: String {
        guard game != nil else {
            return "\(selection.subtitle). Gilt für Spiele, bei denen du nichts anderes eingestellt hast."
        }
        return "\(selection.subtitle). Gilt nur für dieses Spiel und bleibt gespeichert."
    }

    private func option(_ intensity: DrinkIntensity) -> some View {
        let isOn = selection == intensity

        return Button {
            selection = intensity
            if let game {
                DrinkIntensity.store(intensity, for: game)
                // Sofort gueltig, nicht erst beim naechsten Start: Die
                // Mengen werden beim Anzeigen ausformuliert, und der
                // Vorspann liegt vor dem ersten davon.
                DrinkIntensity.current = intensity
            } else {
                DrinkIntensity.standard = intensity
            }
            HapticManager.lightImpact()
            SoundManager.play(.tap)
        } label: {
            VStack(spacing: 3) {
                Text(intensity.emoji).font(.system(size: 20))
                Text(intensity.title)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(isOn ? BeerStatsColor.textOnAccent : BeerStatsColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isOn ? BeerStatsColor.accent : BeerStatsColor.surfaceElevated.opacity(0.6),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
