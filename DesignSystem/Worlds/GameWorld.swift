//
//  GameWorld.swift
//  BeerStats
//
//  Jedes Spiel hat seine eigene Welt.
//
//  Bis zum 28. Oktober sah jedes Partyspiel gleich aus: derselbe Grund mit
//  Blasen, dieselbe dunkle Glasflaeche mit Neonkante, dieselbe runde
//  Schrift – nur die Farbe des Lichts wechselte, und davon gab es fuenf fuer
//  fuenfundzwanzig Spiele. Man erkannte ein Spiel an seinem Titel, nicht an
//  seinem Aussehen. Der Nutzer: "Im Moment sieht jedes Spiel sehr aehnlich
//  aus."
//
//  Das Vorbild sind die Party Packs von Jackbox: fuenf Spiele pro Paket,
//  und die Regel des Studios lautet, jedes in Stil und Thema verschieden zu
//  halten – sonst waere es ein Paket aus gleichfoermigen Spielen. Geteilt
//  wird nur der Rahmen.
//
//  Hier also das GERUEST und die WELT getrennt:
//  - Gleich bleiben Navigation, Knoepfe, Vorspann, Weitergeben, Anleitung,
//    Haerte, Abend und Bilanz – in ihrem Verhalten.
//  - Jede Welt bringt Grund, Oberflaeche, Kante und Schrift mit. Die
//    geteilten Bausteine (`AmbientBackdrop`, `glassPanel`, `neonEdge`,
//    `GameSetupScreen`) lesen die Welt aus der Umgebung und kleiden sich
//    danach ein. Kein Spiel muss dafuer etwas tun, und keines kann es
//    vergessen.
//
//  Drei Regeln, jede mit Grund:
//  1. **Die Welt steht im Katalog** (`PartyGame.world`, ein vollstaendiges
//     `switch`). Ein neues Spiel uebersetzt nicht ohne Welt.
//  2. **Satz-Regel:** Jede Welt laesst sich in einem Satz beschreiben, ohne
//     ein Emoji zu nennen, und kein Satz kommt zweimal vor
//     (`GameWorldTests`). Faellt einem kein eigener Satz ein, ist es keine
//     eigene Welt.
//  3. **Dunkler Grund, dunkle Flaechen.** Schrift und Deckkraefte der App
//     sind auf dunklen Grund gerechnet; ein heller Screen waere der
//     Hell-Modus, den es nicht gibt. Hell duerfen nur GEGENSTAENDE sein
//     (Spielkarte, Akte, Bingoblatt) – mit eigener, fester Tinte.
//
//  Menues haben keine Welt und bleiben, wie sie sind: Dort gilt das
//  Farbschema aus den Einstellungen. In der Welt haben Dinge ihre eigene
//  Farbe – Filz ist gruen, Pergament beige –, so wie Bier bernstein bleibt,
//  egal welches Schema gewaehlt ist.
//

import SwiftUI

enum GameWorld: String, CaseIterable {

    // Mit Karten
    case campfire, racetrack, nightBus, twoPiles, neonSign, recordShelf
    // Raten & reden
    case regularsTable, underTheCup, lieDetector, secretFile, foreheadCard, boardGame
    case quizShow, hourglass, showOfHands, trumpCards, silentFilm, wavelength
    // Schnell zwischendurch
    case bunker, highNoon, casino, pasture
    // Laeuft nebenher
    case gafferTape, bingoHall, decree
    // Rahmen: kein eigenes Spiel, aber ein eigener Ort
    case departureBoard, stadium

    /// Alles, was eine Welt ausmacht, an einer Stelle.
    struct Look {
        /// Die Welt in einem Satz – ohne Emoji, und keiner kommt zweimal vor.
        let sentence: String
        let design: Font.Design
        let width: Font.Width
        /// Die Flaeche, auf der der Inhalt steht – immer dunkel.
        let surfaceTop: Color
        let surfaceBottom: Color
        /// Die Kante dieser Flaeche: Farbe, Staerke, ob sie leuchtet.
        let edge: Color
        let edgeWidth: CGFloat
        let edgeGlows: Bool
        /// Eckiger als bestellt, wo die Welt eckig ist (Akte, Film, Beton);
        /// `nil` laesst die Ecken, wie der Aufrufer sie will.
        let maxCorner: CGFloat?
        /// Ob der Grund sich leise bewegt (Glut, Filmkorn, schwingende Lampe).
        let groundMoves: Bool
    }

