//
//  SecretFile.swift
//  BeerStats
//
//  Die Welt des Spions: Geheimakte, Stempel, Schreibmaschine.
//
//  Die Akte ist ein GEGENSTAND und darf deshalb hell sein – Pappe und
//  Papier mit eigener, fester Tinte (Regel 3 in `GameWorld`). Alles andere
//  bleibt auf dem dunklen Schreibtisch.
//
//  Der Spion bekommt rotes Papier. Das ist keine Zierde, sondern dieselbe
//  Aussage wie vorher die rote Schrift: Wer das Blatt sieht, weiss sofort,
//  welche Rolle er hat – auch bevor das Wort fertig getippt ist.
//

import SwiftUI

enum SecretFile {

    static let folder = SceneArt.rgb(204, 170, 108)
    static let folderLight = SceneArt.rgb(222, 192, 134)
    static let folderDeep = SceneArt.rgb(170, 136, 78)
    static let paper = SceneArt.rgb(241, 233, 214)
    static let alarmPaper = SceneArt.rgb(186, 44, 40)
    static let ink = SceneArt.rgb(28, 26, 26)
    /// Stempelfarbe auf Pappe.
    static let stamp = SceneArt.rgb(176, 34, 34)
    /// Dasselbe Rot auf dem dunklen Schreibtisch – heller gemischt, sonst
    /// verschwindet der Abdruck im Grund.
    static let stampOnDark = SceneArt.rgb(228, 82, 70)
    static let clip = SceneArt.rgb(190, 190, 196)
    static let coffee = SceneArt.rgb(110, 70, 30)

    static func paper(alarm: Bool) -> Color { alarm ? alarmPaper : paper }
    static func ink(alarm: Bool) -> Color { alarm ? paper : ink }
}

// MARK: - Die Akte

/// Die Akte beim Weitergeben: zu, solange das Handy wandert, aufgeklappt
/// zeigt sie das Blatt mit dem Geheimnis.
///
/// Das Geheimnis steht nur im Baum, solange die Akte offen ist – nicht
/// bloss verdeckt. Sonst laese VoiceOver es dem Nebenmann vor, und beim
/// Zuklappen schiene es durch den Deckel, waehrend das Handy schon wandert.
struct Dossier<Secret: View>: View {

    let player: Int
    let isOpen: Bool
    /// Rotes Papier – fuer den, der etwas anderes weiss als alle anderen.
    let alarm: Bool
    let secret: Secret

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static var minHeight: CGFloat { 300 }
    private static var corner: CGFloat { 8 }

    /// Jede Akte eine andere Nummer – dieselbe Nummer fuer alle saehe nach
    /// Formular aus, nicht nach Akte.
    private var number: String { String(format: "%04d", 417 + 23 * player) }

