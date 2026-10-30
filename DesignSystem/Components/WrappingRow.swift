//
//  WrappingRow.swift
//  BeerStats
//
//  Elemente nebeneinander, und wenn die Zeile voll ist, geht es in der
//  naechsten weiter – wie Woerter in einem Satz.
//
//  Entstanden fuer die Hitparade (30. Oktober, Wunsch des Nutzers: "alles
//  auf einen Screen, sodass man nicht viel scrollen muss"). Die eigene
//  Reihe stand dort als Liste untereinander, eine Zeile je Karte und eine
//  je Luecke – mit zehn Karten einundzwanzig Zeilen, und die Antwort lag
//  unter dem Rand. Als umbrechende Reihe sind es drei, vier Zeilen.
//
//  Ein eigener Baustein und kein `LazyVGrid`: Ein Raster gibt jeder Spalte
//  dieselbe Breite, hier sind die Elemente verschieden breit (ein schmales
//  Plus neben einer Jahreszahl), und gerade das spart den Platz.
//

import SwiftUI

struct WrappingRow: Layout {

    /// Abstand zwischen zwei Elementen einer Zeile.
    var spacing: CGFloat = 8
    /// Abstand zwischen zwei Zeilen.
    var lineSpacing: CGFloat = 8
    /// Wohin eine Zeile rueckt, die nicht voll ist: mittig im Spiel, buendig
    /// im Vorspann, wo alles andere auch links steht.
    var alignment: HorizontalAlignment = .center

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let zeilen = lines(for: subviews, width: proposal.width ?? .infinity)
        let hoehe = zeilen.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, zeilen.count - 1))
        let breiteste = zeilen.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? breiteste, height: hoehe)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for zeile in lines(for: subviews, width: bounds.width) {
            var x = bounds.minX + einzug(frei: bounds.width - zeile.width)
            for index in zeile.indices {
                let groesse = subviews[index].sizeThatFits(.unspecified)
                // Innerhalb der Zeile mittig in der Hoehe: Ein Chip ist
                // niedriger als ein Knopf daneben
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (zeile.height - groesse.height) / 2),
                    proposal: ProposedViewSize(groesse)
                )
                x += groesse.width + spacing
            }
            y += zeile.height + lineSpacing
        }
    }

    private func einzug(frei: CGFloat) -> CGFloat {
        switch alignment {
        case .leading: return 0
        case .trailing: return frei
        default: return frei / 2
        }
    }

    private struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// Verteilt die Elemente auf Zeilen. Ein Element, das allein schon
    /// breiter ist als die Zeile, bekommt eine eigene – abgeschnitten wird
    /// nichts.
    private func lines(for subviews: Subviews, width: CGFloat) -> [Line] {
        var zeilen: [Line] = []
        var aktuell = Line()
        for index in subviews.indices {
            let groesse = subviews[index].sizeThatFits(.unspecified)
            let breiter = aktuell.indices.isEmpty ? groesse.width : aktuell.width + spacing + groesse.width
            if breiter > width, !aktuell.indices.isEmpty {
                zeilen.append(aktuell)
                aktuell = Line()
            }
            aktuell.width = aktuell.indices.isEmpty ? groesse.width : aktuell.width + spacing + groesse.width
            aktuell.height = max(aktuell.height, groesse.height)
            aktuell.indices.append(index)
        }
        if !aktuell.indices.isEmpty { zeilen.append(aktuell) }
        return zeilen
    }
}
