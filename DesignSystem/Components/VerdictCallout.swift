//
//  VerdictCallout.swift
//  BeerStats
//
//  Das Urteil nach einer Antwort, gross: wer, und was es kostet.
//
//  Rueckmeldung vom 3. November zur Hitparade: "Nachdem man die Antwort
//  abgegeben hat, muss die Strafe groesser verkuendet werden." Bis dahin
//  stand sie als ein Satz in Fliesstextgroesse unter der Platte – "Daneben.
//  Lena trinkt 2 Schluecke." –, und am Tisch las ihn niemand, weil alle auf
//  die Jahreszahl schauten. Die Menge ist aber genau das, worauf der Tisch
//  wartet.
//
//  Drei Zeilen statt eines Satzes: eine kleine Ueberschrift ("DANEBEN"),
//  der Name, und die Menge so gross, dass man sie aus anderthalb Metern
//  liest. Ohne Verb: "trinkt" waere bei Liegestuetzen falsch
//  (`PenaltyStyle`), und die Menge sagt ohnehin, was zu tun ist.
//
//  Ein geteilter Baustein und kein Text im Spiel, weil jedes Spiel mit
//  einer Strafe denselben Moment hat. Die Schrift kommt aus der Welt.
//

import SwiftUI

struct VerdictCallout: View {

    /// Klein darueber: "DANEBEN", "SITZT", "ALLE ANDEREN".
    let headline: String
    /// Wen es trifft – `nil`, wenn die Ueberschrift das schon sagt.
    var who: String?
    /// Das Grosse: die Menge, oder bei einem Treffer, was man bekommt.
    let verdict: String
    /// Rot fuer eine Strafe, Gruen fuer einen Treffer – die beiden Farben
    /// behalten ihre Bedeutung.
    let tint: Color

    @Environment(\.gameWorld) private var world
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Die Menge schlaegt auf wie ein Stempel – sie soll ankommen, nicht
    /// nur dastehen. Gelesen werden kann sie nach einer Drittelsekunde.
    @State private var landed = false

    var body: some View {
        VStack(spacing: 6) {
            Text(headline)
                .font(.scaled(13, weight: .heavy, design: .rounded))
                .kerning(2.4)
                .foregroundStyle(tint)

            if let who {
                Text(who)
                    .font(Font.world(world, 24, weight: .heavy))
                    .foregroundStyle(BeerStatsColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Text(verdict)
                .font(Font.world(world, 44, weight: .heavy))
                .foregroundStyle(tint)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                // Bei Aufgaben statt Schluecken ist die Menge ein ganzer
                // Satz – dann wird er kleiner, statt abgeschnitten
                .minimumScaleFactor(0.45)
                .scaleEffect(landed ? 1 : 1.6)
                .opacity(landed ? 1 : 0)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(tint.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(tint.opacity(0.55), lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .onAppear {
            guard !reduceMotion else {
                landed = true
                return
            }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { landed = true }
        }
    }
}
