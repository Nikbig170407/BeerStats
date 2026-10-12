//
//  HiddenCards.swift
//  BeerStats
//
//  Karten, die nie wieder kommen sollen.
//
//  Bis jetzt gab es genau einen Weg, eine Karte loszuwerden, die am Tisch
//  nicht funktioniert: sie aus dem Quelltext streichen lassen. Das ist ein
//  Umweg ueber jemanden, der gerade nicht dabei ist – und bis dahin kommt
//  sie jeden Abend wieder.
//
//  Ausgeblendet wird ueber einen STABILEN Schluessel, nicht ueber den
//  angezeigten Text. Der Unterschied ist entscheidend: Viele Karten tragen
//  eine Trinkmenge, und die wird erst beim Anzeigen ausformuliert. "Trink
//  einen Shot" und "Trink 5 Schluecke" sind derselbe Eintrag in
//  verschiedenen Haerten. Wer nach dem Text ausblendet, sieht die Karte
//  wieder, sobald jemand die Haerte umstellt – und versteht nicht, warum.
//
//  Die Schluessel:
//    Beerpong Extreme     -> die Kennung der Karte ("penalty-Ex")
//    Ich hab noch nie     -> der rohe Text der Aussage, ohne Strafen
//    Wahrheit oder Pflicht-> der Text MIT Platzhaltern, vor dem Einsetzen
//
//  Gespeichert lokal, wie die eigenen Karten: Der Stapel gehoert einer
//  Runde, nicht einem Konto.
//

import SwiftUI

enum HiddenCards {

    /// Nicht `private`, damit die Tests sichern und zuruecklegen koennen,
    /// was sie anfassen – sie schreiben in dieselben UserDefaults wie die
    /// App (siehe `PlayerNamesTests`).
    static func storageKey(for deck: CustomCardDeck) -> String {
        "hiddenCards.\(deck.rawValue)"
    }

    static func keys(for deck: CustomCardDeck) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: storageKey(for: deck)) ?? [])
    }

    static func isHidden(_ cardKey: String, in deck: CustomCardDeck) -> Bool {
        keys(for: deck).contains(cardKey)
    }

    static func hide(_ cardKey: String, in deck: CustomCardDeck) {
        var alle = keys(for: deck)
        alle.insert(cardKey)
        UserDefaults.standard.set(Array(alle), forKey: storageKey(for: deck))
    }

    static func show(_ cardKey: String, in deck: CustomCardDeck) {
        var alle = keys(for: deck)
        alle.remove(cardKey)
        UserDefaults.standard.set(Array(alle), forKey: storageKey(for: deck))
    }

    static func showAll(in deck: CustomCardDeck) {
        UserDefaults.standard.removeObject(forKey: storageKey(for: deck))
    }

    static func count(for deck: CustomCardDeck) -> Int {
        keys(for: deck).count
    }
}

// MARK: - Knopf

/// Der Daumen nach unten, ueberall gleich.
///
/// Bewusst klein und unauffaellig neben dem Weiter-Knopf: Ausblenden ist
/// die seltene Entscheidung, Weiterspielen die haeufige. Waeren beide gleich
/// gross, traefe man beim schnellen Tippen das Falsche – und eine
/// versehentlich ausgeblendete Karte merkt man erst, wenn sie fehlt.
///
/// Gemerkt wird der ausgeblendete SCHLUESSEL, nicht ein Ja/Nein.
///
/// Das ist kein Detail, sondern der Grund, warum der Knopf lange nur
/// einmal pro Spiel funktionierte: SwiftUI erkennt eine Ansicht an ihrer
/// Stelle im Baum, nicht an ihren Werten. Neben dem Weiter-Knopf steht
/// derselbe `HideCardButton` fuer jede Karte – mit einem `Bool` blieb
/// deshalb das "schon ausgeblendet" der ersten Karte stehen, und ab da war
/// der Knopf fuer alle folgenden Karten beschriftet wie benutzt und per
/// `disabled` tot. Am Tisch sieht das aus wie ein kaputter Knopf.
///
/// Mit dem Schluessel vergleicht sich der Zustand selbst: Kommt eine neue
/// Karte, passt der gemerkte Schluessel nicht mehr, und der Knopf ist
/// wieder da. Die Aufrufstellen brauchen dafuer kein `.id(…)` zu setzen –
/// was sie garantiert irgendwann vergessen haetten.
struct HideCardButton: View {

    let cardKey: String
    let deck: CustomCardDeck
    var onHidden: () -> Void = {}

    @State private var ausgeblendeterSchluessel: String?

    private var wurdeAusgeblendet: Bool {
        ausgeblendeterSchluessel == cardKey
    }

    var body: some View {
        Button {
            HiddenCards.hide(cardKey, in: deck)
            ausgeblendeterSchluessel = cardKey
            HapticManager.lightImpact()
            onHidden()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: wurdeAusgeblendet ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 12))
                Text(wurdeAusgeblendet ? "Kommt nicht wieder" : "Nie wieder")
                    .font(BeerStatsFont.caption)
            }
            .foregroundStyle(
                wurdeAusgeblendet ? BeerStatsColor.error : BeerStatsColor.textSecondary
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(wurdeAusgeblendet)
    }
}
