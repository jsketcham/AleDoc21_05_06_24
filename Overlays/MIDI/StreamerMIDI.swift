//
//  StreamerMIDI.swift
//  Streamer
//
//  Created by Jim on 8/5/22.
//  MIDI rx/tx for the VM15A emulator

import Cocoa

@objc protocol StreamerMIDIDelegate{
    
    @objc optional func inputsChanged(_ inputNames : [String])
    @objc optional func outputsChanged(_ outputNames : [String])
    @objc optional func didSelectInput(_ input : String)
    @objc optional func didSelectOutput(_ output : String)
    @objc optional func noteOnService(_ midi : [UInt8])
    @objc optional func controlChangeService(_ midi : [UInt8])
    @objc optional func sysexService(_ midi : [UInt8])
    @objc optional func mtcService(_ mtc : UInt8)

}

class StreamerMIDI: NSObject {
    
    var midiClient : SwiftMidiClient?
    var delegate : StreamerMIDIDelegate?
//    var midiBuffer : [UInt8] = [UInt8]()

    init(_ delegate : StreamerMIDIDelegate) {
        super.init()
        
        self.delegate = delegate
        midiClient = SwiftMidiClient("Beeps",self, MENU_TYPE.OUT_ONLY)   // sets delegate
    }
    
//    func midiTx(_ data : NSData){
//
//        midiClient?.midiTx(data)
//
//    }

}
// MARK: ----------- MidiClientDelegate ------------------
extension StreamerMIDI : SwiftMidiClientDelegate{
    
    func processBytes(_ bytes : [UInt8]){
        
        var midi = bytes
        print("midi \(midi)")
        
        // we assume that only complete messages get here
        
        while midi.count > 0{
            switch (midi[0] & 0xf0){    // mask out the channel
            case NOTE_OFF:
                if midi.count < 3{return}   // not enough bytes
                midi.removeFirst(noteOff(midi))
                break
            case NOTE_ON:
                if midi.count < 3{return}   // not enough bytes
                midi.removeFirst(noteOn(midi))
                break
            case POLY_PRESSURE:
                if midi.count < 3{return}   // not enough bytes
                midi.removeFirst(3)
                break
            case CONTROL_CHANGE:
                if midi.count < 3{return}   // not enough bytes
                midi.removeFirst(controlChange(midi))
                break
            case PROG_CHANGE:
                if midi.count < 2{return}   // not enough bytes
                midi.removeFirst(2)
                break
            case CHANNEL_PRESSURE:
                if midi.count < 2{return}   // not enough bytes
                midi.removeFirst(2)
                break
            case PITCH_BEND:
                if midi.count < 3{return}   // not enough bytes
                midi.removeFirst(3)
                break
            case SYSTEM_EXCLUSIVE:  // all 0xfn commands, actually
                midi.removeFirst(fnCmd(midi))
                break
            default:
                midi.removeAll()    // unhandled case, toss the record
                break
                
            }
        }
    }
    
    func noteOff(_ midi : [UInt8])-> Int{
        
        for i in stride(from: 1, through: midi.count - 1, by: 2){
            
            if midi[i] & 0x80 == 0x80{return i}
        }
        
        return midi.count
    }
    func noteOn(_ midi : [UInt8])-> Int{
        
        for i in stride(from: 1, through: midi.count - 1, by: 2){
            
            if midi[i] & 0x80 == 0x80{return i}
            
            DispatchQueue.main.async {
                self.delegate?.noteOnService?(Array(midi[i..<i+2]))
            }
            
//            performSelector(onMainThread: #selector(delegate?.noteOnService(_:)), with: midi, waitUntilDone: false)

        }
        
        return midi.count
    }

    func controlChange(_ midi : [UInt8])-> Int{
        
        for i in stride(from: 1, through: midi.count - 1, by: 2){
            
            if midi[i] & 0x80 == 0x80{
                return i
            }
            
            DispatchQueue.main.async {
                self.delegate?.controlChangeService?(Array(midi[i..<i+2]))
            }

//            performSelector(onMainThread: #selector(delegate?.controlChangeService(_:)), with: midi, waitUntilDone: false)
        }
        
        return midi.count
    }
    
    func fnCmd(_ midi : [UInt8])-> Int{
        
        // commands of the form fn (sysex for instance)
        // returns the number of bytes used
        
        switch(midi[0]){
            
        case SYSTEM_EXCLUSIVE:
            
            if let index = midi.firstIndex(of: MIDI_EOX){
                
                DispatchQueue.main.async {
                    self.delegate?.sysexService?(Array(midi[0...index]))
                }
                
                return index + 1    // number of bytes to consume

            }
            return midi.count   // no EOX, toss the record
            
        case MTC_QUARTER_FRAME:
            if midi.count < 2{return midi.count}   // not enough bytes
            DispatchQueue.main.async {
                self.delegate?.mtcService?(midi[1])
            }
            return 2

        case SONG_POSITION_PTR:
            if midi.count < 3{return  midi.count}   // not enough bytes
            return 3

        case SONG_SELECT:
            if midi.count < 2{return  midi.count}   // not enough bytes
            return 2

        default: return 1   // undefined command, 1 byte
        }
    }
    
    @objc func inputsChanged(_ inputNames : [String]){
                
        // do this on the main thread
        DispatchQueue.main.async {
            self.delegate?.inputsChanged?(inputNames)
        }
    }
    @objc func outputsChanged(_ outputNames : [String]){
        
        // do this on the main thread
        DispatchQueue.main.async {
            self.delegate?.outputsChanged?(outputNames)
        }
        
    }
    @objc func didSelectInput(_ input : String){
        
        // do this on the main thread
        DispatchQueue.main.async {
            self.delegate?.didSelectInput?(input)
        }
        
    }
    @objc func didSelectOutput(_ output : String){
        
        // do this on the main thread
        DispatchQueue.main.async {
            self.delegate?.didSelectOutput?(output)
        }
    }

}
