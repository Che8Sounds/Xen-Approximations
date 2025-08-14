//
//  TonePlayer.swift
//  Xen Approximations Calc
//
//  Created by Ghifar on 24.06.25.
//
import AudioKit
import AVFoundation
import Combine

class TonePlayer {
    let engine = AudioEngine()
    let sampler = AppleSampler()
    private var noteMap: [Int: (note: MIDINoteNumber, bend: MIDIWord, channel: MIDIChannel)] = [:]
    private let velocity: MIDIVelocity = 100
    private let pitchBendRange: Double = 2.0 // in semitones (default for most synths)
    private var activeNoteIds: Set<Int> = []
    private let maxCombinedAmplitude: AUValue = 0.9
    private var nextChannel: MIDIChannel = 0
    private let maxChannels: MIDIChannel = 16 // MIDI has 16 channels (0-15), so we need 16 for modulo

    init() {
        engine.output = sampler
        do {
            try engine.start()
        } catch {
            print("AudioKit did not start! \(error)")
        }
    }

    // Convert cents to frequency (0.00 cents = 440 Hz)
    func centsToFrequency(_ cents: Double) -> Double {
        return 440.0 * pow(2.0, cents / 1200.0)
    }

    // Convert frequency to MIDI note and pitch bend value
    func frequencyToMIDINoteAndBend(_ frequency: Double) -> (MIDINoteNumber, MIDIWord) {
        // MIDI note number (float)
        let midiNoteFloat = 69 + 12 * log2(frequency / 440.0)
        
        // Clamp the MIDI note to valid range (0-127)
        let clampedMidiNoteFloat = max(0, min(127, midiNoteFloat))
        let midiNote = MIDINoteNumber(Int(clampedMidiNoteFloat.rounded(.down)))
        let semitoneOffset = clampedMidiNoteFloat - Double(midiNote)
        
        // MIDI pitch bend: 8192 is center, range is 0..16383
        // Calculate pitch bend for the fractional part, assuming +/-2 semitones range
        let bend = Int(8192 + (semitoneOffset / pitchBendRange) * 8192)
        let bendClamped = MIDIWord(max(0, min(16383, bend)))
        return (midiNote, bendClamped)
    }

    private func getNextChannel() -> MIDIChannel {
        let channel = nextChannel
        nextChannel = (nextChannel + 1) % maxChannels
        return channel
    }

    private func updateAmplitude() {
        let count = max(1, activeNoteIds.count)
        // For N notes, set amplitude to -20*log10(N) dB so that N*amp = 1.0 (0 dB)
        let dB = -20.0 * log10(Double(count))
        sampler.amplitude = AUValue(dB)
    }

    // Play a note at the given cents value, with a unique id (e.g., row index)
    func play(cents: Double, id: Int) {
        let freq = centsToFrequency(cents)
        let (note, bend) = frequencyToMIDINoteAndBend(freq)
        let channel = getNextChannel()
        noteMap[id] = (note, bend, channel)
        
        // Debug logging
        print("Playing note: cents=\(cents), freq=\(freq), MIDI note=\(note), bend=\(bend), channel=\(channel)")
        
        // Reset pitch bend to center first, then set the new value
        sampler.setPitchbend(amount: 8192, channel: channel) // Center
        sampler.setPitchbend(amount: bend, channel: channel)  // Set desired bend
        sampler.play(noteNumber: note, velocity: velocity, channel: channel)
        activeNoteIds.insert(id)
        updateAmplitude()
    }

    // Stop the note with the given id
    func stop(id: Int) {
        if let (note, _, channel) = noteMap[id] {
            print("Stopping note: MIDI note=\(note), channel=\(channel)")
            sampler.stop(noteNumber: note, channel: channel)
            // Reset pitch bend to center when stopping
            sampler.setPitchbend(amount: 8192, channel: channel)
            noteMap.removeValue(forKey: id)
            activeNoteIds.remove(id)
            updateAmplitude()
        }
    }
}

func testAudioKit() {
    let engine = AudioEngine()
    print(engine)
    // let osc = Oscillator() // See if this line errors
    // let akOsc = AKOscillator() // See if this line errors
}

class TonePlayerWrapper: ObservableObject {
    let player = TonePlayer()
}
