//
//  MtkWindowController.swift
//  AleDoc21
//
//  Created by Pro Tools on 1/23/23.
//

import Cocoa

class MtkWindowController: NSWindowController {

    @IBOutlet var mtkViewController: MtkViewController!
    override func windowDidLoad() {
        super.windowDidLoad()

//        self.window?.level = NSWindow.Level(Int(CGWindowLevelKey.floatingWindow.rawValue))
        self.window?.level = overlayWindowLevel
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        self.window!.ignoresMouseEvents = true
        
        self.window!.styleMask = [.fullSizeContentView]
        self.window!.titlebarAppearsTransparent = true
        self.window!.titleVisibility            = .hidden
        self.window?.backgroundColor = NSColor.clear
    }
    
}
