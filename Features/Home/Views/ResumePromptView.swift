//
//  ResumePromptView.swift
//  BeerStats
//
//  Die Frage nach der offenen Partie: weiterspielen oder neu anfangen?
//
//  Vorher stand im Hauptmenue dauerhaft "Eine Partie laeuft noch". Das ist
//  eine Meldung, die nie jemand angefordert hat und die so lange herumsteht,
//  bis sich jemand darum kuemmert. Gefragt wird jetzt dort, wo die Frage
//  aufkommt: beim Griff nach Beerpong.
//
//  Der Stand wird aus dem Wurf-Log nachgespielt und nicht aus dem
//  Spiel-Dokument gelesen. `Game.cupsRemaining` steht seit dem Anlegen
//  unveraendert auf der vollen Becherzahl – aktualisiert haette es eine
//  Cloud Function, die es ohne Blaze-Tarif nie gab. Ein Stand von 10:10
//  waere keine Information, sondern eine Behauptung.
//

import SwiftUI

struct ResumePromptView: View {

    let game: Game
    let throwRepository: ThrowRepositoryProtocol
    let onResume: () -> Void
    let onNewGame: () -> Void

    @Environment(\.dismiss) private var dismiss

    /// Verbleibende Becher je Team, nachgespielt. `nil`, solange geladen wird
    /// oder wenn der Log nicht erreichbar war.
    @State private var remaining: [Int]?
    @State private var isLoading = true
    @State private var isCancelling = false

    private var playersPerTeam: Int { game.type == .oneVsOne ? 1 : 2 }

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.accent)

            VStack(spacing: 20) {
                header
                scoreboard
                Spacer(minLength: 0)
                buttons
            }
            .padding(24)
        }
        .task { await loadScore() }
    }

    // MARK: - Kopf

    private var header: some View {
        VStack(spacing: 8) {
            Text("⏸️").font(.system(size: 48))

            Text("Eine Partie läuft noch")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)

            Text(startedText)
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
        .padding(.top, 12)
    }

    private var startedText: String {
        guard let start = game.startedAt ?? game.createdAt else {
            return "Angefangen und nicht zu Ende gespielt"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE, HH:mm 'Uhr'"
        return "Angefangen \(formatter.string(from: start))"
    }

    // MARK: - Stand

    /// Wer gegen wen, und wie es steht.
    private var scoreboard: some View {
        VStack(spacing: 14) {
            ForEach(Array(game.teams.enumerated()), id: \.element.id) { index, team in
                HStack(spacing: 12) {
                    Text(team.playerNames.joined(separator: " & "))
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer(minLength: 0)

                    cupCount(for: index)
                }

                if index == 0 {
                    Text("gegen")
                        .font(BeerStatsFont.statLabel)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .glassPanel(cornerRadius: 20)
        .neonEdge(BeerStatsColor.accent, cornerRadius: 20, intensity: 0.5)
    }

    @ViewBuilder
    private func cupCount(for index: Int) -> some View {
        if isLoading {
            ProgressView().tint(BeerStatsColor.accent)
        } else if let remaining, remaining.indices.contains(index) {
            HStack(spacing: 5) {
                Text("\(remaining[index])")
                    .font(.scaled(26, weight: .heavy, design: .rounded))
                    .foregroundStyle(BeerStatsColor.accent)
                    .monospacedDigit()
                Text("Becher")
                    .font(BeerStatsFont.statLabel)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
        } else {
            // Lieber nichts als eine Zahl, die vielleicht nicht stimmt.
            Text("–")
                .font(.scaled(22, weight: .heavy, design: .rounded))
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    // MARK: - Die zwei Wege

    private var buttons: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "Weiterspielen", systemImage: "play.fill") {
                onResume()
            }

            // Ausdruecklich benannt, was dabei passiert: Die laufende Partie
            // wird abgebrochen. Sie verschwindet damit aus der Wertung, der
            // Wurf-Log bleibt aber erhalten.
            Button {
                isCancelling = true
                onNewGame()
            } label: {
                VStack(spacing: 2) {
                    Text("Neue Partie")
                        .font(BeerStatsFont.headline)
                    Text("bricht die laufende ab")
                        .font(.scaled(10, weight: .medium, design: .rounded))
                }
                .foregroundStyle(BeerStatsColor.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .glassPanel(cornerRadius: 15)
                .neonEdge(BeerStatsColor.error, cornerRadius: 15, intensity: 0.4)
                .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(isCancelling)

            Button("Später entscheiden") { dismiss() }
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .padding(.top, 2)
        }
    }

    // MARK: - Laden

    private func loadScore() async {
        defer { isLoading = false }
        guard let gameId = game.id else { return }

        do {
            let entries = try await throwRepository.fetchThrows(gameId: gameId)
            let state = throwRepository.replay(
                entries,
                format: game.format,
                playersPerTeam: playersPerTeam
            )
            remaining = state.racks.map(\.remainingCount)
        } catch {
            // Ohne Stand ist die Frage immer noch beantwortbar – wer
            // weiterspielen will, sieht den Stand eine Sekunde spaeter im
            // Spiel selbst.
            remaining = nil
        }
    }
}
