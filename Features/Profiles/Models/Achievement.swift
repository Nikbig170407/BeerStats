//
//  Achievement.swift
//  BeerStats
//
//  Auszeichnungen, die sich aus den vorhandenen Zahlen ergeben.
//
//  Bewusst NICHT gespeichert. Eine Auszeichnung ist hier kein Ereignis, das
//  irgendwann einmal eintritt und dann in der Datenbank liegt, sondern eine
//  Aussage ueber den aktuellen Stand: "Dieses Profil hat ueber hundert
//  Treffer." Das hat drei Vorteile – es braucht kein neues Feld am Profil,
//  keine Wanderung bestehender Daten, und es kann nie danebenliegen. Wird
//  eine Partie zurueckgenommen, verschwindet die Auszeichnung von selbst
//  wieder.
//
//  Der Preis dafuer: Es gibt kein "seit wann" und keinen Moment, in dem es
//  ploetzlich aufblinkt. Fuer eine App, in der die Zahlen ohnehin jederzeit
//  neu gerechnet werden koennen, ist das der ehrlichere Handel.
//

import SwiftUI

struct Achievement: Identifiable, Equatable {
    let id: String
    let emoji: String
    let title: String
    let detail: String
}

enum Achievements {

    // MARK: - Ueber alle Partien

    /// Alles, was dieses Profil bisher erreicht hat.
    static func lifetime(for stats: UserStatistics) -> [Achievement] {
        var earned: [Achievement] = []

        func add(_ id: String, _ emoji: String, _ title: String, _ detail: String, when condition: Bool) {
            guard condition else { return }
            earned.append(Achievement(id: id, emoji: emoji, title: title, detail: detail))
        }

        add("firstGame", "🎬", "Angefangen", "Erste Partie gespielt",
            when: stats.gamesPlayed >= 1)
        add("veteran", "🎖️", "Stammgast", "50 Partien gespielt",
            when: stats.gamesPlayed >= 50)
        add("tenWins", "🏆", "Zehn Siege", "Zehnmal gewonnen",
            when: stats.gamesWon >= 10)
        add("streak", "📈", "Lauf", "Fünf Siege hintereinander",
            when: stats.longestWinStreak >= 5)
        add("hundredHits", "💯", "Hundert Treffer", "100 Becher abgeräumt",
            when: stats.totalHits >= 100)
        add("sniper", "🎯", "Treffsicher", "Über die Hälfte getroffen, bei mindestens 50 Würfen",
            when: stats.totalThrows >= 50 && stats.hitRate >= 0.5)
        add("bouncer", "🏓", "Aufsetzer", "Zehn Bounce Shots versenkt",
            when: stats.totalBounceShotsMade >= 10)
        add("trickster", "🌀", "Trickser", "Fünf Trickshots getroffen",
            when: stats.totalTrickshotsMade >= 5)
        add("onFire", "🔥", "Brandgefährlich", "Serie von fünf Treffern",
            when: stats.longestOnFireStreak >= 5)
        // Auch das ist eine Leistung, nur eben keine gute.
        add("airhead", "💀", "Luftikus", "25 Airballs – jeder davon ein Shot",
            when: stats.totalAirballs >= 25)

        return earned
    }

    /// Die naechste Auszeichnung, die in Reichweite ist. Ohne die wirkt eine
    /// leere Liste wie ein Fehler statt wie ein Anfang.
    static func next(for stats: UserStatistics) -> String? {
        if stats.gamesPlayed < 1 { return "Spiel eine Partie, dann geht es los." }
        if stats.totalHits < 100 { return "Noch \(100 - stats.totalHits) Treffer bis zur Hundert." }
        if stats.gamesWon < 10 { return "Noch \(10 - stats.gamesWon) Siege bis zum Pokal." }
        if stats.gamesPlayed < 50 { return "Noch \(50 - stats.gamesPlayed) Partien bis zum Stammgast." }
        return nil
    }

    // MARK: - Aus einer einzelnen Partie

    /// Was in genau dieser Partie gelungen ist. Wird im Sieger-Screen
    /// gezeigt, solange die Zahlen noch auf dem Tisch liegen.
    static func match(for player: PlayerRef, in state: LiveGameState) -> [Achievement] {
        let stats = state.playerStats(for: player)
        guard stats.attempts > 0 else { return [] }

        let bestStreak = state.bestStreaks[player.teamIndex][player.slot]
        var earned: [Achievement] = []

        func add(_ id: String, _ emoji: String, _ title: String, _ detail: String, when condition: Bool) {
            guard condition else { return }
            earned.append(Achievement(id: id, emoji: emoji, title: title, detail: detail))
        }

        add("flawless", "✨", "Makellos", "Kein einziger Fehlwurf",
            when: stats.hits == stats.attempts)
        add("hattrick", "🔥", "Hattrick", "Drei Treffer in Folge",
            when: bestStreak >= 3)
        add("unstoppable", "⚡️", "Nicht zu halten", "Fünf Treffer in Folge",
            when: bestStreak >= 5)
        add("bounce", "🏓", "Aufsetzer", "Bounce Shot versenkt",
            when: stats.bounces >= 1)
        add("trick", "🌀", "Trickshot", "Nach dem Rebound getroffen",
            when: stats.trickshots >= 1)
        add("rough", "💀", "Zäher Abend", "Drei Airballs in einer Partie",
            when: stats.airballs >= 3)

        return earned
    }
}

/// Zeigt Auszeichnungen als Reihe von Plaketten.
struct AchievementRow: View {

    let achievements: [Achievement]
    var tint: Color = BeerStatsColor.accent

    var body: some View {
        VStack(spacing: 7) {
            ForEach(achievements) { achievement in
                HStack(spacing: 11) {
                    Text(achievement.emoji).font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(achievement.title)
                            .font(BeerStatsFont.headline)
                            .foregroundStyle(BeerStatsColor.textPrimary)
                        Text(achievement.detail)
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .glassPanel(cornerRadius: 14)
                .neonEdge(tint, cornerRadius: 14, intensity: 0.35)
            }
        }
    }
}
