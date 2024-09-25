//
//  Streamer.swift
//  TextView
//
//  Created by Jim on 7/27/22.
//  graphics for VM15A streamers, punch, mask, hide pix
/*
       // https://medium.com/macoclock/quick-start-with-calayer-and-cabasicanimation-e3ff17ea6f11

       let globalDuration: CFTimeInterval = 2.0
       let globalRepeatCount: Float = 2.0

       // MARK: CornerRadius Animation
       let cornerAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.cornerRadius))
       cornerAnimation.fromValue = 0.0
       cornerAnimation.toValue = 20.0
       cornerAnimation.duration = globalDuration
       cornerAnimation.repeatCount = globalRepeatCount
       cornerAnimation.autoreverses = true

       // MARK: Position Animation
       let positionAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.position))
       positionAnimation.fromValue = CGPoint(x: -20, y: 100)
       positionAnimation.toValue = CGPoint(x: 280, y: 100)
       positionAnimation.duration = globalDuration
       positionAnimation.repeatCount = globalRepeatCount
       positionAnimation.autoreverses = true

       // MARK: Background Animation
       let backgroundAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.backgroundColor))
       backgroundAnimation.fromValue = NSColor.blue.cgColor
       backgroundAnimation.toValue = NSColor.green.cgColor
       backgroundAnimation.duration = globalDuration
       backgroundAnimation.repeatCount = globalRepeatCount
       backgroundAnimation.autoreverses = true

       // MARK: Bounds Animation
       let boundsAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.bounds))
       boundsAnimation.fromValue = CGRect(x: 0, y: 0, width: 20, height: 20)
       boundsAnimation.toValue = CGRect(x: 0, y: 0, width: 40, height: 40)
       boundsAnimation.duration = globalDuration
       boundsAnimation.repeatCount = globalRepeatCount
       boundsAnimation.autoreverses = true
     
       // Creation of Sublayer
       let newSublayer = CALayer()
       newSublayer.frame = CGRect(x: 80, y: 80, width: 40, height: 40)
       newSublayer.backgroundColor = NSColor.green.cgColor
       view.layer?.addSublayer(newSublayer)
       
       // from CATransaction documentation
       CATransaction.setCompletionBlock {
           
           print("completion block")
           newSublayer.removeFromSuperlayer()
       }
     
       //Apply all animations to sublayer
       CATransaction.begin()
       newSublayer.add(positionAnimation, forKey: #keyPath(CALayer.position))
       newSublayer.add(cornerAnimation, forKey: #keyPath(CALayer.cornerRadius))
       newSublayer.add(backgroundAnimation, forKey: #keyPath(CALayer.backgroundColor))
       newSublayer.add(boundsAnimation, forKey: #keyPath(CALayer.bounds))
       CATransaction.commit()
 */

import Cocoa
import AVFoundation

// 2.10.02, accessory sends
// mics are notes 94-117
// pb futz is 118
// cp futs is 119
/*
 from Changes to MIDI CC#s.ods 08/08/23
 Track Name    Original CC#    New CC#
         
 *Beeps Lvl          16          17
 *Beeps Gate         116         93
 *Mac CPU            18          18
 *GuideToBooth       22          19
 *CP Futz            104         118
 *PB Futz            88          119
 CP No Futz         105         n/a
 PB No Futz         89          n/a
 *Launchpad Dir L    80-83       94-97
 *Launchpad Dir C    96-99       102-105
 *Launchpad Dir R    112-115    110-113
 *Launchpad Comp L   84-87       98-101
 *Launchpad Comp C   100-103    106-109
 *Launchpad Comp R   116-119    114-117
 *Launchpad PB  L    84-87       98-101
 *Launchpad PB C     100-103    106-109
 *Launchpad PB R     116-119    114-117
 *Parrot Sampler Capture    14       20 CC_CAPTURE_SAMPLE
 *Fill Capture              13       21 CC_CAPTURE_FILL
 *Parrot Sampler Player     11       22 CC_PLAY_SAMPLE
         
* Zoom               20          23
* Source Connect     19          24
* video rec delay   15          0

 */
let MIDI_BEEPS_ON : [UInt8]  = [0xB0,93,127]
let MIDI_BEEPS_OFF : [UInt8] = [0xB0,93,0]
let BEEPS_DURATION = 0.100  //0.083

@objc class Streamer: NSObject {
    
    // https://stackoverflow.com/questions/14158743/alternative-of-cadisplaylink-for-mac-os-x
    var displayLink : CVDisplayLink?    // 10/17/22 we would like to measure streamer 'judder'
    
    var annunciatorTextView : TextView?

    @objc var streamerRenderer : StreamerRenderer?  // 1.3.22 Metal streamers have less judder, maybe
    var vsyncPeriod : Double = 0.016666
    // why do we have a 60hz monitor and 50 hz drawInMTKView?
//    {
//        didSet{
//
//            if(vsyncPeriod != 0.0){
//                streamerRenderer?.numStreamerFields = 2 * Int32(round(1 / vsyncPeriod))
//
//                print("numStreamerFields \(streamerRenderer?.numStreamerFields ?? -1)")
//            }
//        }
//    }
    
    // we have two cases, the video delay calibration case (0) and normal (2)
    var repeatCountBeeps = 2
    var repeatCountPunch = 2
    var punchTimer : Timer?     // Evan wants 3 MIDI messages
    var beepsTimer : Timer?    // Evan wants 3 MIDI messages
    var beepsOffTimer : Timer?    // send beeps on, wait 33 ms, send beeps off

