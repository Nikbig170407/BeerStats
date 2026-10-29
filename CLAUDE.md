# CLAUDE.md – Projektkontext für BeerStats

Diese Datei ist die Einstiegshilfe für eine neue Claude-Sitzung. Bei
Widersprüchen gilt: **Der Code im Repository hat Vorrang.** Die
Begründungen hier sind aber bewusst getroffene Entscheidungen und sollten
nicht ohne Rücksprache umgeworfen werden.

Ausführliche Begründungen zu einzelnen Änderungen stehen in den
Commit-Nachrichten – `git log` ist das eigentliche Gedächtnis des Projekts.

**Was hier hingehört und was nicht.** Diese Datei war im Oktober 2026 auf
tausendzweihundert Zeilen gewachsen, weil jede Änderung ihren Hergang
hineingeschrieben hat – „vorher stand hier X, dann Y, jetzt Z". Das ist
genau das, was `git log` ohnehin erzählt, und doppelt geführte Geschichte
läuft auseinander: Beim Umschreiben am 25. Oktober standen drei
verschiedene Zahlen für dieselbe Rechnung in derselben Datei. Deshalb gilt:

- **Hier hin**: was gilt, was man nicht brechen darf, und **warum** –
  Rahmenbedingungen, Verträge zwischen den Bausteinen, Entscheidungen des
  Nutzers, Fallen, in die schon jemand getreten ist.
