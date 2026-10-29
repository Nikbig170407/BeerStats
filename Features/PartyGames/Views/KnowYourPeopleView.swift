//
//  KnowYourPeopleView.swift
//  BeerStats
//
//  Kennst du deine Leute? – Fragen aus euren eigenen Beerpong-Zahlen.
//
//  Das Spiel schreibt nichts mit. Es liest die Kennzahlen, die beim
//  Beerpong ohnehin entstehen, und macht daraus eine Frage mit zwei
//  Antworten. Deshalb steht es auch nicht in den Statistiken: Eine Runde
//  hier hat keine Trefferquote.
//
//  Gefragt wird reihum. Wer dran ist, entscheidet fuer die Runde – und
//  trinkt, wenn er danebenliegt. Das Handy wandert dabei nicht: Die Frage
//  darf jeder sehen, es gibt nichts zu verbergen.
//

import SwiftUI

struct KnowYourPeopleView: View {

    @Environment(\.tablePlayers) private var tablePlayers

    @State private var questions: [PeopleQuestion] = []
    @State private var index = 0
    @State private var answeredId: String?
    @State private var askedCount = 0

    private let penalty = DrinkAmount.sips(2)

    @Environment(\.gameWorld) private var world

    private var current: PeopleQuestion? {
        questions.indices.contains(index) ? questions[index] : nil
    }

