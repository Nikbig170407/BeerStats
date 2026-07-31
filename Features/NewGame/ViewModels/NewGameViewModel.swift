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
    @Published var cupCount: Int = AppConstants.GameDefaults.standardCupCount

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
                format: GameFormat(cupCount: cupCount),
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
