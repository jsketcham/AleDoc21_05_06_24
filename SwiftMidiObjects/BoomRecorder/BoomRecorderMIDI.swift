//
//  BoomRecorderMIDI.swift
//  BoomRecorderMIDI
//
//  Created by Pro Tools on 9/4/23.
// intended to be a tx/rx for remote MIDI that ran scripts on
// the rx end, this has become a replacement for Evan's
// MIDI tx scripts. The script runner and sysex tx/rx are still here,
// but are not used.

import Cocoa

struct ScriptResult{
    var scriptCmd : String?
    var result : String?
    var interval : Double?
}
//
enum BOOM_REC_STATUS : Int{
    case IDLE,ONLINE,RECORD
}

@objc protocol BoomRecorderMIDIDelegate{
    
    func boomRecorderStatus(_ status : Int, _ channel : Int)
    
}

class BoomRecorderMIDI: NSObject {
    
    var swiftMidi : SwiftMidi?
    var swiftMidi2 : SwiftMidi?
    @objc var inArray : [String]?
    var timer : Timer?
//    var boomRecRun = false
    @objc var delegate : BoomRecorderMIDIDelegate?
    
    let myCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-._ "

    
    let pingResponse :[UInt8] = [0x90,0x00,0x7f]
    
    override init() {
        super.init()
        
        swiftMidi = SwiftMidi(self, "Boom recorder local", .IN_AND_OUT)
        swiftMidi2 = SwiftMidi(self, "Remote", .IN_AND_OUT)
        self.startAdrClient()
    }
    
    func startAdrClient(){
                
//        boomRecRun = true
//        inArray = [String]()
//
        // ping the local (first) boom recorder every second (keep the RECORD indicator lag down)
        
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(timerService), userInfo: nil, repeats: true)  //
        
        // throttle MIDI tx
        throttleTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(throttleTimerService), userInfo: nil, repeats: true)
  }
    
    @objc func timerService(){
        
        // ping the local (first) boom recorder
        // On the local midi boom recorder only, send midi cc 9 on channel 1, any value, every second to trigger the status ping.
        let bytes : [UInt8] = [176,9,0]    // ping
        swiftMidi?.midiClient?.midiTx(Data(bytes: bytes, count: bytes.count) as NSData)
    }
    @objc func midiTx(_ data : NSData){
        
        swiftMidi2?.midiClient?.midiTx(data)    // to remote only
        
    }

// MARK: ---------- Evan's methods ----------------
    
    var throttleTimer : Timer?  // 1 ms throttle
    
    var byteArray = [[UInt8]]()
    
    @objc func throttleTimerService(){
        
        if byteArray.count == 0{
            return
        }
        
        let boomRecOnlineLocal = UserDefaults.standard.bool(forKey: "boomRecOnlineLocal")
        let boomRecOnlineRemote = UserDefaults.standard.bool(forKey: "boomRecOnlineRemote")

        let bytes = byteArray.removeFirst()
        
        if boomRecOnlineLocal{
            swiftMidi?.midiClient?.midiTx(Data(bytes: bytes, count: bytes.count) as NSData)
        }
        
        if boomRecOnlineRemote{
            swiftMidi2?.midiClient?.midiTx(Data(bytes: bytes, count: bytes.count) as NSData)
        }

    }
    
    @objc func startBoomRecorder(_ frameRate : NSString,_ takeNumber : NSString,_ trackWidth : NSString,_ cueName : NSString,_ dialog: NSString){
        
        let txBytes : [UInt8] = [177,77,0]    // clear remote clipboard
        byteArray.append(txBytes)
        
        let k = myCharacters.startIndex
        var str = cueName as String
        
        while str.count > 0{
            
            let c = Array(str)[0]
            str = String(str.dropFirst(1))
            
            if let j = myCharacters.firstIndex(of: c){
                
                let l = myCharacters.distance(from: k, to: j) + 1 // AppleScript first index is 1

                let txBytes : [UInt8] = [177,77,UInt8(l)]    //
                byteArray.append(txBytes)

            }
        }
        
        let width = UInt8(trackWidth.integerValue) + 100
        byteArray.append([177,77,width])  // send width
        
        byteArray.append([177,77,127])  // Set BoomRec Scene to clipboard
        byteArray.append([177,77,125])  // BoomRec Record

    }
    @objc func setBoomRecFolder(_ session : String){
        
        let txBytes : [UInt8] = [177,77,0]    // clear remote clipboard
        byteArray.append(txBytes)
        
        let k = myCharacters.startIndex
        var str = session as String
        
        while str.count > 0{
            
            let c = Array(str)[0]
            str = String(str.dropFirst(1))
            
            if let j = myCharacters.firstIndex(of: c){
                
                let l = myCharacters.distance(from: k, to: j) + 1 // AppleScript first index is 1

                let txBytes : [UInt8] = [177,77,UInt8(l)]    //
                byteArray.append(txBytes)

            }
        }
        byteArray.append([177,77,124])  // set boom rec folder
    }
    @objc func stopBoomRecorder(){
        
        byteArray.append([177,77,126])  // boom rec stop

    }
    @objc func abortBoomRecorder(){
        
        byteArray.append([177,77,123])  // boom rec abort
    }

}
// MARK: ---------- SwiftMidiDelegate ----------------
extension BoomRecorderMIDI :SwiftMidiDelegate{
    
