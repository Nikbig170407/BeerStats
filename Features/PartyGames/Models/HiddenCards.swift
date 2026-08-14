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

    private static func key(_ deck: CustomCardDeck) -> String {
        "hiddenCards.\(deck.rawValue)"
    }

    static func keys(for deck: CustomCardDeck) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key(deck)) ?? [])
    }

    static func isHidden(_ cardKey: String, in deck: CustomCardDeck) -> Bool {
        keys(for: deck).contains(cardKey)
    }

    static func hide(_ cardKey: String, in deck: CustomCardDeck) {
        var alle = keys(for: deck)
        alle.insert(cardKey)
        UserDefaults.standard.set(Array(alle), forKey: key(deck))
    }

    static func show(_ cardKey: String, in deck: CustomCardDeck) {
        var alle = keys(for: deck)
        alle.remove(cardKey)
        UserDefaults.standard.set(Array(alle), forKey: key(deck))
    }

    static func showAll(in deck: CustomCardDeck) {
        UserDefaults.standard.removeObject(forKey: key(deck))
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
struct HideCardButton: View {

    let cardKey: String
    let deck: CustomCardDeck
    var onHidden: () -> Void = {}

    @State private var wurdeAusgeblendet = false

    var body: some View {
        Button {
            HiddenCards.hide(cardKey, in: deck)
            wurdeAusgeblendet = true
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
