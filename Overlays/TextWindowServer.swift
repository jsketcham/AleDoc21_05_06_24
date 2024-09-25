//
//  TextWindowServer.swift
//  Streamer
//
//  Created by Jim on 7/28/22.
//

import Cocoa
import Network

@objc class TextWindowServer: NSObject {
    
    let DEFAULT_NAME = "TextWindowServer"
    let SERVICE_NAME = "TextWindowServer_V3"
    let SERVICE_TYPE = "_endpoint_text._tcp."    // is "_endpoint_text._tcp." in TextWindowServer, is
    let key = "VM15B"

    var streamer : Streamer?
    var textView: TextView?
    var cueIdTextView: TextView?
    var annunciatorTextView: TextView?
    
    @objc var rehRecPb : Int = 0{

        didSet{
            
            var fgColor = NSColor.clear
            var bgColor = NSColor.clear
            var text = ""
            
            switch(rehRecPb){
            case MODE_CONTROL_REHEARSE:
                fgColor = UserDefaults.standard.color(forKey: "rehearseColor")
                bgColor = UserDefaults.standard.color(forKey: "rehearseBgColor")
                text = "Rehearse"
                break
            case MODE_CONTROL_RECORD:
                fgColor = UserDefaults.standard.color(forKey: "recordColor")
                bgColor = UserDefaults.standard.color(forKey: "recordBgColor")
                text = "Record"
                break
            case MODE_CONTROL_PLAYBACK:
                fgColor = UserDefaults.standard.color(forKey: "playbackColor")
                bgColor = UserDefaults.standard.color(forKey: "playbackBgColor")
                text = "Playback"
                break
            case MODE_CONTROL_REHEARSE_PENDING:
                fgColor = UserDefaults.standard.color(forKey: "rehearseColor")
                bgColor = UserDefaults.standard.color(forKey: "rehearseBgColor")
                text = "Rehearse\npending"
                break
            case MODE_CONTROL_RECORD_PENDING:
                fgColor = UserDefaults.standard.color(forKey: "recordColor")
                bgColor = UserDefaults.standard.color(forKey: "recordBgColor")
                text = "Record\npending"
                break
            case MODE_CONTROL_PLAYBACK_PENDING:
                fgColor = UserDefaults.standard.color(forKey: "playbackColor")
                bgColor = UserDefaults.standard.color(forKey: "playbackBgColor")
                text = "Playback\npending"
                break
            default: break
            }
            
            annunciatorTextView?.text = text
            annunciatorTextView?.textColor = fgColor
            annunciatorTextView?.backgroundColor = bgColor
            
        }
    }
    
@objc var rehearseColor : NSColor{
    set{
        let color = newValue.usingColorSpace(.genericRGB)
        
        if annunciatorTextView?.text == REH_MSG{
            
            annunciatorTextView?.textColor = color!
            
        }
        
        UserDefaults.standard.set("\(color!.redComponent)", forKey: "\(key)rehearseColor_r")
        UserDefaults.standard.set("\(color!.greenComponent)", forKey: "\(key)rehearseColor_g")
        UserDefaults.standard.set("\(color!.blueComponent)", forKey: "\(key)rehearseColor_b")
        UserDefaults.standard.set("\(color!.alphaComponent)", forKey: "\(key)rehearseColor_a")

    }get{
        
        let r = Double(UserDefaults.standard.string(forKey: "\(key)rehearseColor_r") ?? "0.0")
        let g = Double(UserDefaults.standard.string(forKey: "\(key)rehearseColor_g") ?? "1.0")
        let b = Double(UserDefaults.standard.string(forKey: "\(key)rehearseColor_b") ?? "0.0")
        let a = Double(UserDefaults.standard.string(forKey: "\(key)rehearseColor_a") ?? "1.0")
            
        return NSColor.init(red: r!, green: g!, blue: b!, alpha: a!)
        
    }
}
@objc var recordColor : NSColor{
    set{
        let color = newValue.usingColorSpace(.genericRGB)
        
        if annunciatorTextView?.text == REC_MSG{
            
            annunciatorTextView?.textColor = color!
            
        }

        UserDefaults.standard.set("\(color!.redComponent)", forKey: "\(key)recordColor_r")
        UserDefaults.standard.set("\(color!.greenComponent)", forKey: "\(key)recordColor_g")
        UserDefaults.standard.set("\(color!.blueComponent)", forKey: "\(key)recordColor_b")
        UserDefaults.standard.set("\(color!.alphaComponent)", forKey: "\(key)recordColor_a")

    }get{
        
        let r = Double(UserDefaults.standard.string(forKey: "\(key)recordColor_r") ?? "1.0")
        let g = Double(UserDefaults.standard.string(forKey: "\(key)recordColor_g") ?? "0.0")
        let b = Double(UserDefaults.standard.string(forKey: "\(key)recordColor_b") ?? "0.0")
        let a = Double(UserDefaults.standard.string(forKey: "\(key)recordColor_a") ?? "1.0")
            
        return NSColor.init(red: r!, green: g!, blue: b!, alpha: a!)
        
    }
}
@objc var playbackColor : NSColor{
    set{
        let color = newValue.usingColorSpace(.genericRGB)
        
        if annunciatorTextView?.text == PB_MSG{
            
            annunciatorTextView?.textColor = color!
            
        }

        UserDefaults.standard.set("\(color!.redComponent)", forKey: "\(key)playbackColor_r")
        UserDefaults.standard.set("\(color!.greenComponent)", forKey: "\(key)playbackColor_g")
        UserDefaults.standard.set("\(color!.blueComponent)", forKey: "\(key)playbackColor_b")
        UserDefaults.standard.set("\(color!.alphaComponent)", forKey: "\(key)playbackColor_a")

    }get{
        
        let r = Double(UserDefaults.standard.string(forKey: "\(key)playbackColor_r") ?? "0.0")
        let g = Double(UserDefaults.standard.string(forKey: "\(key)playbackColor_g") ?? "0.0")
        let b = Double(UserDefaults.standard.string(forKey: "\(key)playbackColor_b") ?? "1.0")
        let a = Double(UserDefaults.standard.string(forKey: "\(key)playbackColor_a") ?? "1.0")
            
        return NSColor.init(red: r!, green: g!, blue: b!, alpha: a!)
        
    }
}
    @objc var rehearseBgColor : NSColor{
        set{
            let color = newValue.usingColorSpace(.genericRGB)
            
            if annunciatorTextView?.text == REH_MSG{
                
                annunciatorTextView?.backgroundColor = color!
                
            }
            
            UserDefaults.standard.set("\(color!.redComponent)", forKey: "\(key)rehearseColor_r")
            UserDefaults.standard.set("\(color!.greenComponent)", forKey: "\(key)rehearseColor_g")
            UserDefaults.standard.set("\(color!.blueComponent)", forKey: "\(key)rehearseColor_b")
            UserDefaults.standard.set("\(color!.alphaComponent)", forKey: "\(key)rehearseColor_a")

        }get{
            
            let r = Double(UserDefaults.standard.string(forKey: "\(key)rehearseColor_r") ?? "0.0")
            let g = Double(UserDefaults.standard.string(forKey: "\(key)rehearseColor_g") ?? "1.0")
            let b = Double(UserDefaults.standard.string(forKey: "\(key)rehearseColor_b") ?? "0.0")
            let a = Double(UserDefaults.standard.string(forKey: "\(key)rehearseColor_a") ?? "1.0")
                
            return NSColor.init(red: r!, green: g!, blue: b!, alpha: a!)
            
        }
    }
    @objc var recordBgColor : NSColor{
        set{
            let color = newValue.usingColorSpace(.genericRGB)
            
            if annunciatorTextView?.text == REC_MSG{
                
                annunciatorTextView?.backgroundColor = color!
                
            }

            UserDefaults.standard.set("\(color!.redComponent)", forKey: "\(key)recordBgColor_r")
            UserDefaults.standard.set("\(color!.greenComponent)", forKey: "\(key)recordBgColor_g")
            UserDefaults.standard.set("\(color!.blueComponent)", forKey: "\(key)recordBgColor_b")
            UserDefaults.standard.set("\(color!.alphaComponent)", forKey: "\(key)recordBgColor_a")

        }get{
            
            let r = Double(UserDefaults.standard.string(forKey: "\(key)recordBgColor_r") ?? "1.0")
            let g = Double(UserDefaults.standard.string(forKey: "\(key)recordBgColor_g") ?? "0.0")
            let b = Double(UserDefaults.standard.string(forKey: "\(key)recordBgColor_b") ?? "0.0")
            let a = Double(UserDefaults.standard.string(forKey: "\(key)recordBgColor_a") ?? "1.0")
                
            return NSColor.init(red: r!, green: g!, blue: b!, alpha: a!)
            
        }
    }
    @objc var playbackBgColor : NSColor{
        set{
            let color = newValue.usingColorSpace(.genericRGB)
            
            if annunciatorTextView?.text == PB_MSG{
                
                annunciatorTextView?.backgroundColor = color!
                
            }

            UserDefaults.standard.set("\(color!.redComponent)", forKey: "\(key)playbackBgColor_r")
            UserDefaults.standard.set("\(color!.greenComponent)", forKey: "\(key)playbackBgColor_g")
            UserDefaults.standard.set("\(color!.blueComponent)", forKey: "\(key)playbackBgColor_b")
            UserDefaults.standard.set("\(color!.alphaComponent)", forKey: "\(key)playbackBgColor_a")

        }get{
            
            let r = Double(UserDefaults.standard.string(forKey: "\(key)playbackBgColor_r") ?? "0.0")
            let g = Double(UserDefaults.standard.string(forKey: "\(key)playbackBgColor_g") ?? "0.0")
            let b = Double(UserDefaults.standard.string(forKey: "\(key)playbackBgColor_b") ?? "1.0")
            let a = Double(UserDefaults.standard.string(forKey: "\(key)playbackBgColor_a") ?? "1.0")
                
            return NSColor.init(red: r!, green: g!, blue: b!, alpha: a!)
            
        }
    }

