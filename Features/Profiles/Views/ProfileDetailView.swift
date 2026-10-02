//
//  ProfileDetailView.swift
//  BeerStats
//
//  Die Statistik eines Mitspielers.
//
//  Aufbau bewusst nach Wichtigkeit statt nach Datenstruktur: Ganz oben die
//  Trefferquote als gefüllter Becher – die eine Zahl, über die am Tisch
//  geredet wird. Danach das Spielergebnis, dann die Spezialwürfe, zuletzt
//  die Serien.
//

import SwiftUI

struct ProfileDetailView: View {

    let profile: PlayerProfile
    /// Alle übrigen Mitspieler – Auswahl für den Direktvergleich.
    let otherProfiles: [PlayerProfile]
    let gameRepository: GameRepositoryProtocol
    let throwRepository: ThrowRepositoryProtocol
    let ownerId: String
    let onEdit: () -> Void

    @State private var period: StatisticsPeriod = .allTime
    @State private var periodStats: UserStatistics?
    @State private var isLoadingPeriod = false
    @State private var trend: [TrendPoint] = []

    /// Mit wem gewonnen, gegen wen verloren. Faellt beim selben Abruf ab wie
    /// der Verlauf – die Rechnung braucht nur die Aufstellungen, keinen
    /// einzigen Wurf-Log.
    @State private var chemistry: TeamChemistry?

    /// Trefferquote nach Tageszeit. Wird erst auf Anforderung geladen – sie
    /// liest jeden Wurf-Log einzeln und kostet so viele Zugriffe wie die
    /// Zeitraum-Statistik.
    @State private var timeSlots: [TimeSlotStats] = []
    @State private var isLoadingTimeSlots = false
    @State private var hasLoadedTimeSlots = false