    var view : NSView?
//    @objc var streamerColor = NSColor.white{
//        didSet{
//
//            let color = streamerColor.usingColorSpace(.genericRGB)
//
//            UserDefaults.standard.set("\(color!.redComponent)", forKey: "streamerColor_r")
//            UserDefaults.standard.set("\(color!.greenComponent)", forKey: "streamerColor_g")
//            UserDefaults.standard.set("\(color!.blueComponent)", forKey: "streamerColor_b")
//            UserDefaults.standard.set("\(color!.alphaComponent)", forKey: "streamerColor_a")
//        }
//    }
//    @objc var endBarColor : NSColor{
//        set{
//            let color = newValue.usingColorSpace(.genericRGB)
//            streamerRenderer?.endBarColor = color!
//
//        }
//        get{
//            let color : NSColor = streamerRenderer!.endBarColor
//            return color
//
//        }
//    }
    @objc var endBarColor : NSColor{
        set{
            let color = newValue.usingColorSpace(.genericRGB)
            UserDefaults.standard.setColor(color, forKey: "endBarColor")
            
        }
        get{
            if let color = UserDefaults.standard.color(forKey: "endBarColor"){
                return color
            }
            return NSColor.white
        }
    }
    @objc var streamerColor : NSColor{
        set{
            let color = newValue.usingColorSpace(.genericRGB)
            UserDefaults.standard.setColor(color, forKey: "streamerColor")
            
        }
        get{
            if let color = UserDefaults.standard.color(forKey: "streamerColor"){
                return color
            }
            return NSColor.white
        }
    }
    @objc var punchColor : NSColor{
        set{
            let color = newValue.usingColorSpace(.genericRGB)
            UserDefaults.standard.setColor(color, forKey: "punchColor")
            
        }
        get{
            if let color = UserDefaults.standard.color(forKey: "punchColor"){
                return color
            }
            return NSColor.white
        }
    }
    var player: AVAudioPlayer?
    var swiftMidi : SwiftMidi?
    
    var punchLayer = CALayer()
    var hidePixLayer = CALayer()
    var rightMaskLayer = CALayer()
    var leftMaskLayer = CALayer()
    var topMaskLayer = CALayer()
    @objc var bottomMaskLayer = CALayer()
    var blackLayer = CALayer()
    
//    var numActiveStreamers = 0
    var streamerWidthFraction = 0.010
//    var endBarFraction = 0.90   // where the end bar is
    var punchFraction = 0.333{ // punch size
        didSet{
            punchFraction = punchXFraction < 0.05 ? 0.05 : punchFraction
            punchFraction = punchXFraction > 0.95 ? 0.95 : punchFraction
            UserDefaults.standard.set("\(punchFraction)", forKey: "punchFraction")

        }
    }
    var punchXFraction = 0.5{
        didSet{
            punchXFraction = punchXFraction < 0.05 ? 0.05 : punchXFraction
            punchXFraction = punchXFraction > 0.95 ? 0.95 : punchXFraction
            UserDefaults.standard.set("\(punchXFraction)", forKey: "punchXFraction")
//            print("punchXFraction \(punchXFraction)")

        }
    }
    var punchYFraction = 0.5{    // punch location
        didSet{
            punchYFraction = punchXFraction < 0.05 ? 0.05 : punchYFraction
            punchYFraction = punchXFraction > 0.95 ? 0.95 : punchYFraction
            UserDefaults.standard.set("\(punchYFraction)", forKey: "punchYFraction")
//            print("punchYFraction \(punchYFraction)")
        }
    }
    var punchXFractionDelta = 0.0
    var punchYFractionDelta = 0.0
    var punchFractionDelta = 0.0
    
    var punchDuration = 0.1
    var isFullFrame = false{
        didSet{
            // show punch frame for dragging
            showPunchFrame()
        }
    }
    @objc var globalDuration: CFTimeInterval = 2.0
//    var qfTimer : Timer?
//    var punch2Timer : Timer?
//    var punch3Timer : Timer?
//    var timer : Timer?
//
//    var punchCtr = 0    // count the punches

    // punch images in 'assets'
    @objc var punchList : [String] = ["bugs", "marvin","foghorn","daffy","porky","batSignal"]
//    var punchImage : NSImage?
    
    //    mask vars
    @objc var topMask = 0
       {
           didSet{
               
               if topMask <= 0{ topMask = 0}
               if topMask > 255{topMask = 255 }
                    
               UserDefaults.standard.set("\(topMask)", forKey: "topMask")
               maskFromValues(topMask, bottomMask, rightMask, leftMask, transparency)

               
           }
       }
    @objc var bottomMask = 0
       {
           didSet{
               
               if bottomMask <= 0{ bottomMask = 0}
               if bottomMask > 255{bottomMask = 255 }

               UserDefaults.standard.set("\(bottomMask)", forKey: "bottomMask")
               maskFromValues(topMask, bottomMask, rightMask, leftMask, transparency)

               
           }
       }
    @objc var leftMask = 0
       {
           didSet{
               
               if leftMask <= 0{ leftMask = 0}
               if leftMask > 255{leftMask = 255 }

               UserDefaults.standard.set("\(leftMask)", forKey: "leftMask")
               maskFromValues(topMask, bottomMask, rightMask, leftMask, transparency)

               
           }
       }
    @objc var rightMask = 0
       {
           didSet{
               
               if rightMask <= 0{ rightMask = 0}
               if rightMask > 255{rightMask = 255 }

               UserDefaults.standard.set("\(rightMask)", forKey: "rightMask")
               maskFromValues(topMask, bottomMask, rightMask, leftMask, transparency)
//               setPunchLayer(next: false)

               
           }
       }
    @objc var transparency = 0
       {
           didSet{
               
               if transparency <= 0{ transparency = 0}
               if transparency > 255{transparency = 255 }

               UserDefaults.standard.set("\(transparency)", forKey: "transparency")
               maskFromValues(topMask, bottomMask, rightMask, leftMask, transparency)

               
           }
       }
       
       @objc var punchIndex = 0{
           didSet{
               
               punchIndex %= punchList.count
               UserDefaults.standard.set("\(punchIndex)", forKey: "punchIndex")
               setPunchLayer()

           }
       }
    
