//
//  UserServiceProtocol.swift
//  BeerStats
//
//  Kapselt alle Firestore-Zugriffe rund um das User-Dokument. Getrennt von
//  AuthService, da Authentifizierung (Firebase Auth) und Nutzerprofil
//  (Firestore) zwei unterschiedliche Verantwortlichkeiten sind.
//

import Foundation

protocol UserServiceProtocol {

    /// Legt Nutzername-Reservierung + Nutzerprofil atomar an (Firestore-
    /// Transaktion). Wirft einen Fehler, falls der Nutzername bereits
    /// vergeben ist.
    func createUserProfile(uid: String, username: String, displayName: String) async throws

    func fetchUser(uid: String) async throws -> User

    /// Batch-Abruf mehrerer Profile auf einmal (z. B. um Anzeigenamen für
    /// eine Freundesliste zu laden) – vermeidet N einzelne Requests.
    func fetchUsers(uids: [String]) async throws -> [User]

    /// Präfix-Suche über den (lowercased) Nutzernamen, für die
    /// Freunde-Suche.
    func searchUsers(usernamePrefix: String) async throws -> [User]
}
