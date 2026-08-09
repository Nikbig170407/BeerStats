//
//  BeerStatsWidgetBundle.swift
//  BeerStatsWidgets
//
//  Die Widget-Extension. Sie zeichnet ausschliesslich die Live-Anzeige der
//  laufenden Partie – Heimbildschirm-Widgets gibt es bewusst keine: Eine
//  Statistik, die man nur alle paar Tage anschaut, gehoert in die App.
//
//  Dieses Ziel baut gegen iOS 16.1, waehrend die App auf 16.0 laeuft. Damit
//  faellt hier jede Verfuegbarkeitspruefung weg; die App entscheidet zur
//  Laufzeit, ob sie ueberhaupt eine Aktivitaet startet.
//

import SwiftUI
import WidgetKit
import ActivityKit

@main
struct BeerStatsWidgetBundle: WidgetBundle {
    var body: some Widget {
        BeerpongLiveActivity()
    }
}

struct BeerpongLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BeerpongActivityAttributes.self) { context in
            lockScreen(context.attributes, context.state)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    score(context.attributes.teamOne, context.state.cupsTeamOne)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    score(context.attributes.teamTwo, context.state.cupsTeamTwo)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 2) {
                        Text(context.state.thrower)
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                        Text(context.state.detail)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Text("🍺")
            } compactTrailing: {
                Text("\(context.state.cupsTeamOne):\(context.state.cupsTeamTwo)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
            } minimal: {
                Text("🍺")
            }
        }
    }

    // MARK: - Sperrbildschirm

    private func lockScreen(
        _ attributes: BeerpongActivityAttributes,
        _ state: BeerpongActivityAttributes.ContentState
    ) -> some View {
        VStack(spacing: 10) {
            HStack {
                score(attributes.teamOne, state.cupsTeamOne)
                Spacer()
                Text("🍺").font(.system(size: 22))
                Spacer()
                score(attributes.teamTwo, state.cupsTeamTwo)
            }

            // Das Eigentliche: Wer wirft. Genau dafuer schaut jemand aufs
            // gesperrte Handy, das auf dem Tisch liegt.
            VStack(spacing: 1) {
                Text(state.thrower)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                Text(state.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }

    private func score(_ team: String, _ cups: Int) -> some View {
        VStack(spacing: 1) {
            Text(team)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(cups)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
    }
}
