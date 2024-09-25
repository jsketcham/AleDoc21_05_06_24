//
//  RemoteMidi.swift
//  AleDoc21
//
//  Created by Pro Tools on 9/8/23.
//

import Cocoa

class RemoteMidi: NSObject {
    
    var swiftMidi : SwiftMidi?

    override init() {
        super.init()
        
        swiftMidi = SwiftMidi(self, "Remote", .IN_AND_OUT);
        
    }
    @objc func midiTx(_ data : NSData){
        
        swiftMidi?.midiClient?.midiTx(data)
        
    }

}
// MARK: ---------- SwiftMidiDelegate ----------------
extension RemoteMidi :SwiftMidiDelegate{
    
}