    var cmdDictionary : Dictionary = [
        // TextWindowServer commands
        "ping" : #selector(ping(_:))
        ,"text" : #selector(text(_:))
        ,"anchor" : #selector(anchor(_:))
        ,"opaque" : #selector(opaque(_:))
        ,"version" : #selector(version(_:))
        ,"hidePix" : #selector(hidePix(_:))
        ,"H" : #selector(showMask(_:))
        ,"V" : #selector(VText(_:))
        ,"V1" : #selector(V1Text(_:))
        ,"V2" : #selector(V2Text(_:))
        ,"showWindow" : #selector(showWindow(_:))
//        ,"nextMonitor" : #selector(nextMonitor(_:))   // drag small window to screen, make full screen
        ,"nextPunch" : #selector(nextPunch(_:))
        // v1.00.23 moved VM15B commands to here
        ,"midi" : #selector(midi(_:))
        ,"C" : #selector(rC(_:))
        ,"E" : #selector(rE(_:))
        ,"U" : #selector(rU(_:))
        ,"U1" : #selector(rU1(_:))
    ]
    
//    @objc func foo(_ msg : NSString) -> NSString?{
//
//        return nil
//
//    }


    init(_ streamer : Streamer,_ textView : TextView,_ cueIdTextView : TextView,_ annunciatorTextView : TextView){
        
        super.init()
        
        self.streamer = streamer
        self.textView = textView
        self.cueIdTextView = cueIdTextView
        self.annunciatorTextView = annunciatorTextView
        
        let dict : [String : Any] = [
            "\(key)rehearseColor_r" : "1.0"
            ,"\(key)rehearseColor_g" : "1.0"
            ,"\(key)rehearseColor_b" : "1.0"
            ,"\(key)rehearseColor_a" : "1.0"
            ,"\(key)recordColor_r" : "1.0"
            ,"\(key)recordColor_g" : "1.0"
            ,"\(key)recordColor_b" : "1.0"
            ,"\(key)recordColor_a" : "1.0"
            ,"\(key)playbackColor_r" : "1.0"
            ,"\(key)playbackColor_g" : "1.0"
            ,"\(key)playbackColor_b" : "1.0"
            ,"\(key)playbackColor_a" : "1.0"
            ,"\(key)rehearseBgColor_r" : "0.0"
            ,"\(key)rehearseBgColor_g" : "1.0"
            ,"\(key)rehearseBgColor_b" : "0.0"
            ,"\(key)rehearseBgColor_a" : "1.0"
            ,"\(key)recordBgColor_r" : "1.0"
            ,"\(key)recordBgColor_g" : "0.0"
            ,"\(key)recordBgColor_b" : "0.0"
            ,"\(key)recordBgColor_a" : "1.0"
            ,"\(key)playbackBgColor_r" : "0.0"
            ,"\(key)playbackBgColor_g" : "0.0"
            ,"\(key)playbackBgColor_b" : "1.0"
            ,"\(key)playbackBgColor_a" : "0.0"
            ]
        
        let defaults = UserDefaults.standard
        defaults.register(defaults: dict)

//        let currentHost = Host.current().localizedName ?? SERVICE_NAME
//        let port : String? = nil
//        listener = Listener(self,port,currentHost,SERVICE_TYPE,isTcp: true)
        
//        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: NSApplication.didBecomeActiveNotification, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidResignActive(_:)), name: NSApplication.didResignActiveNotification, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(didChangeScreenParameters(_:)), name: NSApplication.didChangeScreenParametersNotification, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)), name: NSWindow.willCloseNotification, object: nil)

       // NSWindow.willCloseNotification
        
//        let dict : [String : Any] = [
//
//            "screenSelector" : "0"  // default screen
//        ]
//
//        let defaults = UserDefaults.standard
//        defaults.register(defaults: dict)
//
//        recallDefaults()

    }
    
//    func recallDefaults(){
//
//        let defaults = UserDefaults.standard
//
//        if let s = defaults.string(forKey: "screenSelector"){
//
//            screenSelector = Int(s)!
//        }
//
//    }
    
//    func sizeToCurrentScreen(){
//
//        // the one place where this is done
//        // setPunchLayer
//
//        let screens = NSScreen.screens
//
//        if screenSelector < screens.count{
//
//            if let window = textView?.window{
//
//                window.setFrame(screens[screenSelector].frame, display: true, animate: false)
//                streamer?.setPunchLayer(next: false)    // size the punch when the window size changes
//            }
//        }
//
//    }
//    @objc func windowDidMove(_ notification : NSNotification){
//        if (notification.object as! NSWindow) == textView?.window{
////            print("windowDidMove")
//            for screen in NSScreen.screens{
//
//                let origin = textView?.window?.frame.origin
//
//                if screen.frame.contains(origin!){
//
//                    // keep track of the current overlay screen
//                    screenSelector = NSScreen.screens.firstIndex(of: screen)!
//                    break
//                }
//            }
//        }
//    }
//
//
//    @objc func windowDidBecomeMain(_ notification : NSNotification){
//
////        print("Streamer applicationDidBecomeActive")
//        if let window = textView?.window{
//
//            window.ignoresMouseEvents = false
//
//            // the window is always full size for the screen it is on, no title bar
//
//            // style mask show title bar
//            window.styleMask = [.titled]
//            window.titlebarAppearsTransparent = false
//            window.titleVisibility            = .visible
//
//            // having this here does give the window the focus
//            window.makeKeyAndOrderFront(nil)    // this is the only place this happens
//
//            sizeToCurrentScreen() //
//        }
//
//    }
//    @objc func windowDidResignMain(_ notification : NSNotification){
//
////        print("Streamer applicationDidResignActive")
//        if let window = textView?.window{
//
//            window.ignoresMouseEvents = true
//
//            window.styleMask = [.fullSizeContentView]
//            window.titlebarAppearsTransparent = true
//            window.titleVisibility            = .hidden
//
//            sizeToCurrentScreen() //
//
//            // we save settings in two places, here and when window closes
//            // one or both will be called after a font change
//            saveSettings()
//        }
//    }
//    @objc func didChangeScreenParameters(_ notification : NSNotification){
//
//        sizeToCurrentScreen() //
//    }
//    @objc func windowWillClose(_ notification : NSNotification){
//
//        // save TextView settings
//        // NSFontPanel and NSColorPanel don't do the saves
//        saveSettings()
//    }
    @objc func saveSettings(){
        
        textView?.saveSettings()
        cueIdTextView?.saveSettings()
        annunciatorTextView?.saveSettings()
    }
    
//    @objc func rxMsg(_ cmd : NSString) -> NSString?{
//        
//        let items = cmd.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: CharacterSet.whitespaces)
//
//        if items.count > 0{
//
//            let sel = cmdDictionary[items[0]]
//            
//            if sel != nil{
//
//                let result = self.perform(sel, with: items)
//                
//                return result?.takeUnretainedValue() as? NSString   // no reference count
//
//            }
//        }
//        
//        return nil
//
//    }

