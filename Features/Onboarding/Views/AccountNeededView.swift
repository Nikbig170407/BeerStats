//
//  AccountNeededView.swift
//  BeerStats
//
//  Was ohne Konto nicht geht – und warum.
//
//  Steht hinter der Beerpong-Kachel, wenn ohne Konto gespielt wird. Die
//  Kachel bleibt dabei absichtlich stehen: Sie wegzulassen hiesse, dass
//  niemand sieht, dass die App ueberhaupt Beerpong kann – und das ist der
//  Grund, warum es sie gibt.
//
//  Der Ton ist Erklaerung, nicht Werbung. Wer hier landet, hat gerade auf
//  etwas getippt, das nicht geht; was er braucht, ist der Grund und der Weg,
//  nicht eine Anpreisung.
//

import SwiftUI

struct AccountNeededView: View {

    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.accent)

            FillingScrollView {
                VStack(spacing: 20) {
                    Text("🍺").font(.system(size: 64))

                    Text("Beerpong braucht ein Konto")
                        .font(BeerStatsFont.title)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(GuestMode.explanation)
                        .font(BeerStatsFont.body)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 12) {
                        zeile("👥", "Mitspieler-Profile", "Mit Emoji, Farbe und allem, was sie je geworfen haben")
                        zeile("📊", "Statistiken", "Trefferquote, Serien, bester Partner, schlimmster Gegner")
                        zeile("📜", "Spielverlauf", "Jede Partie Wurf für Wurf – auch auf einem neuen Handy")
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassPanel(cornerRadius: 20)

                    PrimaryButton(title: "Konto anlegen oder anmelden", systemImage: "person.crop.circle") {
                        appState.leaveGuestMode()
                    }

                    Text("Was du bisher gespielt hast, bleibt: Abend, Trinkbilanz und eigene Karten liegen auf dem Gerät und hängen nicht am Konto.")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
            }
        }
        .navigationTitle("Beerpong")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func zeile(_ emoji: String, _ titel: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji).font(.system(size: 22))

            VStack(alignment: .leading, spacing: 2) {
                Text(titel)
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text(text)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
