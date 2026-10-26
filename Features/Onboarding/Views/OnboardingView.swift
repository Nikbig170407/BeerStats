//
//  OnboardingView.swift
//  BeerStats
//
//  Erster echter, bedienbarer Screen der App. Ein einzelner View für
//  Login UND Registrierung (Umschaltung über das ViewModel), um Doppelung
//  zwischen zwei fast identischen Formularen zu vermeiden.
//

import SwiftUI

struct OnboardingView: View {

    @EnvironmentObject private var appState: AppState

    @StateObject private var viewModel: OnboardingViewModel

    init(authRepository: AuthRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(authRepository: authRepository))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                VStack(spacing: 12) {
                    if viewModel.mode == .signUp {
                        BeerStatsTextField(
                            placeholder: "Nutzername",
                            text: $viewModel.username,
                            autocapitalization: .never
                        )
                        BeerStatsTextField(
                            placeholder: "Anzeigename",
                            text: $viewModel.displayName
                        )
                    }

                    BeerStatsTextField(
                        placeholder: "E-Mail",
                        text: $viewModel.email,
                        keyboardType: .emailAddress,
                        autocapitalization: .never
                    )
                    BeerStatsTextField(
                        placeholder: "Passwort",
                        text: $viewModel.password,
                        isSecure: true
                    )
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.error)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }

                actionArea
            }
            .padding(24)
            .animation(AppAnimation.standard, value: viewModel.mode)
        }
        .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(spacing: 8) {
            BeerGlassMark(size: 58)
                .padding(.bottom, 4)
            Text("BeerStats")
                .font(BeerStatsFont.largeTitle)
                .foregroundStyle(BeerStatsColor.textPrimary)
            Text(viewModel.mode == .signIn ? "Willkommen zurück" : "Konto erstellen")
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
        .padding(.top, 40)
    }

    private var actionArea: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                CupFillLoadingView(size: 56)
            } else {
                PrimaryButton(title: viewModel.submitButtonTitle) {
                    Task { await viewModel.submit() }
                }
            }

            SecondaryButton(title: viewModel.toggleModeButtonTitle) {
                viewModel.toggleMode()
            }

            // Der Weg vorbei am Formular. Steht UNTER den beiden anderen
            // und leise: Wer ein Konto will, soll es zuerst sehen. Wer
            // keines will, findet trotzdem hier heraus, dass es auch ohne
            // geht – und genau das ist die Tuer fuer jede fremde Runde, die
            // sonst wieder zumacht (siehe `GuestMode`).
            VStack(spacing: 6) {
                QuietButton(title: "Ohne Konto loslegen") {
                    appState.enterGuestMode()
                }

                Text("Alle Partyspiele laufen sofort. Beerpong kommt dazu, sobald du ein Konto hast.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
        }
    }
}
