//
//  ControlMidi.swift
//  AleDoc21
//
//  Created by Pro Tools on 9/11/23.
//

import Cocoa

class ControlMidi: NSObject {
    
    var swiftMidi : SwiftMidi?
    
    @objc init(_ name : String) {
        super.init()
        
        swiftMidi = SwiftMidi(self, name, .IN_AND_OUT);
        
        swiftMidi?.oscDelegate = NSApp.delegate as? any SwiftMidiOscDelegate;

    }
    
    @objc func midiTx(_ data : NSData){
        
        swiftMidi?.midiClient?.midiTx(data)
        
    }

}
// MARK: ---------- SwiftMidiDelegate ----------------
extension ControlMidi :SwiftMidiDelegate{
}
