//
//  PartyGameFolderView.swift
//  BeerStats
//
//  Die Spiele einer Gruppe.
//
//  Neunzehn Kacheln untereinander waren eine Liste, durch die man scrollt,
//  bis man das Richtige sieht – und bei neunzehn sieht man es nicht mehr.
//  Vier Ordner sind dagegen eine Frage, die man am Tisch ohnehin stellt:
//  Karten in der Mitte, oder reden, oder schnell was zwischendurch?
//
//  Der Ordner selbst ist absichtlich dumm: Er zeigt den Satz der Gruppe
//  und ihre Spiele, sonst nichts. Beides kommt aus `PartyGame.Group`,
//  nicht aus dieser Datei – ein neues Spiel taucht hier also von selbst
//  auf, sobald es im Katalog steht.
//

import SwiftUI

struct PartyGameFolderView: View {

    let group: PartyGame.Group

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: group.tint)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: Layout.spacing) {
                        header

                        ForEach(group.games) { game in
                            PartyGameCard(game: game, height: cardHeight(in: geometry.size.height))
                        }
                    }
                    .padding(Layout.padding)
                    // Ohne eine bestimmte Hoehe hat der freie Platz nichts,
                    // worin er verteilt werden koennte: Zwei Spiele standen
                    // sonst oben gedraengt und darunter lag der halbe
                    // Bildschirm leer.
                    .frame(minHeight: geometry.size.height)
                }
                .verticalScrollOnly()
            }
        }
        .navigationTitle(group.label)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Was die Gruppe ausmacht, in einem halben Satz.
    ///
    /// Der Satz stand im Katalog und wurde nirgends gezeigt. Oben im Ordner
    /// beantwortet er die Frage, die man hier stellt: Passt diese Gruppe
    /// gerade zur Runde?
    private var header: some View {
        VStack(spacing: 6) {
            Text(group.emoji).font(.system(size: 34))

            Text(group.subtitle)
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    /// Wie hoch eine Kachel sein darf, damit die Gruppe den Bildschirm
    /// fuellt.
    ///
    /// Zwei Grenzen, beide aus dem Inhalt begruendet: Unter
    /// `minCardHeight` passt das Emoji-Feld nicht mehr hinein, ueber
    /// `maxCardHeight` wird die Kachel innen leer – dann waere der freie
    /// Platz nur von aussen nach innen gewandert. Was dann noch uebrig
    /// bleibt, verteilt der `minHeight`-Rahmen oben gleichmaessig.
    private func cardHeight(in available: CGFloat) -> CGFloat {
        let anzahl = CGFloat(group.games.count)
        guard anzahl > 0 else { return Layout.minCardHeight }

        let belegt = 2 * Layout.padding + Layout.headerHeight + Layout.spacing * anzahl
        let proKachel = (available - belegt) / anzahl
        return min(max(proKachel, Layout.minCardHeight), Layout.maxCardHeight)
    }

    private enum Layout {
        static let padding: CGFloat = 20
        static let spacing: CGFloat = 12
        /// Emoji-Feld plus Innenabstand – darunter wird die Kachel eng.
        static let minCardHeight: CGFloat = 86
        /// Darueber steht in der Kachel mehr Luft als Inhalt.
        static let maxCardHeight: CGFloat = 156
        /// Grob gerechnet: Emoji plus zwei Zeilen Text.
        static let headerHeight: CGFloat = 76
    }
}

/// Eine Spielkachel samt Weg ins Spiel.
///
/// Stand vorher als zwei Funktionen in `HomeView`. Als eigener Baustein,
/// weil an der Kachel mehr haengt als ein Weg: das Fragezeichen mit der
/// Anleitung und der Vermerk im Abend. Eine zweite Kopie waere eine
/// zweite Stelle, an der das Vermerken fehlt.
struct PartyGameCard: View {

    let game: PartyGame

    /// Wunschhoehe aus dem Ordner. Ohne Angabe so hoch wie ihr Inhalt.
    var height: CGFloat? = nil

    /// Die Anleitung – auf Anforderung, nicht im Weg.
    @State private var showsRules = false

    /// Das Emoji-Feld waechst mit der Kachel.
    ///
    /// Sonst saesse in einer hohen Kachel ein kleines Symbol und daneben
    /// zwei Zeilen Text in viel Luft – genau das Bild, das die hoehere
    /// Kachel vermeiden soll.
    private var emojiSize: CGFloat {
        guard let height else { return 54 }
        return min(max(height * 0.6, 54), 96)
    }

    var body: some View {
        NavigationLink {
            // Vermerkt wird beim Erscheinen, nicht beim Antippen: Wer sich
            // vertippt und sofort zurückgeht, hat nicht gespielt.
            game.destination
                // Tut nichts, wenn kein Abend laeuft – deshalb steht der
                // Aufruf hier ohne Abfrage.
                .onAppear { EveningLog.record(partyGame: game) }
        } label: {
            HStack(spacing: 16) {
                Text(game.emoji)
                    .font(.system(size: emojiSize * 0.58))
                    .frame(width: emojiSize, height: emojiSize)
                    .background(
                        game.tint.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: emojiSize * 0.26, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    // Der Titel in der Schrift seiner Welt – man erkennt
                    // das Spiel am Deckel, bevor man den Titel liest
                    Text(game.title)
                        .font(Font.world(game.world, 17, weight: .bold))
                        .foregroundStyle(BeerStatsColor.textPrimary)
                    Text(game.subtitle)
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .lineLimit(2)

                    // Die zwei Angaben, nach denen am Tisch gefragt wird,
                    // bevor jemand antippt: Wie lange dauert das, und
                    // reichen wir dafuer?
                    Text("\(game.length.label) · \(game.playersLabel)")
                        .font(.scaled(11, weight: .heavy, design: .rounded))
                        .foregroundStyle(game.tint)
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)

                // Das Fragezeichen liegt NEBEN dem Weg ins Spiel, nicht
                // darin: Wer eine Anleitung sucht, will nicht erst das Spiel
                // starten – und wer spielen will, soll nicht danebentippen.
                Button {
                    showsRules = true
                    HapticManager.lightImpact()
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 19))
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())

                Image(systemName: "chevron.right")
                    .foregroundStyle(BeerStatsColor.textSecondary)
            }
            .padding(16)
            .frame(minHeight: height ?? 0)
            .background { lid }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .sheet(isPresented: $showsRules) {
            PartyGameRulesView(game: game)
        }
    }

    /// Die Kachel als Schachteldeckel: darauf ein Standbild vom Grund der
    /// Welt, still – eine Liste, in der ueberall etwas laeuft, liest sich
    /// nicht. Unten dunkler, damit die Schrift steht.
    private var lid: some View {
        WorldGround(world: game.world, plain: false, moves: false, fillsScreen: false)
            .equatable()
            .overlay(
                LinearGradient(colors: [Color.black.opacity(0.25), Color.black.opacity(0.7)],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )
            // Die Kante des Deckels
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1.5)
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
            }
            .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
    }
}

