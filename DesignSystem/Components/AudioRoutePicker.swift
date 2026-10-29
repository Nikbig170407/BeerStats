//
//  AudioRoutePicker.swift
//  BeerStats
//
//  Der Knopf, mit dem der Ton auf eine Box geht – AirPlay oder Bluetooth.
//
//  Am Tisch laeuft die Musik selten aus dem Handy selbst. Ohne diesen Knopf
//  muesste man dafuer aus dem Spiel heraus ins Kontrollzentrum.
//

import AVKit
import SwiftUI

struct AudioRoutePicker: UIViewRepresentable {

    var tint: Color = BeerStatsColor.textSecondary

    func makeUIView(context: Context) -> AVRoutePickerView {
        let knopf = AVRoutePickerView()
        knopf.backgroundColor = .clear
        knopf.prioritizesVideoDevices = false
        knopf.tintColor = UIColor(tint)
        knopf.activeTintColor = UIColor(BeerStatsColor.accent)
        return knopf
    }

    func updateUIView(_ knopf: AVRoutePickerView, context: Context) {
        knopf.tintColor = UIColor(tint)
    }
}
