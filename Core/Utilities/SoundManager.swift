//
//  SoundManager.swift
//  BeerStats
//
//  Klänge für die Ereignisse im Spiel.
//
//  Alle Dateien liegen unter `Resources/Sounds`, und woher jede kommt,
//  steht in `HERKUNFT.md` daneben. Die Beerpong-Signale stammen von Mixkit;
//  der Airball ist ein eigener Ausschnitt, die Bombe selbst erzeugt.
//
//  Neue Klänge kommen nur aus zwei Quellen, beide ohne Lizenz, die man im
//  Blick behalten müsste – das Repository ist öffentlich:
//  - gerechnet (`scripts/make_sounds.py`): Ring of Fire seit dem
//    28. Oktober, dazu Strafe, Gong, Papier, Klebeband und Plattennadel;
//  - aus einem CC0-Paket (`scripts/import_sounds.py`): Karten, Würfel,
//    Chips, Richtig, Falsch, Ticken und der kleine Sieg, seit dem
//    4. November (Wunsch des Nutzers: "mehr Sounds").
//
//  **Ein Klang heißt überall dasselbe.** Bis zum 4. November liehen sich
//  die Partyspiele die Klänge von Beerpong: Jede Strafe war die
//  Bombenexplosion, das Ende der Zeit auch, und Schocken würfelte mit dem
//  Geräusch eines Balls im Becher. Ein Klang, der in fünf Spielen fünf
//  Dinge heißt, sagt nichts mehr. Jetzt hat jeder Moment seinen Klang, und
//  derselbe Moment klingt in jedem Spiel gleich – wie die Kostenarten bei
//  den Szenen.
//
//  Zum Austauschen reicht die Datei: Der Name entspricht dem Fall im Enum,
//  gesucht wird in der Reihenfolge wav, mp3, m4a, caf. Eine alte .wav neben
//  einer neuen .mp3 gewinnt also – die muss weg.
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
    /// Eine Karte wird gezogen oder gelegt – in vier Fassungen, reihum.
    case cardFlip

    // Partyspiele, seit dem 4. November. Jeder Fall ist ein MOMENT, kein
    // Spiel: Er klingt in jedem Spiel gleich, in dem er vorkommt.
    /// Würfeln (Schocken, Mäxchen).
    case diceRoll
    /// Ein Einsatz liegt: Wetten beim Pferderennen, ein Rad im Roulette,
    /// ein Kreuz im Trinkbingo.
    case chips
    /// Eine Antwort war richtig, eine Karte geschafft.
    case correct
    /// Eine Antwort war falsch – das kostet vielleicht etwas, ist aber noch
    /// nicht die Strafe selbst.
    case wrong
    /// Die letzten Sekunden einer Uhr.
    case countdownTick
    /// Eine Runde ist gewonnen. Die große Fanfare (`victory`) bleibt für
    /// den Sieg im ganzen Spiel.
    case roundWon
    /// Jemand muss trinken (oder was die Strafe gerade ist). Die Explosion
    /// gehört nur noch der Bombe.
    case penalty
    /// Die Zeit ist um.
    case timeUp
    /// Etwas Verdecktes wird aufgedeckt: eine Akte, eine Auflösung.
    case reveal
    /// Das Klebeband kommt vom Zettel (Verbotene Wörter).
    case tapeRip
    /// Die Nadel setzt auf, bevor das Lied in der Hitparade kommt.
    case needleDrop

    // Ring of Fire. Vorher teilten sich dort neun von dreizehn Rängen den
    // leisen Kartenklang, und die übrigen liehen sich Beerpong-Klänge – am
    // Tisch hörte man nicht, welche Karte kam. Jetzt klingt jeder Rang
    // anders, dazu Ziehen, Riss und Neulegen.
    case ringTick, ringStop, ringDraw
    case ringRank2, ringRank3, ringRank4, ringRank5, ringRank6, ringRank7, ringRank8
    case ringRank9, ringRank10, ringRank11, ringRank12, ringRank13, ringRank14
    case ringTear, ringHolds, ringShuffle, ringOut
    // Die Schichten zum Schlag (Vorschlag 2, 4. November): Wenn die Karte
    // landet, kommt zum Rangklang, was zur Szene gehoert – Donner zum Blitz,
    // ein Schalter zum Scheinwerfer. Wann welche, steht in `RingScene.cues`.
    case ringSplat, ringGush, ringStream, ringThunder, ringShimmer, ringChoir
    case ringBeat, ringWhoosh, ringHeartbeat, ringSpotlight, ringFlutter
    /// Ring durch: Wo sich der Kranz schliesst, faucht eine Saeule hoch.
    case ringBlaze

    /// Der Klang eines Rangs in Ring of Fire. Alles außerhalb von 2 bis 13
    /// ist das Ass – dieselbe Zuordnung wie bei den Regeln.
    static func ringRank(_ rank: Int) -> GameSound {
        GameSound(rawValue: "ringRank\(rank)") ?? .ringRank14
    }

    /// Unterstützte Endungen, in dieser Reihenfolge gesucht.
    static let supportedExtensions = ["wav", "mp3", "m4a", "caf"]

    /// Wie viele Fassungen dieser Klang hat. Was am Abend dutzendfach
    /// kommt – Karten, Würfel, Chips –, klingt sonst nach dem Schnipsel und
    /// nicht nach dem Tisch. Die Tonhöhe allein (`pitchVariation`) reicht
    /// dafür nicht: Dieselbe Karte, etwas höher, ist immer noch dieselbe.
    var variants: Int {
        switch self {
        case .cardFlip: return 4
        case .diceRoll, .chips: return 3
        default: return 1
        }
    }

    /// Die Datei für einen Durchlauf – reihum durch die Fassungen. Die erste
    /// heißt wie der Fall, die weiteren tragen eine Nummer (`cardFlip2`);
    /// so schreibt sie `scripts/import_sounds.py`.
    func fileName(forRepetition durchlauf: Int) -> String {
        let fassung = durchlauf % variants
        return fassung == 0 ? rawValue : "\(rawValue)\(fassung + 1)"
    }

    /// Alle Dateien dieses Klangs.
    var fileNames: [String] {
        (0..<variants).map { fileName(forRepetition: $0) }
    }

    /// Nach dieser Zeit wird ausgeblendet. `nil` heißt: ganz abspielen.
    ///
    /// Die eingekauften Klänge sind länger, als das Spiel sie braucht: Der
    /// Fehlwurf bringt über vier Sekunden mit, On Fire über sechs. Beides
    /// passiert im Minutentakt – ungekürzt läge dauernd ein Klang über dem
    /// nächsten. Gekappt wird jeweils dort, wo das Kennzeichnende vorbei ist.
    var maximumDuration: TimeInterval? {
        switch self {
        case .miss: return 0.8       // nur der Aufprall
        case .cardFlip: return 1.0   // ein Blatt, kein ganzes Mischen
        case .ballsBack: return 2.0
        case .onFire: return 2.5
        case .airball: return 3.0
        case .victory: return 5.0
        case .cupHit, .bombe, .reRack, .tap: return nil
        // Beim Einbau geschnitten oder gerechnet – schon so kurz, wie sie
        // sein sollen
        case .diceRoll, .chips, .correct, .wrong, .countdownTick, .roundWon,
             .penalty, .timeUp, .reveal, .tapeRip, .needleDrop:
            return nil
        // Gerechnet und schon so kurz, wie sie sein sollen
        case .ringTick, .ringStop, .ringDraw, .ringRank2, .ringRank3, .ringRank4, .ringRank5,
             .ringRank6, .ringRank7, .ringRank8, .ringRank9, .ringRank10, .ringRank11,
             .ringRank12, .ringRank13, .ringRank14, .ringTear, .ringHolds, .ringShuffle, .ringOut:
            return nil
        }
    }

    /// Wie stark sich dieser Klang bei Wiederholung veraendert.
    ///
    /// Zehn Klaenge fuer eine ganze App heisst: Ein paar davon hoert man
    /// hundertmal am Abend. Ein Becher-Treffer, der jedes Mal bis aufs
    /// Sample identisch klingt, verraet nach zwanzig Wuerfen, dass es
    /// derselbe Schnipsel ist – und ab da hoert man den Schnipsel statt des
    /// Treffers. Am echten Tisch klingt kein Becher wie der vorige.
    ///
    /// Veraendert wird die Abspielrate, also Tempo UND Tonhoehe zugleich.
    /// Bei kurzen, perkussiven Klaengen ist genau das richtig; bei einer
    /// Melodie waere es ein Fehler.
    ///
    /// Die Signaturklaenge bleiben deshalb fest: Ein Sieg, der jedes Mal
    /// anders klingt, klingt kaputt. Variiert wird nur, was oft kommt.
    var pitchVariation: Float {
        switch self {
        case .cupHit, .tap, .cardFlip, .miss: return 0.06
        // Die Ratsche hoert man zwanzigmal je Zug – genau das, was variieren soll
        case .ringTick: return 0.06
        case .airball, .bombe, .ballsBack, .onFire, .reRack, .victory: return 0
        // Was dutzendfach kommt, wechselt zusaetzlich zu den Fassungen leicht
        // die Tonhoehe – die Uhr nicht: Ein Ticken, das schwankt, klingt kaputt
        case .diceRoll, .chips: return 0.06
        // Bedeutungen, keine Geraeusche: "richtig" soll jedes Mal gleich klingen
        case .correct, .wrong, .countdownTick, .roundWon, .penalty, .timeUp,
             .reveal, .tapeRip, .needleDrop:
            return 0
        // Die Raenge sind Signaturklaenge: Jede Karte soll klingen wie sie selbst
        case .ringStop, .ringDraw, .ringRank2, .ringRank3, .ringRank4, .ringRank5,
             .ringRank6, .ringRank7, .ringRank8, .ringRank9, .ringRank10, .ringRank11,
             .ringRank12, .ringRank13, .ringRank14, .ringTear, .ringHolds, .ringShuffle, .ringOut:
            return 0
        // Die Schichten gehoeren zu einer Szene und klingen jedes Mal gleich –
        // bis auf die Stroeme, die fuenfmal hintereinander aufschlagen
        case .ringStream: return 0.08
        case .ringSplat, .ringGush, .ringThunder, .ringShimmer, .ringChoir,
             .ringBeat, .ringWhoosh, .ringHeartbeat, .ringSpotlight, .ringFlutter, .ringBlaze:
            return 0
        }
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
    /// Je Datei ein Spieler – ein Klang mit Fassungen hat mehrere.
    private static var players: [String: AVAudioPlayer] = [:]
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

        let durchlauf = nextRepetition(of: sound)
        guard let player = player(named: sound.fileName(forRepetition: durchlauf)) else { return }

        // Ein noch laufender Ausblend-Auftrag würde sonst den neuen
        // Durchlauf mitten im Ton abwürgen.
        pendingStops[sound]?.cancel()
        pendingStops[sound] = nil

        player.volume = sound.volume
        player.rate = rate(for: sound, repetition: durchlauf)
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
        useAmbientSession()
    }

    /// Die Sitzung der App-Klaenge. Oeffentlich, weil die Hitparade fuer die
    /// Dauer eines Lieds eine andere braucht (`SongPreviewPlayer`) und danach
    /// hierher zurueckkehren muss – an EINER Stelle steht, wie sie aussieht.
    static func useAmbientSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            AppLogger.app.error("Audio-Sitzung konnte nicht gesetzt werden: \(error.localizedDescription)")
        }
    }

    /// Wie oft dieser Klang schon lief – fuer Fassung und Variation.
    private static var repetitions: [GameSound: Int] = [:]

    private static func nextRepetition(of sound: GameSound) -> Int {
        let durchlauf = repetitions[sound] ?? 0
        repetitions[sound] = durchlauf + 1
        return durchlauf
    }

    /// Die Abspielrate dieses Durchlaufs.
    ///
    /// Gerechnet und nicht gewuerfelt: Zufall trifft irgendwann zweimal
    /// hintereinander denselben Wert, und genau das hoert man – zwei
    /// identische Treffer nacheinander fallen mehr auf als zwanzig
    /// verschiedene. Die Stufen laufen deshalb reihum, und weil es fuenf
    /// Stufen sind und hoechstens vier Fassungen, trifft dieselbe Fassung
    /// erst nach vielen Durchlaeufen wieder auf dieselbe Stufe.
    private static func rate(for sound: GameSound, repetition durchlauf: Int) -> Float {
        let spanne = sound.pitchVariation
        guard spanne > 0 else { return 1 }

        let schritt = durchlauf % 5

        // Fuenf Stufen um 1 herum: -2, -1, 0, +1, +2 mal ein Fuenftel der
        // Spanne. Hoerbar, aber nicht als Tonart.
        let versatz = Float(schritt - 2) * (spanne / 2)
        return 1 + versatz
    }

    private static func player(named name: String) -> AVAudioPlayer? {
        if let existing = players[name] { return existing }

        for fileExtension in GameSound.supportedExtensions {
            guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else {
                continue
            }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                // Ohne das ignoriert der Player jede Rate ausser 1.
                player.enableRate = true
                player.prepareToPlay()
                players[name] = player
                return player
            } catch {
                AppLogger.app.error("Klang \(name) nicht ladbar: \(error.localizedDescription)")
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
