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

    private let gameRepository: GameRepositoryProtocol
    let currentUserId: String
    private var observationTask: Task<Void, Never>?

    init(gameRepository: GameRepositoryProtocol, currentUserId: String) {
        self.gameRepository = gameRepository
        self.currentUserId = currentUserId
        observe()
    }

    deinit {
        observationTask?.cancel()
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
