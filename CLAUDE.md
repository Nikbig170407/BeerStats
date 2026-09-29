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
- **Swift lässt sich hier nicht kompilieren.** Die einzige echte Prüfung ist
  der Actions-Lauf, und der dauert zehn Minuten. Was in Sekunden auffallen
  kann, soll nicht dort auffallen — deshalb **vor jedem Push**:

  ```
  python scripts/check.py
  ```

  Findet Klammerfehler, mitten im Satz endende Literale, iOS-17-only-APIs
  (Deployment-Target ist **iOS 16**) und Swift-Dateien, die in keinem
  Quellordner aus `project.yml` liegen und deshalb stillschweigend gar
  nicht übersetzt werden. Es ist kein Compiler und ersetzt den Lauf nicht.
- **Pushen ist erwünscht.** Push auf `main` löst den Build aus.
- **Das Ergebnis kann Claude selbst nachlesen** – das Repo ist öffentlich,
  damit ist die Actions-API ohne Anmeldung zugänglich. `gh` ist nicht
  installiert und wird nicht gebraucht:

  ```
  python scripts/watch_build.py          # wartet auf den neuesten Lauf
  ```

  Das Skript nennt bei einem Fehlschlag den **Schritt**, der gestolpert
  ist. Meist grenzt das die Ursache schon ein; erst wenn es „App bauen"
  oder „Regelwerk testen" ist, braucht es die Zeilen ab dem ersten
  `error:`. Den Nutzer danach zu fragen ist der zweite Schritt, nicht der
  erste.
- **Das Repository ist öffentlich – und zwar aus Kostengründen.** macOS-Runner
  zählen bei GitHub zehnfach; die 2000 Freiminuten eines privaten Repos sind
  in Wahrheit 200 macOS-Minuten im Monat, und die waren aufgebraucht. Für
  öffentliche Repos sind Actions unbegrenzt frei. Daraus folgt eine Regel:
  **Keine Geheimnisse in den Quelltext.** Öffentlich ist auch die ganze
  Historie, ein nachträglich gelöschtes Passwort ist also trotzdem draußen.
  Die `GoogleService-Info.plist` ist bewusst dabei – Firebase dokumentiert
  sie als nicht geheim, und sie steckt ohnehin in jeder `.ipa`. Die echte
  Absicherung sind die Firestore-Regeln.
- **Firebase CLI ist eingerichtet.** `firebase deploy --only firestore:rules`
  läuft direkt aus dem Repo (`.firebaserc` zeigt auf `beerstats-c84d8`).
  Regeländerungen müssen **nicht** mehr von Hand in die Konsole kopiert
  werden.
- **Kein Blaze-Tarif.** Cloud Functions sind damit ausgeschlossen. Firestore
  selbst ist im kostenlosen Spark-Tarif nutzbar, inklusive Offline-Cache.
- **Repo-Struktur ist flach**: `App/`, `Core/`, `DesignSystem/`,
  `Features/`, `Models/`, `Repositories/`, `Services/`, `Resources/`,
  `Tests/`, `Widgets/` liegen direkt im Root. `project.yml` verweist darauf.
- **Drei Ziele**: die App, `BeerStatsTests` (Regelwerk, eigener CI-Job) und
  `BeerStatsWidgets` (Live-Anzeige auf dem Sperrbildschirm, baut gegen
  iOS 16.1). Die Extension hängt am App-Ziel und landet in der `.ipa` –
  wenn Sideloadly plötzlich zickt, ist sie der erste Verdächtige.

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

Was hier steht, ist der **Standard**. Sechs dieser Regeln lassen sich seit
den Hausregeln abschalten (`HouseRule` in `Core/Utilities/HouseRules.swift`,
Oberfläche im Neues-Spiel-Screen). Jede Partie trägt ihr Regelwerk in ihrem
eigenen Dokument – wer später die Hausregeln ändert, verbiegt damit **nicht**
den nachgespielten Wurf-Log alter Partien.

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
- **Hauptmenü als Spielauswahl.** `HomeView` zeigt nur Spiele. Alles rund um
  Beerpong – Neues Spiel, Fortsetzen, Mitspieler & Statistiken, Rangliste,
  Spielverlauf – liegt eine Ebene tiefer in `BeerpongMenuView`. Das
  `HomeViewModel` wird dorthin durchgereicht, nicht neu gebaut, sonst liefe
  ein zweiter Listener auf dieselben Daten.
