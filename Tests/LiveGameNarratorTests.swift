//
//  LiveGameNarratorTests.swift
//  BeerStatsTests
//
//  Prueft, was die App bei einem Ereignis sagt und einblendet.
//
//  Vor dem Schnitt vom 18. Oktober gab es diesen Test nicht, und er haette
//  sich auch nicht schreiben lassen: Die Saetze entstanden in derselben
//  Funktion, die Haptik ausloeste und Klaenge abspielte, und die steckte in
//  einem ViewModel, das ohne Firestore-Attrappe nicht zu bauen war. Jetzt
//  sind es zwei reine Funktionen auf einem Wert.
//
//  Geprueft wird die Stelle, an der es wirklich schiefgeht: die Grammatik
//  (ein Spieler gegen zwei) und die Frage, welches Ereignis ueberhaupt eine
//  Einblendung verdient.
//

import XCTest
@testable import BeerStats

final class LiveGameNarratorTests: XCTestCase {

    private func narrator(_ eins: [String], _ zwei: [String]) -> LiveGameNarrator {
        let teams = [
            Team(id: "a", playerIds: eins, playerNames: eins, ballsInPlay: eins.count),
            Team(id: "b", playerIds: zwei, playerNames: zwei, ballsInPlay: zwei.count)
        ]
        return LiveGameNarrator(naming: LiveGameNaming(teams: teams))
    }

    // MARK: - Die Grammatik

    func testOnePlayerGetsTheSingularVerb() {
        let text = narrator(["Lena"], ["Jan"]).logText(for: .ballsBack(teamIndex: 0))
        XCTAssertTrue(text.contains("Lena wirft nochmal"), text)
    }

    func testTwoPlayersGetThePluralVerb() {
        let text = narrator(["Lena", "Tim"], ["Jan"]).logText(for: .ballsBack(teamIndex: 0))
        XCTAssertTrue(text.contains("Lena & Tim werfen nochmal"), text)
    }

    /// Dasselbe noch einmal fuer die Einblendung: Sie baut ihren Satz
    /// getrennt vom Protokoll, und genau dort ist die Grammatik schon
    /// einmal liegen geblieben.
    func testTheHighlightConjugatesAsWell() {
        let einer = narrator(["Lena"], ["Jan"]).highlight(for: .bombe(choosingTeamIndex: 0))
        XCTAssertEqual(einer?.subtitle, "Lena wählt 2 weitere Becher")

        let zwei = narrator(["Lena", "Tim"], ["Jan"]).highlight(for: .bombe(choosingTeamIndex: 0))
        XCTAssertEqual(zwei?.subtitle, "Lena & Tim wählen 2 weitere Becher")
    }

    /// Ohne Namen bleibt die Nummer – der Fall "Partie aus einer Sicherung".
    func testWithoutNamesTheNumberRemains() {
        let text = narrator([], []).logText(for: .ballsBack(teamIndex: 1))
        XCTAssertTrue(text.contains("Team 2"), text)
    }

    // MARK: - Wer bekommt eine Einblendung?

    /// Ein normaler Treffer und ein Fehlwurf passieren im Minutentakt. Was
    /// dauernd aufblitzt, nimmt niemand mehr wahr.
    func testTheEverydayEventsStayQuiet() {
        let n = narrator(["Lena"], ["Jan"])
        let werfer = PlayerRef(teamIndex: 0, slot: 0)

        XCTAssertNil(n.highlight(for: .hit(thrower: werfer, bounce: false, trickshot: false, cupIndex: 3)))
        XCTAssertNil(n.highlight(for: .missed(thrower: werfer)))
        XCTAssertNil(n.highlight(for: .cupChosen(byTeamIndex: 1, cupIndex: 2)))
    }

    func testBounceAndTrickshotAreWorthShowing() {
        let n = narrator(["Lena"], ["Jan"])
        let werfer = PlayerRef(teamIndex: 0, slot: 0)

        XCTAssertEqual(
            n.highlight(for: .hit(thrower: werfer, bounce: true, trickshot: false, cupIndex: 1))?.kind,
            .bounce
        )
        XCTAssertEqual(
            n.highlight(for: .hit(thrower: werfer, bounce: false, trickshot: true, cupIndex: 1))?.kind,
            .trickshot
        )
    }

    /// Der Airball im Trickshot kostet nichts. Ein rotes „AIRBALL!" ueber
    /// einem folgenlosen Wurf waere eine Luege – und genau diese
    /// Unterscheidung steht im Regelwerk.
    func testOnlyThePunishedAirballIsShown() {
        let n = narrator(["Lena"], ["Jan"])
        let werfer = PlayerRef(teamIndex: 0, slot: 0)

        XCTAssertNil(n.highlight(for: .airball(thrower: werfer, penalised: false)))
        XCTAssertEqual(n.highlight(for: .airball(thrower: werfer, penalised: true))?.kind, .airball)
    }

    /// Das Spielende hat den Sieger-Screen – eine Einblendung davor wuerde
    /// ihn nur ueberdecken.
    func testTheEndHasNoHighlight() {
        XCTAssertNil(narrator(["Lena"], ["Jan"]).highlight(for: .finished(winnerTeamIndex: 0)))
    }
}
