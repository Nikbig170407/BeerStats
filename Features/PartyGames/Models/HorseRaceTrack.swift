//
//  HorseRaceTrack.swift
//  BeerStats
//
//  Wie lang das Pferderennen ist.
//
//  Eigener Wert neben der Ansicht, weil ihn mehr als eine Stelle braucht: der
//  Screen fuers Raster, der Untertitel im Katalog und der Test. In der Ansicht
//  selbst waere der Untertitel eine Abhaengigkeit des Katalogs auf einen
//  Screen – und die Zahl stuende ein zweites Mal als Wort im Text und wuerde
//  beim naechsten Verkuerzen vergessen.
//

import Foundation

enum HorseRaceTrack {

    /// Felder bis zum Ziel. Sechs: kurz genug fuer mehrere Rennen am Abend,
    /// lang genug, dass die Seitenstrecke greift (vorher sieben, am
    /// 4. November auf Wunsch eine Spalte weniger).
    static let finishLine = 6

    /// Eine Seitenkarte je Spalte zwischen Start und Ziel. Abgeleitet und
    /// nicht getippt: Eine Karte ohne Spalte stuende ueber nichts, eine
    /// Spalte ohne Karte waere ein Feld, an dem nie etwas passiert. Am Start
    /// ist noch niemand vorbei, im Ziel ist das Rennen aus – beide haben
    /// keine.
    static let sideCount = finishLine - 1
}
