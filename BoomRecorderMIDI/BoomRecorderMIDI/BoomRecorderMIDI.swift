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

@objc protocol BoomRecorderMIDIDelegate{
    
}

class BoomRecorderMIDI: NSObject {
    
    var swiftMidi : SwiftMidi?
    @objc var inArray : [String]?
    var timer : Timer?
    var boomRecRun = false
    
    let pingResponse :[UInt8] = [0x90,0x00,0x7f]
    
    override init() {
        super.init()
        
        swiftMidi = SwiftMidi(self, "Boom Recorder", .IN_AND_OUT)
//        self.startAdrClient() not used in Evan's method
    }
    
    func startAdrClient(){
        
        boomRecRun = true
        inArray = [String]()
        
        timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(timerService), userInfo: nil, repeats: true)
        
    }
    
    @objc func timerService(){
        
        if !boomRecRun{
            timer?.invalidate()
            return
        }
        
        if inArray?.count == 0{
            return
        }
        
        if let array = self.inArray{
            
            self.inArray!.removeAll()
            
            DispatchQueue.global(qos: .default).async {
                
                let localArray = array  // array may be change in 10 ms, make a copy
                
                for str in localArray{
                    
                    var args = str.contains("\t") ? str.components(separatedBy: "\t") : str.components(separatedBy: " ")
                    
                    if args.count == 0{ continue}
                    
                    var scriptResult = ScriptResult(scriptCmd: args[0],result: "",interval:0.0)
                    
                    let s = String(format: "/Users/%@/Library/Scripts/%@.scpt" ,NSUserName(),args[0])
                    
                    args[0] = s
                    
                    print("\(args)")
                    
                    let then = Date()
                    
                    let task = Process()
                    
                    task.launchPath = "/usr/bin/osascript"
                    task.arguments  = args
                    task.standardOutput = Pipe()
                    task.launch()
                    task.waitUntilExit()
                    
                    let now = Date()
                    
                    scriptResult.interval = now.timeIntervalSince(then)
                    
                    let output = (task.standardOutput as! Pipe).fileHandleForReading.availableData
                    
                    scriptResult.result = String(decoding: output, as: UTF8.self)
                    
                    DispatchQueue.main.async { [scriptResult] in
                        
                        self.processScriptResult(scriptResult)
                        
                    }
                }
            }
       }
    }
    
    func processScriptResult(_ scriptResult : ScriptResult){
        
        return  // not used in Evan's approach
        
        // send a string to the AleDoc end
        let s = scriptResult.result?.trimmingCharacters(in: CharacterSet(charactersIn: "\t\r\n"))
        let msg = String(format: "%@\t%@\t %.3f\n", scriptResult.scriptCmd!,s!,scriptResult.interval!)
        swiftMidi?.midiClient?.midiTxString(msg)
//        let s = String(format: "%2.5f", scriptResult.interval!)
//        print("processScriptResult \(scriptResult.result ?? "no result") \(s)")
        
    }
    
// MARK: ---------- Evan's methods ----------------
    
    @objc func startBoomRecorder(_ frameRate : NSString,_ takeNumber : NSString,_ trackWidth : NSString,_ cueName : NSString,_ dialog: NSString){
        
    }
    @objc func setBoomRecFolder(_ session : NSString){
        
    }
    @objc func stopBoomRecorder(){
        
    }
    @objc func abortBoomRecorder(){
        
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
        print("noteOnService \(midi)")
        if midi[1] == 0 && midi[2] == 0{
            
            DispatchQueue.main.async { [self] in
                
                self.swiftMidi?.midiClient?.midiTx(NSData(bytes: self.pingResponse, length: self.pingResponse.count))
                
            }

        }
        
    }
    func noteOffService(_ midi : [UInt8], _ sender : SwiftMidi){
        
        // 2.00.00 11/1/22 PT Ultimate we see 80 00 40 for ping, this
        // keeps the PT HUI error dialog from appearing
        print("noteOffService \(midi)")
        if midi[1] == 0 && midi[2] == 0x40{
            
            DispatchQueue.main.async { [self] in
                
                self.swiftMidi?.midiClient?.midiTx(NSData(bytes: self.pingResponse, length: self.pingResponse.count))
                
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




