//
//  AppDelegate.swift
//  WindowCapture
//
//  Created by Pro Tools on 3/29/24.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!
    var ptWindow : WindowCaptureController<ContentView>?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        ptWindow = WindowCaptureController(rootView: ContentView())
        ptWindow?.window?.makeKeyAndOrderFront(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


    @IBAction func onButton(_ sender: Any) {
        print("onButton")
    }
}