    /// Bei „Gesamt" die am Profil gespeicherten Summen, sonst die aus dem
    /// Wurf-Log neu gerechneten Werte. Die gespeicherten Summen sind
    /// Lebenszeit-Werte und lassen sich nicht nachträglich zerlegen –
    /// deshalb der Umweg über den Log, der dafür rückwirkend gilt.
    private var stats: UserStatistics {
        period == .allTime ? profile.statistics : (periodStats ?? UserStatistics())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                periodPicker
                hitRateGauge

                if stats.gamesPlayed == 0 {
                    emptyState
                } else {
                    resultSection
                    trendSection
                    arsenalSection
                    chemistrySection
                    timeOfDaySection
                    streakSection
                    achievementSection
                }

                if stats.totalHits > 0 {
                    heatmapLink
                }

                if !otherProfiles.isEmpty {
                    comparisonSection
                }
            }
            .padding(20)
        }
        .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadFromFinishedGames() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Bearbeiten", action: onEdit)
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.accent)
            }
        }
    }

    // MARK: - Kopf

    private var header: some View {
        VStack(spacing: 10) {
            ProfileAvatarView(profile: profile, size: 88)
            Text(profile.name)
                .font(BeerStatsFont.largeTitle)
                .foregroundStyle(BeerStatsColor.textPrimary)
            if !profile.isActive {
                Text("Spielt aktuell nicht mit")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
        }
        .padding(.top, 8)
    }

    private var periodPicker: some View {
        VStack(spacing: 8) {
            Picker("Zeitraum", selection: $period) {
                ForEach(StatisticsPeriod.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            if isLoadingPeriod {
                Text("Werte werden aus dem Spielverlauf gerechnet…")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
        }
        .onChange(of: period) { newValue in
            guard newValue != .allTime else { return }
            Task { await loadPeriodStatistics() }
        }
    }

    /// Rechnet die Werte für den gewählten Zeitraum aus den Partien.
    ///
    /// Absichtlich erst bei Bedarf und nicht beim Öffnen: Für „Gesamt"
    /// liegen die Zahlen schon am Profil, und der Log muss dafür gar nicht
    /// angefasst werden.
    private func loadPeriodStatistics() async {
        guard let profileId = profile.id else { return }
        isLoadingPeriod = true
        defer { isLoadingPeriod = false }
        do {
            let games = try await gameRepository.fetchFinishedGames(userId: ownerId)
            periodStats = try await throwRepository.aggregateStatistics(
                profileId: profileId,
                games: period.filter(games)
            )
        } catch {
            AppLogger.firestore.error("Zeitraum-Werte nicht ladbar: \(error.localizedDescription)")
        }
    }

    /// Auszeichnungen werden nicht gespeichert, sondern aus den Zahlen
    /// abgeleitet. Sie gelten deshalb immer fuer den gewaehlten Zeitraum –
    /// im Monatsfilter steht hier, was in diesem Monat gelungen ist.
    private var achievementSection: some View {
        let earned = Achievements.lifetime(for: stats)

        return VStack(alignment: .leading, spacing: 10) {
            Text("AUSZEICHNUNGEN")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .kerning(1.8)
                .foregroundStyle(BeerStatsColor.textSecondary)

            if earned.isEmpty {
                Text(Achievements.next(for: stats) ?? "Noch nichts freigespielt.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                AchievementRow(achievements: earned, tint: profile.color.color)

                if let next = Achievements.next(for: stats) {
                    Text(next)
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Der Verlauf der letzten Partien.
    ///
    /// Erst ab drei Punkten: Zwei Werte ergeben eine Gerade, und eine Gerade
    /// zeigt keinen Verlauf, sondern nur zwei Zahlen mit einem Strich dazwischen.
    @ViewBuilder
    private var trendSection: some View {
        if trend.count >= 3 {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("VERLAUF")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .kerning(1.8)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                    Spacer()
                    Text("letzte \(trend.count) Partien")
                        .font(BeerStatsFont.statLabel)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }

                HitRateTrendChart(points: trend, tint: profile.color.color)
                    .padding(.vertical, 4)

                Text("Gefüllt heißt gewonnen. Die gestrichelte Linie ist die Hälfte.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassPanel(cornerRadius: 18)
        }
    }

    // MARK: - Team-Chemie

    /// Die Frage, die am Tisch beim Auslosen wirklich gestellt wird.
    @ViewBuilder
    private var chemistrySection: some View {
        if let chemistry, !chemistry.partners.isEmpty || !chemistry.opponents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("TEAM-CHEMIE")
                    .font(BeerStatsFont.statLabel)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                if let partner = chemistry.bestPartner {
                    pairingRow(
                        emoji: "🤝",
                        label: "Bester Partner",
                        pairing: partner,
                        tint: BeerStatsColor.success
                    )
                }

                if let gegner = chemistry.worstOpponent {
                    pairingRow(
                        emoji: "😤",
                        label: "Schlimmster Gegner",
                        pairing: gegner,
                        tint: BeerStatsColor.error
                    )
                }

                if chemistry.bestPartner == nil && chemistry.worstOpponent == nil {
                    Text("Noch zu wenige gemeinsame Partien. Ab \(AppConstants.GameDefaults.minimumGamesForChemistry) mit derselben Person steht hier etwas.")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassPanel(cornerRadius: 18)
        }
    }

    private func pairingRow(
        emoji: String,
        label: String,
        pairing: Pairing,
        tint: Color
    ) -> some View {
        let gegenueber = otherProfiles.first { $0.id == pairing.profileId }

        return HStack(spacing: 12) {
            Text(emoji).font(.system(size: 24)).frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(BeerStatsFont.statLabel)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                // Ein geloeschtes Profil steht weiter in alten Partien. Es
                // zu verschweigen waere falsch, es als Namen auszugeben
                // auch.
                Text(gegenueber?.name ?? "Nicht mehr dabei")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(pairing.winRate.map { "\(Int(($0 * 100).rounded())) %" } ?? "–")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                Text("\(pairing.wins) von \(pairing.games)")
                    .font(BeerStatsFont.statLabel)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
        }
    }

    // MARK: - Nach Uhrzeit

    /// Die ehrlichste Statistik, die diese App hat: nicht wer besser wirft,
    /// sondern was der Abend aus einem macht.
    private var timeOfDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NACH UHRZEIT")
                .font(BeerStatsFont.statLabel)
                .foregroundStyle(BeerStatsColor.textSecondary)

            if hasLoadedTimeSlots {
                if timeSlots.isEmpty {
                    Text("Keine Würfe mit Zeitstempel gefunden.")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                } else {
                    ForEach(timeSlots) { slot in
                        timeSlotRow(slot)
                    }

                    Text("Ab \(AppConstants.GameDefaults.minimumThrowsPerTimeSlot) Würfen steht eine Quote da. Darunter nur die Zahl – eine Quote aus fünf Würfen sieht aus wie eine Messung und ist geraten.")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            } else if isLoadingTimeSlots {
                CupFillLoadingView(size: 44)
                    .frame(maxWidth: .infinity)
            } else {
                Button {
                    Task { await loadTimeSlots() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "clock")
                        Text("Auswerten")
                            .font(BeerStatsFont.headline)
                        Spacer()
                        Text("liest die Wurf-Logs")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(profile.color.color)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .glassPanel(cornerRadius: 14)
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassPanel(cornerRadius: 18)
    }

    private func timeSlotRow(_ slot: TimeSlotStats) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(slot.title)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .monospacedDigit()

                Spacer()

                Text(slot.hitRate.map { "\(Int(($0 * 100).rounded())) %" } ?? "–")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        slot.hitRate == nil ? BeerStatsColor.textSecondary : profile.color.color
                    )

                Text("\(slot.attempts) Würfe")
                    .font(BeerStatsFont.statLabel)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .frame(width: 72, alignment: .trailing)
            }

            // Balkenlaenge ist die Quote selbst, nicht auf den besten Wert
            // gestreckt: Ein halb voller Balken soll fünfzig Prozent heissen,
            // egal wie die anderen Fenster aussehen.
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(BeerStatsColor.surfaceElevated.opacity(0.6))
                    Capsule()
                        .fill(profile.color.color)
                        .frame(width: geometry.size.width * (slot.hitRate ?? 0))
                }
            }
            .frame(height: 7)
        }
    }

    private func loadTimeSlots() async {
        guard let profileId = profile.id, !isLoadingTimeSlots else { return }
        isLoadingTimeSlots = true
        defer {
            isLoadingTimeSlots = false
            hasLoadedTimeSlots = true
        }

        do {
            let games = try await gameRepository.fetchFinishedGames(userId: ownerId)
            timeSlots = try await throwRepository.hitRateByTimeOfDay(
                profileId: profileId,
                games: period.filter(games)
            )
        } catch {
            AppLogger.firestore.error("Tageszeit nicht ladbar: \(error.localizedDescription)")
        }
    }

    /// Laeuft einmal beim Oeffnen.
    ///
    /// Holt die abgeschlossenen Partien einmal und wertet beides daraus aus.
    /// Die Team-Chemie ist dabei geschenkt: Sie braucht nur die
    /// Aufstellungen, die in den Partien ohnehin stehen. Der Verlauf liest
    /// zusaetzlich pro Partie den Wurf-Log – das kostet Lesezugriffe,
    /// deshalb gedeckelt auf fuenfzehn.
    private func loadFromFinishedGames() async {
        guard let profileId = profile.id, trend.isEmpty else { return }
        do {
            let games = try await gameRepository.fetchFinishedGames(userId: ownerId)
            chemistry = TeamChemistry(profileId: profileId, games: games)
            trend = try await throwRepository.hitRateTrend(
                profileId: profileId,
                games: games,
                limit: 15
            )
        } catch {
            AppLogger.firestore.error("Verlauf nicht ladbar: \(error.localizedDescription)")
        }
    }

    private var hitRateGauge: some View {
        CupFillGauge(
            fillLevel: stats.hitRate,
            size: 132,
            tint: profile.color.color,
            caption: "Trefferquote"
        )
    }

    private var emptyState: some View {
        BeerStatsCard {
            VStack(spacing: 6) {
                Text("Noch kein Spiel gewertet")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text("Sobald \(profile.name) ein Spiel zu Ende gespielt hat, stehen hier die Zahlen.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Abschnitte

    private var resultSection: some View {
        section("Bilanz") {
            HStack(spacing: 12) {
                statTile("\(stats.gamesPlayed)", label: "Spiele")
                statTile("\(stats.gamesWon)", label: "Siege")
                statTile(percent(profile.winRate), label: "Siegquote")
            }
        }
    }

    private var arsenalSection: some View {
        section("Wurf-Arsenal") {
            rowList {
                statRow("Treffer", value: "\(stats.totalHits) von \(stats.totalThrows)")
                divider
                statRow("Bounce Shots", value: "\(stats.totalBounceShotsMade)")
                divider
                statRow("Trickshots", value: "\(stats.totalTrickshotsMade)")
                divider
                statRow("Airballs", value: "\(stats.totalAirballs)", tint: BeerStatsColor.error)
            }
        }
    }

    private var streakSection: some View {
        section("Serien") {
            rowList {
                statRow("Längste On-Fire-Serie", value: "\(stats.longestOnFireStreak)", tint: BeerStatsColor.accent)
                divider
                statRow("Aktuelle Siegesserie", value: "\(stats.currentWinStreak)")
                divider
                statRow("Längste Siegesserie", value: "\(stats.longestWinStreak)")
            }
        }
    }

    /// Eigener Container statt BeerStatsCard: Die Zeilen bringen ihren
    /// Innenabstand selbst mit, damit die Trennlinien über die volle Breite
    /// laufen können.
    private func rowList<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            BeerStatsColor.surfaceElevated,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private var heatmapLink: some View {
        section("Trefferbild") {
            NavigationLink {
                CupHeatmapView(
                    profile: profile,
                    gameRepository: gameRepository,
                    throwRepository: throwRepository,
                    ownerId: ownerId
                )
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 22))
                        .foregroundStyle(BeerStatsColor.cupBase)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auf welche Becher trifft \(profile.name)?")
                            .font(BeerStatsFont.body)
                            .foregroundStyle(BeerStatsColor.textPrimary)
                            .lineLimit(1)
                        Text("Verteilung aus dem Wurf-Log")
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
                .padding(14)
                .glassPanel(cornerRadius: 14)
                .neonEdge(BeerStatsColor.cupBase, cornerRadius: 14, intensity: 0.35)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    /// Direktvergleich gegen jeden anderen Mitspieler.
    ///
    /// Bewusst als direkte Links statt über eine Auswahl mit Zustand:
    /// `navigationDestination(item:)` gibt es erst ab iOS 17, das Ziel
    /// dieses Projekts ist iOS 16.
    private var comparisonSection: some View {
        section("Direktvergleich") {
            VStack(spacing: 8) {
                ForEach(otherProfiles) { opponent in
                    NavigationLink {
                        HeadToHeadView(
                            left: profile,
                            right: opponent,
                            gameRepository: gameRepository,
                            ownerId: ownerId
                        )
                    } label: {
                        HStack(spacing: 12) {
                            ProfileAvatarView(profile: opponent, size: 36)
                            Text("gegen \(opponent.name)")
                                .font(BeerStatsFont.body)
                                .foregroundStyle(BeerStatsColor.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(BeerStatsColor.textSecondary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            BeerStatsColor.surfaceElevated,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    // MARK: - Bausteine

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(BeerStatsFont.statLabel)
                .foregroundStyle(BeerStatsColor.accent)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statTile(_ value: String, label: String) -> some View {
        BeerStatsCard {
            VStack(spacing: 4) {
                Text(value)
                    .font(BeerStatsFont.statValue)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text(label)
                    .font(BeerStatsFont.statLabel)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func statRow(_ label: String, value: String, tint: Color = BeerStatsColor.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textSecondary)
            Spacer()
            Text(value)
                .font(BeerStatsFont.statValue)
                .foregroundStyle(tint)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    private var divider: some View {
        Rectangle()
            .fill(BeerStatsColor.textSecondary.opacity(0.12))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
