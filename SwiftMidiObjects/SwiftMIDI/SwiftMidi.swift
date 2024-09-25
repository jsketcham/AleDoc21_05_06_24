//
//  SwiftMidi.swift
//  LpMiniTester
//
//  Created by Pro Tools on 2/5/23.
//

import Cocoa

@objc protocol SwiftMidiDelegate{
    
    @objc optional func inputsChanged(_ inputNames : [String], _ sender : SwiftMidi)
    @objc optional func outputsChanged(_ outputNames : [String], _ sender : SwiftMidi)
    @objc optional func didSelectInput(_ input : String, _ sender : SwiftMidi)
    @objc optional func didSelectOutput(_ output : String, _ sender : SwiftMidi)
    @objc optional func noteOnService(_ midi : [UInt8], _ sender : SwiftMidi)
    @objc optional func noteOffService(_ midi : [UInt8], _ sender : SwiftMidi)
    @objc optional func controlChangeService(_ midi : [UInt8], _ sender : SwiftMidi)
    @objc optional func sysexService(_ midi : [UInt8], _ sender : SwiftMidi)
    @objc optional func mtcService(_ mtc : UInt8, _ sender : SwiftMidi)

}
@objc protocol SwiftMidiOscDelegate{
    
    @objc optional func midi(toOsc:Data, _:String)
}

class SwiftMidi: NSObject {
    
    @objc var midiClient : SwiftMidiClient?
    var delegate : SwiftMidiDelegate?
    var oscDelegate : SwiftMidiOscDelegate?
    
    var loopInToOut = false // Evan's loop through items

    init(_ delegate : SwiftMidiDelegate, _ menuTitle : String,_ menuType :MENU_TYPE) {
        super.init()
        
        self.delegate = delegate
        midiClient = SwiftMidiClient(menuTitle,self, menuType)   // sets delegate
    }
}
// MARK: ----------- MidiClientDelegate ------------------
extension SwiftMidi : SwiftMidiClientDelegate{
    
    func processBytes(_ bytes : [UInt8]){
        
        if loopInToOut{
            // relay the input to the output, Evan's request, 09/08/23 2.10.02
            midiClient?.midiTx(NSData(bytes: bytes, length: bytes.count))
        }
        
        // maybe send to OSC (MIDI indicators)
        oscDelegate?.midi?(toOsc: Data(bytes: bytes, count: bytes.count), (midiClient?.title)!)

        var midi = bytes
//        print("midi \(midi)")
        
        // we assume that only complete messages get here
        
        while midi.count > 0{
            switch (midi[0] & 0xf0){    // mask out the channel
            case NOTE_OFF:
                midi.removeFirst(threeByteMidi(midi))
                break
            case NOTE_ON:
                midi.removeFirst(threeByteMidi(midi))
                break
            case POLY_PRESSURE:
                if midi.count < 3{return}   // not enough bytes
                midi.removeFirst(3)
                break
            case CONTROL_CHANGE:
                midi.removeFirst(threeByteMidi(midi))
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
    
    func threeByteMidi(_ midi : [UInt8])-> Int{
        
        // NOTE_ON, NOTE_OFF, CONTROL_CHANGE have the same record format
        if midi.count < 3{return midi.count}
        
        for i in stride(from: 1, through: midi.count - 1, by: 2){
            
            if midi[i] & 0x80 == 0x80{return i}
            
            // 11/5/23 saw this error
            if (midi.count - i) < 2{
                return midi.count
            }

            DispatchQueue.main.async {
                // keep the first byte, which has channel number
                var array = Array.init(arrayLiteral: midi[0]);array.append(contentsOf: midi[i..<i+2])
                
                switch(midi[0] & 0xf0){
                case NOTE_ON: self.delegate?.noteOnService?(array,self); break
                case NOTE_OFF:
//                    print("threeByteMidi \(array)")
                    self.delegate?.noteOffService?(array,self);
                    break
                case CONTROL_CHANGE: self.delegate?.controlChangeService?(array,self); break
               default: break
                }
                
            }
        }
        
        return midi.count
   }
    
    func fnCmd(_ midi : [UInt8])-> Int{
        
        // commands of the form fn (sysex for instance)
        // returns the number of bytes used
        
        switch(midi[0]){
            
        case SYSTEM_EXCLUSIVE:
            
            if let index = midi.firstIndex(of: MIDI_EOX),
               let delegate = self.delegate{
                
                DispatchQueue.main.async {
                    delegate.sysexService?(Array(midi[0...index]),self)
                }
                
                return index + 1    // number of bytes to consume

            }
            return midi.count   // no EOX, toss the record
            
        case MTC_QUARTER_FRAME:
            if midi.count < 2{return midi.count}   // not enough bytes
            DispatchQueue.main.async {
                self.delegate?.mtcService?(midi[1],self)
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
            self.delegate?.inputsChanged?(inputNames,self)
        }
    }
    @objc func outputsChanged(_ outputNames : [String]){
        
        // do this on the main thread
        DispatchQueue.main.async {
            self.delegate?.outputsChanged?(outputNames,self)
        }
        
    }
    @objc func didSelectInput(_ input : String){
        
        // do this on the main thread
        DispatchQueue.main.async {
            self.delegate?.didSelectInput?(input,self)
        }
        
    }
    @objc func didSelectOutput(_ output : String){
        
        // do this on the main thread
        DispatchQueue.main.async {
            self.delegate?.didSelectOutput?(output,self)
        }
    }
}
