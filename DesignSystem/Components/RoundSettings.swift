//
//  RoundSettings.swift
//  BeerStats
//
//  Die Einstellungen eines Spiels mitten in der Runde: ein Zahnrad oben
//  rechts und ein Blatt mit denselben Schaltern wie im Vorspann.
//
//  Wunsch des Nutzers vom 28. Oktober, nach "Ich hab noch nie": "füg
//  während der Runde noch irgendwo ein Zahnrad ein, das man anklicken kann,
//  und dann die Einstellungen für das Spiel nochmal ändern kann". Vorher
//  ging das nur ueber "Einstellungen ändern" am Ende des Stapels – wer nach
//  zehn Karten merkte, dass die Runde mehr vertraegt, musste neu anfangen.
//
//  Seit dem 29. Oktober in JEDEM Partyspiel ("ja sollst du" auf die Frage,
//  ob das Zahnrad auch in die anderen Spiele soll). Eingehaengt wird es mit
//  `.roundSettings(for:)` – ein Aufruf je Spiel, und `check.py` meldet ein
//  Spiel aus dem Katalog, dem er fehlt. Die Haerte bringt der Baustein
//  selbst mit, denn die hat jedes Spiel; was ein Spiel darueber hinaus
//  anbietet, reicht es als `extra` herein – genau die Schalter aus seinem
//  Vorspann, damit es nur EINE Stelle gibt, an der sie gebaut werden.
//
//  Zwei Regeln, die nicht von selbst gelten:
//  - **Nicht im Vorspann**: Dort ist der Vorspann selbst die Einstellung.
//  - **Nicht, solange eine Uhr laeuft** (Bombe, Sanduhr, Countdown): Das
//    Blatt laege ueber der Uhr, und die Runde liefe ungesehen ab.
//  Beides sagt das Spiel ueber `isAvailable`.
//
//  Macht ein Spiel selbst gleich etwas auf (der Kartenscreen in Ring of
//  Fire), verschwindet das Zahnrad dafuer NICHT – zwei Blaetter zugleich
//  zeigt SwiftUI zwar nicht, aber ein Zahnrad, das bei jedem Zug geht und
//  wiederkommt, war am Geraet die schlechtere Loesung. Das Spiel merkt sich
//  ueber `onOpen`/`onClose`, dass das Blatt offen ist, und zeigt seinen
//  Screen danach.
//

import SwiftUI

/// Das Zahnrad fuer die Leiste oben rechts.
///
/// Dasselbe Zeichen wie die Einstellungen der App im Hauptmenue – nur dass
/// es hier die Einstellungen des Spiels oeffnet, in dem man gerade ist.
struct RoundSettingsButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .foregroundStyle(BeerStatsColor.textSecondary)
                // Die ganze Flaeche nimmt den Tipp an, nicht nur das Zeichen
                // (Lessons Learned Nr. 4 und 12)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Einstellungen des Spiels")
    }
}

/// Das Blatt mit den Einstellungen eines Spiels.
///
/// `note` sagt, wann die Aenderung gilt – das ist je Spiel verschieden
/// ("ab der nächsten Karte", "ab der nächsten Runde") und gehoert dazu:
/// Wer mitten im Spiel umstellt, will wissen, was mit der laufenden Runde
/// passiert.
struct RoundSettingsSheet<Content: View>: View {

    let note: String
    /// Schon fertig gebaut und kein Closure: Der Inhalt landet in einer
    /// Ansicht mit `GeometryReader`, und dessen Closure darf keinen
    /// ViewBuilder-Parameter einfangen (Lessons Learned Nr. 13).
    let content: Content

    @Environment(\.dismiss) private var dismiss

    init(note: String, @ViewBuilder content: () -> Content) {
        self.note = note
        self.content = content()
    }

    var body: some View {
        let inhalt = content

        NavigationStack {
            ZStack {
                AmbientBackdrop()

                FillingScrollView(alignment: .top) {
                    VStack(spacing: 18) {
                        inhalt

                        Text(note)
                            .font(BeerStatsFont.caption)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .font(BeerStatsFont.headline)
                }
            }
        }
        // Gross: Die Schalter sind der ganze Inhalt, und auf halber Hoehe
        // laege die Haerte unter dem Rand
        .presentationDetents([.large])
    }
}

// MARK: - Einhaengen

extension View {

    /// Das Zahnrad eines Partyspiels, das nur die Haerte hat.
    ///
    /// Bewusst ohne Closure-Parameter: Haette diese Fassung auch `onOpen`
    /// oder `onClose`, koennte Swift bei einem Aufruf MIT eigenen Schaltern
    /// die nachgestellte Closure dort einsortieren – sie liefe dann beim
    /// Oeffnen, und die Schalter fehlten im Blatt, ohne dass etwas meckert.
    ///
    /// - Parameters:
    ///   - game: Wessen Haerte im Blatt steht.
    ///   - isAvailable: `false` im Vorspann, solange eine Uhr laeuft und
    ///     solange das Spiel gleich selbst etwas aufmacht.
    func roundSettings(for game: PartyGame, isAvailable: Bool = true) -> some View {
        roundSettings(for: game, isAvailable: isAvailable, note: RoundSettingsNote.nextPenalty) {
            EmptyView()
        }
    }

    /// Dasselbe mit eigenen Schaltern des Spiels ueber der Haerte.
    ///
    /// - Parameters:
    ///   - note: Wann die Aenderung gilt – Pflicht, weil eigene Schalter
    ///     selten genau dann gelten, wann die Haerte gilt.
    ///   - onOpen: Beim Oeffnen – etwa um sich zu merken, was vorher galt.
    ///   - onClose: Beim Schliessen – etwa um neu zu mischen.
    func roundSettings<Extra: View>(
        for game: PartyGame,
        isAvailable: Bool = true,
        note: String,
        onOpen: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {},
        @ViewBuilder extra: () -> Extra
    ) -> some View {
        // Hier ausgewertet und als fertige Ansicht weitergegeben: Der
        // Modifier haelt sie ueber das Blatt hinweg, und ein eingefangener
        // ViewBuilder waere dort nicht erlaubt (Lessons Learned Nr. 13)
        modifier(RoundSettingsModifier(
            game: game,
            isAvailable: isAvailable,
            note: note,
            onOpen: onOpen,
            onClose: onClose,
            extra: extra()
        ))
    }
}

/// Die Saetze, die am haeufigsten unter dem Blatt stehen – an einer Stelle,
/// damit zwanzig Spiele dasselbe Wort fuer dasselbe benutzen.
enum RoundSettingsNote {
    /// Spiele, die nur die Haerte haben. Eine Menge, die gerade schon
    /// dasteht, bleibt stehen – die naechste, die das Spiel ansagt, ist neu.
    static let nextPenalty = "Gilt ab der nächsten Strafe, die das Spiel ansagt."
}

private struct RoundSettingsModifier<Extra: View>: ViewModifier {

    let game: PartyGame
    let isAvailable: Bool
    let note: String
    let onOpen: () -> Void
    let onClose: () -> Void
    let extra: Extra

    @State private var showsSettings = false
    @Environment(\.gameWorld) private var world

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isAvailable {
                        RoundSettingsButton {
                            onOpen()
                            showsSettings = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showsSettings, onDismiss: onClose) {
                RoundSettingsSheet(note: note) {
                    extra
                    DrinkIntensityPicker(game: game)
                }
                // Das Blatt gehoert zum Spiel und steht deshalb in seiner Welt
                .environment(\.gameWorld, world)
            }
    }
}
