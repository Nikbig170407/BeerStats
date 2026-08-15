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
import UniformTypeIdentifiers

struct DataExportView: View {

    let container: AppContainer
    let ownerId: String

    @State private var summary: DataExportSummary?
    @State private var isWorking = false
    @State private var errorText: String?

    @State private var isPickingFile = false
    @State private var importPreview: DataImportPreview?
    @State private var importData: Data?
    @State private var importStep: String?
    @State private var importError: String?

    private var service: (export: DataExportService, importService: DataImportService) {
        (DataExportService(
            profileRepository: container.playerProfileRepository,
            gameRepository: container.gameRepository,
            throwRepository: container.throwRepository
        ),
        DataImportService(
            profileRepository: container.playerProfileRepository,
            gameRepository: container.gameRepository,
            throwRepository: container.throwRepository
        ))
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
                        VStack(spacing: 6) {
                            ProgressView().tint(BeerStatsColor.accent)
                            if let importStep {
                                Text(importStep)
                                    .font(BeerStatsFont.caption)
                                    .foregroundStyle(BeerStatsColor.textSecondary)
                            }
                        }
                    } else if let importStep {
                        Text(importStep)
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.success)
                    }

                    restoreSection
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

    // MARK: - Wiederherstellen

    /// Steht unter dem Sichern und ist zurueckhaltender gestaltet.
    ///
    /// Wiederherstellen ist die seltenere und die gefaehrlichere Haelfte: Es
    /// LEGT AN, es ersetzt nichts. Wer es auf ein Konto laufen laesst, in dem
    /// schon Profile stehen, hat danach jedes zweimal. Deshalb steht die
    /// Warnung im Text und nicht im Kleingedruckten.
    private var restoreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WIEDERHERSTELLEN")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .kerning(1.8)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .padding(.top, 14)

            if let vorschau = importPreview {
                previewCard(vorschau)
            } else {
                Text("Eine gesicherte Datei zurücklesen. Profile und Partien werden neu angelegt – vorhandene bleiben stehen.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Datei auswählen") { isPickingFile = true }
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.accentSecondary)
            }

            if let importError {
                Text(importError)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.json]) { ergebnis in
            handlePickedFile(ergebnis)
        }
    }

    private func previewCard(_ vorschau: DataImportPreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sicherung vom \(vorschau.exportedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(BeerStatsFont.headline)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("\(vorschau.profileCount) Profile · \(vorschau.gameCount) Partien · \(vorschau.throwCount) Würfe")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)

            if !vorschau.canRestoreThrowLog {
                Text("Ältere Fassung ohne Wurf-Aktionen: Profile und Kennzahlen kommen zurück, die Partien lassen sich daraus aber nicht mehr nachspielen.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Achtung: Es wird angelegt, nicht ersetzt. Auf einem Konto mit vorhandenen Profilen steht danach alles doppelt.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.warning)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryButton(title: "Nur Profile und Werte", systemImage: "person.2.fill") {
                Task { await runImport(includeGames: false) }
            }
            .disabled(isWorking)

            if vorschau.canRestoreThrowLog && vorschau.gameCount > 0 {
                Button("Alles, auch die \(vorschau.gameCount) Partien") {
                    Task { await runImport(includeGames: true) }
                }
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .disabled(isWorking)
            }

            Button("Abbrechen") {
                importPreview = nil
                importData = nil
            }
            .font(BeerStatsFont.caption)
            .foregroundStyle(BeerStatsColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassPanel(cornerRadius: 18)
        .neonEdge(BeerStatsColor.accentSecondary, cornerRadius: 18, intensity: 0.5)
    }

    private func handlePickedFile(_ ergebnis: Result<URL, Error>) {
        importError = nil
        do {
            let url = try ergebnis.get()
            // Aus der Dateien-App kommt die Datei mit eingeschraenkten
            // Rechten – ohne diesen Zugriff schlaegt das Lesen fehl.
            let zugriff = url.startAccessingSecurityScopedResource()
            defer { if zugriff { url.stopAccessingSecurityScopedResource() } }

            let daten = try Data(contentsOf: url)
            importPreview = try service.importService.preview(daten)
            importData = daten
        } catch {
            importError = "Datei nicht lesbar: \(error.localizedDescription)"
        }
    }

    private func runImport(includeGames: Bool) async {
        guard let importData else { return }
        isWorking = true
        importError = nil
        defer { isWorking = false }

        do {
            let ergebnis = try await service.importService.restore(
                importData,
                ownerId: ownerId,
                includeGames: includeGames,
                progress: { schritt in importStep = schritt }
            )
            importPreview = nil
            self.importData = nil
            importStep = "\(ergebnis.profiles) Profile, \(ergebnis.games) Partien wiederhergestellt"
            HapticManager.success()
            SoundManager.play(.victory)
        } catch {
            importError = AppError.from(error).localizedDescription
            HapticManager.error()
        }
    }

    // MARK: - Ablauf

    private func run() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }

        do {
            let result = try await service.export.makeExport(ownerId: ownerId)
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
