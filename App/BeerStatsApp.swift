//
//  BeerStatsApp.swift
//  BeerStats
//
//  Einstiegspunkt der App. Verantwortlich für:
//  - Initialisierung von Firebase über den AppDelegate
//  - Aufbau des zentralen Dependency-Injection-Containers
//  - Bereitstellung des globalen AppState an alle Views
//

import SwiftUI

@main
struct BeerStatsApp: App {

    // Bindet den AppDelegate ein, damit Firebase (via `application(_:didFinishLaunchingWithOptions:)`)
    // korrekt initialisiert wird, bevor irgendeine View oder ein Service darauf zugreift.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // Der globale App-Zustand (z. B. Auth-Status, aktives Spiel).
    // Wird als StateObject gehalten, damit er die gesamte App-Lebensdauer überlebt.
    @StateObject private var appState: AppState

    // Der zentrale Dependency-Container. Wird einmal beim Start zusammengesteckt
    // und über die SwiftUI-Environment an alle Views/ViewModels weitergereicht.
    private let container: AppContainer

    init() {
        let container = AppContainer.live()
        self.container = container
        _appState = StateObject(wrappedValue: AppState(authService: container.authService))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environment(\.appContainer, container)
                .preferredColorScheme(.dark) // BeerStats ist primär als Dark-Mode-App konzipiert
        }
    }
}
