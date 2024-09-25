//
//  ViewController.swift
//  Use UpDoc as CALayer example
//  overlay text, streamers, punches
//
//  Created by Jim on 7/7/22.
//
//  this is 'TextWindowServer_v3', use command set from TextWindowServer, plus streamer, beep, and punch commands

import Cocoa
import Network
import AVFoundation
import MetalKit

//enum Anchor : Int32{
//    case TOP_LEFT,BOTTOM_LEFT,TOP_RIGHT,BOTTOM_RIGHT,HIDDEN
//}

//enum DragItem{
//    case NONE,TEXT,CUE_ID,TAKE,PUNCH
//}

//struct RxStruct{
//    var connection : NWConnection?
//    var array : Array<String>?
//}

let STREAMER_Z = ENDBAR_Z + 0.01//ENDBAR_Z + 0.05    // streamer over endbar
let ENDBAR_Z = PUNCH_Z - 0.02//TEXT_Z + 0.05        // endbar behind punch
// 10/19/22 we found that text is 0.0 no matter what we do, so make everything relative to it
// our window is above the other windows, these z levels are relative to our window level
let TEXT_Z = 0.0
let PUNCH_Z = TEXT_Z - 0.05     // punch behind text
let BACKING_Z = PUNCH_Z - 0.05
let HIDEPIX_Z = BACKING_Z - 0.05      // over mask
let MASK_Z = HIDEPIX_Z - 0.05   // mask behind all
//let streamerLayer = CAMetalLayer()  // 2.10.00 Metal streamers are behind other layers, why?

@objc class ViewController: NSViewController {
    
    var aleDelegate : AleDelegate?
    var progressBarTimer : Timer?   // update a few times a second
    var tcc : TcCalculator?

    @IBOutlet var textView: TextView!
    @IBOutlet var cueIdTextView: TextView!
    @IBOutlet var annunciatorTextView: TextView!
    @IBOutlet var progressTextView: TextView!
    @IBOutlet weak var mtkView: MTKView!
    @objc var streamerRenderer : StreamerRenderer?

    @objc var streamer : Streamer?
    
    @objc var opaque : Bool = false{
        didSet{
            
            let wc = textView?.window?.windowController as! OverlayWindowController

            if opaque{
                
                wc.activateWindow()
                wc.window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                streamer!.punchLayer.opacity = 1.0  // make punch layer opaque

            }else{
                
                streamer!.punchLayer.opacity = 0.0  // make punch layer transparent
                wc.deactivateWindow()
            }
            
            progressTextView?.isFullFrame = opaque
            textView?.isFullFrame = opaque
            cueIdTextView?.isFullFrame = opaque
            annunciatorTextView?.isFullFrame = opaque
            streamer?.isFullFrame = opaque    // for dragging punch
            
            annunciatorTextView?.opacity = opaque ? 1.0 : 0.0   // not visible unless in cycle
            aleDelegate?.setLEDForUnitID(9, 41, opaque)

        }
    }
    
    @objc var rehRecPb : Int = 0{
        
        didSet{
            
            var fgColor = NSColor.clear
            var bgColor = NSColor.clear
            let text = ""
            
            switch(rehRecPb){
            case MODE_CONTROL_REHEARSE:
                fgColor = UserDefaults.standard.color(forKey: "rehearseColor")
                bgColor = UserDefaults.standard.color(forKey: "rehearseBgColor")
                //text = "Rehearse" // 2.10.02 leave text blank until cycle starts
                break
            case MODE_CONTROL_RECORD:
                fgColor = UserDefaults.standard.color(forKey: "recordColor")
                bgColor = UserDefaults.standard.color(forKey: "recordBgColor")
                //text = "Record"   // 2.10.02 leave text blank until cycle starts
                break
            case MODE_CONTROL_PLAYBACK:
                fgColor = UserDefaults.standard.color(forKey: "playbackColor")
                bgColor = UserDefaults.standard.color(forKey: "playbackBgColor")
                //text = "Playback" // 2.10.02 leave text blank until cycle starts
                break
            case MODE_CONTROL_REHEARSE_PENDING:
                fgColor = UserDefaults.standard.color(forKey: "rehearseColor")
                bgColor = UserDefaults.standard.color(forKey: "rehearseBgColor")
//                text = "Rehearse\npending"
                break
            case MODE_CONTROL_RECORD_PENDING:
                fgColor = UserDefaults.standard.color(forKey: "recordColor")
                bgColor = UserDefaults.standard.color(forKey: "recordBgColor")
//                text = "Record\npending"
                break
            case MODE_CONTROL_PLAYBACK_PENDING:
                fgColor = UserDefaults.standard.color(forKey: "playbackColor")
                bgColor = UserDefaults.standard.color(forKey: "playbackBgColor")
//                text = "Playback\npending"
                break
            default: break
            }
            
            annunciatorTextView?.text = text
            annunciatorTextView?.textColor = fgColor
            annunciatorTextView?.backgroundColor = bgColor
            
        }
    }

     
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        self.view.wantsLayer = true // trying to get streamers behind other layers
        
