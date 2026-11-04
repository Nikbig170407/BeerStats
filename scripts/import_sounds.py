"""Holt Klaenge aus CC0-Paketen in die App und schreibt ihre Herkunft auf.

    python scripts/import_sounds.py PAKETORDNER

PAKETORDNER enthaelt die ausgepackten Pakete, egal wie tief: Gesucht wird
jede Datei unter ihrem Namen. Die Pakete selbst liegen NICHT im Repository –
nur das, was die App davon braucht, umgewandelt und angeglichen.

Seit dem 4. November, auf Wunsch des Nutzers ("mehr Sounds"). Bis dahin
kamen neue Klaenge nur aus `make_sounds.py`, weil ein gerechneter Klang keine
Lizenz hat. CC0 hat auch keine, die man im Blick behalten muesste – deshalb
sind solche Pakete jetzt erlaubt, und nur solche. Was hier steht, ist in
`Resources/Sounds/HERKUNFT.md` mit Paket und Lizenz vermerkt; `check.py`
meldet jede Klangdatei, die dort fehlt.

Was das Skript mit jeder Datei tut:
- **umwandeln** (ffmpeg): Die Pakete liefern Ogg, das spielt iOS nicht ab.
  Geschrieben wird WAV, mono, 44,1 kHz – kein AAC, weil der Coder vorne
  Stille anhaengt und ein Klick dann spuerbar zu spaet kommt.
- **Stille abschneiden**, vorne und hinten.
- **angleichen** mit derselben Rechnung wie die gerechneten Klaenge
  (`make_sounds.angleichen`): Am Tisch zaehlt, wie laut etwas wirkt, und
  nicht die Spitze.
- **Fassungen**: Hat ein Klang mehrere Dateien, heisst die erste wie der
  Fall in `GameSound`, die weiteren tragen eine Nummer (`cardFlip2`). Die
  App spielt sie reihum (`GameSound.variants`).

Satz-Regel wie ueberall: Jeder Klang hat einen Satz, und keiner kommt
zweimal vor – auch nicht zwischen diesem Skript und `make_sounds.py`.
"""
import os
import struct
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_sounds as werkzeug  # noqa: E402

CC0 = "CC0 1.0 (creativecommons.org/publicdomain/zero/1.0)"

# Was aus den Paketen kommt. Die Auswahl ist gemessen, nicht gehoert:
# Laenge, Lautheit und – bei Toenen – ob die Tonhoehe steigt oder faellt.
# "Richtig" und der Jingle steigen, "falsch" bleibt tief und kurz. Wer am
# Geraet etwas anderes hoeren will, tauscht hier die Datei und laesst das
# Skript laufen.
IMPORTE = [
    {
        "name": "cardFlip",
        "paket": "Casino Audio (Kenney)",
        "dateien": ["card-place-1.ogg", "card-place-2.ogg", "card-place-3.ogg", "card-place-4.ogg"],
        "satz": "Eine Karte gleitet über den Filz und bleibt liegen.",
        "laut": 0.1,
    },
    {
        "name": "diceRoll",
        "paket": "Casino Audio (Kenney)",
        "dateien": ["dice-throw-1.ogg", "dice-throw-2.ogg", "dice-throw-3.ogg"],
        "satz": "Würfel kullern über den Tisch und bleiben liegen.",
        "laut": 0.11,
    },
    {
        "name": "chips",
        "paket": "Casino Audio (Kenney)",
        "dateien": ["chip-lay-1.ogg", "chip-lay-2.ogg", "chip-lay-3.ogg"],
        "satz": "Ein Chip klackt auf den Tisch.",
        "laut": 0.09,
    },
    {
        "name": "correct",
        "paket": "Interface Sounds (Kenney)",
        "dateien": ["confirmation_001.ogg"],
        "satz": "Zwei helle Töne steigen auf: richtig.",
        "laut": 0.1,
    },
    {
        "name": "wrong",
        "paket": "Interface Sounds (Kenney)",
        "dateien": ["error_008.ogg"],
        "satz": "Ein kurzes, tiefes Brummen: falsch.",
        "laut": 0.09,
    },
    {
        "name": "countdownTick",
        "paket": "Interface Sounds (Kenney)",
        "dateien": ["tick_004.ogg"],
        "satz": "Ein knappes Ticken wie von einer Wanduhr.",
        "laut": 0.06,
    },
    {
        "name": "roundWon",
        "paket": "Music Jingles (Kenney)",
        "dateien": ["jingles_PIZZI16.ogg"],
        "satz": "Gezupfte Saiten laufen fröhlich nach oben.",
        "laut": 0.11,
    },
]