    // MARK: -------- TextWindowServer commands ---------
//    func send(_ str : String?, _ connection : NWConnection?){
//
//        // https://www.codegrepper.com/code-examples/swift/send+receive+udp+swift
//        connection?.send(content: str?.data(using: String.Encoding.utf8), completion: NWConnection.SendCompletion.contentProcessed{ (_ error : NWError?) -> Void in
//
//            if error != nil{
//                print(error!)
//            }
//
//        })
//    }
    @objc func ping( _ array: Any) -> NSString?{

//        send("ping\n",connection as? NWConnection)
        return("ping\n")
    }
    @objc func text( _ array: Any) -> NSString?{
        
        guard var array = array as? Array<String> else{
            return nil
        }
        
        array.removeFirst()
        let str = array.joined().replacingOccurrences(of: "\\n", with: "\n").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        textView!.text = str
//        textLayer.showText(str, view)
        return nil

    }
    @objc func anchor( _ array: Any) -> NSString?{
        
//        let conn = connection as! NWConnection    // if you need to cast
        guard let array = array as? Array<String> else{
            return nil
        }
        
        print("anchor \(array)")
        
        if array.count > 1{
            
            var result = Int32(array[1])
            
            if result == -1{    // increment anchor
                
                switch textView!.anchor{
                    
                case .TOP_LEFT: textView!.anchor = .TOP_RIGHT; break
                case .TOP_RIGHT: textView!.anchor = .BOTTOM_RIGHT; break
                case .BOTTOM_RIGHT: textView!.anchor = .BOTTOM_LEFT; break
                case .BOTTOM_LEFT: textView!.anchor = .HIDDEN; break
                case .HIDDEN: textView!.anchor = .TOP_LEFT; break
                }
                
            }else{
                result! %= 5; textView!.anchor = Anchor(rawValue: result!)!
            }

        }
        
//        textLayer.showText(textLayer.text,view)
        
        return nil

    }
    @objc func opaque( _ array: Any) -> NSString?{
        
        // toggle backing view
        // 09/10/22 operand is value of isFullFrame, else toggle
        guard let array = array as? Array<String> else{
            return nil
        }

        if array.count > 1{

            let isFullFrame = array[1] != "0"
            
            let wc = self.textView?.window?.windowController as! OverlayWindowController
            
            if isFullFrame{
                
                wc.activateWindow()
                wc.window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
//                print("makeKeyAndOrderFront %s",key)
                
            }else{
                wc.deactivateWindow()
            }
            
            textView?.isFullFrame = isFullFrame
            cueIdTextView?.isFullFrame = isFullFrame
            annunciatorTextView?.isFullFrame = isFullFrame
            streamer?.isFullFrame = isFullFrame    // for dragging punch
        }
        
        return nil

    }
    @objc func setOpaque(_ opaque : Bool){
        
        let wc = textView?.window?.windowController as! OverlayWindowController

        if opaque{
            
            wc.activateWindow()
            wc.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            streamer!.punchLayer.opacity = 1.0  // make punch layer opaque
//            print("makeKeyAndOrderFront %s",key)

        }else{
            
            streamer!.punchLayer.opacity = 0.0  // make punch layer transparent
            wc.deactivateWindow()
        }
        
        textView?.isFullFrame = opaque
        cueIdTextView?.isFullFrame = opaque
        annunciatorTextView?.isFullFrame = opaque
        streamer?.isFullFrame = opaque    // for dragging punch

    }
    @objc func version( _ array: Any) -> NSString?{
        
//        guard let connection = connection as? NWConnection else{
//            return nil
//        }

        let ver = "\(Bundle.main.infoDictionary!["CFBundleShortVersionString"] ?? "3.00.00")\n"//()
        
//        send("version \(ver)", connection)
        return NSString(utf8String: "version \(ver)")
 
    }
    @objc func hidePix( _ array: Any) -> NSString?{
        
//        let conn = connection as! NWConnection    // if you need to cast
        //WarnerBros-Lot.jpg
        //         NSString *msg = [ NSString stringWithFormat:@"hidePix %d",_hidePix];

        guard let array = array as? Array<String> else{
            return nil
        }
        
        if array.count < 2{ return nil}
        
        let hidePix = array[1] != "0"
        
        streamer?.hidePix(hidePix)
        
//        if hidePix{
//
//            hidePixLayer.contents = NSImage(imageLiteralResourceName: "WarnerBros-Lot")
//            hidePixLayer.frame.origin = CGPoint(x: 0.0, y: 0.0) // because we are relative to our window, not the screen
//            hidePixLayer.frame.size = (view.window?.frame.size)!
//            hidePixLayer.backgroundColor = NSColor.black.cgColor
//            hidePixLayer.zPosition = HIDEPIX_Z
//            view.layer?.addSublayer(hidePixLayer)
//
//            CATransaction.begin()
//            hidePixLayer.removeAllAnimations()
//            CATransaction.commit()
//
//        }else{
//            hidePixLayer.removeFromSuperlayer()
//        }
        return nil
    }
    @objc func showMask( _ array: Any) -> NSString?{
        
//        vm15B!.showMask(connection,array)
        guard let array = array as? Array<String> else{
            return nil
        }
//        guard let connection = connection as? NWConnection else{
//            return nil
//        }

        if array.count >= 6{
            
            streamer!.topMask = Int(array[1])!
            streamer!.bottomMask = Int(array[2])!
            streamer!.leftMask = Int(array[3])!
            streamer!.rightMask = Int(array[4])!
            streamer!.transparency = Int(array[5])!
        }
        // range is 0-255
        
//        maskFromValues(topMask, bottomMask, rightMask, leftMask, transparency)
//        send("H \(streamer!.topMask) \(streamer!.bottomMask) \(streamer!.leftMask) \(streamer!.rightMask) \(streamer!.transparency)\n", connection)
        return NSString(utf8String: "H \(streamer!.topMask) \(streamer!.bottomMask) \(streamer!.leftMask) \(streamer!.rightMask) \(streamer!.transparency)\n")


    }
//    func showTextForLayer(_ array : Any,_ layer : TextLayer){
//
//        guard var array = array as? Array<String> else{
//            return
//        }
//
//        array.removeFirst()
//        let str = array.joined(separator: " ").replacingOccurrences(of: "\\n", with: "\n").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
//        layer.showText(str, view)
//
//    }
//    func showTextForTextView(_ array : Any,_ view : TextView){
//
//        guard var array = array as? Array<String> else{
//            return
//        }
//
//        array.removeFirst()
//        let str = array.joined(separator: " ").replacingOccurrences(of: "\\n", with: "\n").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
//
//        view.text = str
//
//    }
//
//
    func showTextForTextView(_ array : Any,_ view : TextView){
        
        guard var array = array as? Array<String> else{
            return
        }
        
        array.removeFirst()
        let str = array.joined(separator: " ").replacingOccurrences(of: "\\n", with: "\n").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        view.text = str

    }

