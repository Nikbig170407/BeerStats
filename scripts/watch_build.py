"""Wartet auf das Ende eines GitHub-Actions-Laufs und berichtet das Ergebnis.

    python scripts/watch_build.py             # der Lauf zum aktuellen HEAD
    python scripts/watch_build.py 31577161733 # ein bestimmter Lauf

Warum es das gibt: Das Repository ist oeffentlich, damit sind Laeufe ueber
die Actions-API ohne Anmeldung lesbar. Vorher musste bei jedem roten Build
jemand von Hand die Zeilen ab dem ersten "error:" aus der Weboberflaeche
kopieren. Jetzt sagt das Skript direkt, welcher SCHRITT gestolpert ist - und
das grenzt die Ursache meistens schon ein.

Die Wiederholversuche sind kein Beiwerk. Das Skript laeuft ueber eine
Viertelstunde, und ein einzelner DNS-Aussetzer hat schon einen kompletten
Lauf unbeobachtet zu Ende gehen lassen. Ein Beobachter, der bei der ersten
Stoerung aufgibt, ist genau dann nutzlos, wenn es darauf ankommt.

Eine Ausnahme davon ist die Ratengrenze: Ohne Anmeldung erlaubt GitHub nur
60 Anfragen pro Stunde und IP. Die loest sich zur vollen Stunde und nicht
durch Nachfragen - dort wird deshalb sofort aufgegeben, mit Uhrzeit.

Ist die Umgebungsvariable BEERSTATS_GH_TOKEN gesetzt, wird sie benutzt:
5000 Anfragen pro Stunde statt 60. Ohne sie laeuft alles weiter, nur
knapper. Der Token gehoert NICHT ins Repo - es ist oeffentlich.
"""

import http.client
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

REPO = "Nikbig170407/BeerStats"
# Anfragen sind knapp: ohne Anmeldung erlaubt GitHub 60 pro Stunde und IP.
# Ein Build dauert fuenf bis vierzehn Minuten - alle 30 Sekunden zu fragen
# hat das Kontingent verbrannt, ohne die Antwort frueher zu bekommen.
POLL_SECONDS = 90
MAX_MINUTES = 45
# Nach so vielen Fehlversuchen HINTEREINANDER wird aufgegeben. Zwischendurch
# geglueckte Abfragen setzen den Zaehler zurueck: Ein Netz, das mal kurz
# wegbricht, ist kein Grund zum Abbruch.
MAX_CONSECUTIVE_ERRORS = 8


class RateLimited(Exception):
    """Kontingent erschoepft. Neu versuchen hilft hier nicht."""


