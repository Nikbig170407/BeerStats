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

    /// Spielt gerade jemand ohne Konto?
    ///
    /// Steht neben `authState` und nicht darin: Abgemeldet heisst "will sich
    /// anmelden und ist noch nicht fertig", Gast heisst "will gar kein
    /// Konto". Beides fuehrt an verschiedene Orte (siehe `GuestMode`).
    @Published private(set) var isGuest: Bool = GuestMode.isOn

    /// Falls der Nutzer ein Spiel verlässt und wiederkommt, kann die App
    /// direkt zum aktiven Spiel zurückspringen, statt zum Dashboard.
    @Published var activeGameId: String?

    private let authService: AuthServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(authService: AuthServiceProtocol) {
        self.authService = authService
        observeAuthChanges()
    }

    /// Ohne Konto weiter. Ueberlebt den App-Start, sonst stuende beim
    /// naechsten Aufmachen wieder das Formular da.
    func enterGuestMode() {
        GuestMode.isOn = true
        isGuest = true
    }

    /// Zurueck zum Anmelden – aus den Einstellungen heraus.
    func leaveGuestMode() {
        GuestMode.isOn = false
        isGuest = false
    }

    private func observeAuthChanges() {
        authService.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] userId in
                guard let self else { return }
                if let userId {
                    self.authState = .signedIn(userId: userId)
                    // Wer sich anmeldet, ist kein Gast mehr – sonst landete
                    // er nach dem naechsten Abmelden wieder im Hauptmenue
                    // statt im Formular.
                    if self.isGuest { self.leaveGuestMode() }
                } else {
                    self.authState = .signedOut
                    self.activeGameId = nil
                }
            }
            .store(in: &cancellables)
    }
}
