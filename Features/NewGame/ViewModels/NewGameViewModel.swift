//
//  NewGameViewModel.swift
//  BeerStats
//
//  Modus, Becherzahl und Spielerauswahl für ein neues Spiel.
//
//  Die Mitspieler kommen aus den Profilen, nicht aus der Freundesliste: In
//  dieser Ausbaustufe liegt die App nur auf einem Gerät, und nur über die
//  Profile lassen sich die Statistiken am Spielende den richtigen Leuten
//  zuordnen.
//
//  Wichtig für das Verständnis des Datenmodells: `Team.playerIds` enthält
//  hier Profil-IDs, also Leute ohne eigenes Konto. Die Zugriffsberechtigung
//  auf das Spiel-Dokument hängt deshalb nicht daran, sondern wird separat
//  als Konto-ID übergeben (siehe Game.allPlayerIds).
//

import Foundation

@MainActor
final class NewGameViewModel: ObservableObject {

    @Published var gameType: GameType = .twoVsTwo {
        didSet { resetSelection() }
    }
    /// Die Hausregeln dieses Tisches, Becherzahl inklusive.
    ///
    /// Kommt aus UserDefaults und geht bei jeder Aenderung dorthin zurueck:
    /// Wer ohne Bounce spielt, will das nicht vor jeder Partie neu einstellen.
    /// Der Vorsprung steht bewusst NICHT hier drin, sondern kommt erst in
    /// `format` dazu – er gehoert zur Aufstellung, nicht zum Tisch.
    @Published var houseRules: GameFormat = .houseRules {
        didSet { GameFormat.houseRules = houseRules }
    }

    /// Ob der vorgeschlagene Ausgleich angenommen wurde.
    ///
    /// Bewusst ein Ja/Nein und nicht der fertige Vorsprung. Wuerde hier
    /// `[2, 0]` stehen, ueberlebte dieser Wert jede Aenderung an der
    /// Aufstellung: Wechselt man auf 1 gegen 1 oder setzt jemanden ohne
    /// belastbare Quote ein, verschwindet der Vorschlag aus der Ansicht - der
    /// angenommene Vorsprung bliebe aber gesetzt, und die Partie startete mit
    /// einem Handicap, das nirgends mehr steht. So kann das nicht passieren:
    /// Gibt es keinen Vorschlag, gibt es auch keinen Vorsprung.
    @Published var isHandicapAccepted = false

    /// Die Becherzahl. Steht in den Hausregeln, wird aber eine Ebene hoeher
    /// im Screen entschieden – anders als die Sonderregeln aendert sie sich
    /// oft genug, um jedes Mal sichtbar zu sein.
    var cupCount: Int { houseRules.cupCount }

    /// Das Regelwerk dieser Partie – an genau EINER Stelle.
    ///
    /// Vorher wurde es zweimal gebaut: hier fuer Firestore und noch einmal in
    /// der View fuer den Live-Screen. Solange beide nur `cupCount` setzten,
    /// fiel das nicht auf. Beim ersten Wert, der nur an einer der beiden
    /// Stellen ankommt, laufen gespielte Partie und nachgespielte Historie
    /// auseinander - und zwar lautlos, weil beide fuer sich stimmig aussehen.
    var format: GameFormat {
        var laufend = houseRules
        laufend.handicapByTeam = acceptedHandicap
        return laufend
    }

    /// Der tatsaechlich geltende Vorsprung – nur, wenn der Vorschlag noch
    /// steht UND angenommen wurde.
    var acceptedHandicap: [Int]? {
        guard isHandicapAccepted, let vorschlag = suggestedHandicap else { return nil }
        var werte = [0, 0]
        werte[vorschlag.teamIndex] = vorschlag.cups
        return werte
    }

    /// Durchschnittliche Trefferquote eines Teams, sofern belastbar.
    ///
    /// Profile mit zu wenigen Wuerfen bleiben aussen vor: Wer dreimal
    /// geworfen und zweimal getroffen hat, steht mit 67 Prozent da und wuerde
    /// jeden Vorschlag verzerren.
    func teamHitRate(_ teamIndex: Int) -> Double? {
        guard selection.indices.contains(teamIndex) else { return nil }

        let rates = selection[teamIndex]
            .compactMap { $0 }
            .compactMap { id in profiles.first { $0.id == id } }
            .filter { $0.statistics.totalThrows >= AppConstants.GameDefaults.minimumThrowsForHandicap }
            .map(\.statistics.hitRate)

        guard !rates.isEmpty else { return nil }
        return rates.reduce(0, +) / Double(rates.count)
    }

    /// Welches Team wie viele Becher abgeben sollte – oder `nil`.
    ///
    /// Fuenf Prozentpunkte Unterschied entsprechen einem Becher, gedeckelt
    /// bei dreien. Der Deckel ist wichtiger als die Formel: Ein Vorsprung von
    /// der halben Rackgroesse waere kein Ausgleich mehr, sondern ein anderes
    /// Spiel.
    var suggestedHandicap: (teamIndex: Int, cups: Int)? {
        guard let first = teamHitRate(0), let second = teamHitRate(1) else { return nil }

        let unterschied = first - second
        let becher = min(3, Int(abs(unterschied) / 0.05))
        guard becher > 0 else { return nil }

        // Abgeben muss das staerkere Team.
        return (unterschied > 0 ? 0 : 1, becher)
    }

    @Published private(set) var profiles: [PlayerProfile] = []
    /// Gewählte Profil-IDs, `selection[teamIndex][slot]`.
    @Published private(set) var selection: [[String?]] = []

