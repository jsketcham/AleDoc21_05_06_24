//
//  VideoDelayWindowController.swift
//  AleDoc21
//
//  Created by Pro Tools on 7/26/23.
//
// https://tylerayoung.com/2020/12/13/creating-a-swiftui-window-in-an-objective-c-appkit-app/

import Cocoa
import SwiftUI

// a class we can access from objective c
class VideoDelayWindowController : NSWindowController{
    @MainActor var screenRecorder : ScreenRecorder?{
        didSet{
            screenRecorder?.isAppExcluded = UserDefaults.standard.bool(forKey: "delayExcludeApp")
            
            self.sizeToCurrentScreen()
        }
    }

    @objc func sizeToCurrentScreen(){
        
        let screenSelector = UserDefaults.standard.integer(forKey: "videoScreenSelector") % NSScreen.screens.count

        let screen = NSScreen.screens[screenSelector]
        self.window?.setFrameOrigin(screen.frame.origin)
        let delayFullScreen = UserDefaults.standard.bool(forKey: "delayFullScreen")
        screenRecorder?.isFullScreen = true // hide ConfigurationView
        
        self.window?.backgroundColor = NSColor.black    // or we get a white line on the left side

        if(delayFullScreen){
            self.window!.styleMask = [.fullSizeContentView]
            self.window!.titlebarAppearsTransparent = true
            self.window!.titleVisibility            = .hidden
            self.window?.setFrame(screen.frame, display: true)
        }else{

            self.window!.styleMask                  = [.titled,.closable]
            self.window!.titlebarAppearsTransparent = false
            self.window!.titleVisibility            = .visible

            var frame = screen.frame
            frame.size.width /= 2.0
            frame.size.height /= 2.0
            frame.size.height += self.window!.titlebarHeight
            self.window?.setFrame(frame, display: true)

        }

    }
    @objc func setScreenRecorder(_ screenRecorder : Any?){
        
        self.screenRecorder = screenRecorder as? ScreenRecorder;
        
    }

}
// we don't know how to access this from objective c, see VideoDelayWindowController class
class SwiftUIWindowCtrl<RootView: View>: VideoDelayWindowController {
    
    convenience init(rootView: RootView) {
        
//        UserDefaults.standard.set(false, forKey: "delayFullScreen") // temp start not full screen
//        let hostingCtrl = NSHostingController(rootView: rootView.frame(width: 1600, height: 600))
        let hostingCtrl = NSHostingController(rootView:ContentView())
        let window = NSWindow(contentViewController: hostingCtrl)
        window.setContentSize(NSSize(width: 1600, height: 600))
        
        self.init(window: window)
        window.title = "WB Video Delay"

        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)), name: NSWindow.willCloseNotification, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeMain(_:)), name: NSWindow.didBecomeMainNotification, object: nil)
//videoSourceSelector
        UserDefaults.standard.addObserver(self, forKeyPath: "videoSourceSelector", context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "delayExcludeApp", context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "videoScreenSelector", context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "delayFullScreen", context: nil)
//        UserDefaults.standard.addObserver(self, forKeyPath: "screenRecorderChanged", context: nil)

    }
//    @objc func didBecomeMain(_ notification : NSNotification){
//
//        if (notification.object as! NSWindow) == self.window{
//            UserDefaults.standard.set(true, forKey: "useAltGuideInRecord")
//
//            // send status cc 5, delay window open
//            let bytes : [UInt8] = [0xb0,5,127]
//            let data = Data(bytes: bytes, count: bytes.count)
//            let aleDelegate : AleDelegate = NSApp.delegate as! AleDelegate
//            aleDelegate.statusClient.midiTx(data)
//
//            aleDelegate.txOsc("led 9,77,true")
//        }
//
//
//    }
   @objc func windowWillClose(_ notification : NSNotification){
        
        if (notification.object as! NSWindow) == self.window{
            
//            UserDefaults.standard.set(false, forKey: "useAltGuideInRecord")
            
            // send status cc 5, delay window closed
            let bytes : [UInt8] = [0xb0,5,0]
            let data = Data(bytes: bytes, count: bytes.count)
            let aleDelegate : AleDelegate = NSApp.delegate as! AleDelegate
            aleDelegate.statusClient.midiTx(data as NSData)
        }
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        // [SwiftUI] Publishing changes from background threads is not allowed; make sure to publish values from the main thread (via operators like receive(on:)) on model updates.
//        let aleDelegate = NSApp.delegate as! AleDelegate

        switch(keyPath){
        case "videoSourceSelector":
            screenRecorder?.selectedDisplayIndex = UserDefaults.standard.integer(forKey: "videoSourceSelector")
            break;
        case "delayExcludeApp":
            screenRecorder?.isAppExcluded = UserDefaults.standard.bool(forKey: "delayExcludeApp")
            break;
        case "videoScreenSelector":
            sizeToCurrentScreen()
            break
        case "delayFullScreen":
            sizeToCurrentScreen()
            break
        default: break
        }
    }

}
@objc class PrefsWindowObjCBridge: NSView {
    @objc class func makePrefsWindow() -> NSWindowController {
        SwiftUIWindowCtrl(rootView: ContentView())
    }
}