        aleDelegate = NSApplication.shared.delegate as? AleDelegate

        textView.setKey("Text")
        cueIdTextView.setKey("Cue ID and take number")
        annunciatorTextView.setKey("Annunciator")
        progressTextView.setKey("Progress bar")
        annunciatorTextView.opacity = 0 // not visible unless in cycle
        streamer = Streamer(view)
        
        rehRecPb = MODE_CONTROL_REHEARSE
        textView.textColor = UserDefaults.standard.color(forKey: "textColor")
        textView.backgroundColor = UserDefaults.standard.color(forKey: "textBgColor")
        cueIdTextView.textColor = UserDefaults.standard.color(forKey: "cueIdColor")
        cueIdTextView.backgroundColor = UserDefaults.standard.color(forKey: "cueIdBgColor")
        progressTextView.textColor = UserDefaults.standard.color(forKey: "progressBarColor")
        progressTextView.backgroundColor = UserDefaults.standard.color(forKey: "progressBarBgColor")

        // for cancelAllStreamers
        streamer?.annunciatorTextView = annunciatorTextView
        
        //
        tcc = TcCalculator()
        progressBarTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(progressBarService), userInfo: nil, repeats: true)
        
        // 2.10.02 moving the streamer MTKView here so we have zPosition
        mtkView!.layer?.isOpaque = false    // clear background
        mtkView!.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)

        mtkView!.device = MTLCreateSystemDefaultDevice()
        assert((mtkView!.device != nil), "Metal is not supported on this device")

        streamerRenderer = StreamerRenderer.init(metalKitView: mtkView!)
        assert((streamerRenderer != nil), "Renderer failed initialization")

        mtkView!.delegate = streamerRenderer
        mtkView!.wantsLayer = true  // layer-backed view (streamers, text, punches are layers)
        mtkView!.layer?.zPosition = STREAMER_Z
        
        streamer?.streamerRenderer = streamerRenderer

        
    }
    @objc func progressBarService(){
        
        // update the progress bar a few times a second
        // note that we stay in tc, and use pt mtc as the trigger, because we have 'mtcString' handy
        if let doc = aleDelegate?.topDocument(),
           let start = doc.startTc(),
           let end = doc.endTc(),
           let startFrs = tcc?.tc(toBinary: start, withType: 3),
           let endFrs = tcc?.tc(toBinary: end, withType: 3),
           let tc = tcc?.tc(toBinary: aleDelegate?.matrixWindowController.mtcString, withType: 3){
            
            let progress = Double(endFrs - startFrs) / 30.0
            
            let enProgressBar = UserDefaults.standard.bool(forKey: "enProgressBar")
            let inhStreamerInPb = UserDefaults.standard.bool(forKey: "inhibitStreamerInPlayback")
            let isPlaybackMode = (aleDelegate?.matrixWindowController.rehRecPb)! == MODE_CONTROL_PLAYBACK

            if  tc < startFrs ||
                tc > endFrs ||
                progress <= 0  ||
                aleDelegate?.cycleMotion != CYCLE_MOTION_ACTIVE ||
                !enProgressBar ||
                (isPlaybackMode && inhStreamerInPb){
                
                progressTextView.progress = 0.0 // off
                return
                
            }
            
            if progressTextView.progress == 0.0{
                progressTextView.progress = progress    // clip at 100%
            }

            
        }else{
            
            progressTextView.progress = 0.0 // off
            
        }
        
    }
    override func viewWillAppear() {
        
        // https://stackoverflow.com/questions/34531118/how-can-i-create-a-window-with-transparent-background-with-swift-on-osx

        super.viewWillAppear()

        self.view.window?.acceptsMouseMovedEvents = true
        view.window?.backgroundColor = NSColor.clear
        view.window?.hasShadow = false  // redundant, but does not hurt
        // https://jameshfisher.com/2020/08/03/what-is-the-order-of-nswindow-levels/
//        view.window?.level = NSWindow.Level(rawValue: Int(myWindowLevel))

        NSColorPanel.shared.orderOut(self)
        NSFontPanel.shared.orderOut(self)   // hide the panels
        
        NotificationCenter.default.addObserver(self, selector: #selector(colorDidChangeNotification(_:)), name: NSColorPanel.colorDidChangeNotification, object: nil)

    }
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    // MARK: --------- notifications ------------
    @objc func colorDidChangeNotification(_ notification : NSNotification){
//        print("viewController colorDidChangeNotification")
        
        if self.opaque{
            // this happens on color wells or font color changes (any use of NSColorPanel)
            UserDefaults.standard.setColor(cueIdTextView.textColor, forKey: "cueIdColor")
            UserDefaults.standard.setColor(cueIdTextView.backgroundColor, forKey: "cueIdBgColor")
            UserDefaults.standard.setColor(textView.textColor, forKey: "textColor")
            UserDefaults.standard.setColor(textView.backgroundColor, forKey: "textBgColor")
            UserDefaults.standard.setColor(progressTextView.textColor, forKey: "progressBarColor")
            UserDefaults.standard.setColor(progressTextView.backgroundColor, forKey: "progressBarBgColor")

            switch(rehRecPb){
            case MODE_CONTROL_REHEARSE:
                UserDefaults.standard.setColor(annunciatorTextView.textColor, forKey: "rehearseColor")
                UserDefaults.standard.setColor(annunciatorTextView.backgroundColor, forKey: "rehearseBgColor")
                break
            case MODE_CONTROL_RECORD:
                UserDefaults.standard.setColor(annunciatorTextView.textColor, forKey: "recordColor")
                UserDefaults.standard.setColor(annunciatorTextView.backgroundColor, forKey: "recordBgColor")
                break
            case MODE_CONTROL_PLAYBACK:
                UserDefaults.standard.setColor(annunciatorTextView.textColor, forKey: "playbackColor")
                UserDefaults.standard.setColor(annunciatorTextView.backgroundColor, forKey: "playbackBgColor")
                break
            default:
                break
            }
        }else{
            // update the colors from the color wells
            cueIdTextView.textColor = UserDefaults.standard.color(forKey: "cueIdColor")
            cueIdTextView.backgroundColor = UserDefaults.standard.color(forKey: "cueIdBgColor")
            textView.textColor = UserDefaults.standard.color(forKey: "textColor")
            textView.backgroundColor = UserDefaults.standard.color(forKey: "textBgColor")
            progressTextView.textColor = UserDefaults.standard.color(forKey: "progressBarColor")
            progressTextView.backgroundColor = UserDefaults.standard.color(forKey: "progressBarBgColor")

            switch(rehRecPb){
            case MODE_CONTROL_REHEARSE:
                annunciatorTextView.textColor = UserDefaults.standard.color(forKey: "rehearseColor")
                annunciatorTextView.backgroundColor = UserDefaults.standard.color(forKey: "rehearseBgColor")
                break
            case MODE_CONTROL_RECORD:
                annunciatorTextView.textColor = UserDefaults.standard.color(forKey: "recordColor")
                annunciatorTextView.backgroundColor = UserDefaults.standard.color(forKey: "recordBgColor")
                break
            case MODE_CONTROL_PLAYBACK:
                annunciatorTextView.textColor = UserDefaults.standard.color(forKey: "playbackColor")
                annunciatorTextView.backgroundColor = UserDefaults.standard.color(forKey: "playbackBgColor")
                break
            default:
                break
            }
        }
        
    }
    @objc func colorDidChange(sender:AnyObject){
        
        print("viewController colorDidChange")
        
    }

    // MARK: --------- debug ------------
    @objc func tiSinceLastDraw(_ date: NSDate){
        
        // we see that mtc and vertical sync are not synchronized
        // we expect, then, a 1 field variance in streamer starts
        let ti = date.timeIntervalSince((streamer?.streamerRenderer?.drawDate)!)
        print("tiSinceLastDraw \(ti)")
        
    }
    // MARK: --------- actions ------------
    
    @IBAction func onTrigger(_ sender: Any) {
        
        streamer!.triggerStreamer(streamer!.streamerColor)
        
    }
    @IBAction func onImages(_ sender: Any) {
        
        streamer?.setPunchLayer()    // image or color punch
    }
    @objc func bringToFront(){
        // myWindowLevel
//        NSApp.activate(ignoringOtherApps: true)
        self.view.window?.level = overlayWindowLevel//.floating
        self.view.window?.orderFrontRegardless()

    }
    
    // MARK: ------------ mouse ---------------
    
    enum MOUSE_TARGET{
        case none,text,cueId,annunciator,punch,progressBar
    }
    
    var mouseTarget : MOUSE_TARGET = .none

    override func mouseDown(with event: NSEvent) {

        NSColorPanel.shared.level = overlayWindowLevel  // has to be at same level or greater
        NSFontPanel.shared.level = overlayWindowLevel   // has to be at same level or greater

//        print("NSColorPanel \(NSColorPanel.shared.level.rawValue) NSFontPanel \(NSFontPanel.shared.level.rawValue) floating \(NSWindow.Level.floating)")

        // hit test for punch is close to center of punch
        let size = 200.0  // hit area near center of punch
        
        var x = (streamer?.punchLayer.frame.origin.x)!
        x += (streamer?.punchLayer.frame.size.width)! / 2.0
        x -= size / 2.0
        
        var y = (streamer?.punchLayer.frame.origin.y)!
        y += (streamer?.punchLayer.frame.size.height)! / 2.0
        y -= size / 2.0
        
        let rect = NSRect(x: x, y: y, width: size, height: size)

        if streamer!.isFullFrame && rect.contains(event.locationInWindow){
            
            mouseTarget = .punch


        }else
        if textView.isFullFrame && textView.backingLayer.frame.contains(event.locationInWindow){
            
            mouseTarget = .text
            
        }else if cueIdTextView.isFullFrame && cueIdTextView.backingLayer.frame.contains(event.locationInWindow){
            
            mouseTarget = .cueId
            
        }else if annunciatorTextView.isFullFrame && annunciatorTextView.backingLayer.frame.contains(event.locationInWindow){
            
            mouseTarget = .annunciator
        }else if progressTextView.isFullFrame && progressTextView.backingLayer.frame.contains(event.locationInWindow){
            
            mouseTarget = .progressBar
        }
        
        switch mouseTarget {
        case .none: break
        case .text: textView.mouseDown(with: event); break
        case .cueId: cueIdTextView.mouseDown(with: event); break
        case .annunciator: annunciatorTextView.mouseDown(with: event); break
        case .punch: streamer?.mouseDown(with: event); break
        case .progressBar:progressTextView.mouseDown(with: event); break
        }
    }
    override func mouseDragged(with event: NSEvent) {
//        print("ViewController mouseDragged")
        
        switch mouseTarget {
        case .none: break
        case .text: textView.mouseDragged(with: event); break
        case .cueId: cueIdTextView.mouseDragged(with: event); break
        case .annunciator: annunciatorTextView.mouseDragged(with: event); break
        case .punch: streamer?.mouseDragged(with: event); break
        case .progressBar: progressTextView.mouseDragged(with: event); break
       }

    }
    override func mouseUp(with event: NSEvent) {
//        print("ViewController mouseUp")
        
        switch mouseTarget {
        case .none: break
        case .text: textView.mouseUp(with: event); break
        case .cueId: cueIdTextView.mouseUp(with: event); break
        case .annunciator: annunciatorTextView.mouseUp(with: event); break
        case .punch: streamer?.mouseUp(with: event); break
        case .progressBar:progressTextView.mouseUp(with: event); break
        }
        
        mouseTarget = .none

    }
    
}

