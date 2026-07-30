# CLAUDE.md – Projektkontext für BeerStats

Dieses Dokument fasst den kompletten bisherigen Stand zusammen, damit eine
neue Claude-Instanz (hier: Claude Code) nahtlos weiterarbeiten kann, ohne
dass Kontext verloren geht. Bitte dieses Dokument als Grundwahrheit
behandeln – bei Widersprüchen zum tatsächlichen Code gilt: Code-Realität
im Repository hat Vorrang, aber Entscheidungen/Begründungen hier sind
bewusst getroffen und sollten nicht ohne Rücksprache mit dem Nutzer
geändert werden.

---

## 1. Projektüberblick

**BeerStats** ist eine iOS-App (SwiftUI), die Beerpong-Spiele statistisch
auswertet. Das eigentliche Spiel findet komplett offline am echten Tisch
statt – die App ersetzt das Spiel nicht. Während des Spiels tippen die
Spieler auf ihrem Handy an, welche Becher getroffen wurden. Daraus
entstehen automatisch Live-Statistiken, Spielhistorien und
Langzeitstatistiken. Alle Eingaben werden in Echtzeit zwischen den
Geräten der Mitspieler synchronisiert (Firestore).

Der Nutzer ist kein professioneller Entwickler, arbeitet aber bewusst
mit hohem Qualitätsanspruch ("professionell, skalierbar, produktionsreif,
keine Quick-and-Dirty-Lösungen"). Bitte diesen Anspruch beibehalten.

---

## 2. Wichtige Rahmenbedingungen (nicht verhandelbar ohne Rücksprache)

- **Kein Mac vorhanden.** Der Nutzer hat nur ein iPhone + einen Windows-PC.
  Die App wird deshalb NICHT lokal mit Xcode gebaut, sondern über eine
  **Cloud-Build-Kette**: GitHub Actions (macOS-Runner) kompiliert bei
  jedem Push automatisch eine **unsignierte `.ipa`**. Der Nutzer signiert
  und installiert diese anschließend selbst über **Sideloadly** auf
  seinem PC mit seiner privaten (kostenlosen) Apple-ID.
- **Kein App Store.** Die App ist ausschließlich für das private iPhone
  des Nutzers gedacht, keine Veröffentlichung geplant.
- **Kostenlose Apple-ID** → keine Push-Notification-Entitlements
  zuverlässig verfügbar (braucht bezahlten Apple-Developer-Account,
  99 €/Jahr). Deshalb: **E-Mail/Passwort-Login statt Sign in with
  Apple**, Live-Updates laufen ausschließlich über Firestore-Echtzeit-
  Listener (brauchen keine Push-Berechtigung). Push-Benachrichtigungen
  sind als optionales Feature vorgesehen, funktionieren aber aktuell
  nicht zuverlässig und sind nicht kritisch für den Kernbetrieb.
- **Repo-Struktur ist "geflacht":** Beim ersten Upload wurde eine
  Ordnerebene zu viel entfernt. Der Quellcode liegt jetzt **direkt im
  Repo-Root** in den Ordnern `App/`, `Core/`, `DesignSystem/`,
  `Features/`, `Models/`, `Repositories/`, `Services/`, `Resources/` –
  NICHT mehr unter einem gemeinsamen `BeerStats/`-Unterordner.
  `project.yml` verweist entsprechend direkt auf diese Ordner (siehe
  `sources:`-Liste). Falls du die Struktur umbaust, `project.yml`
  entsprechend mitziehen.
- **GitHub-Workflow:** `.github/workflows/build.yml` baut bei jedem Push
  auf `main` automatisch. Falls du direkten Git-Zugriff hast (Claude
  Code kann i. d. R. `git push`), kannst du Änderungen direkt committen
  und pushen, statt sie dem Nutzer zum manuellen Hochladen zu geben –
  das war der Hauptgrund für den Wechsel zu Claude Code.

---

## 3. Architektur

**Pattern:** MVVM + Service-Layer + Repository-Layer

```
View (SwiftUI)
   ⇅
ViewModel (ObservableObject, @MainActor)
   ⇅ async/await (One-Shot) / AsyncStream (Echtzeit-Listener)
Repository (fachliche Logik, kombiniert mehrere Services)
   ⇅
Service (reine Firebase-Kommunikation, hinter Protocol)
   ⇅
Firebase SDK
```

- **Services** = reine Kommunikation mit Firebase, hinter Protokollen,
  damit ViewModels testbar sind (Mocks möglich).
- **Repositories** = fachliche Logik, Validierung, Kombination mehrerer
  Services (z. B. `AuthRepository` kombiniert `AuthService` +
  `UserService` zu einem konsistenten Signup-Vorgang inkl. Rollback).
- **Dependency Injection** über `AppContainer` (kein Singleton-Pattern),
  via SwiftUI-Environment (`\.appContainer`) an Views verteilt.
- **Echtzeit-Listener** werden in Services immer als `AsyncStream`
  gekapselt (nie roh an Views durchgereicht), Listener wird automatisch
  über `continuation.onTermination` entfernt, wenn der konsumierende
  Task abgebrochen wird.
- **Async/await** für alle einmaligen Operationen, native Firestore-
  Async-APIs wo möglich (`getDocument()`, `updateData() async throws`,
  `setData(_:) async throws`), Continuation-Wrapper nur wo nötig
  (z. B. `runTransaction`).
- **Firestore-Statistiken werden NIE komplett neu berechnet**, sondern
  inkrementell fortgeschrieben (Cloud Functions, noch nicht
  implementiert – siehe Abschnitt 7, offene Schritte).
- **Append-Only-Log** für Würfe (`throws`-Subcollection): nie ändern/
  löschen, Korrekturen über kompensierende `undo`-Einträge.

---

## 4. Firestore-Datenstruktur

```
users/{userId}
  └─ stats/summary                     (UserStatistics, noch nicht live befüllt)

usernames/{username} → { uid }         (Uniqueness-Reservierung)

friendships/{friendshipId}
  → participantIds: [uidA, uidB] (sortiert)

games/{gameId}
  → allPlayerIds: [String]            (flaches Array, für array-contains-Queries)
  └─ throws/{throwId}                  (Append-Only, noch nicht implementiert – Schritt 7)
  └─ statistics/summary                (GameStatistics, noch nicht implementiert)

leaderboards/{scope}/entries/{userId}  (noch nicht implementiert – Schritt 9)
```

- `firestore.rules` und `firestore.indexes.json` liegen im Repo-Root,
  wurden vom Nutzer bereits manuell in die Firebase Console eingespielt.
- Wichtigstes Sicherheitsprinzip: Clients dürfen `throws` nur ERSTELLEN,
  nie ändern/löschen. Statistiken/Ranglisten sind für Clients komplett
  schreibgeschützt (nur Cloud Functions – die noch nicht existieren!).

---

## 5. Beerpong-Regelwerk (mit Nutzer im Detail abgestimmt)

Dies ist das vollständige, verbindliche Regelwerk. **Nicht eigenmächtig
ändern** – wurde über mehrere Nachrichten hinweg exakt mit dem Nutzer
abgestimmt.

- **Grundspiel:** 1v1 oder 2v2, Teams werfen abwechselnd, standardmäßig
  10 Becher pro Team (konfigurierbar über `GameFormat.cupCount`).
- **Re-Rack:** verbleibende Becher dürfen zu bestimmten Zeitpunkten neu
  sortiert werden (kein Wurf-Ereignis, eigener `ThrowResult.reRack`).
- **Redemption:** wird der letzte Becher getroffen, bekommt das
  unterlegene Team einen letzten Wurf-Durchgang, bevor der Sieger
  feststeht.
- **On Fire:** Ein einzelner Spieler trifft **3 eigene Würfe in Folge**
  (durchgangsübergreifend, nicht team-bezogen) → er ist "on Fire" und
  bekommt bei **jedem weiteren Treffer** (nicht nur einmalig) einen
  Bonus-Wurf, bis er einen Fehlwurf hat (Streak wird zurückgesetzt).
  Denormalisierter Zähler: `Game.playerStreaks: [String: Int]`.
- **Bounce Shot:** Aufsetzer, der trotzdem im Becher landet → zählt
  **2 Becher**, aber nur **+1** für den On-Fire-Streak-Zähler.
- **Trickshot:** Wirft ein Spieler daneben (Becher verfehlt), der Ball
  berührt nicht den Boden, fliegt zurück auf die eigene Tischhälfte und
  wird von einem beliebigen Spieler des eigenen Teams gefangen → der
  ursprünglich werfende Spieler bekommt einen Trickshot-Bonuswurf
  (normaler Wurf auf verbleibende Becher, kein Zwang). Trifft er: **2
  Becher** weg. Verfehlt er: **keine** Konsequenz, insbesondere **kein
  Airball**, egal wie der Wurf ausgeht.
- **Airball:** Wurf verfehlt sowohl jeden Becher (auch keine Kante) als
  auch den Tisch komplett → der werfende Spieler muss einen Shot
  trinken. Gilt für normale Würfe UND On-Fire-Bonuswürfe. Gilt
  **NICHT** für Trickshot-Bonuswürfe (siehe oben).
- **Doppeltreffer, unterschiedliche Becher:** Treffen beide Spieler
  eines Teams im selben Durchgang (`roundNumber` gleich), bekommt das
  Team beide Bälle zurück und wirft erneut.
- **Doppeltreffer, gleicher Becher:** Treffen beide Spieler eines Teams
  denselben Becher, werden dieser + 2 weitere Becher entfernt. Das
  *gegnerische* Team (das trinken muss) wählt aus, welche 2 zusätzlichen
  Becher das sind (`chosenCupIds` am Throw-Eintrag).

**Datenmodell-Abbildung** (siehe `Models/Throw.swift`):
`result` (hit/miss/airball/redemption/reRack/undo), `throwType`
(normal/onFireBonus/trickshotAttempt), `roundNumber`, `isBounce`,
`enablesTrickshot`, `triggeredByThrowId`, `cupsRemoved`, `chosenCupIds`,
sowie die abgeleitete Regel `triggersAirballPenalty` (computed property,
prüft `result == .airball && throwType != .trickshotAttempt`).

**Wichtig:** Die eigentliche Wurf-Erfassungs-UI (Cup-Grid, Live-Tracking)
existiert noch NICHT – das ist Schritt 7 und der nächste anstehende
Arbeitsschritt.

---

## 6. Aktueller Implementierungsstand

### ✅ Fertig (Schritte 1–6)

1. **Projektstruktur** – Ordnerstruktur, `AppContainer` (DI), `AppLogger`,
   `AppError`, `AppConstants`, Cloud-Build-Pipeline (XcodeGen +
   GitHub Actions + Sideloadly-Anleitung in `README.md`)
2. **Datenmodelle** – alle in `Models/`: `User`, `Friendship`, `Team`,
   `Game`/`GameFormat`, `Throw`, `GameStatistics`, `UserStatistics`,
   `LeaderboardEntry`
3. **Firebase-Struktur** – `firestore.rules`, `firestore.indexes.json`,
   `firebase.json` (vom Nutzer bereits in Firebase Console eingespielt)
4. **Authentifizierung** – E-Mail/Passwort, `AuthService` +
   `UserService` + `AuthRepository` (mit Rollback bei fehlgeschlagener
   Profilerstellung), `OnboardingView`
5. **Freundesystem** – `FriendService` + `FriendRepository`,
   `FriendsView` (Suche, Anfragen, Freundesliste)
6. **Spielsystem** – `GameService` + `GameRepository`, `NewGameView`
   (Modus + Mitspieler wählen), `LobbyView` (Teams anzeigen, Ersteller
   kann starten), `HomeView` (ersetzt Platzhalter, zeigt laufende Spiele)

### 🚧 Design-System (parallel gebaut, gilt für alle Screens)

Farbpalette "Taproom bei Nacht" (`DesignSystem/Colors.swift` +
`Assets.xcassets`), Typografie inkl. Monospace-Stats
(`Typography.swift`), zentrale Animationskurven (`AppAnimation.swift`),
Haptik (`HapticManager.swift`), wiederverwendbare Komponenten:
`PrimaryButton`, `SecondaryButton`, `BeerStatsCard`,
`BeerStatsTextField`, `PressableButtonStyle`, sowie das Signatur-Element
`CupFillLoadingView` (animierter, sich füllender Becher als Lade-
Indikator, ersetzt generische Spinner überall).

### ❌ Noch offen (Roadmap)

7. **Live-Tracking** – DER Kernschritt: Cup-Grid-UI zum Antippen von
   Treffern während des Spiels, `ThrowService`/`ThrowRepository`,
   Implementierung des kompletten Regelwerks aus Abschnitt 5
   (On Fire, Bounce, Trickshot, Airball, Doppeltreffer-Logik),
   Cloud Functions für inkrementelle Statistik-Aggregation (bisher
   komplett unimplementiert – Firebase Cloud Functions existieren noch
   gar nicht im Projekt!)
8. **Statistiken** – Profil-Statistik-Ansicht, Diagramme
9. **Ranglisten** – global/Freunde, Cloud-Function-basiert
10. **Feinschliff** – echtes App-Icon (aktuell deaktiviert, siehe
    Abschnitt 7 "Bekannte Stolpersteine"), Push-Notifications-Politur,
    Error-States, Onboarding-Politur, Settings-Screen (Abmelden lebt
    aktuell übergangsweise im `HomeView`-Toolbar)

**Zusätzlich komplett offen:** Cloud Functions (Node.js/TypeScript,
Firebase Functions) sind noch nicht aufgesetzt. Das braucht ein eigenes
Verzeichnis (`functions/`) mit eigenem `package.json`, separatem Deploy-
Mechanismus (Firebase CLI – funktioniert plattformunabhängig, auch ohne
Mac, da Node.js-basiert). Das wird spätestens in Schritt 7 nötig, wenn
On-Fire-Streaks/Statistiken serverseitig inkrementell fortgeschrieben
werden sollen.

---

## 7. Bekannte Stolpersteine / Lessons Learned (bitte nicht wiederholen)

Diese Fehler sind beim Ersteinrichten der Cloud-Build-Kette aufgetreten
und wieder behoben worden – falls du an Build-Konfiguration arbeitest,
diese Punkte beachten:

1. **`macos-14`-Runner + aktuelles `xcodegen` (via `brew install`) sind
   inkompatibel** – erzeugt ein Projektformat, das die auf `macos-14`
   vorinstallierte Xcode-Version nicht lesen kann ("future Xcode project
   file format"). **Fix:** Runner auf `macos-15` gestellt
   (`.github/workflows/build.yml`).
2. **`AppLogger.swift` fehlte `import Foundation`** (nutzt `Bundle`,
   das ist Foundation, nicht `os`). Import ergänzt.
3. **`ASSETCATALOG_COMPILER_APPICON_NAME` erwartet ein `AppIcon`-Set**,
   das noch nicht existiert → Build schlug fehl. Aktuell in `project.yml`
   auf `""` (leer) gesetzt, um die Anforderung zu deaktivieren. **Muss
   in Schritt 10 durch ein echtes App-Icon ersetzt werden.**
4. **Firebase-Crash beim App-Start** (`FirebaseAuthService`-Init crasht
   in `AppContainer.live()`): SwiftUI garantiert NICHT, dass
   `AppDelegate.didFinishLaunching` vor `App.init()` läuft. `Auth.auth()`
   wurde aufgerufen, bevor `FirebaseApp.configure()` gelaufen war.
   **Fix:** `FirebaseApp.configure()` jetzt direkt (mit
   `if FirebaseApp.app() == nil` Guard) in `BeerStatsApp.init()`,
   NICHT nur im AppDelegate.
5. **Sideloadly hängt bei kostenlosen Apple-IDs automatisch die
   Team-ID an die Bundle-ID an** (aus `com.beerstats.app` wird z. B.
   `com.beerstats.app.TH2H9C963V`), auch wenn im Sideloadly-UI die
   "saubere" Bundle-ID angezeigt wird. Die tatsächliche Team-ID des
   Nutzers: **`TH2H9C963V`**. Es gibt in der Firebase Console
   inzwischen **zwei registrierte iOS-Apps**: `com.beerstats.app`
   (ungenutzt/veraltet) und `com.beerstats.app.TH2H9C963V` (aktiv
   genutzt, mit der aktuell im Repo liegenden `GoogleService-Info.plist`).
   **Falls künftig Bundle-ID-Probleme auftreten: zuerst prüfen, welche
   der beiden Firebase-Apps aktuell mit der im Repo liegenden Plist
   übereinstimmt.**
6. **Repo-Struktur wurde beim allerersten Upload durch den Nutzer
   ungewollt geflacht** (siehe Abschnitt 2) – `project.yml`
   `sources:`-Liste verweist deshalb auf einzelne Ordner im Root statt
   auf einen gemeinsamen `BeerStats/`-Wrapper-Ordner. Falls du das
   Repository neu strukturierst, unbedingt konsistent halten.
7. **Zuletzt ausstehender Test:** Der Firebase-Init-Crash-Fix (Punkt 4)
   wurde erstellt und dem Nutzer zum manuellen Einpflegen in
   `App/BeerStatsApp.swift` und `App/AppDelegate.swift` gegeben – **ob
   der Fix erfolgreich war, ist zum Zeitpunkt dieses Dokuments noch
   nicht bestätigt.** Das ist wahrscheinlich der erste Punkt, den der
   Nutzer mit dir klären möchte.

---

## 8. Arbeitsweise-Vorgaben des Nutzers (bitte beibehalten)

- Schritt für Schritt vorgehen, **nie mehrere große Features
  gleichzeitig** bauen.
- Sauberer, gut kommentierter Code (Kommentare auf Deutsch, Code/
  Bezeichner auf Englisch nach Swift-Konvention).
- MVVM strikt einhalten, Views/ViewModels/Models/Services sauber trennen.
- Keine Magic Numbers/Strings – zentrale Konstanten (`AppConstants`).
- Wiederverwendbare Komponenten statt Duplikation.
- Wenn eine bessere technische Lösung existiert als die vorgeschlagene:
  kurz erklären und umsetzen (eigenständige, sinnvolle
  Architekturentscheidungen sind ausdrücklich erwünscht).
- Der Nutzer selbst schreibt keinen Code – alles wird von Claude
  geschrieben und dem Nutzer zum Einfügen/Committen gegeben (bzw. jetzt
  über Claude Code direkt commit-/pushbar, falls Git-Zugriff besteht).
- Der Nutzer testet auf einem echten iPhone über die Cloud-Build+
  Sideloadly-Kette (siehe Abschnitt 2) – **kein Simulator, keine lokalen
  Previews als alleiniger Test.**

---

## 9. Vorschlag für den nächsten Gesprächseinstieg

Am sinnvollsten zuerst klären: Ist der Firebase-Init-Crash-Fix (Punkt 4
in Abschnitt 7) erfolgreich gewesen, startet die App jetzt? Falls ja:
weiter mit **Schritt 7 (Live-Tracking)** – das ist gleichzeitig der
Punkt, an dem **Cloud Functions** erstmals nötig werden (inkrementelle
Statistik-Aggregation, siehe Abschnitt 6). Falls nein: Crash-Report
erneut auswerten.
