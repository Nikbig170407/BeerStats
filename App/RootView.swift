//
//  RootView.swift
//  BeerStats
//
//  Einziger Ort, an dem anhand des globalen AuthState entschieden wird,
//  ob Onboarding oder der eigentliche App-Inhalt gezeigt wird.
//

import SwiftUI
import Combine

struct RootView: View {

    @EnvironmentObject private var appState: AppState
    @Environment(\.appContainer) private var container

    var body: some View {
        ZStack {
            BeerStatsColor.backgroundPrimary
                .ignoresSafeArea()

            Group {
                switch appState.authState {
                case .unknown:
                    LaunchView()
                        .transition(.opacity)
                case .signedOut:
                    OnboardingView(authRepository: container.authRepository)
                        .transition(screenTransition)
                case .signedIn:
                    if let uid = container.authService.currentUserId {
                        HomeView(container: container, currentUserId: uid)
                            .transition(screenTransition)
                    } else {
                        LaunchView()
                    }
                }
            }
        }
        .animation(AppAnimation.standard, value: appState.authState)
    }

    /// Sanftes Einblenden mit leichtem Hineinwachsen statt hartem Schnitt
    /// zwischen den App-Hauptzuständen (angemeldet/abgemeldet).
    private var screenTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.98)),
            removal: .opacity
        )
    }
}

// MARK: - Platzhalter (werden in den jeweiligen Roadmap-Schritten ersetzt)

private struct LaunchView: View {
    var body: some View {
        VStack(spacing: 20) {
            CupFillLoadingView(size: 72)
            Text("BeerStats")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState(authService: RootViewPreviewAuthService()))
}

/// Nur für die Preview: vermeidet FirebaseAuth-Aufruf im SwiftUI-Canvas.
private final class RootViewPreviewAuthService: AuthServiceProtocol {
    var authStatePublisher: AnyPublisher<String?, Never> { Just(nil).eraseToAnyPublisher() }
    var currentUserId: String? { nil }
    func signUp(email: String, password: String) async throws -> String { "preview-uid" }
    func signIn(email: String, password: String) async throws -> String { "preview-uid" }
    func signOut() throws {}
    func deleteAccount() async throws {}
}