- **Nicht hier hin**: der Hergang einer einzelnen Änderung, Datumsangaben
  zu jedem Schritt, und **Zahlen, die veralten** (Stapelgrößen,
  Spielerzahlen, „sieben Spiele machen X"). Zahlen gehören in den Code und
  werden von Tests festgehalten; ein Satz, der sie nachspricht, ist beim
  nächsten Nachlegen falsch.

Ein Datum steht nur dort, wo es die Aussage trägt – etwa bei einer
Entscheidung des Nutzers, die man kennen muss, bevor man sie umwirft.

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
  `error:`. **Die Logzeilen kann Claude selbst lesen**, sofern die Sitzung
  eine GitHub-Anbindung hat: Job-Logs des fehlgeschlagenen Laufs abrufen
  (`get_job_logs` mit `failed_only`), dort steht der fehlgeschlagene Test
  oder der Compiler-Fehler im Klartext. Den Nutzer nach Logzeilen zu fragen
  ist der letzte Schritt, nicht der erste.

  **Die beiden Jobs sind unabhängig.** Ein rotes „Regelwerk testen" heißt
  nicht, dass keine `.ipa` entstanden ist – der Build-Job läuft daneben
  weiter. Das ist Absicht (siehe Kommentar in `build.yml`): Ein kaputter
  Test soll niemandem die App vom Tisch nehmen.
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

**Läuft auf dem iPhone.** Alle Kernfunktionen sind gebaut.

### Was die App kann

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
- **Trefferquote nach Tageszeit** im Profil, in Fenstern zu vier Stunden.
  Eine Quote erst ab zwanzig Würfen im Fenster, darunter nur die Zahl der
  Würfe. Wird auf Knopfdruck geladen, weil sie jeden Wurf-Log einzeln liest.
- **Team-Chemie im Profil**: bester Partner, schlimmster Gegner. Quote erst
  ab drei gemeinsamen Partien. Kostet keinen zusätzlichen Lesezugriff – sie
  braucht nur die Aufstellungen, die in den Partien ohnehin stehen.
- **Hauptmenü als vier Ordner**: Mit Karten, Raten & reden, Schnell
  zwischendurch, Läuft nebenher – dahinter die Spiele. Oben nur zwei
  Symbole: Spieler und Einstellungen. **„Zuletzt gespielt" gibt es nicht
  mehr** (13. Oktober): Die Idee war, den häufigsten Weg zu verkürzen;
  tatsächlich stand oben eine Liste, die sich bei jedem Aufmachen anders
  sortiert, und die vier Ordner – die immer gleich liegen – rutschten dafür
  nach unten. `RecentPartyGames` ist mit entfernt, nicht nur ausgeblendet:
  Was niemand liest, soll auch niemand schreiben.
- **Einstellungs-Screen**: Darstellung (Farbschema, Hintergrund, Kanten),
  Ton, Sprachansage, Shots, Härte-Vorgabe, Entwicklereinstellungen,
  Abmelden.
- **Darstellung wählbar**: vier Farbschemata (`AppPalette` – färbt Akzente
  UND Hintergrund), Hintergrund in drei Stufen, Neon-Kanten abschaltbar
  (`AppAppearance`). Kein Hell-Modus, siehe unten.
- **Ring of Fire in zwei Screens**: der Ring für sich, die gezogene Karte
  als Vollbild mit „Verstanden". Karten tragen Dauer und Strafe wie die
  Extreme-Karten, und hinter der Karte läuft eine eigene Szene je Rang
  (`RingCardFlourish`). Der Ring liegt **geschuppt** und spielt mit – wer
  ihn reißt, trinkt. Das ganze Regelwerk dazu steht unten als Vertrag; es
  ist die am häufigsten missverstandene Stelle im Projekt. Er bewegt sich
  wie am Tisch: wird ausgeteilt, hebt die gezogene Karte heraus und brennt
  am Ende als Kranz.
- **Hitparade** (29. Oktober, vorher „Zeitstrahl“): ein Musikspiel nach
  dem Vorbild von Hitster. Die App spielt die Hörprobe selbst, ohne Titel
  oder Cover zu zeigen, und lost jede Runde aus, was gefragt wird:
  einsortieren, Titel, Interpret, Jahr ± 3 oder Jahr ± 1. Wer richtig
  liegt, bekommt die Karte in seine Reihe. Ohne Netz spielt der Nachbar das
  Lied auf der Box an. Joker gibt es bewusst noch nicht.
- **Bussfahrer hat sein Ende** (17. Oktober): Zwei Hälften, wie am Tisch –
  erst die Fragerunde, dann **die Busfahrt**. Die hatte gefehlt: Das Spiel
  hörte nach der vierten richtigen Antwort auf („Das Handy geht weiter"),
  und der Bussfahrer, der dem Spiel den Namen gibt, kam nie vor. Jetzt deckt
  er fünf Karten auf, und jede Bildkarte schickt ihn zurück an den Anfang.
- **„Was spielen wir?"** (18. Oktober): ein Würfel unter dem Raster im
  Hauptmenü. Fünfundzwanzig Spiele heißen am Tisch nicht Auswahl, sondern
  fünf Minuten Diskussion, in denen niemand spielt. Gelost wird aus dem,
  was zur Runde **passt**: Die Spielerzahl ist eine Bedingung, keine
  Empfehlung – „Der Spion" zu zweit wäre kein Vorschlag, sondern ein
  Fehler. Dazu kommt eine Filterung nach Dauer. Was nebenher läuft, ist nie
  dabei: Auf „was spielen wir jetzt" ist Trinkbingo keine Antwort.
- **Nochmal dieselben**: die letzte Aufstellung als Zeile im Beerpong-Menü,
  gestartet mit den aktuellen Hausregeln.
- **Ohne Konto spielbar.** Der Login stand vorher vor allem; jetzt gibt es
  „Ohne Konto loslegen". Alle Partyspiele laufen sofort, nur Beerpong
  braucht ein Konto.
- **Strafen müssen kein Trinken sein** (`PenaltyStyle`): Sport, Kasse oder
  Aufgaben statt Schlücke. Wer nicht trinkt, saß vorher daneben.
- **Die App kommentiert** die Beerpong-Partie laut, wenn die Sprachansage
  an ist (`LiveGameCommentator`).
- **Tischmodus**: große Schrift und ein Bildschirm, der anbleibt, für das
  Handy in der Tischmitte.
- **Der Abend startet sich selbst**, sobald das erste Spiel aufgemacht
  wird – und jede gebuchte Menge lässt sich ganz zurücknehmen, samt
  Person.
- **Vier Räder im Trink-Roulette** (25. Oktober): klassisch, zahm, hart –
  und ein **eigenes**, in das die Runde ihre Felder schreibt. Ein Rad mit
  acht festen Feldern ist beim zweiten Abend dasselbe Rad; ab dem dritten
  weiß jeder, was draufsteht.
- **Der Pokal des Abends** (22. Oktober): zwei Kronen statt einer. **🏆
  Pokal** zählt gewonnene Spiele, gewichtet nach Länge (kurz 1, mittel 2,
  lang 3); **🍺 Bilanz** zählt wie bisher, wer trinken musste. Bewusst
  getrennt und **nicht** verrechnet: „Punkte minus Schlücke" würde
  belohnen, wenig zu spielen – und ein Trinkspiel, das Nichttrinken
  belohnt, ist kaputt. Am Tisch sind das ohnehin zwei Titel.
- **Trinkbingo-Blätter verteilen** (22. Oktober): für jeden ein eigenes,
  anders gemischtes Blatt als **Bild** ans Teilen-Blatt. Kein Link: Die App
  läuft auf genau einem Gerät, ein Link öffnet bei den Gästen nichts.
- **Abende bleiben erhalten**: die letzten zwanzig unter „Frühere Abende",
  teilbar als Text.
- **Erinnerung an die Sicherung**: die Karte sagt, wann zuletzt gesichert
  wurde, und wird nach vier Wochen deutlich.
- **Anleitung je Partyspiel**: Fragezeichen auf jeder Spielkachel.
- **Karten aussortieren und eigene dazu** – jetzt in vier Stapeln: Ich hab
  noch nie, Wahrheit oder Pflicht, **Wer würde eher?** und Beerpong Extreme.
  Der Daumen nach unten steht in jedem Schritt da, nicht erst nach dem
  Aufdecken: Ein Knopf, den man erst nach drei Sekunden Countdown sieht,
  ist für den Nutzer keiner.
- **Ich hab noch nie in zwei Richtungen** (28. Oktober, auf Wunsch: „mehr
  Kategorien, noch härter, und welche, die in andere Richtungen gehen“):
  Die Härte reicht von Kinder bis **Tabulos**, daneben stehen Themen –
  Peinlich, Party, Verboten, Tiefgang, Abenteuer. Gemischt wird alles, was
  angehakt ist.
- **Nicht gespeicherte Würfe lassen sich nachreichen** – siehe unten.
- **Die Partyspiele sagen Namen statt Nummern**, sobald jemand am Tisch
  steht – auch ohne laufenden Abend (`PlayerNames`, Reihenfolge unten).
- Glücksrad, das die Teams aus allen aktiven Profilen auslost
- Live-Tracking mit vollständigem Regelwerk, Undo, Re-Rack, Abbruch
- Statistiken auf Profile, umschaltbar zwischen Gesamt und letztem Monat
- Rangliste, Direktvergleich, Spielverlauf, Becher-Heatmap, MVP der Partie
- Sounds (Mixkit, Ring of Fire selbst gerechnet), Sprachansage, App-Icon
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
- **Die Stapel sind groß, und wie groß steht im Code.** Die Zahlen hier
  nachzusprechen hat zweimal nicht funktioniert – `DeckContentTests` hält
  Mindestzahlen fest, und die Untertitel rechnen ihre Größe aus dem Stapel
  selbst (`TruthOrDareDeck.count` und so weiter).
  Wo **nicht** nachgelegt werden kann, liegt es am Spiel und nicht am
  Fleiß: Ring of Fire hat dreizehn Ränge, Bussfahrer und Pferderennen ein
  Skatblatt, Trink-Roulette so viele Felder, wie das gewählte Rad hat.
  Mehr Karten wären dort ein anderes Spiel.
- Fünfundzwanzig Partyspiele auf dem Handy, in vier Gruppen im Hauptmenü:
  *Mit Karten* – Ring of Fire, Pferderennen, Bussfahrer, Wahrheit oder
  Pflicht, Ich hab noch nie, Hitparade. *Raten & reden* – Schocken, Mäxchen, Zwei
  Wahrheiten, Der Spion, Wer bin ich?, 21, Schätzmeister, Kategorien,
  Wer würde eher?, Kennst du deine Leute?, Pantomime, Die Skala. *Schnell
  zwischendurch* – Bombe, Reaktionsduell, Trink-Roulette, Die Herde. *Läuft nebenher* –
  Verbotene Wörter, Trinkbingo, Regel des Abends.
  Die Zahl im Text und die Fälle in `PartyGame` müssen zusammenpassen –
  hier standen eine Zeit lang neunzehn, aufgezählt waren siebzehn.

### Verträge, die man nicht brechen darf

Das Folgende ist der eigentliche Zweck dieser Datei: Regeln, die man aus
dem Code allein erst sieht, wenn man sie schon gebrochen hat.

- **Partyspiele stehen im Katalog `PartyGame`, nicht im Hauptmenü.**
  Titel, Emoji, Untertitel, Farbe, Gruppe und Ziel-Ansicht liegen dort
  beisammen; `HomeView` baut die Liste daraus. Ein neues Spiel ist ein
  neuer Fall in der Aufzählung – und zwar der einzige nötige Eingriff: Am
  Katalog hängen inzwischen Ordner, Anleitung, Turnier-Eignung und die
  Härte. Wer ein Spiel stattdessen in die View schreibt, hat es nirgends
  davon. **Seit dem Würfel sind es zwei Angaben mehr**: `length` (wie lange
  eine Runde dauert) und `players` (mit wie vielen es funktioniert). Beide
  sind vollständige `switch` ohne `default` – der Compiler erzwingt also,
  dass ein neues Spiel eingeordnet wird, und ein Test hält fest, dass für
  jede Spielerzahl etwas übrig bleibt. Die Untergrenze ist dabei keine
  Geschmacksfrage: „Wer würde eher?" braucht jemanden, auf den man zeigen
  kann. Mit zu wenigen Leuten ist so ein Spiel nicht schwächer, sondern
  kaputt.

- **Ein Spiel umbenennen heißt: den Titel ändern, nicht den Fall.**
  „Wer würde eher?" heißt im Code weiter `mostLikely` (`MostLikelyDeck`,
  `MostLikelyView`). Der `rawValue` der Aufzählung steckt in UserDefaults –
  in den eigenen Karten, in den ausgeblendeten und in der Härte des Spiels.
  Wer ihn umbenennt, wirft diese Daten stillschweigend weg: Die eigenen
  Karten sind „verschwunden", die Härte steht wieder auf der Vorgabe, und
  niemand sieht einen Zusammenhang zur Umbenennung.

- **Eine neue abschaltbare Regel ist ein neuer Fall in `HouseRule`.** Titel,
  Erklärung, Kurzform für die Zusammenfassung und der `WritableKeyPath` ins
  `GameFormat` stehen dort beisammen; Einstellungs-Screen und
  Abweichungs-Zeile bauen sich daraus. Wer den Schalter stattdessen in die
  View schreibt, taucht in der Zusammenfassung nicht auf – und dann steht
  „Standard“ über einer Partie, die keiner ist.

- **In der Hitparade muss der Inhalt stimmen** (22. Oktober). Für jeden
  anderen Stapel gilt: Eine erfundene Karte ist eine Karte. Hier ist ein
  falsches Jahr eine falsche Entscheidung, für die jemand trinkt, ohne
  dass es auffällt. Deshalb stehen in `SongDeck` nur Lieder mit bekanntem
  Jahr – lieber weniger sichere als mehr geschätzte –, und wo Album und
  Single oder Original und Remix auseinanderliegen, steht das Lied gar
  nicht erst drin. Dazu gibt es im Spiel den Knopf **„Jahr stimmt
  nicht"**: Weiß die Runde es besser als die App, gewinnt die Runde, und
  wer dafür getrunken hat, bekommt den Schluck zurück. Ohne ihn tränke
  jemand für einen Tippfehler.

- **Die Hitparade spielt selbst, aber verrät nichts** (29. Oktober,
  Entscheidungen des Nutzers: Name „Hitparade“, Hörprobe statt Spotify,
  erst einmal ohne Joker).
  - **Abgespielt wird Apples 30-Sekunden-Hörprobe** (`SongPreviewPlayer`),
    ohne Abo, Konto oder fremde App. Ein Spotify-Link vor dem Aufdecken
    ginge nicht: Die Spotify-App zeigt sofort den Titel, und unsichtbar
    abspielen ginge nur mit Premium, installierter App und eigenem
    Entwicklerkonto bei Spotify. Spotify gibt es deshalb erst **nach** dem
    Aufdecken, als Suche zum Weiterhören.
  - **Vor dem Aufdecken steht nirgends Titel, Interpret, Cover oder Jahr**,
    auch nicht für VoiceOver. Das Etikett auf dem Plattenspieler bleibt
    schwarz, das Cover kommt erst mit der Hülle beim Aufdecken.
  - **Im Repository steht je Lied nur Apples Nummer** (`SongCard.appleId`),
    nie Musik. Die Adresse der Hörprobe wird am Tisch geholt, weil Apple
    sie ändern kann. Ein Test verlangt für jedes Lied eine eigene Nummer.
  - **Neue Lieder bekommen ihre Nummer über `scripts/find_song_ids.py`.**
    Das Skript nimmt nur passende Treffer ohne Live-, Remix-, Karaoke- und
    Cover-Fassung, schreibt die Nummer in den Stapel und ändert das Jahr
    nie selbst. Apple sperrt bei zu vielen Anfragen minutenlang, aus der
    Sitzung heraus kam am 29. Oktober kaum ein Lied durch. Deshalb läuft es
    als von Hand gestartete Action (`song-ids.yml`), und die Zeilen aus
    ihrem Log werden übernommen und gelesen.
  - **Während des Lieds eine andere Tonsitzung**: `.playback`, damit es auch
    bei stummgeschaltetem iPhone läuft – die Musik ist hier der Inhalt und
    keine Zierde. Danach zurück zu den App-Klängen
    (`SoundManager.useAmbientSession`, an einer Stelle beschrieben).
  - **Ohne Hörprobe geht es trotzdem weiter**: im Vorspann „Box“ wählen,
    oder im Zug „Über die Box spielen“. Dann sieht der Nachbar Titel und
    Interpret und spielt das Lied an, wie vor dem 29. Oktober. „Anderes
    Lied“ tauscht nur das Lied, ohne Strafe.
  - **Gefragt wird, was angehakt ist, und reihum gelost**
    (`HitparadeGame`, reine Rechnung mit Tests). Die Frage von eben kommt
    gedämpft wieder, nicht verboten – sonst wechselten sich zwei angehakte
    Fragen stur ab. **Titel und Interpret entscheidet die Runde**, getippt
    wird nicht: Am Tisch dauert Tippen zu lange, und an „feat.“ oder „The“
    scheiterte eine richtige Antwort. Jahre zählen **einschließlich** der
    Grenze – drei Jahre daneben ist bei ± 3 noch richtig.
  - **Im Katalog heißt der Fall weiter `timeline`** (siehe „Ein Spiel
    umbenennen“), der Screen dagegen `HitparadeView` – der alte Name
    verdeckte SwiftUIs Zeitleiste (Lessons Learned Nr. 15).

- **Die Partyspiele sind Verlierer-Spiele** (22. Oktober). Schocken
  rechnet aus, wer alle Deckel hat, die Bombe, wer draufsitzt, das Turnier,
  wer die Runde verloren hat – wer *gewonnen* hat, weiß keines von ihnen.
  Ein Pokal, der Siege zählt, hätte deshalb fast nichts zu zählen. Der Weg
  dorthin ist **nicht**, in jeder einzelnen Ansicht einen Sieger zu
  erfinden, sondern ihn dort anzutippen, wo der Abend ohnehin steht: Jede
  Zeile unter „Gespielt" öffnet `WinnerPickerView`. Spiele, die ihren
  Sieger selbst kennen (Beerpong, Hitparade), melden ihn weiterhin von
  allein; dort lässt er sich nur korrigieren.

- **Ein Sieg gehört einer PERSON, nicht einem Text** (22. Oktober).
  `EveningEntry.winner` ist eine Zeile zum Anzeigen („Lena & Jan"); für die
  Wertung zählt `winnerIds`. Vorher zählte die App den Text, und ein
  2-gegen-2-Sieg ging damit an einen Namen, den es nicht gibt – beide
  Spieler standen bei null. Was ein Sieg wert ist, steht als `points`
  **im Eintrag** und wird nicht später aus dem Katalog geholt: Ein Abend
  von letztem Monat soll so ausgewertet werden, wie er gespielt wurde
  (dieselbe Regel wie bei der Sicherungsdatei). Nachgetragen wird über
  `EveningLog.recordWinner(positions:for:)` an den Eintrag, der beim
  **Betreten** des Spiels entstanden ist – deshalb trägt der Eintrag auch
  `gameId`. Ein zweiter Eintrag beim Gewinnen würde dasselbe Spiel doppelt
  in den Abend schreiben.

- **Was nebenher läuft, gehört nicht in den View-Zustand** (18. Oktober).
  Die Regeln des Abends stapeln sich und gelten weiter, während die Runde
  Ring of Fire spielt – also liegen sie in UserDefaults
  (`ActiveEveningRules`) und nicht in `@State`. Mit `@State` wäre der Tisch
  nach dem Zurückkommen regellos, obwohl am echten Tisch alles weiter galt.
  Gespeichert wird der **Text** der Regel, nicht ihr Platz im Stapel: Ein
  Stapel wächst und wird umsortiert, eine Nummer zeigte danach auf eine
  andere Regel, ohne dass es jemandem auffiele. Aus demselben Grund hat das
  Spiel **eine** Strafe für alle Regeln und nicht eine je Karte – sonst
  müsste die gespeicherte Regel ihren Preis mitbringen.

- **Wer heute mitspielt, steht in `TableRoster`** – und kommt über
  `\.tablePlayers` in der SwiftUI-Umgebung bei den Spielen an, nicht als
  Parameter an `PartyGame.destination`. Sonst müsste jedes Spiel die Liste
  annehmen, auch die große Mehrheit, die sie nicht braucht. Wichtig:
  **Leer ist ein gültiger Zustand** – wer keine Profile hat, spielt ohne
  Namen weiter. Beide Wege müssen im Spiel stehen, nicht nur der schöne.
  Nicht zu verwechseln mit `PlayerProfile.isActive`: Das heißt „gehört noch
  zur Truppe" und gilt für Monate, die Aufstellung heißt „ist heute da".

- **Der Spielscreen besteht aus fünf Teilen, nicht aus einem** (18.
  Oktober). `LiveGameViewModel` hält nur noch den Zustand, den Undo-Verlauf
  und die Reihenfolge. Daneben liegen: `LiveGameNaming` (wie Leute und
  Teams heißen), `LiveGameNarrator` (Protokollzeile und Einblendung zu
  einem Ereignis – reine Rechnung, ohne Gerät prüfbar),
  `LiveGameFeedback` (Rütteln und Klang, reine Nebenwirkung),
  `ExtremeCardDealer` (welche Becher geladen sind) und `LiveGameSync` (alles
  zum Wurf-Log, samt Warteschlange). Der Schnitt verläuft zwischen **Satz
  und Nebenwirkung**: Vorher entstanden die Einblendungstexte in derselben
  Funktion, die Haptik auslöste – ein Satz ließ sich nicht ändern, ohne am
  Gerät zu prüfen, ob dabei das Rütteln heil bleibt. Jetzt hängen an beiden
  neuen Werten Tests, die es vorher nicht geben konnte.

- **Ein fehlgeschlagener Schreibvorgang darf nicht verpuffen.** Der
  Wurf-Log ist die Wahrheit; fehlt dort ein Eintrag, läuft die
  nachgespielte Partie dauerhaft anders als die gespielte. Scheitert das
  Schreiben, merkt sich `LiveGameViewModel` den Vorgang und reicht ihn auf
  Knopfdruck nach. Das geht nur, weil die laufende Nummer im mitgegebenen
  Spielzustand steckt und nicht in der Uhrzeit des Schreibens – ein
  Eintrag darf beliebig später kommen. **Jeder liegengebliebene Eintrag
  merkt sich seine Partie** (`LiveGameSync`): Vorher lagen Warteschlange und
  Spielkennung getrennt, eine Revanche schrieb die Kennung um – und ein
  nachgereichter Wurf der Vorpartie wäre in den Log der NEUEN Partie
  gelaufen. Nachgespielt hätte die Revanche einen Treffer enthalten, den es
  nie gab.

- **Eine Partie anlegen heißt `createAndStart`.** Es gibt zwei Wege in eine
  Partie (Neues Spiel und „Nochmal dieselben"); beide gehen durch dieselbe
  Funktion, die auch die Aufstellung für den Schnellstart merkt. Eine
  zweite Kopie hätte garantiert irgendwann vergessen, die Partie zu
  starten.

- **Freier Platz ist kein Design** (17. Oktober). In sechs Spielen stand
  zwischen der Karte und den Knöpfen ein `Spacer`: Die Karte blieb so klein
  wie ihr Text, und auf einem großen Gerät lag die Hälfte des Screens leer.
  Der Platz gehört dem Inhalt – die Karte bekommt `maxHeight: .infinity`,
  die Spacer wandern nach INNEN und halten den Text in ihrer Mitte.
  Umgestellt sind Bussfahrer, Schätzmeister, Ich hab noch nie, Wahrheit oder
  Pflicht, Wer würde eher? und Kennst du deine Leute?. Bei den Letzteren,
  die in einem `ScrollView` liegen, braucht es zusätzlich ein
  `frame(minHeight: geometry.size.height)` – ohne eine bestimmte Höhe hat
  `maxHeight: .infinity` nichts, in das es wachsen könnte.

  **Und eine Ebene höher: `FillingScrollView`** (25. Oktober). Siebzehn
  Screens standen als `ScrollView { VStack { … } }` da, und ein ScrollView
  legt seinen Inhalt nach **oben**. Bei langem Inhalt fällt das nicht auf;
  bei kurzem – der Spion in der Vorbereitung, Schocken zwischen zwei
  Würfen, der Sieger im Turnier – klebte alles am oberen Rand und die
  untere Hälfte blieb leer. Der Baustein macht genau das, was oben als
  Rezept steht (GeometryReader plus `minHeight`), aber **an einer Stelle**:
  An der Aufrufstelle steht nur ein anderer Name als `ScrollView`, sonst
  nichts. Wer das siebzehnmal selbst tippt, tippt es irgendwo nur halb.
  Zwei Listen, die von oben gelesen werden, geben `alignment: .top` an (der
  Abend-Rückblick und die eigenen Karten) – die gewinnen nur das
  Ausfüllen in der Breite. `verticalScrollOnly()` steckt im Baustein; an
  den umgestellten Aufrufstellen ist es deshalb weg.

- **Jedes Spiel hat seine eigene Welt** (`DesignSystem/Worlds/`).
  Entscheidung des Nutzers vom 28. Oktober: „Im Moment sieht jedes Spiel
  sehr ähnlich aus.“ Bis dahin lag unter jedem Spiel derselbe Blasengrund,
  der Inhalt auf derselben Glasfläche mit Neonkante, in derselben runden
  Schrift – nur die Lichtfarbe wechselte, und davon gab es fünf für
  fünfundzwanzig Spiele. Das Vorbild sind die Party Packs von Jackbox:
  jedes Spiel in eigenem Stil, geteilt wird nur der Rahmen.
  - **Gerüst und Welt sind getrennt.** Gleich bleiben Navigation, Knöpfe,
    Vorspann, Weitergeben, Anleitung, Härte, Abend und Bilanz – im
    Verhalten. Jede Welt (`GameWorld`) bringt Grund, Fläche, Kante und
    Schrift mit. **Die geteilten Bausteine lesen die Welt selbst**
    (`\.gameWorld` in der Umgebung): `AmbientBackdrop` zeichnet ihren
    Grund, `glassPanel` ihre Fläche, `neonEdge` ihre Kante,
    `GameSetupScreen` und `HandoffPanel` ihre Schrift. Kein Spiel muss
    dafür etwas tun, und keines kann es vergessen. In Menüs ist keine Welt
    gesetzt – sie bleiben im Rahmen der App. Einzige Ausnahme sind die
    Spielkacheln in den Ordnern: Sie tragen den Grund ihrer Welt als
    **stillen Deckel** (`WorldGround(…, moves: false, fillsScreen: false)`)
    und den Titel in ihrer Schrift. Man soll das Spiel erkennen, bevor man
    es aufmacht – still, weil eine Liste, in der überall etwas läuft, sich
    nicht mehr liest. „Schlicht“ gilt auch für den Deckel.
  - **Die Welt steht im Katalog** (`PartyGame.world`, vollständiges
    `switch`), gesetzt in `PartyGame.destination` – auch für den Vorspann.
    Auslosen und Turnier sind kein Spiel, haben aber einen eigenen Ort
    (Abfahrtstafel, Stadion).
  - **Satz-Regel, eine Ebene höher**: Jede Welt lässt sich in einem Satz
    sagen, ohne Emoji, kein Satz kommt doppelt vor, und keine zwei Spiele
    teilen sich eine Welt (`GameWorldTests`).
  - **Dunkler Grund, dunkle Flächen.** Schrift und Deckkräfte sind auf
    Dunkel gerechnet. Hell dürfen nur Gegenstände sein (Spielkarte, Akte,
    Bingoblatt) – mit eigener, fester Tinte.
  - **Grün und Rot behalten ihre Bedeutung.** Eine Kante in Erfolgs- oder
    Fehlerfarbe bleibt so; jede andere Farbe war nur die Farbe des Spiels
    und weicht der Welt (`GameWorld.edgeColor`).
  - **Die Einstellungen gelten weiter.** Das Farbschema rahmt die App
    (Knöpfe, Navigation, Menüs); in der Welt haben Dinge ihre eigene Farbe,
    wie Bier. „Hintergrund“ heißt in einer Welt, wie viel los ist:
    Schlicht ist die Grundfarbe, Ruhig die Textur, Blasen dazu die leise
    Bewegung der Welt. Neonkanten gelten für den Rahmen.
  - **Text steht nach spätestens einer halben Sekunde.** Rückmeldung des
    Nutzers zur Vorschau: Manche Schriften brauchten zu lange, um
    dazustehen. Bewegung darf drumherum weiterlaufen, aber niemand wartet
    aufs Lesen.
  - **Nur Systemschriften**, über `Font.scaled(…, width:)` auch schmal oder
    breit – keine Schriftdatei, keine Lizenzfrage, die Systemgröße gilt.
    Breite Schriften brauchen Platz: Ein Spieltitel läuft deshalb über
    `keepsWordsWhole` – Umbruch nur zwischen Wörtern, sonst wird er
    kleiner. Ohne das stand in der Kachel „Schätzmeiste“ über einem „r“.
  - **Texturen werden einmal gezeichnet** (`WorldGround` ist
    gleichsetzbar, ein Tastendruck rechnet den Grund nicht neu), leise
    Bewegung höchstens mit 30 Bildern je Sekunde.
  - **Die Dinge einer Welt liegen neben ihrem Grund**, eine Datei je Welt
    in `DesignSystem/Worlds/` (`SecretFile`, `NightBus`, `Casino` …). Die
    Spiele benutzen sie und zeichnen nicht selbst. Geteilte Bausteine
    ziehen sich in einer Welt selbst um: `HandoffPanel` ist beim Spion eine
    Akte (`Dossier`) und bei Verbotene Wörter ein abgeklebter Zettel
    (`TapedCard`). Das Verhalten bleibt an einer Stelle, nur das Kleid
    wechselt.
  - **Verdeckt heißt: nicht gebaut.** Was eine Karte noch verbirgt – die
    Rolle beim Spion, das Wort unter dem Klebeband –, entsteht erst, wenn
    es aufgedeckt ist. Bloß überdeckt, liest VoiceOver es trotzdem vor.
  - **Die Satz-Regel der Szenen gilt auch für Beerpong**: Umstellen,
    Redemption und Trickshot haben je eine eigene Bewegung statt eines
    gemeinsamen einfliegenden Symbols (`HighlightOverlayView`).

- **Jede Szene hat ihre eigene Bewegung**
  (`DesignSystem/Components/DrawnScenes.swift`). Entscheidung des Nutzers
  vom 27. Oktober, nach dem Test am Tisch: „Die sehen alle gleich aus, nur
  mit anderen Emojis.“ Zweimal ist es an derselben Stelle gescheitert –
  erst eine Flugbahn mit dreizehn Emoji, dann Schichtungen aus denselben
  vier Bausteinen, wieder mit dreizehn Emoji. Ein anderes Zeichen auf
  derselben Bahn ist keine andere Szene.
  Deshalb gilt die **Satz-Regel**: Jede Szene lässt sich in einem Satz
  beschreiben, **ohne ein Emoji zu nennen**, und kein Satz kommt zweimal
  vor. Für die Ränge von Ring of Fire stehen die Sätze im Code
  (`RingScene.motion`), und `RingSceneTests` hält fest, dass kein Rang seine
  Bewegung mit einem anderen teilt. Fällt einem für eine neue Szene kein
  eigener Satz ein, ist es keine neue Szene.

  Eine Szene ist eine Zeichenfunktion in `SceneArt`, gezeigt von
  `EffectCanvas` (Leinwand plus Zeitleiste) – alle sind derselbe Typ, ein
  `AnyView` braucht es dafür nicht mehr. Teilchen, Druckwelle, Strahlen und
  Einschlag sind **entfernt** und nicht bloß unbenutzt: Ein Baustein, der
  nur Gleichheit erzeugen kann, wird beim nächsten Mal wieder genommen,
  weil er bequem daliegt. In `VisualEffects.swift` geblieben sind
  `EffectConfetti` und `EffectFlash`. Szenen stehen hinter
  jeder Ring-Karte, im Sieger-Screen (Feuerwerk und Konfetti, nur bei einem
  Sieger, nie beim Unentschieden), in der Bombe (Rauch und Splitter, einmal),
  beim Sieg in der Hitparade (eine Schallplatte), am Pokal des Abends (ein
  Goldglanz, leise – er steht in einer **Liste**, und eine Liste, in der an
  mehreren Stellen etwas fliegt, liest sich nicht mehr) und im leeren Ring,
  wenn eine Runde Ring of Fire durch ist (ein Flammenkranz, `RingFinale` –
  bewusst kein zweites Feuerwerk, das gehört dem Beerpong-Sieg).

  **Dieselbe Kostenart sieht überall gleich aus.** Ein Shot glüht wie das
  Ass, Schlücke steigen als Bier wie bei der Drei, wer nichts trinkt, atmet
  in Grün auf. Im Trink-Roulette hängt die Szene deshalb an der
  **Kostenart** und nicht am Text – so bekommt auch ein selbst gebautes Rad
  sie. Diese Sprache lernt man einmal, nicht je Spiel; das ist die eine
  Stelle, an der zwei Momente bewusst gleich aussehen.

  Die Regeln, jede mit Grund:
  - **Zierde, kein Inhalt.** Alles liegt hinter dem Text, nimmt keine
    Tipps an und ist für VoiceOver unsichtbar. **Wie laut, hat der Nutzer
    entschieden** (26. Oktober, zweimal verlangt): „fällt auf“ statt
    „stört nicht“ – das Leise war auf einem Handy in der Tischmitte aus
    anderthalb Metern unsichtbar. Die Grenze ist weiter hinten, aber
    dieselbe: Der **Text muss lesbar bleiben**. Kräftig darf sein, was am
    Rand oder unten liegt; was durch die Mitte geht, bleibt blass.
  - **Gerechneter Zufall** (`EffectNoise`). Mit `Double.random` springt
    alles bei jedem Neuzeichnen woandershin – und gezeichnet wird jedes
    Bild neu.
  - **Nichts läuft weiter, wenn der Screen weg ist.** Szenen zeichnen auf
    einer Zeitleiste, die mit der Ansicht verschwindet; was einmalig ist
    (die Explosion), hält danach an (`lasts`). Konfetti und Blitz tragen
    ihre Bewegung in den Modifiern. Kein Timer, keine Task-Schleife.
  - **Bewegung reduzieren** zeigt ein stilles Bild aus der Szene
    (`stillAt`) – nicht nichts, sonst fehlt die Farbe, die zum Moment
    gehört.
  - **`EffectFlash` hängt an einem WERT von draußen**, nicht an
    `onAppear` – ein Blitz gehört zu einem Ereignis. Und er merkt sich den
    Wert statt ein Ja/Nein, sonst blitzt er genau einmal pro Screen
    (Lessons Learned Nr. 11).

  **Der Riss hat seinen eigenen Moment** (`RingEmbers.swift`, Wunsch des
  Nutzers vom 28. Oktober: „erst eine einzelne Animation, die klar macht,
  dass der Kreis gerissen ist – man soll nachvollziehen können, wo“).
  Vorher schob sich der Kartenscreen sofort über den Ring, und eine
  Feuerwand schlug an seinem Rand herein – mächtig, aber die Stelle sah
  niemand. Jetzt gehören dem Ring 1,6 Sekunden: Der Glutfaden reißt an der
  Lücke, eine Stichflamme schlägt heraus, die Nachbarkarten zucken weg,
  alles wird dunkel bis auf die Stelle, und „RISS“ steht über der Lücke.
  Erst danach kommt die Karte. Der Moment liegt über dem **ganzen** Screen,
  nicht nur über dem Ring; der Ring meldet seine Lage als Anker nach oben
  (`RingTearSpotKey`), weil er in einem ScrollView liegt und seine Punkte
  sonst niemand kennt. Die Feuerwand (`EffectFlames`) ist entfernt, nicht
  nur unbenutzt, und die Rang-Szene läuft auch nach einem Riss wieder.
  Eine Falle aus dem Bau ist geblieben: Generische Typen dürfen keine
  statischen gespeicherten Werte haben, und `check.py` sieht das nicht.

  **Und die Karte selbst tritt je Rang anders auf** (`RingCardEntrance`,
  Wunsch des Nutzers vom 28. Oktober: „noch mehr voneinander ab, sodass es
  abwechslungsreicher ist“). Die Szenen waren schon verschieden, aber das
  Größte auf dem Screen – die Karte – kam bei allen dreizehn Rängen gleich,
  federnd aus 70 Prozent. Jetzt steckt die Zwei wie ein Pfeil, die Zehn
  knallt auf wie ein Stempel, der König wirbelt wie eine Münze. Es gilt
  dieselbe Satz-Regel (`RingCardEntrance.motion`, `RingCardEntranceTests`),
  dazu drei Regeln, jede mit Test:
  - **Reine Rechnung.** `pose(at:)` liefert für den Fortschritt eine Pose,
    `RingCardEntering` zeigt sie nur an. Die Animation selbst ist linear –
    eine Kurve darüber verböge die Rechnung.
  - **Ende ohne Ruck, Anfang verborgen.** Jeder Auftritt endet genau auf
    dem Platz und ist kurz davor schon fast dort. Am Anfang ist die Karte
    unsichtbar oder weit draußen, denn währenddessen fährt der Screen herein.
  - **Lesbar nach gut einer halben Sekunde.** Was danach kommt, ist
    Nachschwingen. Wer sich überschlägt, zeigt zwischendurch die
    **Rückseite** (`CardPose.showsBack`) – sonst stünde die Karte halb
    spiegelverkehrt da. Beide Seiten liegen immer da, nur eine ist zu
    sehen; ein `if` baute die Karte mitten in der Drehung neu.

  **Szene, Auftritt und Rangklang warten, bis der Kartenscreen fast steht**
  (`RingOfFireActionView.settle`). Er fährt als Vollbild von unten herein,
  und was in dieser Bewegung beginnt, sieht niemand – ausgerechnet der
  Anfang, an dem man den Rang erkennt. Der Text steht trotzdem sofort da.
  `EffectCanvas` kann dafür seit diesem Tag später loslaufen (`delay`).
  Am selben Tag sind Jungs und Mädels kein Spiegelpaar mehr: Blitze und
  Glitzer statt derselben Bläschen von links und von rechts.

- **Kartengrößen rechnen, nicht tippen.** Bussfahrer zeigte seine Karten in
  festen 68 Punkten, egal wie breit das Gerät war. Jetzt teilen sie sich die
  verfügbare Breite (mit Deckel bei einem Viertel, sonst wird die Reihe
  höher als alles darunter) – dasselbe Prinzip wie beim Ring, wo die
  Kartenbreite aus dem Layout folgt.

- **Die Palette ist zweigeteilt** (`DesignSystem/Colors.swift`): Akzente
  und Hintergründe kommen aus `AppPalette` und sind wählbar, Schrift,
  Statusfarben und Becher aus dem Asset-Katalog und gelten immer. Alle
  Schemata sind **dunkel** – die Schrift und sämtliche Deckkräfte sind
  dafür gerechnet. Ein helles Schema ist kein fünftes Schema, sondern der
  Hell-Modus.

- **Feste Schriftgrößen nur noch für Emoji.** Textstile gehen über
  `Font.scaled(…)`, damit sie der Systemeinstellung folgen; Emoji in
  Rahmen fester Größe bleiben fest, sonst laufen sie über. Die Datei
  `BeerpongActivityAttributes.swift` gehört zum **Widget-Ziel** und sieht
  `DesignSystem` nicht – dort geht `scaled` nicht.

- **„Wer ist dran?" steht in `TurnRow`** (18. Oktober). Sechs Spiele sagten
  es nicht – die App reichte das Handy weiter und die Runde diskutierte, wer
  jetzt muss; bei „Ich hab noch nie" ist das nach drei Karten eine echte
  Frage. Die Spiele zählen nur, wie oft sie weitergegangen sind;
  `PlayerNames.nameForTurn` macht daraus einen Namen (modulo der Leute,
  gleiche Quellen-Reihenfolge wie überall). **Steht niemand fest, ist die
  Zeile weg** – nicht „Spieler 3 ist dran", das hilft niemandem, der nicht
  weiß, wer die Drei ist. Zwei Feinheiten, die beide in einem Kommentar am
  Zähler stehen: Bei „Ich hab noch nie" zählt eine **Strafkarte nicht**
  weiter (sie trifft alle, danach liest dieselbe Person), und beim
  Bussfahrer zählt sie nur nach einer **geschafften** Hand – nach einem
  Fehler fängt dieselbe Person von vorne an.

- **Beerpong nennt seine Teams nach den Leuten** (18. Oktober), nicht
  „Team 1". Die Zeichenarbeit liegt in `Team` und ist getestet, weil mit den
  Namen die **Grammatik** dazukommt: „Lena wirft nochmal", aber „Lena & Jan
  WERFEN nochmal". Alle zehn Sätze gehen über `teamVerb(_:_:_:)`. Für enge
  Stellen – die Team-Leiste neben dem Fortschrittsbalken und den
  Sperrbildschirm – gibt es `shortDisplayName` („Maximilian & K.").

- **Namen in Partyspielen laufen über `PlayerNames`**, und die Reihenfolge
  der Quellen ist Pflicht, nicht Geschmack: **laufender Abend, sonst Tisch,
  sonst „Spieler 3"**. Die Trinkbilanz ist auf die Positionen des Abends
  gebucht – käme der Name von woanders, hieße Position 3 im Spiel jemand
  anderes als Position 3 in der Bilanz, und die Bilanz wäre falsch, ohne
  dass es auffiele. Ein Test hält das fest. Die Namen des Tisches liegen als
  Schnappschuss in UserDefaults, weil ein Partyspiel kein Repository kennt
  und auch keins bekommen soll.
  **Gebucht wird über `EveningLog.record(_:forPlayer:)`** – die Funktion
  steht zwar in der Datei `PlayerNames.swift`, gehört aber zu `EveningLog`.
  Wer nach dem Dateinamen greift, schreibt `PlayerNames.record` und merkt
  es erst im Actions-Lauf; `check.py` ist kein Compiler. Und gebucht wird
  die **Position**, nicht der fortlaufende Zähler eines Spiels –
  `PlayerNames.position(forTurn:)` rechnet das um. Ein Spiel, das seinen
  Zähler direkt bucht, schreibt ab der zweiten Runde ins Leere.

- **Einstellungen vor dem Spiel gehören in `GameSetupScreen`**, die Auswahl
  aus wenigen Werten in `ChoiceRow`, eine Spielkachel in `PartyGameCard`,
  die Zeile „Wie lange / Strafe" in `TermRow`, die leise Nebenhandlung
  („Neu mischen", „Spielerzahl ändern", „Rückgängig") in `QuietButton`.
  Alles geteilte Bausteine wie `PlayerCountStepper` und `HandoffPanel` –
  wer einen eigenen baut, lässt ihn anders aussehen. `TermRow` war die
  zweite Kopie, `PartyGameCard` die zweite Stelle, an der man das Vermerken
  im Abend vergessen kann, `QuietButton` stand vierundzwanzigmal da – und
  jedes Mal ohne Trefferfläche (siehe Lessons Learned Nr. 12).

- **Anleitung und Untertitel stehen im Katalog**, nicht im Spiel
  (`PartyGame.howToPlay`). Im Spiel stünden sie in so vielen Formen, wie
  es Spiele gibt, und ein neues hätte sie garantiert nicht.

- **Extreme-Karten tragen Dauer und Strafe als eigene Felder**, nicht im
  Text. Die Dauer steht auf jeder Karte, auch wenn sie „Sofort" lautet; die
  Strafe fehlt nur dort, wo es nichts zu brechen gibt. Drei Tests halten das
  fest, einer davon: Jede Challenge muss sagen, was Verweigern kostet – ohne
  das ist sie eine Bitte.

- **Kartenspiele tragen den ganzen Satz auf der Karte**, nicht nur den
  Nachsatz. Ein fester Vorspann („Ich hab noch nie …") kann grammatisch
  nicht aufgehen: Es gibt „Ich bin noch nie …" und „Ich hatte noch nie …".

- **Ein Thema ist keine Stufe** (`NeverHaveIEverCategory.direction`). Bei
  „Ich hab noch nie“ gab es nur eine Achse, und wer einen Abend lang
  spielte, landete zwangsläufig bei Sex. Seit dem 28. Oktober gibt es zwei
  Richtungen: wie hart (Kinder bis Tabulos) und worum es geht (Peinlich,
  Party …). Der Vorspann zeigt sie als zwei Gruppen, gemischt wird aber
  alles, was angehakt ist – „Peinlich“ ist nicht zahmer als „Extrem“,
  sondern etwas anderes. Eine neue Kategorie ist ein neuer Fall samt
  Richtung und Liste, und ein Test verlangt, dass sie allein eine Runde
  trägt. „Tabulos“ heißt deutlicher und persönlicher, nicht derber – und
  nie auf Kosten von jemandem, der nicht gefragt wurde.

- **Einstellungen mitten in der Runde: das Zahnrad** (`RoundSettings.swift`,
  Wunsch des Nutzers vom 28. Oktober). Oben rechts sitzt während der Runde
  ein Zahnrad, das ein Blatt mit den Einstellungen des Spiels öffnet –
  bisher bei „Ich hab noch nie“. Zwei Regeln, damit es in jedem Spiel gleich
  bleibt: Im Blatt stehen **dieselben** Schalter wie im Vorspann (eine
  Eigenschaft, zwei Orte – zwei Kopien liefen auseinander), und das Blatt
  sagt, **wann** die Änderung gilt. Bei „Ich hab noch nie“: ab der nächsten
  Karte; die Karte, die gerade dasteht, bleibt, und gespielte Fragen kommen
  nicht wieder (`shuffled(…, excluding:)` nimmt sie heraus, bevor die
  Strafen verteilt werden – sonst lägen zwei Strafen hintereinander).

- **Jede Karte leuchtet anders, aber Rot gehört den Strafen**
  (`NeonSign.Look`, 28. Oktober: „mehr Abwechslung, ändere zum Beispiel
  die Farben der LEDs“). Farbe, Kopfzeilenfarbe, Rahmen (Röhre, Doppelröhre,
  Pille, Lauflicht, Ecken) und Schrift wechseln von Karte zu Karte. Gerechnet
  aus der **Stelle im Stapel**, nicht gewürfelt: Die Zyklen sind
  teilerfremd lang, zwei Karten hintereinander leuchten nie gleich – auch
  nicht mit einer Strafe dazwischen –, und ein Neuzeichnen ändert nichts.
  Rot und alles nah an Rot fehlt in den Farben der Aussagen; eine Strafe
  sieht immer gleich aus (`Look.penalty`), sonst liest jemand eine Frage als
  Anweisung. `NeonSignTests` hält beides fest.

- **Die Stapel sind getestet, nicht nur geschrieben** (`DeckContentTests`).
  Inhalt wächst oft und wird selten geprüft, und beim Nachlegen passieren
  immer dieselben zwei Dinge – beide fallen beim Spielen **nicht** auf:
  Eine Karte steht zweimal drin (am Tisch denkt man „hatten wir die nicht
  schon?" und spielt weiter; der Stapel ist stillschweigend kleiner als er
  aussieht), oder eine Karte passt nicht in ihre Form – ein ganzer Satz, wo
  ein Begriff hin muss („Wer bin ich?" ist mit einem Satz an der Stirn
  nicht spielbar), zwei Wörter, wo eines verboten werden soll. Der Test
  prüft Doppelte, Mindestzahlen und die Form je Stapel. Die Mindestzahlen
  stehen bewusst **unter** dem Stand: Sie sollen ein Löschen merken, nicht
  jedes Nachlegen zur Teständerung machen. Beim Nachlegen vom
  13. Oktober hat er sofort zehn Doppelte gefunden, die ich selbst
  eingetragen hatte.

- **Zahlen über Stapelgrößen werden gerechnet, nicht getippt.** Drei
  Untertitel nannten feste Zahlen („90 Karten", „150 Fragen", „50 Fragen")
  und waren nach dem ersten Nachlegen falsch. Sie kommen jetzt aus den
  Stapeln selbst (`TruthOrDareDeck.count`, `NeverHaveIEverDeck.statements`,
  `EstimationDeck.count`), und ein Test hält das fest – dieselbe Falle wie
  beim Spielezähler weiter oben.

- **Geteilte Bausteine benutzen, nicht neu tippen.** Zwei Sachen standen
  mehrfach fast gleich im Projekt und sind inzwischen je eine Komponente:
  `PlayerCountStepper` (die Spielerzahl einstellen, stand fünfmal da) und
  `HandoffPanel` (Handy übernehmen → aufdecken → weitergeben, stand
  zweimal da). Beide waren bereits auseinandergelaufen, bevor sie
  zusammengelegt wurden – unterschiedliche Größen, Radien, Ausrichtungen.
  Wer ein Spiel baut, das eines von beidem braucht, nimmt die Komponente.

- **Das Ergebnis als Bild** (`ShareCard`, 18. Oktober). Alles, was die App
  nach außen gab, war Text. Ein Bild landet dagegen in der Gruppe – und das
  holt die Runde am nächsten Abend wieder in die App. Zwei Stellen haben es:
  der Sieger-Screen und der Abend-Rückblick (dort **zusätzlich** zum Text,
  denn Text lässt sich vorlesen, suchen und in zehn Jahren noch öffnen).
  Drei Entscheidungen, die man beim Nachbauen wissen muss:
  - **Feste Schriftgrößen** – die einzige Stelle, an der das richtig ist.
    Mit `Font.scaled` würde die Systemeinstellung des Absenders bestimmen,
    wie der Empfänger das Bild sieht.
  - **Kein `AmbientBackdrop`**, sondern ein einfacher Verlauf: Der
    App-Hintergrund streut zufällige Blasen und liest Einstellungen; beides
    gehört nicht in ein Bild, das Bestand haben soll. Die `CupShape` bleibt
    als Wasserzeichen.
  - **Einmal rendern, nicht im `body`.** Das Bild ist 1620 × 2025 Pixel, und
    der Sieger-Screen zeichnet beim Übernehmen neu. Gerendert wird in
    `onAppear`, in einem `Task { @MainActor in … }` – `ImageRenderer` ist
    main-actor-isoliert und aus einer Ansichts-Eigenschaft heraus gar nicht
    aufrufbar. Scheitert es, bleibt der Knopf weg; eine Partie anzuhalten,
    weil ein Bild nicht geschrieben werden konnte, wäre die falsche
    Reihenfolge.

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

- **Beim Wiederherstellen ist der PLATZ im Team eine Aussage.**
  `DataImportService.remapped` übersetzt die alten Profil-Kennungen auf die
  neuen und behält dabei Länge und Reihenfolge – wer nicht in der Tabelle
  steht, behält seine alte Kennung. Sie zeigt dann auf kein Profil mehr,
  und das ist richtig so: Angezeigt werden die mitgesicherten Namen, und
  jede Auswertung sucht ihre Profil-ID in der Liste statt sie
  nachzuschlagen. Warum das keine Geschmacksfrage ist, steht in Lessons
  Learned Nr. 14. Dazu: Eine Partie, die sich nicht anlegen lässt, wird
  **übersprungen und gezählt**, nicht zum Abbruch des ganzen Laufs.

- **Zeitraum-Statistiken werden gerechnet, nicht gespeichert.** Die Werte am
  Profil sind Lebenszeit-Summen. Für „letzter Monat" spielt
  `ThrowRepository.aggregateStatistics` die Wurf-Logs der betroffenen
  Partien neu durch. Das gilt dadurch rückwirkend und rechnet Undos korrekt
  heraus – kostet aber Lesezugriffe, deshalb nur auf Anforderung.
- **„Kennst du deine Leute?" liest die Statistiken, schreibt aber keine.**
  Die Fragen entstehen aus den Kennzahlen am Profil
  (`KnowYourPeople.questions(for:)`), und zwei Grenzen entscheiden darüber,
  ob das Spiel fair ist: Eine Frage nach der Trefferquote gibt es erst, wenn
  **beide** genug geworfen haben, und überhaupt nur, wenn die Werte weit
  genug auseinanderliegen – fünf Prozentpunkte bei Quoten, zwei bei
  Zählwerten. Bei 48 gegen 47 Prozent gibt es keine richtige Antwort,
  sondern nur eine, die zufällig stimmt, und wer dafür trinkt, trinkt zu
  Unrecht. Solche Fragen entstehen deshalb gar nicht erst; Tests halten
  beide Grenzen fest. Die Strafe wird über die **Profil-ID** gebucht
  (`EveningLog.record(_:forProfileId:)`), nicht über die Position – die
  Aufstellung und die Teilnehmerliste des Abends müssen nicht dieselbe
  Reihenfolge haben.

- **Die Räder des Trink-Roulettes stehen im Katalog `RouletteWheel`**
  (25. Oktober), nicht in der Ansicht – dieselbe Entscheidung wie bei
  `PartyGame`. Ein fünftes Rad ist ein neuer Fall und sonst nichts. Zwei
  Dinge, die man beim Anfassen wissen muss. Erstens trägt ein Feld seine
  Menge als **`RouletteCost`** und nicht als Zahl im Text: Eine eingetippte
  „3 Schlücke" ignoriert die Härte stillschweigend. `RouletteCost` ist ein
  eigener, speicherbarer Typ, weil `DrinkAmount` einen zugeordneten Wert
  trägt und deshalb nicht `Codable` ist – und weil ein gespeichertes Format
  nicht am Anzeigetyp hängen soll (dieselbe Regel wie bei der
  Sicherungsdatei). Zweitens landet die Menge im Satz dort, wo **`{}`**
  steht; fehlt der Platzhalter, kommt sie als Anhang. Genau deshalb braucht
  der Editor für eigene Felder keine Schreibweise zu erklären – aber die
  **ausgelieferten** Felder müssen `{}` enthalten, und ein Test hält das
  fest: Der Anhang ist für die eigenen Felder gedacht, in einem fertigen
  Rad ist er Schlamperei. Das eigene Rad liegt in UserDefaults und ist erst
  **ab drei Feldern** spielbar: Mit zwei ist es eine Münze.

- **Ohne Konto läuft KEIN Firestore-Listener** (`GuestMode`). Das ist nicht
  nur sparsam: Ohne Anmeldung weist Firestore jeden Zugriff ab, und ein
  Listener, der dauernd abgewiesen wird, kostet Strom und schreibt Fehler
  ins Log. `HomeViewModel.currentUserId` ist deshalb optional und startet
  bei `nil` gar nichts erst. Gast ist ein **eigener** Zustand neben
  „abgemeldet": Abgemeldet heißt „will sich anmelden und ist noch nicht
  fertig", Gast heißt „will gar kein Konto" – beides führt an verschiedene
  Orte. Was ohne Konto fehlt, ist genau zweierlei: die Beerpong-Kachel
  (sie bleibt stehen und erklärt, warum – sie wegzulassen hieße, dass
  niemand sieht, dass die App Beerpong kann) und die Spieler-Zentrale (die
  ist **weg** statt grau; ein Symbol, das nichts tut, probiert man am
  Tisch dreimal).

- **Eine Strafe ist nicht zwingend ein Schluck** (`PenaltyStyle`). Vier
  Währungen: Trinken, Sport, Kasse, Aufgaben. Möglich war das als
  Zwei-Zeilen-Eingriff nur, weil Mengen nirgends als Zahl im Text stehen,
  sondern **alle** durch `DrinkAmount` laufen – es gibt genau eine Stelle,
  an der eine Menge zu einem Satz wird. Die Umrechnung ist bewusst grob
  (drei Stufen, deren Grenzen an **einer** Stelle stehen) und
  deterministisch: Würfelte die Aufgabe, stünde auf der Karte etwas
  anderes als in der Bilanz. Gebucht wird weiter in Schlücken und Shots –
  das ist die Währung, in der gebucht wurde, und ein alter Abend wird
  nicht nachträglich umgerechnet. Härte und Shot-Schalter verschwinden,
  solange nicht getrunken wird: Beide formulieren Schlücke aus und hätten
  nichts zu sagen.

- **Der Kommentator ist eine reine Rechnung** (`LiveGameCommentator`),
  genau wie der Narrator – Ereignis und laufende Nummer hinein, Satz
  heraus; gesprochen wird er woanders. Drei Regeln entscheiden, ob man ihn
  nach fünf Minuten abschaltet, und alle drei hängen an einem Test:
  **Nicht jedes Ereignis spricht** (Treffer und Fehlwurf nur gelegentlich,
  Verwaltung gar nicht, die großen Momente aber IMMER – hier hätte ein
  „nur jedes dritte Mal" an der falschen Stelle den wichtigsten Satz
  verschluckt), **mehrere Fassungen je Ereignis**, und die Fassung wird
  **gerechnet statt gewürfelt**: Sonst klänge derselbe Zug beim
  Nachspielen eines Logs anders als beim Spielen.

- **Der Abend startet sich selbst, aber nur mit Leuten**
  (`EveningLog.startIfNeeded`). Ein Abend ohne Teilnehmer kann nichts
  buchen und wäre eine Liste gespielter Spiele ohne Leute. Ein laufender
  Abend wird nie überschrieben, sonst wäre nach dem zweiten Spiel die
  halbe Bilanz weg. **Jede Buchung wird gemerkt** (`Evening.lastBooking`)
  und lässt sich ganz zurücknehmen – am Tisch vertippt man sich auf zwei
  Arten, falsche Menge und falsche PERSON, und die Minus-Taste am
  Teilnehmer heilt nur die erste. Gemerkt wird an **einer** Stelle: Beide
  Wege in die Bilanz (über die Position und über die Profil-ID) gehen
  durch dieselbe private Funktion, sonst ließe sich die eine zurücknehmen
  und die andere nicht.

- **Der Tischmodus gilt app-weit** (`TableMode`) und steht deshalb dort,
  wo die App zusammengesetzt wird. Große Schrift nur als **Untergrenze**
  (`.accessibility1...`): Eine feste Größe würde ausgerechnet denen die
  Schrift verkleinern, die sie größer gestellt haben. Möglich ist er
  überhaupt nur, weil die Textstile über `Font.scaled` laufen. Der
  Bildschirm bleibt dabei an und wird beim Verlassen der App wieder
  freigegeben.

- **Partyspiele zahlen nicht auf die Beerpong-Statistiken ein.** Eine Runde
  Bombe hat keine Trefferquote. Wer dort eine Wertung will, braucht einen
  eigenen Zähler, nicht `UserStatistics`.
- **Trinkmengen niemals als Zahl in den Text schreiben.** Sie laufen über
  `DrinkAmount` (`.sips(3)`, `.shot`) und werden erst beim Anzeigen in der
  geltenden Härte ausformuliert. Eine fest eingetippte Menge ignoriert die
  Einstellung stillschweigend – und genau so etwas fällt erst am Tisch auf.

- **Der Riss in Ring of Fire ist Rechnerei, nicht Zufall** (`RingLayout`).
  Das ist die Regel, die dem Spiel den Namen gibt, und sie hat drei
  Anläufe gebraucht – was dabei schiefging, steht in `git log`. Was gilt:

  **Gerissen ist der Ring, wenn von oben kein durchgehender Kreis mehr da
  ist.** Gerechnet wird mit den nächsten noch **liegenden** Nachbarn, nicht
  mit den Nachbarplätzen: Liegt links schon ein Loch und man zieht die
  Karte daneben, liegen danach zwei Kartenbreiten frei – und das ist ein
  Riss, auch wenn der Nachbarplatz leer war. Für **dieselbe** Lücke zahlt
  aber niemand zweimal, deshalb die Gegenprobe vor dem Zug: War der Ring
  an einer der beiden Seiten schon offen? Dann hat das jemand anderes
  bezahlt.

  **„Gerissen" heißt sichtbar gerissen** (26. Oktober, am Tisch gemeldet:
  „Es reißt, aber ich sehe keine Lücke"). Vorher reichte „die Nachbarn
  berühren sich nicht mehr" – und das ist genau der Moment, in dem die
  Lücke **null** ist. Die Regel feuerte also bauartbedingt, bevor es etwas
  zu sehen gab; nachgerechnet lag die Hälfte aller Risse unter einem
  Sechstel Kartenbreite. Seitdem gibt es eine Mindestbreite (`visibleGap`).
  Erst mit ihr ist mehr Überlappung unbedenklich: Ohne sie machte
  dichteres Legen den Spalt am Moment des Risses nur feiner, mit ihr macht
  es den Riss nur **seltener**, nie unsichtbarer. Darauf bauen zwei
  Entscheidungen des Nutzers: am 27. Oktober („reißt ein bisschen schnell
  – Karten größer, mehr Überlappung“) Überlappung und Streuung hoch, der
  Ring 12 pt je Seite näher an den Rand; am 28. Oktober („reißt fast immer
  innerhalb von 1–3 Karten“) die Schwelle von einer Viertel- auf eine
  **halbe Karte**. Die drei Zahlen hängen voneinander ab und werden nur
  zusammen angefasst; `RingLayoutTests` hält die Folgen fest.

  **Und die Lücke wird GEZEICHNET – als Glutfaden** (`RingLayout.links`,
  `RingEmbers`). Unter den Karten liegt ein glühender Faden. Wo sie sich
  überlappen, ist er verdeckt; in einer Lücke sieht man ihn. Unter der
  Schwelle hält er, wird aber dünner und unruhiger, je weiter die Lücke
  ist; an der Schwelle reißt er. Nötig ist das seit der halben Karte:
  Darunter entstehen Lücken, die nicht zählen, und ohne Faden sähe der
  Tisch dort ein Loch ohne Shot. Der Faden rechnet **nicht selbst**,
  sondern mit denselben Zahlen wie die Regel, und ob er reißt, entscheidet
  derselbe Vergleich (`Link.isOpen`, nicht über die geteilte Spannung –
  die rundet an der Schwelle anders). Ein Test hält fest, dass er genau
  dort reißt, wo `openings` eine offene Stelle meldet. Das ist der
  Gegenpol zum unsichtbaren Kartenplatz weiter unten – unsichtbar ist der
  Platz der **gezogenen Karte**, sichtbar die **Verbindung zwischen den
  Nachbarn**. Nach dem dritten Riss ist die Glut aus: Asche statt Faden.

  **Drei Risse kostet eine Runde, dann ist die Regel durch.** Nach den
  ersten beiden wird eingesammelt und neu gelegt (`relayout()`); danach
  bleibt der Ring liegen, wie er liegt, und die Lücken sind nur noch
  Spielstand. Der Deckel ist nötig, weil jede Lücke die nächste
  wahrscheinlicher macht – ohne ihn wäre der Riss eine Steuer, die den
  ganzen Abend mitläuft.

  **Drei Konstanten machen das Spiel**, alle durchgerechnet und per Test
  gedeckelt: `overlapFactor` sagt, wie viel breiter eine Karte ist als der
  mittlere Abstand zur Nachbarin, `jitter` streut die Abstände,
  `visibleGap` ist die Mindestbreite einer Lücke, die zählt. Ohne Streuung lägen alle Karten gleich dicht, und Ziehen wäre
  entweder nie oder immer gefährlich; mit Streuung gibt es dichte Stellen
  und dünne – und **man kann es sehen**. Die Größenordnung hält
  `RingLayoutTests` fest: wie oft es schon in den ersten drei Zügen reißt
  (die Zahl, an der die Entscheidung vom 28. Oktober hängt), wie viele
  Züge die drei Shots halten, und dass **jede Lücke, die zählt, mindestens
  so breit ist, wie die Schwelle verlangt**. Der letzte Punkt ist der
  Wächter: Fällt er, ist die Regel wieder unsichtbar, egal wie richtig sie
  rechnet. Die
  Karten werden mit der Überlappung größer und das Loch in der Mitte
  kleiner – die Restzahl dort hat Vorrang vor noch größeren Karten.

  Vier Feinheiten, die beim Anfassen alle einen Shot wert sind:
  - Die Abstände werden auf genau **360 Grad normiert**, sonst klafft
    zwischen der letzten und der ersten Karte eine Naht, die nie jemand
    gezogen hat.
  - Die **Kartenbreite folgt dem Layout**, nicht umgekehrt. Was man an
    Überlappung sieht, ist genau das, womit gerechnet wird – wer die
    Breite frei wählt, baut ein Bild, das lügt.
  - Der freie Platz einer gezogenen Karte ist **unsichtbar**. Als
    gestrichelter Umriss hat er die Regel unsichtbar gemacht: Mit einem
    Platzhalter an der Stelle sieht jeder Zug gleich aus, und am Tisch kam
    mal eine Strafe und mal nicht, ohne erkennbaren Unterschied.
  - Neu gelegt wird erst, wenn der **Aktionsscreen zu ist**, und dabei
    wird **gemischt**. Sonst läge der Ring schon anders, während man noch
    die Karte liest – und wer die Reihenfolge gemerkt hat, wüsste weiter,
    was kommt.

- **Ring of Fire: was die App weiß und was sie bucht.**
  - **Von jedem Rang liegen alle vier Karten im Ring**, und zwar von oben:
    `PlayingCardDeck.highestRanks(count:)` – kurz die fünf höchsten Ränge,
    mittel die acht, lang alle. Vorher wurde der gemischte Stapel
    abgeschnitten, und bei zwanzig Karten lagen dann drei Buben und ein
    König im Ring. Regeln, die vom Zählen leben, gehen daran kaputt: Ein
    Daumenmeister, den es nur einmal gibt, ist keine Rolle, sondern ein
    Zufall. Unten im Blatt stehen die Karten, die nur eine Menge ansagen;
    oben die, die etwas mit dem Tisch machen – eine kurze Runde soll die
    dichte sein, nicht die zahme.
  - **Gebucht werden nur die Drei und das Ass** (`drawerDrinks` im
    Katalog). Beide sagen dem Zieher selbst eine Menge an. Alles andere
    trifft andere, eine Gruppe oder den Verlierer einer Runde – und wen,
    weiß nur der Tisch. Eine geratene Buchung wäre schlimmer als keine,
    weil sie in der Bilanz aussieht wie eine bestätigte. Ein Ass, das den
    Ring reißt, kostet **zwei** Shots; das wird nicht verrechnet. Der Shot
    geht an die Person, die **vor** dem Hochzählen dran war – danach ist
    `turn` schon der Nächste.
  - **Die Merkliste sagt, WER die Rolle hat.** Gespeichert wird der Name
    und nicht der Zählerstand: Kommt jemand dazu, verschiebt
    `position(forTurn:)` sich, und die Rolle säße plötzlich bei jemand
    anderem. Die Zeile rechnet `RingOfFireRoleBoard.label(for:holders:)`,
    reine Zeichenarbeit neben der Ansicht und deshalb geprüft. Steht nur
    die Hälfte fest, gibt es **keine halbe Zeile**, sondern wieder die
    Zahl – „Lena, Spieler 2" liest sich wie eine Auskunft und ist eine
    halbe.
  - **Derselbe Rang kommt nicht gleich wieder** (`RingDraw`, Wunsch des
    Nutzers vom 28. Oktober). Mit vier Karten je Rang kam er bei reinem
    Zufall im Schnitt dreimal je Runde direkt hintereinander, egal wie
    groß der Ring. Jetzt ist der Rang von eben ausgeschlossen, solange etwas
    anderes liegt, die beiden davor sind gedämpft, und Ränge mit mehr
    offenen Karten kommen eher dran – sonst sammelten sich die
    Wiederholungen am Ende. Gelost wird **vorher**, das Licht läuft nur hin
    und hält dort, wo die Karte herkommt. `RingDrawTests` rechnet ganze
    Runden mit festem Startwert durch.
  - **Der Tisch bewegt sich, aber er verrät nichts** (`RingMotion`, Wunsch
    des Nutzers vom 28. Oktober: „noch mehr Animationen“). Zu Beginn und
    nach jedem Riss wird aus einem Stapel in der Mitte ausgeteilt – so
    **sieht** man, dass neu gemischt wurde. Eingesammelt wird erst, wenn der
    Kartenscreen weg ist, sonst sähe man nur noch den Stapel. Die gezogene
    Karte hebt sich als eigene Ansicht heraus, ohne Einblenden
    (`.transition(.identity)`): Die Animation der Restzahl gilt für den
    ganzen Ring und blendete sie sonst gleichzeitig ein und aus. Der
    Kartenscreen kommt erst danach. Dazu fünf Regeln:
    - **Die Rolle kommt erst nach dem Kartenscreen in die Merkliste**
      (`pendingRole`). Während die Karte sich heraushebt, steht die Liste
      sichtbar darunter – „Daumenmeister“ verriete die Karte, bevor man
      sie sieht.
    - **Das Lauflicht glimmt nur in der Farbe nach**, Größe und Schein
      springen. Glimmte die ganze Karte nach, stünden in der schnellen
      Phase dreißig aufgeblähte Karten im Ring.
    - **Der Kranz brennt erst, wenn die letzte Karte gelesen ist**
      (`showsFinale`). Er beginnt mit einem Lauf einmal herum, und der lief
      sonst unter dem Kartenscreen ab. Er bleibt in seiner Fläche – darüber
      liegt nur ein schmaler Rand, und abgeschnittenes Feuer sieht aus wie
      ein Bild, das nicht passt – und zeichnet höchstens dreißigmal je
      Sekunde (`EffectCanvas.minimumInterval`), weil „Ring durch“ oft
      minutenlang dasteht.
    - **Mit „Bewegung reduzieren“** liegen die Karten gleich im Kreis, es
      hebt sich nichts heraus, und der Kranz steht als stilles Bild da.
    - **Gezogen wird erst, wenn alles liegt** (`isBusy`): Ein Zug während
      des Austeilens ginge an eine Karte, die noch fliegt.
  - **Das Rad tickt von der ersten Sekunde.** Die Auslosung tickte nur im
    Auslaufen; man drückte, es drehte sich, und man hörte nichts. Jetzt
    kommt beim Druck sofort ein Klang, und die schnelle Phase tickt auf
    jedem vierten Schritt – auf jedem wäre es bei 12 Millisekunden ein
    Rauschen.
  - **Jeder Rang klingt anders, und die Klänge sind gerechnet**
    (`scripts/make_ring_sounds.py`, Entscheidung des Nutzers vom
    28. Oktober). Vorher teilten sich neun Ränge den leisen Kartenklang,
    der Rest lieh sich Beerpong. Das Skript erzeugt Ratsche, Halt, Ziehen,
    dreizehn Ränge, Riss, „hält knapp“, Mischen und „Regel durch“ aus
    Schwingungen und Rauschen, nur mit der Standardbibliothek. Drei
    Regeln: Neue Klänge kommen **ins Skript**, nie als Datei aus dem Netz
    (das Repo ist öffentlich, ein gerechneter Klang hat keine Lizenz).
    Die WAV-Dateien werden **nie von Hand** geändert, der nächste Lauf
    überschreibt sie. Und die Satz-Regel gilt auch hier: Jeder Klang hat
    seinen Satz im Skript, und es bricht ab, wenn zwei sich einen teilen.
    Der Rangklang kommt mit der Karte auf den Kartenscreen, nicht beim
    Ziehen – er gehört zu dem Moment, in dem man sie sieht.

- **Die Härte gehört zum Spiel, nicht zum Gerät.** Sie stand bis Oktober
  2026 einmal über den Partyspielen und galt für alle. Am Tisch ist sie
  aber eine Eigenschaft der Runde: Mäxchen wird anders getrunken als
  Trink-Roulette, und von weit oben im Hauptmenü aus stellt sie niemand um.
  Jetzt gilt:
  - `DrinkIntensity.standard` ist die **Vorgabe** (Einstellungen, alter
    UserDefaults-Schlüssel – die Wahl des Nutzers bleibt also stehen).
    Beerpong Extreme stellt sie im Neues-Spiel-Screen.
  - `DrinkIntensity.stored(for: game)` ist die Härte **eines Spiels**,
    Rückfall auf die Vorgabe.
  - `DrinkIntensity.current` ist, was **gerade** gilt – nur im Speicher.
    `PartyGame.destination` setzt es beim Betreten und nimmt es beim
    Verlassen zurück. Das Zurücknehmen ist Pflicht: sonst läuft Beerpong
    Extreme nach einer harten Runde Schocken auch hart, und nichts auf dem
    Bildschirm sagt, warum.
  - **Wo** gewählt wird, steht im Katalog (`PartyGame.intensityStep`):
    Spiele, die vorher ohnehin etwas fragen, haben die Härte in demselben
    Vorspann; alle anderen bekommen einen eigenen (`IntensityGate`). Wie
    viele es gerade sind, sagt der `switch` und nicht dieser Satz.
    **Jedes** Partyspiel nennt inzwischen eine Menge und hat damit eine
    Härte – Bombe, Reaktionsduell und „Wer würde eher?" sagten bis zum
    13. Oktober bloßes „du trinkst", und was die Runde dann aushandelte,
    hatte mit der eingestellten Härte nichts zu tun. Dass ein neues Spiel
    eingeordnet wird, erzwingt der Compiler: `intensityStep` ist ein
    vollständiges `switch` ohne `default`. Ein neues Spiel wird an dieser einen Stelle
    eingeordnet – wer es vergisst, hat ein Spiel ohne Härte-Wahl, und ein
    Test hält das fest.

### Bewusst dormant

Das Freundesystem (`Features/Friends/`) und `LobbyView` sind gebaut, aber
nicht verlinkt. Sie sind der Weg für später, wenn die App auf mehreren
Geräten läuft. **Nicht löschen.**

### Offen und denkbar

Nichts mit konkretem Anlass. Denkbar bleiben Cloud Functions – die
bräuchten Blaze, und den gibt es nicht.

**Was hier NICHT mehr steht**, weil es gebaut ist: die Live Activity
(`LiveGameActivity`, gestartet von `LiveGameView`) und die Aufteilung des
`LiveGameViewModel`. Beide standen monatelang als offene Punkte da, obwohl
sie fertig waren – und eine Liste offener Punkte, die Fertiges enthält,
kostet beim nächsten Mal genau die Zeit, die sie sparen soll. Dieselbe
Regel gilt für Abschnitt 9.

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
   **Behoben am 1. Oktober 2026**: `finishGame` schreibt den Endstand einmal
   am Spielende, und `Game.finalCups` entscheidet, ob ein Stand ueberhaupt
   ein Ergebnis ist. `currentTurnTeamId` und `playerStreaks` warten
   weiterhin auf dieselbe Cloud Function und duerfen nicht gelesen werden.

10. **Vor dem Vorschlagen in die Datei schauen, nicht in die
    Suchergebnisse.** Zweimal an einem Tag habe ich behauptet, etwas fehle
    ganz, obwohl es halb da war: Der fehlgeschlagene Wurf zeigte sehr wohl
    eine Warnung (drei Zeilen unter der Logger-Zeile, die ich gegrept
    hatte), und der Abend-Rückblick existierte vollständig. Beide Male war
    der Code besser als meine Beschreibung. Ein Vorschlag, der ein Problem
    erfindet, kostet den Nutzer Vertrauen – und beim Umsetzen fällt es
    ohnehin auf.

11. **Ein `Bool` im geteilten Baustein merkt sich die letzte Karte.** Der
    Daumen nach unten („Nie wieder") funktionierte pro Spielstart genau
    einmal. Die Ursache ist keine Eigenheit des Knopfes, sondern von
    SwiftUI: Eine Ansicht wird an ihrer **Stelle im Baum** erkannt, nicht
    an ihren Werten. Neben dem Weiter-Knopf steht derselbe
    `HideCardButton` für jede Karte – sein `@State wurdeAusgeblendet`
    blieb deshalb nach der ersten Karte stehen, und ab da war der Knopf
    beschriftet wie benutzt und per `disabled` tot. Am Tisch sieht das
    aus wie ein kaputter Knopf, und kein Test hätte es gefunden: Der
    Zustand lebt in der Ansicht, nicht in der Rechnung. Die Lösung ist
    nicht `.id(…)` an jeder Aufrufstelle – das vergisst die nächste –,
    sondern **den Schlüssel merken statt ein Ja/Nein**: Passt der
    gemerkte Schlüssel nicht zur Karte, ist der Knopf von selbst wieder
    da. Wer in einem geteilten Baustein `@State` braucht, speichert
    deshalb das, worauf er sich bezieht (so wie `CupFillGauge` es mit
    `onChange` tut), nie ein nacktes `Bool`.

12. **„Reagiert nicht" heißt oft „wurde nicht getroffen".** Vierundzwanzig
    leise Knöpfe standen als `Button("…")` mit Kleinschrift und grauer
    Farbe im Projekt – ohne Innenabstand, ohne `contentShape`, ohne
    Druck-Rückmeldung. Tastbar war damit nur die Schrift selbst, rund
    fünfzehn Punkte hoch gegen Apples vierundvierzig; getroffen wird am
    Tisch aber nicht gezielt. Das ist Nr. 4 in seiner leisen Form, und
    es trifft ausgerechnet die wichtigen Nebenhandlungen – auch
    „Rückgängig" im Sieger-Screen. Liegt jetzt in `QuietButton`.

13. **Ein `@ViewBuilder`-Parameter darf nicht in einen `GeometryReader`.**
    Zwei der neuen Spiele hatten einen gemeinsamen Rahmen als Funktion –
    `panel(content:buttons:)`, Inhalt mittig, Knöpfe unten. Darin steht ein
    `GeometryReader`, und dessen Closure ist **escaping**: „escaping closure
    captures non-escaping parameter 'content'". Der Fehler kostet einen
    ganzen Actions-Lauf, weil `check.py` ihn nicht sehen kann – er ist kein
    Syntaxfehler, sondern eine Regel des Typsystems. Die Lösung ist eine
    Zeile: die Closures **vor** dem `GeometryReader` auswerten
    (`let inhalt = content()`) und die fertige Ansicht hineinreichen. Eine
    Ansicht ist ein Wert und darf überall mit.

    Dasselbe gilt für jede Hilfsfunktion mit `@ViewBuilder`-Parameter, die
    innen eine escaping Closure benutzt – auch `Task`, `onAppear` oder eine
    Animation mit Abschluss.

14. **Ein `compactMap` in einer Übersetzung verkürzt die Liste – und
    manchmal ist die Länge die Aussage.** Das Wiederherstellen übersetzte
    die alten Profil-Kennungen eines Teams mit
    `team.playerIds.compactMap { profileIds[$0] }`. Wer nicht in der Tabelle
    stand, fiel heraus. Das klingt sauber („lieber keine Kennung als eine
    falsche") und bricht zwei Dinge auf einmal: Aus einem 2-gegen-2 wurde
    ein Team mit einem Spieler, und `GameRepository.createGame` lehnt genau
    das ab – die **ganze** Wiederherstellung brach mitten im Lauf ab, mit
    der Meldung „Jedes Team braucht genau 2 Spieler" und einem halb
    beschriebenen Konto. Dazu ist der Platz in `playerIds` der Platz im
    Team: `ThrowRepository` leitet den Slot daraus ab, ein verschobener
    Platz hätte die Würfe auf die falsche Person gebucht.
    Der Fall ist nicht gesucht, sondern der Normalfall nach einem Jahr: Wer
    aus der Truppe gelöscht wird, steht in seinen alten Partien weiter als
    Kennung, aber nicht mehr in der Profilliste – und die Sicherung enthält
    beides so. Eine Zeile tiefer machte der Wurf-Log es übrigens schon
    richtig (`profileIds[alt] ?? alt`): Dieselbe Funktion widersprach sich
    selbst.
    **Die Regel:** Wo eine Position etwas bedeutet, darf eine Übersetzung
    die Länge nicht ändern – `map` mit Rückfall statt `compactMap`. Und ein
    Vorgang, der schreibt und nicht umkehrbar ist, bricht nicht beim ersten
    Fehler ab, sondern überspringt das kaputte Stück und **sagt am Ende, wie
    viel übersprungen wurde**. Eine Sicherung, die halb durchläuft und
    „fertig" meldet, ist schlimmer als eine, die scheitert.

15. **Ein eigener Typ kann einen SwiftUI-Typ verdecken.** Der Screen des
    Musikspiels hieß bis zum 29. Oktober `TimelineView` – genau wie SwiftUIs
    Zeitleiste. `TimelineView(.animation)` rief deshalb den Spiel-Screen auf, und der
    Lauf brach mit „argument passed to call that takes no arguments“ ab
    (27. Oktober, beim Bau von `EffectFlames`). Gemeint ist dann
    `SwiftUI.TimelineView`, voll ausgeschrieben. `check.py` meldet so einen
    Aufruf seitdem selbst – der Name allein ist kein Fehler, aber ein
    Aufruf mit Punkt-Argument (`(.animation)`) meint fast immer SwiftUI.

16. **Ein Tupel aus Tupeln in einer `map`-Closure kann den Typprüfer
    aufhängen.** `.map { k in ((Double(k) * 48 + 10, 0), (… , h)) }`
    sieht harmlos aus, aber jedes Zahlenliteral darin bekommt seinen Typ
    erst vom Ziel, und der Compiler probiert die Kombinationen durch, bis
    er mit „unable to type-check this expression in reasonable time“
    aufgibt (28. Oktober, Lauf 165, zweimal in den Gründen der
    Spielwelten). Eine Schleife mit benannten Punkten (`let oben: Point =
    (x, 0)`) hat das Problem nicht. `check.py` meldet das Muster seitdem.

17. **Setzen und im selben Durchgang zurück animieren sieht niemand.**
    `EffectFlash` schaltete auf hell und blendete in derselben Funktion
    wieder aus. SwiftUI zeichnet aber erst nach dem ganzen Durchgang und
    sieht dann nur den Endwert – dunkel nach dunkel, also nichts. Der Blitz
    kam damit nie an. Aufgefallen ist das beim Lesen (28. Oktober), nicht
    am Tisch: Ein Blitz, der fehlt, fehlt niemandem. Die Lösung ist, den
    Ausgangswert zu setzen und die Animation erst im nächsten Durchgang zu
    starten (`DispatchQueue.main.async { withAnimation { … } }`). Das
    braucht jeder Baustein, der etwas aufblitzen, anschlagen oder
    zurückfedern lässt; in den Spielwelten steht es an mehreren Stellen.

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
dieser Zeit ausschließlich „übersetzt sich, Tests laufen durch". Seit Ende
Oktober spielt der Nutzer wieder auf dem Gerät; die Funde von dort stehen
in `git log`.

**Diese Liste ist deshalb keine Liste von Fehlern, sondern von
Behauptungen** – alles hier ist gerechnet, gelesen oder gedacht, aber nicht
beobachtet. Zwei Regeln dazu, beide schon schmerzhaft gelernt:

- **Abgearbeitete Punkte streichen.** Eine Liste, in der die Hälfte erledigt
  ist, liest beim nächsten Mal niemand mehr – und kostet damit genau die
  Zeit, die sie sparen soll.
- **Nicht annehmen, dass etwas läuft, weil es drinsteht.** Wenn unklar ist,
  ob ein Punkt erledigt ist: den Nutzer fragen, nicht raten.

Geordnet ist nach **Folgen**, nicht nach Datum: Was Daten kostet, steht
oben; was schief aussieht, unten.

### Hier können Daten verloren gehen – zuerst

- **Nachreichen, auch nach einer Revanche**: Flugmodus an, ein paar Würfe
  tippen, Netz an, „Nachreichen" drücken – danach die Partie fortsetzen und
  prüfen, ob der Stand stimmt. Das ist der einzige Weg, an dem Daten
  verloren gehen. Und dann derselbe Weg über eine Revanche hinweg: Würfe
  tippen, Partie zu Ende spielen, Revanche starten, erst dann nachreichen.
  Die Würfe müssen in der **alten** Partie landen, der Spielverlauf der
  Revanche darf sie nicht zeigen – genau das lief vorher falsch.
- **Datensicherung** samt Teilen-Blatt – und vor allem das
  **Wiederherstellen**, weil es als einziges schreibt. Beim ersten Versuch
  „Nur Profile und Werte" auf einem frischen Konto, nicht „Alles" auf dem
  echten. Seit dem 26. Oktober gibt es dort einen Fall, der vorher
  **abgebrochen** wäre: eine Sicherung mit einer Partie, deren Spieler
  inzwischen gelöscht ist. Die muss jetzt durchlaufen, und wenn eine
  Partie wirklich nicht anzulegen ist, muss die Ergebniszeile sagen, wie
  viele übersprungen wurden.
- **Ohne Netz:** Flugmodus, App killen, ganze Partie spielen, Netz an. Der
  Firestore-Cache ist nirgends im Code konfiguriert – auf iOS ist er
  standardmäßig an, geprüft hat es nie jemand. Gespielt wird im Keller.
### Was zuletzt gebaut wurde und nie lief

- **Ring of Fire bewegt sich, und derselbe Rang kommt seltener**
  (28. Oktober, auf Wunsch – Austeilen und Herausheben in der Vorschau
  „Riss im Ring“ gezeichnet, der Kranz im Browser, auf dem Gerät nichts
  davon). Zu prüfen:
  - **Kommt derselbe Rang noch direkt hintereinander?** Gerechnet
    praktisch nie, mit einer Karte dazwischen etwa halb so oft wie vorher.
    Fühlt sich das Ziehen trotzdem noch nach Zufall an?
  - **Austeilen**: Beim Start und nach jedem Riss liegt erst ein Stapel in
    der Mitte, dann wird im Uhrzeigersinn ausgeteilt. Dauert es zu lange,
    bis man ziehen kann? Sieht man nach einem Riss erst die Lücke, dann
    das Einsammeln?
  - **Herausheben**: Sieht man, woher die Karte kommt, bevor der
    Kartenscreen sie zeigt – oder wirkt die Pause wie ein Hänger?
  - **Schweif**: Zieht das Licht beim Losen einen Schweif, ohne dass der
    Ring in der schnellen Phase nur noch rot ist?
  - **Merkliste**: Taucht „Daumenmeister“ erst nach „Verstanden“ auf und
    rutscht dann hinein – nicht schon, während die Karte herausgehoben
    wird?
  - **Ring durch**: Läuft das Feuer einmal herum und schließt sich oben?
    Ruckelt der Kranz auf dem iPhone 13, und stört er die Zahl in der
    Mitte?
  - Mit „Bewegung reduzieren“: Karten gleich im Kreis, kein Herausheben,
    der Kranz als stilles Bild.

- **Jede Karte kommt anders** (28. Oktober, auf Wunsch – die Auftritte
  im Browser gezeichnet, auf dem Gerät nie gelaufen). Zu prüfen:
  - **Erkennt man den Rang am Auftritt**, bevor man liest? Wenn zwei sich
    ähneln oder einer albern wirkt – sag welche.
  - **Wirkt die kurze Pause nach dem Hereinfahren wie Absicht** oder wie
    ein Hänger? Der Screen kommt, dann erst die Karte und ihr Klang.
  - **Beim Wasserfall**: Läuft die Karte sauber hinter der Welle ins Bild,
    und hat sie danach ihren Schatten wie alle anderen?
  - Ruckelt etwas auf dem iPhone 13, am ehesten beim König (Münze) und
    beim Buben (Überschlag)? Zeigen beide zwischendurch die Rückseite?
  - Mit „Bewegung reduzieren“ muss die Karte sofort stehen.
  - Und die neuen Szenen hinter der 5 und der 6: Blitze an den Rändern,
    Glitzer von oben – stört eines davon den Text?

- **Der Riss als eigener Moment, seltener, mit Glutfaden** (28. Oktober,
  auf Wunsch – in der Vorschau „Riss im Ring“ abgestimmt, auf dem Gerät nie
  gelaufen). Zu prüfen:
  - **Sieht man, wo es gerissen ist?** Der Faden reißt, die Flamme
    schlägt aus der Lücke, „RISS“ steht darüber – und erst nach gut
    anderthalb Sekunden kommt die Karte. Zu lang, zu kurz?
  - **Reißt es jetzt selten genug?** Gerechnet: bei 20 Karten in etwa
    jeder zehnten Runde schon in den ersten drei Zügen statt in vier von
    zehn. Kommt die Regel in einer kurzen Runde trotzdem noch vor?
  - **Versteht man den Faden?** Eine kleine Lücke, über der der Faden
    glüht, darf nicht wie ein Riss aussehen – und ein dünner, flackernder
    Faden soll nach „gleich reißt es“ aussehen.
  - Ruckelt der Moment auf dem iPhone 13? Mit „Bewegung reduzieren“ muss
    ein stilles Bild mit Markierung dastehen, nicht nichts.
  - Weiter offen von vorher: Landet der Shot bei der Person, die gezogen
    hat, liegt der Ring nach dem „Verstanden" sichtbar **neu**, und ist
    nach dem dritten Riss die Glut aus?
- **Ring of Fire bucht mit (25. Oktober)**: Einen Abend starten, Ring of
  Fire spielen, bis ein Ass und eine Drei gezogen sind – stehen beide
  danach in der Trinkbilanz der richtigen Person? Und steht dort **nichts**
  von einer Fünf oder einer Zwei (die trifft andere, und das soll die App
  nicht raten)? Dazu die Merkliste: Sagt sie „Daumenmeister · Lena" statt
  „×1", steht bei der Zehn „von Lena" unter der Regel, und ist die Zeile
  ohne Abend und ohne Aufstellung wieder nur die Rolle?
- **Das Rad tickt sofort (25. Oktober)**: Beim Druck auf „Karte ziehen"
  muss sofort etwas zu hören sein, und das Ticken in der schnellen Phase
  darf kein Rauschen sein.
- **Alle Screens füllen (25. Oktober)**: Siebzehn Spiele haben jetzt
  `FillingScrollView` statt `ScrollView`. Einmal durch alle und schauen, ob
  irgendwo das Gegenteil passiert – ein Screen, der mit kurzem Inhalt
  mittig hängt, wo man ihn oben erwartet, oder eine Liste, die beim
  Scrollen springt. Besonders: Spion (der gemeldete Fall), Schocken,
  Wer bin ich?, Turnier, die gezogene Karte in Ring of Fire (dort liegt
  unten der „Verstanden"-Knopf über dem Inhalt) und die beiden Listen mit
  `.top` (Abend-Rückblick, eigene Karten).
- **Trink-Roulette mit Rädern (25. Oktober)**: Der Vorspann ist neu – vier
  Zeilen plus Härte, und die Härte steht jetzt dort statt in einem eigenen
  Screen davor. Zu prüfen: Baut sich ein eigenes Rad mit drei, fünf und
  zehn Feldern ordentlich auf (Beschriftung im Tortenstück lesbar, keine
  zwei gleichfarbigen Nachbarn), bleibt es nach dem App-Start erhalten,
  und sagt der Knopf „Anderes Rad" sauber zurück in die Auswahl? Dazu die
  Vorschau im Editor: Steht dort derselbe Satz, der nach der Drehung
  erscheint?
- **Jedes Spiel hat seine eigene Welt** (28. Oktober, auf Wunsch): Grund,
  Fläche, Kante und Schrift kommen aus der Welt, und jedes Spiel hat
  seine eigenen Dinge bekommen – Akte, Würfelbecher, Leuchtreklame,
  Zielanzeige, Pergament und so weiter. Abgestimmt wurde die Vorschau im
  Browser; auf einem Gerät lief nichts davon. Zu prüfen, in dieser
  Reihenfolge:
  - **Steht der Text nach einer halben Sekunde?** Das war die Rückmeldung
    zur Vorschau (Spion, Bussfahrer). Wo etwas noch länger braucht – sag
    wo.
  - **Erkennt man jedes Spiel ohne seinen Titel?** Auch an der Kachel im
    Ordner, die jetzt den Grund ihrer Welt als Deckel trägt.
  - **Bleibt aller Text lesbar**, mit großer Schrift und im Tischmodus?
    Am ehesten eng: die Abfahrtstafel beim Würfel, die Stirnkarte bei
    „Wer bin ich?" und die Anzeigetafel im Turnier. Und bricht nirgends
    mehr ein Titel mitten im Wort um (gemeldet: Schätzmeister und
    Reaktionsduell in den Kacheln)?
  - **Ruckelt etwas auf dem iPhone 13?** Am meisten zu tun haben die
    Leuchtreklame bei „Ich hab noch nie", das Casino-Rad, die Herde, die
    Fallblätter und die Gründe mit Bewegung (Glut, Lampe, Filmkorn).
  - **Geht alles, was sich anders bedient?** Die Akte beim Spion und das
    Klebeband bei Verbotene Wörter statt der alten Karte, die Kleckse und
    Striche im Trinkbingo, die Karte, die bei „Wer bin ich?" wegfliegt.
  - Mit „Hintergrund: Schlicht“ muss jede Welt fast einfarbig sein, mit
    „Bewegung reduzieren“ still – und trotzdem vollständig: Jede Karte
    muss aufgedeckt dastehen, kein Text darf fehlen.
- **Jede Szene bewegt sich anders** (27. Oktober, auf Wunsch): Alle Szenen
  sind neu gezeichnet – dreizehn hinter den Ring-Karten, dazu Feuerwerk im
  Sieger-Screen, Rauch und Splitter in der Bombe, die Schallplatte beim
  Sieg in der Hitparade, der Goldglanz am Pokal des Abends und die drei
  Kostenarten im Trink-Roulette. Abgestimmt wurde im Browser, auf einem
  Gerät lief nichts davon. Zu prüfen, in dieser Reihenfolge:
  - **Unterscheidet man sie?** Einmal durch Ring of Fire, bis jeder Rang
    dran war: Erkennt man die Karte an der Bewegung, bevor man den Text
    liest? Wenn sich zwei ähneln – sag welche.
  - **Bleibt der Text lesbar**, auch mit großer Schrift und im Tischmodus?
    Am ehesten im Weg sind die Szenen, die durch die Mitte gehen:
    Wasserfall, Himmel, Dame und Kategorie. Stört eine, wird dort
    gedämpft, nicht überall.
  - **Ruckelt es auf dem iPhone 13?** Jedes Bild wird neu gezeichnet; am
    meisten zu tun haben das Feuerwerk und die Glut beim Ass.
  - **Mit „Bewegung reduzieren“** muss jede Szene ein stilles Bild zeigen –
    nicht nichts.
- **Ohne Konto (26. Oktober)**: Abmelden, dann „Ohne Konto loslegen" –
  laufen alle Partyspiele, bleibt die Beerpong-Kachel stehen und erklärt
  sich, ist das Personen-Symbol weg? Danach aus den Einstellungen heraus
  anmelden: Abend, eigene Karten und Aufstellung müssen danach noch da
  sein. **Offen und bewusst so**: Ohne Konto gibt es keine Profile, also
  auch keine Aufstellung – und damit keinen Abend und keine Bilanz. Für
  eine fremde Runde fehlen dafür lokale Mitspieler.
- **Strafen ohne Trinken (26. Oktober)**: In den Einstellungen auf Sport
  stellen und einmal quer durch – sagt wirklich **nichts** mehr „Schluck"
  (Karten, Rad, Vorspänne, Bilanz, Abend-Plakat)? Fühlen sich die drei
  Stufen richtig an, oder ist ein Shot zu billig weggekommen?
- **Der Kommentator (26. Oktober)**: Sprachansage einschalten und eine
  Partie spielen. Redet er zu viel oder zu wenig? Kommt er den
  Einblendungen in die Quere? Und sagt er bei zwei Spielern „werfen" und
  bei einem „wirft"?
- **Tischmodus (26. Oktober)**: Einschalten und aus anderthalb Metern auf
  den Tisch schauen. Ist es lesbar – und zerlegt die größere Schrift
  irgendwo ein Layout? Bleibt der Bildschirm an, und geht er nach dem
  Verlassen der App wieder normal aus?
- **Abend von selbst und Zurücknehmen (26. Oktober)**: Aufstellung setzen,
  irgendein Spiel aufmachen – läuft der Abend? Dann eine Strafe auf die
  falsche Person buchen und im Hauptmenü „Zurücknehmen" – steht die
  Bilanz danach wieder richtig?

### Ring of Fire sonst

- **Die neuen Klänge (28. Oktober)**: Unterscheidet man die Ränge am Ton,
  bevor man die Karte liest? Nervt die Ratsche beim Losen nach zehn
  Zügen? Sind Riss und Ass laut genug gegen Musik, und ist nichts so laut,
  dass es erschreckt? Gerechnet und im Spektrum geprüft, gehört hat sie
  vor dem Einbau nur der Nutzer in der Vorschau.

- **Der Ring selbst**: Liegen die Karten erkennbar geschuppt, und sieht man
  die dünnen Stellen? Bei **zwanzig** Karten wird der Kranz dicht und das
  Loch in der Mitte klein – dort steht dann nur die Zahl, ohne Flasche und
  ohne „übrig". Passt das? Dazu die Auslosung: Sie dauert etwa drei
  Sekunden, geschätzt und nicht gemessen.
- **Eine kurze Runde ist fast nur Rollenkarten** – Zehn bis Ass, also vier
  Daumenmeister, vier Question Queens, vier Hausregeln. Ist das dicht oder
  zu viel auf einmal? Und mit vier Assen plus drei Riss-Shots sind das
  sieben Shots auf zwanzig Züge: zu heiß?
- **Schwarze Karten**: Pik und Kreuz waren weiß und damit unsichtbar. Einmal
  durch Ring of Fire, Bussfahrer und Pferderennen schauen, ob alle vier
  Farben jetzt normal aussehen.
### Beerpong
- **Drei neue Einblendungen** (28. Oktober): Beim Umstellen gleiten
  Becher in die neue Formation, bei der Redemption steht ein umgekippter
  Becher wieder auf, beim Trickshot zieht ein Ball eine Schleife in den
  Becher. Unterscheidet man sie im Vorbeisehen, und sind sie vorbei, bevor
  weitergetippt wird?
- **Hausregeln**: Eine Partie mit abgeschalteter Redemption zu Ende spielen –
  der letzte Becher muss direkt in den Sieger-Screen führen, ohne Nachwurf.
  Das Regelwerk selbst deckt `HouseRulesTests` ab, den Weg dorthin nicht:
  dass der Schalter das Spiel erreicht, dass die Einstellung den App-Start
  überlebt, und dass die Abweichungs-Zeile mit sieben Einträgen nicht
  auseinanderfällt.
- **Beerpong Extreme** insgesamt: Blitzt die Karte auf? Beim richtigen Team?
  Die Zuordnung `.hit` → Gegner und `.cupChosen` → wählendes Team ist
  durchdacht, nicht beobachtet.
- **Letzter Becher geladen:** Karte und Sieger-Screen treffen gleichzeitig
  aufeinander. Ungetestet, wahrscheinlichster Ärger.
- **Beerpong mit Namen (18. Oktober)**: Die Einblendungen sagen jetzt
  „Lena & Jan werfen nochmal". Zu prüfen, ob in der schmalen Team-Leiste
  und auf dem Sperrbildschirm nichts abgeschnitten wird – da steht die
  Kurzform.
- **Ergebnis als Bild (18. Oktober)**: Im Sieger-Screen und im
  Abend-Rückblick. Sieht das Bild in einer Chat-Vorschau gut aus, und
  stimmen die Zahlen darauf mit dem Screen überein? Beides nie auf Hardware
  gelaufen – auf dem Simulator gibt es kein Teilen-Blatt, das etwas
  verschickt.
- **Alles vom 1. Oktober**: Endstand im Spielverlauf (alte Partien müssen
  einen Strich zeigen, neue ein echtes Ergebnis), die Trefferquote nach
  Tageszeit, und ob die Partyspiele die richtigen Namen sagen – besonders
  mit laufendem Abend, wo seine Teilnehmer gelten und nicht der Tisch.
- **Team-Chemie (2. Oktober)**: Stimmen bester Partner und schlimmster
  Gegner mit dem überein, was ihr am Tisch sagen würdet? Die Rechnung ist
  per Test abgedeckt, die Datenlage nicht – bei wenigen Partien kann ein
  Name oben stehen, der sich falsch anfühlt.
- **Abend, Trinkbilanz, Namen** in den Partyspielen – besonders, ob Position
  3 im Spiel und Position 3 in der Teilnehmerliste dieselbe Person meinen.
- **„Kennst du deine Leute?" (8. Oktober)**: Stehen überhaupt Fragen da,
  oder sagt das Spiel „noch zu wenig gespielt"? Die beiden Grenzen sind
  getestet, die Datenlage nicht – mit wenigen Partien kann es gut sein, dass
  nur zwei oder drei Fragen übrig bleiben. Und: Landet die Strafe beim
  Richtigen, wenn ein Abend läuft?
### Partyspiele: Inhalt, Mengen, Gefühl
- **Ich hab noch nie mit neuen Kategorien (28. Oktober)**: Ist „Tabulos“
  hart genug – oder schon zu viel für eure Runde? Fühlen sich die Themen
  wirklich anders an als die Stufen, und trägt jedes allein eine Runde?
  Fragen, die nicht passen, mit dem Daumen aussortieren und mir nennen.
  Dazu der Vorspann: Bleiben die zwei Gruppen mit großer Schrift
  übersichtlich? Und die Schilder, die jetzt je Karte anders leuchten: zu
  bunt oder genau richtig? Bleibt die kursive und die schmale Schrift aus
  anderthalb Metern lesbar, und ruckelt das Lauflicht nicht? Und das
  **Zahnrad** oben rechts: mitten in der Runde Tabulos dazunehmen, Fertig –
  kommt ab der nächsten Karte die neue Mischung, und keine Frage doppelt?
  Soll das Zahnrad auch in die anderen Spiele?
- **Hitparade (29. Oktober, vorher Zeitstrahl)**: Das Wichtigste –
  stimmen die Jahreszahlen, und läuft das richtige Lied? Beim ersten
  Durchgang auf Lieder achten, bei denen die Runde widerspricht oder eine
  falsche Fassung läuft (live, Remix, Cover), und sie mir nennen. Dann:
  - Startet das Lied von allein, auch bei stummgeschaltetem iPhone, und
    hört die Playlist auf dem Handy dafür auf? Geht der Ton über den
    Box-Knopf auf AirPlay oder Bluetooth – und **zeigt die Box irgendwo den
    Titel an**?
  - Steht vor dem Aufdecken wirklich nirgends Titel, Interpret oder Cover –
    auch nicht auf dem Sperrbildschirm oder im Kontrollzentrum?
  - Fühlen sich die Fragen richtig an? Ist ± 1 zu schwer, kommt eine Frage
    zu oft? Und entscheidet die Runde bei Titel und Interpret ohne Streit?
  - Ohne Netz (Flugmodus): Kommt die Meldung, und führen „Anderes Lied“ und
    „Über die Box spielen“ sauber weiter?
  - Dreht sich die Platte, liegt der Tonarm auf, läuft der Ring mit? Ist
    das Zählwerk am Tisch schnell genug zu bedienen?
  - Stimmt die geschätzte Dauer im Vorspann ungefähr?
- **Pokal (22. Oktober)**: Stimmt die Wertung am Ende mit dem überein, was
  ihr im Kopf habt? Von allein melden nur **Hitparade** und **Beerpong**;
  bei allen anderen tippt ihr den Sieger im Abend-Screen an. Zu prüfen, ob
  das am Tisch tatsächlich jemand macht – wenn es vergessen wird, bleibt
  der Pokal leer, und dann gehört er näher ans Spielende statt in den
  Abend.
- **Die Herde (22. Oktober)**: Treffen die Fragen die Mitte zwischen „zu
  offen" (zehn Antworten, keine Mehrheit) und „zu geschlossen" (alle sagen
  dasselbe, niemand trinkt)? Das ist die einzige Stelle, an der der Stapel
  scheitern kann, und sie fällt nur am Tisch auf. Dazu: Ist das Antippen,
  wer allein stand, mit sieben Leuten schnell genug, oder bremst es?
- **Die Skala (22. Oktober)**: Trifft die Runde die Zone oft genug, dass
  es sich nach Können anfühlt? Die Trefferzone ist 15 Prozent breit, der
  straffreie Ring 36 – beides gerechnet, nicht erprobt. Zu schmal heißt
  Lotterie, zu breit heißt, jeder Hinweis gewinnt. Und: Lässt sich der
  Zeiger am Tisch gemeinsam bedienen, oder reißt ihn einer an sich? Seit
  dem 28. Oktober zieht man ihn direkt auf der Scheibe statt an einem
  Regler darunter.
- **„Was spielen wir?" (18. Oktober)**: Lost der Würfel etwas aus, das am
  Tisch gerade wirklich passt – oder landet dreimal hintereinander dasselbe
  Spiel? Gelost wird auf einer Abfahrtstafel: Eine halbe Sekunde klappern
  die Fallblätter, dann steht der Titel nach knapp einer weiteren. Beides
  geschätzt, nicht gemessen – zu kurz, um zu zeigen, dass gelost wird,
  oder zu lang zum Warten? Und stimmen die
  Dauer-Angaben („2 Minuten", „10 Minuten") ungefähr mit dem überein, was
  eine Runde tatsächlich braucht? Sie stehen jetzt auch auf jeder
  Spielkachel im Ordner.
- **Blätter verteilen (22. Oktober)**: Kommen die Bilder in WhatsApp
  lesbar an, oder sind sechzehn Felder auf einem Handybild zu klein? Und
  geht AirDrop an mehrere gleichzeitig?
- **„Regel des Abends" (18. Oktober)**: Zieht sie eine Regel, die wirklich
  auffällt, oder eine, die den Abend lahmlegt? Besonders zu prüfen, dass die
  Regeln **das Verlassen des Screens überleben** – ziehen, Ring of Fire
  spielen, zurückgehen: Es müssen noch dieselben dastehen. Und ob fünf
  gleichzeitig noch spielbar sind oder ob die Warnung früher kommen muss.
- **Pantomime (18. Oktober)**: Reichen 90 Sekunden, oder ist die Runde
  vorher durch? Die Begriffe sind die von „Wer bin ich?" – taugen sie zum
  Vorspielen, oder sind gerade „Film & Serie" dafür zu schwer? Und ob die
  beiden großen Flächen zu treffen sind, während man gleichzeitig spielt.
- **Bussfahrer vom 17. Oktober**: Die Busfahrt ist neu und nie gelaufen.
  Fünf Karten, jede Bildkarte zurück an den Anfang – gerechnet kommt der
  Bussfahrer in etwa jedem sechsten Versuch durch. Fühlt sich das am Tisch
  richtig an oder sitzt er zu lange? Und füllt der Screen jetzt?
- **„Wer ist dran?" (18. Oktober)**: In Ring of Fire, Ich hab noch nie,
  Wahrheit oder Pflicht, Zwei Wahrheiten, Kategorien und Bussfahrer. Zeigt
  die Zeile die richtige Person, und läuft sie im selben Takt wie der Kreis
  am Tisch? Ohne Abend und ohne Aufstellung muss sie **ganz weg** sein.
- **Drei Spiele sagen jetzt eine Menge** (13. Oktober) und haben deshalb
  eine Härte: „Wer würde eher?" („Die meisten Finger: 3 Schlücke"), Bombe
  (4 Schlücke für den, der drauf sitzen bleibt) und Reaktionsduell
  (2 Schlücke für den Verlierer, 4 für den Früh-Tipp – vorschnell tippen
  ist ein Schummelversuch und soll mehr kosten als langsam sein). Die
  Zahlen sind gesetzt, nicht erprobt: Fühlen sie sich am Tisch richtig an?
- **Härte je Spiel (13. Oktober)**: In Schocken, Mäxchen, Spion, Verbotene
  Wörter, Wer bin ich?, Ich hab noch nie und Ring of Fire steht sie im
  Vorspann, den es schon gab – passt das Layout noch, auch mit großer
  Schrift? Die anderen zehn haben jetzt einen eigenen Vorspann davor; der
  ist neu und nie gelaufen. Und der eigentliche Test: In einem Spiel hart
  einstellen, zurück, Beerpong starten – die Extreme-Karten müssen wieder
  in der Vorgabe dastehen.
- **Mehr Platz in sechs Spielen** (17. Oktober): Die Karten wachsen in den
  freien Raum. Zu prüfen, ob irgendwo das Gegenteil passiert – eine Karte,
  die mit kurzem Text riesig und leer dasteht.
### Oberfläche
- **Hauptmenü vom 13. Oktober**: Die Ordner sind größer, und die Zahl steht
  jetzt als „5 Spiele" in der Unterzeile statt fett und farbig am rechten
  Rand – dort sah sie aus wie eine ungelesene Nachricht. „Zuletzt gespielt"
  ist weg. Passt das Ganze noch, auch mit großer Schrift?
- **Sechs Kacheln im Hauptmenü** (17. Oktober): Beerpong oben links, Turnier
  unten rechts. Passt das Raster auf dem Gerät, auch mit großer Schrift?
- **Inhalt in den Kacheln** (18. Oktober): Jede Kachel trägt jetzt einen
  halben Satz und eine Emoji-Reihe – die Spiele der Gruppe, bei Beerpong die
  Leute am Tisch. Zu prüfen: Bleiben zehn Emoji bei „Raten & reden" in einer
  Zeile lesbar, stehen die beiden Kacheln einer Reihe gleich hoch, und
  stimmt die Zahl unter Beerpong mit der Reihe darüber überein? Dazu die
  Ordner: „Läuft nebenher" hat zwei Spiele – sind die Kacheln dort jetzt zu
  groß, statt dass der Platz darunter leer bleibt?
- **Knöpfe vom 12. Oktober**: Der Daumen nach unten muss jetzt bei **jeder**
  Karte gehen, nicht nur bei der ersten – zweimal hintereinander in „Ich hab
  noch nie" ausprobieren. Dazu „Wer würde eher?", das ihn neu hat, und einmal
  quer durch die Spiele die leisen Knöpfe („Neu mischen", „Spielerzahl
  ändern"): Sie sind jetzt höher, also auch im Layout zu prüfen. Und die
  Stapelwahl unter „Eigene Karten" hat vier Kacheln und bricht um.
- **Aufstellung, Vorbereitung, Hintergrund**: „am Tisch", das Setzen beim
  Pferderennen, Dauer und Strafe auf den Extreme-Karten, die Frage nach der
  offenen Partie, der Hintergrund.
- **Ordner, Einstellungen, Farbschemata**: die vier
  Ordner, der Einstellungs-Screen, die vier Farbschemata (Minze, Beere und
  Eis sind gerechnet, nicht gesehen – besonders die Statusfarben auf dem
  neuen Grund), „Nochmal dieselben", frühere Abende samt Teilen, die
  Sicherungs-Erinnerung, die Anleitungen. Und einmal mit großer Schrift
  durch die App: 105 Größen folgen jetzt der Systemeinstellung.
### Technik
- **Widget-Extension:** Erst der Sideload zeigt, ob die `.ipa` installierbar
  bleibt (Lessons Learned Nr. 5).
---

## 10. Offene Entscheidungen des Nutzers

**Elo: abgelehnt (September 2026).** `eloRating` steht in drei Modellen, in
`LeaderboardEntry` und in der Sicherungsdatei – immer auf `1000`, nirgends
gerechnet. Gerechnet werden soll es ausdrücklich nicht. Damit bleibt nur
streichen oder so lassen; bitte nicht ungefragt wieder als Vorschlag
aufwärmen. Der Kommentar am Feld versprach bis zum 25. Oktober ein
"Feature folgt später (siehe Roadmap)" – das ist korrigiert, denn es gibt
keine Roadmap und die Entscheidung ist gefallen.

**Zwei weitere Felder warten auf nichts.** `Game.currentTurnTeamId` und
`Game.playerStreaks` warten laut Kommentar auf dieselbe Cloud Function, die
es ohne Blaze nie geben wird – sie werden einmal beim Anlegen geschrieben
und von keiner Logik gelesen (`GameInitializationTests` prüft, dass
`playerStreaks` korrekt mit Nullen anfängt – also dass ein Feld, das
niemand liest, richtig leer ist). Dasselbe gilt für
`users/{uid}/stats/summary`. Streichen wäre richtig, ist aber eine
Änderung am Datenmodell und an der Sicherungsdatei: Das entscheidet der
Nutzer, nicht Claude.

**Lokal-zuerst statt Firestore.** Firestore kauft genau eine Sache:
Synchronisation über mehrere Geräte. Die ist dormant (`Features/Friends/`,
`LobbyView`) und wurde zweimal abgewählt. Bezahlt wird dafür mit Kontingent,
Regeln, einem Login vor der ersten Nutzung und einem Konto als
Totalverlust-Risiko. **Lokal-zuerst** würde all das auflösen – und die
neueren Bausteine (Abend, Trinkbilanz, eigene Karten, ausgeblendete Karten)
liegen ohnehin schon in UserDefaults. Nicht eigenmächtig umbauen; aber wenn
der Nutzer danach fragt, ist das die Antwort.
