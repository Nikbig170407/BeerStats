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
  Extreme-Karten; Lücken bleiben als gestrichelter Platz stehen.
- **Bussfahrer hat sein Ende** (17. Oktober): Zwei Hälften, wie am Tisch –
  erst die Fragerunde, dann **die Busfahrt**. Die hatte gefehlt: Das Spiel
  hörte nach der vierten richtigen Antwort auf („Das Handy geht weiter"),
  und der Bussfahrer, der dem Spiel den Namen gibt, kam nie vor. Jetzt deckt
  er fünf Karten auf, und jede Bildkarte schickt ihn zurück an den Anfang.
- **Der Ring spielt mit** (17. Oktober): Die Karten liegen zufällig gestreut
  und **geschuppt** – jede ein Stück unter der nächsten, wie am echten
  Tisch. Reißt ein Zug den Ring, kostet er einen Shot. Vorher lagen sie in
  gleichen Abständen mit Luft dazwischen und die Regel gab es nicht: ein
  Stapel, den jemand im Kreis angeordnet hatte.
- **Nochmal dieselben**: die letzte Aufstellung als Zeile im Beerpong-Menü,
  gestartet mit den aktuellen Hausregeln.
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
- **Nicht gespeicherte Würfe lassen sich nachreichen** – siehe unten.
- **Die Partyspiele sagen Namen statt Nummern**, sobald jemand am Tisch
  steht – auch ohne laufenden Abend (`PlayerNames`, Reihenfolge unten).
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
- **Die Stapel sind groß** (Stand 16. Oktober): 225 Aussagen bei „Ich hab
  noch nie" (drei Stufen à 75), 140 Karten bei „Wahrheit oder Pflicht",
  125 Begriffe beim Spion, 100 Karten bei „Wer würde eher?", 100 verbotene
  Wörter, 90 Kategorien, 80 Schätzfragen, 70 Begriffe je Kategorie bei „Wer
  bin ich?", 64 Bingo-Felder, 60 Themen bei „Zwei Wahrheiten", 45 Strafkarten.
  Wo **nicht** nachgelegt werden kann, liegt es am Spiel und nicht am
  Fleiß: Ring of Fire hat dreizehn Ränge, Bussfahrer und Pferderennen ein
  Skatblatt, Trink-Roulette acht Felder auf dem Rad. Mehr Karten wären dort
  ein anderes Spiel.
- Zwanzig Partyspiele auf dem Handy, in vier Gruppen im Hauptmenü:
  *Mit Karten* – Ring of Fire, Pferderennen, Bussfahrer, Wahrheit oder
  Pflicht, Ich hab noch nie. *Raten & reden* – Schocken, Mäxchen, Zwei
  Wahrheiten, Der Spion, Wer bin ich?, 21, Schätzmeister, Kategorien,
  Wer würde eher?, Kennst du deine Leute?. *Schnell zwischendurch* – Bombe,
  Reaktionsduell, Trink-Roulette. *Läuft nebenher* – Verbotene Wörter,
  Trinkbingo.
  Die Zahl im Text und die Fälle in `PartyGame` müssen zusammenpassen –
  hier standen eine Zeit lang neunzehn, aufgezählt waren siebzehn.

**Was man beim Weiterbauen wissen muss:**

- **Partyspiele stehen im Katalog `PartyGame`, nicht im Hauptmenü.**
  Titel, Emoji, Untertitel, Farbe, Gruppe und Ziel-Ansicht liegen dort
  beisammen; `HomeView` baut die Liste daraus. Ein neues Spiel ist ein
  neuer Fall in der Aufzählung – und zwar der einzige nötige Eingriff: Am
  Katalog hängen inzwischen Ordner, Anleitung, Turnier-Eignung und die
  Härte. Wer ein Spiel stattdessen in die View schreibt, hat es nirgends
  davon.

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

- **Wer heute mitspielt, steht in `TableRoster`** – und kommt über
  `\.tablePlayers` in der SwiftUI-Umgebung bei den Spielen an, nicht als
  Parameter an `PartyGame.destination`. Sonst müssten alle zwanzig Spiele
  die Liste annehmen, auch die achtzehn, die sie nicht brauchen. Wichtig:
  **Leer ist ein gültiger Zustand** – wer keine Profile hat, spielt ohne
  Namen weiter. Beide Wege müssen im Spiel stehen, nicht nur der schöne.
  Nicht zu verwechseln mit `PlayerProfile.isActive`: Das heißt „gehört noch
  zur Truppe" und gilt für Monate, die Aufstellung heißt „ist heute da".

- **Ein fehlgeschlagener Schreibvorgang darf nicht verpuffen.** Der
  Wurf-Log ist die Wahrheit; fehlt dort ein Eintrag, läuft die
  nachgespielte Partie dauerhaft anders als die gespielte. Scheitert das
  Schreiben, merkt sich `LiveGameViewModel` den Vorgang und reicht ihn auf
  Knopfdruck nach. Das geht nur, weil die laufende Nummer im mitgegebenen
  Spielzustand steckt und nicht in der Uhrzeit des Schreibens – ein
  Eintrag darf beliebig später kommen.

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
  (`PartyGame.howToPlay`). Im Spiel stünden sie in zwanzig verschiedenen
  Formen, und ein neues Spiel hätte sie garantiert nicht.

- **Extreme-Karten tragen Dauer und Strafe als eigene Felder**, nicht im
  Text. Die Dauer steht auf jeder Karte, auch wenn sie „Sofort" lautet; die
  Strafe fehlt nur dort, wo es nichts zu brechen gibt. Drei Tests halten das
  fest, einer davon: Jede Challenge muss sagen, was Verweigern kostet – ohne
  das ist sie eine Bitte.

- **Kartenspiele tragen den ganzen Satz auf der Karte**, nicht nur den
  Nachsatz. Ein fester Vorspann („Ich hab noch nie …") kann grammatisch
  nicht aufgehen: Es gibt „Ich bin noch nie …" und „Ich hatte noch nie …".

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

- **Partyspiele zahlen nicht auf die Beerpong-Statistiken ein.** Eine Runde
  Bombe hat keine Trefferquote. Wer dort eine Wertung will, braucht einen
  eigenen Zähler, nicht `UserStatistics`.
- **Trinkmengen niemals als Zahl in den Text schreiben.** Sie laufen über
  `DrinkAmount` (`.sips(3)`, `.shot`) und werden erst beim Anzeigen in der
  geltenden Härte ausformuliert. Eine fest eingetippte Menge ignoriert die
  Einstellung stillschweigend – und genau so etwas fällt erst am Tisch auf.

- **Der Riss in Ring of Fire ist Rechnerei, nicht Zufall** (`RingLayout`).
  Zwei Konstanten machen das Spiel, beide durchgerechnet und per Test
  gedeckelt: `overlapFactor` (2,4) sagt, wie viel breiter eine Karte ist als
  der mittlere Abstand zur Nachbarin, `jitter` (0,6) streut die Abstände.
  Ohne Streuung lägen alle Karten gleich dicht, und Ziehen wäre entweder nie
  oder immer gefährlich; mit Streuung gibt es dichte Stellen und dünne – und
  **man kann es sehen**. Ergebnis: Solange der Ring geschlossen daliegt,
  reißt etwa jeder sechste Zug, über eine Runde mit 52 Karten drei bis vier.
  Zwei Feinheiten, die beide einen Shot wert sind: Die Abstände werden auf
  genau 360 Grad **normiert** (sonst klafft zwischen der letzten und der
  ersten Karte eine Naht, die nie jemand gezogen hat), und neben einer
  bestehenden Lücke reißt **nichts** (dort war schon offen – zweimal zahlt
  niemand für dieselbe Lücke). Die **Kartenbreite folgt dem Layout**, nicht
  umgekehrt: Was man an Überlappung sieht, ist genau das, womit gerechnet
  wird. Wer die Breite frei wählt, baut ein Bild, das lügt.

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
    sieben Spiele fragen vorher ohnehin etwas und haben die Härte in
    demselben Vorspann, dreizehn bekommen einen eigenen (`IntensityGate`).
    **Jedes** Partyspiel nennt inzwischen eine Menge und hat damit eine
    Härte – Bombe, Reaktionsduell und „Wer würde eher?" sagten bis zum
    13. Oktober bloßes „du trinkst", und was die Runde dann aushandelte,
    hatte mit der eingestellten Härte nichts zu tun. Dass ein neues Spiel
    eingeordnet wird, erzwingt der Compiler: `intensityStep` ist ein
    vollständiges `switch` ohne `default`. Ein neues Spiel wird an dieser einen Stelle
    eingeordnet – wer es vergisst, hat ein Spiel ohne Härte-Wahl, und ein
    Test hält das fest.

**Bewusst dormant:** Das Freundesystem (`Features/Friends/`) und
`LobbyView` sind gebaut, aber nicht verlinkt. Sie sind der Weg für später,
wenn die App auf mehreren Geräten läuft. Nicht löschen.

**Offen / denkbar**, nach Wert sortiert:

1. **`LiveGameViewModel` teilen.** 771 Zeilen, zehn `@Published`. Vier der
   acht Funde aus der Cloud-Prüfung vom 15. August lagen dort, alle mit
   derselben Ursache: derselbe Zustand an zwei Stellen gehalten. Ein Schnitt
   entlang Regelwerk / Synchronisation / Nebenwirkungen legt die Fehlerklasse
   trocken, statt sie einzeln zu jagen.

Weiter denkbar, aber ohne konkreten Anlass: Cloud Functions (bräuchte
Blaze), Ergebnis als Bild teilen.

**Die Live Activity steht hier nicht mehr – sie ist gebaut.** Sie stand
monatelang als Idee in dieser Liste, obwohl `LiveGameActivity` samt Start,
Aktualisieren und Beenden im `LiveGameViewModel` liegt und `LiveGameView`
sie beim Erscheinen startet. Eine Liste offener Punkte, die Fertiges
enthält, kostet beim nächsten Mal genau die Zeit, die sie sparen soll.

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
- **Alles vom 6. bis 8. Oktober**: Ring of Fire in zwei Screens, die vier
  Ordner, der Einstellungs-Screen, die vier Farbschemata (Minze, Beere und
  Eis sind gerechnet, nicht gesehen – besonders die Statusfarben auf dem
  neuen Grund), „Nochmal dieselben", frühere Abende samt Teilen, die
  Sicherungs-Erinnerung, die Anleitungen. Und einmal mit großer Schrift
  durch die App: 105 Größen folgen jetzt der Systemeinstellung.
- **Nachreichen**: Flugmodus an, ein paar Würfe tippen, Netz an, „Nachreichen"
  drücken – und danach die Partie fortsetzen und prüfen, ob der Stand
  stimmt. Das ist der einzige Weg, an dem Daten verloren gehen können.
- **Team-Chemie (2. Oktober)**: Stimmen bester Partner und schlimmster
  Gegner mit dem überein, was ihr am Tisch sagen würdet? Die Rechnung ist
  per Test abgedeckt, die Datenlage nicht – bei wenigen Partien kann ein
  Name oben stehen, der sich falsch anfühlt.
- **Alles vom 1. Oktober**: Endstand im Spielverlauf (alte Partien müssen
  einen Strich zeigen, neue ein echtes Ergebnis), die Trefferquote nach
  Tageszeit, und ob die Partyspiele die richtigen Namen sagen – besonders
  mit laufendem Abend, wo seine Teilnehmer gelten und nicht der Tisch.
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
- **„Kennst du deine Leute?" (8. Oktober)**: Stehen überhaupt Fragen da,
  oder sagt das Spiel „noch zu wenig gespielt"? Die beiden Grenzen sind
  getestet, die Datenlage nicht – mit wenigen Partien kann es gut sein, dass
  nur zwei oder drei Fragen übrig bleiben. Und: Landet die Strafe beim
  Richtigen, wenn ein Abend läuft?
- **Hauptmenü vom 13. Oktober**: Die Ordner sind größer, und die Zahl steht
  jetzt als „5 Spiele" in der Unterzeile statt fett und farbig am rechten
  Rand – dort sah sie aus wie eine ungelesene Nachricht. „Zuletzt gespielt"
  ist weg. Passt das Ganze noch, auch mit großer Schrift?
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
- **„Wer ist dran?" (18. Oktober)**: In Ring of Fire, Ich hab noch nie,
  Wahrheit oder Pflicht, Zwei Wahrheiten, Kategorien und Bussfahrer. Zeigt
  die Zeile die richtige Person, und läuft sie im selben Takt wie der Kreis
  am Tisch? Ohne Abend und ohne Aufstellung muss sie **ganz weg** sein.
- **Beerpong mit Namen (18. Oktober)**: Die Einblendungen sagen jetzt
  „Lena & Jan werfen nochmal". Zu prüfen, ob in der schmalen Team-Leiste
  und auf dem Sperrbildschirm nichts abgeschnitten wird – da steht die
  Kurzform.
- **Bussfahrer vom 17. Oktober**: Die Busfahrt ist neu und nie gelaufen.
  Fünf Karten, jede Bildkarte zurück an den Anfang – gerechnet kommt der
  Bussfahrer in etwa jedem sechsten Versuch durch. Fühlt sich das am Tisch
  richtig an oder sitzt er zu lange? Und füllt der Screen jetzt?
- **Mehr Platz in sechs Spielen** (17. Oktober): Die Karten wachsen in den
  freien Raum. Zu prüfen, ob irgendwo das Gegenteil passiert – eine Karte,
  die mit kurzem Text riesig und leer dasteht.
- **Ring of Fire vom 17. Oktober**: Das Wichtigste zuerst – liegen die
  Karten erkennbar geschuppt, und sieht man die dünnen Stellen? Dann: reißt
  der Ring ungefähr so oft, dass es Spannung macht statt Ärger (gerechnet:
  drei bis vier Shots auf 52 Karten)? Blitz, Ruck und Knall beim Riss sind
  nie auf Hardware gelaufen. Und bei **zwanzig** Karten wird der Kranz dicht
  und das Loch in der Mitte klein – dort steht dann nur die Zahl, ohne
  Flasche und ohne „übrig". Passt das?
- **Schwarze Karten**: Pik und Kreuz waren weiß und damit unsichtbar. Einmal
  durch Ring of Fire, Bussfahrer und Pferderennen schauen, ob alle vier
  Farben jetzt normal aussehen.
- **Sechs Kacheln im Hauptmenü** (17. Oktober): Beerpong oben links, Turnier
  unten rechts. Passt das Raster auf dem Gerät, auch mit großer Schrift?
- **Knöpfe vom 12. Oktober**: Der Daumen nach unten muss jetzt bei **jeder**
  Karte gehen, nicht nur bei der ersten – zweimal hintereinander in „Ich hab
  noch nie" ausprobieren. Dazu „Wer würde eher?", das ihn neu hat, und einmal
  quer durch die Spiele die leisen Knöpfe („Neu mischen", „Spielerzahl
  ändern"): Sie sind jetzt höher, also auch im Layout zu prüfen. Und die
  Stapelwahl unter „Eigene Karten" hat vier Kacheln und bricht um.
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

**Lokal-zuerst statt Firestore.** Firestore kauft genau eine Sache:
Synchronisation über mehrere Geräte. Die ist dormant (`Features/Friends/`,
`LobbyView`) und wurde zweimal abgewählt. Bezahlt wird dafür mit Kontingent,
Regeln, einem Login vor der ersten Nutzung und einem Konto als
Totalverlust-Risiko. **Lokal-zuerst** würde all das auflösen – und die
neueren Bausteine (Abend, Trinkbilanz, eigene Karten, ausgeblendete Karten)
liegen ohnehin schon in UserDefaults. Nicht eigenmächtig umbauen; aber wenn
der Nutzer danach fragt, ist das die Antwort.
