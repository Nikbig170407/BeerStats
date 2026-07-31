//
//  SpeechAnnouncer.swift
//  BeerStats
//
//  Sagt an, wer als Nächstes wirft.
//
//  Der Sinn dahinter: Das Handy liegt während einer Partie auf dem Tisch,
//  oft außerhalb der Blickrichtung. Wer gerade dran ist, soll man hören
//  können, ohne hinzusehen – das passt zur Vorgabe, dass das eigentliche
//  Spiel am Tisch stattfindet und nicht auf dem Display.
//
//  Eigene Ein-/Aus-Einstellung getrennt vom Ton: Klänge will man fast immer,
//  eine sprechende App je nach Lautstärke im Raum eher nicht.
//

import Foundation
import AVFoundation

enum SpeechAnnouncer {

    private static let preferenceKey = "beerstats.speechEnabled"
    private static let synthesizer = AVSpeechSynthesizer()

    /// Standardmäßig aus: Eine App, die unaufgefordert spricht, überrascht
    /// mehr als sie hilft. Wer es will, schaltet es ein.
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: preferenceKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: preferenceKey) }
    }

    /// Kündigt den nächsten Werfer an.
    static func announceTurn(playerName: String) {
        speak("\(playerName) ist dran")
    }

    static func announce(_ text: String) {
        speak(text)
    }

    static func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private static func speak(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }

        // Eine noch laufende Ansage abbrechen – bei schnellen Zugwechseln
        // würden sich die Namen sonst stapeln und hinterherhinken.
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
        // Etwas schneller als normal: Es ist eine Zwischenmeldung, keine
        // Vorlesung, und am Tisch soll sie nicht im Weg stehen.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.08
        utterance.volume = 0.9
        synthesizer.speak(utterance)
    }
}
