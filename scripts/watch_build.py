"""Wartet auf das Ende eines GitHub-Actions-Laufs und berichtet das Ergebnis.

    python scripts/watch_build.py            # neuester Lauf auf main
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
"""

import http.client
import json
import sys
import time
import urllib.error
import urllib.request

REPO = "Nikbig170407/BeerStats"
POLL_SECONDS = 30
MAX_MINUTES = 45
# Nach so vielen Fehlversuchen HINTEREINANDER wird aufgegeben. Zwischendurch
# geglueckte Abfragen setzen den Zaehler zurueck: Ein Netz, das mal kurz
# wegbricht, ist kein Grund zum Abbruch.
MAX_CONSECUTIVE_ERRORS = 8


def api(path):
    url = f"https://api.github.com/repos/{REPO}/{path}"
    request = urllib.request.Request(url, headers={"User-Agent": "beerstats-watch"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def api_with_retry(path):
    """Fragt die API ab und haelt Netzstoerungen aus.

    Gibt bei anhaltendem Fehler None zurueck, statt eine Ausnahme nach oben
    durchzureichen - der Aufrufer entscheidet, ob das das Ende ist.
    """
    delay = 5
    for _ in range(MAX_CONSECUTIVE_ERRORS):
        try:
            return api(path)
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


def latest_run_id():
    data = api_with_retry("actions/runs?per_page=1")
    if not data or not data.get("workflow_runs"):
        sys.exit("kein Lauf gefunden")
    return str(data["workflow_runs"][0]["id"])


def main():
    run_id = sys.argv[1] if len(sys.argv) > 1 else latest_run_id()
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
