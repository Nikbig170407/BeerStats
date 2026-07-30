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
import FirebaseCore

@main
struct BeerStatsApp: App {

    // Bindet den AppDelegate ein, damit Push-Registrierung
    // (via `application(_:didFinishLaunchingWithOptions:)`) korrekt abläuft.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // Der globale App-Zustand (z. B. Auth-Status, aktives Spiel).
    // Wird als StateObject gehalten, damit er die gesamte App-Lebensdauer überlebt.
    @StateObject private var appState: AppState

    // Der zentrale Dependency-Container. Wird einmal beim Start zusammengesteckt
    // und über die SwiftUI-Environment an alle Views/ViewModels weitergereicht.
    private let container: AppContainer

    init() {
        // WICHTIG: FirebaseApp.configure() muss hier, direkt im App-Init,
        // aufgerufen werden – nicht erst im AppDelegate. SwiftUIs Start-
        // reihenfolge garantiert nicht, dass AppDelegate.didFinishLaunching
        // vor diesem init() läuft. Da AppContainer.live() sofort einen
        // FirebaseAuthService erzeugt (der intern Auth.auth() aufruft),
        // muss Firebase zu diesem Zeitpunkt bereits konfiguriert sein –
        // sonst stürzt die App direkt beim Start ab.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

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
