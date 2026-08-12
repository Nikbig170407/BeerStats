//
//  DeveloperSettingsView.swift
//  BeerStats
//
//  Werkzeuge zum Geradeziehen der Daten: Kennzahlen von Hand korrigieren,
//  alles zurücksetzen, ein Profil endgültig entfernen.
//
//  Wichtige Einordnung zum Passwort: Es ist kein echter Schutz. Wer die
//  App auseinandernimmt, kommt an diesem Screen vorbei, und daran ändert
//  auch der Hash unten nichts. Es verhindert genau das, wofür es gedacht
//  ist: dass jemand am Tisch aus Versehen oder aus Spaß alle Statistiken
//  löscht. Für mehr wäre eine serverseitige Prüfung nötig.
//
//  Warum trotzdem ein Hash und nicht der Klartext: Das Repository ist
//  öffentlich. Ein Klartext-Passwort wäre damit für jeden nachlesbar, der
//  die Datei aufruft – das ist eine andere Größenordnung als "wer die App
//  zerlegt". Der Hash kostet nichts und nimmt genau diesen Weg weg.
//
//  Was der Hash NICHT leistet: Er ist ungesalzen und schnell. Ein kurzes
//  Passwort ist damit in Sekunden zu erraten, erst recht eines, das dem
//  alten ähnelt – und das alte steht als Klartext für immer in der
//  Historie. Für den Zweck hier reicht das; wer mehr braucht, prüft
//  serverseitig statt hier nachzubessern.
//
//  Passwort ändern: neuen Hash bilden und unten einsetzen.
//    python -c "import hashlib;print(hashlib.sha256(b'NEUESPASSWORT').hexdigest())"
//

import CryptoKit
import SwiftUI

struct DeveloperSettingsView: View {

    /// Beobachtet dieselbe Sammlung wie die Mitspieler-Ansicht – dadurch
    /// aktualisiert sich die Liste unmittelbar nach einer Korrektur.
    @StateObject private var viewModel: ProfilesViewModel

    private let repository: PlayerProfileRepositoryProtocol
    private let ownerId: String

    init(repository: PlayerProfileRepositoryProtocol, ownerId: String) {
        self.repository = repository
        self.ownerId = ownerId
        _viewModel = StateObject(
            wrappedValue: ProfilesViewModel(repository: repository, ownerId: ownerId)
        )
    }

    private var profiles: [PlayerProfile] { viewModel.profiles }

    @Environment(\.dismiss) private var dismiss

    @State private var isUnlocked = false
    @State private var passwordInput = ""
    @State private var showsWrongPassword = false

    @State private var editingProfile: PlayerProfile?
    @State private var confirmingReset = false
    @State private var profileToDelete: PlayerProfile?
    @State private var statusMessage: String?
    @State private var isWorking = false

    /// SHA-256 des Passworts. Siehe Kopf der Datei, wie man es austauscht.
    private static let passwordHash = "26de13be81fb2b99647c4a9c13be33024f1282b178f1f9e039a2c3ac9cf511b2"

    private static func matches(_ input: String) -> Bool {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined() == passwordHash
    }

