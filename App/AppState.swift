//
//  AppState.swift
//  BeerStats
//
//  Zentraler, app-weiter Zustand. Bewusst schlank gehalten: Nur Zustand,
//  der wirklich von mehreren, nicht miteinander verwandten Features
//  gebraucht wird (z. B. Root-Navigation abhängig vom Login-Status).
//  Feature-spezifischer Zustand gehört in die jeweiligen ViewModels,
//  nicht hierher.
//

import Foundation
import Combine

/// Repräsentiert den Authentifizierungsstatus der App.
enum AuthState: Equatable {
    case unknown        // Initialzustand, bevor der erste Auth-Check abgeschlossen ist
    case signedOut
    case signedIn(userId: String)
}

@MainActor
final class AppState: ObservableObject {

    @Published private(set) var authState: AuthState = .unknown

    /// Falls der Nutzer ein Spiel verlässt und wiederkommt, kann die App
    /// direkt zum aktiven Spiel zurückspringen, statt zum Dashboard.
    @Published var activeGameId: String?

    private let authService: AuthServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(authService: AuthServiceProtocol) {
        self.authService = authService
        observeAuthChanges()
    }

    private func observeAuthChanges() {
        authService.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] userId in
                guard let self else { return }
                if let userId {
                    self.authState = .signedIn(userId: userId)
                } else {
                    self.authState = .signedOut
                    self.activeGameId = nil
                }
            }
            .store(in: &cancellables)
    }
}
