//
//  PosterTools.swift
//  BeerStats
//
//  Handgriffe fuer die Plakate, die mehr als ein Motiv brauchen: Pfade aus
//  der Vorschau, Ellipsen, Kartenfarben, Schrift auf dem Bild.
//
//  Die Plakate werden im Browser als SVG abgestimmt und dann hier
//  nachgezeichnet. Damit dabei keine Kurve verrutscht, nimmt `path(_:)`
//  die Pfade aus der Vorschau woertlich – dieselben Zahlen an beiden
//  Stellen, statt sie von Hand in `addCurve` umzuschreiben.
//

import SwiftUI

extension PosterInk {

    // MARK: - Pfade aus der Vorschau

    /// Ein SVG-Pfad mit den Befehlen M, L, C, Q und Z, absolut, Zahlen durch
    /// Leerzeichen oder Komma getrennt. Mehr brauchen die Plakate nicht;
    /// Boegen stehen als `addArc` im Code, weil ihre SVG-Schreibweise eine
    /// eigene Rechnung braeuchte.
    ///
    /// Gedacht fuer `static let` – geparst wird einmal, nicht je Bild.
    static func path(_ d: String) -> Path {
        var path = Path()
        var zahlen: [CGFloat] = []
        var befehl: Character = "M"

        func ausfuehren() {
            switch befehl {
            case "M":
                guard zahlen.count >= 2 else { return }
                path.move(to: CGPoint(x: zahlen[0], y: zahlen[1]))
                // Weitere Paare nach M sind Linien, wie im SVG
                var i = 2
                while i + 1 < zahlen.count {
                    path.addLine(to: CGPoint(x: zahlen[i], y: zahlen[i + 1]))
                    i += 2
                }
            case "L":
                var i = 0
                while i + 1 < zahlen.count {
                    path.addLine(to: CGPoint(x: zahlen[i], y: zahlen[i + 1]))
                    i += 2
                }
            case "C":
                var i = 0
                while i + 5 < zahlen.count {
                    path.addCurve(
                        to: CGPoint(x: zahlen[i + 4], y: zahlen[i + 5]),
                        control1: CGPoint(x: zahlen[i], y: zahlen[i + 1]),
                        control2: CGPoint(x: zahlen[i + 2], y: zahlen[i + 3])
                    )
                    i += 6
                }
            case "Q":
                var i = 0
                while i + 3 < zahlen.count {
                    path.addQuadCurve(
                        to: CGPoint(x: zahlen[i + 2], y: zahlen[i + 3]),
                        control: CGPoint(x: zahlen[i], y: zahlen[i + 1])
                    )
                    i += 4
                }
            case "Z":
                path.closeSubpath()
            default:
                break
            }
            zahlen = []
        }

        var wort = ""
        func zahlAbschliessen() {
            if let zahl = Double(wort) { zahlen.append(CGFloat(zahl)) }
            wort = ""
        }

        for zeichen in d {
            if "MLCQZ".contains(zeichen) {
                zahlAbschliessen()
                ausfuehren()
                befehl = zeichen
            } else if zeichen == " " || zeichen == "," {
                zahlAbschliessen()
            } else if zeichen == "-", !wort.isEmpty {
                // "10-5" sind zwei Zahlen
                zahlAbschliessen()
                wort = "-"
            } else {
                wort.append(zeichen)
            }
        }
        zahlAbschliessen()
        ausfuehren()
        return path
    }

    // MARK: - Formen

    static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: 2 * rx, height: 2 * ry))
    }

    static func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, corner: CGFloat = 0) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: corner, style: .continuous)
    }

    /// Gefuellt und mit der dunklen Kontur – die Handschrift des Siebdrucks.
    static func inked(_ g: inout GraphicsContext, _ path: Path, _ fill: Color, line: CGFloat = 2.4, ink color: Color = PosterInk.ink) {
        g.fill(path, with: .color(fill))
        g.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
    }

    /// Der harte Schatten unter einem Ding, leicht nach rechts unten versetzt.
    static func dropShadow(_ g: inout GraphicsContext, _ path: Path, dx: CGFloat = 5, dy: CGFloat = 6, opacity: Double = 0.3) {
        g.fill(path.offsetBy(dx: dx, dy: dy), with: .color(Color.black.opacity(opacity)))
    }

    static func line(_ g: inout GraphicsContext, _ path: Path, _ color: Color, _ width: CGFloat, opacity: Double = 1, dash: [CGFloat] = []) {
        g.stroke(path, with: .color(color.opacity(opacity)),
                 style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash))
    }

    /// Ein Zeichen auf dem Bild, um seine Mitte gesetzt. Feste Groesse: Es
    /// ist Teil der Zeichnung und waechst mit ihr, nicht mit der Schrift
    /// des Systems.
    static func letter(_ g: inout GraphicsContext, _ text: String, at mitte: CGPoint, size: CGFloat, color: Color) {
        g.draw(
            Text(text)
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .foregroundColor(color),
            at: mitte
        )
    }

    // MARK: - Kartenfarben

    /// Als Pfade, nicht als Zeichen: "♥" kaeme auf manchen Geraeten als
    /// Emoji, und auf einem Plakat zaehlt jede Farbe.
    static let spade = path("M0 -30 C18 -12 34 0 22 14 C14 22 4 18 2 12 L8 30 L-8 30 L-2 12 C-4 18 -14 22 -22 14 C-34 0 -18 -12 0 -30 Z")
    static let heart = path("M0 26 C-30 4 -34 -16 -18 -24 C-8 -29 0 -20 0 -12 C0 -20 8 -29 18 -24 C34 -16 30 4 0 26 Z")
    static let diamond = path("M0 -28 L22 0 L0 28 L-22 0 Z")
    static let club: Path = {
        var p = Path()
        p.addEllipse(in: CGRect(x: -11, y: -30, width: 22, height: 22))
        p.addEllipse(in: CGRect(x: -26, y: -10, width: 22, height: 22))
        p.addEllipse(in: CGRect(x: 4, y: -10, width: 22, height: 22))
        p.addPath(path("M-3 4 L3 4 L8 28 L-8 28 Z"))
        return p
    }()

    /// Eine Kartenfarbe um `mitte`, `scale` 1 ist gut 60 Einheiten hoch.
    static func suit(_ form: Path, at mitte: CGPoint, scale: CGFloat) -> Path {
        form.applying(CGAffineTransform(translationX: mitte.x, y: mitte.y).scaledBy(x: scale, y: scale))
    }
}
