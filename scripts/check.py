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
  5. Ein eigener Typ, der einen SwiftUI-Typ verdeckt, und ein Aufruf, der
     trotzdem SwiftUI meint. Bis zum 29. Oktober hiess der Screen des
     Musikspiels `TimelineView` - `TimelineView(.animation)` rief also den
     Screen auf, und der Lauf scheiterte mit "argument passed to call that
     takes no arguments" (Lessons Learned Nr. 15).
  6. Ein `map`, dessen Closure in einem Ausdruck ein Paar aus Tupeln baut –
     `.map { k in ((x, 0), (x, h)) }`. Lauter Zahlenliterale, deren Typ erst
     aus dem Ziel folgt: Der Compiler probiert jede Kombination durch und
     gibt mit "unable to type-check this expression in reasonable time" auf
     (Lauf 165, Lessons Learned Nr. 16). Eine Schleife mit benannten Punkten
     hat das Problem nicht.

Rueckgabewert 1, wenn etwas gefunden wurde - damit es sich in eine
Befehlskette haengen laesst.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Verzeichnisse, die zwar Swift enthalten, aber nicht zu diesem Projektstand
# gehoeren. `.claude/worktrees` ist der wichtigste Fall: Dort liegt eine
# vollstaendige Kopie des Projekts, wenn eine Aufgabe nebenher in einem
# eigenen Arbeitsbaum laeuft. Ohne diese Liste meldet der Pruefer jede Datei
# darin als "liegt in keinem Quellordner" - 135 Fehlalarme auf einmal, und
# der echte Befund geht darin unter.
IGNORIERT = {".claude", ".git", ".build", "DerivedData", "Pods", "build", "Payload"}

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
    # Genau nach diesen greift man beim Gestalten – und sie sind alle neuer
    # als das Deployment-Target (Spielwelten, 28. Oktober).
    "KeyframeAnimator",
    ".keyframeAnimator",
    ".phaseAnimator",
    ".visualEffect",
    ".scrollTransition",
    ".sensoryFeedback",
    ".colorEffect",
    ".layerEffect",
    ".distortionEffect",
    "numericText(value:",
    "TextRenderer",
    # Liegt nahe, sobald ein Rueckruf auf dem Hauptfaden laeuft, aber nicht
    # als solcher markiert ist (Hoerprobe der Hitparade, 29. Oktober)
    "assumeIsolated",
]


# SwiftUI-Typen, die ein eigener Typ leicht verdecken kann. Gemeldet wird
# nicht die Verdeckung selbst (ein Name ist kein Fehler), sondern
# ein Aufruf mit einem Argument, das mit einem Punkt beginnt - so sieht ein
# SwiftUI-Aufruf aus (`TimelineView(.animation)`), ein eigener Screen nicht.
SWIFTUI_TYPEN = {
    "TimelineView", "Canvas", "Label", "Text", "Image", "Button", "Group",
    "Section", "Color", "Font", "Gradient", "Path", "Circle", "Capsule",
    "Toggle", "Picker", "Slider", "Link", "Menu", "Form", "List", "Grid",
    "Table", "Spacer", "Divider", "Animation", "ScrollView", "TabView",
}


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
    dateien = []

    for path in swift_files():
        rel = path.relative_to(ROOT)
        text = path.read_text(encoding="utf-8")
        code, offene = strip_code(text)
        dateien.append((rel, code))

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

    # Eigene Typen, die einen SwiftUI-Namen tragen, und Aufrufe, die trotzdem
    # SwiftUI meinen. Voll ausgeschrieben (`SwiftUI.TimelineView`) ist es gut.
    eigene = set()
    for _, code in dateien:
        eigene.update(re.findall(r"\b(?:struct|class|enum|actor|typealias|protocol)\s+([A-Z]\w*)", code))
    for name in sorted(eigene & SWIFTUI_TYPEN):
        muster = re.compile(r"(?<![\w.])" + name + r"\s*\(\s*\.")
        for rel, code in dateien:
            for treffer in muster.finditer(code):
                zeile = code[:treffer.start()].count("\n") + 1
                funde.append(
                    f"{rel}:{zeile}  {name}(.…) meint vermutlich SwiftUI.{name} - "
                    f"ein eigener Typ im Projekt verdeckt den Namen"
                )

    # Tupel aus Tupeln in einer einzeiligen map-Closure: Daran hat sich der
    # Typpruefer zweimal festgerechnet, und das sieht man erst nach Minuten.
    tupel_map = re.compile(r"\.map\s*\{\s*\w+\s+in\s*\(\s*\(")
    for rel, code in dateien:
        for treffer in tupel_map.finditer(code):
            zeile = code[:treffer.start()].count("\n") + 1
            funde.append(
                f"{rel}:{zeile}  map-Closure baut ein Tupel aus Tupeln - "
                f"als Schleife mit benannten Punkten schreiben"
            )

    # Dateien, die in keinem Quellordner liegen, werden nie uebersetzt - der
    # Build bleibt gruen und die Aenderung wirkt trotzdem nicht.
    bekannt = {p.resolve() for p in swift_files()}
    for path in ROOT.rglob("*.swift"):
        if IGNORIERT & set(path.parts):
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
