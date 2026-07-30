//
//  PlayerProfile.swift
//  BeerStats
//
//  Ein Mitspieler, der kein eigenes App-Konto hat.
//
//  Hintergrund: In der Startphase liegt die App nur auf einem Gerät, und
//  von dort werden alle Mitspieler verwaltet. Ein Profil ist deshalb
//  bewusst KEIN `User` – es hat keine Anmeldung, keine Freundschaften und
//  keine Geräte. Es ist ein Namensschild mit einer Statistik daran.
//
//  Abgelegt unter `users/{ownerUid}/players/{profileId}`. Dadurch gehören
//  die Profile eindeutig einem Konto, die Zugriffsregel bleibt trivial
//  (nur der Besitzer), und ein späterer Wechsel auf echte Konten kann ein
//  Profil einfach mit einer User-ID verknüpfen, statt die Historie zu
//  verlieren.
//

import Foundation
import FirebaseFirestore

struct PlayerProfile: Codable, Identifiable, Equatable {

    @DocumentID var id: String?

    var name: String
    /// Emoji als Avatar – am Tisch schneller zu unterscheiden als Text und
    /// ohne Foto-Verwaltung, Berechtigungen oder Storage-Kosten.
    var emoji: String
    var color: ProfileColor

    /// Dieselbe Kennzahlen-Struktur wie bei echten Konten. Bewusst
    /// wiederverwendet statt dupliziert: Wird ein Profil später zu einem
    /// echten Konto, wandern die Werte unverändert mit.
    var statistics: UserStatistics

    /// Wird auf `false` gesetzt statt das Dokument zu löschen, sobald jemand
    /// nicht mehr mitspielt. Sonst würden abgeschlossene Spiele auf ein
    /// Profil verweisen, das es nicht mehr gibt.
    var isActive: Bool

    @ServerTimestamp var createdAt: Date?

    init(
        id: String? = nil,
        name: String,
        emoji: String = "🍺",
        color: ProfileColor = .amber,
        statistics: UserStatistics = UserStatistics(),
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.color = color
        self.statistics = statistics
        self.isActive = isActive
    }

    /// Kürzel für enge Stellen, an denen der volle Name nicht passt.
    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init)
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }

    var winRate: Double {
        statistics.gamesPlayed == 0 ? 0 : Double(statistics.gamesWon) / Double(statistics.gamesPlayed)
    }
}

/// Auswählbare Profilfarben.
///
/// Gespeichert wird der Name, nicht der Farbwert. Dadurch lässt sich die
/// Palette später anpassen, ohne bereits angelegte Profile zu migrieren –
/// die konkreten Farbwerte liegen im Design-System, nicht im Modell.
enum ProfileColor: String, Codable, CaseIterable, Equatable {
    case amber
    case red
    case green
    case blue
    case purple
    case teal

    var displayName: String {
        switch self {
        case .amber: return "Bernstein"
        case .red: return "Cup-Rot"
        case .green: return "Foam-Grün"
        case .blue: return "Blau"
        case .purple: return "Violett"
        case .teal: return "Türkis"
        }
    }
}
