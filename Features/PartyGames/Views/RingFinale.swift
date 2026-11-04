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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        EffectCanvas(
            draw: { g, size, t in RingFinaleArt.draw(&g, size, t, radius: Double(radius)) },
            stillAt: RingFinaleArt.still,
            delay: RingFinaleArt.delay,
            minimumInterval: RingFinaleArt.frameInterval
        )
        // Wo das Feuer sich schliesst, faucht die Saeule hoch – man hoert und
        // spuert es. Mit "Bewegung reduzieren" steht der Kranz still da, ohne
        // einen Knall zu einem Moment, den man nicht sieht.
        .task {
            guard !reduceMotion else { return }
            try? await Task.sleep(nanoseconds: UInt64((RingFinaleArt.delay + RingFinaleArt.closing) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            SoundManager.play(.ringBlaze)
            HapticManager.play([
                HapticManager.Tap(time: 0, intensity: 1, sharpness: 0.5),
                HapticManager.Tap(time: 0.12, intensity: 0.6, sharpness: 0.3)
            ])
        }
    }
}

/// Alles Zeichnen fuer den Kranz. Reine Rechnung auf der Leinwand.
enum RingFinaleArt {

    /// Die Szene in einem Satz (Satz-Regel). `RingSceneTests` haelt fest,
    /// dass kein Rang ihn mit ihr teilt.
    static let motion = "Ein Feuer jagt mit heller Spitze um den Ring, schießt beim Schließen oben als Säule hoch, Glut regnet langsam herab, die Luft darüber flimmert, und danach brennt der Kranz ruhig weiter."

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

        // Hinten: die Glut im leeren Ring atmet, ein zweiter, langsamer
        // Kranz loht dahinter, und die Luft darueber flimmert
        SceneArt.glow(&g, cx, cy, r * 0.95, SceneArt.ember,
                      (0.12 + 0.06 * sin(t * 2.2)) * SceneArt.clamp(t / closing) + 0.25 * auf)
        backWreath(&g, cx, cy, r, lang: lang, platz: platz, t: t, auf: auf)
        shimmer(&g, cx, cy, r, platz: platz, t: t)

