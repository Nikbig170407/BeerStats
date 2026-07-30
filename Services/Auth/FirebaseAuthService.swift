//
//  FirebaseAuthService.swift
//  BeerStats
//
//  Konkrete Firebase-Implementierung von AuthServiceProtocol.
//  Ausschließlich verantwortlich für den Auth-Account selbst (anlegen,
//  einloggen, ausloggen, löschen) – NICHT für das Firestore-Nutzerprofil,
//  das ist Aufgabe von UserService/AuthRepository.
//

import Foundation
import Combine
import FirebaseAuth

final class FirebaseAuthService: AuthServiceProtocol {

    private let authStateSubject = CurrentValueSubject<String?, Never>(nil)
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    var authStatePublisher: AnyPublisher<String?, Never> {
        authStateSubject.eraseToAnyPublisher()
    }

    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    init() {
        authStateSubject.send(Auth.auth().currentUser?.uid)
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            AppLogger.auth.info("Auth-Status geändert: \(user != nil ? "angemeldet" : "abgemeldet")")
            self?.authStateSubject.send(user?.uid)
        }
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
    }

    func signUp(email: String, password: String) async throws -> String {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            AppLogger.auth.info("Neuer Auth-Account angelegt")
            return result.user.uid
        } catch {
            throw AppError.from(error)
        }
    }

    func signIn(email: String, password: String) async throws -> String {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            return result.user.uid
        } catch {
            throw AppError.from(error)
        }
    }

    func signOut() throws {
        do {
            try Auth.auth().signOut()
        } catch {
            throw AppError.from(error)
        }
    }

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AppError.notAuthenticated
        }
        do {
            try await user.delete()
            // Hinweis: Die vollständige Kaskadenlöschung der Firestore-Daten
            // (Nutzerprofil, Spiele, Statistiken – DSGVO-Anforderung, siehe
            // Architektur-Dokument 8.) folgt über eine Cloud Function, die
            // auf die Auth-Löschung reagiert. Das ist bewusst noch nicht
            // Teil dieses Schritts.
        } catch {
            throw AppError.from(error)
        }
    }
}
