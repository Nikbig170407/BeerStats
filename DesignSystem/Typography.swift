//
//  Typography.swift
//  BeerStats
//
//  Zentrale Text-Stile. Nutzt Dynamic Type (relativeTo:) als Basis für
//  Barrierefreiheit, mit fester Rundung/Gewichtung für den markanten,
//  hochwertigen App-Look.
//

import SwiftUI

enum BeerStatsFont {

    /// Große, prägnante Zahl – z. B. Punktestand im Live-Spiel, muss auf
    /// einen Blick aus Armlänge lesbar sein.
    static let scoreDisplay = Font.system(size: 64, weight: .bold, design: .rounded)

    static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let title = Font.system(.title2, design: .rounded).weight(.semibold)
    static let headline = Font.system(.headline, design: .rounded)
    static let body = Font.system(.body, design: .default)
    static let caption = Font.system(.caption, design: .default)

    /// Für Buttons während des Live-Spiels: groß genug für einhändige,
    /// schnelle Bedienung (siehe Architektur-Vorgabe „1–2 Sekunden Bedienzeit“).
    static let liveGameButton = Font.system(.title3, design: .rounded).weight(.bold)

    /// Monospaced-Ziffern für Statistik-/Scoreboard-Zahlen: verhindert
    /// "Wackeln" des Layouts, wenn sich Zahlen ändern (z. B. Live-Trefferquote),
    /// und gibt Statistik-Screens bewusst einen eigenen, "datenhaften" Charakter
    /// gegenüber der runden, freundlichen Display-Schrift.
    static let statValue = Font.system(.title, design: .monospaced).weight(.semibold)
    static let statLabel = Font.system(.caption, design: .monospaced).weight(.medium)
}