- Neues Spiel aus Profilen → direkt ins Live-Tracking (keine Lobby)
- **Hausregeln**: Bounce, Trickshot, On Fire (samt Schwelle), Airball-Strafe,
  Umstellen und Redemption einzeln abschaltbar. Liegen in UserDefaults, weil
  sie zum Tisch gehören und nicht zur Partie; in die Partie geschrieben wird
  trotzdem jedes Mal. Die Zeile im Neues-Spiel-Screen nennt, was abweicht,
  und der Regeln-Screen erklärt nur noch, was auch gilt.
- **Spieler-Zentrale**: Das Personen-Symbol in der Spielauswahl führt zu den
  Mitspielern – anlegen, bearbeiten, Statistiken, Rangliste. Dort steht auch,
  **wer heute am Tisch ist** (`TableRoster`). Diese Aufstellung gilt für alle
  Spiele, nicht nur für Beerpong.
- **Vorbereitung vor dem Spiel**: Ring of Fire fragt vorher die Kartenzahl,
  Pferderennen lässt die Leute vorher auf die Farben setzen. Der gemeinsame
  Baustein dafür ist `GameSetupScreen`.
- **Die offene Partie ruft nicht mehr.** Statt einer dauerhaften Anzeige wird
  beim Griff nach Beerpong gefragt: weiterspielen oder neu, mit Aufstellung
  und Stand. Der Stand kommt aus dem nachgespielten Wurf-Log.
- Glücksrad, das die Teams aus allen aktiven Profilen auslost
- Live-Tracking mit vollständigem Regelwerk, Undo, Re-Rack, Abbruch
- Statistiken auf Profile, umschaltbar zwischen Gesamt und letztem Monat
- Rangliste, Direktvergleich, Spielverlauf, Becher-Heatmap, MVP der Partie
- Sounds (selbst synthetisiert), Sprachansage, App-Icon
- Entwicklereinstellungen, passwortgeschützt (im Quelltext steht nur der
  SHA-256; das Passwort selbst kennt der Nutzer)
- **Datensicherung**: „Daten sichern" im Beerpong-Menü schreibt Profile,
  abgeschlossene Partien und den vollständigen Wurf-Log als JSON und gibt
  sie ans Teilen-Blatt. Bewusst **nicht** hinter dem Entwickler-Passwort –
  eine Sicherung, an die man nur kommt, wenn ohnehin alles läuft, ist
  keine. **Zurücklesen geht ebenfalls** – wahlweise nur Profile samt
  Kennzahlen oder alles inklusive Wurf-Logs. Es *legt an*, es ersetzt
  nichts: Auf einem Konto mit vorhandenen Profilen steht danach alles
  doppelt.
- Turniermodus: lost geeignete Spiele aus, Strafe steigt je Runde
- Neunzehn Partyspiele auf dem Handy, in vier Gruppen im Hauptmenü:
  *Mit Karten* – Ring of Fire, Pferderennen, Bussfahrer, Wahrheit oder
  Pflicht, Ich hab noch nie. *Raten & reden* – Schocken, Mäxchen, Zwei
  Wahrheiten, Der Spion, Wer bin ich?, 21, Schätzmeister, Kategorien,
  Wer von uns?. *Schnell zwischendurch* – Bombe, Reaktionsduell,
  Trink-Roulette. *Läuft nebenher* – Verbotene Wörter, Trinkbingo.
  Die Zahl im Text und die Fälle in `PartyGame` müssen zusammenpassen –
  hier standen eine Zeit lang neunzehn, aufgezählt waren siebzehn.

**Was man beim Weiterbauen wissen muss:**

- **Partyspiele stehen im Katalog `PartyGame`, nicht im Hauptmenü.**
  Titel, Emoji, Untertitel, Farbe, Gruppe und Ziel-Ansicht liegen dort
  beisammen; `HomeView` baut die Liste daraus. Ein neues Spiel ist ein
  neuer Fall in der Aufzählung – wer es stattdessen in die View schreibt,
  taucht in „Zuletzt gespielt" nicht auf.

- **Eine neue abschaltbare Regel ist ein neuer Fall in `HouseRule`.** Titel,
  Erklärung, Kurzform für die Zusammenfassung und der `WritableKeyPath` ins
  `GameFormat` stehen dort beisammen; Einstellungs-Screen und
  Abweichungs-Zeile bauen sich daraus. Wer den Schalter stattdessen in die
  View schreibt, taucht in der Zusammenfassung nicht auf – und dann steht
  „Standard“ über einer Partie, die keiner ist.

