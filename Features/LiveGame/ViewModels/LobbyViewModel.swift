//
//  LobbyViewModel.swift
//  BeerStats
//
//  Beobachtet ein einzelnes Spiel live (Echtzeit-Stream). Nur der
//  Ersteller darf das Spiel aus der Lobby heraus starten – alle anderen
//  Teilnehmer sehen den Live-Zustand automatisch mit, sobald das Spiel
//  auf "active" wechselt (kein manuelles "Beitreten" nötig, da alle
//  Teilnehmer bereits bei der Erstellung festgelegt wurden).
//

import Foundation

@MainActor
final class LobbyViewModel: ObservableObject {

    @Published private(set) var game: Game?
    @Published var errorMessage: String?
    @Published private(set) var isStarting = false

    private let gameRepository: GameRepositoryProtocol
    let gameId: String
    let currentUserId: String
    private var observationTask: Task<Void, Never>?

    init(gameRepository: GameRepositoryProtocol, gameId: String, currentUserId: String) {
        self.gameRepository = gameRepository
        self.gameId = gameId
        self.currentUserId = currentUserId
        observe()
    }

    deinit {
        observationTask?.cancel()
    }

    var isCreator: Bool {
        game?.createdBy == currentUserId
    }

    private func observe() {
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await game in gameRepository.observeGame(gameId: gameId) {
                self.game = game
            }
        }
    }

    func startGame() async {
        isStarting = true
        defer { isStarting = false }
        do {
            try await gameRepository.startGame(gameId: gameId)
            HapticManager.success()
        } catch {
            errorMessage = AppError.from(error).errorDescription
        }
    }
}
