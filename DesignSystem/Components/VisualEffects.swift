//
//  VisualEffects.swift
//  BeerStats
//
//  Was von den Bausteinen fuer Bewegung geblieben ist: gerechneter Zufall,
//  Konfetti und Blitz. Die Szenen selbst stehen seit dem 27. Oktober in
//  `DrawnScenes.swift`.
//
//  Hier lagen vorher sechs Bausteine – Teilchen, Druckwelle, Strahlen,
//  Einschlag, Konfetti, Blitz –, und eine Szene war eine Schichtung daraus.
//  Das war die Antwort auf die EINE Animation davor und hat ihr Problem nur
//  verschoben: Wird jede Szene aus denselben vier Bausteinen gestapelt,
//  bewegt sich jede gleich, und was sich unterscheidet, ist das Emoji. Der
//  Nutzer am Tisch: "Die sehen alle gleich aus, nur mit anderen Emojis."
//
//  Teilchen, Druckwelle, Strahlen und Einschlag sind deshalb ENTFERNT und
//  nicht bloss unbenutzt. Ein Baustein, der nur Gleichheit erzeugen kann,
//  wird beim naechsten Mal wieder genommen, weil er so bequem daliegt.
//  Geblieben ist, was eine eigene Bewegung hat: Konfetti faellt, der Blitz
//  haengt an einem Ereignis.
//
//  Die Flammenwand vom 27. Oktober ist ebenfalls entfernt: Seit dem
//  28. Oktober brennt der Riss von Ring of Fire an der Luecke selbst
//  (`RingEmbers.swift`), und ein unbenutztes Feuer laege nur bequem herum.
//
//  Vier Regeln gelten fuer diese Bausteine und fuer die Szenen in
//  `DrawnScenes.swift`, und jede hat einen Grund:
//
//  1. **Zierde, kein Inhalt.** Alles liegt HINTER dem Text, nimmt keine
//     Tipps an (`allowsHitTesting(false)`) und ist fuer VoiceOver
//     unsichtbar. Was zu tun ist, steht geschrieben da.
//  2. **Gerechneter Zufall, nicht gewuerfelter.** `EffectNoise` ist eine
//     Funktion des Index. Mit `Double.random` springt alles bei jedem
//     Neuzeichnen an eine andere Stelle – und SwiftUI zeichnet oefter neu,
//     als man denkt.
//  3. **Nichts laeuft weiter, wenn der Screen weg ist.** Konfetti und Blitz
//     tragen ihre Bewegung in den Modifiern, ausgeloest von einem Zustand,
//     der einmal umkippt. Szenen zeichnen auf einer Zeitleiste, die mit
//     der Ansicht verschwindet. Kein Timer, keine Task-Schleife.
//  4. **Bewegung reduzieren wird beachtet.** Wer die Systemeinstellung an
//     hat, bekommt ein stilles Bild – nicht nichts, sonst fehlt die Farbe,
//     die zum Moment gehoert.
//
//  **Zur Lautstaerke** (26. Oktober, auf Wunsch des Nutzers): Am Tisch
//  liegt das Handy in der Mitte und wird aus anderthalb Metern angeschaut.
//  Was dort "nicht stoert", sieht niemand. Deshalb "faellt auf" – mit
//  derselben Grenze wie vorher, nur weiter hinten: **Der Text muss lesbar
//  bleiben.** Kraeftig darf sein, was am Rand oder unten liegt; was durch
//  die Mitte geht, bleibt blass.
//

import SwiftUI

// MARK: - Gerechneter Zufall

enum EffectNoise {

    /// Immer derselbe Wert zwischen -1 und 1 fuer denselben Index.
    ///
    /// Gerechnet statt gewuerfelt: sonst springen die Teilchen bei jedem
    /// Neuzeichnen woanders hin.
    static func scatter(_ index: Int, seed: Int = 0) -> CGFloat {
        let wert = sin(Double(index * 127 + seed) * 12.9898) * 43758.5453
        return CGFloat(wert - wert.rounded(.down)) * 2 - 1
    }

    /// Dasselbe, aber zwischen 0 und 1.
    static func unit(_ index: Int, seed: Int = 0) -> CGFloat {
        (scatter(index, seed: seed) + 1) / 2
    }
}

// MARK: - Konfetti

/// Fallende Streifen in mehreren Farben – fuer die Stellen, an denen jemand
/// gewonnen hat.
///
/// Bewusst Streifen und keine Emoji: Ein Emoji traegt Bedeutung, und ein
/// Sieg hat schon genug davon. Streifen sind reine Freude.
struct EffectConfetti: View {

    var count: Int = 32
    var duration: Double = 2.8
    var colors: [Color] = [
        BeerStatsColor.accent,
        BeerStatsColor.accentSecondary,
        BeerStatsColor.warning,
        BeerStatsColor.success,
        BeerStatsColor.error
    ]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var running = false

    private static let maximum = 52

    private var anzahl: Int { min(max(count, 1), Self.maximum) }

    var body: some View {
        GeometryReader { geometry in
            let breite = geometry.size.width
            let hoehe = geometry.size.height

            ZStack(alignment: .top) {
                ForEach(0..<anzahl, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(colors[index % max(colors.count, 1)])
                        .frame(width: 9, height: 20 + EffectNoise.unit(index, seed: 5) * 16)
                        .rotationEffect(.degrees(running ? 540 + Double(EffectNoise.scatter(index, seed: 9)) * 360 : 0))
                        .offset(
                            x: EffectNoise.scatter(index, seed: 2) * breite * 0.48,
                            y: running ? hoehe * 1.1 : -40
                        )
                        .opacity(reduceMotion ? 0.8 : (running ? 0.1 : 1))
                        .animation(
                            reduceMotion
                                ? nil
                                : .easeIn(duration: duration + Double(EffectNoise.unit(index, seed: 4)) * 1.4)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(index) * 0.06),
                            value: running
                        )
                }
            }
            .frame(width: breite, height: hoehe, alignment: .top)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onAppear { running = true }
    }
}

// MARK: - Blitz

/// Ein einzelner heller Schlag ueber den ganzen Screen.
///
/// Haengt an einem Wert von draussen und nicht an `onAppear`: Ein Blitz
/// gehoert zu einem Ereignis (ein Riss, ein Treffer), nicht zum Erscheinen
/// einer Ansicht. Nach Lessons Learned Nr. 11 merkt er sich DEN WERT und
/// nicht ein Ja/Nein – sonst blitzt er genau einmal pro Screen.
struct EffectFlash<Trigger: Equatable>: View {

    let trigger: Trigger
    var tint: Color = BeerStatsColor.warning
    /// Wie hell der Blitz aufleuchtet. Kraeftig, wenn er ein Ereignis
    /// meldet; blasser, wenn er nur einen Schnitt markiert.
    var peak: Double = 0.8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Trigger?
    @State private var bright = false

    var body: some View {
        Rectangle()
            .fill(tint)
            .opacity(bright ? peak : 0)
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .onChange(of: trigger) { neu in
                guard !reduceMotion, neu != shown else { return }
                shown = neu
                bright = true
                // Erst den hellen Zustand zeigen, dann ausblenden – im selben
                // Durchlauf gesetzt, saehe SwiftUI nur den Endwert, und der
                // Blitz kaeme nie an.
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.65)) { bright = false }
                }
            }
    }
}
