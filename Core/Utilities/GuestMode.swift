//
//  GuestMode.swift
//  BeerStats
//
//  Ob jemand ohne Konto spielt.
//
//  Bis Oktober 2026 stand der Login vor allem: Wer die App aufmachte, sah
//  ein Anmeldeformular. Fuer den Nutzer selbst war das einmal laestig, fuer
//  jede andere Runde ist es die Tuer, die zu bleibt – ein fremdes Handy
//  fragt nach einer E-Mail, bevor es ueberhaupt gezeigt hat, was es kann.
//
//  Dabei brauchen die Partyspiele Firestore gar nicht. Abend, Trinkbilanz,
//  eigene Karten, ausgeblendete Karten, die Aufstellung, die Haerte: alles
//  liegt schon in UserDefaults. Nur Beerpong braucht ein Konto, weil dort
//  Profile, Partien und der Wurf-Log hingehoeren.
//
//  Deshalb diese Trennung. Sie ist bewusst ein eigener Zustand und nicht
//  einfach "abgemeldet": Abgemeldet heisst "will sich anmelden und ist noch
//  nicht fertig", Gast heisst "will gar kein Konto". Beides fuehrt an
//  verschiedene Orte, und wer sich einmal fuer Gast entschieden hat, soll
//  beim naechsten Start nicht wieder im Formular landen.
//
//  Ein Konto kommt spaeter jederzeit dazu (Einstellungen). Was lokal liegt,
//  bleibt dabei liegen – es haengt nicht am Konto.
//

import Foundation

enum GuestMode {

    static let storageKey = "app.guestMode"

    /// Spielt gerade jemand ohne Konto?
    static var isOn: Bool {
        get { UserDefaults.standard.bool(forKey: storageKey) }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }

    /// Was ohne Konto nicht geht – einmal formuliert, damit es ueberall
    /// gleich dasteht.
    static let explanation = """
        Beerpong schreibt mit: Profile, Partien und jeden einzelnen Wurf. \
        Das liegt in deinem Konto, damit es ein neues Handy überlebt. \
        Die Partyspiele brauchen das nicht – die laufen ohne alles.
        """
}
