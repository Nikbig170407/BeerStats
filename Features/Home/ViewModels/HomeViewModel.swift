//
//  HomeViewModel.swift
//  BeerStats
//
//  Beobachtet alle nicht abgeschlossenen Spiele des Nutzers live, damit
//  der Home-Screen sofort aktualisiert, sobald z. B. ein Freund ein neues
//  gemeinsames Spiel erstellt.
//

import Foundation

@MainActor
final class HomeViewModel: ObservableObject {

    @Published private(set) var games: [Game] = []

    /// Das zuletzt begonnene, noch laufende Spiel.
    ///
    /// Bewusst nur eines statt einer Liste: Es läuft immer höchstens eine
    /// Partie. Der Eintrag existiert allein dafür, dass eine angefangene
    /// Runde nach einem versehentlichen Verlassen weitergehen kann.
    var resumableGame: Game? {
        games.first { $0.status == .active || $0.status == .lobby }
    }

    /// Mitspieler-Profile, damit der Startbildschirm eine Übersicht zeigen
    /// kann statt nur zwei Knöpfe.
    @Published private(set) var profiles: [PlayerProfile] = []

    private let gameRepository: GameRepositoryProtocol
    private let profileRepository: PlayerProfileRepositoryProtocol
    let currentUserId: String
    private var observationTask: Task<Void, Never>?
    private var profileTask: Task<Void, Never>?

    init(
        gameRepository: GameRepositoryProtocol,
        profileRepository: PlayerProfileRepositoryProtocol,
        currentUserId: String
    ) {
        self.gameRepository = gameRepository
        self.profileRepository = profileRepository
        self.currentUserId = currentUserId
        observe()
        observeProfiles()
    }

    deinit {
        observationTask?.cancel()
        profileTask?.cancel()
    }

    // MARK: - Überblick für den Startbildschirm

    var activeProfiles: [PlayerProfile] { profiles.filter(\.isActive) }

    var totalGamesTracked: Int {
        // Jede Partie taucht bei mehreren Profilen auf – durch die Teamgröße
        // teilen ergäbe je nach Modus falsche Werte, deshalb die höchste
        // Einzelzahl als verlässliche Untergrenze.
        profiles.map(\.statistics.gamesPlayed).max() ?? 0
    }

    /// Wer aktuell vorn liegt: meiste Siege, bei Gleichstand bessere Quote.
    var leadingProfile: PlayerProfile? {
        profiles
            .filter { $0.statistics.gamesPlayed > 0 }
            .max { left, right in
                (left.statistics.gamesWon, left.winRate) < (right.statistics.gamesWon, right.winRate)
            }
    }

    private func observeProfiles() {
        profileTask = Task { [weak self] in
            guard let self else { return }
            for await profiles in profileRepository.observeProfiles(ownerId: currentUserId) {
                self.profiles = profiles
            }
        }
    }

    private func observe() {
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await games in gameRepository.observeUserGames(currentUserId: currentUserId) {
                self.games = games.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            }
        }
    }
}
