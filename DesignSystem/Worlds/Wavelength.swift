//
//  Wavelength.swift
//  BeerStats
//
//  Die Welt der Skala: ein Halbkreis zwischen zwei Polen. Eine Klappe liegt
//  ueber der Zielzone, solange geraten wird; zur Aufloesung dreht sie sich
//  weg. Die Runde zieht die Nadel am Bogen entlang statt an einem Regler.
//
//  Der Regler war richtig, aber er war ein Regler – dasselbe Bauteil wie in
//  den Einstellungen. Am Tisch zeigt man auf eine STELLE, und ein Bogen ist
//  eine Stelle, die man zeigen kann.
//

import SwiftUI

enum Wavelength {
    static let cool = SceneArt.rgb(60, 200, 220)
    static let warm = SceneArt.rgb(240, 120, 40)
    static let near = SceneArt.rgb(255, 220, 90)
    static let bullseye = SceneArt.rgb(200, 40, 40)
    static let shutter = SceneArt.rgb(22, 44, 66)
    static let housing = SceneArt.rgb(14, 30, 44)
    static let needle = SceneArt.rgb(240, 60, 60)

    /// Wie viel Platz unter der Grundlinie bleibt – dort verschwindet die
    /// Klappe im Gehaeuse.
    static let housingHeight: CGFloat = 46

    static func mix(_ u: Double) -> Color {
        let a = (r: 60.0, g: 200.0, b: 220.0), b = (r: 240.0, g: 120.0, b: 40.0)
        return SceneArt.rgb(a.r + (b.r - a.r) * u, a.g + (b.g - a.g) * u, a.b + (b.b - a.b) * u)
    }
}

/// Das Rad. `guess` ist zum Ziehen gebunden; `nil` zeigt keine Nadel.
struct WavelengthDial: View {

    let target: Double
    /// Halbe Breite der Zonen, in Punkten der Skala (0 bis 100).
    let bullseye: Double
    let nearMiss: Double
    @Binding var guess: Double
    let showsNeedle: Bool
    /// Ob die Klappe offen ist. Wechselt sie auf offen, dreht sie sich weg.
    let isOpen: Bool
    let leftPole: String
    let rightPole: String
    /// Zur Aufloesung: Die Klappe ist erst zu und dreht sich dann weg.
    var opensOnAppear = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shutter: Double = 0

    var body: some View {
        GeometryReader { geometry in
            DialFace(target: target, bullseye: bullseye, nearMiss: nearMiss,
                     guess: showsNeedle ? guess : nil, shutter: shutter)
                .contentShape(Rectangle())
                // Ohne Nadel gibt es nichts zu ziehen
                .gesture(drag(in: geometry.size), including: showsNeedle ? .all : .none)
        }
        .frame(height: 230)
        .onAppear {
            guard opensOnAppear, !reduceMotion else {
                shutter = isOpen ? 1 : 0
                return
            }
            shutter = 0
            // Erst zu zeigen, dann aufdrehen – im selben Durchlauf saehe
            // SwiftUI nur den Endwert
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.8)) { shutter = 1 }
            }
        }
        .onChange(of: isOpen) { offen in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.8)) { shutter = offen ? 1 : 0 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Skala von \(leftPole) bis \(rightPole)")
        .accessibilityValue(showsNeedle ? "\(Int(guess.rounded())) von 100" : "")
        .accessibilityAdjustableAction { richtung in
            guard showsNeedle else { return }
            switch richtung {
            case .increment: guess = min(100, guess + 5)
            case .decrement: guess = max(0, guess - 5)
            @unknown default: break
            }
        }
    }

    /// Aus der Stelle des Fingers wird ein Wert: Winkel um die Mitte des
    /// Bogens, links null, rechts hundert. Unter der Grundlinie bleibt die
    /// Nadel am naeheren Ende.
    private func drag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { zug in
                let mitte = DialFace.center(in: size)
                let dx = Double(zug.location.x - mitte.x)
                let dy = Double(zug.location.y - mitte.y)
                let winkel = atan2(dy, dx)
                let wert: Double
                if winkel <= 0 {
                    wert = (winkel + .pi) / .pi * 100
                } else {
                    wert = winkel > .pi / 2 ? 0 : 100
                }
                let neu = min(100, max(0, wert))
                // Ein leichter Tick je zehn Punkte – man spuert, wo man ist
                if Int(neu / 10) != Int(guess / 10) { HapticManager.lightImpact() }
                guess = neu
            }
    }
}