def api(path):
    url = f"https://api.github.com/repos/{REPO}/{path}"
    headers = {"User-Agent": "beerstats-watch"}

    # Optional. Ohne Token geht alles weiter, nur mit 60 Anfragen pro Stunde
    # statt 5000 - und nur die Schrittnamen statt der echten Fehlerzeilen.
    token = os.environ.get("BEERSTATS_GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"

    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        # 403 mit aufgebrauchtem Kontingent ist kein Netzfehler, sondern eine
        # Grenze mit Uhrzeit. Wiederholen verbraucht nur weitere Anfragen.
        if error.code in (403, 429) and error.headers.get("X-RateLimit-Remaining") == "0":
            reset = error.headers.get("X-RateLimit-Reset")
            wann = ""
            if reset and reset.isdigit():
                wann = time.strftime(" (frei ab %H:%M)", time.localtime(int(reset)))
            raise RateLimited(
                f"GitHub-Kontingent aufgebraucht{wann}. "
                "Mit gesetztem BEERSTATS_GH_TOKEN waeren es 5000 statt 60 Anfragen pro Stunde."
            ) from error
        raise


def api_with_retry(path):
    """Fragt die API ab und haelt Netzstoerungen aus.

    Gibt bei anhaltendem Fehler None zurueck, statt eine Ausnahme nach oben
    durchzureichen - der Aufrufer entscheidet, ob das das Ende ist.
    """
    delay = 5
    for _ in range(MAX_CONSECUTIVE_ERRORS):
        try:
            return api(path)
        except RateLimited as grenze:
            # Bewusst nicht wiederholen: Die Grenze loest sich zur vollen
            # Stunde, nicht durch Nachfragen.
            sys.exit(str(grenze))
        # Bewusst breit gefasst. Drei verschiedene Netzfehler haben dieses
        # Skript nacheinander umgebracht - DNS, SSL, und ein abgerissener
        # Verbindungsaufbau -, und nur der erste kam als URLError an. Welche
        # Ausnahme genau geflogen ist, aendert hier ohnehin nichts: Es wird
        # neu versucht. Nur ein Tippfehler im Skript soll durchschlagen, und
        # der waere kein OSError.
        except (OSError, http.client.HTTPException, json.JSONDecodeError) as error:
            print(f"  (Abfrage fehlgeschlagen: {error} - neuer Versuch in {delay}s)")
            time.sleep(delay)
            # Langsam laenger warten: Bei einer laengeren Stoerung bringt
            # schnelles Nachbohren nichts ausser Rauschen im Protokoll.
            delay = min(delay * 2, 60)
    return None


def head_sha():
    return subprocess.run(
        ["git", "rev-parse", "HEAD"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()


def run_id_for_head():
    """Sucht den Lauf zum aktuellen Commit – nicht einfach den neuesten.

    "Der neueste Lauf" war der falsche Ansatz: Die Liste kommt bei GitHub aus
    mehreren Repliken, und kurz nach einem Push liefert sie manchmal noch den
    Stand von davor. Das Skript hat dann den vorherigen Lauf beobachtet und
    dessen Ergebnis gemeldet - im schlimmsten Fall ein rotes, das laengst
    repariert war.

    Ueber die Commit-Kennung kann das nicht passieren: Entweder der Lauf ist
    da, oder es wird gewartet.
    """
    sha = head_sha()

    # Nach einem Push dauert es einen Moment, bis der Lauf angelegt ist.
    for _ in range(10):
        data = api_with_retry("actions/runs?per_page=15")
        if data:
            for run in data.get("workflow_runs", []):
                if run["head_sha"] == sha:
                    return str(run["id"])
        print(f"  (noch kein Lauf für {sha[:7]} – warte)")
        time.sleep(15)

    sys.exit(
        f"Kein Lauf für {sha[:7]} gefunden. Wurde gepusht? "
        "Änderungen nur an Markdown oder scripts/ lösen absichtlich keinen aus."
    )


def main():
    run_id = sys.argv[1] if len(sys.argv) > 1 else run_id_for_head()
    deadline = time.time() + MAX_MINUTES * 60

    run = None
    while time.time() < deadline:
        run = api_with_retry(f"actions/runs/{run_id}")
        if run is None:
            sys.exit("API dauerhaft nicht erreichbar - Lauf bleibt unbeobachtet")
        if run["status"] == "completed":
            break
        time.sleep(POLL_SECONDS)
    else:
        print(f"Zeitgrenze erreicht, Lauf laeuft noch: {run_id}")
        return

    print(f"ERGEBNIS: {run['conclusion'].upper()}   ({run['head_sha'][:7]})")
    print(run["html_url"])

    jobs = api_with_retry(f"actions/runs/{run_id}/jobs")
    if jobs is None:
        print("(Schritte nicht abrufbar)")
        return

    for job in jobs["jobs"]:
        print(f"\n=== {job['name']}: {job['conclusion']} ===")
        steps = job.get("steps", [])
        if not steps:
            # Genau dieses Bild bedeutet: Der Job wurde nie gestartet. Siehe
            # Lessons Learned Nr. 7 in CLAUDE.md.
            print("  KEINE SCHRITTE - Job wurde nie gestartet (Abrechnung? Kontingent?)")
        for step in steps:
            mark = "ok " if step["conclusion"] == "success" else ">> "
            print(f"  {mark}{str(step['conclusion']):<12} {step['name']}")


if __name__ == "__main__":
    main()