    @objc func VText( _ array: Any) -> NSString?{
        
//        vm15B?.VText(connection, array)
        guard let array = array as? Array<String> else{
            return nil
        }
        
        showTextForTextView(array, textView!)

//        showTextForTextView(array, textView)

//        showTextForLayer(array, textLayer)
        return nil
    }
    @objc func V1Text( _ array: Any) -> NSString?{

        guard let array = array as? Array<String> else{
            return nil
        }
        
        showTextForTextView(array, annunciatorTextView!)
        return nil

    }
    @objc func V2Text( _ array: Any) -> NSString?{

        guard let array = array as? Array<String> else{
            return nil
        }
        
        showTextForTextView(array, cueIdTextView!)
        return nil

    }
    @objc func showWindow( _ array: Any) -> NSString?{
        
        NSApp.activate(ignoringOtherApps: true)
        return nil
        
    }
    
//    @objc func nextMonitor( _ array: Any) -> NSString?{
//
//        // move text window server to the next monitor
//
//        screenSelector += 1
//        return nil
//
//    }
    @objc func nextPunch( _ array: Any) -> NSString?{
        
        streamer?.punchIndex += 1   // increments index, shows punch
        streamer?.showPunch(true)   // increments index, shows punch
        return nil
    }
    // MARK: ----------- items moved from VM15B -------------
    let streamerColors = [
        NSColor.clear,  // placeholder for index 0, which is not used
        NSColor.white,
        NSColor.yellow,
        NSColor.cyan,
        NSColor.green,
        NSColor.magenta,
        NSColor.red,
        NSColor.blue,
        NSColor.black,
        NSColor.clear, // this is a bad color to use, isn't it?
        NSColor.brown,
        NSColor.orange,
        NSColor.purple,
        NSColor.white
    ]

