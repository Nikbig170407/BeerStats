"""Erzeugt die Klaenge fuer Ring of Fire – gerechnet, nicht heruntergeladen.

    python scripts/make_ring_sounds.py            # schreibt nach Resources/Sounds
    python scripts/make_ring_sounds.py ZIELORDNER # woanders hin, zum Anhoeren

Warum gerechnet: Das Repository ist oeffentlich, und fremde Klaenge bringen
eine Lizenz mit, die man im Blick behalten muesste. Gerechnete Klaenge haben
keine. Jeder Klang hier ist eine Funktion aus Schwingungen, Rauschen und
Filtern – nur die Standardbibliothek, kein Paket, kein Download.

Satz-Regel wie bei den Szenen: Jeder Klang laesst sich in einem Satz
beschreiben, und kein Satz kommt zweimal vor. Der Satz steht am Klang, und
das Skript bricht ab, wenn zwei sich einen teilen. Wer einen Klang aendern
will, aendert hier die Funktion – nie die WAV-Datei von Hand, sonst
ueberschreibt der naechste Lauf die Aenderung stillschweigend.

Gerechnet wird mit festem Startwert je Klang: Jeder Lauf schreibt dieselben
Dateien, und ein Diff zeigt nur, was sich wirklich geaendert hat.

Die Dateinamen sind die Faelle von `GameSound` in der App.
"""
import math
import os
import random
import struct
import sys
import wave

RATE = 44100
TAU = 2 * math.pi


# ---------------------------------------------------------------- Werkzeug

def n_von(sek):
    return max(1, int(sek * RATE))


def leer(sek):
    return [0.0] * n_von(sek)


def legen(ziel, quelle, ab_sek, gain=1.0):
    """Mischt `quelle` ab der Zeit `ab_sek` in `ziel` (verlaengert bei Bedarf)."""
    start = int(ab_sek * RATE)
    ende = start + len(quelle)
    if ende > len(ziel):
        ziel.extend([0.0] * (ende - len(ziel)))
    for i, v in enumerate(quelle):
        ziel[start + i] += v * gain
    return ziel


def rauschen(sek, rng):
    return [rng.uniform(-1, 1) for _ in range(n_von(sek))]


def sinus(freq, sek, phase=0.0):
    """Sinus mit fester oder gleitender Frequenz (`freq` darf eine Funktion der Zeit sein)."""
    n = n_von(sek)
    out = [0.0] * n
    ph = phase
    for i in range(n):
        f = freq(i / RATE) if callable(freq) else freq
        out[i] = math.sin(ph)
        ph += TAU * f / RATE
    return out


def huellkurve(n, anstieg, abfall, halten=0.0):
    """Linearer Anstieg, Halten, dann exponentielles Abklingen (abfall = Zeitkonstante)."""
    a = max(1, int(anstieg * RATE))
    h = int(halten * RATE)
    out = [0.0] * n
    for i in range(n):
        if i < a:
            out[i] = i / a
        elif i < a + h:
            out[i] = 1.0
        else:
            out[i] = math.exp(-(i - a - h) / (abfall * RATE))
    return out


def mal(x, kurve):
    return [a * b for a, b in zip(x, kurve)]


def tiefpass(x, grenze):
    """Einpoliger Tiefpass; `grenze` darf eine Funktion der Zeit sein."""
    out = [0.0] * len(x)
    y = 0.0
    for i, v in enumerate(x):
        f = grenze(i / RATE) if callable(grenze) else grenze
        a = 1 - math.exp(-TAU * f / RATE)
        y += a * (v - y)
        out[i] = y
    return out


def hochpass(x, grenze):
    t = tiefpass(x, grenze)
    return [a - b for a, b in zip(x, t)]