/// Die Zeichnung des Rades. Animierbar ueber die Klappe.
private struct DialFace: View, Animatable {

    let target: Double
    let bullseye: Double
    let nearMiss: Double
    let guess: Double?
    var shutter: Double

    var animatableData: Double {
        get { shutter }
        set { shutter = newValue }
    }

    static func center(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height - Wavelength.housingHeight)
    }

    static func radius(in size: CGSize) -> Double {
        Double(min(size.width / 2 - 24, size.height - Wavelength.housingHeight - 12))
    }

    var body: some View {
        Canvas { context, size in
            let mitte = Self.center(in: size)
            let cx = Double(mitte.x), cy = Double(mitte.y)
            let r = Self.radius(in: size)
            let winkel: (Double) -> Double = { .pi + $0 / 100 * .pi }

            // Der Bogen in sechzig Stuecken, von kuehl nach warm
            for i in 0..<60 {
                let a0 = Double(i) / 60, a1 = Double(i + 1) / 60
                var keil: [SceneArt.Point] = [(cx, cy)]
                keil += SceneArt.arc(cx, cy, r, winkel(a0 * 100), winkel(a1 * 100) + 0.01, 3)
                SceneArt.fill(&context, keil, Wavelength.mix(a0), 0.9)
            }

            // Die Zonen: straffrei aussen, Treffer in der Mitte
            for (breite, farbe) in [(nearMiss, Wavelength.near), (bullseye, Wavelength.bullseye)] {
                let von = max(0, target - breite), bis = min(100, target + breite)
                var keil: [SceneArt.Point] = [(cx, cy)]
                keil += SceneArt.arc(cx, cy, r, winkel(von), winkel(bis), 16)
                SceneArt.fill(&context, keil, farbe, 0.95)
            }

            // Die Klappe dreht weg; was unter die Grundlinie dreht,
            // verschwindet im Gehaeuse
            if shutter < 1 {
                var klappe = context
                klappe.clip(to: Path(CGRect(x: 0, y: 0, width: Double(size.width), height: cy)))
                klappe.translateBy(x: cx, y: cy)
                klappe.rotate(by: .radians(shutter * .pi))
                var deckel: [SceneArt.Point] = [(0, 0)]
                deckel += SceneArt.arc(0, 0, r + 4, .pi, 2 * .pi, 40)
                SceneArt.fill(&klappe, deckel, Wavelength.shutter, 1)
                for i in 1..<6 {
                    let ri = r * Double(i) / 6
                    SceneArt.stroke(&klappe, SceneArt.arc(0, 0, ri, .pi + 0.05, 2 * .pi - 0.05, 30), .white, 0.06, 2)
                }
            }

            // Das Gehaeuse unter der Grundlinie
            let gehaeuse = CGRect(x: cx - r - 24, y: cy, width: 2 * r + 48, height: Double(Wavelength.housingHeight))
            context.fill(Path(roundedRect: gehaeuse, cornerRadius: 14), with: .color(Wavelength.housing))
            let links: SceneArt.Point = (cx - r - 24, cy)
            let rechts: SceneArt.Point = (cx + r + 24, cy)
            SceneArt.lines(&context, [(links, rechts)], Wavelength.cool, 0.35, 2)

            if let guess {
                let w = winkel(guess)
                let spitze: SceneArt.Point = (cx + cos(w) * (r + 16), cy + sin(w) * (r + 16))
                let fuss: SceneArt.Point = (cx, cy)
                SceneArt.stroke(&context, [fuss, spitze], Wavelength.needle, 1, 5)
                SceneArt.circle(&context, cx, cy, 12, Wavelength.needle, 1)
                SceneArt.circle(&context, spitze.x, spitze.y, 16, .white, 0.22)
            }
        }
    }
}