    func inputsChanged(_ inputNames : [String], _ sender : SwiftMidi){
//        print("inputsChanged")
    }
    func outputsChanged(_ outputNames : [String], _ sender : SwiftMidi){
//        print("outputsChanged")
    }
    func didSelectInput(_ input : String, _ sender : SwiftMidi){
        
    }
    func didSelectOutput(_ output : String, _ sender : SwiftMidi){
        
    }
    
    func noteOnService(_ midi : [UInt8], _ sender : SwiftMidi){
        
        // process 3 bytes of note on
//        The status tally is midi note 6 value 127 if in record. Value zero if idle but connected. It will return every second.
        if midi[1] == 6 && delegate != nil{
            
            delegate?.boomRecorderStatus(midi[2] == 127 ? BOOM_REC_STATUS.RECORD.rawValue : BOOM_REC_STATUS.ONLINE.rawValue,sender == swiftMidi ? 0 : 1)
            
        }

        
    }
    func noteOffService(_ midi : [UInt8], _ sender : SwiftMidi){
        
//        print("BoomRecorderMIDI noteOffService \(midi)")
        // we see 80 06 40 for ping
        if midi[1] == 6 && midi[2] == 0x40{
            
            DispatchQueue.main.async { [self] in
                
                delegate?.boomRecorderStatus(BOOM_REC_STATUS.ONLINE.rawValue,sender == swiftMidi ? 0 : 1)

            }

        }
   }
    func controlChangeService(_ midi : [UInt8], _ sender : SwiftMidi){
        
        // process 2 bytes of control change
//        print("controlChangeService \(midi)")

    }
    func convert87(_ bytes: [UInt8]) -> [UInt8]{
        
        // can't send top bits in a sysex, we are using UTF8 encoding for text, which has top bits
        // so, top bits for [1-7] are encoded in [0], repeat
        
        var buffer = [UInt8]()
        var topBits : UInt8 = 0

        for i in 0..<bytes.count{
            
            if i % 8 == 0{topBits = bytes[i]; continue}
            buffer.append((topBits & 1 != 0 ? 0x80 : 0) | bytes[i] & 0x7f)
            topBits >>= 1
            
        }
        
//        var s = ""
//
//        for i in 0..<buffer.count{
//            s.append(String(format: "%02X ", buffer[i]))
//        }
//        print("\(s)")
        
        return buffer
    }
    
    func sysexService(_ midi: [UInt8], _ sender: SwiftMidi){
        
        var midi = midi
        
        // check headers, 6 bytes
        if midi.count > proToolsHeader.count - 1{
            
            let hdr = [UInt8](midi[0..<proToolsHeader.count])
            let twiHdr = [UInt8](twiHeader[0..<twiHeader.count])  // without SYSEX
            
            if hdr == twiHdr{    // a Jim Ketcham UTF8 text command, Time Warner command group
                
                midi.removeLast() // MIDI_EOX
                midi.removeFirst(hdr.count)    // header
                                
                // utf8 uses top bits, can't have that in MIDI, encode top bits
                let buffer87 = convert87(midi)    // 8 bytes -> 7 bytes, top bits of [1-7] are in [0]
                                
                if let s = String(bytes: buffer87, encoding: .utf8){
                    
                    NSLog("string from MIDI SYSEX: \(s)")
//                    self.inArray?.append(s)
//                    delegate?.cmdDecoder?(s,self)
                }

            }
        
        }
    }
    func mtcService(_ mtc : UInt8, _ sender : SwiftMidi){
        
        // process 1 byte of mtc
//        print("mtcService")

    }

}




