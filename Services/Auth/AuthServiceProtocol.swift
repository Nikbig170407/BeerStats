//
//  AuthServiceProtocol.swift
//  BeerStats
//
//  Protokoll statt konkreter Firebase-Klasse: ViewModels sprechen nur mit
//  diesem Interface, nie direkt mit FirebaseAuth. Dadurch lassen sie sich
//  in Tests mit einem Mock füttern, und ein späterer Wechsel/Ausbau der
//  Auth-Anbindung betrifft ausschließlich die konkrete Implementierung.
//
//  Nutzt E-Mail/Passwort statt Sign in with Apple (siehe Entscheidung beim
//  Cloud-Build-Setup: Sideloading mit kostenloser Apple-ID unterstützt
//  bestimmte Capabilities nicht zuverlässig, E-Mail/Passwort ist dafür
//  uneingeschränkt kompatibel).
//

import Foundation
import Combine

protocol AuthServiceProtocol {

    /// Sendet die aktuelle User-ID (oder nil, wenn ausgeloggt) bei jeder
    /// Änderung des Auth-Zustands. Wird vom AppState abonniert.
    var authStatePublisher: AnyPublisher<String?, Never> { get }

    var currentUserId: String? { get }

    /// Legt einen neuen Firebase-Auth-Account an. Gibt die neue User-ID
    /// zurück. Erstellt bewusst NUR den Auth-Account, nicht das Firestore-
    /// Nutzerprofil – das übernimmt AuthRepository, damit dieser Service
    /// ausschließlich für Authentifizierung zuständig bleibt.
    func signUp(email: String, password: String) async throws -> String

    func signIn(email: String, password: String) async throws -> String

    func signOut() throws

    /// Löscht den Firebase-Auth-Account unwiderruflich. Wird sowohl für
    /// echte Account-Löschungen als auch als Rollback verwendet, falls
    /// die Profilerstellung nach signUp() fehlschlägt (siehe AuthRepository).
    func deleteAccount() async throws
}
