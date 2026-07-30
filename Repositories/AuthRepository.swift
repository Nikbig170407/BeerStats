//
//  AuthRepository.swift
//  BeerStats
//
//  Orchestriert AuthService (Firebase Auth) und UserService (Firestore-
//  Profil) zu einem einzigen, konsistenten Signup-Vorgang. ViewModels
//  sprechen ausschließlich mit diesem Repository, nie einzeln mit den
//  beiden darunterliegenden Services – das ist der Unterschied zwischen
//  Service (reine Kommunikation) und Repository (fachliche Logik), siehe
//  Architektur-Dokument, Abschnitt 1.
//

import Foundation
import Combine

protocol AuthRepositoryProtocol {
    var authStatePublisher: AnyPublisher<String?, Never> { get }
    func signUp(email: String, password: String, username: String, displayName: String) async throws
    func signIn(email: String, password: String) async throws
    func signOut() throws
}

final class AuthRepository: AuthRepositoryProtocol {

    private let authService: AuthServiceProtocol
    private let userService: UserServiceProtocol

    init(authService: AuthServiceProtocol, userService: UserServiceProtocol) {
        self.authService = authService
        self.userService = userService
    }

    var authStatePublisher: AnyPublisher<String?, Never> {
        authService.authStatePublisher
    }

    func signUp(email: String, password: String, username: String, displayName: String) async throws {
        let normalizedUsername = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedUsername.count >= AppConstants.Validation.usernameMinLength,
              normalizedUsername.count <= AppConstants.Validation.usernameMaxLength else {
            throw AppError.validation(
                "Nutzername muss zwischen \(AppConstants.Validation.usernameMinLength) und \(AppConstants.Validation.usernameMaxLength) Zeichen lang sein."
            )
        }
        guard !trimmedDisplayName.isEmpty else {
            throw AppError.validation("Bitte gib einen Anzeigenamen ein.")
        }

        let uid = try await authService.signUp(email: email, password: password)

        do {
            try await userService.createUserProfile(uid: uid, username: normalizedUsername, displayName: trimmedDisplayName)
        } catch {
            // Rollback: ein Auth-Account ohne zugehöriges Firestore-Profil
            // (z. B. weil der Nutzername inzwischen vergeben wurde) darf
            // nicht bestehen bleiben.
            AppLogger.auth.error("Profilerstellung fehlgeschlagen, mache Auth-Account rückgängig")
            try? await authService.deleteAccount()
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        _ = try await authService.signIn(email: email, password: password)
    }

    func signOut() throws {
        try authService.signOut()
    }
}
