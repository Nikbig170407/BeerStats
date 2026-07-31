//
//  FirebaseThrowService.swift
//  BeerStats
//
//  Konkrete Firestore-Implementierung des Wurf-Logs.
//
//  Sortiert wird serverseitig nach `sequenceNumber` und nicht nach dem
//  Zeitstempel: Der Zeitstempel wird erst vom Server gesetzt und wäre bei
//  Einträgen, die kurz hintereinander von verschiedenen Geräten kommen,
//  nicht verlässlich eindeutig. Die fortlaufende Nummer stammt dagegen aus
//  der Engine und legt die Reihenfolge eindeutig fest – wichtig, weil der
//  Spielstand durch Nachspielen in genau dieser Reihenfolge entsteht.
//

import Foundation
import FirebaseFirestore

final class FirebaseThrowService: ThrowServiceProtocol {

    private let db = Firestore.firestore()

    private func throwsCollection(gameId: String) -> CollectionReference {
        db.collection(AppConstants.Firestore.games)
            .document(gameId)
            .collection(AppConstants.Firestore.throwsSubcollection)
    }

    func appendThrow(_ throwEvent: Throw, gameId: String) async throws {
        let data = try Firestore.Encoder().encode(throwEvent)
        try await throwsCollection(gameId: gameId).addDocument(data: data)
    }

    func fetchThrows(gameId: String) async throws -> [Throw] {
        let snapshot = try await throwsCollection(gameId: gameId)
            .order(by: "sequenceNumber")
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Throw.self) }
    }

    func observeThrows(gameId: String) -> AsyncStream<[Throw]> {
        AsyncStream { continuation in
            let listener = throwsCollection(gameId: gameId)
                .order(by: "sequenceNumber")
                .addSnapshotListener { snapshot, error in
                    guard let snapshot else {
                        AppLogger.firestore.error("Throws-Listener-Fehler: \(error?.localizedDescription ?? "unbekannt")")
                        return
                    }
                    let entries = snapshot.documents.compactMap { try? $0.data(as: Throw.self) }
                    continuation.yield(entries)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }
}
