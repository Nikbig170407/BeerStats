# CLAUDE.md – Projektkontext für BeerStats

Diese Datei ist die Einstiegshilfe für eine neue Claude-Sitzung. Bei
Widersprüchen gilt: **Der Code im Repository hat Vorrang.** Die
Begründungen hier sind aber bewusst getroffene Entscheidungen und sollten
nicht ohne Rücksprache umgeworfen werden.

Ausführliche Begründungen zu einzelnen Änderungen stehen in den
Commit-Nachrichten – `git log` ist das eigentliche Gedächtnis des Projekts.

---

## 1. Projektüberblick

**BeerStats** ist eine iOS-App (SwiftUI), die Beerpong-Spiele statistisch
auswertet. Das Spiel findet komplett offline am echten Tisch statt – die
App ersetzt es nicht, sie protokolliert. Während des Spiels tippt man an,
welche Becher getroffen wurden; daraus entstehen Live-Anzeige, Historie
und Langzeitstatistiken.

Der Nutzer ist kein professioneller Entwickler, arbeitet aber mit hohem
Qualitätsanspruch: professionell, skalierbar, keine Quick-and-Dirty-
Lösungen. Diesen Anspruch bitte beibehalten.

---

## 2. Rahmenbedingungen (nicht verhandelbar ohne Rücksprache)

- **Kein Mac.** Nur iPhone + Windows-PC. Gebaut wird über GitHub Actions
  (macOS-Runner) → unsignierte `.ipa` → der Nutzer signiert lokal mit
  **Sideloadly** und seiner kostenlosen Apple-ID. Anleitung: `README.md`.
- **Swift lässt sich hier nicht kompilieren.** Die einzige Prüfung ist der
  Actions-Lauf. Vor jedem Push lohnt sich eine Durchsicht auf
  Klammerbilanz, ungerade Anführungszeichen und iOS-17-only-APIs
  (Deployment-Target ist **iOS 16**).
- **Pushen ist erwünscht.** Push auf `main` löst den Build aus. Der Nutzer
  meldet dann grün oder rot; bei rot braucht es die Zeilen ab dem ersten
  `error:` aus dem Actions-Log.
- **Firebase CLI ist eingerichtet.** `firebase deploy --only firestore:rules`
  läuft direkt aus dem Repo (`.firebaserc` zeigt auf `beerstats-c84d8`).
  Regeländerungen müssen **nicht** mehr von Hand in die Konsole kopiert
  werden.
- **Kein Blaze-Tarif.** Cloud Functions sind damit ausgeschlossen. Firestore
  selbst ist im kostenlosen Spark-Tarif nutzbar, inklusive Offline-Cache.
- **Repo-Struktur ist flach**: `App/`, `Core/`, `DesignSystem/`,
  `Features/`, `Models/`, `Repositories/`, `Services/`, `Resources/` liegen
  direkt im Root. `project.yml` verweist darauf.

---

## 3. Architektur

MVVM + Service-Layer + Repository-Layer, DI über `AppContainer`
(kein Singleton), verteilt via `\.appContainer` in der SwiftUI-Environment.
Echtzeit-Listener sind immer als `AsyncStream` gekapselt.

**Das Herzstück ist die Regel-Engine** (`Features/LiveGame/Engine/`):

- `LiveGameState` ist ein reiner Wert-Typ.
- `GameEngine.apply(action, to:) -> (state, events)` ist eine reine Funktion.
- Daraus folgt dreierlei: Undo ist der vorherige Wert, das Regelwerk ist
  ohne Firebase testbar, und alle Geräte kommen aus demselben Log auf
  denselben Stand.

**Der Wurf-Log ist die Wahrheit.** Jede Aktion landet als `Throw` in
`games/{id}/throws`. Der Spielstand entsteht durch Nachspielen dieses Logs
durch die Engine. Der Server rechnet nichts. Korrekturen sind
kompensierende Einträge (`result == .undo`), nie Löschungen.

**Statistiken rechnet das iPhone**, nicht ein Server – mangels Blaze-Tarif.
Ausgewertet wird erst bei „Ergebnis übernehmen" im Sieger-Screen, damit
Undo bis dahin gefahrlos bleibt. Aggregiert wird aus dem nachgespielten
Endzustand, in dem zurückgenommene Würfe bereits herausgerechnet sind.

---

## 4. Firestore-Struktur

```
users/{uid}
  └─ players/{profileId}     PlayerProfile – Mitspieler ohne eigenes Konto
  └─ stats/summary           UserStatistics (aktuell ungenutzt)

usernames/{username} → { uid }
friendships/{id}           (aktuell dormant, siehe Abschnitt 6)

games/{gameId}
  → allPlayerIds: [String]   Konto-IDs mit Zugriff, NICHT die Spieler
  └─ throws/{throwId}        Append-Only-Log
```

**Wichtige Feinheit:** `Team.playerIds` enthält **Profil-IDs** von Leuten
ohne Konto. `Game.allPlayerIds` enthält dagegen **Konto-IDs** – stünden
dort Profil-IDs, liefe die Zugriffsregel ins Leere.

---

## 5. Beerpong-Regelwerk (mit dem Nutzer abgestimmt)

Vollständig in `GameEngine` umgesetzt. Nicht eigenmächtig ändern.

- **Zwei Bälle pro Zug, in beiden Modi.** Im 2v2 wirft jeder Spieler einen,
  im 1v1 dieselbe Person beide. `ballsPerTurn` ist deshalb von
  `playersPerTeam` getrennt.
- **Balls Back:** Treffen beide Bälle eines Zuges, wirft das Team erneut.
  Gilt auch in der Redemption.
- **Bombe:** Trifft der zweite Ball denselben Becher wie der erste, fallen
  dieser + 2 weitere; die zusätzlichen wählt das gegnerische Team.
