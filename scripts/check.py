"""Prueft den Swift-Code, bevor er gepusht wird.

    python scripts/check.py

Ersetzt das, was bisher vor jedem Push von Hand zusammengetippt wurde. Der
Anlass steht in CLAUDE.md: Hier laesst sich kein Swift uebersetzen, die
einzige echte Pruefung ist der Actions-Lauf, und der dauert zehn Minuten.
Was in Sekunden auffallen kann, sollte nicht dort auffallen.

Das hier ist KEIN Compiler und will keiner sein. Es findet die Handvoll
Fehler, die in diesem Projekt tatsaechlich vorgekommen sind:

  1. Unausgeglichene Klammern - der Klassiker beim Umbauen von Views.
  2. Ein Literal, das mitten im Satz endet, weil ein deutsches
     Anfuehrungszeichen mit einem ASCII-Quote geschlossen wurde. Das hat
     einmal den ganzen Build lahmgelegt (Lessons Learned Nr. 3).
  3. APIs, die es erst ab iOS 17 gibt - das Deployment-Target ist 16.
  4. Swift-Dateien, die in keinem Quellordner aus project.yml liegen und
     deshalb stillschweigend gar nicht uebersetzt werden.

Rueckgabewert 1, wenn etwas gefunden wurde - damit es sich in eine
Befehlskette haengen laesst.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Muss zu den `sources`-Eintraegen in project.yml passen.
SOURCE_DIRS = [
    "App", "Core", "DesignSystem", "Features", "Models",
    "Repositories", "Services", "Resources", "Tests", "Widgets",
]

# Symbole, die es unter iOS 16 nicht gibt. Bewusst kurz gehalten: Lieber
# wenige sichere Treffer als eine lange Liste mit Fehlalarmen, die nach dem
# dritten Mal ignoriert wird.
IOS17_ONLY = [
    "ContentUnavailableView",
    "@Observable",
    "scrollTargetBehavior",
    "containerRelativeFrame",
    "symbolEffect",
    "PhaseAnimator",
    "MeshGradient",
    "onChange(of:initial:",
]


def swift_files():
    for directory in SOURCE_DIRS:
        yield from (ROOT / directory).rglob("*.swift")


def strip_code(text):
    """Entfernt Kommentare und Zeichenketten und meldet offene Literale.

    Gibt den bereinigten Text zurueck plus die Zeilennummern, in denen eine
    einzeilige Zeichenkette nicht geschlossen wurde. Nur auf dem bereinigten
    Text darf man Klammern zaehlen - eine geschweifte Klammer in einem
    Kommentar oder in einem Text zaehlt sonst mit.
    """
    out = []
    offene = []
    i, line, n = 0, 1, len(text)

    while i < n:
        ch = text[i]

        if ch == "\n":
            line += 1
            out.append("\n")
            i += 1
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
        elif text.startswith("/*", i):
            i += 2
            while i < n and not text.startswith("*/", i):
                if text[i] == "\n":
                    line += 1
                i += 1
            i += 2
        elif text.startswith('"""', i):
            i += 3
            while i < n and not text.startswith('"""', i):
                if text[i] == "\n":
                    line += 1
                i += 1
            i += 3
        elif ch == '"':
            start = line
            i += 1
            geschlossen = False
            while i < n:
                if text[i] == "\\":
                    # Interpolation bringt echten Code mit - dessen Klammern
                    # muessen mitgezaehlt werden, sonst meldet der Zaehler
                    # jede Zeile mit \(...) als unausgeglichen.
                    if text.startswith("\\(", i):
                        tiefe, i = 0, i + 1
                        while i < n:
                            if text[i] == "(":
                                tiefe += 1
                            elif text[i] == ")":
                                tiefe -= 1
                                if tiefe == 0:
                                    i += 1
                                    break
                            i += 1
                        continue
                    i += 2
                    continue
                if text[i] == '"':
                    i += 1
                    geschlossen = True
                    break
                if text[i] == "\n":
                    break
                i += 1
            if not geschlossen:
                offene.append(start)
        else:
            out.append(ch)
            i += 1

    return "".join(out), offene


def main():
    funde = []

    for path in swift_files():
        rel = path.relative_to(ROOT)
        text = path.read_text(encoding="utf-8")
        code, offene = strip_code(text)

        for zeile in offene:
            funde.append(f"{rel}:{zeile}  Zeichenkette wird nicht geschlossen")

        for auf, zu, name in (("{", "}", "geschweifte"), ("(", ")", "runde"), ("[", "]", "eckige")):
            if code.count(auf) != code.count(zu):
                funde.append(
                    f"{rel}  {name} Klammern: {code.count(auf)} auf, {code.count(zu)} zu"
                )

        for symbol in IOS17_ONLY:
            for treffer in re.finditer(re.escape(symbol), code):
                zeile = code[:treffer.start()].count("\n") + 1
                funde.append(f"{rel}:{zeile}  {symbol} gibt es erst ab iOS 17")

    # Dateien, die in keinem Quellordner liegen, werden nie uebersetzt - der
    # Build bleibt gruen und die Aenderung wirkt trotzdem nicht.
    bekannt = {p.resolve() for p in swift_files()}
    for path in ROOT.rglob("*.swift"):
        if ".build" in path.parts or "DerivedData" in path.parts:
            continue
        if path.resolve() not in bekannt:
            funde.append(f"{path.relative_to(ROOT)}  liegt in keinem Quellordner aus project.yml")

    if funde:
        print(f"{len(funde)} Auffaelligkeit(en):\n")
        for fund in funde:
            print("  " + fund)
        return 1

    anzahl = sum(1 for _ in swift_files())
    print(f"{anzahl} Swift-Dateien geprueft, nichts gefunden.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
