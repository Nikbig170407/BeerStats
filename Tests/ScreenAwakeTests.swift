//
//  ScreenAwakeTests.swift
//  BeerStatsTests
//
//  Ob der Bildschirm anbleibt, entscheidet eine Zeile – aber sie hat zwei
//  Seiten, und beide fallen erst am Tisch auf: Geht er zu frueh aus, muss
//  jemand mitten in der Runde entsperren (die Rueckmeldung vom 3. November);
//  geht er nie aus, ist am naechsten Morgen der Akku leer.
//

import XCTest
@testable import BeerStats

final class ScreenAwakeTests: XCTestCase {

    /// Wer gerade spielt, hat den Bildschirm an – auch nach Minuten ohne
    /// Tippen, solange die Grenze nicht erreicht ist.
    func testAPlayedGameStaysAwake() {
        XCTAssertTrue(ScreenAwake.staysAwake(alwaysOn: false, untouchedFor: 0))
        XCTAssertTrue(ScreenAwake.staysAwake(alwaysOn: false, untouchedFor: ScreenAwake.untouchedLimit - 1))
    }

    /// Ein vergessenes Handy darf wieder sperren.
    func testAForgottenPhoneMayLockAgain() {
        XCTAssertFalse(ScreenAwake.staysAwake(alwaysOn: false, untouchedFor: ScreenAwake.untouchedLimit))
        XCTAssertFalse(ScreenAwake.staysAwake(alwaysOn: false, untouchedFor: 8 * 60 * 60))
    }

    /// Der Tischmodus haelt ihn ganz an – den hat jemand ausdruecklich
    /// eingeschaltet.
    func testTableModeKeepsItOnForGood() {
        XCTAssertTrue(ScreenAwake.staysAwake(alwaysOn: true, untouchedFor: 8 * 60 * 60))
    }

    /// Die Grenze selbst: deutlich laenger als jede Sperre, die man am
    /// iPhone einstellen kann (hoechstens fuenf Minuten) – sonst aenderte
    /// sich nichts. Aber nicht so lang, dass ein Handy in der Tasche den
    /// Abend ueber leuchtet.
    func testTheLimitIsLongerThanTheIPhonesButNotEndless() {
        XCTAssertGreaterThan(ScreenAwake.untouchedLimit, 5 * 60)
        XCTAssertLessThanOrEqual(ScreenAwake.untouchedLimit, 20 * 60)
    }
}
