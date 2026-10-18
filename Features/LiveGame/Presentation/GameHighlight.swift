//
//  GameHighlight.swift
//  BeerStats
//
//  Die kurzlebige Einblendung ueber dem Tisch – "BOMBE!", "ON FIRE!".
//
//  Lag als verschachtelter Typ im ViewModel. Dort war sie nicht zu bauen,
//  ohne das ganze ViewModel zu bauen – und genau das braucht ein Test, der
//  pruefen will, ob ein Ereignis die richtige Einblendung ergibt.
//
//  `LiveGameViewModel.Highlight` bleibt als Zweitname bestehen, damit die
//  Ansichten unveraendert weiterlaufen.
//

import SwiftUI

struct GameHighlight: Equatable, Identifiable {

    /// Bestimmt Farbe **und** Animation – deshalb nach dem Ereignis
    /// benannt und nicht nach der Stimmung.
    enum Kind: Equatable {
        case airball, ballsBack, bombe, onFire, reRack, redemption, bounce, trickshot, neutral
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let subtitle: String

    var tint: Color {
        switch kind {
        case .airball:    return BeerStatsColor.error
        case .ballsBack:  return BeerStatsColor.success
        case .bombe:      return BeerStatsColor.accentSecondary
        case .onFire:     return BeerStatsColor.accent
        case .reRack:     return BeerStatsColor.accent
        case .redemption: return BeerStatsColor.accentSecondary
        case .bounce:     return BeerStatsColor.warning
        case .trickshot:  return BeerStatsColor.success
        case .neutral:    return BeerStatsColor.textPrimary
        }
    }
}