    @objc func midi(_ array: Any)-> NSString?{
        
//        print("midi \(array)")
        guard let array = array as? Array<String> else{
            return nil
        }
        
        if array.count < 4{return nil}
        
        switch UInt(array[1], radix: 16){
        case 0x90:  // note on
            
            let i = UInt(array[2], radix: 16)
            if i! >= 124 && i! <= 127 || i == 119{
                // trigger streamer, [3] is color?
                // colors 1-13 match colors in the AleDoc/Streamer Setup/Streamer dropdown
                let j = Int(UInt(array[3], radix: 16)!)
                let color = j < streamerColors.count ? streamerColors[j] : NSColor.white
                // no clear streamers
                streamer?.triggerStreamer(color == NSColor.clear ? NSColor.white : color)
            }
            if i! >= 120 && i! <= 123{
                // trigger punch
                let j = Int(UInt(array[3], radix: 16)!)
                streamer?.punchColor = j < streamerColors.count ? streamerColors[j] : NSColor.white
                // no clear punches
                streamer?.showPunch(true)

            }
            // TODO: streamer black cue black, rgb fade, what else?
            break
        default:
            break
        }
        
        return nil

    }
    @objc func rC(_ array: Any) -> NSString?{
        
        // the VM15A message from vm15.c
        //     NSString *tx = [NSString stringWithFormat:@"C %x %x %x %x %x %x %x %x %x\n",(int)mask,(int)_width,0,ms20_count,(int)_colorMsb,(int)_top,255 - (int)_bottom,(int)_transparency,108];
        
        guard let array = array as? Array<String> else{
            return nil
        }

        if array.count >= 10{
            // enough items in array
            
            // save C state, to echo back to AleDoc, rather than constructing it
            UserDefaults.standard.set(array.joined(separator: " "), forKey: "rC")
            
            let colorLsb = Int(array[1],radix: 16)!
            let width = Int(array[2],radix: 16)!
            let colorMsb = Int(array[5],radix: 16)!
            let top = Int(array[6],radix: 16)!
            let bottom = Int(array[7],radix: 16)!
            let transparency = Int(array[8],radix: 16)!
            
            let i = 1 + (colorLsb & 7) | ((colorMsb & 1) << 3)
            let streamerColor = i < streamerColors.count ? streamerColors[i] : NSColor.white
            let j = 1 + ((colorLsb >> 12) & 7) | (((colorMsb >> 4) & 1) << 3)
            let endBarColor = j < streamerColors.count ? streamerColors[j] : NSColor.white
            
            streamer!.streamerColor = (streamerColor == NSColor.clear ? NSColor.white : streamerColor)
            streamer!.endBarColor = (endBarColor == NSColor.clear ? NSColor.white : endBarColor)
            
            // TODO: width etc
            print("width \(width) top \(top) bottom \(bottom) transparency \(transparency)")
//            delegate?.rStreamer(streamerColor,endBarColor, width, top, bottom, transparency)

        }
        // echo the C state
        if let s = UserDefaults.standard.string(forKey: "rC"){
            
//            send("\(s)\n",connection as? NWConnection)
            return NSString(utf8String: "\(s)\n")
            
        }
        
        return nil

    }
    @objc func rE(_ array: Any) -> NSString?{
        /*
         see AleDoc/Streamer/PunchImage/txPunchMsg()
         
         if(_punchEnable) punchMask = 1;
         if(_beepsEnable) punchMask |= 2;

         NSString *tx = [NSString stringWithFormat:@"E %x %x %x %x %x %x %x %x\n",(int)mask,(int)_x,(int)_y,(int)_diameter,(int)_durationFrames, delay, (int)_beepsRepeatCount, punchMask];

         */
        
        guard let array = array as? Array<String> else{
            return nil
        }
//                print("array \(array)")

        if array.count >= 9{

            // save E state, to echo back to AleDoc, rather than constructing it
            UserDefaults.standard.set(array.joined(separator: " "), forKey: "rE")
            
            let punchMask = Int(array[8],radix: 16)!
            
            let enPunch = (punchMask & 1) != 0
            let enBeeps = (punchMask & 0x2) != 0
            
            // TODO; many more flags in this message
            UserDefaults.standard.set(enPunch, forKey: "enPunch")
            UserDefaults.standard.set(enBeeps, forKey: "enBeeps")
//            delegate?.rPunch(enPunch, enBeeps)
            // TODO; many more flags in this message
            
            let colorLsb =  1 + Int(array[1],radix: 16)!
            let color = colorLsb < streamerColors.count ? streamerColors[colorLsb] : NSColor.white
            streamer!.punchColor = (color == NSColor.clear ? NSColor.white : color)
            let x = Int(array[2],radix: 16)!
            let y = Int(array[3],radix: 16)!
            let d = Int(array[4],radix: 16)!
            streamer!.punchXFraction = Double(x) / 256.0
            streamer!.punchYFraction = 1 - (Double(y) / 256.0)
            streamer!.punchFraction = Double(d) / 256.0
            print("x \(x) y \(y)")
//            streamer!.setPunchLayer(next: false)
            streamer!.setPunchLayer()

        }
        
        // send the E state
        if let s = UserDefaults.standard.string(forKey: "rE"){
            
            var array = s.components(separatedBy: " ")
            
            // need at least 9 items
            while array.count < 9{
                array.append("0")
            }
            
            array[0] = "E"  // punch command, should be set already, can't hurt
            
            // fill in the values we are using, leave the rest as is
            let index = streamerColors.firstIndex(of: streamer!.punchColor)
            
            if let index = index{
                array[1] = String(format: "%02x", index - 1)

            }
            
            
            let x = Int(256.0 * streamer!.punchXFraction)
            let y = Int(256.0 * (1 - streamer!.punchYFraction))
            let size = Int(256.0 * streamer!.punchFraction)
            

            array[2] = String(format: "%02x", x)
            array[3] = String(format: "%02x", y)
            array[4] = String(format: "%02x", size)
            array[7] = "3"  // 3 punches
            var mask = UserDefaults.standard.bool(forKey: "enPunch") ? 1 : 0
            mask += UserDefaults.standard.bool(forKey: "enBeeps") ? 2 : 0
            array[8] = String(format: "%02x", mask)

//            send("\(array.joined(separator: " "))\n",connection as? NWConnection)
            return NSString(utf8String: "\(array.joined(separator: " "))\n")
        }
        
        return nil
    }
    let REH_MSG = "Rehearse"
    let REC_MSG = "Record"
    let PB_MSG = "Playback"
    
