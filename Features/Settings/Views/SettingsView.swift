//
//  SettingsView.swift
//  BeerStats
//
//  Alles, was man einmal einstellt und dann in Ruhe laesst.
//
//  Vorher lagen diese Schalter als vier Symbole in der Leiste der
//  Spielauswahl: abmelden, Ton, Ansage, Entwicklereinstellungen. Vier
//  Symbole, von denen man drei nie braucht, und eines davon meldet einen ab
//  – direkt neben der Spielauswahl. Das war keine Leiste, das war eine
//  Ablage.
//
//  Die Haerte steht hier UND weiterhin im Hauptmenue. Das ist kein
//  Versehen: Sie wird am Tisch entschieden, kurz bevor es losgeht, und wer
//  dafuer erst in die Einstellungen abbiegen muss, laesst es. Beide Wege
//  schreiben denselben Wert – es gibt keine zweite Wahrheit.
//

import SwiftUI

struct SettingsView: View {

    let container: AppContainer
    let ownerId: String

    /// Spiegeln die dauerhaft gespeicherten Werte, damit der Schalter sofort
    /// umspringt – UserDefaults meldet sich nicht von selbst bei SwiftUI.
    @State private var isSoundOn = SoundManager.isEnabled
    @State private var isSpeechOn = SpeechAnnouncer.isEnabled
    @AppStorage(DrinkRules.shotsStorageKey) private var shotsEnabled = true
    @AppStorage(AppAppearance.backdropKey) private var backdropRaw = BackdropStyle.bubbles.rawValue
    @AppStorage(AppAppearance.neonEdgesKey) private var neonEdgesOn = true

    @State private var showsSignOutConfirmation = false

    var body: some View {
        ZStack {
            AmbientBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    appearanceSection
                    soundSection
                    drinkSection
                    developerSection
                    accountSection
                }
                .padding(20)
            }
            .verticalScrollOnly()
        }
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Wirklich abmelden?",
            isPresented: $showsSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Abmelden", role: .destructive) {
                try? container.authRepository.signOut()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Deine Profile und Partien bleiben im Konto. Zum Weiterspielen musst du dich wieder anmelden.")
        }
    }

    // MARK: - Darstellung

    /// Der Look ist Geschmack, und Geschmack gehoert nicht fest verdrahtet.
    ///
    /// Beides wirkt sofort und ueberall: Hintergrund und Kanten werden von
    /// den Bausteinen selbst gelesen, nicht von den einzelnen Ansichten.
    private var appearanceSection: some View {
        section("DARSTELLUNG") {
            Text("HINTERGRUND")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .kerning(1.2)
                .foregroundStyle(BeerStatsColor.textSecondary)

            ChoiceRow(
                options: BackdropStyle.allCases.map {
                    ChoiceOption(value: $0.rawValue, title: $0.title, detail: $0.detail)
                },
                selection: $backdropRaw
            )

            toggleRow(
                title: "Leuchtende Kanten",
                detail: neonEdgesOn
                    ? "Karten glühen in ihrer Farbe"
                    : "Nur eine feine Linie – ruhiger, aber die Karten bleiben abgegrenzt",
                isOn: $neonEdgesOn
            )
            .padding(.top, 2)

            Text("Farbschema und Hell-Modus kommen als Nächstes. Dafür müssen erst alle Farben aus dem Asset-Katalog in den Code – sonst gäbe es nur eine Palette zur Auswahl.")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(BeerStatsColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Ton

    private var soundSection: some View {
        section("TON") {
            toggleRow(
                title: "Geräusche",
                detail: "Treffer, Balls Back, Sieg – selbst erzeugte Klänge",
                isOn: Binding(
                    get: { isSoundOn },
                    set: { neu in
                        isSoundOn = neu
                        SoundManager.isEnabled = neu
                        if neu { SoundManager.play(.tap) }
                        HapticManager.lightImpact()
                    }
                )
            )

            toggleRow(
                title: "Sprachansage",
                detail: "Sagt an, was gerade passiert ist",
                isOn: Binding(
                    get: { isSpeechOn },
                    set: { neu in
                        isSpeechOn = neu
                        SpeechAnnouncer.isEnabled = neu
                        if neu { SpeechAnnouncer.announce("Ansage ist an") }
                        HapticManager.lightImpact()
                    }
                )
            )
        }
    }

    // MARK: - Trinkregeln

    private var drinkSection: some View {
        section("TRINKREGELN") {
            DrinkIntensityPicker()

            toggleRow(
                title: "Mit Shots",
                detail: shotsEnabled
                    ? "Karten dürfen Shots verlangen"
                    : "Shots werden in Schlücke umgerechnet",
                isOn: $shotsEnabled
            )

            Text("Gilt für alle Partyspiele. Dieselbe Einstellung steht auch im Hauptmenü – sie wird am Tisch entschieden, nicht hier.")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(BeerStatsColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Entwickler

    private var developerSection: some View {
        section("ENTWICKLER") {
            NavigationLink {
                DeveloperSettingsView(
                    repository: container.playerProfileRepository,
                    ownerId: ownerId
                )
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Entwicklereinstellungen")
                            .font(BeerStatsFont.headline)
                            .foregroundStyle(BeerStatsColor.textPrimary)
                        Text("Passwortgeschützt")
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: - Konto

    private var accountSection: some View {
        section("KONTO") {
            Button {
                showsSignOutConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .frame(width: 24)
                    Text("Abmelden")
                        .font(BeerStatsFont.headline)
                    Spacer()
                }
                .foregroundStyle(BeerStatsColor.error)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: - Bausteine

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .kerning(1.8)
                .foregroundStyle(BeerStatsColor.textSecondary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassPanel(cornerRadius: 18)
    }

    private func toggleRow(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text(detail)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(BeerStatsColor.accent)
    }
}
