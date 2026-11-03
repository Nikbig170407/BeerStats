//
//  ScreenAwake.swift
//  BeerStats
//
//  Der Bildschirm bleibt an, solange jemand die App benutzt – und geht
//  trotzdem aus, wenn das Handy vergessen ist.
//
//  Rueckmeldung vom 3. November: "Lass den Bildschirm laenger an. Der geht
//  zu schnell aus, wenn man nicht draufttippt." Wach hielten ihn bis dahin
//  nur der Tischmodus und die Beerpong-Partie; ueberall sonst galt die
//  Sperre des iPhones, meist eine halbe Minute. Am Tisch reicht die nicht:
//  Zwischen zwei Karten in Ring of Fire wird geredet, eine Pflicht dauert
//  Minuten, und danach muss erst jemand entsperren.
//
//  Laenger einstellen laesst iOS die Sperre nicht – es gibt nur an oder aus
//  (`isIdleTimerDisabled`). Deshalb rechnet die App ihre eigene, laengere
//  Sperre:
//
//  1. **Zehn Minuten ohne Beruehrung**, dann darf das iPhone wieder sperren
//     wie sonst. Ein Spiel, an dem gespielt wird, wird angetippt; ein Handy,
//     das so lange niemand anfasst, liegt in der Tasche oder ueber Nacht
//     auf dem Tisch – mit einer Szene, die dreissigmal je Sekunde neu
//     zeichnet. Die naechste Beruehrung haelt ihn wieder wach.
//  2. **App-weit, nicht je Spiel.** Am Tisch liegt auch der Abend mit der
//     Bilanz oder das Beerpong-Menue, und eine Liste von Screens, die
//     wachhalten, vergisst garantiert einen.
//  3. **Der Tischmodus haelt ihn ganz an**, ohne die zehn Minuten. Den
//     schaltet jemand ausdruecklich ein; die zehn Minuten sind fuer alle,
//     die es nicht getan haben.
//
//  Nur hier wird `isIdleTimerDisabled` gesetzt. Vorher taten es zwei
//  Stellen, und die eine machte die andere kaputt: Wer eine Beerpong-Partie
//  verliess, schaltete die Sperre wieder ein – auch im Tischmodus.
//
//  Beruehrungen zaehlt ein stiller Beobachter am Fenster (`TouchWatcher`)
//  und nicht jeder Screen fuer sich: Nur am Fenster kommen auch die
//  Beruehrungen in den Blaettern an – im Zahnrad, auf dem Kartenscreen.
//

import SwiftUI
import UIKit.UIGestureRecognizerSubclass

enum ScreenAwake {

    /// So lange ohne jede Beruehrung bleibt der Bildschirm an.
    static let untouchedLimit: TimeInterval = 10 * 60

    /// Die ganze Entscheidung, ohne Geraet pruefbar.
    static func staysAwake(alwaysOn: Bool, untouchedFor: TimeInterval) -> Bool {
        alwaysOn || untouchedFor < untouchedLimit
    }

    // MARK: - Zustand

    /// Tischmodus – siehe Dateikopf, Punkt 3.
    @MainActor private static var alwaysOn = false
    @MainActor private static var lastTouch = Date()

    /// Jemand hat den Bildschirm beruehrt (oder die App gerade geoeffnet,
    /// was dasselbe heisst).
    @MainActor static func noteTouch() {
        lastTouch = Date()
        apply()
    }

    @MainActor static func setAlwaysOn(_ isOn: Bool) {
        alwaysOn = isOn
        apply()
    }

    @MainActor private static func apply() {
        let wach = staysAwake(alwaysOn: alwaysOn, untouchedFor: Date().timeIntervalSince(lastTouch))
        // Nur bei einer Aenderung: Das hier laeuft bei jeder Beruehrung
        if UIApplication.shared.isIdleTimerDisabled != wach {
            UIApplication.shared.isIdleTimerDisabled = wach
        }
    }

    /// Sieht nach, ob die zehn Minuten um sind – und schlaeft bis zu dem
    /// Moment, an dem sie es fruehestens sein koennen. Wer dazwischen tippt,
    /// schiebt diesen Moment nur nach hinten; nachgesehen wird trotzdem
    /// selten. Laeuft, solange die App zu sehen ist (`.task`).
    @MainActor static func watchClock() async {
        while !Task.isCancelled {
            apply()
            let still = Date().timeIntervalSince(lastTouch)
            let rest = still < untouchedLimit ? untouchedLimit - still : untouchedLimit
            // Mindestens eine Sekunde: Knapp vor der Grenze rundet die Uhr
            // sonst in eine Schleife, die alle paar Mikrosekunden aufwacht.
            try? await Task.sleep(nanoseconds: UInt64(max(1, rest) * 1_000_000_000))
        }
    }

    /// Haengt den Beobachter an jedes Fenster, das noch keinen hat.
    @MainActor static func watchTouches() {
        let fenster = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        for window in fenster where !(window.gestureRecognizers ?? []).contains(where: { $0 is TouchWatcher }) {
            let watcher = TouchWatcher(target: nil, action: nil)
            // Er sieht nur zu: nimmt keine Beruehrung weg und haelt keine
            // auf. Siehe `TouchWatcher`.
            watcher.cancelsTouchesInView = false
            watcher.delaysTouchesBegan = false
            watcher.delaysTouchesEnded = false
            window.addGestureRecognizer(watcher)
        }
    }
}

/// Merkt sich jede Beruehrung im Fenster – und gibt sofort auf.
///
/// Ein Gestenerkenner am Fenster bekommt jede Beruehrung zu sehen, auch in
/// Blaettern und Vollbildern. Weil er schon beim ersten Kontakt scheitert,
/// erkennt er nie etwas: Er steht keiner Geste im Weg, kein Knopf und kein
/// Wischen wartet auf ihn.
private final class TouchWatcher: UIGestureRecognizer {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        ScreenAwake.noteTouch()
        state = .failed
    }
}

/// Setzt das alles in Gang – einmal, dort, wo die App zusammengesetzt wird.
private struct ScreenAwakeModifier: ViewModifier {

    let alwaysOn: Bool

    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear {
                ScreenAwake.watchTouches()
                ScreenAwake.setAlwaysOn(alwaysOn)
                ScreenAwake.noteTouch()
            }
            .onChange(of: alwaysOn) { neu in
                ScreenAwake.setAlwaysOn(neu)
            }
            // Wer in die App zurueckkommt, hat sie gerade angefasst – sonst
            // zaehlte die Pause im Hintergrund als Zeit ohne Beruehrung, und
            // der Bildschirm ginge kurz nach dem Zurueckkommen aus.
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                ScreenAwake.watchTouches()
                ScreenAwake.noteTouch()
            }
            .task { await ScreenAwake.watchClock() }
    }
}

extension View {

    /// Siehe `ScreenAwake`. `alwaysOn` ist der Tischmodus.
    func keepsScreenAwake(alwaysOn: Bool) -> some View {
        modifier(ScreenAwakeModifier(alwaysOn: alwaysOn))
    }
}