    var body: some View {
        ZStack {
            page

            cover
                // Der Deckel klappt um die linke Kante auf. Danach blendet er
                // kurz aus, damit von der Kante nichts stehen bleibt.
                .rotation3DEffect(.degrees(isOpen ? -90 : 0), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.55)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: isOpen)
                .opacity(isOpen ? 0 : 1)
                .animation(reduceMotion ? nil : .linear(duration: 0.08).delay(isOpen ? 0.27 : 0), value: isOpen)
                .allowsHitTesting(false)
                .accessibilityHidden(isOpen)
        }
        // Ruecken und Reiter als Hintergrund: Ein Hintergrund bekommt die
        // fertige Groesse. In einem ScrollView ist die Hoehe sonst offen,
        // und eine Flaeche ohne eigene Hoehe waere zehn Punkte hoch.
        .background {
            RoundedRectangle(cornerRadius: Self.corner, style: .continuous)
                .fill(SecretFile.folderDeep)
                .shadow(color: .black.opacity(0.55), radius: 12, y: 8)
        }
        .background(alignment: .topTrailing) { tab.offset(x: -26, y: -24) }
        .padding(.top, 24)
    }

    private var page: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isOpen {
                secret
                    // Weg ist weg – kein Ausblenden, waehrend das Handy wandert
                    .transition(.identity)
            }
        }
        .foregroundStyle(SecretFile.ink(alarm: alarm))
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(22)
        // Zu und offen gleich hoch, damit beim Aufklappen nichts springt
        .frame(minHeight: Self.minHeight - 28, alignment: .top)
        .background(SecretFile.paper(alarm: alarm), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            // Durch Haende gegangen. Auf dem roten Blatt nicht – dort soll
            // nichts von der Rolle ablenken.
            if !alarm {
                CoffeeRing().frame(width: 64, height: 64).padding(8)
            }
        }
        .rotationEffect(.degrees(-0.8))
        .padding(14)
    }

    private var cover: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AKTE NR. \(number)")
                    .font(.scaled(13, weight: .bold, design: .monospaced))
                    .foregroundStyle(SecretFile.ink.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(SecretFile.paper.opacity(0.92), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                Spacer(minLength: 0)
            }

            Spacer(minLength: 24)

            RubberStamp(text: "STRENG GEHEIM", color: SecretFile.stamp, angle: -9, slams: false)

            Spacer(minLength: 24)

            Text("Nur für \(PlayerNames.plainName(for: player))")
                .font(.scaled(14, weight: .medium, design: .monospaced))
                .foregroundStyle(SecretFile.ink.opacity(0.7))

            Text("Handy übernehmen, dann aufdecken.")
                .font(.scaled(12, weight: .regular, design: .monospaced))
                .foregroundStyle(SecretFile.ink.opacity(0.55))
                .padding(.top, 4)
        }
        .multilineTextAlignment(.center)
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: Self.minHeight)
        .background(
            LinearGradient(colors: [SecretFile.folderLight, SecretFile.folder], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Self.corner, style: .continuous)
        )
        .overlay(alignment: .topTrailing) {
            PaperClip().frame(width: 22, height: 64).offset(x: -46, y: -16)
        }
        .accessibilityElement(children: .combine)
    }

    /// Der Reiter ragt oben aus dem Ruecken heraus.
    private var tab: some View {
        Text(number)
            .font(.scaled(12, weight: .bold, design: .monospaced))
            .foregroundStyle(SecretFile.ink.opacity(0.55))
            .padding(.horizontal, 22)
            .padding(.top, 7)
            .padding(.bottom, 16)
            .background(SecretFile.folderDeep, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Stempel

/// Ein Stempel, der aufknallt und seinen Abdruck hinterlaesst.
///
/// Der Text steht nach einer Viertelsekunde – der Abdruck ist die Nachricht,
/// das Aufknallen nur der Weg dorthin.
struct RubberStamp: View {

    let text: String
    var color: Color = SecretFile.stampOnDark
    var angle: Double = -7
    /// Auf dem Deckel der Akte ist er schon da; in den Phasen des Spiels
    /// knallt er beim Erscheinen auf.
    var slams = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    var body: some View {
        let liegt = !slams || reduceMotion || landed

        Text(text)
            .font(.scaled(20, weight: .heavy, design: .monospaced))
            .kerning(2)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(color, lineWidth: 3))
            // Stempelfarbe ist nie ueberall gleich satt
            .mask(StampWear(seed: text.count))
            .rotationEffect(.degrees(angle))
            .scaleEffect(liegt ? 1 : 1.8)
            .opacity(liegt ? 1 : 0)
            .onAppear {
                guard slams, !reduceMotion else { return }
                withAnimation(.spring(response: 0.24, dampingFraction: 0.62)) { landed = true }
            }
    }
}

/// Die Maske des Stempels: voll, mit ausgesparten Stellen, an denen die
/// Farbe nicht angekommen ist. Gerechneter Zufall – sonst sprangen die
/// Fehlstellen bei jedem Neuzeichnen.
private struct StampWear: View {

    let seed: Int

    var body: some View {
        Canvas { context, size in
            let rahmen = CGRect(origin: .zero, size: size)
            context.fill(Path(rahmen), with: .color(.black))
            context.blendMode = .destinationOut
            let anzahl = Int(Double(size.width * size.height) / 30)
            SceneArt.grain(&context, anzahl, .black, 0.85, seed: seed * 7 + 3, rahmen, dot: 2.2)
        }
    }
}

// MARK: - Kleinkram auf der Akte

private struct PaperClip: View {

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(SecretFile.clip.opacity(0.9), lineWidth: 2.5)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(SecretFile.clip.opacity(0.9), lineWidth: 2.5)
                .frame(width: 12, height: 44)
                .padding(.top, 8)
        }
        .accessibilityHidden(true)
    }
}

private struct CoffeeRing: View {

    var body: some View {
        Canvas { context, size in
            let w = Double(size.width), h = Double(size.height)
            let bogen = SceneArt.arc(w / 2, h / 2, min(w, h) / 2 - 4, 0.4, 4.9)
            SceneArt.stroke(&context, bogen, SecretFile.coffee, 0.16, 5)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
