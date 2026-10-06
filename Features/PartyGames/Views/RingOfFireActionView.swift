//
//  RingOfFireActionView.swift
//  BeerStats
//
//  Der zweite Screen von Ring of Fire: die gezogene Karte, gross.
//
//  Vorher stand die Karte als Panel unter dem Ring. Das hiess: kleine
//  Spielkarte, kleiner Text, und daneben lenkte der ganze Ring ab – obwohl
//  in diesem Moment nur eine Frage zaehlt, naemlich was jetzt zu tun ist.
//
//  Deshalb Vollbild und nur ein Knopf. Die Karte ist gross genug, dass man
//  sie quer ueber den Tisch erkennt, und unter dem Text stehen dieselben
//  zwei Zeilen wie auf den Extreme-Karten: wie lange es gilt und was es
//  kostet, wenn man verliert.
//

import SwiftUI

struct RingOfFireActionView: View {

    let card: PlayingCard
    let rule: RingOfFireRule
    let onDone: () -> Void

    @State private var hasAppeared = false

    /// Rollen-Karten faerben rot, der Rest bernstein – dieselbe Zuordnung
    /// wie vorher im Panel.
    private var tint: Color {
        rule.role == nil ? BeerStatsColor.accent : BeerStatsColor.error
    }

    var body: some View {
        ZStack {
            AmbientBackdrop(glow: tint)

            ScrollView {
                VStack(spacing: 16) {
                    PlayingCardView(card: card, width: 150)
                        .shadow(color: tint.opacity(0.4), radius: 24)
                        .scaleEffect(hasAppeared ? 1 : 0.7)
                        .padding(.top, 12)

                    Text(rule.nickname)
                        .font(.scaled(11, weight: .heavy, design: .rounded))
                        .kerning(2)
                        .foregroundStyle(BeerStatsColor.textSecondary)

                    HStack(spacing: 10) {
                        Text(rule.emoji).font(.system(size: 30))
                        Text(rule.title)
                            .font(.scaled(30, weight: .heavy, design: .rounded))
                            .foregroundStyle(tint)
                            .multilineTextAlignment(.center)
                    }

                    Text(rule.text)
                        .font(BeerStatsFont.body)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)

                    terms
                        .padding(.top, 4)
                }
                .padding(24)
            }
            .verticalScrollOnly()
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Verstanden", systemImage: "checkmark") {
                onDone()
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [
                        BeerStatsColor.backgroundPrimary.opacity(0),
                        BeerStatsColor.backgroundPrimary
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                hasAppeared = true
            }
        }
    }

    /// Wie lange und was es kostet.
    ///
    /// Die Dauer steht IMMER da, auch wenn sie „Sofort" lautet – dieselbe
    /// Entscheidung wie bei den Extreme-Karten. Die Strafe fehlt dagegen bei
    /// Karten, die einfach eine Menge ansagen: Dort ist das Trinken die
    /// Handlung, es gibt nichts zu verlieren.
    private var terms: some View {
        VStack(spacing: 6) {
            TermRow(
                systemImage: "clock",
                label: "Wie lange",
                value: rule.duration ?? "Sofort"
            )

            if let penalty = rule.penalty {
                TermRow(
                    systemImage: "drop.fill",
                    label: "Strafe",
                    value: penalty,
                    tint: BeerStatsColor.error
                )
            }
        }
    }
}
