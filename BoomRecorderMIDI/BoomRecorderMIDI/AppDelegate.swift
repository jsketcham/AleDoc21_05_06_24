//
//  AppDelegate.swift
//  BoomRecorderMIDI
//
//  Created by Pro Tools on 9/4/23.
//
/*
    we started on a boom recorder MIDI remote, but Evan wants to keep MidiPipe.
 */
import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!
    var boomRecorderMIDI : BoomRecorderMIDI?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        boomRecorderMIDI = BoomRecorderMIDI()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    @IBAction func onDoSomething(_ sender: Any) {
        
        boomRecorderMIDI?.inArray?.append("jxaGetSampleRate")
    }
}
