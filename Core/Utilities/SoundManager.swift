//
//  SoundManager.swift
//  BeerStats
//
//  Klänge für die Ereignisse im Spiel.
//
//  Alle Dateien liegen unter `Resources/Sounds`. Die kurzen Signale sind
//  selbst erzeugt (siehe Skript in der Projekthistorie) und damit frei von
//  Lizenzfragen; der Airball nutzt einen eigenen Ausschnitt.
//
//  Bewusst AVAudioPlayer statt der früheren Systemtöne: Nur so lassen sich
//  eigene Dateien in beliebigem Format abspielen, die Lautstärke steuern und
//  ein längerer Ausschnitt nach ein paar Sekunden wieder ausblenden.
//

import Foundation
import AVFoundation

/// Die Ereignisse, die einen Klang bekommen. Der Name entspricht exakt dem
/// Dateinamen im Bundle – ein Klang lässt sich also allein durch Austausch
/// der Datei ändern.
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

    /// Unterstützte Endungen, in dieser Reihenfolge gesucht.
    static let supportedExtensions = ["wav", "mp3", "m4a", "caf"]

    /// Nach dieser Zeit wird ausgeblendet. `nil` heißt: ganz abspielen.
    ///
    /// Nur der Airball braucht das – dort liegt ein Musikausschnitt, der
    /// ohne Begrenzung noch liefe, wenn längst weitergeworfen wird.
    var maximumDuration: TimeInterval? {
        self == .airball ? 3.0 : nil
    }

    /// Grundlautstärke. Der Airball ist ein Musikclip und deutlich lauter
    /// abgemischt als die kurzen Signale.
    var volume: Float {
        switch self {
        case .airball: return 0.85
        case .tap: return 0.35
        default: return 0.7
        }
    }
}

enum SoundManager {

    private static let preferenceKey = "beerstats.soundEnabled"
    private static var players: [GameSound: AVAudioPlayer] = [:]
    private static var pendingStops: [GameSound: DispatchWorkItem] = [:]
    private static var didConfigureSession = false

    /// Am Tisch will man das gelegentlich abschalten, ohne das ganze Handy
    /// stumm zu stellen – deshalb eine eigene, dauerhaft gespeicherte
    /// Einstellung.
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: preferenceKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: preferenceKey) }
    }

    static func play(_ sound: GameSound) {
        guard isEnabled else { return }
        configureSessionIfNeeded()

        guard let player = player(for: sound) else { return }

        // Ein noch laufender Ausblend-Auftrag würde sonst den neuen
        // Durchlauf mitten im Ton abwürgen.
        pendingStops[sound]?.cancel()
        pendingStops[sound] = nil

        player.volume = sound.volume
        player.currentTime = 0
        player.play()

        scheduleFadeOutIfNeeded(for: sound, player: player)
    }

    /// Beendet alles Laufende – etwa beim Verlassen des Spielscreens.
    static func stopAll() {
        pendingStops.values.forEach { $0.cancel() }
        pendingStops.removeAll()
        players.values.forEach { $0.stop() }
    }

    // MARK: - Intern

    /// `.ambient` mit `mixWithOthers`: Eine laufende Playlist soll durch die
    /// App nicht unterbrochen werden – auf einer Party wäre das der
    /// sicherste Weg, sie wieder ausgeschaltet zu bekommen.
    private static func configureSessionIfNeeded() {
        guard !didConfigureSession else { return }
        didConfigureSession = true
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            AppLogger.app.error("Audio-Sitzung konnte nicht gesetzt werden: \(error.localizedDescription)")
        }
    }

    private static func player(for sound: GameSound) -> AVAudioPlayer? {
        if let existing = players[sound] { return existing }

        for fileExtension in GameSound.supportedExtensions {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: fileExtension) else {
                continue
            }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[sound] = player
                return player
            } catch {
                AppLogger.app.error("Klang \(sound.rawValue) nicht ladbar: \(error.localizedDescription)")
            }
        }
        // Fehlt die Datei, bleibt es einfach still – lieber kein Ton als ein
        // unpassender Systemton.
        return nil
    }

    private static func scheduleFadeOutIfNeeded(for sound: GameSound, player: AVAudioPlayer) {
        guard let limit = sound.maximumDuration, player.duration > limit else { return }

        let fade = 0.5
        let work = DispatchWorkItem {
            player.setVolume(0, fadeDuration: fade)
            DispatchQueue.main.asyncAfter(deadline: .now() + fade) {
                player.stop()
                player.volume = sound.volume
            }
            pendingStops[sound] = nil
        }
        pendingStops[sound] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + limit - fade, execute: work)
    }
}
