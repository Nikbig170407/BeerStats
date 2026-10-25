//
//  RingCardFlourish.swift
//  BeerStats
//
//  Die Szene hinter der gezogenen Karte – für jeden Rang eine andere.
//
//  Dreizehn Karten sahen beim Aufdecken gleich aus: dieselbe Karte, derselbe
//  Aufbau, nur ein anderer Text. Am Tisch heisst das, dass die Runde den
//  Text lesen muss, um zu wissen, was los ist. Eine Bewegung, die zur Karte
//  gehoert, sagt es schon vorher – und sie sagt es ueber den Tisch hinweg,
//  wo niemand mitliest.
//
//  Hier stand bis zum 25. Oktober EINE Bewegung mit dreizehn Einstellungen:
//  Zeichen, Anzahl, Richtung. Das war als Sparmassnahme richtig gedacht und
//  als Ergebnis falsch – dreizehn Mal dieselbe Flugbahn sieht dreizehn Mal
//  gleich aus, egal wie verschieden die Emoji sind. Am Tisch unterscheidet
//  man sie dann nicht, und damit ist der ganze Sinn weg.
//
//  Jetzt ist jeder Rang eine SZENE aus mehreren Schichten (`VisualEffects`):
//  ein Einschlag, der eine Druckwelle wirft, dahinter drehende Strahlen und
//  steigende Funken. Der gute Teil des alten Ansatzes bleibt – eine Szene
//  ist eine Kombination von Bausteinen und kein neuer Entwurf, eine
//  vierzehnte Karte braucht also weiter nur ein paar Zeilen.
//
//  Die Richtung ist dabei nicht Geschmack: Was auf dich zukommt, faellt
//  (Dame, Drei); was von dir ausgeht, steigt (Daumen, Regel); was alle
//  gleichzeitig trifft, platzt auseinander (Kategorie); was bleibt, kreist
//  (Trink-Duo, Reim). Wer die Karte kennt, erkennt sie an der Bewegung,
//  bevor er den Titel liest.
//
//  Deckkraft ist hier kein Detail, sondern die Bedingung: Die Szene liegt
//  HINTER dem Text, und der muss lesbar bleiben. Strahlen laufen deshalb um
//  0,2, Einschlaege um 0,3 – was man sucht, findet man, was man liest,
//  stoert es nicht.
//

import SwiftUI

struct RingCardFlourish: View {

    let rank: Int