    var look: Look {
        switch self {
        case .campfire:
            return Look(sentence: "Ein Kartenring auf dunklem Holz, aus dessen Mitte Glut leuchtet.",
                        design: .rounded, width: .standard,
                        surfaceTop: Self.rgb(48, 32, 21), surfaceBottom: Self.rgb(32, 21, 14),
                        edge: Self.rgb(255, 140, 60), edgeWidth: 1.4, edgeGlows: true, maxCorner: nil, groundMoves: true)
        case .racetrack:
            return Look(sentence: "Asse galoppieren auf grünem Rasen über weiße Bahnlinien ins Ziel.",
                        design: .default, width: .condensed,
                        surfaceTop: Self.rgb(22, 62, 36), surfaceBottom: Self.rgb(14, 44, 26),
                        edge: Self.rgb(245, 245, 240), edgeWidth: 2, edgeGlows: false, maxCorner: 8, groundMoves: false)
        case .nightBus:
            return Look(sentence: "Eine orange Leuchtanzeige stellt die Fragen, die Karten drehen sich um ihre Längsachse.",
                        design: .monospaced, width: .standard,
                        surfaceTop: Self.rgb(20, 28, 56), surfaceBottom: Self.rgb(12, 17, 36),
                        edge: Self.rgb(255, 150, 30), edgeWidth: 1.5, edgeGlows: true, maxCorner: 10, groundMoves: false)
        case .twoPiles:
            return Look(sentence: "Ein diagonal geteilter Tisch: kühles Blau für Geständnisse, Rot mit Warnstreifen für Befehle.",
                        design: .default, width: .condensed,
                        surfaceTop: Self.rgb(26, 36, 64), surfaceBottom: Self.rgb(40, 14, 20),
                        edge: Self.rgb(240, 196, 40), edgeWidth: 2, edgeGlows: false, maxCorner: 18, groundMoves: false)
        case .neonSign:
            return Look(sentence: "Auf einer Backsteinwand zündet jeder Satz flackernd wie eine Neonröhre.",
                        design: .rounded, width: .standard,
                        surfaceTop: Self.rgb(42, 18, 18), surfaceBottom: Self.rgb(26, 11, 11),
                        edge: Self.rgb(255, 72, 170), edgeWidth: 2.5, edgeGlows: true, maxCorner: nil, groundMoves: false)
        case .recordShelf:
            return Look(sentence: "Lieder stecken in Plattenhüllen, und die Farbe der Hülle verrät das Jahrzehnt.",
                        design: .default, width: .expanded,
                        surfaceTop: Self.rgb(46, 32, 21), surfaceBottom: Self.rgb(30, 21, 14),
                        edge: Self.rgb(236, 72, 153), edgeWidth: 1.5, edgeGlows: false, maxCorner: 6, groundMoves: false)
        case .regularsTable:
            return Look(sentence: "Drei Würfel kullern über ein Filzbrett, und der Verlierer bekommt echte Bierdeckel.",
                        design: .serif, width: .standard,
                        surfaceTop: Self.rgb(20, 80, 48), surfaceBottom: Self.rgb(13, 58, 35),
                        edge: Self.rgb(128, 84, 46), edgeWidth: 5, edgeGlows: false, maxCorner: nil, groundMoves: false)
        case .underTheCup:
            return Look(sentence: "Ein Lederbecher knallt auf den Tisch, und gelüftet wird mit dem Daumen.",
                        design: .default, width: .condensed,
                        surfaceTop: Self.rgb(50, 30, 19), surfaceBottom: Self.rgb(30, 18, 12),
                        edge: Self.rgb(200, 160, 90), edgeWidth: 1.5, edgeGlows: false, maxCorner: 12, groundMoves: true)
        case .lieDetector:
            return Look(sentence: "Auf Millimeterpapier zeichnet eine Nadel, die bei der Lüge ausschlägt.",
                        design: .monospaced, width: .standard,
                        surfaceTop: Self.rgb(18, 32, 29), surfaceBottom: Self.rgb(12, 22, 20),
                        edge: Self.rgb(90, 170, 150), edgeWidth: 1.5, edgeGlows: false, maxCorner: 6, groundMoves: false)
        case .secretFile:
            return Look(sentence: "Eine Akte klappt auf, und das Wort tippt sich wie auf einer Schreibmaschine.",
                        design: .monospaced, width: .standard,
                        surfaceTop: Self.rgb(66, 54, 36), surfaceBottom: Self.rgb(48, 39, 26),
                        edge: Self.rgb(204, 170, 108), edgeWidth: 1.5, edgeGlows: false, maxCorner: 4, groundMoves: false)
        case .foreheadCard:
            return Look(sentence: "Der Begriff füllt den ganzen Screen, und ein Band läuft schrumpfend um den Rand.",
                        design: .default, width: .compressed,
                        surfaceTop: Self.rgb(40, 48, 128), surfaceBottom: Self.rgb(28, 34, 96),
                        edge: Self.rgb(255, 200, 80), edgeWidth: 3, edgeGlows: false, maxCorner: nil, groundMoves: false)
        case .boardGame:
            return Look(sentence: "Die Zahlen liegen als Felder auf einem gewundenen Pfad, und jede Regel klebt als Aufkleber darauf.",
                        design: .rounded, width: .standard,
                        surfaceTop: Self.rgb(16, 52, 56), surfaceBottom: Self.rgb(10, 36, 40),
                        edge: Self.rgb(232, 222, 196), edgeWidth: 2, edgeGlows: false, maxCorner: nil, groundMoves: false)
        case .quizShow:
            return Look(sentence: "Lauflichter umrahmen die Frage, und die Lösung rollt auf Zahlenwalzen ein.",
                        design: .default, width: .expanded,
                        surfaceTop: Self.rgb(36, 24, 80), surfaceBottom: Self.rgb(22, 14, 52),
                        edge: Self.rgb(255, 214, 120), edgeWidth: 2, edgeGlows: true, maxCorner: nil, groundMoves: false)
        case .hourglass:
            return Look(sentence: "Eine Sanduhr dreht sich bei jedem Zug um und wird jede Runde kleiner.",
                        design: .default, width: .standard,
                        surfaceTop: Self.rgb(16, 38, 44), surfaceBottom: Self.rgb(10, 24, 28),
                        edge: Self.rgb(226, 186, 120), edgeWidth: 1.5, edgeGlows: false, maxCorner: nil, groundMoves: false)
        case .showOfHands:
            return Look(sentence: "Drei Zahlen fallen mit Wumms, dann schnappen Zeigefinger von allen Rändern zur Mitte.",
                        design: .default, width: .compressed,
                        surfaceTop: Self.rgb(44, 22, 72), surfaceBottom: Self.rgb(28, 14, 48),
                        edge: Self.rgb(180, 90, 255), edgeWidth: 1.8, edgeGlows: true, maxCorner: nil, groundMoves: false)
        case .trumpCards:
            return Look(sentence: "Zwei Sammelkarten prallen in der Mitte aufeinander, und der bessere Wert leuchtet.",
                        design: .default, width: .condensed,
                        surfaceTop: Self.rgb(30, 32, 38), surfaceBottom: Self.rgb(18, 20, 24),
                        edge: Self.rgb(200, 206, 216), edgeWidth: 1.5, edgeGlows: false, maxCorner: 14, groundMoves: false)
        case .silentFilm:
            return Look(sentence: "Schwarzweiß mit Filmkorn, und die Begriffe stehen als Zwischentitel im verzierten Rahmen.",
                        design: .serif, width: .standard,
                        surfaceTop: Self.rgb(14, 14, 14), surfaceBottom: Self.rgb(6, 6, 6),
                        edge: Self.rgb(240, 240, 236), edgeWidth: 1.5, edgeGlows: false, maxCorner: 3, groundMoves: true)
        case .wavelength:
            return Look(sentence: "Ein Halbkreis zwischen zwei Polen, dessen Klappe die Zielzone freigibt.",
                        design: .rounded, width: .standard,
                        surfaceTop: Self.rgb(16, 36, 50), surfaceBottom: Self.rgb(10, 24, 34),
                        edge: Self.rgb(60, 200, 220), edgeWidth: 1.5, edgeGlows: false, maxCorner: nil, groundMoves: false)
        case .bunker:
            return Look(sentence: "Eine gezeichnete Bombe sprüht Funken aus der Zündschnur, mit Warnstreifen an Ober- und Unterkante.",
                        design: .default, width: .compressed,
                        surfaceTop: Self.rgb(48, 48, 50), surfaceBottom: Self.rgb(34, 34, 36),
                        edge: Self.rgb(240, 196, 40), edgeWidth: 2, edgeGlows: false, maxCorner: 6, groundMoves: false)
        case .highNoon:
            return Look(sentence: "Wüste in der Dämmerung, und der Screen atmet, bis das Signal blitzt.",
                        design: .serif, width: .standard,
                        surfaceTop: Self.rgb(66, 32, 40), surfaceBottom: Self.rgb(42, 20, 26),
                        edge: Self.rgb(250, 230, 190), edgeWidth: 1.5, edgeGlows: false, maxCorner: 10, groundMoves: false)
        case .casino:
            return Look(sentence: "Das Rad dreht sich über grünem Spieltischfilz mit goldenem Rand.",
                        design: .serif, width: .standard,
                        surfaceTop: Self.rgb(16, 70, 45), surfaceBottom: Self.rgb(10, 50, 32),
                        edge: Self.rgb(212, 175, 90), edgeWidth: 2, edgeGlows: false, maxCorner: nil, groundMoves: false)
        case .pasture:
            return Look(sentence: "Eine gezeichnete Herde rückt zusammen, und wer allein stand, trottet an den Rand.",
                        design: .rounded, width: .standard,
                        surfaceTop: Self.rgb(26, 58, 36), surfaceBottom: Self.rgb(16, 40, 24),
                        edge: Self.rgb(150, 108, 70), edgeWidth: 3, edgeGlows: false, maxCorner: nil, groundMoves: false)
        case .gafferTape:
            return Look(sentence: "Das Wort liegt unter Gewebeband, das zum Aufdecken abgezogen wird.",
                        design: .default, width: .condensed,
                        surfaceTop: Self.rgb(70, 52, 34), surfaceBottom: Self.rgb(50, 37, 24),
                        edge: Self.rgb(168, 170, 176), edgeWidth: 3, edgeGlows: false, maxCorner: 6, groundMoves: false)
        case .bingoHall:
            return Look(sentence: "Auf einem hellen Papierblatt hinterlässt jeder Tipp einen Stempelklecks.",
                        design: .rounded, width: .standard,
                        surfaceTop: Self.rgb(44, 24, 54), surfaceBottom: Self.rgb(28, 15, 36),
                        edge: Self.rgb(226, 40, 130), edgeWidth: 1.8, edgeGlows: false, maxCorner: 12, groundMoves: false)
        case .decree:
            return Look(sentence: "Jede Regel entrollt sich als Pergament und wird versiegelt.",
                        design: .serif, width: .standard,
                        surfaceTop: Self.rgb(62, 16, 24), surfaceBottom: Self.rgb(40, 10, 16),
                        edge: Self.rgb(220, 186, 120), edgeWidth: 1.5, edgeGlows: false, maxCorner: 5, groundMoves: false)
        case .departureBoard:
            return Look(sentence: "Fallblätter klappern durch die Spielnamen und bleiben beim Ergebnis stehen.",
                        design: .monospaced, width: .standard,
                        surfaceTop: Self.rgb(30, 30, 32), surfaceBottom: Self.rgb(20, 20, 22),
                        edge: Self.rgb(245, 197, 24), edgeWidth: 1.5, edgeGlows: false, maxCorner: 10, groundMoves: false)
        case .stadium:
            return Look(sentence: "Eine Anzeigetafel zählt die Runden, und die Strafe steigt als Treppe.",
                        design: .default, width: .condensed,
                        surfaceTop: Self.rgb(18, 20, 30), surfaceBottom: Self.rgb(10, 12, 20),
                        edge: Self.rgb(255, 70, 50), edgeWidth: 1.5, edgeGlows: true, maxCorner: 10, groundMoves: false)
        }
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r / 255, green: g / 255, blue: b / 255)
    }

    // MARK: - Was die geteilten Bausteine fragen

    /// Die Schrift der Welt. Folgt der Systemgroesse wie jeder andere
    /// Textstil – nur Gestalt und Breite kommen aus der Welt.
    func font(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .scaled(size, weight: weight, design: look.design, width: look.width)
    }

    func corner(_ requested: CGFloat) -> CGFloat {
        guard let grenze = look.maxCorner else { return requested }
        return min(requested, grenze)
    }

    /// Welche Farbe eine Kante in dieser Welt hat.
    ///
    /// Gruen und Rot behalten ihre Bedeutung – gut und schlecht, Treffer und
    /// Strafe. Jede andere Farbe war bisher bloss die Farbe des Spiels, und
    /// genau die hat alle Spiele gleich aussehen lassen; dort spricht jetzt
    /// die Welt.
    func edgeColor(for tint: Color) -> Color {
        if tint == BeerStatsColor.success || tint == BeerStatsColor.error { return tint }
        return look.edge
    }
}

// MARK: - Die Welt in der Umgebung

private struct GameWorldKey: EnvironmentKey {
    static let defaultValue: GameWorld? = nil
}

extension EnvironmentValues {
    /// Die Welt des Spiels, in dem diese Ansicht steht – `nil` in Menues.
    var gameWorld: GameWorld? {
        get { self[GameWorldKey.self] }
        set { self[GameWorldKey.self] = newValue }
    }
}

extension Font {
    /// Die Schrift der Welt – oder die runde Schrift der App, wo keine Welt ist.
    static func world(_ world: GameWorld?, _ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        guard let world else { return .scaled(size, weight: weight, design: .rounded) }
        return world.font(size, weight: weight)
    }
}