- **Wer heute mitspielt, steht in `TableRoster`** – und kommt über
  `\.tablePlayers` in der SwiftUI-Umgebung bei den Spielen an, nicht als
  Parameter an `PartyGame.destination`. Sonst müssten alle neunzehn Spiele
  die Liste annehmen, auch die siebzehn, die sie nicht brauchen. Wichtig:
  **Leer ist ein gültiger Zustand** – wer keine Profile hat, spielt ohne
  Namen weiter. Beide Wege müssen im Spiel stehen, nicht nur der schöne.
  Nicht zu verwechseln mit `PlayerProfile.isActive`: Das heißt „gehört noch
  zur Truppe" und gilt für Monate, die Aufstellung heißt „ist heute da".

- **Einstellungen vor dem Spiel gehören in `GameSetupScreen`**, die Auswahl
  aus wenigen Werten in `ChoiceRow`. Beides sind geteilte Bausteine wie
  `PlayerCountStepper` und `HandoffPanel` – wer einen eigenen Vorspann baut,
  lässt ihn anders aussehen.

- **Extreme-Karten tragen Dauer und Strafe als eigene Felder**, nicht im
  Text. Die Dauer steht auf jeder Karte, auch wenn sie „Sofort" lautet; die
  Strafe fehlt nur dort, wo es nichts zu brechen gibt. Drei Tests halten das
  fest, einer davon: Jede Challenge muss sagen, was Verweigern kostet – ohne
  das ist sie eine Bitte.

