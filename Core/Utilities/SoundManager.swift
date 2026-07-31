//
//  SoundManager.swift
//  BeerStats
//
//  Kurze Klänge für die Ereignisse im Spiel.
//
//  Aufbau in zwei Stufen: Liegt im Bundle eine Datei mit dem passenden
//  Namen, wird die abgespielt. Fehlt sie, greift ein iOS-Systemklang als
//  Platzhalter. Dadurch klingt die App ab sofort, und eigene Sounds lassen
//  sich später allein durch Hinzufügen der Dateien nachrüsten – ohne eine
//  Zeile Code zu ändern.
//
//  Bewusst AudioToolbox statt AVAudioPlayer: Für sehr kurze Signale ist das
//  der schlankere Weg, und es unterbricht laufende Musik nicht.
//

import Foundation
import AudioToolbox

/// Die Ereignisse, die einen Klang bekommen.
enum GameSound: String, CaseIterable {

    case cupHit
    case miss
    case airball
    case bombe
    case ballsBack
    case onFire
    case reRack
    case victory
    case tap

    /// Erwarteter Dateiname im Bundle, falls eigene Klänge hinterlegt werden.
    /// Beispiel: `bombe.caf`. Unterstützt werden caf, wav und m4a.
    var fileName: String { rawValue }

    /// Platzhalter aus dem iOS-Systemvorrat, solange keine eigene Datei
    /// vorliegt. Die Nummern sind bewusst so gewählt, dass sich die
    /// Ereignisse hörbar unterscheiden – ein hoher Klick für den Treffer,
    /// ein dumpferer für den Fehlwurf, Fanfaren für die großen Momente.
    var systemSoundID: SystemSoundID {
        switch self {
        case .cupHit:    return 1057   // heller, kurzer Anschlag
        case .miss:      return 1104   // dumpfer Tastenklick
        case .airball:   return 1053   // absteigender Ton
        case .bombe:     return 1023   // kräftiger Impuls
        case .ballsBack: return 1025   // aufsteigende Folge
        case .onFire:    return 1016   // heller Signalton
        case .reRack:    return 1103   // kurzer Doppelklick
        case .victory:   return 1027   // Fanfare
        case .tap:       return 1104   // wie miss, nur leiser wahrgenommen
        }
    }
}

enum SoundManager {

    private static let preferenceKey = "beerstats.soundEnabled"
    private static var cache: [GameSound: SystemSoundID] = [:]

    /// Am Tisch will man das gelegentlich abschalten, ohne das Handy
    /// stumm zu stellen – deshalb eine eigene, dauerhaft gespeicherte
    /// Einstellung.
    static var isEnabled: Bool {
        get {
            // Ohne gespeicherten Wert soll Ton an sein, nicht aus.
            UserDefaults.standard.object(forKey: preferenceKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: preferenceKey)
        }
    }

    static func play(_ sound: GameSound) {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(soundID(for: sound))
    }

    /// Ermittelt die abzuspielende Kennung: eigene Datei bevorzugt,
    /// Systemklang als Rückfall. Das Ergebnis wird gemerkt, damit nicht bei
    /// jedem Wurf erneut im Bundle gesucht wird.
    private static func soundID(for sound: GameSound) -> SystemSoundID {
        if let cached = cache[sound] { return cached }

        var resolved = sound.systemSoundID
        for fileExtension in ["caf", "wav", "m4a"] {
            guard let url = Bundle.main.url(forResource: sound.fileName, withExtension: fileExtension) else {
                continue
            }
            var customID: SystemSoundID = 0
            if AudioServicesCreateSystemSoundID(url as CFURL, &customID) == kAudioServicesNoError {
                resolved = customID
                break
            }
        }

        cache[sound] = resolved
        return resolved
    }
}
