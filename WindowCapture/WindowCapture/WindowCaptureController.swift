//
//  WindowCaptureController.swift
//  WindowCapture
//
//  Created by Pro Tools on 3/29/24.
//  Evan wants to capture a PT window to send elsewhere
//  1X graphics (no scaling), sizeable, scrollable
//  this window controller is lifted from UpDoc, a re-written version of AleDoc21.

import Cocoa
import SwiftUI
import Combine

class WindowCaptureController <RootView: View>: NSWindowController {
    
    @MainActor var screenRecorder : ScreenRecorder?{
        didSet{
            screenRecorder?.captureType = .display
            
            obsDictionary = [
                "delayFullScreen" : #selector(sizeToCurrentScreen(_:))
                ,"videoScreenSelector" : #selector(sizeToCurrentScreen(_:))
                ,"videoSourceSelector" : #selector(obsNextSource(_:))
                ,"delayExcludeApp" : #selector(obsDisplayExcludeApp(_:))
            ]
            
        }
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    convenience init(rootView: RootView) {
        
        let dict : [String : Any] = [
            
            "videoSourceSelector" : 0
            ,"videoScreenSelector" : 0
            ,"delayExcludeApp" : true
        ]
        
        UserDefaults.standard.register(defaults: dict)
        
        let hostingCtrl = NSHostingController(rootView: ContentView())
        let window = NSWindow(contentViewController: hostingCtrl)
        window.setContentSize(NSSize(width: 720, height: 240))
        self.init(window: window)
        
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

    }
    
    var obsDictionary : [String : Selector]?{
        didSet{
            
            // initialize the observations
            if obsDictionary != nil{
                var array = [Selector]()
                
                for key in obsDictionary!.keys{
                    
                    UserDefaults.standard.addObserver(self, forKeyPath: key ,options: NSKeyValueObservingOptions.new, context: nil)
                    
                    if let sel = obsDictionary![key],
                       !array.contains(sel){
                        
                        array.append(sel)   // perform once only
                        perform(sel, with: "")
                    }
                }
            }
        }
    }
    @objc func sizeToCurrentScreen(_ keyPath : String){
        
        let screenSelector = UserDefaults.standard.integer(forKey: "videoScreenSelector") % NSScreen.screens.count
//        Swift.print("sizeToCurrentScreen \(screenSelector)")

        let screen = NSScreen.screens[screenSelector]
        self.window?.setFrameOrigin(screen.frame.origin)
        self.window!.styleMask                  = [.titled,.closable]
        self.window!.titlebarAppearsTransparent = false
        self.window!.titleVisibility            = .visible
        
        self.window!.title = "PT Window"

        // TODO: make it sizeable, scrollable
        var frame = screen.frame
        frame.size.width /= 2.0
        frame.size.height /= 2.0
        frame.size.height += self.window!.titlebarHeight
        self.window?.setFrame(frame, display: true)

    }

    @objc func obsNextSource(_ keyPath : String){
        
        screenRecorder?.displayIndex = UserDefaults.standard.integer(forKey: "videoSourceSelector")

    }
    @objc func obsDisplayExcludeApp(_ keyPath : String){
        
        screenRecorder?.isAppExcluded = UserDefaults.standard.bool(forKey: "delayExcludeApp")
    }

    @objc func keyService(_ keyPath : String){
        
        if let sel = obsDictionary?[keyPath]{
            
            perform(sel, with: keyPath)
            
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        self.performSelector(onMainThread: #selector(keyService), with: keyPath, waitUntilDone: false)

        
//        DispatchQueue.main.async { [] in
//
//            self.keyService(keyPath!)
//
//        }
        
    }


}
extension NSWindow {
    // https://stackoverflow.com/questions/28955483/how-do-i-get-default-title-bar-height-of-a-nswindow
    var titlebarHeight: CGFloat {
        frame.height - contentRect(forFrameRect: frame).height
    }
}