    /// Wer gerade antworten muss – reihum durch die Leute am Tisch.
    private var askedPerson: PlayerProfile? {
        guard !tablePlayers.isEmpty else { return nil }
        return tablePlayers[askedCount % tablePlayers.count]
    }

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: BeerStatsColor.accentSecondary)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 18) {
                        if let current {
                            questionCard(current)
                        } else {
                            emptyState
                        }
                    }
                    .padding(22)
                    .frame(minHeight: geometry.size.height)
                }
                .verticalScrollOnly()
            }
        }
        .navigationTitle("Kennst du deine Leute?")
        .navigationBarTitleDisplayMode(.inline)
        .roundSettings(for: .knowYourPeople)
        .onAppear(perform: buildQuestionsIfNeeded)
    }

    // MARK: - Die Frage

    private func questionCard(_ frage: PeopleQuestion) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            if let askedPerson {
                Text("\(askedPerson.emoji) \(askedPerson.name) ist dran")
                    .font(BeerStatsFont.statLabel)
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }

            Text(frage.kind.question)
                .font(Font.world(world, 30, weight: .heavy))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Aus euren Beerpong-Zahlen")
                .font(Font.world(world, 15, weight: .medium))
                .foregroundStyle(BeerStatsColor.textSecondary)

            // Zwei Sammelkarten, die von beiden Seiten hereinkommen
            HStack(spacing: 12) {
                answerButton(frage, profile: frage.left, isLeft: true)
                answerButton(frage, profile: frage.right, isLeft: false)
            }

            if answeredId != nil {
                revealPanel(frage)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .glassPanel(cornerRadius: 22)
        .neonEdge(BeerStatsColor.accentSecondary, cornerRadius: 22, intensity: 0.6)
    }

    private func answerButton(_ frage: PeopleQuestion, profile: PlayerProfile, isLeft: Bool) -> some View {
        let isAnswered = answeredId != nil
        let isCorrect = profile.id == frage.correctId
        let isChosen = profile.id == answeredId
        let wert = isLeft ? frage.leftValue : frage.rightValue
        let punkte = isLeft ? frage.leftScore : frage.rightScore
        let bester = max(frage.leftScore, frage.rightScore, 0.0001)
        let verliert = isAnswered && !isCorrect

        return Button {
            guard !isAnswered, let id = profile.id else { return }
            answeredId = id
            if isCorrect {
                HapticManager.success()
                SoundManager.play(.victory)
            } else {
                HapticManager.error()
                SoundManager.play(.bombe)
                // Gebucht wird ueber die Profil-ID, nicht ueber die
                // Position: Dieses Spiel kennt seine Leute als Profile, und
                // die Reihenfolge der Aufstellung muss nicht die des Abends
                // sein. Laeuft kein Abend, tut der Aufruf nichts.
                if let dran = askedPerson?.id {
                    EveningLog.record(penalty, forProfileId: dran)
                }
            }
        } label: {
            // Bis geraten ist, steht auf beiden Karten ein Fragezeichen.
            // Danach zeigen BEIDE Seiten Farbe: die richtige gruen, die
            // falsch gewaehlte rot – nur die gewaehlte zu markieren hiesse,
            // die Antwort noch einmal suchen zu muessen.
            QuartetCard(
                name: profile.name,
                color: profile.color.color,
                statLabel: frage.kind.statLabel,
                value: isAnswered ? wert : nil,
                share: punkte / bester,
                isBetter: isAnswered && isCorrect,
                shineOffset: isLeft ? 0 : 0.5
            ) {
                ProfileAvatarView(profile: profile, size: 48)
            }
            .overlay {
                if isAnswered, isCorrect || isChosen {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isCorrect ? BeerStatsColor.success : BeerStatsColor.error, lineWidth: 3)
                }
            }
            // Wer verliert, kippt weg
            .rotationEffect(.degrees(verliert ? (isLeft ? -7 : 7) : 0), anchor: .bottom)
            .opacity(verliert ? 0.6 : 1)
            .animation(.easeOut(duration: 0.4), value: isAnswered)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isAnswered)
        .id(frage.id)
        .transition(.move(edge: isLeft ? .leading : .trailing).combined(with: .opacity))
        .accessibilityLabel(profile.name)
        .accessibilityValue(isAnswered ? "\(frage.kind.statLabel) \(wert)" : "")
    }

    private func revealPanel(_ frage: PeopleQuestion) -> some View {
        let richtig = answeredId == frage.correctId

        return VStack(spacing: 10) {
            Text(frage.revealText)
                .font(Font.world(world, 24, weight: .heavy))
                .foregroundStyle(BeerStatsColor.textPrimary)
                .monospacedDigit()

            Text(richtig
                 ? "Richtig."
                 : "Daneben. \(askedPerson?.name ?? "Wer geraten hat") trinkt \(penalty.text).")
                .font(BeerStatsFont.caption)
                .foregroundStyle(richtig ? BeerStatsColor.success : BeerStatsColor.error)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryButton(title: "Nächste Frage", systemImage: "arrow.right") {
                next()
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Zu wenig Daten

    /// Ohne Zahlen kein Spiel – und das ehrlich gesagt, statt mit erfundenen
    /// Fragen zu fuellen.
    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("📊").font(.system(size: 54))

            Text(questions.isEmpty && !tablePlayers.isEmpty
                 ? "Noch zu wenig gespielt"
                 : "Dafür braucht es Mitspieler")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
                .multilineTextAlignment(.center)

            Text(tablePlayers.count < 2
                 ? "Stell im Hauptmenü über das Personen-Symbol ein, wer heute am Tisch ist – mindestens zwei Leute."
                 : "Die Fragen kommen aus euren Beerpong-Zahlen. Solange zwei Leute dort fast gleichauf liegen, gäbe es keine richtige Antwort – also fragt die App lieber nicht. Spielt ein paar Partien, dann steht hier was.")
                .font(BeerStatsFont.body)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassPanel(cornerRadius: 22)
    }

    // MARK: - Ablauf

    private func buildQuestionsIfNeeded() {
        guard questions.isEmpty else { return }
        questions = KnowYourPeople.questions(for: tablePlayers)
    }

    private func next() {
        withAnimation(AppAnimation.standard) {
            answeredId = nil
            askedCount += 1

            if index + 1 < questions.count {
                index += 1
            } else {
                // Von vorn, neu gemischt: Lieber eine Frage zweimal am Abend
                // als ein Spiel, das nach acht Runden zu Ende ist.
                questions = KnowYourPeople.questions(for: tablePlayers)
                index = 0
            }
        }
    }
}