def bandpass(x, mitte, guete):
    """Biquad-Bandpass (RBJ, 0 dB Spitze); `mitte` darf eine Funktion der Zeit sein."""
    out = [0.0] * len(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        f = mitte(i / RATE) if callable(mitte) else mitte
        f = min(max(f, 20.0), RATE * 0.45)
        w0 = TAU * f / RATE
        alpha = math.sin(w0) / (2 * guete)
        b0, b2 = alpha, -alpha
        a0, a1, a2 = 1 + alpha, -2 * math.cos(w0), 1 - alpha
        y = (b0 * v + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, v
        y2, y1 = y1, y
        out[i] = y
    return out


def resonator(anregung, freq, abklingen):
    """Zweipoliger Resonator: klingt auf `freq` mit der Zeitkonstante `abklingen` aus."""
    r = math.exp(-1 / (abklingen * RATE))
    c = 2 * r * math.cos(TAU * freq / RATE)
    out = [0.0] * len(anregung)
    y1 = y2 = 0.0
    for i, v in enumerate(anregung):
        y = v + c * y1 - r * r * y2
        y2, y1 = y1, y
        out[i] = y
    return normiert(out, 1.0)


def impuls(sek, rng, abfall=0.0015):
    """Ein kurzer Rauschstoss – die Anregung fuer Klicks und Schlaege."""
    n = n_von(sek)
    return [rng.uniform(-1, 1) * math.exp(-i / (abfall * RATE)) for i in range(n)]


def saettigen(x, druck=1.5):
    return [math.tanh(v * druck) / math.tanh(druck) for v in x]


def normiert(x, spitze):
    m = max((abs(v) for v in x), default=0.0)
    return x if m == 0 else [v * spitze / m for v in x]


def ausblenden(x, sek=0.02):
    n = min(len(x), n_von(sek))
    for i in range(n):
        x[len(x) - 1 - i] *= i / n
    return x


def hall(x, anteil=0.2, raum=0.78, laenge=0.6, daempfung=0.4):
    """Hall nach Art von Freeverb: acht Kammfilter, vier Allpaesse.

    Mit nur vier Kammfiltern klang er metallisch – die Echos lagen so
    regelmaessig, dass man sie als Flattern hoerte.
    """
    x = x + [0.0] * n_von(laenge)
    nass = [0.0] * len(x)
    for verz in (1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617):
        puffer = [0.0] * verz
        k = 0
        tief = 0.0
        for i, v in enumerate(x):
            aus = puffer[k]
            tief = aus * (1 - daempfung) + tief * daempfung
            puffer[k] = v * 0.015 + tief * raum
            k = (k + 1) % verz
            nass[i] += aus
    for verz in (556, 441, 341, 225):
        puffer = [0.0] * verz
        k = 0
        for i, v in enumerate(nass):
            aus = puffer[k]
            puffer[k] = v + aus * 0.5
            nass[i] = aus - v
            k = (k + 1) % verz
    nass = normiert(nass, max(abs(v) for v in x) or 1.0)
    return [a * (1 - anteil) + b * anteil for a, b in zip(x, nass)]


def tiefpass2(x, grenze):
    """Zwei Tiefpaesse hintereinander – steiler, fuer Rauschen, das nicht zischen soll."""
    return tiefpass(tiefpass(x, grenze), grenze)


def gleichanteil_weg(x):
    """Haelt die Nulllinie: ein Hochpass knapp unter dem Hoerbaren."""
    out = [0.0] * len(x)
    vor = 0.0
    y = 0.0
    for i, v in enumerate(x):
        y = v - vor + 0.995 * y
        vor = v
        out[i] = y
    return out


def lautheit(x, fenster=0.25):
    """Die lauteste Viertelsekunde als Effektivwert – so laut wirkt ein Klang."""
    n = min(len(x), n_von(fenster))
    quadrate = [v * v for v in x]
    summe = sum(quadrate[:n])
    beste = summe
    for i in range(n, len(x)):
        summe += quadrate[i] - quadrate[i - n]
        beste = max(beste, summe)
    return math.sqrt(beste / n)


def angleichen(x, ziel, spitze=0.95):
    """Bringt den Klang auf die Lautheit `ziel`; Spitzen werden weich begrenzt."""
    l = lautheit(x)
    if l == 0:
        return x
    x = [v * ziel / l for v in x]
    m = max(abs(v) for v in x)
    if m > spitze:
        # Weich begrenzen statt hart abschneiden: tanh rundet die Spitzen
        x = [spitze * math.tanh(v / spitze) for v in x]
    return x


def additiv(freq, sek, teile):
    """Summe von Teiltoenen: (Verhaeltnis, Lautstaerke, Abklingzeit)."""
    n = n_von(sek)
    out = [0.0] * n
    for verh, laut, abkl in teile:
        f = freq * verh
        if f >= RATE * 0.45:
            continue
        for i in range(n):
            out[i] += laut * math.sin(TAU * f * i / RATE) * math.exp(-i / (abkl * RATE))
    return out


def fm_glocke(freq, sek, verhaeltnis=3.5, index=2.5, abfall=0.35):
    n = n_von(sek)
    out = [0.0] * n
    for i in range(n):
        t = i / RATE
        abkl = math.exp(-t / abfall)
        mod = index * math.exp(-t / (abfall * 0.4)) * math.sin(TAU * freq * verhaeltnis * t)
        out[i] = math.sin(TAU * freq * t + mod) * abkl
    attack = n_von(0.003)
    for i in range(min(attack, n)):
        out[i] *= i / attack
    return out


def gezupft(freq, sek, rng, daempfung=0.996, hell=0.5):
    """Karplus-Strong: eine gezupfte Saite."""
    periode = max(2, int(RATE / freq))
    puffer = [rng.uniform(-1, 1) for _ in range(periode)]
    # Etwas weicher anreissen – sonst klingt es nach Draht statt nach Harfe
    puffer = tiefpass(puffer, 2000 + 6000 * hell)
    out = [0.0] * n_von(sek)
    k = 0
    for i in range(len(out)):
        a = puffer[k]
        b = puffer[(k + 1) % periode]
        puffer[k] = daempfung * 0.5 * (a + b)
        out[i] = a
        k = (k + 1) % periode
    return out


def saege(freq, sek, obertoene=14, verstimmung=0.0):
    n = n_von(sek)
    out = [0.0] * n
    for k in range(1, obertoene + 1):
        f = freq * k * (1 + verstimmung)
        if f > RATE * 0.45:
            break
        for i in range(n):
            out[i] += math.sin(TAU * f * i / RATE) / k
    return out


def knistern(sek, rng, dichte, abfall, mitte=2800, guete=1.2):
    """Verstreute kleine Knackser – Glut, Funken, Feuer."""
    out = [0.0] * n_von(sek)
    t = 0.0
    while True:
        rate = dichte * math.exp(-t / abfall)
        if rate < 0.5:
            break
        t += rng.expovariate(rate)
        if t >= sek:
            break
        k = impuls(0.012, rng, abfall=0.0008)
        laut = rng.uniform(0.3, 1.0) * math.exp(-t / (abfall * 1.5))
        legen(out, k, t, laut)
    return bandpass(out, mitte, guete)


# ---------------------------------------------------------------- Die Klaenge
# Jeder Klang: (Dateiname, Anzeigename, Satz, Funktion, Lautheit)
#
# Angeglichen wird nach Lautheit, nicht nach Spitze: Ein Pfiff und ein
# Glockenschlag mit derselben Spitze klingen verschieden laut, und am Tisch
# zaehlt, was man hoert. Die Ratsche bleibt leise, weil sie oft kommt; der
# Riss ist der lauteste Klang des Spiels.

KLAENGE = []
KARTE = 0.13


def klang(datei, name, satz, laut=KARTE):
    def deko(fn):
        KLAENGE.append((datei, name, satz, fn, laut))
        return fn
    return deko


@klang("ringTick", "Ratsche", "Ein trockenes Holzklicken, wie eine Ratsche am Glücksrad.", 0.05)
def tick(rng):
    k = impuls(0.05, rng, abfall=0.0012)
    hell = bandpass(k, 2600, 3.5)
    koerper = resonator(impuls(0.05, rng, 0.0006), 950, 0.012)
    return ausblenden([a + 0.35 * b for a, b in zip(hell, koerper)], 0.01)


@klang("ringStop", "Licht hält", "Ein satter Holzschlag, wenn das Licht auf der Karte stehen bleibt.", 0.12)
def stop(rng):
    k = impuls(0.18, rng, abfall=0.002)
    klack = bandpass(k, 1300, 2.5)
    holz = resonator(impuls(0.18, rng, 0.001), 430, 0.045)
    bauch = mal(sinus(lambda t: 150 - 40 * t, 0.18), huellkurve(n_von(0.18), 0.002, 0.04))
    return ausblenden([a + 0.6 * b + 0.5 * c for a, b, c in zip(klack, holz, bauch)])


@klang("ringDraw", "Karte zieht", "Papier rutscht über Papier: ein kurzes Wischen nach oben.", 0.08)
def ziehen(rng):
    sek = 0.24
    r = rauschen(sek, rng)
    wisch = bandpass(r, lambda t: 1400 + 3200 * min(1, t / 0.16), 1.4)
    kurve = huellkurve(len(r), 0.05, 0.05, halten=0.08)
    wisch = mal(wisch, kurve)
    klapp = bandpass(impuls(0.06, rng, 0.003), 900, 1.2)
    return ausblenden(legen(wisch, klapp, 0.17, 0.5))


@klang("ringRank2", "Zwei · Du bestimmst", "Ein kurzer Pfiff, der nach oben zeigt.")
def zwei(rng):
    sek = 0.3
    f = lambda t: 1100 * (2.2 ** min(1, t / 0.16)) * (1 + 0.012 * math.sin(TAU * 9 * t))
    ton = sinus(f, sek)
    atem = bandpass(rauschen(sek, rng), f, 6)
    kurve = huellkurve(n_von(sek), 0.02, 0.05, halten=0.17)
    return ausblenden(mal([a + 0.25 * b for a, b in zip(ton, atem)], kurve), 0.04)


@klang("ringRank3", "Drei · Du selbst", "Zweimal tief geschluckt.")
def drei(rng):
    out = []
    for nr, (ab, oben, unten) in enumerate(((0.0, 420, 150), (0.24, 360, 120))):
        sek = 0.16
        blubb = sinus(lambda t, o=oben, u=unten: u + (o - u) * math.exp(-t / 0.03), sek)
        blubb = mal(blubb, huellkurve(n_von(sek), 0.004, 0.045))
        blubb = tiefpass(blubb, 900)
        legen(out, blubb, ab)
        legen(out, bandpass(impuls(0.02, rng, 0.0008), 2400, 2), ab + 0.005, 0.15)
    return hall(out, 0.12, 0.6, 0.2)


@klang("ringRank4", "Vier · Wasserfall", "Rauschen schwillt an wie ein Wasserfall, darin perlen Blasen.")
def vier(rng):
    sek = 1.25
    r = rauschen(sek, rng)
    wasser = tiefpass(bandpass(r, lambda t: 700 + 500 * math.sin(TAU * 0.7 * t) ** 2, 0.8), 3200)
    schwall = [min(1, t / 0.35) * (1 if t < 0.75 else math.exp(-(t - 0.75) / 0.18))
               for t in (i / RATE for i in range(len(wasser)))]
    gurgeln = [0.75 + 0.25 * math.sin(TAU * 5.3 * t + 2 * math.sin(TAU * 1.7 * t))
               for t in (i / RATE for i in range(len(wasser)))]
    wasser = [a * b * c for a, b, c in zip(wasser, schwall, gurgeln)]
    for _ in range(16):
        ab = rng.uniform(0.15, 0.95)
        f0 = rng.uniform(450, 900)
        blase = sinus(lambda t, f=f0: f * (1 + 2.5 * t / 0.04), 0.04)
        blase = mal(blase, huellkurve(len(blase), 0.004, 0.012))
        legen(wasser, blase, ab, rng.uniform(0.08, 0.2))
    return ausblenden(hall(wasser, 0.2, 0.7, 0.4), 0.1)


@klang("ringRank5", "Fünf · Die Jungs", "Zwei tiefe Hornstöße, der zweite höher.")
def fuenf(rng):
    out = []
    for ab, f, dauer in ((0.0, 110.0, 0.2), (0.27, 146.8, 0.32)):
        a = saege(f, dauer, 9, -0.0015)
        b = saege(f, dauer, 9, 0.0015)
        ton = [x + y for x, y in zip(a, b)]
        # Ein Horn oeffnet sich beim Anblasen und wird dann weich
        ton = tiefpass2(ton, lambda t: 380 + 900 * math.exp(-t / 0.06))
        kurve = huellkurve(len(ton), 0.03, 0.06, halten=dauer - 0.1)
        # Sanft schliessen – abgeschnitten klickt jeder Stoss am Ende
        legen(out, ausblenden(mal(ton, kurve), 0.03), ab)
    return ausblenden(hall(out, 0.15, 0.7, 0.3), 0.05)


@klang("ringRank6", "Sechs · Die Mädels", "Zwei helle Glockentöne, der zweite höher.")
def sechs(rng):
    out = []
    legen(out, fm_glocke(1318.5, 0.8, 3.5, 2.0, 0.3), 0.0)
    legen(out, fm_glocke(1760.0, 0.9, 3.5, 2.0, 0.35), 0.15)
    return ausblenden(hall(out, 0.25, 0.75, 0.5), 0.1)


@klang("ringRank7", "Sieben · Hände hoch", "Ein Ton schießt nach oben und funkelt oben kurz.")
def sieben(rng):
    sek = 0.5
    f = lambda t: 330 * (5.2 ** ((min(1, t / 0.42)) ** 1.6)) * (1 + 0.02 * math.sin(TAU * 7 * t) * t)
    ton = sinus(f, sek)
    atem = bandpass(rauschen(sek, rng), f, 5)
    kurve = huellkurve(n_von(sek), 0.03, 0.06, halten=0.38)
    out = mal([a + 0.2 * b for a, b in zip(ton, atem)], kurve)
    for k, fp in enumerate((2637.0, 3136.0, 3951.0)):
        legen(out, fm_glocke(fp, 0.35, 2.0, 0.8, 0.09), 0.42 + 0.05 * k, 0.35)
    return ausblenden(hall(out, 0.2, 0.7, 0.35), 0.06)


@klang("ringRank8", "Acht · Trink-Duo", "Zwei Gläser stoßen an.")
def acht(rng):
    out = []
    for ab, f, laut in ((0.0, 2100.0, 1.0), (0.11, 2380.0, 0.75)):
        glas = additiv(f, 0.75, [(1.0, 1.0, 0.28), (2.32, 0.55, 0.14), (4.25, 0.3, 0.07), (6.63, 0.18, 0.04)])
        ruck = hochpass(impuls(0.01, rng, 0.0006), 3000)
        legen(glas, ruck, 0.0, 0.6)
        legen(out, glas, ab, laut)
    return ausblenden(hall(out, 0.2, 0.72, 0.45), 0.08)


@klang("ringRank9", "Neun · Reimen", "Vier Holztöne, zweimal dieselbe Wendung – sie reimen sich.")
def neun(rng):
    def marimba(f):
        ton = additiv(f, 0.45, [(1.0, 1.0, 0.16), (3.93, 0.25, 0.03), (9.0, 0.06, 0.01)])
        legen(ton, bandpass(impuls(0.01, rng, 0.0005), 3000, 1.5), 0.0, 0.15)
        return ton
    out = []
    for ab, f in ((0.0, 440.0), (0.14, 659.3), (0.36, 523.3), (0.5, 659.3)):
        legen(out, marimba(f), ab)
    return ausblenden(hall(out, 0.15, 0.65, 0.3), 0.05)


@klang("ringRank10", "Zehn · Zehn Gebote", "Der Hammer des Richters: leise, dann laut.")
def zehn(rng):
    def schlag():
        holz = resonator(impuls(0.22, rng, 0.0012), 260, 0.07)
        klack = bandpass(impuls(0.22, rng, 0.0015), 1000, 2.0)
        bauch = mal(sinus(lambda t: 95 - 30 * t, 0.22), huellkurve(n_von(0.22), 0.002, 0.05))
        return [0.7 * a + 0.8 * b + 0.6 * c for a, b, c in zip(holz, klack, bauch)]
    out = []
    legen(out, schlag(), 0.0, 0.45)
    legen(out, schlag(), 0.2, 1.0)
    return ausblenden(hall(out, 0.15, 0.6, 0.3), 0.05)


@klang("ringRank11", "Bube · Daumenmeister", "Ein Daumen drückt auf einen Knopf: Klick, dann ein kleines Pling.")
def bube(rng):
    out = resonator(hochpass(impuls(0.03, rng, 0.0005), 2000), 3200, 0.006)
    out = [v * 0.5 for v in out]
    pling = additiv(2093.0, 0.6, [(1.0, 1.0, 0.22), (2.0, 0.3, 0.1), (3.01, 0.12, 0.05)])
    legen(out, pling, 0.06, 0.8)
    return ausblenden(hall(out, 0.2, 0.7, 0.3), 0.05)


@klang("ringRank12", "Dame · Question Queen", "Eine Harfe streicht in acht Tönen nach oben.")
def dame(rng):
    out = []
    toene = (523.3, 587.3, 659.3, 784.0, 880.0, 1046.5, 1174.7, 1318.5)
    for k, f in enumerate(toene):
        legen(out, gezupft(f, 0.9, rng, 0.9965, 0.4), 0.045 * k, 0.7 + 0.04 * k)
    return ausblenden(hall(out, 0.3, 0.78, 0.6), 0.12)


@klang("ringRank13", "König · Kategorie", "Die Klingel der Quizshow: Ding-Ding.")
def koenig(rng):
    def ding():
        return additiv(1046.5, 0.7, [(1.0, 1.0, 0.3), (2.0, 0.5, 0.18), (3.0, 0.25, 0.1), (4.2, 0.15, 0.05)])
    out = []
    legen(out, ding(), 0.0)
    legen(out, ding(), 0.17)
    return ausblenden(hall(out, 0.2, 0.72, 0.4), 0.08)


@klang("ringRank14", "Ass · Shot", "Ein Schnapsglas knallt auf den Tisch, dann faucht eine Flamme auf.")
def ass(rng):
    out = []
    tisch = mal(sinus(lambda t: 75 - 20 * t, 0.15), huellkurve(n_von(0.15), 0.002, 0.035))
    knall = tiefpass(impuls(0.15, rng, 0.004), 1500)
    glas = additiv(4200.0, 0.12, [(1.0, 1.0, 0.03), (1.38, 0.6, 0.02)])
    legen(out, [a + 0.8 * b for a, b in zip(tisch, knall)], 0.0)
    legen(out, glas, 0.0, 0.3)
    sek = 0.6
    fauch = bandpass(rauschen(sek, rng), lambda t: 2800 * math.exp(-t / 0.18) + 500, 0.9)
    fauch = mal(fauch, [min(1, t / 0.06) * math.exp(-max(0, t - 0.06) / 0.16)
                        for t in (i / RATE for i in range(n_von(sek)))])
    legen(out, fauch, 0.12, 0.9)
    legen(out, knistern(0.6, rng, 60, 0.2), 0.14, 0.25)
    return ausblenden(hall(out, 0.15, 0.6, 0.3), 0.06)


@klang("ringTear", "Riss", "Ein trockenes Knacken, dann schlägt eine Stichflamme hoch und knistert nach.", 0.22)
def riss(rng):
    out = []
    # Das Knacken: ein harter Stoss, dahinter zwei Splitter
    for ab, laut in ((0.0, 1.0), (0.011, 0.55), (0.024, 0.35)):
        k = hochpass(impuls(0.04, rng, 0.0009), 1800)
        k = [a + 0.5 * b for a, b in zip(k, resonator(impuls(0.04, rng, 0.0004), 1900, 0.01))]
        legen(out, k, ab, laut)
    # Die Stichflamme: Rauschen, das hell aufreisst und dunkel ausklingt
    sek = 1.1
    flamme = tiefpass2(rauschen(sek, rng), lambda t: 300 + 1800 * math.exp(-((t - 0.07) / 0.11) ** 2) + 350 * math.exp(-t / 0.4))
    # Flammen flattern: unregelmaessig, zwischen acht und vierzehn Mal je Sekunde
    flattern = [0.7 + 0.3 * math.sin(TAU * 9 * t + 3 * math.sin(TAU * 2.3 * t)) for t in (i / RATE for i in range(n_von(sek)))]
    flamme = mal(flamme, [min(1, t / 0.04) * math.exp(-max(0, t - 0.04) / 0.26) * f
                          for t, f in zip((i / RATE for i in range(n_von(sek))), flattern)])
    legen(out, saettigen(normiert(flamme, 1.0), 1.4), 0.02, 0.85)
    grollen = mal(sinus(lambda t: 58 - 15 * t, 0.4), huellkurve(n_von(0.4), 0.01, 0.12))
    legen(out, grollen, 0.02, 0.5)
    legen(out, knistern(1.0, rng, 70, 0.3, 3000, 1.0), 0.1, 0.35)
    return ausblenden(hall(out, 0.12, 0.65, 0.35), 0.1)


@klang("ringShuffle", "Neu legen", "Ein Stapel wird gemischt: schnelles Flattern, zum Schluss klopft er auf den Tisch.", 0.09)
def mischen(rng):
    out = []
    t = 0.0
    for k in range(30):
        abstand = 0.012 + 0.02 * abs(math.cos(math.pi * k / 30))
        blatt = bandpass(impuls(0.025, rng, 0.003), rng.uniform(2200, 4200), 0.9)
        legen(out, blatt, t, rng.uniform(0.6, 1.0))
        t += abstand
    klopf = resonator(impuls(0.12, rng, 0.0015), 320, 0.03)
    legen(out, klopf, t + 0.06, 0.12)
    return ausblenden(hall(out, 0.1, 0.55, 0.2), 0.04)


@klang("ringHolds", "Hält knapp", "Die Glut knistert leise und hält – ein Durchatmen.", 0.06)
def haelt(rng):
    sek = 0.6
    out = knistern(sek, rng, 30, 0.25, 2600, 1.3)
    summen = [a + 0.5 * b for a, b in zip(sinus(110, sek), sinus(220.5, sek))]
    summen = mal(summen, [math.sin(math.pi * min(1, t / sek)) ** 2 for t in (i / RATE for i in range(n_von(sek)))])
    legen(out, tiefpass(summen, 600), 0.0, 0.5)
    return ausblenden(out, 0.08)


@klang("ringOut", "Regel durch", "Wasser auf Glut: ein langes Zischen, das leiser wird.", 0.11)
def aus(rng):
    sek = 1.5
    zisch = hochpass(rauschen(sek, rng), 2500)
    pfeif = bandpass(rauschen(sek, rng), lambda t: 5200 - 1400 * t / sek, 18)
    kurve = [min(1, t / 0.08) * math.exp(-max(0, t - 0.08) / 0.45) for t in (i / RATE for i in range(n_von(sek)))]
    out = mal([a + 2.5 * b for a, b in zip(zisch, pfeif)], kurve)
    legen(out, knistern(0.3, rng, 50, 0.1), 0.0, 0.4)
    return ausblenden(out, 0.15)


# ---------------------------------------------------------------- Schreiben

def schreiben(pfad, x):
    with wave.open(pfad, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in x))


def main():
    standard = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "Sounds")
    ziel = sys.argv[1] if len(sys.argv) > 1 else standard
    os.makedirs(ziel, exist_ok=True)
    saetze = [satz for _, _, satz, _, _ in KLAENGE]
    if len(set(saetze)) != len(saetze):
        raise SystemExit("Zwei Klaenge teilen sich einen Satz – dann sind es nicht zwei Klaenge")
    for datei, name, satz, fn, laut in KLAENGE:
        rng = random.Random(datei)
        x = angleichen(gleichanteil_weg(fn(rng)), laut)
        schreiben(os.path.join(ziel, datei + ".wav"), x)
        print(f"{datei:12s} {len(x) / RATE:5.2f} s  {name}")


if __name__ == "__main__":
    main()
