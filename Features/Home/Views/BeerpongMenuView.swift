//
//  BeerpongMenuView.swift
//  BeerStats
//
//  Alles, was zu Beerpong gehoert – eine Ebene unter dem Hauptmenue.
//
//  Mitspieler, Rangliste und Verlauf haengen ausschliesslich an Beerpong:
//  Die Partyspiele erzeugen keine dieser Zahlen. Im Hauptmenue standen sie
//  trotzdem gleichrangig neben den Spielen und liessen die Auswahl wie eine
//  Einstellungsliste wirken.
//
//  Das HomeViewModel wird von oben durchgereicht statt hier neu gebaut:
//  Sonst liefe ein zweiter Firestore-Listener auf dieselben Daten.
//

import SwiftUI

struct BeerpongMenuView: View {

    let container: AppContainer
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Bewusst nur das zuletzt begonnene Spiel statt einer Liste:
                // Es laeuft immer hoechstens eine Partie, und die soll nach
                // einem versehentlichen Verlassen weitergehen.
                if let running = viewModel.resumableGame {
                    resumeLink(for: running)
                }

                newGameLink
                rulesCard
                destinationCards
                backupCard
            }
            .padding(20)
        }
        .background(GridBackdrop())
        .navigationTitle("Beerpong")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Spielen

    private var newGameLink: some View {
        NavigationLink {
            NewGameView(container: container, currentUserId: viewModel.currentUserId)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("Neues Spiel")
            }
            .font(BeerStatsFont.headline)
            .foregroundStyle(BeerStatsColor.textOnAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(BeerStatsColor.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func resumeLink(for game: Game) -> some View {
        NavigationLink {
            LiveGameView(
                teams: game.teams,
                format: game.format,
                playersPerTeam: game.type == .oneVsOne ? 1 : 2,
                perspectiveTeamIndex: 0,
                gameId: game.id,
                throwRepository: container.throwRepository,
                gameRepository: container.gameRepository,
                profileRepository: container.playerProfileRepository,
                ownerId: viewModel.currentUserId
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(BeerStatsColor.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spiel fortsetzen")
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                    Text(game.teams.map { $0.playerNames.joined(separator: " & ") }.joined(separator: " vs "))
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            .padding(16)
            .glassPanel()
            .neonEdge(BeerStatsColor.accent, intensity: 0.7)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Auswertung

    private var destinationCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AUSWERTUNG")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .kerning(1.8)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .padding(.top, 4)

            NavigationLink {
                ProfilesView(container: container, ownerId: viewModel.currentUserId)
            } label: {
                destinationCard(
                    title: "Mitspieler & Statistiken",
                    subtitle: "Profile anlegen, Werte ansehen, vergleichen",
                    systemImage: "chart.bar.xaxis",
                    tint: BeerStatsColor.accent
                )
            }
            .buttonStyle(PressableButtonStyle())

            NavigationLink {
                LeaderboardView(profiles: viewModel.profiles)
            } label: {
                destinationCard(
                    title: "Rangliste",
                    subtitle: viewModel.leadingProfile.map { "Aktuell vorn: \($0.name)" }
                        ?? "Noch keine Wertung",
                    systemImage: "trophy.fill",
                    tint: BeerStatsColor.warning
                )
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(viewModel.profiles.isEmpty)
            .opacity(viewModel.profiles.isEmpty ? 0.45 : 1)

            NavigationLink {
                GameHistoryView(
                    gameRepository: container.gameRepository,
                    ownerId: viewModel.currentUserId
                )
            } label: {
                destinationCard(
                    title: "Spielverlauf",
                    subtitle: "Vergangene Partien mit Ergebnis",
                    systemImage: "clock.arrow.circlepath",
                    tint: BeerStatsColor.success
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: - Nachschlagen

    /// Steht bewusst weit oben und nicht bei der Auswertung: Gebraucht wird
    /// das, BEVOR gespielt wird – meistens von jemandem, der zum ersten Mal
    /// mit am Tisch steht.
    private var rulesCard: some View {
        NavigationLink {
            RulesView()
        } label: {
            destinationCard(
                title: "Regeln",
                subtitle: "Balls Back, Bombe, On Fire – alles zum Nachlesen",
                systemImage: "book.fill",
                tint: BeerStatsColor.textSecondary
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Sicherung

    /// Eigener Abschnitt, nicht bei der Auswertung: Das hier wertet nichts
    /// aus, es holt die Daten heraus. Und es steht bewusst im Hauptweg statt
    /// bei den Entwicklereinstellungen – hinter dem Passwort wuerde es
    /// niemand finden, der es braucht.
    private var backupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SICHERUNG")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .kerning(1.8)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .padding(.top, 4)

            NavigationLink {
                DataExportView(container: container, ownerId: viewModel.currentUserId)
            } label: {
                destinationCard(
                    title: "Daten sichern",
                    subtitle: "Profile, Partien und Wurf-Logs als Datei",
                    systemImage: "arrow.down.doc.fill",
                    tint: BeerStatsColor.accentSecondary
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func destinationCard(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.18))
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text(subtitle)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
        .padding(16)
        .glassPanel()
        .neonEdge(tint, intensity: 0.4)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