- **Kartenspiele tragen den ganzen Satz auf der Karte**, nicht nur den
  Nachsatz. Ein fester Vorspann („Ich hab noch nie …") kann grammatisch
  nicht aufgehen: Es gibt „Ich bin noch nie …" und „Ich hatte noch nie …".

- **Geteilte Bausteine benutzen, nicht neu tippen.** Zwei Sachen standen
  mehrfach fast gleich im Projekt und sind inzwischen je eine Komponente:
  `PlayerCountStepper` (die Spielerzahl einstellen, stand fünfmal da) und
  `HandoffPanel` (Handy übernehmen → aufdecken → weitergeben, stand
  zweimal da). Beide waren bereits auseinandergelaufen, bevor sie
  zusammengelegt wurden – unterschiedliche Größen, Radien, Ausrichtungen.
  Wer ein Spiel baut, das eines von beidem braucht, nimmt die Komponente.

- **Die Sicherungsdatei hat ein eigenes Format**, absichtlich getrennt von
  den Firestore-Modellen (`Services/DataExportService.swift`). Technisch,
  weil `@DocumentID` und `@ServerTimestamp` sich nicht mit einem normalen
  `JSONEncoder` schreiben lassen – vor allem aber, damit eine Umbenennung
  im Modell nicht die Sicherungen von letztem Jahr entwertet. Das Format
  trägt eine `formatVersion` und darf sich langsamer ändern als der Code.
  Neue Felder gehören deshalb **optional** hinein – so wie der Regelwerk-
  Abschnitt einer Partie: Sicherungen von vorher haben ihn nicht, für die
  gilt beim Zurücklesen der Standard, und genau der galt damals auch.
  Alles, was die Engine zum Nachspielen braucht, muss dort stehen. Sonst
  läuft der wiederhergestellte Log unter anderen Regeln als der echte.

- **Zeitraum-Statistiken werden gerechnet, nicht gespeichert.** Die Werte am
  Profil sind Lebenszeit-Summen. Für „letzter Monat" spielt
  `ThrowRepository.aggregateStatistics` die Wurf-Logs der betroffenen
  Partien neu durch. Das gilt dadurch rückwirkend und rechnet Undos korrekt
  heraus – kostet aber Lesezugriffe, deshalb nur auf Anforderung.
- **Partyspiele zahlen nicht auf die Beerpong-Statistiken ein.** Eine Runde
  Bombe hat keine Trefferquote. Wer dort eine Wertung will, braucht einen
  eigenen Zähler, nicht `UserStatistics`.
- **Trinkmengen niemals als Zahl in den Text schreiben.** Sie laufen über
  `DrinkAmount` (`.sips(3)`, `.shot`) und werden erst beim Anzeigen in der
  gewählten Härte ausformuliert (`DrinkIntensity`, gespeichert in
  UserDefaults, gilt für alle Partyspiele). Eine fest eingetippte Menge
  ignoriert die Einstellung stillschweigend – und genau so etwas fällt erst
  am Tisch auf.

**Bewusst dormant:** Das Freundesystem (`Features/Friends/`) und
`LobbyView` sind gebaut, aber nicht verlinkt. Sie sind der Weg für später,
wenn die App auf mehreren Geräten läuft. Nicht löschen.

**Offen / denkbar**, nach Wert sortiert:

1. **Trefferquote über die Uhrzeit.** Jeder `Throw` trägt einen Zeitstempel,
   benutzt wird er für nichts. „Bis 22 Uhr 47 %, nach Mitternacht 22 %" ist
   die ehrlichste Statistik, die diese App haben kann, und kostet keine
   neuen Daten.
2. **Bester Partner, schlimmster Gegner.** Die Partien enthalten die
   Aufstellungen; mit wem man gewinnt, ist reine Auswertung.
   `HeadToHeadView` gibt es schon, Team-Chemie fehlt.
3. **`LiveGameViewModel` teilen.** 771 Zeilen, zehn `@Published`. Vier der
   acht Funde aus der Cloud-Prüfung vom 15. August lagen dort, alle mit
   derselben Ursache: derselbe Zustand an zwei Stellen gehalten. Ein Schnitt
   entlang Regelwerk / Synchronisation / Nebenwirkungen legt die Fehlerklasse
   trocken, statt sie einzeln zu jagen.
4. **„Kennst du deine Leute?"** – ein Partyspiel, dessen Fragen aus den
   eigenen Beerpong-Daten entstehen („Wer trifft besser, wer wirft mehr
   Airballs?"). Besprochen, nicht begonnen. Kein Inhalt zu schreiben, und
   das einzige Trinkspiel, das nur diese App haben kann.

Weiter denkbar, aber ohne konkreten Anlass: Cloud Functions (bräuchte
Blaze), Live Activity für den Sperrbildschirm, Ergebnis als Bild teilen.

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
7. **Rot heißt nicht immer kaputt.** Vier Läufe hintereinander waren rot,
   und der Fehler steckte nicht im Code: GitHub hatte die Jobs wegen des
   Abrechnungslimits gar nicht erst gestartet. Das Erkennungszeichen ist
   eindeutig – **beide** Jobs enden nach wenigen Sekunden mit **null**
   aufgezeichneten Schritten. Ein Compiler-Fehler sieht nie so aus. Bevor
   der Swift-Code durchsucht wird, gehört deshalb der Blick auf die
   Schritte; `scripts/watch_build.py` schreibt genau das hin.
8. **Eine Einstellung, die niemand einstellen kann, wird auch nicht
   ausgewertet.** `GameFormat` trug sieben Schalter, von denen nur die
   Becherzahl an der Oberfläche ankam. Beim Sichtbarmachen stellte sich
   heraus: `redemptionAllowed` hat die Engine nie gelesen – die Redemption
   lief auch abgeschaltet. Kein Test hätte das gefunden, es gab keinen. Wer
   Konfiguration auf Vorrat baut, baut ungeprüften Code; entweder gleich mit
   Oberfläche und Test, oder gar nicht.

9. **Ein denormalisiertes Feld wartet nicht auf eine Cloud Function, die es
   nie gab.** `Game.cupsRemaining` traegt laut Modellkommentar den
   Becherstand und wird „von einer Cloud Function bei jedem neuen Throw
   aktualisiert". Cloud Functions brauchen Blaze, und den gibt es nicht –
   geschrieben wird das Feld genau einmal, beim Anlegen, mit der vollen
   Becherzahl. Der Spielverlauf liest es und zeigt deshalb bei jeder Partie
   10 : 10. Wer eine Architektur im Kommentar beschreibt, die es nicht gibt,
   baut eine Falle: Der naechste liest den Kommentar und glaubt ihm.

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

---

## 9. Offene Prüfpunkte am Gerät

Vom 15. August bis Ende September 2026 wurde **ohne Testgerät** gearbeitet:
gebaut wurde nur, was die Cloud-Kette allein bestätigen kann – reine Logik,
Auswertungen, Tests, Oberfläche über vorhandenen Daten. „Grün" hieß in
dieser Zeit ausschließlich „übersetzt sich, Tests laufen durch".

Alles hier ist deshalb **nie auf Hardware gelaufen**. Abgearbeitete Punkte
bitte streichen – die Liste nützt nur, solange sie stimmt.

- **Hausregeln**: Eine Partie mit abgeschalteter Redemption zu Ende spielen –
  der letzte Becher muss direkt in den Sieger-Screen führen, ohne Nachwurf.
  Das Regelwerk selbst deckt `HouseRulesTests` ab, den Weg dorthin nicht:
  dass der Schalter das Spiel erreicht, dass die Einstellung den App-Start
  überlebt, und dass die Abweichungs-Zeile mit sieben Einträgen nicht
  auseinanderfällt.
- **Alles vom 29. September**: Aufstellung („am Tisch"), Vorbereitung bei
  Ring of Fire samt ausgeloster Karte, Setzen beim Pferderennen, Dauer und
  Strafe auf den Extreme-Karten, die Frage nach der offenen Partie, der neue
  Hintergrund. Nichts davon lief je auf Hardware. Besonders zu prüfen: die
  Auslosung bei Ring of Fire dauert etwa drei Sekunden – das ist geschätzt,
  nicht gemessen.
- **Beerpong Extreme** insgesamt: Blitzt die Karte auf? Beim richtigen Team?
  Die Zuordnung `.hit` → Gegner und `.cupChosen` → wählendes Team ist
  durchdacht, nicht beobachtet.
- **Letzter Becher geladen:** Karte und Sieger-Screen treffen gleichzeitig
  aufeinander. Ungetestet, wahrscheinlichster Ärger.
- **Abend, Trinkbilanz, Namen** in den Partyspielen – besonders, ob Position
  3 im Spiel und Position 3 in der Teilnehmerliste dieselbe Person meinen.
- **Datensicherung** samt Teilen-Blatt – und vor allem das
  **Wiederherstellen**, weil es als einziges schreibt. Beim ersten Versuch
  „Nur Profile und Werte" auf einem frischen Konto, nicht „Alles" auf dem
  echten.
- **Widget-Extension:** Erst der Sideload zeigt, ob die `.ipa` installierbar
  bleibt (Lessons Learned Nr. 5).
- **Ohne Netz:** Flugmodus, App killen, ganze Partie spielen, Netz an. Der
  Firestore-Cache ist nirgends im Code konfiguriert – auf iOS ist er
  standardmäßig an, geprüft hat es nie jemand. Gespielt wird im Keller.

---

## 10. Offene Entscheidungen des Nutzers

**Elo: abgelehnt (September 2026).** `eloRating` steht in drei Modellen, in
`LeaderboardEntry` und in der Sicherungsdatei – immer auf `1000`, nirgends
gerechnet. Gerechnet werden soll es ausdrücklich nicht. Damit bleibt nur
streichen oder so lassen; bitte nicht ungefragt wieder als Vorschlag
aufwärmen.

**Der Becherstand im Spielverlauf.** `Game.cupsRemaining` steht immer auf der
vollen Becherzahl (siehe Lessons Learned Nr. 9), `GameHistoryView` zeigt ihn
trotzdem als Ergebnis. Vorschlag: beim „Ergebnis übernehmen" die tatsächlich
verbliebenen Becher schreiben – ein Schreibzugriff an einer Stelle, an der
ohnehin geschrieben wird – und „beide Teams auf voller Becherzahl" im
Verlauf als *unbekannt* behandeln statt als Ergebnis. Alte Partien blieben
unbekannt; nachtraeglich ginge es nur durch Nachspielen aller Logs. Dem
Nutzer am 29. September gemeldet, noch nicht entschieden.

**Lokal-zuerst statt Firestore.** Firestore kauft genau eine Sache:
Synchronisation über mehrere Geräte. Die ist dormant (`Features/Friends/`,
`LobbyView`) und wurde zweimal abgewählt. Bezahlt wird dafür mit Kontingent,
Regeln, einem Login vor der ersten Nutzung und einem Konto als
Totalverlust-Risiko. **Lokal-zuerst** würde all das auflösen – und die
neueren Bausteine (Abend, Trinkbilanz, eigene Karten, ausgeblendete Karten)
liegen ohnehin schon in UserDefaults. Nicht eigenmächtig umbauen; aber wenn
der Nutzer danach fragt, ist das die Antwort.
