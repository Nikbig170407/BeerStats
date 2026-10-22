//
//  BingoHandoutView.swift
//  BeerStats
//
//  Blätter verteilen: für jeden ein eigenes, als Bild aufs eigene Handy.
//
//  Das Trinkbingo lag bisher als EIN Blatt in der Tischmitte, und das ist
//  fuer das Spiel am Tisch auch weiterhin richtig – siehe den Kommentar in
//  `DrinkBingoView`. Was fehlte, war der andere Weg: Jeder bekommt sein
//  eigenes Blatt, und ab da laeuft das Spiel den ganzen Abend auf sieben
//  Handys, ohne dass eines davon die App braucht.
//
//  **Jedes Blatt ist anders gemischt.** Mit demselben Blatt haetten alle
//  gleichzeitig Bingo, und das Spiel waere eine gemeinsame Strichliste.
//
//  Verschickt wird ueber das Teilen-Blatt des Systems: Darin stehen
//  WhatsApp, AirDrop, Signal, Mail und was sonst installiert ist. Eine
//  eigene Wahl ("WhatsApp-Knopf") waere eine Vermutung darueber, was die
//  Runde benutzt – das weiss das System besser.
//
//  Alle Blaetter auf einmal in den Gruppenchat ist der schnellere Weg:
//  Jedes traegt den Namen gross oben, also findet jeder seines. Einzeln
//  geht trotzdem, fuer AirDrop an den, der neben einem sitzt.
//

import SwiftUI

struct BingoHandoutView: View {

    /// Ein fertiges Blatt samt Bilddatei.
    private struct Sheet: Identifiable {
        let id = UUID()
        let owner: String
        let url: URL
    }

    let spotPenalty: String
    let bingoReward: String

    @Environment(\.dismiss) private var dismiss

    @State private var playerCount = 5
    @State private var sheets: [Sheet] = []
    @State private var isRendering = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdrop(glow: BeerStatsColor.success)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        intro

                        if sheets.isEmpty {
                            setup
                        } else {
                            result
                        }
                    }
                    .padding(22)
                }
                .verticalScrollOnly()
            }
            .navigationTitle("Blätter verteilen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.success)
                }
            }
        }
        .onAppear(perform: adoptTableCount)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Jeder bekommt ein eigenes Blatt – anders gemischt, mit seinem Namen darauf. Als Bild, damit es auf jedem Handy ankommt, auch ohne diese App.")
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Abgehakt wird dann im Kopf oder per Screenshot. Antippen geht nur auf dem Blatt in der Tischmitte.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassPanel(cornerRadius: 18)
    }

    // MARK: - Vorbereitung

    private var setup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FÜR WIE VIELE?")
                .font(.scaled(11, weight: .heavy, design: .rounded))
                .kerning(1.6)
                .foregroundStyle(BeerStatsColor.textSecondary)

            PlayerCountStepper(count: $playerCount, range: 2...PartyGame.manyPlayers, tint: BeerStatsColor.success)

            if !PlayerNames.knowsNames {
                // Ohne Abend und ohne Aufstellung stuende "Spieler 3" auf
                // einem Bild in einer Gruppe – das hilft niemandem beim
                // Zuordnen. Dann heissen die Blaetter lieber nach ihrer
                // Nummer, und wer welches nimmt, klaert die Runde.
                Text("Es steht noch niemand am Tisch – die Blätter heißen dann „Blatt 1“ bis „Blatt \(playerCount)“. Wer heute dabei ist, stellst du im Hauptmenü über das Personen-Symbol ein.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if failed {
                Text("Die Bilder ließen sich nicht erzeugen. Probier es noch einmal.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.error)
            }

            PrimaryButton(
                title: isRendering ? "Einen Moment …" : "\(playerCount) Blätter erzeugen",
                systemImage: "square.grid.2x2"
            ) {
                render()
            }
            .opacity(isRendering ? 0.5 : 1)
            .disabled(isRendering)
        }
    }

    // MARK: - Fertige Blätter

    private var result: some View {
        VStack(alignment: .leading, spacing: 14) {
            ShareLink(items: sheets.map(\.url)) {
                HStack(spacing: 10) {
                    Image(systemName: "paperplane.fill")
                    Text("Alle \(sheets.count) Blätter teilen")
                        .font(BeerStatsFont.headline)
                }
                .foregroundStyle(BeerStatsColor.textOnAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(BeerStatsColor.success, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Text("In den Gruppenchat schicken ist am schnellsten – auf jedem Blatt steht oben, wem es gehört.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("EINZELN")
                .font(.scaled(11, weight: .heavy, design: .rounded))
                .kerning(1.6)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .padding(.top, 4)

            ForEach(sheets) { blatt in
                ShareLink(item: blatt.url) {
                    HStack(spacing: 12) {
                        Text(blatt.owner)
                            .font(BeerStatsFont.headline)
                            .foregroundStyle(BeerStatsColor.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(BeerStatsColor.success)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .glassPanel(cornerRadius: 14)
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            QuietButton(title: "Neu mischen") {
                sheets = []
                render()
            }
        }
    }

    // MARK: - Ablauf

    private func adoptTableCount() {
        guard sheets.isEmpty, let vorschlag = PlayerNames.suggestedCount() else { return }
        playerCount = min(vorschlag, PartyGame.manyPlayers)
    }

    /// Erzeugt die Bilder.
    ///
    /// In einem `Task { @MainActor … }`, weil `ImageRenderer` main-actor-
    /// isoliert ist und aus einer Ansichts-Eigenschaft heraus gar nicht
    /// aufrufbar waere – dieselbe Stelle wie beim Ergebnis-Bild.
    private func render() {
        guard !isRendering else { return }
        isRendering = true
        failed = false

        Task { @MainActor in
            var erzeugt: [Sheet] = []

            for index in 0..<playerCount {
                let name = PlayerNames.knowsNames
                    ? PlayerNames.name(for: index)
                    : "Blatt \(index + 1)"

                // Jedes Blatt neu gemischt. Haetten alle dasselbe, haetten
                // auch alle gleichzeitig Bingo.
                let felder = BingoDeck.draw()

                guard let url = ShareImage.file(named: "trinkbingo-\(index + 1)", content: {
                    BingoShareCard(
                        owner: name,
                        fields: felder,
                        spotPenalty: spotPenalty,
                        bingoReward: bingoReward
                    )
                }) else { continue }

                erzeugt.append(Sheet(owner: name, url: url))
            }

            sheets = erzeugt
            failed = erzeugt.isEmpty
            isRendering = false

            if erzeugt.isEmpty {
                HapticManager.error()
            } else {
                HapticManager.success()
                SoundManager.play(.cardFlip)
            }
        }
    }
}