    @Published private(set) var isLoading = true
    @Published private(set) var isCreating = false
    @Published var errorMessage: String?
    @Published private(set) var createdGameId: String?
    /// Die fertige Aufstellung – wird direkt an den Spielscreen
    /// weitergereicht, damit dieser das Spiel nicht erneut laden muss.
    @Published private(set) var createdTeams: [Team] = []

    private let gameRepository: GameRepositoryProtocol
    private let profileRepository: PlayerProfileRepositoryProtocol
    let currentUserId: String
    private var observationTask: Task<Void, Never>?

    init(
        gameRepository: GameRepositoryProtocol,
        profileRepository: PlayerProfileRepositoryProtocol,
        currentUserId: String
    ) {
        self.gameRepository = gameRepository
        self.profileRepository = profileRepository
        self.currentUserId = currentUserId
        resetSelection()
        observeProfiles()
    }

    deinit {
        observationTask?.cancel()
    }

    // MARK: - Abgeleitete Werte

    var playersPerTeam: Int {
        gameType == .oneVsOne ? 1 : 2
    }

    /// Nur aktive Profile treten an – ausgemusterte Mitspieler sollen nicht
    /// versehentlich wieder in einer Aufstellung landen.
    var selectableProfiles: [PlayerProfile] {
        profiles.filter(\.isActive)
    }

    private var assignedIds: Set<String> {
        Set(selection.flatMap { $0 }.compactMap { $0 })
    }

    /// Profile, die noch keinem Platz zugeordnet sind.
    var unassignedProfiles: [PlayerProfile] {
        selectableProfiles.filter { profile in
            guard let id = profile.id else { return false }
            return !assignedIds.contains(id)
        }
    }

    func profile(withId id: String?) -> PlayerProfile? {
        guard let id else { return nil }
        return profiles.first { $0.id == id }
    }

    func profile(teamIndex: Int, slot: Int) -> PlayerProfile? {
        guard selection.indices.contains(teamIndex),
              selection[teamIndex].indices.contains(slot) else { return nil }
        return profile(withId: selection[teamIndex][slot])
    }

    var canCreateGame: Bool {
        !isCreating && selection.allSatisfy { team in
            team.allSatisfy { $0 != nil }
        }
    }

    var hasEnoughProfiles: Bool {
        selectableProfiles.count >= playersPerTeam * 2
    }

    // MARK: - Auswahl

    func assign(profileId: String, teamIndex: Int, slot: Int) {
        guard selection.indices.contains(teamIndex),
              selection[teamIndex].indices.contains(slot) else { return }
        // Falls das Profil woanders steht, dort zuerst entfernen – ein
        // Spieler kann nicht gleichzeitig in beiden Teams antreten.
        for team in selection.indices {
            for position in selection[team].indices where selection[team][position] == profileId {
                selection[team][position] = nil
            }
        }
        selection[teamIndex][slot] = profileId
        HapticManager.lightImpact()
    }

    func clear(teamIndex: Int, slot: Int) {
        guard selection.indices.contains(teamIndex),
              selection[teamIndex].indices.contains(slot) else { return }
        selection[teamIndex][slot] = nil
        HapticManager.lightImpact()
    }

    func clearCreatedGame() {
        createdGameId = nil
    }

    /// Übernimmt eine ausgeloste Aufstellung aus dem Glücksrad.
    func applyDrawnLineup(_ teams: [[String]]) {
        resetSelection()
        for teamIndex in teams.indices where selection.indices.contains(teamIndex) {
            for (slot, profileId) in teams[teamIndex].enumerated()
            where selection[teamIndex].indices.contains(slot) {
                selection[teamIndex][slot] = profileId
            }
        }
        HapticManager.success()
    }

    private func resetSelection() {
        selection = Array(
            repeating: Array(repeating: nil, count: playersPerTeam),
            count: 2
        )
    }

    private func observeProfiles() {
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await profiles in profileRepository.observeProfiles(ownerId: currentUserId) {
                self.profiles = profiles
                self.isLoading = false
            }
        }
    }

    // MARK: - Anlegen

    func createGame() async {
        guard canCreateGame else {
            errorMessage = "Bitte besetze alle Plätze."
            return
        }

        isCreating = true
        defer { isCreating = false }

        do {
            let teams: [Team] = try selection.map { slots in
                let chosen = slots.compactMap { profile(withId: $0) }
                guard chosen.count == playersPerTeam else {
                    throw AppError.validation("Ein Team ist nicht vollständig besetzt.")
                }
                return Team(
                    id: UUID().uuidString,
                    playerIds: chosen.compactMap(\.id),
                    playerNames: chosen.map(\.name),
                    ballsInPlay: chosen.count
                )
            }

            let gameId = try await gameRepository.createGame(
                type: gameType,
                teams: teams,
                format: format,
                createdBy: currentUserId,
                // Nur mein Konto darf das Spiel lesen und schreiben – die
                // Mitspieler sind Profile ohne eigenen Zugang.
                accessUserIds: [currentUserId]
            )
            // Direkt aktiv setzen: Eine Lobby, in der auf Mitspieler gewartet
            // wird, ergibt keinen Sinn, wenn die App nur auf einem Gerät liegt.
            try await gameRepository.startGame(gameId: gameId)

            createdTeams = teams
            createdGameId = gameId
            HapticManager.success()
        } catch {
            HapticManager.error()
            errorMessage = AppError.from(error).errorDescription
        }
    }
}