/// Wie ein Partyspiel gespielt wird.
///
/// Bis Oktober 2026 hatte nur Beerpong einen Regel-Screen. Die neunzehn
/// Partyspiele erklaerten sich im Spiel selbst – wer neu am Tisch stand,
/// musste fragen, und wer die Regeln kannte, musste sie neunzehnmal
/// erzaehlen.
struct PartyGameRulesView: View {

    let game: PartyGame

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdrop(glow: game.tint)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(game.emoji).font(.system(size: 48))

                        Text(game.title)
                            .font(BeerStatsFont.title)
                            .foregroundStyle(BeerStatsColor.textPrimary)

                        Text(game.subtitle)
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(game.howToPlay)
                            .font(BeerStatsFont.body)
                            .foregroundStyle(BeerStatsColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassPanel(cornerRadius: 16)

                        Text("Die Trinkmengen richten sich nach der eingestellten Härte – nachzulesen und zu ändern in den Einstellungen.")
                            .font(.scaled(11, weight: .medium, design: .rounded))
                            .foregroundStyle(BeerStatsColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(22)
                }
                .verticalScrollOnly()
            }
            .navigationTitle("Wie geht das?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(game.tint)
                }
            }
        }
        // Nur gross: Die Anleitung ist der ganze Inhalt dieses Blatts – auf
        // halber Hoehe haette man sie erst aufziehen muessen, um sie zu
        // lesen.
        .presentationDetents([.large])
    }
}
