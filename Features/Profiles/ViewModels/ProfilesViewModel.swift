//
//  ProfilesViewModel.swift
//  BeerStats
//
//  Verwaltet die Mitspieler-Profile eines Kontos.
//
//  Beobachtet die Sammlung als Echtzeit-Stream statt einmalig zu laden:
//  Nach einem beendeten Spiel schreiben sich die Statistiken selbst fort,
//  und die Liste soll das ohne manuelles Neuladen zeigen.
//

import Foundation

@MainActor
final class ProfilesViewModel: ObservableObject {

    @Published private(set) var profiles: [PlayerProfile] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let repository: PlayerProfileRepositoryProtocol
    let ownerId: String
    private var observationTask: Task<Void, Never>?

    init(repository: PlayerProfileRepositoryProtocol, ownerId: String) {
        self.repository = repository
        self.ownerId = ownerId
        observe()
    }

    deinit {
        observationTask?.cancel()
    }

    /// Aktive Profile zuerst – ausgemusterte Mitspieler rutschen nach unten,
    /// statt aus der Liste zu verschwinden.
    var activeProfiles: [PlayerProfile] { profiles.filter(\.isActive) }
    var inactiveProfiles: [PlayerProfile] { profiles.filter { !$0.isActive } }

    private func observe() {
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await profiles in repository.observeProfiles(ownerId: ownerId) {
                self.profiles = profiles
                self.isLoading = false
            }
        }
    }

    func createProfile(name: String, emoji: String, color: ProfileColor) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            try await repository.createProfile(name: name, emoji: emoji, color: color, ownerId: ownerId)
            HapticManager.success()
            return true
        } catch {
            errorMessage = AppError.from(error).errorDescription
            HapticManager.error()
            return false
        }
    }

    func updateProfile(
        _ profile: PlayerProfile,
        name: String,
        emoji: String,
        color: ProfileColor,
        isActive: Bool
    ) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            try await repository.updateProfile(
                profile,
                name: name,
                emoji: emoji,
                color: color,
                isActive: isActive,
                ownerId: ownerId
            )
            HapticManager.success()
            return true
        } catch {
            errorMessage = AppError.from(error).errorDescription
            HapticManager.error()
            return false
        }
    }
}
