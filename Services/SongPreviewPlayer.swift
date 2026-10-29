//
//  SongPreviewPlayer.swift
//  BeerStats
//
//  Spielt das Lied der Hitparade ab: die 30-Sekunden-Hoerprobe, die Apple
//  zu fast jedem Lied frei anbietet. Ohne Abo, ohne Konto, ohne fremde App –
//  und ohne dass irgendwo Titel, Interpret oder Cover stehen.
//
//  Warum nicht Spotify (Entscheidung vom 29. Oktober): Ein Spotify-Link
//  oeffnet die Spotify-App, und die zeigt sofort den Titel. Unsichtbar
//  abspielen ginge nur ueber Spotifys Entwickler-Baukasten, wie Hitster es
//  macht – mit Premium, installierter App und einem eigenen
//  Entwicklerkonto. Spotify gibt es deshalb erst NACH dem Aufdecken, als
//  Link zum Weiterhoeren.
//
//  Im Repository steht je Lied nur Apples Nummer (`SongCard.appleId`), keine
//  Musik. Die Adresse der Hoerprobe wird erst am Tisch geholt: Apple kann sie
//  aendern, die Nummer bleibt.
//

import AVFoundation
import Combine
import Foundation

@MainActor
final class SongPreviewPlayer: ObservableObject {

    enum State: Equatable {
        case idle
        case loading
        case playing
        case paused
        /// Die Hoerprobe ist durchgelaufen.
        case finished
        /// Kein Netz, oder Apple kennt das Lied nicht mehr.
        case failed
    }

    /// So lang ist eine Hoerprobe bei Apple.
    static let previewLength = 30.0
    /// Laenger wartet am Tisch niemand auf ein Lied.
    private static let timeout: TimeInterval = 10

    @Published private(set) var state: State = .idle
    /// Wie viel der Hoerprobe gelaufen ist, von 0 bis 1.
    @Published private(set) var progress = 0.0
    /// Das Cover – erst nach dem Aufdecken zu zeigen.
    @Published private(set) var artworkURL: URL?

    private struct Preview {
        let audio: URL
        let artwork: URL?
    }

    private let player = AVPlayer()
    private var cache: [Int: Preview] = [:]
    private var loading: Task<Void, Never>?
    private var loadedId: Int?
    private var timeObserver: Any?
    private var watchers: Set<AnyCancellable> = []

    init() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] zeit in
            // Der Block laeuft auf dem Hauptfaden, ist aber nicht als solcher
            // markiert – `MainActor.assumeIsolated` gibt es erst ab iOS 17
            Task { @MainActor in self?.tick(zeit) }
        }

        // Ein Anruf oder ein anderer Ton haelt das Abspielen an – dann soll
        // der Knopf nicht weiter "Pause" anbieten
        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self, status == .paused, self.state == .playing else { return }
                self.state = .paused
            }
            .store(in: &watchers)

        // Die Adresse war da, die Datei kommt aber nicht – dann soll der Zug
        // nicht stumm auf ein Lied warten
        player.publisher(for: \.currentItem?.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self, status == .failed else { return }
                self.state = .failed
            }
            .store(in: &watchers)

        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] meldung in
                guard let self, (meldung.object as? AVPlayerItem) === self.player.currentItem else { return }
                self.state = .finished
                self.progress = 1
            }
            .store(in: &watchers)
    }

    // MARK: - Steuern

    /// Laedt das Lied und spielt es an, sobald es da ist.
    func play(_ song: SongCard) {
        if loadedId == song.appleId, state != .failed {
            resume()
            return
        }
        loading?.cancel()
        player.replaceCurrentItem(with: nil)
        loadedId = nil
        progress = 0
        artworkURL = nil
        state = .loading

        loading = Task { [weak self] in
            guard let self else { return }
            guard let probe = await self.preview(for: song.appleId), !Task.isCancelled else {
                if !Task.isCancelled { self.state = .failed }
                return
            }
            self.loadedId = song.appleId
            self.artworkURL = probe.artwork
            self.player.replaceCurrentItem(with: AVPlayerItem(url: probe.audio))
            self.resume()
        }
    }

    /// Holt schon die Adresse des naechsten Lieds, damit es nach dem
    /// "Weiter" sofort laeuft.
    func prefetch(_ song: SongCard) {
        guard cache[song.appleId] == nil else { return }
        Task { [weak self] in _ = await self?.preview(for: song.appleId) }
    }

    func resume() {
        guard player.currentItem != nil else { return }
        usePlaybackSession()
        if state == .finished { player.seek(to: .zero) }
        player.play()
        state = .playing
    }

    func pause() {
        player.pause()
        if state == .playing { state = .paused }
    }

    func restart() {
        guard player.currentItem != nil else { return }
        player.seek(to: .zero)
        progress = 0
        resume()
    }

    /// Haelt an und gibt den Ton wieder frei – beim Verlassen des Spiels und
    /// vor jedem neuen Lied, das noch nicht laufen soll.
    func stop() {
        loading?.cancel()
        player.pause()
        player.replaceCurrentItem(with: nil)
        loadedId = nil
        progress = 0
        state = .idle
        SoundManager.useAmbientSession()
    }

    // MARK: - Intern

    private func tick(_ zeit: CMTime) {
        guard state == .playing || state == .paused else { return }
        let laenge = player.currentItem?.duration.seconds ?? Self.previewLength
        let gesamt = laenge.isFinite && laenge > 0 ? laenge : Self.previewLength
        progress = min(1, max(0, zeit.seconds / gesamt))
    }

    /// Fuer die Dauer des Lieds eine Sitzung, die auch bei stummgeschaltetem
    /// iPhone spielt: Hier ist die Musik der Inhalt des Spiels und keine
    /// Zierde wie die App-Klaenge. Eine Playlist auf demselben Handy haelt
    /// dafuer an – sonst hoerte niemand, was geraten werden soll.
    private func usePlaybackSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            AppLogger.app.error("Audio-Sitzung fuer die Hoerprobe ging nicht: \(error.localizedDescription)")
        }
    }

    private struct Antwort: Decodable {
        struct Eintrag: Decodable {
            let previewUrl: URL?
            let artworkUrl100: String?
        }
        let results: [Eintrag]
    }

    private func preview(for appleId: Int) async -> Preview? {
        if let bekannt = cache[appleId] { return bekannt }
        guard var adresse = URLComponents(string: "https://itunes.apple.com/lookup") else { return nil }
        adresse.queryItems = [
            URLQueryItem(name: "id", value: String(appleId)),
            URLQueryItem(name: "country", value: "de"),
            URLQueryItem(name: "entity", value: "song"),
        ]
        guard let url = adresse.url else { return nil }

        var anfrage = URLRequest(url: url)
        anfrage.timeoutInterval = Self.timeout
        do {
            let (daten, _) = try await URLSession.shared.data(for: anfrage)
            let eintrag = try JSONDecoder().decode(Antwort.self, from: daten).results.first
            guard let audio = eintrag?.previewUrl else { return nil }
            // Apple liefert das Cover in 100 Punkten; dieselbe Adresse gibt
            // es auch groesser, fuer die Huelle beim Aufdecken
            let cover = eintrag?.artworkUrl100
                .map { $0.replacingOccurrences(of: "100x100", with: "600x600") }
                .flatMap { URL(string: $0) }
            let probe = Preview(audio: audio, artwork: cover)
            cache[appleId] = probe
            return probe
        } catch {
            AppLogger.app.error("Hoerprobe \(appleId) nicht geladen: \(error.localizedDescription)")
            return nil
        }
    }
}