    @objc func rU(_ array: Any) -> NSString?{
        
        guard let array = array as? Array<String> else{
            return nil
        }
        
        if array.count < 2{
            return nil
        }
            
        switch(array[1]){
        case "1":
            annunciatorTextView!.setTextBounds(text: REH_MSG, textColor: NSColor.white, backgroundColor: rehearseColor)
            break
        case "2":
            // TODO: set foreground, background colors
            annunciatorTextView!.setTextBounds(text: REC_MSG, textColor: NSColor.white, backgroundColor: recordColor)
            break
        case "3":
            // TODO: set foreground, background colors
            annunciatorTextView!.setTextBounds(text: PB_MSG, textColor: NSColor.white, backgroundColor: playbackColor)
            break
        default:
            annunciatorTextView!.text = ""
            break
        }
        
        return nil
    }
    
    @objc func rU1(_ array: Any) -> NSString?{
        
        /*
         NSString *msg = [NSString stringWithFormat:@"U1 %d %d %d %d %d %d %d %d %d",
                          redReh,greenReh,blueReh,
                          redRec,greenRec,blueRec,
                          redPb,greenPb,bluePb
                          ];

         */
        
        guard let array = array as? Array<String> else{
            return nil
        }
        
        if array.count >= 10{
            
            var r = Double(Int(array[1])!)/255.0
            var g = Double(Int(array[2])!)/255.0
            var b = Double(Int(array[3])!)/255.0
            
            rehearseColor = NSColor.init(red: r, green: g, blue: b, alpha: 1.0)
            
            r = Double(Int(array[4])!)/255.0
            g = Double(Int(array[5])!)/255.0
            b = Double(Int(array[6])!)/255.0
            
            recordColor = NSColor.init(red: r, green: g, blue: b, alpha: 1.0)
            
            r = Double(Int(array[7])!)/255.0
            g = Double(Int(array[8])!)/255.0
            b = Double(Int(array[9])!)/255.0
            
            playbackColor = NSColor.init(red: r, green: g, blue: b, alpha: 1.0)
        }

        // tx U1 state
        
        let ri = Int(rehearseColor.redComponent * 255)
        let gi = Int(rehearseColor.greenComponent * 255)
        let bi = Int(rehearseColor.blueComponent * 255)
        
        let ri2 = Int(recordColor.redComponent * 255)
        let gi2 = Int(recordColor.greenComponent * 255)
        let bi2 = Int(recordColor.blueComponent * 255)
        
        let ri3 = Int(playbackColor.redComponent * 255)
        let gi3 = Int(playbackColor.greenComponent * 255)
        let bi3 = Int(playbackColor.blueComponent * 255)

        let s = "U1 \(ri) \(gi) \(bi) \(ri2) \(gi2) \(bi2) \(ri3) \(gi3) \(bi3)\n"
        
//        send(s,connection as? NWConnection)
        return NSString(utf8String: s)

    }

}
//// MARK: -------- Listener delegate ---------
//
//extension TextWindowServer : ListenerDelegate{
//
//    func addConnection(_ newConnection : NWConnection){
//
//        print("ViewController Listener delegate addConnection")
//
//        // check for duplicate endpoints, remove old duplicate
//        var connsToKeep = [Connection]()
//
//        for connection in connections{
//
//            if let endpoint = connection.connection?.endpoint{
//                if endpoint != newConnection.endpoint{
//                    connsToKeep.append(connection)
//                }
//            }
//        }
//        connsToKeep.append(Connection(self,newConnection))
//        connections = connsToKeep
//
//        print("ViewController connections: \(connections.count)")
//
//    }
//    func listenerReady(_ listener : Listener){
//
//        print("ViewController Listener delegate listenerReady")
//        // TODO: remove all previous connection?
//    }
//
//}
////MARK: ------- ConnectionDelegate ----------
//extension TextWindowServer : ConnectionDelegate{
//    func receiveErrorService(_ connection: NWConnection, _ error: NWError) {
//
//    }
//
//    func receiveService(_ connection: NWConnection, _ data: Data) {
//
//        let str = String(decoding: data, as: UTF8.self)
//
//        let array = str.components(separatedBy: CharacterSet.init(charactersIn: "\n"))
//
//        for cmd in array{
//
//            let items = cmd.components(separatedBy: CharacterSet.whitespaces)
//
//            if items.count > 0{
//
//                let sel = cmdDictionary[items[0]]
//
//                if sel != nil{
//
////                    let rxStruct = RxStruct(connection: connection, array: items)
////                    performSelector(onMainThread: sel!, with: rxStruct, waitUntilDone: false)
//                    DispatchQueue.main.async {
//                        self.perform(sel, with: connection, with: items)
//                    }
//                }
//            }
//        }
//
//    }
//
//    func connectionReady(_ connection: NWConnection) {
//
//    }
//
//    func connectionFailed(_ connection: NWConnection) {
//
//        for conn in connections{
//
//            if conn.connection?.endpoint == connection.endpoint{
//
//                print("connectionFailed, removing connection from list")
//                connections.remove(at: connections.firstIndex(of: conn)!)
//                return
//            }
//        }
//
//    }
//
//
//}