    var body: some View {
        Group {
            if isUnlocked {
                toolList
            } else {
                lockScreen
            }
        }
        .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Entwickler")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingProfile) { profile in
            StatisticsEditorView(profile: profile) { corrected in
                editingProfile = nil
                Task { await overwrite(profile: profile, statistics: corrected) }
            }
        }
        .alert("Alle Statistiken zurücksetzen?", isPresented: $confirmingReset) {
            Button("Abbrechen", role: .cancel) {}
            Button("Zurücksetzen", role: .destructive) {
                Task { await resetAll() }
            }
        } message: {
            Text("Spiele, Siege, Treffer und Serien aller \(profiles.count) Profile werden auf null gesetzt. Namen, Emoji und Farbe bleiben erhalten. Das lässt sich nicht rückgängig machen.")
        }
        .alert(
            "Profil löschen?",
            isPresented: Binding(
                get: { profileToDelete != nil },
                set: { if !$0 { profileToDelete = nil } }
            )
        ) {
            Button("Abbrechen", role: .cancel) { profileToDelete = nil }
            Button("Endgültig löschen", role: .destructive) {
                if let profile = profileToDelete {
                    Task { await delete(profile: profile) }
                }
            }
        } message: {
            Text("\(profileToDelete?.name ?? "Das Profil") wird samt Statistik entfernt. Bereits gespielte Partien verweisen danach auf einen Spieler, den es nicht mehr gibt.")
        }
    }

    // MARK: - Sperre

    private var lockScreen: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 52))
                .foregroundStyle(BeerStatsColor.accent)

            Text("Geschützter Bereich")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Hier lassen sich Statistiken überschreiben und Profile löschen. Bitte Passwort eingeben.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            BeerStatsTextField(placeholder: "Passwort", text: $passwordInput, isSecure: true)
                .padding(.horizontal, 32)

            if showsWrongPassword {
                Text("Passwort stimmt nicht.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.error)
            }

            PrimaryButton(title: "Entsperren", systemImage: "lock.open.fill") {
                if Self.matches(passwordInput) {
                    withAnimation(AppAnimation.standard) { isUnlocked = true }
                    HapticManager.success()
                } else {
                    showsWrongPassword = true
                    passwordInput = ""
                    HapticManager.error()
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Werkzeuge

    private var toolList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let statusMessage {
                    Text(statusMessage)
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.success)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                section("Kennzahlen korrigieren") {
                    VStack(spacing: 8) {
                        ForEach(profiles) { profile in
                            Button {
                                editingProfile = profile
                            } label: {
                                profileRow(profile, systemImage: "square.and.pencil", tint: BeerStatsColor.accent)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }

                section("Profil entfernen") {
                    VStack(spacing: 8) {
                        ForEach(profiles) { profile in
                            Button {
                                profileToDelete = profile
                            } label: {
                                profileRow(profile, systemImage: "trash", tint: BeerStatsColor.error)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }

                section("Alles zurücksetzen") {
                    Button {
                        confirmingReset = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Statistiken aller Profile auf null")
                                .font(BeerStatsFont.headline)
                            Spacer()
                        }
                        .foregroundStyle(BeerStatsColor.error)
                        .padding(16)
                        .background(
                            BeerStatsColor.error.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(BeerStatsColor.error.opacity(0.5), lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                if isWorking {
                    CupFillLoadingView(size: 48)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
    }

    private func profileRow(_ profile: PlayerProfile, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            ProfileAvatarView(profile: profile, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name)
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text("\(profile.statistics.gamesPlayed) Spiele · \(profile.statistics.totalHits) Treffer")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            Spacer()
            Image(systemName: systemImage).foregroundStyle(tint)
        }
        .padding(14)
        .background(BeerStatsColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(BeerStatsFont.statLabel)
                .foregroundStyle(BeerStatsColor.accent)
            content()
        }
    }

    // MARK: - Aktionen

    private func overwrite(profile: PlayerProfile, statistics: UserStatistics) async {
        guard let profileId = profile.id else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await repository.overwriteStatistics(
                profileId: profileId,
                statistics: statistics,
                ownerId: ownerId
            )
            statusMessage = "Kennzahlen von \(profile.name) gespeichert."
            HapticManager.success()
        } catch {
            statusMessage = AppError.from(error).errorDescription
            HapticManager.error()
        }
    }

    private func resetAll() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await repository.resetAllStatistics(ownerId: ownerId)
            statusMessage = "Alle Statistiken zurückgesetzt."
            HapticManager.success()
        } catch {
            statusMessage = AppError.from(error).errorDescription
            HapticManager.error()
        }
    }

    private func delete(profile: PlayerProfile) async {
        guard let profileId = profile.id else { return }
        profileToDelete = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await repository.deleteProfile(profileId: profileId, ownerId: ownerId)
            statusMessage = "\(profile.name) wurde gelöscht."
            HapticManager.success()
        } catch {
            statusMessage = AppError.from(error).errorDescription
            HapticManager.error()
        }
    }
}

// MARK: - Kennzahlen von Hand ändern

private struct StatisticsEditorView: View {

    let profile: PlayerProfile
    let onSave: (UserStatistics) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var values: [Field: String]

    /// Die änderbaren Felder. Als Aufzählung statt einzelner States, damit
    /// ein neues Feld nur hier ergänzt werden muss.
    private enum Field: String, CaseIterable, Identifiable {
        case gamesPlayed, gamesWon, totalThrows, totalHits
        case totalAirballs, totalBounceShotsMade, totalTrickshotsMade
        case currentWinStreak, longestWinStreak, longestOnFireStreak

        var id: String { rawValue }

        var title: String {
            switch self {
            case .gamesPlayed: return "Spiele"
            case .gamesWon: return "Siege"
            case .totalThrows: return "Würfe"
            case .totalHits: return "Treffer"
            case .totalAirballs: return "Airballs"
            case .totalBounceShotsMade: return "Bounce Shots"
            case .totalTrickshotsMade: return "Trickshots"
            case .currentWinStreak: return "Aktuelle Siegesserie"
            case .longestWinStreak: return "Längste Siegesserie"
            case .longestOnFireStreak: return "Längste On-Fire-Serie"
            }
        }

        func value(in statistics: UserStatistics) -> Int {
            switch self {
            case .gamesPlayed: return statistics.gamesPlayed
            case .gamesWon: return statistics.gamesWon
            case .totalThrows: return statistics.totalThrows
            case .totalHits: return statistics.totalHits
            case .totalAirballs: return statistics.totalAirballs
            case .totalBounceShotsMade: return statistics.totalBounceShotsMade
            case .totalTrickshotsMade: return statistics.totalTrickshotsMade
            case .currentWinStreak: return statistics.currentWinStreak
            case .longestWinStreak: return statistics.longestWinStreak
            case .longestOnFireStreak: return statistics.longestOnFireStreak
            }
        }

        func apply(_ newValue: Int, to statistics: inout UserStatistics) {
            switch self {
            case .gamesPlayed: statistics.gamesPlayed = newValue
            case .gamesWon: statistics.gamesWon = newValue
            case .totalThrows: statistics.totalThrows = newValue
            case .totalHits: statistics.totalHits = newValue
            case .totalAirballs: statistics.totalAirballs = newValue
            case .totalBounceShotsMade: statistics.totalBounceShotsMade = newValue
            case .totalTrickshotsMade: statistics.totalTrickshotsMade = newValue
            case .currentWinStreak: statistics.currentWinStreak = newValue
            case .longestWinStreak: statistics.longestWinStreak = newValue
            case .longestOnFireStreak: statistics.longestOnFireStreak = newValue
            }
        }
    }

    init(profile: PlayerProfile, onSave: @escaping (UserStatistics) -> Void) {
        self.profile = profile
        self.onSave = onSave
        var initial: [Field: String] = [:]
        for field in Field.allCases {
            initial[field] = String(field.value(in: profile.statistics))
        }
        _values = State(initialValue: initial)
    }

    /// Warnt, wenn Treffer über Würfen liegen – rechnerisch unmöglich und
    /// würde eine Trefferquote über 100 Prozent ergeben.
    private var isInconsistent: Bool {
        let hits = Int(values[.totalHits] ?? "") ?? 0
        let attempts = Int(values[.totalThrows] ?? "") ?? 0
        let won = Int(values[.gamesWon] ?? "") ?? 0
        let played = Int(values[.gamesPlayed] ?? "") ?? 0
        return hits > attempts || won > played
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        ProfileAvatarView(profile: profile, size: 48)
                        Text(profile.name)
                            .font(BeerStatsFont.title)
                            .foregroundStyle(BeerStatsColor.textPrimary)
                        Spacer()
                    }
                    .padding(.bottom, 4)

                    if isInconsistent {
                        Text("Achtung: Treffer über Würfen oder Siege über Spielen ergeben unmögliche Quoten.")
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.warning)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ForEach(Field.allCases) { field in
                        HStack {
                            Text(field.title)
                                .font(BeerStatsFont.body)
                                .foregroundStyle(BeerStatsColor.textSecondary)
                            Spacer()
                            TextField("0", text: binding(for: field))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(BeerStatsFont.statValue)
                                .foregroundStyle(BeerStatsColor.textPrimary)
                                .frame(width: 90)
                        }
                        .padding(14)
                        .background(
                            BeerStatsColor.surfaceElevated,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                    }
                }
                .padding(20)
            }
            .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Kennzahlen ändern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sichern") { onSave(assembled()) }
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.accent)
                }
            }
        }
    }

    private func binding(for field: Field) -> Binding<String> {
        Binding(
            get: { values[field] ?? "0" },
            // Nur Ziffern zulassen, sonst käme beim Sichern still eine Null heraus.
            set: { values[field] = $0.filter(\.isNumber) }
        )
    }

    private func assembled() -> UserStatistics {
        var statistics = profile.statistics
        for field in Field.allCases {
            field.apply(Int(values[field] ?? "") ?? 0, to: &statistics)
        }
        return statistics
    }
}
