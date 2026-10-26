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
    /// Der Abend als Bild – einmal gerendert, wenn der Rueckblick steht.
    @State private var eveningImageURL: URL?
    /// Der Eintrag, fuer den gerade ein Sieger eingetragen wird.
    @State private var winnerEntry: EveningEntry?

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.accentSecondary)

            FillingScrollView(alignment: .top) {
                VStack(spacing: 20) {
                    if let summary {
                        summaryView(summary)
                    } else if let evening, evening.isRunning {
                        runningView(evening)
                    } else {
                        setupView
                        earlierEvenings
                    }
                }
                .padding(22)
            }
        }
        .navigationTitle("Abend")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { evening = EveningLog.current }
        .sheet(item: $winnerEntry) { eintrag in
            WinnerPickerView(
                entry: eintrag,
                participants: evening?.participants ?? []
            ) { ids in
                EveningLog.setWinner(ids, forEntry: eintrag.id)
                // Aus dem Speicher nachladen: Die Ansicht haelt eine Kopie
                // des Abends, und die weiss von der Aenderung nichts.
                evening = EveningLog.current
            }
        }
    }

    // MARK: - Frueher

    /// Die letzten Abende zum Nachlesen.
    ///
    /// Der Rueckblick war bis Oktober 2026 einmalig – "Fertig" antippen, und
    /// er war weg. Dabei ist er das Einzige, was von einem Abend uebrig
    /// bleibt: Die Partyspiele schreiben keine Statistik, und die
    /// Trinkbilanz steht nirgendwo sonst.
    @ViewBuilder
    private var earlierEvenings: some View {
        let frueher = EveningLog.archived

        if !frueher.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("FRÜHERE ABENDE")
                    .font(.scaled(11, weight: .heavy, design: .rounded))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                ForEach(Array(frueher.enumerated()), id: \.offset) { _, abend in
                    Button {
                        summary = abend
                    } label: {
                        HStack(spacing: 12) {
                            Text("🌅").font(.system(size: 22))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(dateText(abend))
                                    .font(BeerStatsFont.headline)
                                    .foregroundStyle(BeerStatsColor.textPrimary)
                                Text("\(abend.readableDuration) · \(abend.entries.count) \(abend.entries.count == 1 ? "Spiel" : "Spiele")")
                                    .font(BeerStatsFont.caption)
                                    .foregroundStyle(BeerStatsColor.textSecondary)
                            }

                            Spacer(minLength: 0)

                            if let sieger = abend.mostWins {
                                Text("🏆 \(sieger.name)")
                                    .font(BeerStatsFont.caption)
                                    .foregroundStyle(BeerStatsColor.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(14)
                        .glassPanel(cornerRadius: 14)
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dateText(_ abend: Evening) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE, d. MMMM"
        return formatter.string(from: abend.startedAt)
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

            // Ueber der Bilanz, nicht darunter: Wer hierherkommt, weil er
            // sich vertippt hat, soll nicht erst an acht Namen vorbei.
            LastBookingRow(evening: abend) { evening = EveningLog.current }

            VStack(alignment: .leading, spacing: 10) {
                Text(PenaltyStyle.current.tallyTitle)
                    .font(.scaled(11, weight: .heavy, design: .rounded))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                ForEach(abend.participants) { teilnehmer in
                    tallyRow(teilnehmer)
                }
            }

            if !abend.entries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GESPIELT")
                        .font(.scaled(11, weight: .heavy, design: .rounded))
                        .kerning(1.8)
                        .foregroundStyle(BeerStatsColor.textSecondary)

                    ForEach(abend.entries.reversed()) { eintrag in
                        gespieltZeile(eintrag)
                    }

                    Text("Antippen, um den Sieger einzutragen – die meisten Spiele rechnen nur aus, wer verloren hat.")
                        .font(.scaled(10, weight: .medium, design: .rounded))
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
            }

            PrimaryButton(title: "Abend beenden", systemImage: "flag.checkered") {
                summary = EveningLog.finish()
                evening = nil
                HapticManager.success()
                SoundManager.play(.victory)
            }

            QuietButton(title: "Abend verwerfen") {
                EveningLog.discard()
                evening = nil
                chosen = []
            }
        }
    }

    /// Eine Zeile der Bilanz: Name, Stand, und drei Knoepfe.
    /// Eine Zeile unter "Gespielt" – antippbar, um den Sieger einzutragen.
    private func gespieltZeile(_ eintrag: EveningEntry) -> some View {
        Button {
            winnerEntry = eintrag
            HapticManager.lightImpact()
        } label: {
            HStack(spacing: 10) {
                Text(eintrag.emoji)
                Text(eintrag.title)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textPrimary)

                Spacer(minLength: 0)

                if let winner = eintrag.winner {
                    Text("🏆 \(winner)")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.success)
                        .lineLimit(1)
                } else {
                    Text("Sieger?")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .glassPanel(cornerRadius: 12)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

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
                .font(.scaled(15, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .glassPanel(cornerRadius: 12)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Der Abend als Bild

    /// Einmal gerendert, wenn der Rueckblick steht.
    private func renderEveningImage(_ abend: Evening) {
        guard eveningImageURL == nil else { return }
        Task { @MainActor in
            eveningImageURL = ShareImage.file(named: "beerstats-abend") {
                shareCard(for: abend)
            }
        }
    }

    private func shareCard(for abend: Evening) -> ShareCard {
        let pokal = abend.trophyWinner

        var rows: [ShareCard.Row] = [
            .init(label: abend.entries.count == 1 ? "Spiel" : "Spiele", value: "\(abend.entries.count)"),
            .init(label: "Gespielt", value: abend.readableDuration)
        ]
        // Beide Kronen aufs Bild – das sind die zwei Titel, um die am Tisch
        // gespielt wurde, und sie gehoeren verschiedenen Leuten.
        if let durstig = abend.mostDrinks {
            rows.append(.init(label: "Durstigste Person", value: "\(durstig.emoji) \(durstig.name)"))
        }
        // Was den Abend bestimmt hat. Die erzaehlendste Zeile des Plakats:
        // "Vier Runden Ring of Fire" ist die Erinnerung, die Dauer nicht.
        if let oft = abend.mostPlayed {
            rows.append(.init(label: "Meistgespielt", value: "\(oft.emoji) \(oft.title) (\(oft.count)×)"))
        }
        // Eine Auszeichnung, nicht alle: Das Plakat soll ein Plakat
        // bleiben und keine Liste. Die erste ist die seltenste, weil
        // `forEvening` von selten nach haeufig baut.
        if let besonderes = EveningAchievements.forEvening(abend).first {
            rows.append(.init(label: besonderes.title, value: "\(besonderes.emoji) \(besonderes.detail)"))
        }

        let datum = Date.FormatStyle.dateTime.day().month(.wide).year()

        return ShareCard(
            title: "UNSER ABEND",
            // Die Ueberschrift ist der Sieger des Abends, nicht das Datum:
            // Das Datum steht unten und interessiert niemanden als Erstes.
            headline: pokal.map { "\($0.participant.name) gewinnt den Abend" }
                ?? abend.mostWins.map { "\($0.name) hat den Abend gewonnen" }
                ?? "Unser Abend",
            subline: pokal.map { "\($0.wins)× gewonnen · \($0.points) Punkte" }
                ?? abend.mostWins.map { "\($0.count)× gewonnen" },
            rows: rows,
            footnote: abend.startedAt.formatted(datum),
            tint: BeerStatsColor.accentSecondary
        )
    }

    private func standText(_ teilnehmer: EveningParticipant) -> String {
        teilnehmer.tallyText(separator: " · ", whenEmpty: "noch nichts")
    }

    // MARK: - Der Pokal

    /// Die Siegerwertung – getrennt von der Trinkbilanz.
    ///
    /// Beides in einer Zahl zu verrechnen ("Punkte minus Schluecke") waere
    /// naheliegend und falsch: Dann lohnt es sich, wenig zu spielen, und
    /// ein Trinkspiel, das Nichttrinken belohnt, ist kaputt. Am Tisch sind
    /// das ohnehin zwei Titel, und beide will jemand haben.
    ///
    /// Die Tabelle bleibt weg, solange niemand etwas gewonnen hat – eine
    /// Liste mit lauter Nullen sagt nur, dass die App etwas zaehlt, was
    /// nicht stattgefunden hat.
    @ViewBuilder
    private func pokalTabelle(_ abend: Evening) -> some View {
        let wertung = abend.trophyBoard

        if wertung.contains(where: { $0.points > 0 }) {
            VStack(alignment: .leading, spacing: 8) {
                Text("POKAL")
                    .font(.scaled(11, weight: .heavy, design: .rounded))
                    .kerning(1.8)
                    .foregroundStyle(BeerStatsColor.textSecondary)

                ForEach(Array(wertung.enumerated()), id: \.element.id) { platz, rang in
                    HStack(spacing: 10) {
                        Text("\(platz + 1).")
                            .font(.scaled(13, weight: .heavy, design: .rounded))
                            .foregroundStyle(platz == 0 ? BeerStatsColor.warning : BeerStatsColor.textSecondary)
                            .monospacedDigit()
                            .frame(width: 24, alignment: .leading)

                        Text(rang.participant.emoji)
                        Text(rang.participant.name)
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Text("\(rang.wins)× · \(rang.points) P")
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(rang.points > 0 ? BeerStatsColor.warning : BeerStatsColor.textSecondary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .glassPanel(cornerRadius: 12)
                }

                Text("Punkte je Sieg nach Spiellänge: kurz 1, mittel 2, lang 3.")
                    .font(.scaled(10, weight: .medium, design: .rounded))
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
        }
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

            if let pokal = abend.trophyWinner {
                highlight(
                    "🏆",
                    "Sieger des Abends",
                    "\(pokal.participant.name) — \(pokal.points) \(pokal.points == 1 ? "Punkt" : "Punkte")",
                    BeerStatsColor.warning
                )
                // Nur beim Pokal und nur hier: Der Rueckblick ist eine
                // Liste, und eine Liste, in der an mehreren Stellen etwas
                // fliegt, liest sich nicht mehr.
                .background(
                    EffectConfetti(count: 14, duration: 3.4)
                        .frame(height: 140)
                )
            } else if let sieger = abend.mostWins {
                // Frueher Abende kennen nur den Namen des Siegers, keine
                // Punkte. Sie sollen trotzdem etwas zeigen.
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

            pokalTabelle(abend)

            VStack(alignment: .leading, spacing: 8) {
                Text("ENDSTAND")
                    .font(.scaled(11, weight: .heavy, design: .rounded))
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

            // Zwei Wege nach draussen, und beide haben ihren Grund: Text
            // laesst sich vorlesen, suchen und in zehn Jahren noch oeffnen –
            // ein Bild landet in der Gruppe. Der Text bleibt deshalb, das
            // Bild kommt dazu.
            ShareLink(item: abend.shareText) {
                HStack(spacing: 10) {
                    Image(systemName: "text.alignleft")
                    Text("Als Text teilen")
                        .font(BeerStatsFont.headline)
                }
                .foregroundStyle(BeerStatsColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .glassPanel(cornerRadius: 15)
                .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }

            if let url = eveningImageURL {
                ShareLink(item: url) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Als Bild teilen")
                            .font(BeerStatsFont.headline)
                    }
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .glassPanel(cornerRadius: 15)
                    .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
            }

            PrimaryButton(title: "Fertig", systemImage: "checkmark") {
                summary = nil
                chosen = []
                // Sonst verschickt der naechste Abend das Bild von diesem.
                eveningImageURL = nil
            }

            Text("Bleibt unter „Frühere Abende“ gespeichert.")
                .font(.scaled(10, weight: .medium, design: .rounded))
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
        .onAppear { renderEveningImage(abend) }
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
                    .font(.scaled(11, weight: .heavy, design: .rounded))
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
                .font(.scaled(10, weight: .heavy, design: .rounded))
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
