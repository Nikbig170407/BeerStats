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
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 44))
                .foregroundStyle(BeerStatsColor.accent)
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
        }
    }
}
