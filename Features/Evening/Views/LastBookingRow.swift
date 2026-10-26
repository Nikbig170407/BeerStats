//
//  LastBookingRow.swift
//  BeerStats
//
//  „Zuletzt: Lena, 3 Schlücke – zurücknehmen."
//
//  Die Partyspiele buchen Mengen auf Leute, und am Tisch vertippt man sich
//  dabei auf zwei Arten: falsche Menge und falsche PERSON. Bis Oktober 2026
//  gab es dagegen nur die Minus-Taste am Teilnehmer im Abend-Screen – die
//  nimmt einen Schluck zurueck, nicht eine Buchung, und die falsche Person
//  heilt sie gar nicht. Drei Schluecke auf den Falschen hiessen: dreimal
//  Minus beim einen, dreimal Plus beim anderen. Das macht niemand, und
//  danach glaubt der Bilanz keiner mehr.
//
//  Die Zeile steht deshalb an den zwei Orten, an denen man nach einem
//  Vertipper hinschaut: im Abend-Screen und auf der Abend-Karte im
//  Hauptmenue – von jedem Spiel aus einmal Zurueck.
//
//  Sie zeigt sich nur, wenn es etwas zurueckzunehmen gibt, und verschwindet
//  nach dem Zuruecknehmen von selbst. Eine Zeile, die dauernd dasteht, liest
//  nach dem dritten Mal niemand mehr.
//

import SwiftUI

struct LastBookingRow: View {

    let evening: Evening?
    /// Wird nach dem Zuruecknehmen gerufen – die Ansicht darueber muss den
    /// Abend neu lesen, UserDefaults meldet sich nicht von selbst.
    let onUndo: () -> Void

    var body: some View {
        if let abend = evening, abend.isRunning,
           let buchung = abend.lastBooking,
           let person = abend.participants.first(where: { $0.id == buchung.participantId }),
           buchung.sips > 0 || buchung.shots > 0 {

            HStack(spacing: 10) {
                Text("↩️")

                VStack(alignment: .leading, spacing: 1) {
                    Text("Zuletzt gebucht")
                        .font(.scaled(10, weight: .heavy, design: .rounded))
                        .kerning(1.2)
                        .foregroundStyle(BeerStatsColor.textSecondary)

                    Text("\(person.emoji) \(person.name) · \(menge(buchung))")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                QuietButton(title: "Zurücknehmen") {
                    guard EveningLog.undoLastBooking() else { return }
                    HapticManager.lightImpact()
                    onUndo()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassPanel(cornerRadius: 14)
        }
    }

    /// Die gebuchten Zahlen, nicht `DrinkAmount`: Hier steht, was in der
    /// Bilanz gelandet IST. Die Haerte galt beim Buchen und darf eine
    /// Rueckfrage nicht nachtraeglich umrechnen.
    private func menge(_ buchung: EveningBooking) -> String {
        var teile: [String] = []
        if buchung.sips > 0 {
            teile.append(buchung.sips == 1 ? "1 Schluck" : "\(buchung.sips) Schlücke")
        }
        if buchung.shots > 0 {
            teile.append(buchung.shots == 1 ? "1 Shot" : "\(buchung.shots) Shots")
        }
        return teile.joined(separator: " · ")
    }
}
