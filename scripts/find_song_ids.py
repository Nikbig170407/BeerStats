"""Sucht zu jedem Lied der Hitparade seine Nummer im deutschen Apple-Katalog.

Aufruf:  python scripts/find_song_ids.py            (alle ohne Nummer)
         python scripts/find_song_ids.py --pause 15 (langsamer, falls Apple sperrt)

Warum es das gibt: Die Hitparade spielt jedes Lied als 30-Sekunden-Hoerprobe
von Apple ab, ohne Titel oder Cover zu zeigen. Dafuer braucht jedes Lied im
Stapel (`Features/PartyGames/Models/SongDeck.swift`) die Nummer, unter der
Apple es fuehrt (`appleId`). Ins Repository kommt nur diese Nummer, keine
Musik: Die Hoerprobe wird erst am Tisch geladen.

Was das Skript tut:
- Es sucht jedes Lied ohne Nummer ueber die oeffentliche Suche von Apple
  (kein Schluessel, kein Konto) im deutschen Katalog.
- Es nimmt nur Treffer, deren Titel und Interpret passen, und verwirft Live-,
  Remix-, Karaoke-, Cover- und Neuaufnahmen. Eine falsche Fassung ist am
  Tisch schlimmer als keine: Wer die Live-Version hoert, raet das Jahr des
  Konzerts.
- Unter den passenden Treffern gewinnt der, dessen Erscheinungsjahr dem Jahr
  im Stapel am naechsten liegt und der nicht auf einer Sammlung steht.
- Jede gefundene Nummer schreibt es sofort in SongDeck.swift. Ein
  abgebrochener Lauf macht also beim naechsten Aufruf dort weiter, wo er
  stand.
- Am Ende sagt es, was es nicht gefunden hat und wo Apples Jahr vom Stapel
  abweicht. Das Jahr im Stapel aendert es NIE selbst: Apple nennt oft das
  Jahr einer Neuauflage, und der Stapel ist von Hand geprueft.

Apple laesst nur langsame Anfragen zu und sperrt sonst fuer eine Weile
(HTTP 403). Deshalb die Pause zwischen den Anfragen und das Warten bei einer
Sperre. Nur Standardbibliothek.
"""

import argparse
import json
import os
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request

HIER = os.path.dirname(os.path.abspath(__file__))
STAPEL = os.path.join(HIER, "..", "Features", "PartyGames", "Models", "SongDeck.swift")

EINTRAG = re.compile(
    r'SongCard\(title: "(?P<title>(?:[^"\\]|\\.)*)", artist: "(?P<artist>(?:[^"\\]|\\.)*)", '
    r'year: (?P<year>\d+)(?:, appleId: (?P<id>\d+))?\)'
)

# Fassungen, die nicht das Original sind – es sei denn, der Titel im Stapel
# sagt es selbst
FALSCHE_FASSUNG = [
    r"\blive\b", r"\bremix", r"\bkaraoke\b", r"\binstrumental\b", r"\bacoustic\b", r"\bakustik",
    r"\bunplugged\b", r"\bcover\b", r"\btribute\b", r"re-?recorded", r"taylor.s version", r"\bdemo\b",
    r"in the style of", r"made famous", r"originally performed", r"\borchestral\b", r"\bsymphonic\b",
    r"piano version", r"sped up", r"\bslowed\b", r"nightcore", r"\bmashup\b", r"\bmedley\b", r"\breprise\b",
    r"\bextended\b", r"\bclub mix\b", r"\bvip\b", r"\blullaby\b",
    # Neu eingespielt fuer einen Anlass, etwa "Hips Don't Lie" zur WM 2006
    r"\bbamboo\b",
]
# Sammlungen: zur Not erlaubt, aber das Album oder die Single ist besser
SAMMLUNG = [r"best of", r"greatest", r"\bhits\b", r"collection", r"anthology", r"essential", r"\bgold\b",
            r"bravo", r"now that", r"kuschelrock", r"ballermann", r"\bparty\b", r"compilation", r"ultimate"]

# Wo Apple ein Lied anders fuehrt, als es am Tisch heisst. Der Stapel behaelt
# den Namen, den man kennt; gesucht und verglichen wird mit Apples Namen.
APPLE_TITEL = {
    ("Pink Floyd", "Another Brick in the Wall"): "Another Brick in the Wall, Pt. 2",
}


def normal(text):
    text = unicodedata.normalize("NFKD", text.lower())
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = text.replace("&", " and ").replace("ß", "ss")
    text = re.sub(r"[’'`´]", "", text)
    # Punkte in Abkuerzungen zaehlen nicht: "U.S.A." ist "USA"
    text = re.sub(r"(?<=[a-z0-9])\.(?=[a-z0-9])", "", text)
    text = re.sub(r"[^a-z0-9 ]+", " ", text)
    return " ".join(text.split())


def ohne_zusatz(text):
    """Titel ohne Klammern und ohne Anhang nach " - " (Remastered, Single Version ...)."""
    text = re.sub(r"\s*[\(\[][^\)\]]*[\)\]]", "", text)
    text = re.split(r"\s+-\s+", text)[0]
    return normal(text)


def haupt_interpret(text):
    teile = re.split(r"\s+(?:feat\.?|ft\.?|featuring|with|x|&|und|and)\s+|,", text, flags=re.I)
    # "The Black Eyed Peas" heisst bei Apple "Black Eyed Peas" – und umgekehrt
    return re.sub(r"^the ", "", normal(teile[0]))


def titel_passt(gesucht, gefunden):
    a, b = normal(gesucht), normal(gefunden)
    return a == b or ohne_zusatz(gesucht) == ohne_zusatz(gefunden) or a == ohne_zusatz(gefunden)


