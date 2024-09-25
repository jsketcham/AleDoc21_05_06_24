//
//  OverlayWindowController.swift
//  AleDoc
//
//  Created by Jim on 9/19/22.
//  Copyright © 2022 James Ketcham. All rights reserved.
//
/*
 10/17/22 we would like to measure streamer 'judder'
 use callback to CVDisplayLink
 */


import Cocoa
import AVFoundation
//import AVKit

// from TextWindowServer_V2
let overlayWindowLevel : NSWindow.Level =  NSWindow.Level(Int(CGWindowLevelKey.floatingWindow.rawValue))

let overlayKey = "OVERLAY_KEY"

@objc class OverlayWindowController: NSWindowController {
    
    @IBOutlet var viewController: ViewController!
//    @objc var streamerWindowController : MtkWindowController?
    
    // https://stackoverflow.com/questions/14158743/alternative-of-cadisplaylink-for-mac-os-x
    
    @objc var screenSelector : Int{
        set{

            // 2.10.02 don't store it, causes missing monitors to change
            // the default, only happens in AleDelegate
//            UserDefaults.standard.set(newValue % NSScreen.screens.count, forKey: "\(overlayKey)screenSelector")
            sizeToCurrentScreen()
        }
        get{
            return UserDefaults.standard.integer(forKey: "\(overlayKey)screenSelector") % NSScreen.screens.count
        }
    }
    
    let defaultWindowSize = NSSize(width: 480, height: 270)

    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.window?.level = overlayWindowLevel
        NSColorPanel.shared.level = overlayWindowLevel  // has to be at same level or greater
        NSFontPanel.shared.level = overlayWindowLevel   // has to be at same level or greater
        NSColorPanel.shared.showsAlpha = true

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        let dict : [String : Any] = [
            
            "\(overlayKey)screenSelector" : 0  // default screen
        ]
        
        let defaults = UserDefaults.standard
        defaults.register(defaults: dict)
        
//        recallDefaults()

        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeMain(_:)), name: NSWindow.didBecomeMainNotification, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignMain(_:)), name: NSWindow.didResignMainNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidMove(_:)), name: NSWindow.didMoveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)), name: NSWindow.willCloseNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didResignActive(_:)), name: NSApplication.didResignActiveNotification, object: nil)
        // NSApplicationWillResignActiveNotification
       
        // we don't get this notification when PT video comes to the front
//        NotificationCenter.default.addObserver(self, selector: #selector(windowDidChangeOcclusionState(_:)), name: NSWindow.didChangeOcclusionStateNotification, object: nil)
                
    }
    // MARK: --------- utilities --------------
    @objc func triggerStreamer(_ color: NSColor){
        
        viewController.streamer?.triggerStreamer(color)
//        streamerWindowController?.mtkViewController.streamerRenderer?.addStreamer(color);

    }
    @objc func testFlag()-> (Bool){
        
        let flag = viewController.streamerRenderer!.streamerDidFinish
        viewController.streamerRenderer!.streamerDidFinish = false
        return flag
    }
    // MARK: --------- notifications --------------
    
    @objc func didResignActive(_ notification : NSNotification){
        
//        print("didResignActive")
        viewController?.bringToFront()
        
    }

    @objc func windowDidMove(_ notification : NSNotification){
        if (notification.object as! NSWindow) == self.window{
            for screen in NSScreen.screens{
                
                if screen.frame.contains((self.window?.frame.origin)!){
                    
//                    print("windowDidMove \(screen.frame) \(self.window?.frame)")
                    // keep track of the current overlay screen
                    // we get a bogus 'windowDidMove' on power up, can't do this, use 'textNextScreen' button 
//                    screenSelector = NSScreen.screens.firstIndex(of: screen)!
                    break
                }
            }
        }
    }
