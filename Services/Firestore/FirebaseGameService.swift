//
//  FirebaseGameService.swift
//  BeerStats
//
//  Konkrete Firestore-Implementierung. Nutzt das in Schritt 3 ergänzte
//  `allPlayerIds`-Feld, um "alle Spiele eines Nutzers" effizient per
//  array-contains abzufragen (siehe firestore.indexes.json für den dafür
//  nötigen Composite Index).
//

import Foundation
import FirebaseFirestore

final class FirebaseGameService: GameServiceProtocol {

    private let db = Firestore.firestore()

    func createGame(_ game: Game) async throws -> String {
        let ref = db.collection(AppConstants.Firestore.games).document()
        let data = try Firestore.Encoder().encode(game)
        try await ref.setData(data)
        return ref.documentID
    }

    func observeGame(gameId: String) -> AsyncStream<Game?> {
        AsyncStream { continuation in
            let listener = db.collection(AppConstants.Firestore.games).document(gameId)
                .addSnapshotListener { snapshot, error in
                    guard let snapshot else {
                        AppLogger.firestore.error("Game-Listener-Fehler: \(error?.localizedDescription ?? "unbekannt")")
                        return
                    }
                    continuation.yield(try? snapshot.data(as: Game.self))
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func observeUserGames(userId: String) -> AsyncStream<[Game]> {
        AsyncStream { continuation in
            let listener = db.collection(AppConstants.Firestore.games)
                .whereField("allPlayerIds", arrayContains: userId)
                .whereField("status", in: [
                    GameStatus.lobby.rawValue,
                    GameStatus.active.rawValue,
                    GameStatus.paused.rawValue
                ])
                .addSnapshotListener { snapshot, error in
                    guard let snapshot else {
                        AppLogger.firestore.error("UserGames-Listener-Fehler: \(error?.localizedDescription ?? "unbekannt")")
                        return
                    }
                    let games = snapshot.documents.compactMap { try? $0.data(as: Game.self) }
                    continuation.yield(games)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func updateGameStatus(gameId: String, status: GameStatus, startedAt: Date?) async throws {
        var data: [String: Any] = ["status": status.rawValue]
        if startedAt != nil {
            data["startedAt"] = FieldValue.serverTimestamp()
        }
        try await db.collection(AppConstants.Firestore.games).document(gameId).updateData(data)
    }

    func fetchFinishedGames(userId: String) async throws -> [Game] {
        let snapshot = try await db.collection(AppConstants.Firestore.games)
            .whereField("allPlayerIds", arrayContains: userId)
            .whereField("status", isEqualTo: GameStatus.finished.rawValue)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Game.self) }
    }

    func finishGame(gameId: String, winnerTeamId: String?) async throws {
        var data: [String: Any] = [
            "status": GameStatus.finished.rawValue,
            "endedAt": FieldValue.serverTimestamp()
        ]
        // Bei einem Unentschieden bleibt das Feld bewusst leer, statt eine
        // Platzhalter-ID zu schreiben, die später falsch ausgewertet würde.
        data["winnerTeamId"] = winnerTeamId ?? NSNull()

        try await db.collection(AppConstants.Firestore.games).document(gameId).updateData(data)
    }
}