def falsche_fassung(gesucht, treffer):
    text = (treffer.get("trackName", "") + " " + treffer.get("collectionName", "")).lower()
    eigen = gesucht.lower()
    return any(re.search(m, text) and not re.search(m, eigen) for m in FALSCHE_FASSUNG)


def bewertung(lied, treffer):
    punkte = 0.0
    if normal(lied["title"]) == normal(treffer.get("trackName", "")):
        punkte += 3
    jahr = int((treffer.get("releaseDate") or "0000")[:4] or 0)
    abstand = abs(jahr - lied["year"])
    punkte += 4 if abstand == 0 else 2 if abstand == 1 else 0
    punkte -= 0.5 * min(10, abstand)
    sammlung = treffer.get("collectionName", "").lower()
    if any(re.search(m, sammlung) for m in SAMMLUNG):
        punkte -= 2
    if treffer.get("collectionArtistName", "").lower() == "various artists":
        punkte -= 3
    return punkte


def suche(begriff, pause):
    adresse = "https://itunes.apple.com/search?" + urllib.parse.urlencode(
        {"term": begriff, "entity": "song", "country": "de", "limit": 25})
    for versuch in range(6):
        try:
            with urllib.request.urlopen(adresse, timeout=30) as antwort:
                text = antwort.read().decode("utf-8").strip()
            if text:
                return json.loads(text).get("results", [])
            grund = "leere Antwort"
        except urllib.error.HTTPError as fehler:
            grund = f"HTTP {fehler.code}"
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as fehler:
            grund = str(fehler)
        warte = 60 * (versuch + 1)
        print(f"    Apple sperrt ({grund}) – warte {warte} s", flush=True)
        time.sleep(warte)
    raise SystemExit("Apple antwortet nicht mehr. Spaeter erneut starten – gefundene Nummern sind gespeichert.")


def finde(lied, pause):
    titel = APPLE_TITEL.get((lied["artist"], lied["title"]), lied["title"])
    begriffe = [f'{titel} {haupt_interpret(lied["artist"])}']
    kurz = re.sub(r"\s*\([^)]*\)", "", titel).strip()
    if kurz != titel:
        begriffe.append(f'{kurz} {haupt_interpret(lied["artist"])}')
    gesehen = []
    for begriff in begriffe:
        treffer = suche(begriff, pause)
        time.sleep(pause)
        gesehen += treffer
        passend = [
            t for t in treffer
            if t.get("previewUrl") and t.get("trackId")
            and titel_passt(titel, t.get("trackName", ""))
            and haupt_interpret(lied["artist"]) in normal(t.get("artistName", ""))
            and not falsche_fassung(titel, t)
        ]
        if passend:
            return max(passend, key=lambda t: bewertung(dict(lied, title=titel), t)), gesehen
    return None, gesehen


def main():
    teil = argparse.ArgumentParser()
    teil.add_argument("--pause", type=float, default=13, help="Sekunden zwischen zwei Anfragen")
    optionen = teil.parse_args()

    with open(STAPEL, encoding="utf-8") as f:
        quelle = f.read()
    offen = [m.groupdict() for m in EINTRAG.finditer(quelle) if not m.group("id")]
    for lied in offen:
        lied["year"] = int(lied["year"])
    print(f"{len(offen)} Lieder ohne Nummer", flush=True)

    fehlt, abweichend = [], []
    for nummer, lied in enumerate(offen, 1):
        treffer, gesehen = finde(lied, optionen.pause)
        name = f'{lied["artist"]} – {lied["title"]} ({lied["year"]})'
        if not treffer:
            fehlt.append(name)
            print(f"[{nummer}/{len(offen)}] NICHT GEFUNDEN  {name}", flush=True)
            # Was Apple stattdessen hatte – daran sieht man, ob das Lied
            # fehlt oder nur anders heisst (dann gehoert es in APPLE_TITEL)
            for t in gesehen[:6]:
                print(f'      {t.get("trackName", "")} | {t.get("artistName", "")} | '
                      f'{t.get("collectionName", "")} | {(t.get("releaseDate") or "")[:4]}', flush=True)
            continue
        jahr = int((treffer.get("releaseDate") or "0")[:4] or 0)
        if jahr != lied["year"]:
            abweichend.append(f'{name}: Apple nennt {jahr} ({treffer.get("collectionName", "")})')
        print(f'[{nummer}/{len(offen)}] {treffer["trackId"]}  {name}  ->  '
              f'{treffer["trackName"]} | {treffer["artistName"]} | {treffer.get("collectionName", "")} | {jahr}',
              flush=True)

        # Sofort speichern, damit ein Abbruch nichts kostet
        alt = (f'SongCard(title: "{lied["title"]}", artist: "{lied["artist"]}", year: {lied["year"]})')
        neu = alt[:-1] + f', appleId: {treffer["trackId"]})'
        with open(STAPEL, encoding="utf-8") as f:
            quelle = f.read()
        if quelle.count(alt) != 1:
            raise SystemExit(f"Eintrag nicht eindeutig: {alt}")
        with open(STAPEL, "w", encoding="utf-8") as f:
            f.write(quelle.replace(alt, neu))

    print("\nNicht gefunden:" if fehlt else "\nAlle gefunden.")
    for name in fehlt:
        print("  " + name)
    if abweichend:
        print("\nApple nennt ein anderes Jahr (nur zur Pruefung, nichts geaendert):")
        for zeile in abweichend:
            print("  " + zeile)


if __name__ == "__main__":
    main()