//    @objc func windowDidResignMain(_ notification : NSNotification){
//        if (notification.object as! NSWindow) == self.window{
//            deactivateWindow()
////            viewController.opaque = false // causes a crash
////            // save settings happens on windowWillClose, also
//            viewController.textView?.saveSettings()
//            viewController.cueIdTextView?.saveSettings()
//            viewController.annunciatorTextView?.saveSettings()
//
//        }
//    }
    @objc func windowDidBecomeMain(_ notification : NSNotification){
        if (notification.object as! NSWindow) == self.window{
//            print("windowDidBecomeMain")
            activateWindow()
        }
    }
    @objc func windowWillClose(_ notification : NSNotification){
        
        if (notification.object as! NSWindow) == self.window{
//            print("windowWillClose")
            // save settings
            viewController.textView?.saveSettings()
            viewController.cueIdTextView?.saveSettings()
            viewController.annunciatorTextView?.saveSettings()
        }

    }
//    @objc func windowDidChangeOcclusionState(_ notification : NSNotification){
//
//        print("did change occlusion state")
//        // myWindowLevel
//        self.window?.level = .floating
//        self.window?.orderFrontRegardless()
//    }
    // MARK: --------- utilities --------------
    
    @objc func activateWindow(){
        
        self.window!.ignoresMouseEvents = false
        
        // style mask show title bar
        self.window!.styleMask                  = [.titled]
        self.window!.titlebarAppearsTransparent = false
        self.window!.titleVisibility            = .visible
        
        sizeToCurrentScreen()

    }
    @objc func deactivateWindow(){
        
        // title bar is hidden when full screen
//        if fullScreen{
            self.window!.ignoresMouseEvents = true
            
            self.window!.styleMask                  = [.fullSizeContentView]
            self.window!.titlebarAppearsTransparent = true
            self.window!.titleVisibility            = .hidden
            
            sizeToCurrentScreen()
//        }

    }
    
    @objc func getVsyncPeriod(){
        // a test function, we are debugging streamer delay
        let screen = NSScreen.screens[screenSelector]
        
        viewController.streamer?.vsyncPeriod = (viewController.streamer?.getNominalOutputVideoRefreshPeriod(screen.displayID!))!
    }
    
    @objc func sizeToCurrentScreen(){
        
        let screen = NSScreen.screens[screenSelector]
        self.window?.backgroundColor = NSColor.clear
        self.window?.setFrame(screen.frame, display: true)
        
        viewController.textView.putTextOnScreen()
        viewController.cueIdTextView.putTextOnScreen()
        viewController.annunciatorTextView.putTextOnScreen()

        viewController.streamer?.setPunchLayer() // for current frame size
        viewController.textView.setTextBounds()
        viewController.cueIdTextView.setTextBounds()
        viewController.annunciatorTextView.setTextBounds()
        viewController.streamer?.maskFromValues()
        
        // we need the vsync period for the streamer delay feature
        // convert delay in ms to count of periods
        getVsyncPeriod()
        viewController.streamer?.startRenderCallback(screen.displayID!)

//        streamerWindowController?.window?.setFrame(self.window!.frame, display: true);

    }
}
// MARK: ---------- extensions ---------------

// https://gist.github.com/briankc/025415e25900750f402235dbf1b74e42
// we need this for vsync callback for the screen we are on
extension NSScreen {
  var displayID: CGDirectDisplayID? {
    return deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID
  }
}
// MARK: ----- NSDate timeOfDay ------

extension NSDate{
    func timeOfDay() -> String{
        
        var dateFormatter : DateFormatter?
        
        dateFormatter = DateFormatter()
        dateFormatter!.timeStyle = DateFormatter.Style.medium
        dateFormatter!.dateStyle = DateFormatter.Style.none

        let ds = dateFormatter!.string(for: NSDate())!
        let array = ds.components(separatedBy: " ")
        var ti = NSDate().timeIntervalSinceReferenceDate
        ti *= 1000
        let ms = Int(ti) % 1000
        
        return String(format: "%@.%03ld",array[0],ms)
    }
}

