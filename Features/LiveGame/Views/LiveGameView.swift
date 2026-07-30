//
//  LiveGameView.swift
//  BeerStats
//
//  Der Screen, auf dem während des Spiels getippt wird.
//
//  Leitidee aus dem Regelwerk-Entwurf: Eine Eingabe darf höchstens ein bis
//  zwei Sekunden dauern und muss einhändig erreichbar sein. Deshalb liegen
//  die Racks oben und in der Mitte, während alle Buttons unten im
//  Daumenbereich sitzen – „Daneben" als größte Fläche, weil es der
//  häufigste Fall ist.
//

import SwiftUI

struct LiveGameView: View {

    @StateObject private var viewModel: LiveGameViewModel
    @Environment(\.dismiss) private var dismiss

    /// Team, aus dessen Sicht gezeigt wird – dessen Becher liegen unten.
    private let perspectiveTeamIndex: Int

    @State private var abortProgress: CGFloat = 0

    init(
        teams: [Team],
        format: GameFormat,
        playersPerTeam: Int,
        perspectiveTeamIndex: Int = 0,
        gameId: String? = nil,
        throwRepository: ThrowRepositoryProtocol? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: LiveGameViewModel(
                teams: teams,
                format: format,
                playersPerTeam: playersPerTeam,
                gameId: gameId,
                throwRepository: throwRepository
            )
        )
        self.perspectiveTeamIndex = perspectiveTeamIndex
    }

    private var bottomTeam: Int { perspectiveTeamIndex }
    private var topTeam: Int { 1 - perspectiveTeamIndex }

    var body: some View {
        ZStack {
            BeerStatsColor.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 8)
                teamBar(topTeam)
                RackView(
                    rack: viewModel.state.racks[topTeam],
                    isOpponentRack: true,
                    stateForCup: { viewModel.cupState(teamIndex: topTeam, cupIndex: $0) },
                    onTap: { viewModel.handleCupTap(teamIndex: topTeam, cupIndex: $0) }
                )
                turnPill
                RackView(
                    rack: viewModel.state.racks[bottomTeam],
                    isOpponentRack: false,
                    stateForCup: { viewModel.cupState(teamIndex: bottomTeam, cupIndex: $0) },
                    onTap: { viewModel.handleCupTap(teamIndex: bottomTeam, cupIndex: $0) }
                )
                teamBar(bottomTeam)
                Spacer(minLength: 8)
                actionArea
            }
            .padding(.horizontal, 16)

            if let highlight = viewModel.highlight {
                highlightOverlay(highlight)
            }

            if viewModel.state.isFinished {
                gameOverOverlay
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.isShowingReRackSheet) {
            ReRackSheet(
                formations: viewModel.availableFormations,
                remainingCups: viewModel.state.racks[viewModel.state.targetRackIndex].remainingCount,
                teamName: viewModel.teamName(viewModel.state.opponent(of: viewModel.state.turnTeamIndex))
            ) { formation in
                viewModel.isShowingReRackSheet = false
                viewModel.perform(.reRack(formation))
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Kopfzeile

    private var header: some View {
        HStack(spacing: 12) {
            abortButton

            VStack(spacing: 2) {
                Text(matchTitle)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .lineLimit(1)
                if viewModel.state.phase == .redemption {
                    Text("Redemption — \(viewModel.teamName(viewModel.state.turnTeamIndex))")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.accentSecondary)
                }
            }
            .frame(maxWidth: .infinity)

            // Platzhalter gleicher Breite, damit der Titel mittig bleibt.
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.top, 4)
    }

    /// Abbrechen erfordert drei Sekunden Halten – ein versehentlicher Tipper
    /// mitten im Spiel darf die Partie nicht beenden.
    private var abortButton: some View {
        ZStack {
            Circle()
                .stroke(BeerStatsColor.textSecondary.opacity(0.25), lineWidth: 2)
            Circle()
                .trim(from: 0, to: abortProgress)
                .stroke(BeerStatsColor.accentSecondary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(abortProgress > 0 ? BeerStatsColor.accentSecondary : BeerStatsColor.textSecondary)
        }
        .frame(width: 36, height: 36)
        .contentShape(Circle())
        // Bewusst die `pressing:perform:`-Variante: die neuere Schreibweise
        // mit `onPressingChanged:` gibt es erst ab iOS 17, das Deployment-
        // Target dieses Projekts ist iOS 16.
        .onLongPressGesture(
            minimumDuration: 3.0,
            pressing: { isPressing in
                withAnimation(.linear(duration: isPressing ? 3.0 : 0.2)) {
                    abortProgress = isPressing ? 1 : 0
                }
            },
            perform: {
                HapticManager.error()
                dismiss()
            }
        )
        .accessibilityLabel("Spiel abbrechen, drei Sekunden halten")
    }

    private var matchTitle: String {
        let first = viewModel.teams[0].playerNames.joined(separator: " & ")
        let second = viewModel.teams[1].playerNames.joined(separator: " & ")
        return "\(first)  vs  \(second)"
    }

    // MARK: - Team-Zeile

    private func teamBar(_ teamIndex: Int) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(viewModel.teamName(teamIndex))
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                Spacer()
                Text("\(viewModel.state.racks[teamIndex].remainingCount)")
                    .font(BeerStatsFont.statValue)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }

            HStack(spacing: 8) {
                ForEach(0..<viewModel.state.playersPerTeam, id: \.self) { slot in
                    playerChip(PlayerRef(teamIndex: teamIndex, slot: slot))
                }
                Spacer()
            }
        }
        .padding(.vertical, 6)
    }

    private func playerChip(_ player: PlayerRef) -> some View {
        let isActive = !viewModel.state.isFinished
            && viewModel.state.currentThrower == player
            && viewModel.state.pendingChoice == nil
        let isOnFire = viewModel.state.onFire[player.teamIndex][player.slot]

        return HStack(spacing: 4) {
            Text(viewModel.playerName(player))
                .font(BeerStatsFont.caption)
                .lineLimit(1)
            if isOnFire { Text("🔥").font(.system(size: 11)) }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(isActive ? BeerStatsColor.accent : Color.clear)
        )
        .overlay(
            Capsule().strokeBorder(
                isOnFire ? BeerStatsColor.accentSecondary : BeerStatsColor.textSecondary.opacity(0.25),
                lineWidth: 1
            )
        )
        .foregroundStyle(isActive ? BeerStatsColor.textOnAccent : BeerStatsColor.textSecondary)
        .animation(AppAnimation.tap, value: isActive)
    }

    // MARK: - Zug-Anzeige

    private var turnPill: some View {
        Text(viewModel.turnDescription)
            .font(BeerStatsFont.statLabel)
            .foregroundStyle(BeerStatsColor.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(BeerStatsColor.surfaceElevated))
            .overlay(Capsule().strokeBorder(BeerStatsColor.textSecondary.opacity(0.15), lineWidth: 1))
            .padding(.vertical, 10)
            .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Bedienbereich

    private var actionArea: some View {
        VStack(spacing: 10) {
            if let prompt = viewModel.choicePrompt {
                banner(prompt, tint: BeerStatsColor.accent)
            } else if let hint = viewModel.trickshotHint {
                banner(hint, tint: BeerStatsColor.success)
            }

            chipRow

            // Während einer erzwungenen Auswahl sind alle Wurf-Buttons
            // bedeutungslos – ausblenden statt nur sperren.
            if viewModel.state.pendingChoice == nil {
                Button {
                    viewModel.perform(.miss)
                } label: {
                    Text("Daneben")
                        .font(BeerStatsFont.liveGameButton)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
                .background(BeerStatsColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .buttonStyle(PressableButtonStyle())
                .disabled(!viewModel.canThrow)

                HStack(spacing: 8) {
                    smallButton("Airball", tint: BeerStatsColor.error, enabled: viewModel.canThrow) {
                        viewModel.perform(.airball)
                    }
                    smallButton("Rebound", tint: BeerStatsColor.success, enabled: viewModel.canRebound) {
                        viewModel.perform(.rebound)
                    }
                    if viewModel.canDeclareBombe {
                        smallButton("💣 Bombe", tint: BeerStatsColor.accentSecondary, enabled: true) {
                            viewModel.perform(.bombe)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 12)
        .animation(AppAnimation.standard, value: viewModel.state.pendingChoice != nil)
    }

    private var chipRow: some View {
        HStack(spacing: 8) {
            chip("↶ Zurück", isOn: false, enabled: viewModel.canUndo) { viewModel.undo() }
            chip("🏓 Bounce", isOn: viewModel.state.bounceArmed, enabled: viewModel.canArmBounce) {
                viewModel.perform(.toggleBounce)
            }
            chip(
                viewModel.state.reRackUsed[viewModel.state.turnTeamIndex] ? "🔄 Umgestellt" : "🔄 Umstellen",
                isOn: false,
                enabled: viewModel.canReRack
            ) {
                viewModel.isShowingReRackSheet = true
            }
        }
    }

    private func chip(_ title: String, isOn: Bool, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(BeerStatsFont.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .background(Capsule().fill(isOn ? BeerStatsColor.accent : Color.clear))
        .overlay(Capsule().strokeBorder(BeerStatsColor.textSecondary.opacity(0.25), lineWidth: 1))
        .foregroundStyle(isOn ? BeerStatsColor.textOnAccent : BeerStatsColor.textSecondary)
        .buttonStyle(PressableButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    private func smallButton(
        _ title: String,
        tint: Color,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(BeerStatsFont.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .foregroundStyle(tint)
        .buttonStyle(PressableButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    private func banner(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(BeerStatsFont.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(tint, lineWidth: 1)
            )
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Overlays

    private func highlightOverlay(_ highlight: LiveGameViewModel.Highlight) -> some View {
        VStack(spacing: 10) {
            Text(highlight.title)
                .font(BeerStatsFont.largeTitle)
                .foregroundStyle(highlight.tint)
            Text(highlight.subtitle)
                .font(BeerStatsFont.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BeerStatsColor.backgroundPrimary.opacity(0.94))
        .ignoresSafeArea()
        // Darf keine Taps abfangen: Wer schnell weitertippt, soll nicht
        // durch die Animation ausgebremst werden.
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private var gameOverOverlay: some View {
        let winner = viewModel.state.winnerTeamIndex

        return VStack(spacing: 12) {
            Text(winner == nil ? "🤝" : "🏆").font(.system(size: 56))

            Text(winner.map { "\(viewModel.teamName($0)) gewinnt!" } ?? "Unentschieden")
                .font(BeerStatsFont.largeTitle)
                .foregroundStyle(BeerStatsColor.accent)
                .multilineTextAlignment(.center)

            if let winner {
                Text(viewModel.teams[winner].playerNames.joined(separator: "  ·  "))
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)

                HStack(spacing: 24) {
                    statTile("\(viewModel.state.cupsKnockedDown(by: winner))", label: "Becher")
                    statTile(accuracyText(for: winner), label: "Quote")
                    statTile("\(viewModel.state.bestStreaks[winner].max() ?? 0)", label: "Serie")
                }
                .padding(.top, 4)
            }

            VStack(spacing: 10) {
                PrimaryButton(title: "Fertig", systemImage: "checkmark") { dismiss() }
                Button("Rückgängig") { viewModel.undo() }
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .disabled(!viewModel.canUndo)
            }
            .padding(.top, 16)
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BeerStatsColor.backgroundPrimary.opacity(0.97))
        .ignoresSafeArea()
        .transition(.opacity)
    }

    private func statTile(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(BeerStatsFont.statValue)
                .foregroundStyle(BeerStatsColor.accent)
            Text(label)
                .font(BeerStatsFont.statLabel)
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    private func accuracyText(for teamIndex: Int) -> String {
        guard let accuracy = viewModel.state.teamStats(teamIndex).accuracy else { return "–" }
        return "\(Int((accuracy * 100).rounded()))%"
    }
}

// MARK: - Re-Rack-Auswahl

private struct ReRackSheet: View {

    let formations: [RackFormation]
    let remainingCups: Int
    let teamName: String
    let onSelect: (RackFormation) -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Becher umstellen")
                    .font(BeerStatsFont.title)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text("\(remainingCups) Becher von \(teamName) · einmal pro Spiel")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            .padding(.top, 20)

            HStack(alignment: .top, spacing: 12) {
                ForEach(formations) { formation in
                    Button {
                        onSelect(formation)
                    } label: {
                        VStack(spacing: 8) {
                            FormationPreview(rows: formation.rows)
                            Text(formation.name)
                                .font(BeerStatsFont.caption)
                                .foregroundStyle(BeerStatsColor.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .background(BeerStatsColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
    }
}

/// Kleine Vorschau einer Formation, damit am Tisch sofort erkennbar ist,
/// wie die Becher danach stehen.
private struct FormationPreview: View {
    let rows: [Int]

    var body: some View {
        VStack(spacing: 3) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, count in
                HStack(spacing: 3) {
                    ForEach(0..<count, id: \.self) { _ in
                        Circle()
                            .fill(BeerStatsColor.cupBase)
                            .frame(width: 9, height: 9)
                    }
                }
            }
        }
        .frame(height: 46)
    }
}
