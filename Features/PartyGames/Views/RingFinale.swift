//
//  RingFinale.swift
//  BeerStats
//
//  Ring durch: Ein Feuer laeuft einmal um den leeren Ring, schliesst sich
//  oben und lodert als Kranz weiter.
//
//  Wunsch des Nutzers vom 28. Oktober: "noch mehr Animationen" bei Ring of
//  Fire. Eine durchgespielte Runde stand bis dahin als Zeile unter einem
//  leeren Kreis. Jetzt wird der Ring, um den es die ganze Runde ging, am
//  Ende zu dem, was der Name des Spiels sagt.
//
//  Bewusst kein Feuerwerk: Das hat der Sieger-Screen von Beerpong, und zwei
//  Momente sehen nur dort gleich aus, wo sie dasselbe bedeuten (Satz-Regel,
//  siehe `DrawnScenes`). Gezeichnet wird dort, wo die Karten lagen – auf dem
//  Radius des Rings, mit denselben Flammenzungen wie der Riss. Im Browser
//  mit derselben Rechnung abgestimmt, fuer 20, 32 und 52 Karten.
//

import SwiftUI

/// Der Flammenkranz, wenn nichts mehr im Ring liegt. Liegt im Quadrat des
/// Rings, hinter der Zahl in der Mitte.
struct RingFinale: View {

    /// Auf diesem Radius lagen die Kartenmitten – dort brennt der Kranz.
    let radius: CGFloat

    var body: some View {
        EffectCanvas(
            draw: { g, size, t in RingFinaleArt.draw(&g, size, t, radius: Double(radius)) },
            stillAt: RingFinaleArt.still,
            delay: RingFinaleArt.delay,
            minimumInterval: RingFinaleArt.frameInterval
        )
    }
}

/// Alles Zeichnen fuer den Kranz. Reine Rechnung auf der Leinwand.
enum RingFinaleArt {

    /// Die Szene in einem Satz (Satz-Regel). `RingSceneTests` haelt fest,
    /// dass kein Rang ihn mit ihr teilt.
    static let motion = "Ein Feuer läuft einmal um den leeren Ring, schließt sich oben und lodert als Kranz weiter."

    /// So lange laeuft das Feuer einmal herum.
    static let closing = 1.3
    /// So lange waechst eine Flamme, nachdem das Feuer bei ihr war.
    static let growing = 0.35
    /// So lange flammt der Kranz auf, nachdem er sich geschlossen hat.
    static let flaring = 0.7
    /// Zungen je Lage – eine Lage nach aussen, eine kuerzere nach innen.
    static let tongueCount = 44
    /// Funken, die vom brennenden Kranz aufsteigen, und wie lange einer
    /// unterwegs ist.
    static let sparkCount = 28
    static let sparkCycle = 1.6
    /// Funken, die beim Schliessen aus der Naht spritzen.
    static let burstCount = 16

    /// Das stille Bild bei "Bewegung reduzieren": der geschlossene Kranz.
    static let still = 2.6
    /// Der Kartenscreen faehrt beim Schliessen nach unten aus dem Bild – der
    /// Anfang liefe sonst unter ihm.
    static let delay = 0.25
    /// Der Kranz brennt, solange "Ring durch" dasteht, oft minutenlang.
    /// Dreissig Bilder je Sekunde reichen fuer Flammen.
    static let frameInterval = 1.0 / 30

    /// Wann das Feuer an einer Stelle ankommt, in Grad von oben im
    /// Uhrzeigersinn: gleichmaessig, wie eine Zuendschnur.
    static func reaches(_ grad: Double) -> Double {
        closing * grad / 360
    }

    static func draw(_ g: inout GraphicsContext, _ size: CGSize, _ t: Double, radius r: Double) {
        let w = Double(size.width), h = Double(size.height)
        let cx = w / 2, cy = h / 2
        let platz = min(w, h) / 2 - r
        // Die laengste Zunge (Grundlaenge 1,15, Aufflammen 1,35) bleibt in
        // der Flaeche. Abgeschnitten saehe der Kranz aus wie ein Bild, das
        // nicht passt.
        let lang = max(10, min(34, (platz - 6) / 1.55))
        let front = 360 * SceneArt.clamp(t / closing)
        let nach = t - closing
        let auf = nach >= 0 ? 1 - SceneArt.clamp(nach / flaring) : 0

        band(&g, cx, cy, r, bis: front, auf: auf)
        flames(&g, cx, cy, r, lang: lang, t: t, auf: auf)
        if nach >= 0 {
            seam(&g, cx, cy, r, nach: nach)
        } else {
            head(&g, RingTearArt.point(cx, cy, r, front))
        }
        sparks(&g, cx, cy, r, lang: lang, platz: platz, t: t)
    }

    /// Die Glut auf dem Ring, so weit das Feuer schon gelaufen ist.
    private static func band(_ g: inout GraphicsContext, _ cx: Double, _ cy: Double, _ r: Double,
                             bis: Double, auf: Double) {
        guard bis > 0.5 else { return }
        let punkte = RingTearArt.ringArc(cx, cy, r, 0, bis, max(2, Int((bis / 4).rounded())))
        SceneArt.stroke(&g, punkte, RingTearArt.ember, 0.12 + 0.2 * auf, 18 + 6 * auf)
        SceneArt.stroke(&g, punkte, RingTearArt.strained, 0.32 + 0.3 * auf, 7)
        SceneArt.stroke(&g, punkte, RingTearArt.hot, 0.85, 2.4)
    }

