//
//  SeededGenerator.swift
//  BeerStatsTests
//
//  Ausgesaeter Zufall fuer Tests, die mit Zufall rechnen.
//
//  Mit `SystemRandomNumberGenerator` waere ein seltener Fall einmal rot und
//  beim naechsten Lauf wieder gruen – und damit unauffindbar. Mit festem
//  Startwert ist jeder Fehlschlag wiederholbar.
//
//  Stand bis zum 28. Oktober privat in `ThrowLogReplayTests`; seit auch die
//  Auslosung im Ring gerechnet wird (`RingDrawTests`), brauchen ihn zwei
//  Tests, und eine zweite Kopie liefe auseinander.
//

struct SeededGenerator: RandomNumberGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
