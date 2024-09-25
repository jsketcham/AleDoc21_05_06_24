//
//  Dials.swift
//  AleDoc21
//
//  Created by Pro Tools on 9/6/23.
//  Jason wants the dials to be faders and mutes on his console in ADR3, which is larger
//  dials and sliders are sent as 176,cc,value, where cc's are in the midiDialDictionary below
//  mute button down is sent as 90,cc,xx, where 0<xx<=127
//  mute button up is sent as 80,cc,xx, where xx does not matter
//  a long press of mute button down resets to 0dB, which works for dials, but sliders will
//  jump back to where they are
import Cocoa

@objc protocol DialsDelegate{
    
    @objc func doSomething(_ someValue : Int)
    
}

import Cocoa

class Dials: NSObject {
    
    // MIDI cc to offset in AleDelegate.unit_9_dictionary
    let midiDialDictionary : [Int : Int] = [
        1:92        // "Zoom"
        ,2:93       // "Source\\nConnect"
        ,3:94       // "Actor\\nDirect"
        ,4:95       // "Actor\\nHP"
        ,5:96       // "Beeps"
        ,6:97       // "Mac\\nCPU"
        ,7:98       // "Guide\\nTo Booth"
        ,8:99       // "Snoop"
        ,9:100      // "Loopback"
        ,10:101     // "Remote\\nActor Dir"
        ,11:102     // "Remote\\nActor HP"
        ,12:103     // "Video\\nDelay"
        ,13:104     // "Control\\nRoom"
        ,14:105     // "Stage"
        ,15:106     // "Editor\\nHP"
    ]

    var swiftMidi : SwiftMidi?
    var keyOneShot : Timer?
    
    override init() {
        super.init()
        
        swiftMidi = SwiftMidi(self, "Dials", .IN_AND_OUT)

        }


}
// MARK: ---------- SwiftMidiDelegate ----------------
extension Dials :SwiftMidiDelegate{
    
    @objc func noteOnService(_ midi : [UInt8], _ sender : SwiftMidi){
        
    }
    @objc func noteOffService(_ midi : [UInt8], _ sender : SwiftMidi){
        
    }
    @objc func controlChangeService(_ midi : [UInt8], _ sender : SwiftMidi){
        
    }

}
        