- **On Fire:** Ab dem **3.** Treffer in Folge behält derselbe Spieler den
  Ball, bis er verfehlt.
- **Bounce Shot:** Aufsetzer im Becher → 2 Becher, den zweiten wählt der
  Gegner, Serie zählt +1.
- **Rebound → Trickshot:** Statt „Daneben" antippbar, wenn der Ball ohne
  Bodenkontakt zurückkommt und gefangen wird. Der Trickshot-Treffer zählt
  ebenfalls 2 Becher. Ein Airball zählt hier **nicht** als Strafe. Nicht
  verkettbar.
- **Airball:** Weder Becher noch Tisch → Shot-Strafe.
- **Redemption:** Ist ein Rack leer, wirft das unterlegene Team weiter,
  beide Bälle immer zu Ende. Treffen beide → Balls Back, sonst Spielende.
  Räumt es alles ab → unentschieden.
- **Umstellen (Re-Rack):** **Einmal pro Team pro Spiel.** Auswahl aus festen
  Formationen, die die drei Regeln bauartbedingt erfüllen: kein Becher
  allein, mindestens einer an der hinteren Kante, gleiche Becherzahl.
  Der **Berserker** ist zwei versetzte Linien *in Wurfrichtung*.

---

## 6. Stand

**Läuft auf dem iPhone.** Alle Kernfunktionen sind gebaut:

- Login (E-Mail/Passwort), Mitspieler-Profile mit Emoji und Farbe
- Neues Spiel aus Profilen → direkt ins Live-Tracking (keine Lobby)
- Glücksrad, das die Teams aus allen aktiven Profilen auslost
- Live-Tracking mit vollständigem Regelwerk, Undo, Re-Rack, Abbruch
- Statistiken auf Profile, umschaltbar zwischen Gesamt und letztem Monat
- Rangliste, Direktvergleich, Spielverlauf, Becher-Heatmap, MVP der Partie
- Sounds (selbst synthetisiert), Sprachansage, App-Icon
- Entwicklereinstellungen, passwortgeschützt (`ClaudeMinion67`)
- Partyspiele auf dem Handy: Bombe weitergeben, Ich hab noch nie

**Zwei Dinge, die man beim Weiterbauen wissen muss:**

- **Zeitraum-Statistiken werden gerechnet, nicht gespeichert.** Die Werte am
  Profil sind Lebenszeit-Summen. Für „letzter Monat" spielt
  `ThrowRepository.aggregateStatistics` die Wurf-Logs der betroffenen
  Partien neu durch. Das gilt dadurch rückwirkend und rechnet Undos korrekt
  heraus – kostet aber Lesezugriffe, deshalb nur auf Anforderung.
- **Partyspiele zahlen nicht auf die Beerpong-Statistiken ein.** Eine Runde
  Bombe hat keine Trefferquote. Wer dort eine Wertung will, braucht einen
  eigenen Zähler, nicht `UserStatistics`.

**Bewusst dormant:** Das Freundesystem (`Features/Friends/`) und
`LobbyView` sind gebaut, aber nicht verlinkt. Sie sind der Weg für später,
wenn die App auf mehreren Geräten läuft. Nicht löschen.

**Offen / denkbar:** Cloud Functions (bräuchte Blaze), Live Activity für
den Sperrbildschirm, faire Teams nach Statistik, Ergebnis als Bild teilen,
Auszeichnungen, weitere Partyspiele (Reaktionsduell, Mäxchen).

---

## 7. Lessons Learned – bitte nicht wiederholen

1. **`macos-14`-Runner + aktuelles xcodegen sind inkompatibel.** Läuft
   deshalb auf `macos-15`.
2. **Firebase-Dienste müssen in der Konsole einzeln aktiviert werden.**
   Das Projekt existierte, aber weder Firestore noch Authentication waren
   eingerichtet. Symptom war ein nichtssagender „internal error"; der
   eigentliche Grund (`CONFIGURATION_NOT_FOUND`) steckte in einem
   verschachtelten Fehlerobjekt. `AppError.from` packt so etwas jetzt aus.
3. **Deutsche Anführungszeichen in Swift-String-Literalen.** Ein öffnendes
   Zeichen mit ASCII-Quote am Ende beendet das Literal mitten im Satz. Hat
   einmal den ganzen Build lahmgelegt.
4. **Trefferflächen in SwiftUI.** Liegt der Hintergrund *außerhalb* des
   Button-Labels, reagiert nur die Schrift. Hintergrund und `contentShape`
   gehören ins Label.
5. **Sideloadly hängt die Team-ID an die Bundle-ID.** Tatsächlich läuft die
   App als `com.beerstats.app.TH2H9C963V`. Die `GoogleService-Info.plist`
   im Repo passt dazu.
6. **7-Tage-Signatur.** Mit kostenloser Apple-ID läuft die Installation
   nach einer Woche ab, dann in Sideloadly erneut „Start".

---

## 8. Arbeitsweise

- Schritt für Schritt, nie mehrere große Features gleichzeitig.
- Kommentare auf Deutsch, Bezeichner auf Englisch. Kommentare erklären
  **warum**, nicht was.
- Keine Magic Numbers, zentrale Konstanten in `AppConstants`.
- Wiederverwendbare Komponenten statt Duplikation – das Design-System ist
  gewachsen und soll genutzt werden (`CupShape` ist das durchgängige
  Signatur-Element von Login über Icon bis Spielscreen).
- Bessere technische Lösungen kurz erklären und umsetzen; eigenständige
  Architekturentscheidungen sind erwünscht.
- Der Nutzer schreibt keinen Code. Claude committet und pusht direkt.
- Getestet wird auf einem echten iPhone über die Cloud-Build-Kette – kein
  Simulator.