# Was schon vorher da war und nicht aus einem der beiden Skripte kommt.
# Steht hier, damit HERKUNFT.md vollstaendig ist und nicht von Hand gepflegt
# werden muss.
BESTAND = [
    ("cupHit.mp3", "Mixkit", "Mixkit Sound Effects Free License"),
    ("miss.mp3", "Mixkit", "Mixkit Sound Effects Free License"),
    ("ballsBack.mp3", "Mixkit", "Mixkit Sound Effects Free License"),
    ("onFire.mp3", "Mixkit", "Mixkit Sound Effects Free License"),
    ("reRack.mp3", "Mixkit", "Mixkit Sound Effects Free License"),
    ("victory.mp3", "Mixkit", "Mixkit Sound Effects Free License"),
    ("tap.mp3", "Mixkit", "Mixkit Sound Effects Free License"),
    ("airball.mp3", "eigener Ausschnitt", "vor dem 28. Oktober eingebaut, siehe git log"),
    ("bombe.wav", "selbst erzeugt", "vor dem 28. Oktober gerechnet, das Skript dazu steht nicht im Repository"),
]

STILLE = 10 ** (-50 / 20)  # -50 dBFS


def dateiname(name, nummer):
    return name if nummer == 0 else f"{name}{nummer + 1}"


def finden(paketordner, datei):
    for wurzel, _, dateien in os.walk(paketordner):
        if datei in dateien:
            return os.path.join(wurzel, datei)
    raise SystemExit(f"{datei} liegt in keinem der Pakete unter {paketordner}")


def laden(pfad):
    roh = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", pfad, "-ac", "1", "-ar", str(werkzeug.RATE), "-f", "s16le", "-"],
        capture_output=True, check=True,
    ).stdout
    werte = struct.unpack(f"<{len(roh) // 2}h", roh)
    return [v / 32768 for v in werte]


def stille_weg(x):
    anfang = next((i for i, v in enumerate(x) if abs(v) > STILLE), 0)
    ende = next((i for i in range(len(x) - 1, -1, -1) if abs(x[i]) > STILLE), len(x) - 1)
    # Ein paar Millisekunden Luft hinten, sonst klingt das Ausklingen abgehackt
    return x[anfang:min(len(x), ende + werkzeug.n_von(0.02))]


def herkunft_schreiben(ziel):
    zeilen = [
        "# Herkunft der Klänge",
        "",
        "Erzeugt von `scripts/import_sounds.py` – nicht von Hand ändern, der",
        "nächste Lauf überschreibt die Datei. `scripts/check.py` meldet jede",
        "Klangdatei in diesem Ordner, die hier fehlt.",
        "",
        "Neue Klänge kommen nur aus zwei Quellen: gerechnet (`scripts/make_sounds.py`)",
        "oder aus einem CC0-Paket (`scripts/import_sounds.py`). Das Repository ist",
        "öffentlich, und eine fremde Lizenz müsste man im Blick behalten.",
        "",
        "| Datei | Herkunft | Lizenz |",
        "|---|---|---|",
    ]
    for datei, quelle, lizenz in BESTAND:
        zeilen.append(f"| `{datei}` | {quelle} | {lizenz} |")
    for datei, name, satz, _, _ in werkzeug.KLAENGE:
        zeilen.append(f"| `{datei}.wav` | gerechnet: {name} – {satz} | keine (selbst gerechnet) |")
    for eintrag in IMPORTE:
        for nummer, quelle in enumerate(eintrag["dateien"]):
            zeilen.append(
                f"| `{dateiname(eintrag['name'], nummer)}.wav` | {eintrag['paket']}: `{quelle}` – {eintrag['satz']} | {CC0} |"
            )
    zeilen += ["", "Kenney-Pakete: www.kenney.nl – Nennung nicht verlangt, aber verdient.", ""]
    with open(os.path.join(ziel, "HERKUNFT.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(zeilen))


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    paketordner = sys.argv[1]
    ziel = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "Sounds")
    werkzeug.pruefe_saetze()
    for eintrag in IMPORTE:
        for nummer, datei in enumerate(eintrag["dateien"]):
            x = stille_weg(laden(finden(paketordner, datei)))
            x = werkzeug.ausblenden(werkzeug.angleichen(werkzeug.gleichanteil_weg(x), eintrag["laut"]), 0.01)
            name = dateiname(eintrag["name"], nummer)
            werkzeug.schreiben(os.path.join(ziel, name + ".wav"), x)
            print(f"{name:14s} {len(x) / werkzeug.RATE:5.2f} s  aus {datei}")
    herkunft_schreiben(ziel)
    print("HERKUNFT.md geschrieben")


if __name__ == "__main__":
    main()
