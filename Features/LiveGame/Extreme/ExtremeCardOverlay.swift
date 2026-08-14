//
//  ExtremeCardOverlay.swift
//  BeerStats
//
//  Die Karte, die nach einem geladenen Becher aufblitzt.
//
//  Der Aufbau folgt der Reihenfolge, in der man am Tisch hinsieht: erst die
//  Farbe (gut oder schlecht?), dann wen es trifft, dann der Titel, zuletzt
//  der Text. Deshalb faehrt der farbige Schein zuerst hoch und der Text
//  einen Wimpernschlag spaeter nach.
//
//  Weggetippt wird nur ueber den Knopf, nicht durch Tippen irgendwo. Im
//  Live-Screen liegen die Becher direkt darunter, und ein Fehlgriff waere
//  hier besonders aergerlich: Die Karte ist weg, bevor sie jemand gelesen
//  hat, und der Wurf ist schon gebucht.
//

import SwiftUI

struct ExtremeCardOverlay: View {

    let card: ExtremeCard
    let onDismiss: () -> Void

    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            // Verdunkelt alles darunter, faengt aber bewusst KEINE Tipps ab,
            // die den Becher treffen wuerden – der Knopf ist der einzige Weg
            // hinaus.
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text(card.category.emoji)
                    .font(.system(size: 62))
                    .scaleEffect(hasAppeared ? 1 : 0.4)

                Text(card.category.title.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .kerning(2.4)
                    .foregroundStyle(card.category.color)
                    .padding(.top, 10)

                Text(card.category.target)
                    .font(BeerStatsFont.caption)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                    .padding(.top, 2)

                Text(card.title)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)

                Text(card.text)
                    .font(BeerStatsFont.body)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .padding(.horizontal, 6)

                Button {
                    onDismiss()
                    HapticManager.lightImpact()
                } label: {
                    Text("Verstanden")
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            card.category.color,
                            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 22)
            }
            .padding(26)
            .frame(maxWidth: 340)
            .glassPanel(cornerRadius: 26)
            .neonEdge(card.category.color, cornerRadius: 26, intensity: 1)
            .shadow(color: card.category.color.opacity(0.5), radius: 30)
            .scaleEffect(hasAppeared ? 1 : 0.8)
            .opacity(hasAppeared ? 1 : 0)
            .padding(24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                hasAppeared = true
            }
        }
    }
}
