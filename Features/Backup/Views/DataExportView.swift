//
//  DataExportView.swift
//  BeerStats
//
//  "Alles als Datei sichern" – der einzige Weg, die Daten aus der App
//  herauszubekommen.
//
//  Bewusst NICHT hinter dem Entwickler-Passwort: Eine Sicherung, an die man
//  nur kommt, wenn ohnehin alles laeuft, ist keine. Sie muss gerade dann
//  erreichbar sein, wenn etwas schiefgeht.
//
//  Bewusst auch nichts, was im Hintergrund automatisch passiert. Jede Partie
//  ist eine eigene Abfrage, und Lesezugriffe sind im Spark-Tarif begrenzt –
//  eine Sicherung, die sich taeglich selbst anstoesst, verbraucht das
//  Kontingent fuer etwas, das der Nutzer vielleicht nie braucht. Er
//  entscheidet, wann.
//

import SwiftUI

struct DataExportView: View {

    let container: AppContainer
    let ownerId: String

    @State private var summary: DataExportSummary?
    @State private var isWorking = false
    @State private var errorText: String?

    private var service: DataExportService {
        DataExportService(
            profileRepository: container.playerProfileRepository,
            gameRepository: container.gameRepository,
            throwRepository: container.throwRepository
        )
    }

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.accent)

            ScrollView {
                VStack(spacing: 20) {
                    header
                    explanation

                    if let summary {
                        resultCard(summary)
                    }

                    if let errorText {
                        Text(errorText)
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.error)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PrimaryButton(
                        title: summary == nil ? "Sicherung erstellen" : "Neu erstellen",
                        systemImage: "arrow.down.doc"
                    ) {
                        Task { await run() }
                    }
                    .disabled(isWorking)
                    .opacity(isWorking ? 0.5 : 1)

                    if isWorking {
                        ProgressView()
                            .tint(BeerStatsColor.accent)
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Daten sichern")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Bausteine

    private var header: some View {
        VStack(spacing: 10) {
            Text("💾").font(.system(size: 56))

            Text("Alles als Datei")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
        }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 10) {
            row("Profile mit allen Kennzahlen")
            row("Jede abgeschlossene Partie")
            row("Den vollständigen Wurf-Log jeder Partie")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassPanel(cornerRadius: 20)
        .neonEdge(BeerStatsColor.accent, cornerRadius: 20, intensity: 0.4)
    }

    private func row(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(BeerStatsColor.accent)
            Text(text)
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textPrimary)
            Spacer(minLength: 0)
        }
    }

    private func resultCard(_ summary: DataExportSummary) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 22) {
                figure("\(summary.profileCount)", "Profile")
                figure("\(summary.gameCount)", "Partien")
                figure("\(summary.throwCount)", "Würfe")
            }

            Text(summary.readableSize)
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)

            // Die Datei liegt im Zwischenspeicher des Systems und kann dort
            // jederzeit geräumt werden. Erst das Teilen bringt sie an einen
            // Ort, der bleibt – deshalb steht der Knopf so deutlich da.
            ShareLink(item: summary.fileURL) {
                Text("Datei sichern oder teilen")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        BeerStatsColor.success,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Text("Noch nicht in Sicherheit: Erst das Teilen legt die Datei irgendwo ab, wo sie bleibt.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.warning)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassPanel(cornerRadius: 22)
        .neonEdge(BeerStatsColor.success, cornerRadius: 22, intensity: 0.7)
    }

    private func figure(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.success)
                .monospacedDigit()
            Text(caption)
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    // MARK: - Ablauf

    private func run() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }

        do {
            let result = try await service.makeExport(ownerId: ownerId)
            summary = result
            HapticManager.success()
            SoundManager.play(.victory)
        } catch {
            // Der eigentliche Fehler gehoert auf den Bildschirm, nicht in die
            // Konsole: Wer sichert, will wissen, ob es geklappt hat.
            errorText = AppError.from(error).localizedDescription
            HapticManager.error()
        }
    }
}
