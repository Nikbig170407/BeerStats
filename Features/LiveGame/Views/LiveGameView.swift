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
    @State private var isHoldingAbort = false

    private static let abortHoldDuration: Double = 1.5

    init(
        teams: [Team],
        format: GameFormat,
        playersPerTeam: Int,
        perspectiveTeamIndex: Int = 0,
        gameId: String? = nil,
        throwRepository: ThrowRepositoryProtocol? = nil,
        gameRepository: GameRepositoryProtocol? = nil,
        profileRepository: PlayerProfileRepositoryProtocol? = nil,
        ownerId: String? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: LiveGameViewModel(
                teams: teams,
                format: format,
                playersPerTeam: playersPerTeam,
                gameId: gameId,
                throwRepository: throwRepository,
                gameRepository: gameRepository,
                profileRepository: profileRepository,
                ownerId: ownerId
            )
        )
        self.perspectiveTeamIndex = perspectiveTeamIndex
    }

    private var bottomTeam: Int { perspectiveTeamIndex }
    private var topTeam: Int { 1 - perspectiveTeamIndex }

    var body: some View {
        ZStack {
            GridBackdrop(spacing: 40, lineOpacity: 0.04)

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
                HighlightOverlayView(highlight: highlight) {
                    viewModel.dismissHighlight()
                }
                .id(highlight.id)   // erzwingt den Neustart der Animation bei Folge-Ereignissen
                .transition(.opacity)
                .zIndex(1)          // liegt sicher über Racks und Bedienleiste
            }

            if viewModel.state.isFinished {
                gameOverOverlay
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        // Während einer Partie liegt das Handy oft minutenlang unberührt auf
        // dem Tisch – ohne das müsste man vor jedem Wurf erst entsperren.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
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

    /// Abbrechen erfordert anderthalb Sekunden Halten – kurz genug, dass es
    /// nicht nervt, lang genug, dass ein versehentlicher Tipper mitten im
    /// Spiel die Partie nicht beendet. Der Knopf wächst dabei sichtbar an,
    /// damit erkennbar ist, dass gerade etwas passiert.
    private var abortButton: some View {
        ZStack {
            Circle()
                .fill(BeerStatsColor.accentSecondary.opacity(isHoldingAbort ? 0.2 : 0))
            Circle()
                .stroke(BeerStatsColor.textSecondary.opacity(0.25), lineWidth: 2)
            Circle()
                .trim(from: 0, to: abortProgress)
                .stroke(BeerStatsColor.accentSecondary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isHoldingAbort ? BeerStatsColor.accentSecondary : BeerStatsColor.textSecondary)
        }
        .frame(width: 36, height: 36)
        .scaleEffect(isHoldingAbort ? 1.45 : 1)
        .contentShape(Circle())
        // Bewusst die `pressing:perform:`-Variante: die neuere Schreibweise
        // mit `onPressingChanged:` gibt es erst ab iOS 17, das Deployment-
        // Target dieses Projekts ist iOS 16.
        .onLongPressGesture(
            minimumDuration: Self.abortHoldDuration,
            pressing: { isPressing in
                if isPressing { HapticManager.lightImpact() }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
                    isHoldingAbort = isPressing
                }
                withAnimation(.linear(duration: isPressing ? Self.abortHoldDuration : 0.2)) {
                    abortProgress = isPressing ? 1 : 0
                }
            },
            perform: {
                HapticManager.error()
                viewModel.abandonGame()
                dismiss()
            }
        )
        .accessibilityLabel("Spiel abbrechen, anderthalb Sekunden halten")
    }

    private var matchTitle: String {
        let first = viewModel.teams[0].playerNames.joined(separator: " & ")
        let second = viewModel.teams[1].playerNames.joined(separator: " & ")
        return "\(first)  vs  \(second)"
    }

    // MARK: - Team-Zeile

    /// Team-Leiste als eigenes Panel. Das Team am Zug leuchtet – dadurch ist
    /// aus Armlänge erkennbar, wer dran ist, ohne den Text zu lesen.
    private func teamBar(_ teamIndex: Int) -> some View {
        let isActive = !viewModel.state.isFinished && viewModel.state.turnTeamIndex == teamIndex
        let tint = teamIndex == 0 ? BeerStatsColor.accent : BeerStatsColor.accentSecondary
        let remaining = viewModel.state.racks[teamIndex].remainingCount
        let total = viewModel.state.racks[teamIndex].totalSlots

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(viewModel.teamName(teamIndex))
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .kerning(1.4)
                    .foregroundStyle(isActive ? tint : BeerStatsColor.textSecondary)

                // Fortschrittsbalken der abgeräumten Becher – zeigt den
                // Spielstand als Bild statt nur als Zahl.
                GeometryReader { geometry in
                    let ratio = total > 0 ? CGFloat(remaining) / CGFloat(total) : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(BeerStatsColor.textSecondary.opacity(0.15))
                        Capsule().fill(tint).frame(width: geometry.size.width * ratio)
                    }
                }
                .frame(height: 4)

                Text("\(remaining)")
                    .font(BeerStatsFont.statValue)
                    .foregroundStyle(isActive ? tint : BeerStatsColor.textSecondary)
                    .frame(minWidth: 26, alignment: .trailing)
            }

            HStack(spacing: 8) {
                ForEach(0..<viewModel.state.playersPerTeam, id: \.self) { slot in
                    playerChip(PlayerRef(teamIndex: teamIndex, slot: slot))
                }
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassPanel(cornerRadius: 16)
        .neonEdge(tint, cornerRadius: 16, intensity: isActive ? 0.9 : 0.18)
        .animation(AppAnimation.standard, value: isActive)
        .animation(AppAnimation.standard, value: remaining)
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
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(isActive ? BeerStatsColor.accent : Color.clear)
        )
        .overlay(
            Capsule().strokeBorder(
                isOnFire ? BeerStatsColor.accentSecondary : BeerStatsColor.textSecondary.opacity(0.25),
                lineWidth: isOnFire ? 1.5 : 1
            )
        )
        .foregroundStyle(isActive ? BeerStatsColor.textOnAccent : BeerStatsColor.textSecondary)
        // Wer dran ist, tritt spürbar hervor – am Tisch aus Armlänge lesbar.
        .scaleEffect(isActive ? 1.06 : 1)
        .shadow(color: isOnFire ? BeerStatsColor.accentSecondary.opacity(0.5) : .clear, radius: 7)
        .animation(AppAnimation.tap, value: isActive)
        .animation(AppAnimation.standard, value: isOnFire)
    }

    // MARK: - Zug-Anzeige

    /// Zeigt an, wer wirft. Bei Bonuswürfen wechselt die Umrandung auf die
    /// Akzentfarbe – man erkennt am Rand, dass gerade eine Sonderregel läuft,
    /// ohne den Text lesen zu müssen.
    private var turnPill: some View {
        let isSpecial = viewModel.state.pending != .normal

        return Text(viewModel.turnDescription)
            .font(BeerStatsFont.statLabel)
            .foregroundStyle(isSpecial ? BeerStatsColor.accent : BeerStatsColor.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(BeerStatsColor.surfaceElevated))
            .overlay(
                Capsule().strokeBorder(
                    isSpecial ? BeerStatsColor.accent : BeerStatsColor.textSecondary.opacity(0.15),
                    lineWidth: isSpecial ? 1.5 : 1
                )
            )
            .shadow(color: isSpecial ? BeerStatsColor.accent.opacity(0.35) : .clear, radius: 8)
            .animation(AppAnimation.standard, value: isSpecial)
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
                // Hintergrund und Trefferfläche liegen INNERHALB des Labels.
                // Läge der Hintergrund außerhalb, reagierte der Button nur
                // auf die Schrift selbst – und die Druck-Animation würde auch
                // nur den Text skalieren statt der ganzen Fläche.
                Button {
                    viewModel.perform(.miss)
                } label: {
                    Text("Daneben")
                        .font(BeerStatsFont.liveGameButton)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            BeerStatsColor.surfaceElevated,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
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
                .foregroundStyle(isOn ? BeerStatsColor.textOnAccent : BeerStatsColor.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(isOn ? BeerStatsColor.accent : Color.clear))
                .overlay(Capsule().strokeBorder(BeerStatsColor.textSecondary.opacity(0.25), lineWidth: 1))
                .contentShape(Capsule())
        }
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
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
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
                // Erst hier wird das Ergebnis festgeschrieben – vorher bleibt
                // „Rückgängig" gefahrlos möglich.
                PrimaryButton(title: "Ergebnis übernehmen", systemImage: "checkmark") {
                    viewModel.confirmResult()
                    dismiss()
                }

                if viewModel.isStartingRematch {
                    CupFillLoadingView(size: 44)
                } else {
                    Button {
                        Task { await viewModel.startRematch() }
                    } label: {
                        Label("Revanche, gleiche Aufstellung", systemImage: "arrow.counterclockwise")
                            .font(BeerStatsFont.headline)
                            .foregroundStyle(BeerStatsColor.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(BeerStatsColor.accent, lineWidth: 1.5)
                            )
                            // Ohne das wäre nur der gezeichnete Rahmen tastbar,
                            // die Fläche dazwischen bleibt sonst leer.
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                }

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
                            FormationPreview(rows: formation.rows, offsets: formation.resolvedRowOffsets)
                            Text(formation.name)
                                .font(BeerStatsFont.caption)
                                .foregroundStyle(BeerStatsColor.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            BeerStatsColor.surfaceElevated,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
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
    let offsets: [Double]

    private let dotSize: CGFloat = 9
    private let spacing: CGFloat = 3

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, count in
                HStack(spacing: spacing) {
                    ForEach(0..<count, id: \.self) { _ in
                        Circle()
                            .fill(BeerStatsColor.cupBase)
                            .frame(width: dotSize, height: dotSize)
                    }
                }
                // Ohne den Versatz sähen Quadrat und Berserker identisch aus.
                .offset(x: (dotSize + spacing) * shift(at: index))
            }
        }
        .frame(height: 46)
    }

    private func shift(at index: Int) -> CGFloat {
        offsets.indices.contains(index) ? CGFloat(offsets[index]) : 0
    }
}
