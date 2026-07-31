//
//  ProfileEditorView.swift
//  BeerStats
//
//  Anlegen und Bearbeiten eines Mitspieler-Profils.
//
//  Ein Screen für beide Fälle: Die Felder sind identisch, nur Titel und
//  Aktionsbeschriftung unterscheiden sich. Beim Bearbeiten kommt der
//  Aktiv-Schalter dazu.
//
//  Emoji und Farbe werden bewusst aus festen Sätzen gewählt statt per
//  Tastatur oder Farbrad: Das geht schneller, sieht in der Liste
//  einheitlich aus, und es kann kein leeres oder mehrzeiliges Emoji
//  entstehen.
//

import SwiftUI

struct ProfileEditorView: View {

    /// `nil` bedeutet: neues Profil anlegen.
    let existingProfile: PlayerProfile?
    let isSaving: Bool
    let onSave: (String, String, ProfileColor, Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var emoji: String
    @State private var color: ProfileColor
    @State private var isActive: Bool

    private static let emojiChoices = [
        "🍺", "🔥", "🎯", "⚡️", "🏆", "💣", "🌀", "🏓",
        "😎", "🤠", "👑", "🦊", "🐻", "🦅", "🐺", "🦁"
    ]

    init(
        existingProfile: PlayerProfile?,
        isSaving: Bool,
        onSave: @escaping (String, String, ProfileColor, Bool) -> Void
    ) {
        self.existingProfile = existingProfile
        self.isSaving = isSaving
        self.onSave = onSave
        _name = State(initialValue: existingProfile?.name ?? "")
        _emoji = State(initialValue: existingProfile?.emoji ?? "🍺")
        _color = State(initialValue: existingProfile?.color ?? .amber)
        _isActive = State(initialValue: existingProfile?.isActive ?? true)
    }

    private var isEditing: Bool { existingProfile != nil }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
            && trimmedName.count <= AppConstants.Validation.profileNameMaxLength
            && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    preview
                    nameField
                    emojiPicker
                    colorPicker

                    if isEditing {
                        activeToggle
                    }
                }
                .padding(20)
            }
            .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle(isEditing ? "Profil bearbeiten" : "Neues Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Sichern" : "Anlegen") {
                        onSave(trimmedName, emoji, color, isActive)
                    }
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(canSave ? BeerStatsColor.accent : BeerStatsColor.textSecondary)
                    .disabled(!canSave)
                }
            }
        }
    }

    /// Zeigt sofort, wie der Spieler später in der Liste und am Tisch
    /// aussieht – Emoji und Farbe wirken abstrakt, bis man sie zusammen sieht.
    private var preview: some View {
        VStack(spacing: 10) {
            ProfileAvatarView(
                profile: PlayerProfile(
                    name: trimmedName.isEmpty ? "Neu" : trimmedName,
                    emoji: emoji,
                    color: color,
                    isActive: isActive
                ),
                size: 84
            )
            Text(trimmedName.isEmpty ? "Noch ohne Namen" : trimmedName)
                .font(BeerStatsFont.title)
                .foregroundStyle(trimmedName.isEmpty ? BeerStatsColor.textSecondary : BeerStatsColor.textPrimary)
        }
        .padding(.top, 8)
        .animation(AppAnimation.tap, value: color)
        .animation(AppAnimation.tap, value: emoji)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Name")
            BeerStatsTextField(placeholder: "z. B. Nik", text: $name)
            Text("\(trimmedName.count)/\(AppConstants.Validation.profileNameMaxLength)")
                .font(BeerStatsFont.caption)
                .foregroundStyle(
                    trimmedName.count > AppConstants.Validation.profileNameMaxLength
                        ? BeerStatsColor.error
                        : BeerStatsColor.textSecondary
                )
        }
    }

    private var emojiPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Zeichen")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                ForEach(Self.emojiChoices, id: \.self) { choice in
                    Button {
                        emoji = choice
                        HapticManager.lightImpact()
                    } label: {
                        Text(choice)
                            .font(.system(size: 24))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(emoji == choice ? color.color.opacity(0.28) : BeerStatsColor.surfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(emoji == choice ? color.color : .clear, lineWidth: 2)
                    )
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Farbe")
            HStack(spacing: 10) {
                ForEach(ProfileColor.allCases, id: \.self) { choice in
                    Button {
                        color = choice
                        HapticManager.lightImpact()
                    } label: {
                        Circle()
                            .fill(choice.color)
                            .frame(height: 40)
                            .overlay(
                                Circle().strokeBorder(
                                    BeerStatsColor.textPrimary,
                                    lineWidth: color == choice ? 3 : 0
                                )
                            )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel(choice.displayName)
                }
            }
        }
    }

    private var activeToggle: some View {
        BeerStatsCard {
            Toggle(isOn: $isActive) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spielt aktiv mit")
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                    Text("Inaktive Profile tauchen bei der Spielerauswahl nicht mehr auf, ihre Statistik bleibt aber erhalten.")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
            }
            .tint(BeerStatsColor.accent)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(BeerStatsFont.statLabel)
            .foregroundStyle(BeerStatsColor.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
