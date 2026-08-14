//
//  RulesView.swift
//  BeerStats
//
//  Das Regelwerk zum Nachlesen.
//
//  Die App setzt jede dieser Regeln um – Balls Back, Bombe, On Fire,
//  Redemption, Trickshot – und konnte bisher keine einzige davon erklaeren.
//  Kam jemand Neues an den Tisch und fragte "was ist ein Bounce Shot?",
//  musste ein Mensch antworten. Damit ist die App bedienbar, aber nicht
//  erklaerbar.
//
//  Entscheidend ist, WOHER die Texte ihre Zahlen nehmen: aus demselben
//  `GameFormat`, mit dem die Engine rechnet. Steht dort ein anderer
//  Schwellwert fuer On Fire, sagt die Erklaerung ihn auch. Eine
//  Regelbeschreibung, die man getrennt pflegen muss, ist nach dem zweiten
//  Regel-Feinschliff falsch – und falsche Regeln sind schlimmer als keine,
//  weil man ihnen glaubt.
//
//  Abgeschaltete Regeln stehen gar nicht erst da. Wer mit ausgeschaltetem
//  Bounce Shot spielt, soll nicht ueber eine Regel stolpern, die es in
//  seiner Partie nicht gibt.
//

import SwiftUI

struct RulesView: View {

    /// Standardformat, wenn der Screen ausserhalb einer Partie geoeffnet wird.
    var format: GameFormat = GameFormat()

    var body: some View {
        ZStack {
            GridBackdrop(glow: BeerStatsColor.accent)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    section("Der Zug", rules: turnRules)
                    section("Treffer mit Wirkung", rules: hitRules)
                    section("Das Ende", rules: endRules)

                    footer
                }
                .padding(22)
            }
        }
        .navigationTitle("Regeln")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Bausteine

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📖").font(.system(size: 48))

            Text("So wird gespielt")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            Text("\(format.cupCount) Becher pro Team. Die App zählt mit – ihr werft.")
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textSecondary)
        }
    }

    private func section(_ title: String, rules: [Rule]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .kerning(1.8)
                .foregroundStyle(BeerStatsColor.textSecondary)

            ForEach(rules) { rule in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 9) {
                        Text(rule.emoji).font(.system(size: 20))
                        Text(rule.title)
                            .font(BeerStatsFont.headline)
                            .foregroundStyle(BeerStatsColor.textPrimary)
                    }
                    Text(rule.text)
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .glassPanel(cornerRadius: 16)
            }
        }
    }

    private var footer: some View {
        Text("Bei Streit gilt, was die App sagt. Sie hat den ganzen Abend mitgezählt, ihr nicht.")
            .font(BeerStatsFont.caption)
            .foregroundStyle(BeerStatsColor.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    // MARK: - Inhalt

    private struct Rule: Identifiable {
        let emoji: String
        let title: String
        let text: String
        var id: String { title }
    }

    private var turnRules: [Rule] {
        var rules = [
            Rule(
                emoji: "🎯",
                title: "Zwei Bälle pro Zug",
                text: "Jedes Team wirft zwei Bälle, auch im 1 gegen 1 – dort wirft dieselbe Person beide."
            ),
            Rule(
                emoji: "🔁",
                title: "Balls Back",
                text: "Treffen beide Bälle eines Zuges, wirft dasselbe Team noch einmal. Gilt auch in der Redemption."
            )
        ]

        if format.onFireEnabled {
            rules.append(Rule(
                emoji: "🔥",
                title: "On Fire",
                text: "Ab dem \(format.onFireStreakThreshold). Treffer in Folge behält derselbe Spieler den Ball, bis er verfehlt."
            ))
        }

        if format.airballPenaltyEnabled {
            rules.append(Rule(
                emoji: "💀",
                title: "Airball",
                text: "Weder Becher noch Tisch getroffen: Das kostet einen Shot. Nach einem Rebound zählt es nicht."
            ))
        }

        return rules
    }

    private var hitRules: [Rule] {
        var rules = [
            Rule(
                emoji: "💣",
                title: "Bombe",
                text: "Trifft der zweite Ball denselben Becher wie der erste, fallen dieser und zwei weitere. Die zwei sucht das gegnerische Team aus."
            )
        ]

        if format.bounceShotsAllowed {
            rules.append(Rule(
                emoji: "🏓",
                title: "Bounce Shot",
                text: "Aufsetzer im Becher zählt zwei Becher – den zweiten wählt der Gegner. Für die Serie zählt er als ein Treffer."
            ))
        }

        if format.trickshotsAllowed {
            rules.append(Rule(
                emoji: "🌀",
                title: "Rebound und Trickshot",
                text: "Kommt der Ball ohne Bodenkontakt zurück und wird gefangen, darf sofort noch einmal geworfen werden. Trifft er, zählt er zwei Becher. Nicht verkettbar."
            ))
        }

        if format.reRacksAllowed {
            rules.append(Rule(
                emoji: "🔺",
                title: "Umstellen",
                text: "Einmal pro Team pro Spiel dürft ihr die Becher neu anordnen. Zur Auswahl stehen feste Formationen – jede lässt keinen Becher allein und behält die Becherzahl."
            ))
        }

        return rules
    }

    private var endRules: [Rule] {
        var rules: [Rule] = []

        if format.redemptionAllowed {
            rules.append(Rule(
                emoji: "⏳",
                title: "Redemption",
                text: "Ist ein Rack leer, wirft das unterlegene Team weiter – immer beide Bälle zu Ende. Treffen beide, geht es weiter. Räumt es alles ab, steht es unentschieden."
            ))
        }

        rules.append(Rule(
            emoji: "🏆",
            title: "Gewonnen",
            text: "Wer zuerst alle \(format.cupCount) Becher des Gegners abräumt und die Redemption übersteht, gewinnt."
        ))

        rules.append(Rule(
            emoji: "↩️",
            title: "Vertippt?",
            text: "Zurücknehmen geht jederzeit. Die App merkt sich jeden Wurf einzeln und rechnet den Stand neu aus."
        ))

        return rules
    }
}