    @objc var fadeSeconds = 1.0
    @objc func fadeToBlack(_ black : Bool, _ duration : Double){
        
//        print("fadeToBlack \(black) \(duration)")
        
        // TextWindowServer_V2 function
        // a black layer at the same z as the mask
        // fade to picture (black layer fades out)
//        self.view?.window?.level = overlayWindowLevel//.floating
//        self.view?.window?.orderFrontRegardless()   // put in front of PT
        
        var black = black
        if(hidePix){
            black = true    // always hide pix
        }
        
        if blackLayer.superlayer == nil{
            
            blackLayer.frame.origin = CGPoint(x: 0.0, y: 0.0)
            blackLayer.backgroundColor = NSColor.black.cgColor
            blackLayer.zPosition = MASK_Z
            blackLayer.opacity = 0.0    // transparent when added to superlayer
            
            view!.layer?.addSublayer(blackLayer)
        }
        let size = view!.window?.frame.size
        blackLayer.frame.size = size!
        
//        print("\(black) \(blackLayer.opacity) \(duration)")
        // fade once only
        if blackLayer.opacity == (black ? 1.0 : 0.0) {
//            print("fadeToBlack once only")
            return
        }

        blackLayer.opacity = black ? 1.0 : 0.0  // value after animation

        let anim = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        anim.fromValue = black ? 0.0 : 1.0
        anim.toValue = black ? 1.0 : 0.0// sets how quickly the image fades out
        anim.duration = duration
        anim.isRemovedOnCompletion = true

        // from CATransaction documentation
        CATransaction.setCompletionBlock {
//            print("blackLayer completion block")
//            if self.blackLayer.opacity == 0.0{
//                self.blackLayer.removeFromSuperlayer()
//            }
//
        }
        
        
        if(duration != 0.0){
            CATransaction.begin()
            
            blackLayer.removeAllAnimations()
            blackLayer.add(anim, forKey: #keyPath(CALayer.opacity))
            CATransaction.commit()
        }

    }
    @objc var hidePix = false{
        didSet{
            
            // 2.10.02 set indicators here
            let aleDelegate = NSApplication.shared.delegate as? AleDelegate
            
            aleDelegate?.setLEDForUnitID(9, 33, hidePix)
            aleDelegate?.xKey.setLEDForUnitID(8, 10+80, hidePix ? 1 : 0)

            if hidePix{
                
                self.fadeToBlack(true, 0.0)
                
//                hidePixLayer.contents = NSImage(imageLiteralResourceName: "WarnerBros-Lot")
//                hidePixLayer.frame.origin = CGPoint(x: 0.0, y: 0.0) // because we are relative to our window, not the screen
//                hidePixLayer.frame.size = (view!.window?.frame.size)!
//                hidePixLayer.backgroundColor = NSColor.black.cgColor
//                hidePixLayer.zPosition = HIDEPIX_Z
//                view!.layer?.addSublayer(hidePixLayer)
//
//                CATransaction.begin()
//                hidePixLayer.removeAllAnimations()
//                CATransaction.commit()
                
            }else{
                self.fadeToBlack(false, 0.0)

//                hidePixLayer.removeFromSuperlayer()
            }
        }

    }
    
    // see https://stackoverflow.com/questions/32446978/swift-capture-keydown-from-nsviewcontroller

    init(_ view : NSView){
        super.init()
        print("Streamer init")
        
        self.view = view
        self.view?.window?.level = overlayWindowLevel
        
        swiftMidi = SwiftMidi(self, "Beeps", .OUT_ONLY)
        
        // register defaults
        
        var dict : [String : Any]?
        
        do{
            dict = [
                "punchFraction" : "\(punchFraction)",
                "punchXFraction" : "\(punchXFraction)",
                "punchYFraction" : "\(punchYFraction)",
                "topMask" : "\(topMask)",
                "leftMask" : "\(leftMask)",
                "bottomMask" : "\(bottomMask)",
                "rightMask" : "\(rightMask)",
                "transparency" : "\(transparency)",
                "punchIndex" : "\(punchIndex)",
                "streamerColor" : try NSKeyedArchiver.archivedData(withRootObject: NSColor.white, requiringSecureCoding: false),
                "endBarColor" : try NSKeyedArchiver.archivedData(withRootObject: NSColor.white, requiringSecureCoding: false),
                "punchColor" : try NSKeyedArchiver.archivedData(withRootObject: NSColor.white, requiringSecureCoding: false),
                "fadeSeconds" : Double(2.0),
                "audioBeep" : false,
                "fromImage" : false
            ]
        }catch{
            
        }
        
        if let dict = dict{
            let defaults = UserDefaults.standard
            defaults.register(defaults: dict)
        }
        
        recallDefaults()
        
//        maskFromValues(topMask, bottomMask, rightMask, leftMask, transparency)
        
        // remote beeps off, Evan paranoia
        let msg : [UInt8] = MIDI_BEEPS_OFF   // MIDI note off
        let data = NSData(bytes: msg, length: 3)
        swiftMidi?.midiClient?.midiTx(data)

        // load the beeps player
        loadBeepsPlayer()
        fadeToBlack(false, 0.0) // initialize black layer, set it to transparent

    }
    func loadBeepsPlayer(){
        
        // https://developer.apple.com/library/archive/qa/qa1913/_index.html
        // The NSDataAsset class allows you to access an object from a data set stored in an asset catalog
        if let asset = NSDataAsset(name:"beeps"){
     
           do {
                 // Use NSDataAsset's data property to access the audio file stored in Sound.
                player = try AVAudioPlayer(data:asset.data, fileTypeHint:"aif")
               player?.delegate = self
                player?.prepareToPlay()
           } catch let error as NSError {
                 print(error.localizedDescription)
           }
        }
    }
    func recallDefaults(){
        
        let defaults = UserDefaults.standard
        
        if let s = defaults.string(forKey: "punchFraction"){
            
            punchFraction = Double(s)!
        }
        if let s = defaults.string(forKey: "punchXFraction"){
            
            punchXFraction = Double(s)!
        }
        if let s = defaults.string(forKey: "punchYFraction"){
            
            punchYFraction = Double(s)!
        }
        if let s = defaults.string(forKey: "topMask"){
            
            topMask = Int(s)!
        }
        if let s = defaults.string(forKey: "leftMask"){
            
            leftMask = Int(s)!
        }
        if let s = defaults.string(forKey: "bottomMask"){
            
            bottomMask = Int(s)!
        }
        if let s = defaults.string(forKey: "rightMask"){
            
            rightMask = Int(s)!
        }
        if let s = defaults.string(forKey: "transparency"){
            
            transparency = Int(s)!
        }
        if let s = defaults.string(forKey: "punchIndex"){
            
            punchIndex = Int(s)!
//            setPunchLayer(next:false)

        }
        
    }
    // MARK: ---------- vsync callback ---------------
    // 10/17/22 we want to measure streamer 'judder'
    // see 'QRReader' for starting code
    
//    static let vSyncArraySize = 256
    static var vCtr = 0
//    static var vSyncArray = Array(repeating: 0.0, count: vSyncArraySize)
    
    func getNominalOutputVideoRefreshPeriod(_ displayID: CGDirectDisplayID) -> Double{
        
        if displayLink != nil{CVDisplayLinkStop(displayLink!)}
        
        let _ = CVDisplayLinkCreateWithCGDisplay(displayID, &displayLink)
        CVDisplayLinkSetOutputCallback(displayLink!,Streamer.renderCallback,Unmanaged.passUnretained(self).toOpaque())
        
        let t = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(displayLink!)
        
        let period = Double(t.timeValue)/Double(t.timeScale)
        
//        print("vsync period \(period)")

        return period;
    }
    
    func startRenderCallback(_ displayID: CGDirectDisplayID){
        
        if displayLink != nil{CVDisplayLinkStop(displayLink!)}
        
        let _ = CVDisplayLinkCreateWithCGDisplay(displayID, &displayLink)
        CVDisplayLinkSetOutputCallback(displayLink!,Streamer.renderCallback,Unmanaged.passUnretained(self).toOpaque())
        
        CVDisplayLinkStart(displayLink!)
        
    }
    
    func displaySlip(_ slip : Int){
        
//        print("\(slip)")
        // monitor matrix, delta, in 'Test items' box
        let slip = slip % 60
        UserDefaults.standard.set(slip, forKey: "slip")
    }

    static let renderCallback : CVDisplayLinkOutputCallback = {(displayLink : CVDisplayLink
                                                                ,inNow : UnsafePointer<CVTimeStamp>
                                                                ,inOutputTime : UnsafePointer<CVTimeStamp>
                                                                ,flagsIn : UInt64
                                                                ,flagsOut : UnsafeMutablePointer<UInt64>
                                                                ,displayLinkContext : Optional<UnsafeMutableRawPointer>)-> Int32 in
        
        // 04/24/23 logging vsyncs shows that Mac Mini M2 never misses one, the jitter is low
        
        Streamer.vCtr += 1
        Streamer.vCtr %= 60 //vSyncArraySize
        
        if(Streamer.vCtr == 0){
            
            let s : Streamer = Unmanaged.fromOpaque(displayLinkContext!).takeUnretainedValue()
            
                        DispatchQueue.main.async {
                            s.streamerRenderer!.streamerDidFinish = false
                            s.displaySlip(s.streamerRenderer!.drawCounter)
                        }
        }
        
        return 0
    }

    // MARK: --------- utilities ------------
    
//    var streamerLayer : CALayer?   // debug temp for judder measurement
    // an array of CALayers so that we can cancel streamers
//    var streamerArray : Array<CALayer> = Array<CALayer>()
    
    @objc func cancelAllStreamers(){
        
        annunciatorTextView?.text = ""  // annunciator blank text
 
        CATransaction.begin()
        punchLayer.removeAllAnimations()
        punchLayer.removeFromSuperlayer()
        CATransaction.commit()
        
        // cancel metal streamers
        
        streamerRenderer?.cancelStreamers()
        
        // cancel punch

        CATransaction.begin()
        punchLayer.removeAllAnimations()
        punchLayer.removeFromSuperlayer()
        punchTimer?.invalidate()
        CATransaction.commit()
                
        // cancel beeps
        
//        let msg : [UInt8] = MIDI_BEEPS_OFF   // MIDI note off
//        let data = NSData(bytes: msg, length: 3)
//        swiftMidi?.midiClient?.midiTx(data)

        beepsTimer?.invalidate()
        player?.stop()      // pause the player
        loadBeepsPlayer()   // reload beeps, it is paused and hasn't finished
        
    }
    func beepOnOff(){
        
        // 2.10.02 MIDI beeps: send MIDI_BEEPS_ON, wait a frame, send MIDI_BEEPS_OFF
        let msg : [UInt8] = MIDI_BEEPS_ON
        let data = NSData(bytes: msg, length: 3)
        swiftMidi?.midiClient?.midiTx(data)
        
        beepsOffTimer?.invalidate()
        var beepsDuration = UserDefaults.standard.double(forKey: "beepsDuration")
        if beepsDuration > 0.120{
            beepsDuration = 0.120
            UserDefaults.standard.set(beepsDuration, forKey: "beepsDuration")            
        }
        if beepsDuration < 0.020{
            beepsDuration = 0.020
            UserDefaults.standard.set(beepsDuration, forKey: "beepsDuration")
        }
        beepsOffTimer = Timer.scheduledTimer(timeInterval: beepsDuration, target: self, selector: #selector(beepsOffTimerService), userInfo: nil, repeats: false)

    }
    @objc func beepsOffTimerService(){
        
        let msg : [UInt8] = MIDI_BEEPS_OFF
        let data = NSData(bytes: msg, length: 3)
        swiftMidi?.midiClient?.midiTx(data)
    }
    
    @objc func triggerBeeps(_ repeatCount: NSInteger){
        
        if(streamerRenderer?.streamerIsActive() == true){
            return;
        }
        repeatCountBeeps = repeatCount
        
        let audioBeep = UserDefaults.standard.bool(forKey: "audioBeep")
        let duration = globalDuration / 3.0 // time between punches/beeps

        if audioBeep{
            
            player?.play()  // 3 beeps in 1 file
            
            if repeatCount == 0{
                // cancel the audio player after 1 beep
                // we ignore the repeatCount == 1 case
                beepsTimer?.invalidate()
                beepsTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(beepsTimerService), userInfo: nil, repeats: true)
           }
            
        }else{
            
            // send MIDI note 120 to RemotePop, our external beeps generator
            // FIXME: 11/05/22 remotePop on the PT computer has serious delays,
            // but RemotePop on a different computer doesn't.
            self.beepOnOff() // send beep on, wait 33 ms, send beep off
            // 0 beeps cancels the beep on timeout, need this to stop audio beep
            
            beepsTimer?.invalidate()
            beepsTimer = Timer.scheduledTimer(timeInterval: duration, target: self, selector: #selector(beepsTimerService), userInfo: nil, repeats: true)
        }

        
    }
    @objc func beepsTimerService(){
        
        repeatCountBeeps -= 1
        
        if repeatCountBeeps < 0{
            
            // cancel beeps
            
//            let msg : [UInt8] = MIDI_BEEPS_OFF   // MIDI note off
//            let data = NSData(bytes: msg, length: 3)
//            swiftMidi?.midiClient?.midiTx(data)

            player?.stop()      // pause the player
            loadBeepsPlayer()   // reload beeps, it is paused and hasn't finished

        }else{
            
            self.beepOnOff()
        }

        if repeatCountBeeps <= 0{
            
            beepsTimer?.invalidate()
            
        }

    }
//    @objc func triggerPunch(_ repeatCount: NSInteger, _ delaySeconds : Double){
//
//        // we have 2 cases: a single punch, for calibrating video delay,
//        // and a multiple punch. Streamers and punch may be delayed by PT 'Video Sync Offset'.
//        repeatCountPunch = repeatCount
//
//        if delaySeconds == 0.0{
//
//            showPunch(repeatCountPunch)
//
//        }else{
//
//            punchTimer?.invalidate()
//            punchTimer = Timer.scheduledTimer(timeInterval: delaySeconds, target: self, selector: #selector(punchTimerService), userInfo: nil, repeats: false)
//        }
//
//    }
//    @objc func punchTimerService(){
//
//        triggerPunch(2)
//
//    }
    @objc func triggerPunch(_ repeatCount: NSInteger){
        
        // return if already active
//        if endBarLayer.superlayer != nil{return}
        if(streamerRenderer?.streamerIsActive() == true){
            return;
        }
        
        let duration = globalDuration / 3.0 // time between punches
        
        punchLayer.removeFromSuperlayer()
        
        // CAAnimation, punch spacing and fade timing
        
        let anim = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        anim.fromValue = 1.0
        anim.toValue = -2.0 // sets how quickly the image fades out
        anim.duration = duration    // time between punches
        anim.autoreverses = false
        anim.repeatCount = Float(repeatCount) + 0.5   // .5 lets us see the last punch animation
        punchLayer.opacity = -2.0   // be transparent when finished

        // from CATransaction documentation
        CATransaction.setCompletionBlock {
//                print("punch completion block")
            self.punchLayer.removeFromSuperlayer()
            self.punchBusy = false
        }

        CATransaction.begin()
        punchLayer.removeAllAnimations()
        punchLayer.add(anim, forKey: #keyPath(CALayer.opacity))
        CATransaction.commit()
        
        view!.layer?.addSublayer(punchLayer)
    }

    @objc func triggerStreamer(_ color: NSColor, _ withBeeps : Bool){
        
//        self.view?.window?.level = overlayWindowLevel
        
        if(withBeeps){
            
            triggerBeeps(2) // repeat count
            
            let enPunch = UserDefaults.standard.bool(forKey: "enPunch")

            if(enPunch){
                
                triggerPunch(2)
                
            }
            
        }
        // after punch trigger so that streamerIsActive return value is right
        //enStreamer
        // github tickler
        let enStreamer = UserDefaults.standard.bool(forKey: "enStreamer")
        
        let aleDelegate = NSApplication.shared.delegate as? AleDelegate
        let inhStreamerInPb = UserDefaults.standard.bool(forKey: "inhibitStreamerInPlayback") && ((aleDelegate?.matrixWindowController.rehRecPb)! == MODE_CONTROL_PLAYBACK)

        if(enStreamer && !inhStreamerInPb){
            streamerRenderer?.addStreamer(color)    // 2.00.00 Metal GPU rendering of streamers
        }
    }
   @objc func triggerStreamer(_ color: NSColor){
       
       let enPunch = UserDefaults.standard.bool(forKey: "enPunch")
       let enBeeps = UserDefaults.standard.bool(forKey: "enBeeps")
       let enStreamer = UserDefaults.standard.bool(forKey: "enStreamer")

       if(enStreamer){
           streamerRenderer?.addStreamer(color)    // 2.00.00 Metal GPU rendering of streamers
       }
       
       if(enPunch){
           triggerPunch(2)
           //triggerPunch(2,0.0) // repeat count, delay
       }
       if(enBeeps){
           triggerBeeps(2) // repeat count
       }
    }
    
//    @objc func triggerStreamer(_ color: NSColor, _ withBeeps : Bool){
//
//
//        // myWindowLevel
//        self.view?.window?.level = overlayWindowLevel//.floating
////        self.view?.window?.level = NSWindow.Level(rawValue:  Int(FLOATING_WINDOW_LEVEL));  // above ProTools
//
////        self.view?.window?.orderFrontRegardless()   // 2.00.00 10/30/22 PT is constantly taking focus every few seconds
//
//        // the streamers in the editor window don't have beeps, cues for Foley
//        if(withBeeps){
//            showPunch(false)    // not forced, checks 'enPunch'
//        }
//
//        if UserDefaults.standard.bool(forKey: "enStreamer") == false{
//            return;
//        }
//
//        streamerRenderer?.addStreamer(color,0)    // 2.00.00 Metal GPU rendering of streamers
//
////        let yPos = view!.frame.size.height / 2.0
////        let xPos = view!.frame.size.width * endBarFraction;
////
////        // MARK: Position Animation
////        let positionAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.position))
////        positionAnimation.fromValue = CGPoint(x: 0, y: yPos)
////        positionAnimation.toValue = CGPoint(x: xPos, y: yPos)
////        positionAnimation.duration = globalDuration
//////        positionAnimation.repeatCount = 0 // default is 0
////        positionAnimation.autoreverses = false
////        // default for .isRemovedOnCompletion is true, and we still get a completion block
////
////        // Creation of Sublayer
////        // tried CAMetalLayer, does that speed things up?
////        let newSublayer = CALayer()//CAMetalLayer()
//////        newSublayer.delegate = self   // no calls to draw(), not useful
////
////        // when the animation stops, this is where the layer is
////        // not important here but it is with punch
////        // see https://stackoverflow.com/questions/13888926/cannot-get-current-position-of-calayer-during-animation
//////        newSublayer.position = positionAnimation.toValue as! CGPoint
////
////        var streamerWidth = streamerWidthFraction * view!.frame.size.width
////        if streamerWidth < 1.0{
////            streamerWidth = 1.0
////        }
////
////        newSublayer.frame = CGRect(x: -streamerWidth, y: 0, width: streamerWidth, height: view!.frame.size.height)
////        newSublayer.backgroundColor = color.cgColor
////        newSublayer.zPosition = STREAMER_Z   // above the endbar
////
////        // 2.00.00 10/30/22 we have seen judder
////        // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/ImprovingAnimationPerformance/ImprovingAnimationPerformance.html#//apple_ref/doc/uid/TP40004514-CH9-SW1
////        newSublayer.isOpaque = true // faster animation?
////        view?.layerContentsRedrawPolicy = .onSetNeedsDisplay    // faster animation?
////        // CAMetalLayer has a var for syncing to vertical sync
//////        newSublayer.displaySyncEnabled = true   // CAMetalLayer defaults to true
////        view!.layer?.addSublayer(newSublayer)
////        streamerArray.append(newSublayer)
////
//////        showEndBar()    // under the streamer
////
////        // trying to characterize judder, using vsync callback 'renderCallback'
////        // note we can only have one streamer going for testing
//////        streamerLayer = newSublayer // renderCallback needs to access this for judder measure
////
////        // from CATransaction documentation
////        CATransaction.setCompletionBlock { [self] in
////
////            newSublayer.removeFromSuperlayer()
////            // this is the only place that items are removed from streamerArray
////            self.streamerArray.remove(at: self.streamerArray.index(of: newSublayer)!)
//////            self.hideEndBar()
////        }
////
////        //Apply all animations to sublayer
////        CATransaction.begin()
////        newSublayer.add(positionAnimation, forKey: #keyPath(CALayer.position))
////        CATransaction.commit()
//
//
//    }
    
    func drawPunch(_ color : NSColor) -> NSImage{
        
        var size = view!.frame.size
        size.height *= punchFraction
        size.width = size.height    // a square for the image

        let img = NSImage(size: size)
        let rep : NSBitmapImageRep = NSBitmapImageRep(bitmapDataPlanes: nil
                                                      ,pixelsWide: Int(size.width)
                                                      ,pixelsHigh: Int(size.height)
                                                      ,bitsPerSample: 8
                                                      ,samplesPerPixel: 4
                                                      ,hasAlpha: true
                                                      ,isPlanar: false
                                                      ,colorSpaceName: NSColorSpaceName.calibratedRGB
                                                      ,bytesPerRow: 0
                                                      ,bitsPerPixel: 0)!
        
        img.addRepresentation(rep)
        
        img.lockFocus()
        
        let ctx : CGContext = NSGraphicsContext.current!.cgContext
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: NSRect(x: 0, y: 0, width: size.width, height: size.height))
        
        img.unlockFocus()

        return img
    }
     
    @objc func setPunchLayer(/*next : Bool*/){
        
        var image : NSImage?
        
        CATransaction.begin()
        punchLayer.removeAllAnimations()
        CATransaction.commit()
        
        // TODO: select from assets or draw with a color
        if UserDefaults.standard.bool(forKey: "fromImage"){
            
            image = NSImage(imageLiteralResourceName: punchList[punchIndex]) // we get an execution error if the file does not exist, but can't do a do/catch
        }else{
            
            image = drawPunch(punchColor)
        }

        if let image = image,
           let window = view?.window{
            
            punchLayer.contents = image
            punchLayer.backgroundColor = NSColor.clear.cgColor
            punchLayer.zPosition = PUNCH_Z
            
            let rectSize = window.frame.size

            var diameter = rectSize.height * (punchFraction + punchFractionDelta)   // a square for the image
            
            diameter = diameter < 100.0 ? 100.0 : diameter  // clip to minimum size
            
            var xPos = (rectSize.width * (punchXFraction + punchXFractionDelta)) - diameter / 2.0
            var yPos = (rectSize.height * (punchYFraction + punchYFractionDelta)) - diameter / 2.0
            let xMax = Double(rectSize.width) - diameter
            let yMax = Double(rectSize.height) - diameter
            
            // onscreen
            xPos = xPos < 0.0 ? 0.0 : xPos; xPos = xPos > xMax ? xMax : xPos
            yPos = yPos < 0.0 ? 0.0 : yPos; yPos = yPos > yMax ? yMax : yPos
            
            punchLayer.frame = CGRect(x: xPos, y: yPos, width: diameter, height: diameter)

        }
        
//        if next{
//            showPunch(true)   // force punch, ignores 'enPunch'
//        }
                
    }
    
    var punchBusy = false
    
    @objc func testFunction(){
        
        // 11/21/22 looking for the IAC delay problem
        // this is as simple as it can be
        // why are beeps delayed when on this computer, but not on
        // a different computer
        
        // this routine from OSC front panel
        // 11/21/22
        // 08:39:04.916 tx beeps noteOn
        // 08:39:23.765 tx beeps noteOn
        // 08:40:33.736 tx beeps noteOn
        // 08:39:05.372 noteOn beeps    .456 delay
        // 08:39:24.233 noteOn beeps    .468 delay
        // 08:40:34.204 noteOn beeps    .468 delay
        
        // 11/22/22
        /* why is this working today, but not yesterday?
         appendToLog 07:36:48.021 tx beeps noteOn
         appendToLog 07:36:50.256 tx beeps noteOn
         appendToLog 07:36:52.315 tx beeps noteOn
         
         07:36:48.041 noteOn beeps  .020
         07:36:50.271 noteOn beeps  .015
         07:36:52.329 noteOn beeps  .014


         */
        
        
        let msg : [UInt8] = MIDI_BEEPS_ON
        let data = NSData(bytes: msg, length: 3)
        swiftMidi?.midiClient?.midiTx(data)
        self.appendToLog("tx beeps noteOn", Date())
        
    }

//    @objc func showPunchx(_ force : Bool){
//
//        // return if already active
////        if endBarLayer.superlayer != nil{return}
//        if(streamerRenderer?.streamerIsActive() == true){
//            return;
//        }
//
//        let enPunch = UserDefaults.standard.bool(forKey: "enPunch")
//        let enBeeps = UserDefaults.standard.bool(forKey: "enBeeps")
//        let audioBeep = UserDefaults.standard.bool(forKey: "audioBeep")
//
//        if punchBusy || !force && !enPunch && !enBeeps{return}
//
//        punchBusy = true
//
//        let duration = globalDuration / 3.0 // time between punches
//
//        if enBeeps || force{    // files are 3 beeps
//
//            if audioBeep{
//
//                player?.play()  // 3 beeps in 1 file
//            }else{
//
//                // send MIDI note 120 to RemotePop, our external beeps generator
//                // FIXME: 11/05/22 remotePop on the PT computer has serious delays,
//                // but RemotePop on a different computer doesn't.
//                let msg : [UInt8] = MIDI_BEEPS_ON
//                let data = NSData(bytes: msg, length: 3)
//                swiftMidi?.midiClient?.midiTx(data)
//
////                self.appendToLog("beeps MIDI", Date())
//
//                // Evan wants 3 MIDI messages
//                punchTimer?.invalidate(); punchTimer2?.invalidate()
//                punchTimer = Timer.scheduledTimer(timeInterval: duration, target: self, selector: #selector(punchTimerService), userInfo: nil, repeats: false)
//                punchTimer2 = Timer.scheduledTimer(timeInterval: 2 * duration, target: self, selector: #selector(punchTimerService), userInfo: nil, repeats: false)
//            }
//
//
//        }  // 3 beeps
//
//        punchLayer.removeFromSuperlayer()
//
//        if enPunch || force{
//
//            // CAAnimation, punch spacing and fade timing
//
//            let anim = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
//            anim.fromValue = 1.0
//            anim.toValue = -2.0 // sets how quickly the image fades out
//            anim.duration = duration    // time between punches
//            anim.autoreverses = false
//            anim.repeatCount = 2.5      // .5 lets us see the last punch animation
//            punchLayer.opacity = -2.0   // be transparent when finished
//
//            // from CATransaction documentation
//            CATransaction.setCompletionBlock {
////                print("punch completion block")
//                self.punchLayer.removeFromSuperlayer()
//                self.punchBusy = false
//            }
//
//            CATransaction.begin()
//            punchLayer.removeAllAnimations()
//            punchLayer.add(anim, forKey: #keyPath(CALayer.opacity))
//            CATransaction.commit()
//
//            view!.layer?.addSublayer(punchLayer)
//
//        }   // 3 punches
//    }
    func appendToLog(_ msg : String, _ date : Date){
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .medium
        dateFormatter.dateStyle = .none
        dateFormatter.dateFormat = "HH:mm:ss"
        
        let t = dateFormatter.string(from: date)
        let ms = Int(date.timeIntervalSince1970 * 1000) % 1000
        
        let str = "\(t).\(String(format: "%03ld", ms)) \(msg)"
        
        print("appendToLog \(str)")
    }
    func showPunchFrame(){
        
        // remove previous layer (hide punch when not opqaque)
        self.punchLayer.removeFromSuperlayer()

        if isFullFrame{
            // show the punch frame for dragging
//            setPunchLayer(next: false)
            setPunchLayer()

            CATransaction.begin()
            punchLayer.removeAllAnimations()   // no animations
            CATransaction.commit()
            
            view?.layer?.addSublayer(punchLayer)

        }
    }
    
    var punchDate = Date()

//    func showEndBar(){
//
////        numActiveStreamers += 1
////        print("showEndBar")
//
//        if endBarLayer.superlayer == nil{
//
//            // first streamer, show end bar
//            // Creation of Sublayer
//            var streamerWidth = streamerWidthFraction * view!.frame.size.width
//            if streamerWidth < 1.0{
//                streamerWidth = 1.0
//            }
//
//            let xPos = (view!.frame.size.width * endBarFraction) - (streamerWidth / 2.0)
//
////            endBarLayer.frame = CGRect(x: xPos, y: 0, width: streamerWidth, height: view!.frame.size.height)
////            endBarLayer.backgroundColor = endBarColor.cgColor
////            endBarLayer.zPosition = ENDBAR_Z
//            view!.layer?.addSublayer(endBarLayer)
//
//            // https://stackoverflow.com/questions/5833488/how-to-disable-calayer-implicit-animations
//            CATransaction.begin()
////            CATransaction.setDisableActions(true) // to disable particular animations using keys
//
//            endBarLayer.removeAllAnimations()   // end bar has no animations, easier than using multiple keys
//            CATransaction.commit()
//
//            // enable vsync callback for the first streamer, looking at judder
////            if displayLink != nil{CVDisplayLinkStart(displayLink!)} // TODO: 2.00.00 debug temp
//
//
//        }
//
//
//    }
//    func hideEndBar(){
//
////        numActiveStreamers -= 1
////        print("removeEndBar \(numActiveStreamers)")
//
//        if /*numActiveStreamers*/streamerArray.count == 0{
//            // last streamer, remove end bar
//            endBarLayer.removeFromSuperlayer()
//
//            // disable vsync callback
////            if displayLink != nil{CVDisplayLinkStop(displayLink!)}  // TODO: 2.00.00 debug temp
//        }
//
//    }

    func maskFromValues(){
        maskFromValues(topMask,bottomMask,rightMask,leftMask,transparency)
    }
    func maskFromValues(_ top : Int,_ bottom : Int,_ right : Int,_ left : Int,_ alpha : Int){
        
        // inputs are 0-255
        // MASK_Z
        rightMaskLayer.removeFromSuperlayer()
        leftMaskLayer.removeFromSuperlayer()
        topMaskLayer.removeFromSuperlayer()
        bottomMaskLayer.removeFromSuperlayer()
        
        var maskWidthInPixels = 0.0
        var maskHeightInPixels = 0.0
        guard let size = view!.window?.frame.size else{
            return
        }
        
        let a = 1.0 - Double(alpha) / 256.0
        let bgColor = NSColor.black.usingColorSpace(.genericRGB)?.withAlphaComponent(a)

        maskWidthInPixels = size.width * Double(left) / 256.0
        leftMaskLayer.frame.origin = CGPoint(x: 0.0, y: 0.0)
        leftMaskLayer.frame.size.height = size.height
        leftMaskLayer.frame.size.width = maskWidthInPixels
        leftMaskLayer.backgroundColor = bgColor?.cgColor
        leftMaskLayer.zPosition = MASK_Z
                
        maskWidthInPixels = size.width * Double(right) / 256.0
        rightMaskLayer.frame.size.width = maskWidthInPixels
        rightMaskLayer.frame.origin = CGPoint(x: size.width - maskWidthInPixels, y: 0.0)
        rightMaskLayer.frame.size.height = size.height
        rightMaskLayer.backgroundColor = bgColor?.cgColor
        rightMaskLayer.zPosition = MASK_Z
        
        // mask does not overlay leftMaskLayer or rightMaskLayer, or we get 2 alphas
        maskHeightInPixels = size.height * Double(bottom) / 256.0
        bottomMaskLayer.frame.origin = CGPoint(x: leftMaskLayer.frame.size.width, y: 0.0)
        bottomMaskLayer.frame.size.height = maskHeightInPixels
        bottomMaskLayer.frame.size.width = size.width - leftMaskLayer.frame.size.width - rightMaskLayer.frame.size.width
        bottomMaskLayer.backgroundColor = bgColor?.cgColor
        bottomMaskLayer.zPosition = MASK_Z

        
        // mask does not overlay leftMaskLayer or rightMaskLayer, or we get 2 alphas
        maskHeightInPixels = size.height * Double(top) / 256.0
        topMaskLayer.frame.size.height = maskHeightInPixels
        topMaskLayer.frame.origin = CGPoint(x: leftMaskLayer.frame.size.width, y: size.height - maskHeightInPixels)
        topMaskLayer.frame.size.width = size.width  - leftMaskLayer.frame.size.width - rightMaskLayer.frame.size.width
        topMaskLayer.backgroundColor = bgColor?.cgColor
        topMaskLayer.zPosition = MASK_Z
        
        if left > 0{
            
            view!.layer?.addSublayer(leftMaskLayer)
            
            CATransaction.begin()
            leftMaskLayer.removeAllAnimations()
            CATransaction.commit()

        }
        if bottom > 0{
            
            view!.layer?.addSublayer(bottomMaskLayer)
            
            CATransaction.begin()
            bottomMaskLayer.removeAllAnimations()
            CATransaction.commit()

        }
        if right > 0{
            
            view!.layer?.addSublayer(rightMaskLayer)
            
            CATransaction.begin()
            rightMaskLayer.removeAllAnimations()
            CATransaction.commit()

        }
        if top > 0{
            
            view!.layer?.addSublayer(topMaskLayer)
            
            CATransaction.begin()
            topMaskLayer.removeAllAnimations()
            CATransaction.commit()
        }
        
    }
    
    func hidePix(_ hidePix : Bool){
        
        if hidePix{
            
            hidePixLayer.contents = NSImage(imageLiteralResourceName: "WarnerBros-Lot")
            hidePixLayer.frame.origin = CGPoint(x: 0.0, y: 0.0) // because we are relative to our window, not the screen
            hidePixLayer.frame.size = (view!.window?.frame.size)!
            hidePixLayer.backgroundColor = NSColor.black.cgColor
            hidePixLayer.zPosition = HIDEPIX_Z
            view!.layer?.addSublayer(hidePixLayer)
            
            CATransaction.begin()
            hidePixLayer.removeAllAnimations()
            CATransaction.commit()

        }else{
            hidePixLayer.removeFromSuperlayer()
        }

    }
    //MARK: ------- mouse ----------
    
    var dragStart : NSPoint?
    var dragEnd : NSPoint?

    func mouseDown(with event: NSEvent){
        
        dragStart = event.locationInWindow
        dragEnd = event.locationInWindow
        
        // check for option, control, command, shift keys
        // https://stackoverflow.com/questions/32446978/swift-capture-keydown-from-nsviewcontroller
        switch NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask){
            
        case [.control]:
            // popup menu?
            let cp = NSColorPanel.shared
            cp.setTarget(self)
            cp.setAction(#selector(colorDidChange(sender:)))
            cp.makeKeyAndOrderFront(self)
//            cp.continuous = true
            break
        case [.option]:
            // resize
            NSCursor.resizeLeftRight.set()
            break
//        case [.command]:
//            break
//        case [.control,.option]:    // multi-key
//            break
        default:
            NSCursor.openHand.set() // window is being dragged
            break
        }
        

    }
    func mouseDragged(with event: NSEvent){
        
        dragEnd = event.locationInWindow
        
        // check for option, control, command, shift keys
        // https://stackoverflow.com/questions/32446978/swift-capture-keydown-from-nsviewcontroller
        switch NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask){
            
        case [.control]:
            // popup menu, drag does nothing
            break
        case [.option]:
            // resize
            NSCursor.resizeLeftRight.set()
            
            punchFractionDelta = (dragEnd!.x - dragStart!.x) / (self.view?.frame.size.width)!
            showPunchFrame()
            
            break
        default:
            NSCursor.openHand.set() // window is being dragged
            
            punchXFractionDelta = (dragEnd!.x - dragStart!.x) / (self.view?.frame.size.width)!
            punchYFractionDelta = (dragEnd!.y - dragStart!.y) / (self.view?.frame.size.height)!
            
            showPunchFrame()
            
            break
        }

    }
    func mouseUp(with event: NSEvent){
        
        NSCursor.arrow.set()    // drag complete
        // save drag result
        punchXFraction += punchXFractionDelta; punchXFractionDelta = 0.0
        punchYFraction += punchYFractionDelta; punchYFractionDelta = 0.0
        punchFraction += punchFractionDelta; punchFractionDelta = 0.0
        
        dragEnd = nil
        dragStart = nil
    }
    @objc func colorDidChange(sender:AnyObject) {
        if let cp = sender as? NSColorPanel {
            print("streamer colorDidChange")
            punchColor = cp.color
            showPunchFrame()
        }
    }

}
//MARK: ------- CAAnimationDelegate ----------
extension Streamer : CAAnimationDelegate{
    func animationDidStart(_ anim: CAAnimation){
        print("animationDidStart \(anim)")
    }
    func animationDidStop(_ anim: CAAnimation,
                          finished flag: Bool){
        print("animationDidStop \(anim)")
    }
}
//MARK: ------- AVAudioPlayerDelegate ----------
extension Streamer : AVAudioPlayerDelegate{
    
