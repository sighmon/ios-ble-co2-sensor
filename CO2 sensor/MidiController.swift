//
//  MidiController.swift
//  CO2 sensor
//
//  Created by Simon Loffler on 11/9/2022.
//

import Foundation
import AudioToolbox
import SwiftUI

func playNote(co2: Int16) {
    var sequence : MusicSequence? = nil
    NewMusicSequence(&sequence)

    var track : MusicTrack? = nil
    MusicSequenceNewTrack(sequence!, &track)

    // Play middle C (60) corresponding to 1,000 ppm
    var time = MusicTimeStamp(0.5)
    var note = MIDINoteMessage(
        channel: 0,
        note: 60,
        velocity: 64,
        releaseVelocity: 0,
        duration: 0.5
    )
    MusicTrackNewMIDINoteEvent(track!, time, &note)
    time += 0.5

    // Play a note corresponding to the current CO2 ppm
    let co2Note = UInt8(Double(co2) / (1000 / 60))
    print("Playing CO2 \(co2) ppm as note \(co2Note)")
    note = MIDINoteMessage(
        channel: 0,
        note: co2Note,
        velocity: 64,
        releaseVelocity: 0,
        duration: 0.5
    )
    MusicTrackNewMIDINoteEvent(track!, time, &note)

    // Creating a player
    var musicPlayer : MusicPlayer? = nil
    NewMusicPlayer(&musicPlayer)
    MusicPlayerSetSequence(musicPlayer!, sequence)
    MusicPlayerStart(musicPlayer!)
}

func vibrate(co2: Int16) {
    if co2 > 2000 {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    } else if co2 > 1000 {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    } else {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