    var body: some View {
        scene(for: rank)
            // Die ganze Szene haengt an der Karte: Ein neuer Rang baut sie
            // neu auf, statt die alte Bewegung weiterlaufen zu lassen.
            // Steht HIER und nicht an der Aufrufstelle – die eine Stelle,
            // die es vergessen koennte, ist dann keine (Lessons Learned
            // Nr. 11).
            .id(rank)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    // MARK: - Die dreizehn Szenen

    /// Bewusst `AnyView` und kein `@ViewBuilder` – dieselbe Entscheidung wie
    /// bei `PartyGame.destination`. Dreizehn Faelle mit je mehreren Schichten
    /// bauen als `@ViewBuilder` einen Typ aus verschachtelten
    /// Entweder-Oder-Huellen, den der Compiler erst in Minuten prueft – und
    /// manchmal gar nicht. Die Kosten einer `AnyView` sind hier
    /// bedeutungslos: Es haengt genau eine davon im Baum, und sie wechselt
    /// nur, wenn eine neue Karte gezogen wird.
    private func scene(for rank: Int) -> AnyView {
        switch rank {

        case 2:
            // Zeigt auf jemanden. Der Finger kommt von der Seite herein und
            // bleibt, dahinter ziehen weitere quer durch.
            return AnyView(ZStack {
                EffectParticles(
                    symbol: "👉", count: 6, flight: .sweep,
                    tint: BeerStatsColor.accent, duration: 1.9, opacity: 0.55
                )
                EffectSlam(symbol: "👉", from: .leading, tint: BeerStatsColor.accent, size: 160, opacity: 0.28)
            })

        case 3:
            // Kommt auf DICH herunter: Einschlag von oben, Druckwelle, und
            // es regnet weiter nach.
            return AnyView(ZStack {
                EffectShockwave(tint: BeerStatsColor.error, rings: 2, duration: 1.5, delay: 0.25)
                EffectParticles(
                    symbol: "⬇️", count: 7, flight: .fall,
                    tint: BeerStatsColor.error, duration: 1.7, opacity: 0.5
                )
                EffectSlam(symbol: "🍺", from: .top, tint: BeerStatsColor.error, size: 150, opacity: 0.3)
            })

        case 4:
            // Der Wasserfall. Zwei Tropfenschichten in verschiedenem Tempo –
            // eine allein sieht aus wie Regen, zwei wie Stroemung.
            return AnyView(ZStack {
                EffectParticles(
                    symbol: "💧", count: 12, flight: .fall,
                    tint: BeerStatsColor.accentSecondary, duration: 1.4,
                    stagger: 0.08, sizeRange: 18...34, opacity: 0.6
                )
                EffectParticles(
                    symbol: "💧", count: 8, flight: .fall,
                    tint: BeerStatsColor.accent, duration: 2.3,
                    stagger: 0.14, sizeRange: 30...52, opacity: 0.35, seed: 31
                )
                EffectParticles(
                    symbol: "🫧", count: 6, flight: .rise,
                    tint: BeerStatsColor.accentSecondary, duration: 2.6,
                    sizeRange: 16...28, opacity: 0.4, seed: 57
                )
            })

        case 5:
            // Die Jungs: Arme gehen hoch, der Bizeps schlaegt von unten
            // herein.
            return AnyView(ZStack {
                EffectRays(tint: BeerStatsColor.accentSecondary, spokes: 10, opacity: 0.16)
                EffectParticles(
                    symbol: "🙋‍♂️", count: 7, flight: .rise,
                    tint: BeerStatsColor.accentSecondary, duration: 2.0, opacity: 0.55
                )
                EffectSlam(symbol: "💪", from: .bottom, tint: BeerStatsColor.accentSecondary, size: 150, opacity: 0.28)
            })

        case 6:
            // Die Maedels: gleiche Bauart, andere Farbe und anderes Zeichen.
            // Die beiden Karten gehoeren zusammen und sollen das aussehen.
            return AnyView(ZStack {
                EffectRays(tint: BeerStatsColor.error, spokes: 10, opacity: 0.16)
                EffectParticles(
                    symbol: "🙋‍♀️", count: 7, flight: .rise,
                    tint: BeerStatsColor.error, duration: 2.0, opacity: 0.55
                )
                EffectSlam(symbol: "💃", from: .bottom, tint: BeerStatsColor.error, size: 150, opacity: 0.28)
            })

        case 7:
            // Alle Haende sofort hoch. Schnell und viele – hier zaehlt
            // Hektik, nicht Pracht.
            return AnyView(ZStack {
                EffectParticles(
                    symbol: "☝️", count: 14, flight: .rise,
                    tint: BeerStatsColor.warning, duration: 1.1,
                    stagger: 0.06, sizeRange: 22...40, opacity: 0.6
                )
                EffectShockwave(tint: BeerStatsColor.warning, rings: 3, duration: 1.2)
            })

        case 8:
            // Das Trink-Duo: Zwei Glaeser kreisen umeinander, der
            // Handschlag steht in der Mitte.
            return AnyView(ZStack {
                EffectParticles(
                    symbol: "🍻", count: 8, flight: .orbit,
                    tint: BeerStatsColor.success, duration: 3.2, stagger: 0.2, opacity: 0.45
                )
                EffectShockwave(tint: BeerStatsColor.success, rings: 2, duration: 2.0, lineWidth: 2, delay: 0.3)
                EffectSlam(symbol: "🤝", from: .bottom, tint: BeerStatsColor.success, size: 150, opacity: 0.3)
            })

        case 9:
            // Reimen: Noten kreisen, das Mikrofon kommt von unten.
            return AnyView(ZStack {
                EffectRays(tint: BeerStatsColor.accentSecondary, spokes: 8, duration: 20, opacity: 0.13)
                EffectParticles(
                    symbol: "🎵", count: 9, flight: .orbit,
                    tint: BeerStatsColor.accentSecondary, duration: 3.6, stagger: 0.22, opacity: 0.5
                )
                EffectSlam(symbol: "🎤", from: .bottom, tint: BeerStatsColor.accentSecondary, size: 140, opacity: 0.28)
            })

        case 10:
            // Die Regel: Das Siegel klatscht aufs Papier – deshalb der
            // Einschlag zuerst und die Druckwelle mit Verzoegerung danach.
            return AnyView(ZStack {
                EffectParticles(
                    symbol: "📜", count: 6, flight: .rise,
                    tint: BeerStatsColor.warning, duration: 2.6, opacity: 0.4
                )
                EffectShockwave(tint: BeerStatsColor.warning, rings: 2, duration: 1.4, lineWidth: 4, delay: 0.28)
                EffectSlam(symbol: "🖋️", from: .trailing, tint: BeerStatsColor.warning, size: 150, opacity: 0.3)
            })

        case 11:
            // Der Daumenmeister: Ein grosser Daumen schlaegt von unten ein,
            // der ganze Tisch zieht nach.
            return AnyView(ZStack {
                EffectShockwave(tint: BeerStatsColor.success, rings: 3, duration: 1.5, delay: 0.3)
                EffectParticles(
                    symbol: "👍", count: 9, flight: .rise,
                    tint: BeerStatsColor.success, duration: 1.8, stagger: 0.12, opacity: 0.5
                )
                EffectSlam(symbol: "👍", from: .bottom, tint: BeerStatsColor.success, size: 190, opacity: 0.32)
            })

        case 12:
            // Die Dame ist die praechtigste Karte: Strahlen, Kronenregen,
            // Funken, Druckwelle – und die Krone setzt sich oben auf.
            return AnyView(ZStack {
                EffectRays(tint: BeerStatsColor.warning, spokes: 14, duration: 12, opacity: 0.22)
                EffectParticles(
                    symbol: "👑", count: 8, flight: .fall,
                    tint: BeerStatsColor.warning, duration: 2.2, opacity: 0.5
                )
                EffectParticles(
                    symbol: "✨", count: 10, flight: .burst,
                    tint: BeerStatsColor.warning, duration: 1.8,
                    stagger: 0.1, sizeRange: 14...26, opacity: 0.55, seed: 41
                )
                EffectShockwave(tint: BeerStatsColor.warning, rings: 2, duration: 1.6, lineWidth: 2, delay: 0.3)
                EffectSlam(symbol: "👑", from: .top, tint: BeerStatsColor.warning, size: 170, opacity: 0.3)
            })

        case 13:
            // Die Kategorie: Begriffe platzen nach allen Seiten – das Spiel
            // geht reihum und nicht auf eine Person.
            return AnyView(ZStack {
                EffectRays(tint: BeerStatsColor.accent, spokes: 12, duration: 16, opacity: 0.15)
                EffectParticles(
                    symbol: "📚", count: 10, flight: .burst,
                    tint: BeerStatsColor.accent, duration: 2.0, stagger: 0.12, opacity: 0.5
                )
                EffectSlam(symbol: "👑", from: .top, tint: BeerStatsColor.accent, size: 160, opacity: 0.26)
            })

        default:
            // Das Ass ist der einzige Shot im Blatt. Es brennt: Strahlen,
            // zwei Funkenschichten, Druckwelle, Glas.
            return AnyView(ZStack {
                EffectRays(tint: BeerStatsColor.error, spokes: 16, duration: 9, opacity: 0.24)
                EffectParticles(
                    symbol: "🔥", count: 11, flight: .rise,
                    tint: BeerStatsColor.error, duration: 1.6,
                    stagger: 0.1, sizeRange: 26...48, opacity: 0.6
                )
                EffectParticles(
                    symbol: "✨", count: 9, flight: .rise,
                    tint: BeerStatsColor.warning, duration: 2.4,
                    stagger: 0.16, sizeRange: 12...22, opacity: 0.5, seed: 67
                )
                EffectShockwave(tint: BeerStatsColor.error, rings: 3, duration: 1.3)
                EffectSlam(symbol: "🥃", from: .bottom, tint: BeerStatsColor.error, size: 160, opacity: 0.32)
            })
        }
    }
}
