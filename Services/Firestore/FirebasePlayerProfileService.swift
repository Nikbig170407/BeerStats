//
//  FirebasePlayerProfileService.swift
//  BeerStats
//
//  Konkrete Firestore-Implementierung der Profil-Sammlung.
//
//  Die Statistik-Fortschreibung läuft über eine Transaktion und nicht über
//  ein einfaches Überschreiben. Grund: Serien sind Höchststände und der
//  Siegesserien-Zähler wird bei einer Niederlage zurückgesetzt – beides
//  lässt sich nicht als reines Hochzählen ausdrücken, sondern braucht den
//  vorherigen Wert. Die Transaktion stellt sicher, dass zwischen Lesen und
//  Schreiben niemand dazwischenfunkt, falls später doch mehrere Geräte
//  mitschreiben.
//

import Foundation
import FirebaseFirestore

final class FirebasePlayerProfileService: PlayerProfileServiceProtocol {

    private let db = Firestore.firestore()

    private func profilesCollection(ownerId: String) -> CollectionReference {
        db.collection(AppConstants.Firestore.users)
            .document(ownerId)
            .collection(AppConstants.Firestore.playersSubcollection)
    }

    // MARK: - Lesen

    func observeProfiles(ownerId: String) -> AsyncStream<[PlayerProfile]> {
        AsyncStream { continuation in
            let listener = profilesCollection(ownerId: ownerId)
                .order(by: "name")
                .addSnapshotListener { snapshot, error in
                    guard let snapshot else {
                        AppLogger.firestore.error("Profil-Listener-Fehler: \(error?.localizedDescription ?? "unbekannt")")
                        return
                    }
                    let profiles = snapshot.documents.compactMap { try? $0.data(as: PlayerProfile.self) }
                    continuation.yield(profiles)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func fetchProfiles(ownerId: String) async throws -> [PlayerProfile] {
        let snapshot = try await profilesCollection(ownerId: ownerId).order(by: "name").getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: PlayerProfile.self) }
    }

    // MARK: - Schreiben

    func createProfile(_ profile: PlayerProfile, ownerId: String) async throws -> String {
        let ref = profilesCollection(ownerId: ownerId).document()
        let data = try Firestore.Encoder().encode(profile)
        try await ref.setData(data)
        return ref.documentID
    }

    func updateProfileDetails(
        profileId: String,
        ownerId: String,
        name: String,
        emoji: String,
        color: ProfileColor,
        isActive: Bool
    ) async throws {
        try await profilesCollection(ownerId: ownerId).document(profileId).updateData([
            "name": name,
            "emoji": emoji,
            "color": color.rawValue,
            "isActive": isActive
        ])
    }

    func incrementStatistics(
        profileId: String,
        ownerId: String,
        deltas: ProfileStatisticsDelta
    ) async throws {
        let reference = profilesCollection(ownerId: ownerId).document(profileId)

        return try await withCheckedThrowingContinuation { continuation in
            db.runTransaction({ transaction, errorPointer -> Any? in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(reference)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }

                guard let profile = try? snapshot.data(as: PlayerProfile.self) else {
                    errorPointer?.pointee = AppError.validation(
                        "Profil \(profileId) konnte nicht gelesen werden."
                    ) as NSError
                    return nil
                }

                let updated = Self.applying(deltas, to: profile.statistics)
                do {
                    let encoded = try Firestore.Encoder().encode(updated)
                    transaction.updateData(["statistics": encoded], forDocument: reference)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }
                return nil
            }) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    /// Die eigentliche Rechenregel, absichtlich als reine Funktion: So lässt
    /// sie sich prüfen, ohne Firestore zu starten.
    static func applying(_ deltas: ProfileStatisticsDelta, to current: UserStatistics) -> UserStatistics {
        var stats = current

        stats.gamesPlayed += deltas.gamesPlayed
        stats.gamesWon += deltas.gamesWon
        stats.totalThrows += deltas.totalThrows
        stats.totalHits += deltas.totalHits
        stats.totalAirballs += deltas.totalAirballs
        stats.totalBounceShotsMade += deltas.totalBounceShotsMade
        stats.totalTrickshotsMade += deltas.totalTrickshotsMade

        // Höchststand, kein Summand.
        stats.longestOnFireStreak = max(stats.longestOnFireStreak, deltas.longestOnFireStreakCandidate)

        // Nur bei einem abgeschlossenen Spiel bewegt sich die Siegesserie.
        if deltas.gamesPlayed > 0 {
            stats.currentWinStreak = deltas.didWin ? stats.currentWinStreak + 1 : 0
            stats.longestWinStreak = max(stats.longestWinStreak, stats.currentWinStreak)
        }

        stats.lastUpdated = Date()
        return stats
    }
}
