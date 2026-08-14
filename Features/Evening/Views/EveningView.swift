//
//  EveningView.swift
//  BeerStats
//
//  Abend starten, Trinkbilanz fuehren, am Ende auswerten.
//
//  Die Bilanz ist der Kern und die eigentliche Neuerung: Die App sagt den
//  ganzen Abend, wer wie viel trinken muss, und hat es nie mitgeschrieben.
//  Alle Mengen laufen ohnehin ueber `DrinkAmount`, sie wurden bisher nur
//  angezeigt und vergessen.
//
//  Eintragen muss mit einem Griff gehen, sonst passiert es nicht. Deshalb
//  liegt pro Person eine Zeile mit drei Knoepfen da – Schluck, Shot, zurueck
//  – statt eines Formulars. Was am Tisch mehr als eine Bewegung kostet,
//  benutzt nach dem dritten Bier niemand mehr.
//

import SwiftUI

struct EveningView: View {

    let profiles: [PlayerProfile]

    @State private var evening: Evening?
    @State private var summary: Evening?
    @State private var chosen: Set<String> = []

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.accentSecondary)

            ScrollView {
                VStack(spacing: 20) {
                    if let summary {
                        summaryView(summary)
                    } else if let evening, evening.isRunning {
                        runningView(evening)
                    } else {
                        setupView
                    }
                }
                .padding(22)
            }
        }
        .navigationTitle("Abend")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { evening = EveningLog.current }
    }

    // MARK: - Vorbereitung

    private var setupView: some View {
        VStack(spacing: 18) {
            Text("🌙").font(.system(size: 56))

            Text("Wer ist heute dabei?")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("Der Abend sammelt alles, was ihr spielt – Beerpong und Partyspiele – und führt nebenbei die Trinkbilanz.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if profiles.isEmpty {
                Text("Lege zuerst Mitspieler an.")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.warning)
            }

            VStack(spacing: 8) {
                ForEach(profiles) { profile in
                    let id = profile.id ?? ""
                    Button {
                        if chosen.contains(id) { chosen.remove(id) } else { chosen.insert(id) }
                        HapticManager.lightImpact()
                    } label: {
                        HStack(spacing: 12) {
                            Text(profile.emoji).font(.system(size: 24))
                            Text(profile.name)
                                .font(BeerStatsFont.headline)
                                .foregroundStyle(BeerStatsColor.textPrimary)
                            Spacer()
                            Image(systemName: chosen.contains(id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(
                                    chosen.contains(id) ? BeerStatsColor.success : BeerStatsColor.textSecondary
                                )
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 12)
                        .glassPanel(cornerRadius: 15)
                        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }

            PrimaryButton(title: "Abend starten", systemImage: "moon.stars.fill") {
                EveningLog.start(with: profiles.filter { chosen.contains($0.id ?? "") })
                evening = EveningLog.current
                HapticManager.success()
                SoundManager.play(.victory)
            }
            .disabled(chosen.isEmpty)
            .opacity(chosen.isEmpty ? 0.5 : 1)
        }
    }

    // MARK: - Laufender Abend

    private func runningView(_ abend: Evening) -> some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text("🌙").font(.system(size: 44))
                Text("Läuft seit \(abend.readableDuration)")
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text(abend.entries.isEmpty
                     ? "Noch nichts gespielt"
                     : "\(abend.entries.count) \(abend.entries.count == 1 ? "Spiel" : "Spiele")")
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("TRINKBILANZ")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                ForEach(abend.participants) { teilnehmer in
                    tallyRow(teilnehmer)
                }
            }

            if !abend.entries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GESPIELT")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .kerning(1.8)
                        .foregroundStyle(BeerStatsColor.textSecondary)

                    ForEach(abend.entries.reversed()) { eintrag in
                        HStack(spacing: 10) {
                            Text(eintrag.emoji)
                            Text(eintrag.title)
                                .font(BeerStatsFont.caption)
                                .foregroundStyle(BeerStatsColor.textPrimary)
                            Spacer()
                            if let winner = eintrag.winner {
                                Text(winner)
                                    .font(BeerStatsFont.caption)
                                    .foregroundStyle(BeerStatsColor.success)
                            }
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .glassPanel(cornerRadius: 12)
                    }
                }
            }

            PrimaryButton(title: "Abend beenden", systemImage: "flag.checkered") {
                summary = EveningLog.finish()
                evening = nil
                HapticManager.success()
                SoundManager.play(.victory)
            }

            Button("Abend verwerfen") {
                EveningLog.discard()
                evening = nil
                chosen = []
            }
            .font(BeerStatsFont.caption)
            .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    /// Eine Zeile der Bilanz: Name, Stand, und drei Knoepfe.
    private func tallyRow(_ teilnehmer: EveningParticipant) -> some View {
        HStack(spacing: 10) {
            Text(teilnehmer.emoji).font(.system(size: 22))

            VStack(alignment: .leading, spacing: 1) {
                Text(teilnehmer.name)
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Text(standText(teilnehmer))
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 4)

            tallyButton("+1", tint: BeerStatsColor.accent) {
                EveningLog.addSips(1, to: teilnehmer.id)
            }
            tallyButton("🥃", tint: BeerStatsColor.error) {
                EveningLog.addShot(to: teilnehmer.id)
            }
            tallyButton("↩︎", tint: BeerStatsColor.textSecondary) {
                EveningLog.undoLastDrink(for: teilnehmer.id)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .glassPanel(cornerRadius: 15)
    }

    private func tallyButton(_ label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
            evening = EveningLog.current
            HapticManager.lightImpact()
        } label: {
            Text(label)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .glassPanel(cornerRadius: 12)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func standText(_ teilnehmer: EveningParticipant) -> String {
        if teilnehmer.sips == 0 && teilnehmer.shots == 0 { return "noch nichts" }
        var teile: [String] = []
        if teilnehmer.sips > 0 {
            teile.append(teilnehmer.sips == 1 ? "1 Schluck" : "\(teilnehmer.sips) Schlücke")
        }
        if teilnehmer.shots > 0 {
            teile.append(teilnehmer.shots == 1 ? "1 Shot" : "\(teilnehmer.shots) Shots")
        }
        return teile.joined(separator: " · ")
    }

    // MARK: - Auswertung

    private func summaryView(_ abend: Evening) -> some View {
        VStack(spacing: 18) {
            Text("🌅").font(.system(size: 56))

            Text("Der Abend")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("\(abend.readableDuration) · \(abend.entries.count) \(abend.entries.count == 1 ? "Spiel" : "Spiele")")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)

            if let sieger = abend.mostWins {
                highlight("🏆", "Meiste Siege", "\(sieger.name) — \(sieger.count)×", BeerStatsColor.warning)
            }

            if let durstig = abend.mostDrinks {
                highlight(
                    "🍺",
                    "Durstigste Person",
                    "\(durstig.name) — \(standText(durstig))",
                    BeerStatsColor.error
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("ENDSTAND")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                ForEach(abend.participants.sorted { $0.weight > $1.weight }) { teilnehmer in
                    HStack {
                        Text(teilnehmer.emoji)
                        Text(teilnehmer.name)
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textPrimary)
                        Spacer()
                        Text(standText(teilnehmer))
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .glassPanel(cornerRadius: 12)
                }
            }

            auszeichnungen(abend)

            // Kein erhobener Zeigefinger, aber auch kein Weggucken: Die Zahl
            // steht ohnehin da, und wer sie liest, weiss selbst Bescheid.
            Text("Trinkt Wasser und kommt gut heim.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .padding(.top, 4)

            PrimaryButton(title: "Fertig", systemImage: "checkmark") {
                summary = nil
                chosen = []
            }
        }
    }

    /// Plaketten fuer den Abend und fuer jeden, der eine bekommen hat.
    ///
    /// Personen ohne Auszeichnung tauchen gar nicht auf. Eine Ueberschrift
    /// mit "keine" darunter liest sich wie ein Vorwurf, und der Endstand
    /// darueber sagt ohnehin schon alles.
    @ViewBuilder
    private func auszeichnungen(_ abend: Evening) -> some View {
        let fuerDenAbend = EveningAchievements.forEvening(abend)
        let proPerson = abend.participants
            .map { ($0, EveningAchievements.forParticipant($0, in: abend)) }
            .filter { !$0.1.isEmpty }

        if !fuerDenAbend.isEmpty || !proPerson.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("AUSZEICHNUNGEN")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                if !fuerDenAbend.isEmpty {
                    AchievementRow(achievements: fuerDenAbend, tint: BeerStatsColor.accentSecondary)
                }

                ForEach(proPerson, id: \.0.id) { person, plaketten in
                    Text("\(person.emoji) \(person.name)")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .padding(.top, 4)

                    AchievementRow(achievements: plaketten, tint: BeerStatsColor.warning)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func highlight(_ emoji: String, _ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.system(size: 34))
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .kerning(1.4)
                .foregroundStyle(BeerStatsColor.textSecondary)
            Text(value)
                .font(BeerStatsFont.headline)
                .foregroundStyle(tint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassPanel(cornerRadius: 18)
        .neonEdge(tint, cornerRadius: 18, intensity: 0.6)
    }
}
