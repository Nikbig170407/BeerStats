//
//  Casino.swift
//  BeerStats
//
//  Die Welt des Trink-Roulettes: Spieltischfilz mit goldenem Rand. Das Rad
//  und seine Szenen sind neu und bleiben – dazu kommen ein Kranz aus Holz
//  und Gold, Lichter, die sich mitdrehen, und eine goldene Nabe.
//

import SwiftUI

enum CasinoArt {
    static let gold = SceneArt.rgb(212, 175, 90)
    static let wood = SceneArt.rgb(120, 90, 40)
    static let bulb = SceneArt.rgb(255, 236, 170)
}

/// Der Kranz um das Rad. Die Lichter drehen sich mit, wenn `rotation`
/// mitgegeben wird.
struct CasinoRim: View {

    let size: CGFloat
    let rotation: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(CasinoArt.wood, lineWidth: 16)
                .frame(width: size + 22, height: size + 22)
            Circle()
                .stroke(CasinoArt.gold, lineWidth: 5)
                .frame(width: size + 14, height: size + 14)

            Canvas { context, canvas in
                let cx = Double(canvas.width) / 2, cy = Double(canvas.height) / 2
                let r = Double(size) / 2 + 7
                var lichter = Path()
                for i in 0..<16 {
                    let winkel = Double(i) / 16 * 2 * .pi
                    let x = cx + cos(winkel) * r, y = cy + sin(winkel) * r
                    lichter.addEllipse(in: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5))
                }
                context.fill(lichter, with: .color(CasinoArt.bulb))
            }
            .frame(width: size + 30, height: size + 30)
            .rotationEffect(.degrees(rotation))
        }
        .shadow(color: .black.opacity(0.6), radius: 18, y: 8)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
