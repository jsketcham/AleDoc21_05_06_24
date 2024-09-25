//
//  AudioPlayerWindowController.swift
//  AleDoc21
//
//  Created by Pro Tools on 7/25/23.
//

import Cocoa

class AudioPlayerWindowController: NSWindowController {

    @IBOutlet var audioPlayerViewController: AudioPlayerViewController!
    override func windowDidLoad() {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
    // MARK: ------ stubs for samplerWindowController
    
    @objc func loopFromOsc(_ keyNumber : Int){
        
        var btn : SwiftDropButton?
        
        switch(keyNumber){
        case 60: btn = audioPlayerViewController.standardFillButton; break
        case 61: btn = audioPlayerViewController.customFillButton; break
        default: break;
        }
        
        btn?.state = btn?.state == .on ? .off : .on
        
        audioPlayerViewController.onFillButton(btn!)
        
    }
    @objc func initLoopButtons(){
        
        let aleDelegate = NSApp.delegate as? AleDelegate
        aleDelegate?.setLEDForUnitID(9, 60, false)
        aleDelegate?.setLEDForUnitID(9, 61, false)

    }
    @objc func playback(_ playbackOn : Bool){
        
        let aleDelegate = NSApp.delegate as? AleDelegate
        
        let btn : SwiftDropButton = (aleDelegate?.lpMini.isMidiCustomFillState())! ? audioPlayerViewController.customFillButton : audioPlayerViewController.standardFillButton
        
        btn.state = playbackOn ? .on : .off
        audioPlayerViewController.onFillButton(btn)

    }
    @objc func sayTake(_ text : NSString){
        
        audioPlayerViewController.sayTake(text)
    }

}