        band(&g, cx, cy, r, bis: front, auf: auf)
        flames(&g, cx, cy, r, lang: lang, t: t, auf: auf)
        if nach >= 0 {
            column(&g, cx, cy, r, platz: platz, nach: nach, t: t)
            seam(&g, cx, cy, r, nach: nach)
            emberRain(&g, cx, cy, r, platz: platz, w: w, nach: nach)
        } else {
            head(&g, cx, cy, r, front: front, t: t)
        }
        sparks(&g, cx, cy, r, lang: lang, platz: platz, t: t)
    }

    /// Ein zweiter, langsamer Kranz hinter dem ersten – breiter, dunkler,
    /// er gibt dem Feuer Tiefe.
    private static func backWreath(_ g: inout GraphicsContext, _ cx: Double, _ cy: Double, _ r: Double,
                                   lang: Double, platz: Double, t: Double, auf: Double) {
        var feuer = g
        feuer.blendMode = .plusLighter
        for k in 0..<22 {
            let kk = Double(k)
            let grad = kk * 360 / 22 + 8
            let alter = t - reaches(grad)
            guard alter > 0 else { continue }
            let wachsen = SceneArt.easeOut(alter / 0.6)
            let flackern = 0.7 + 0.3 * sin(t * (3 + SceneArt.unit(k, 30)) + kk)
            let laenge = min(platz - 4, lang * 1.7 * wachsen * flackern * (1 + 0.4 * auf))
            let richtung = (grad - 90) * .pi / 180 + 0.2 * sin(t * 1.5 + kk)
            RingTearArt.tongue(&feuer, RingTearArt.point(cx, cy, r + 6, grad), richtung, laenge, 14,
                               0.35 * wachsen, t * 0.5, k + 50)
        }
    }

    /// Die Luft ueber dem Kranz flimmert: feine Wellenlinien, die aufsteigen.
    private static func shimmer(_ g: inout GraphicsContext, _ cx: Double, _ cy: Double, _ r: Double,
                                platz: Double, t: Double) {
        let da = SceneArt.clamp((t - 0.8) / 1.2)
        guard da > 0 else { return }
        let oben = cy - r
        let weg = r * 0.5 + platz - 6
        for k in 0..<5 {
            let dk = Double(k)
            let z = SceneArt.fract(t * 0.3 + dk / 5)
            let y = oben + r * 0.5 - weg * z
            var linie: [SceneArt.Point] = []
            var x = cx - r * 1.2
            while x <= cx + r * 1.2 {
                linie.append((x, y + 4 * sin(x * 0.06 + t * 5 + dk)))
                x += 12
            }
            SceneArt.stroke(&g, linie, SceneArt.emberCore, 0.08 * sin(z * .pi) * da, 2)
        }
    }

    /// Wo das Feuer sich oben schliesst, schiesst es als Saeule hoch – so
    /// hoch, wie die Flaeche reicht, und dort schon verglueht.
    private static func column(_ g: inout GraphicsContext, _ cx: Double, _ cy: Double, _ r: Double,
                               platz: Double, nach: Double, t: Double) {
        guard nach < 1.2 else { return }
        let kraft = SceneArt.easeOut(nach / 0.12) * (1 - SceneArt.easeIn(SceneArt.clamp((nach - 0.25) / 0.95)))
        guard kraft > 0 else { return }
        let oben = RingTearArt.point(cx, cy, r, 0)
        let hoch = (platz - 4) * kraft
        var feuer = g
        feuer.blendMode = .plusLighter
        let saeule: [SceneArt.Point] = [(oben.x - 26, oben.y), (oben.x + 26, oben.y), (oben.x + 40, oben.y - hoch), (oben.x - 40, oben.y - hoch)]
        SceneArt.fill(&feuer, saeule, from: (0, oben.y), to: (0, oben.y - hoch), [
            (0, SceneArt.rgb(255, 236, 190), 0.55 * kraft),
            (0.5, SceneArt.rgb(255, 140, 50), 0.25 * kraft),
            (1, SceneArt.rgb(200, 50, 20), 0)
        ])
        for k in 0..<9 {
            let dk = Double(k)
            let richtung = -Double.pi / 2 + (dk - 4) * 0.09 + 0.05 * sin(t * 9 + dk)
            let laenge = (platz - 4) * (0.82 + 0.18 * SceneArt.unit(k, 421)) * kraft * (k == 4 ? 1 : 0.92)
            RingTearArt.tongue(&feuer, oben, richtung, laenge, 13, 0.95, t, k + 70)
        }
    }

    /// Glut regnet langsam herab – von dort, wohin die Saeule sie geworfen hat.
    private static func emberRain(_ g: inout GraphicsContext, _ cx: Double, _ cy: Double, _ r: Double,
                                  platz: Double, w: Double, nach: Double) {
        guard nach >= 0.2 else { return }
        var b = SceneBrush(g)
        let farben: [Color] = [SceneArt.rgb(255, 240, 180), SceneArt.rgb(255, 150, 50), SceneArt.rgb(220, 70, 30)]
        let deckkraft: [Double] = [1, 0.85, 0.6]
        let oben = cy - r
        for i in 0..<46 {
            let alter = nach - 0.2 - 1.8 * SceneArt.unit(i, 430)
            guard alter >= 0, alter <= 2.4 else { continue }
            let x = cx + (SceneArt.unit(i, 431) - 0.5) * min(w - 20, r * 2.6) + 14 * sin(alter * 2.2 + Double(i))
            let y = oben - (platz - 6) * SceneArt.unit(i, 432) + (60 + 50 * SceneArt.unit(i, 433)) * alter
            guard y < cy + r + platz - 6 else { continue }
            let rest = 1 - alter / 2.4
            let stufe = rest > 0.66 ? 0 : (rest > 0.33 ? 1 : 2)
            b.circle(x, y, 1.2 + 1.6 * SceneArt.unit(i, 434), farben[stufe], deckkraft[stufe])
        }
        b.flush()
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

    /// Die Spitze des Feuers, solange es noch laeuft: ein heller Kopf, der
    /// nach hinten zuengelt.
    private static func head(_ g: inout GraphicsContext, _ cx: Double, _ cy: Double, _ r: Double,
                             front: Double, t: Double) {
        let p = RingTearArt.point(cx, cy, r, front)
        if front > 2 {
            var feuer = g
            feuer.blendMode = .plusLighter
            let rueckwaerts = (front - 90) * .pi / 180 - .pi / 2
            for k in 0..<4 {
                RingTearArt.tongue(&feuer, p, rueckwaerts + (Double(k) - 1.5) * 0.35 - 0.6,
                                   36 + 14 * SceneArt.unit(k, 420), 9, 0.9, t, k + 90)
            }
        }
        SceneArt.glow(&g, p.x, p.y, 40, SceneArt.rgb(255, 160, 60), 0.9)
        SceneArt.glow(&g, p.x, p.y, 14, RingTearArt.core, 0.95)
        SceneArt.circle(&g, p.x, p.y, 4, RingTearArt.core, 1)
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
