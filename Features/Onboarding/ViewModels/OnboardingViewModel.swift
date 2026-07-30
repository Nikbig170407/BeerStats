//
//  OnboardingViewModel.swift
//  BeerStats
//
//  Steuert sowohl Login als auch Registrierung über einen gemeinsamen
//  Modus-Schalter, statt zwei fast identische ViewModels zu pflegen.
//  Spricht ausschließlich mit AuthRepository, nie direkt mit Firebase.
//

import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {

    enum Mode {
        case signIn
        case signUp
    }

    @Published var mode: Mode = .signIn
    @Published var email = ""
    @Published var password = ""
    @Published var username = ""
    @Published var displayName = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    var submitButtonTitle: String {
        mode == .signIn ? "Anmelden" : "Konto erstellen"
    }

    var toggleModeButtonTitle: String {
        mode == .signIn ? "Neu hier? Konto erstellen" : "Schon ein Konto? Anmelden"
    }

    func toggleMode() {
        errorMessage = nil
        mode = (mode == .signIn) ? .signUp : .signIn
    }

    func submit() async {
        errorMessage = nil

        guard !email.trimmingCharacters(in: .whitespaces).isEmpty, !password.isEmpty else {
            errorMessage = AppError.validation("Bitte E-Mail und Passwort ausfüllen.").errorDescription
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            switch mode {
            case .signIn:
                try await authRepository.signIn(email: email, password: password)
            case .signUp:
                try await authRepository.signUp(
                    email: email,
                    password: password,
                    username: username,
                    displayName: displayName
                )
            }
        } catch {
            HapticManager.error()
            errorMessage = AppError.from(error).errorDescription
        }
    }
}