    @objc func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully: Bool) {
        
        // debugging 'got error 2003332927 while sending format information'
        // It is defined in AudioFile.h as kAudioFileUnspecifiedError = 'wht?', // 0x7768743F, 2003334207
//        print("audioPlayerDidFinishPlaying")
        self.punchBusy = false  // for beeps/no punch case
        
    }

}
// MARK: ---------------- swiftMidiDelegate -------------------
extension Streamer : SwiftMidiDelegate{
    
    func inputsChanged(_ inputNames : [String], _ sender : SwiftMidi){
        
    }
    func outputsChanged(_ outputNames : [String], _ sender : SwiftMidi){
        
    }
    func didSelectInput(_ input : String, _ sender : SwiftMidi){
        
    }
    func didSelectOutput(_ output : String, _ sender : SwiftMidi){
        
    }
    func noteOnService(_ midi : [UInt8], _ sender : SwiftMidi){
        
    }
    func noteOffService(_ midi : [UInt8], _ sender : SwiftMidi){
    }
    func controlChangeService(_ midi : [UInt8], _ sender : SwiftMidi){
        
    }
    func sysexService(_ midi : [UInt8], _ sender : SwiftMidi){
        
    }
    func mtcService(_ mtc : UInt8, _ sender : SwiftMidi){
        

    }
    
}
// MARK: ---------------- CALayerDelegate -------------------
extension Streamer:CALayerDelegate{
    
    // 10/18/22 not called for CAAnimation streamer movement
    
    func layerWillDraw(_ layer: CALayer) {
        print("+")
    }
    
    func draw(_ layer: CALayer, in ctx: CGContext) {
        print(".")
    }
    
}

