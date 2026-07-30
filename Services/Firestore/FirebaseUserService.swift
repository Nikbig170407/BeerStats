//
//  FirebaseUserService.swift
//  BeerStats
//
//  Konkrete Firestore-Implementierung. Die Username-Reservierung läuft
//  bewusst über eine Firestore-Transaktion statt eines einfachen "prüfen,
//  dann schreiben": ohne Transaktion könnten zwei Nutzer, die exakt
//  gleichzeitig denselben Nutzernamen wählen, beide erfolgreich sein –
//  die Transaktion garantiert, dass nur einer von beiden gewinnt.
//

import Foundation
import FirebaseFirestore

final class FirebaseUserService: UserServiceProtocol {

    private let db = Firestore.firestore()

    func createUserProfile(uid: String, username: String, displayName: String) async throws {
        let usernameRef = db.collection(AppConstants.Firestore.usernames).document(username)
        let userRef = db.collection(AppConstants.Firestore.users).document(uid)
        let newUser = User(id: uid, username: username, displayName: displayName)
        let userData = try Firestore.Encoder().encode(newUser)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, errorPointer -> Any? in
                let usernameSnapshot: DocumentSnapshot
                do {
                    usernameSnapshot = try transaction.getDocument(usernameRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }

                if usernameSnapshot.exists {
                    errorPointer?.pointee = NSError(
                        domain: "BeerStats",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Dieser Nutzername ist bereits vergeben."]
                    )
                    return nil
                }

                transaction.setData(userData, forDocument: userRef)
                transaction.setData(["uid": uid], forDocument: usernameRef)
                return nil
            }, completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }

        AppLogger.firestore.info("Nutzerprofil angelegt")
    }

    func fetchUser(uid: String) async throws -> User {
        let snapshot = try await db.collection(AppConstants.Firestore.users).document(uid).getDocument()
        guard let user = try? snapshot.data(as: User.self) else {
            throw AppError.notFound("Nutzerprofil")
        }
        return user
    }

    func fetchUsers(uids: [String]) async throws -> [User] {
        guard !uids.isEmpty else { return [] }
        // Firestore erlaubt max. 30 Werte pro "in"-Query – in 10er-Blöcken
        // anfragen, um innerhalb sicherer Grenzen zu bleiben.
        let chunks = stride(from: 0, to: uids.count, by: 10).map {
            Array(uids[$0..<min($0 + 10, uids.count)])
        }
        var results: [User] = []
        for chunk in chunks {
            let snapshot = try await db.collection(AppConstants.Firestore.users)
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            results.append(contentsOf: snapshot.documents.compactMap { try? $0.data(as: User.self) })
        }
        return results
    }

    func searchUsers(usernamePrefix: String) async throws -> [User] {
        let prefix = usernamePrefix.trimmingCharacters(in: .whitespaces).lowercased()
        guard !prefix.isEmpty else { return [] }
        // Klassischer Firestore-Trick für Präfix-Suche: alles zwischen
        // "prefix" und "prefix" + höchstem Unicode-Zeichen liegt alphabetisch
        // danach, ergibt effektiv ein "startsWith".
        let end = prefix + "\u{f8ff}"
        let snapshot = try await db.collection(AppConstants.Firestore.users)
            .whereField("username", isGreaterThanOrEqualTo: prefix)
            .whereField("username", isLessThanOrEqualTo: end)
            .limit(to: 20)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: User.self) }
    }
}