    /// Die Zungen: abwechselnd nach aussen und, kuerzer, nach innen. Jede
    /// flackert in zwei eigenen Takten und ist verschieden lang – mit einem
    /// Takt fuer alle stuende da eine Sonne und kein Feuer.
    private static func flames(_ g: inout GraphicsContext, _ cx: Double, _ cy: Double, _ r: Double,
                               lang: Double, t: Double, auf: Double) {
        var feuer = g
        feuer.blendMode = .plusLighter
        let breite = min(11, 2 * Double.pi * r / Double(tongueCount) * 0.42)

        for k in 0..<(tongueCount * 2) {
            let innen = k % 2 == 1
            let kk = Double(k)
            let grad = kk * 180 / Double(tongueCount) + 2.5 * SceneArt.noise(k, 1)
            let alter = t - reaches(max(0, grad))
            guard alter > 0 else { continue }

            let wachsen = SceneArt.easeOut(alter / growing)
            let langsam = sin(t * (8 + 5 * SceneArt.unit(k, 8)) + 6.3 * SceneArt.unit(k, 9))
            let rasch = sin(t * (19 + 4 * SceneArt.unit(k, 10)) + kk)
            let flackern = 0.6 + 0.25 * langsam + 0.15 * rasch
            let grund = 0.55 + 0.6 * SceneArt.unit(k, 3)
            let anteil: Double = innen ? 0.45 : 1
            let laenge = anteil * lang * grund * wachsen * flackern * (1 + 0.35 * auf)

            let aussen = (grad - 90) * Double.pi / 180
            let wiegen = 0.16 * sin(t * (3 + 2 * SceneArt.unit(k, 11)) + kk)
            let richtung = (innen ? aussen + Double.pi : aussen) + wiegen
            let schmal: Double = innen ? 0.7 : 1
            let dicke = breite * schmal * (0.8 + 0.4 * SceneArt.unit(k, 12))

            RingTearArt.tongue(&feuer, RingTearArt.point(cx, cy, r, grad), richtung, laenge, dicke,
                               min(1, wachsen * 1.3), t, k)
        }
    }

    /// Die Spitze des Feuers, solange es noch laeuft.
    private static func head(_ g: inout GraphicsContext, _ p: SceneArt.Point) {
        SceneArt.glow(&g, p.x, p.y, 34, SceneArt.rgb(255, 160, 60), 0.85)
        SceneArt.glow(&g, p.x, p.y, 12, RingTearArt.core, 0.9)
        SceneArt.circle(&g, p.x, p.y, 3.5, RingTearArt.core, 1)
    }

    /// Der Kranz schliesst sich oben: Aufleuchten an der Naht und ein
    /// Funkenschwall. Der Schein bleibt in der Flaeche – oberhalb des Rings
    /// ist nur ein schmaler Rand, und dort waere er hart abgeschnitten.
    private static func seam(_ g: inout GraphicsContext, _ cx: Double, _ cy: Double, _ r: Double, nach: Double) {
        let oben = RingTearArt.point(cx, cy, r, 0)
        let weit = min(44, oben.y - 2)
        SceneArt.glow(&g, oben.x, oben.y, weit * (0.5 + 0.5 * SceneArt.easeOut(nach / 0.3)),
                      SceneArt.rgb(255, 236, 190), 0.85 * (1 - SceneArt.clamp(nach / 0.9)))

        for i in 0..<burstCount {
            let alter = nach - 0.02 * SceneArt.unit(i, 13)
            guard alter >= 0, alter <= 0.8 else { continue }
            let winkel = -Double.pi / 2 + (SceneArt.unit(i, 14) * 2 - 1) * 1.4
            let tempo = 120 + 160 * SceneArt.unit(i, 15)
            let x = oben.x + cos(winkel) * tempo * alter
            let y = oben.y + sin(winkel) * tempo * alter + 300 * alter * alter
            let rest = 1 - alter / 0.8
            SceneArt.circle(&g, x, y, 1.2 + 1.4 * rest, funke(rest), rest)
        }
    }

    /// Funken steigen von dort auf, wo es schon brennt – nach aussen, bis
    /// kurz vor den Rand.
    private static func sparks(_ g: inout GraphicsContext, _ cx: Double, _ cy: Double, _ r: Double,
                               lang: Double, platz: Double, t: Double) {
        for i in 0..<sparkCount {
            let lauf = t / sparkCycle + SceneArt.unit(i, 5)
            let z = SceneArt.fract(lauf)
            let runde = Int(lauf.rounded(.down))
            let grad = 360 * SceneArt.unit(i + 37 * runde, 6)
            guard t - z * sparkCycle >= reaches(grad) + 0.15 else { continue }

            let weg = r + lang * 0.5 + (platz - lang * 0.5 - 4) * SceneArt.easeOut(z)
            let p = RingTearArt.point(cx, cy, weg, grad + 6 * SceneArt.noise(i + 11 * runde, 7) * z)
            let rest = 1 - z
            SceneArt.circle(&g, p.x, p.y, 1 + 1.3 * rest, funke(rest), 0.9 * rest)
        }
    }

    /// Ein Funke ist erst hell und wird zum Ende rot.
    private static func funke(_ rest: Double) -> Color {
        rest > 0.5 ? SceneArt.rgb(255, 236, 160) : SceneArt.rgb(255, 110, 40)
    }
}
