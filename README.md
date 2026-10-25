# BeerStats – Setup ohne Mac (Cloud-Build + Sideloadly)

Diese Anleitung bringt den Code aus diesem Ordner auf dein iPhone – **ganz
ohne eigenen oder gemieteten Mac**, kostenlos, ausschließlich für dein
privates Gerät (kein App Store).

## Prinzip
```
Code (dieser Ordner)  →  GitHub Repository  →  GitHub Actions (Cloud-Mac,
automatisch)  →  unsignierte .ipa-Datei zum Download  →  Sideloadly auf
deinem PC signiert sie mit deiner Apple-ID  →  Installation per USB auf
dein iPhone
```

## Einmalige Einrichtung

### 1. GitHub-Repository anlegen
1. Auf [github.com](https://github.com) einloggen → oben rechts „+“ → „New repository“
2. Name: `BeerStats` → **Private** auswählen (empfohlen, da `GoogleService-Info.plist` sonst öffentlich einsehbar wäre)
3. „Create repository“ – noch nichts anhaken (kein README etc.), leeres Repo reicht

### 2. Diesen Ordner ins Repository hochladen
Am einfachsten über die GitHub-Weboberfläche (kein Git-Kommandozeilen-Wissen nötig):
1. Im neuen, leeren Repository auf „uploading an existing file“ klicken
2. Alle Dateien und Ordner aus diesem Archiv hineinziehen (den kompletten Inhalt, inkl. `.github`-Ordner – falls der nicht angezeigt wird, weil er mit einem Punkt beginnt: im Datei-Explorer versteckte Dateien einblenden)
3. „Commit changes“

*(Falls du später öfter Änderungen hochladen willst, lohnt sich [GitHub Desktop](https://desktop.github.com) – eine grafische Oberfläche ohne Kommandozeile.)*

### 3. Firebase-Konfigurationsdatei ergänzen
Die Datei `GoogleService-Info.plist` (aus der Firebase Console, siehe vorheriger Schritt) muss noch in `BeerStats/Resources/` landen – im Repository per „Add file“ → „Upload files“ in genau diesen Ordner hochladen.

### 4. Build automatisch anstoßen
Sobald Punkt 2–3 erledigt sind, startet GitHub Actions **automatisch** (wegen `on: push` im Workflow). Zum Prüfen:
1. Im Repository oben auf den Reiter „Actions“ klicken
2. Der Lauf „Build BeerStats (unsigned IPA)“ sollte erscheinen (gelber Punkt = läuft, grüner Haken = fertig, ca. 5–10 Minuten)
3. Falls rot/fehlgeschlagen: auf den Lauf klicken → den fehlgeschlagenen Schritt aufklappen → Fehlertext mir schicken

### 5. IPA herunterladen
1. Im fertigen (grünen) Workflow-Lauf ganz unten bei „Artifacts“ auf `BeerStats-ipa` klicken → lädt eine ZIP-Datei herunter
2. Entpacken → `BeerStats.ipa` kommt raus

### 6. Mit Sideloadly installieren
1. [Sideloadly](https://sideloadly.io) herunterladen und installieren (Windows)
2. iPhone per USB-Kabel mit dem PC verbinden, entsperren, „Diesem Computer vertrauen“ bestätigen
3. Sideloadly öffnen → dein iPhone sollte oben erscheinen
4. Die `BeerStats.ipa`-Datei in das Sideloadly-Fenster ziehen
5. Deine Apple-ID und Passwort eingeben (wird nur lokal auf deinem PC verwendet, um die App für dein Gerät zu signieren – nicht Teil von GitHub)
6. „Start“ klicken → Sideloadly signiert und installiert die App auf deinem iPhone

### 7. App auf dem iPhone freigeben
Erstes Öffnen der App: iOS blockiert unbekannte Entwickler standardmäßig.
- Einstellungen → Allgemein → VPN & Geräteverwaltung → deine Apple-ID auswählen → „Vertrauen“ bestätigen

**Wichtig – 7-Tage-Grenze:** Mit einer kostenlosen Apple-ID läuft die Signatur nach 7 Tagen ab, die App verschwindet dann vom Home-Bildschirm bzw. lässt sich nicht mehr öffnen. Einfach Schritt 6 wiederholen (iPhone anschließen, in Sideloadly erneut „Start“) – dauert dann nur 1 Minute, da die IPA schon vorhanden ist.

## Firestore-Regeln & Indexes einrichten (Schritt 3)

Damit niemand außer dir selbst (bzw. den jeweiligen Mitspielern) deine
Daten lesen oder verändern kann, und damit die App-Abfragen performant
bleiben, müssen zwei Dateien in dein Firebase-Projekt übertragen werden –
das geht komplett ohne Kommandozeile über die Firebase Console:

### 1. Security Rules einspielen
1. In der [Firebase Console](https://console.firebase.google.com) → dein Projekt → „Firestore Database“ → Reiter **„Rules“**
2. Den kompletten Inhalt der Datei `firestore.rules` (aus diesem Ordner) kopieren
3. Den vorhandenen Text im Rules-Editor der Console komplett ersetzen
4. „Publish“ klicken

### 2. Composite Indexes anlegen
Zwei Möglichkeiten:
- **Einfacher:** Die Indexes müssen nicht sofort angelegt werden – sobald wir später eine Abfrage bauen, die einen fehlenden Index braucht, gibt Firestore in der Fehlermeldung einen direkten Link aus, der den passenden Index automatisch mit einem Klick anlegt. Das reicht für den Moment völlig aus.
- **Vorausschauend:** Firebase Console → „Firestore Database“ → Reiter **„Indexes“** → „Composite“ → „Add Index“ → die Felder aus `firestore.indexes.json` manuell eintragen (3 Indexes, siehe Datei).

Für den Anfang reicht Option 1 – wir kommen darauf zurück, sobald es in Schritt 5/6 relevant wird.

## Ab jetzt: laufender Ablauf bei jeder Code-Änderung
1. Ich baue neue Features als Dateien
2. Du lädst die geänderten/neuen Dateien im Repository hoch (oder ich sage dir genau, welche Datei sich ändert)
3. GitHub Actions baut automatisch neu (Reiter „Actions“ beobachten)
4. Neue `.ipa` herunterladen → mit Sideloadly erneut installieren

## Falls Sideloadly nicht startet

Fehlermeldung: **„Der Prozedureinsprungpunkt `PyInit_sideloadly_wrap` wurde
in der DLL `…\Sideloadly\sideloadly.exe` nicht gefunden."**

Sideloadly ist ein Python-Programm; die Meldung heißt, dass ein
mitgeliefertes Hilfsmodul (`sideloadly_wrap.pyd`) nicht zur `sideloadly.exe`
passt. Zwei Ursachen, und die zweite ist die, wegen der es **wiederkommt**:

1. Reste einer alten Version – der Installer überschreibt den Ordner, löscht
   aber nicht.
2. **Der Virenscanner.** Windows Defender erkennt Sideloadly regelmäßig
   falsch-positiv (es signiert fremde Apps) und nimmt die `.pyd` in
   Quarantäne. Danach fehlt genau dieser Einsprungpunkt – nach *jeder*
   Neuinstallation wieder.

Deshalb in dieser Reihenfolge:

1. Windows-Sicherheit → Viren- & Bedrohungsschutz → **Schutzverlauf**: Steht
   dort etwas mit Sideloadly? → **Zulassen/Wiederherstellen**
2. Dort unter *Einstellungen verwalten → Ausschlüsse* den Ordner
   `%LocalAppData%\Sideloadly` ausschließen. Ohne diesen Schritt war der
   Rest umsonst.
3. Sideloadly deinstallieren, dann im Explorer über `%LocalAppData%` den
   Ordner **`Sideloadly` ganz löschen** (Drüberinstallieren reicht nicht).
4. Neustart, 64-bit-Version neu laden, als Administrator installieren.

**Als Skript:** `scripts/fix-sideloadly.ps1` macht die Schritte 1 bis 4 in
der richtigen Reihenfolge. PowerShell **als Administrator** öffnen (der
Defender-Ausschluss geht nicht ohne), dann:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\fix-sideloadly.ps1
```

Kommt es ein drittes Mal: **AltStore/SideStore** statt Sideloadly. Der
AltServer signiert die App automatisch über WLAN nach, bevor die 7 Tage
ablaufen – damit entfällt auch das wöchentliche Kabelsuchen.

## Falls der Build fehlschlägt
Am häufigsten:
- `GoogleService-Info.plist` fehlt oder liegt im falschen Ordner
- Tippfehler beim Hochladen einzelner Dateien

Schick mir in diesem Fall einfach den roten Fehlertext aus dem „Actions“-Tab, dann beheben wir das gemeinsam.

## Nächster Schritt
Wir testen diese komplette Kette jetzt einmal mit dem aktuellen Grundgerüst
(Schritt 1). Sobald die App auf deinem iPhone startet und "Onboarding folgt
in Schritt 4" anzeigt, wissen wir: die komplette Kette funktioniert – und
wir gehen weiter zu **Schritt 2: Datenmodelle**.
