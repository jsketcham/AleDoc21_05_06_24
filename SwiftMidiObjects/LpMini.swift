//
//  LpMini.swift
//  LpMiniTester
//
//  Created by Pro Tools on 2/5/23.
//
/*
 B0 68-6f top row
 90 78-7f from bottom, right column

 8x8 keypad   right col
 00-07          7f
 10-17          7e
 20-27          7d
 30-37          7c
 40-47          7b
 50-57          7a
 60-67          79
 70-77          78
 */

import Cocoa
// tickle github
let COLOR_AIP_RED = UInt8(0xf)
let COLOR_AIP_GREEN = UInt8(0x3c)
let COLOR_AIP_GREEN_DIM = UInt8(0x1c)
let COLOR_AIP_AMBER = UInt8(0x3f)
let COLOR_AIP_OFF = UInt8(0xc)
let COLOR_AIP_AMBER_DIM = UInt8(0x1D)
let COLOR_AIP_YELLOW = UInt8(0x3e)
let COLOR_RED_BLINK = UInt8(0xb)

//let CC_CAPTURE_SAMPLE = UInt8(20)
//let CC_VIDEO_REC_DELAY = UInt8(0)

@objc protocol LpMiniDelegate{

    @objc func txOsc(_ str : String)
    @objc func toggleMatrixButton(_ index : Int, _ buttonTag : Int)
    @objc func getMatrixButton(_ index : Int, _ buttonTag : Int)->Bool
    @objc func accessoryService(_ data : NSData)
    
}

@objc class LpMini: NSObject {
    
    let MIC_DICTIONARY_KEY = "micDictionary2"   // 2, because we changed dictionary formats
    
    var delegate : LpMiniDelegate?
    var swiftMidi : SwiftMidi?
//    var swiftMidi2 : SwiftMidi?
    @objc var accMidi : SwiftMidi?
//    @objc var boomRecorderMidi : SwiftMidi?
    var micTimer : Timer?
    var midiIOTimer : Timer?
    
    var colors : [UInt8] = [
        COLOR_AIP_RED
        ,COLOR_AIP_GREEN
        ,COLOR_AIP_GREEN_DIM
        ,COLOR_AIP_AMBER
        ,COLOR_AIP_OFF
        ,COLOR_AIP_AMBER_DIM
        ,COLOR_AIP_YELLOW]
    
    var aipSelector = 0
    
    @objc init(_ delegate : LpMiniDelegate){
        
        super.init()
        self.delegate = delegate
        
        do{
            let registrationDefaults : [String : Any] = try [MIC_DICTIONARY_KEY : NSKeyedArchiver.archivedData(withRootObject: micDictionary, requiringSecureCoding: false)]
            
            UserDefaults.standard.register(defaults: registrationDefaults)
            
        }catch{
            print("failed to register user defaults")
        }
        
        recallMicDictionary()
        
        micTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(micRefresh), userInfo: nil, repeats: true)
        
        swiftMidi = SwiftMidi(self, "LP Mini", .IN_AND_OUT)
//        swiftMidi2 = SwiftMidi(self, "LP Mini 2", .IN_AND_OUT)
        accMidi = SwiftMidi(self, "Accessory", .IN_AND_OUT)
//        boomRecorderMidi = SwiftMidi(self, "Boom Recorder", .IN_AND_OUT)
        
    }
    // MARK: ------- utilities --------
    @objc func lpMidiTx(_ data : NSData){
        // send to both devices
        swiftMidi?.midiClient?.midiTx(data)
//        swiftMidi2?.midiClient?.midiTx(data)
    }
    func recallMicDictionary(){
        
        let set = NSSet.init(objects: NSString.self,NSDictionary.self,NSNumber.self)
        do{
            let data = UserDefaults.standard.data(forKey: MIC_DICTIONARY_KEY)
            micDictionary = try NSKeyedUnarchiver.unarchivedObject(ofClasses: set as! Set<AnyHashable>, from: data!) as! [String : NSNumber]
        }catch{
            
            print("failed to unarchive micDictionary, old format?")
            saveMicDictionary()

        }
    }
    func saveMicDictionary(){
        
        do{
            let data = try NSKeyedArchiver.archivedData(withRootObject: micDictionary, requiringSecureCoding: false)
            UserDefaults.standard.set(data, forKey: MIC_DICTIONARY_KEY)
        }catch{
            
            print("saveMicDictionary")
            
        }
        
    }
    @objc func initAipHead(){
        
        setAipIndicator(0,true)  // start in actor/editor
        setAipIndicator(1,false)  // turn off the old value
        setAipIndicator(2,false)  // turn off the old value

        for i in 0..<7{
            for j in 0..<13{
                
                let state = delegate?.getMatrixButton(i, j)
                setMatrixIndicator(i, j, state!)
            }
        }
        for key : String in micDictionary.keys{
            
            txMic(key)
            
       }
        // backlight the unused buttons in the matrix
        for i in 0..<5{
            
            var bytes : [UInt8] = [0x90,UInt8((i << 4) & 0xff),COLOR_AIP_GREEN_DIM]
            var data = NSData(bytes: bytes, length: bytes.count)
            lpMidiTx(data as NSData)
            
            bytes = [0x90,UInt8(((i << 4) | 4) & 0xff),COLOR_AIP_GREEN_DIM]
            data = NSData(bytes: bytes, length: bytes.count)
            lpMidiTx(data as NSData)

        }
   }
    @objc func setRehRecPb(_ foo : Int){
        
    }
    @objc func setMatrixIndicator(_ matrix : Int, _ button : Int, _ state : Bool){
        
//        print("setMatrixIndicator matrix \(matrix) button \(button) state \(state)");
        // send the state to StreamDeck
        // "lpMini 0_0,3f" or "lpMini 0_1,0c"
        let aleDelegate = NSApp.delegate as? AleDelegate
        
        var onColor = COLOR_AIP_AMBER   // 2.10.02 follow reh/rec/pb
        
        switch(Int(aleDelegate!.matrixWindowController.rehRecPb)){
        case MODE_CONTROL_RECORD:   onColor = COLOR_AIP_RED; break
        case MODE_CONTROL_PLAYBACK: onColor = COLOR_AIP_GREEN; break
        default: onColor = COLOR_AIP_AMBER; break
        }
        
        let color = state ? onColor : COLOR_AIP_OFF
        
        let str = String(format: "lpMini %d_%d,%02x", matrix,button,color)
        delegate?.txOsc(str)
        
        // check that the selected matrix is being shown
        if let dict = oscToAipDictionary[NSNumber.init(integerLiteral: aipSelector)],
           let key = dict[String(format: "%d_%d", matrix,button)]{
            
            let value = UInt32(key, radix: 16) ?? 0
            let bytes : [UInt8] = [0x90,UInt8((value >> 8) & 0xff),color]
            let data = NSData(bytes: bytes, length: bytes.count)
            lpMidiTx(data as NSData)
            
//            print("setMatrixIndicator \(aleDelegate!.matrixWindowController.rehRecPb) \(bytes[0]) \(bytes[1]) \(bytes[2])")
            
        }

    }
    @objc func cmdDecoder(_ cmd : String){
        
        if let selector = midiKeyDictionary[cmd.lowercased()]{
            DispatchQueue.main.async { [] in
                self.perform(selector, with: cmd.lowercased())
            }
        }

    }

    @objc func txMic(_ key : String){
        
        // keys like 90517f
//        print("txMic")
        
        micSendToAcc(key)   // send MIDI, there is a cross ref table
        
        let state = micDictionary[key] as? NSNumber.BooleanLiteralType
        let value = UInt32(key, radix: 16) ?? 0
        let color = state! ? COLOR_AIP_RED : COLOR_AIP_GREEN_DIM

        let bytes : [UInt8] = [0x90,UInt8((value >> 8) & 0xff),color]

        // indicators
        // LP Mini wants a separate message for each note
        let data = NSData(bytes: bytes, length: bytes.count)
        lpMidiTx(data as NSData)
        
        // StreamDeck
        let str = String(format: "lpMini %@,%02x", key,color)
        delegate?.txOsc(str)

    }

    @objc func setMics(_ state : Bool){
        
        // a test function, getting lpMini and StreamDeck indicators going
                
        for key : String in micDictionary.keys{
            
            micDictionary[key] = NSNumber(booleanLiteral: state)
            
            txMic(key)
            
       }
        
    }
    func setAipIndicator(_ selector : Int, _ state : Bool){
        
        var bytes : [UInt8] = [0xb0,0,0]
        bytes[2] = state ? COLOR_AIP_AMBER : COLOR_AIP_GREEN_DIM
        
        bytes[1] = 0x69 + UInt8(selector)
        var data = NSData(bytes: bytes, length: bytes.count)
        lpMidiTx(data as NSData)

        bytes[1] += 4
        data = NSData(bytes: bytes, length: bytes.count)
        lpMidiTx(data as NSData)

        if(!state){
            // not this bank, don't set button LEDs
            return
            
        }
        
        if let dict = oscToAipDictionary[NSNumber.init(integerLiteral: selector)]{
            
            for key in dict.keys{
                
                let array = key.components(separatedBy: "_")
                
                if let matrix = Int(array[0]),
                   let button = Int(array[1]){
                    
                    let state = delegate?.getMatrixButton(matrix, button)
                    setMatrixIndicator(matrix,button,state!)
                    
                }
            }
        }
        
    }
    // MARK: ------- jump table functions --------
    @objc func lpUnused(_ msg : String){
        print("lpUnused \(msg)")
        
    }
    @objc func toggleAutoPlay(_ msg : String){
        
        print("toggleAutoPlay \(msg)")
    }
    @objc func aipPair(_ msg : String){
        
        // note that toggleAutoPlay is not used, we could move everything to the left and have a button for remote actor/remote editor
        print("aipPair \(msg)")
        setAipIndicator(0,false)  // turn off the old value
        setAipIndicator(1,false)  // turn off the old value
        setAipIndicator(2,false)  // turn off the old value
        
        switch(msg){
        case "b0697f": aipSelector = 0; break
        case "b06a7f": aipSelector = 1; break
        case "b06b7f": aipSelector = 2; break
        case "b06d7f": aipSelector = 0; break
        case "b06e7f": aipSelector = 1; break
        default: break
        }
        
        setAipIndicator(aipSelector, true)  // turn on the new value
    }
    
    @objc func aipToggle(_ msg : String){
        
//        print("aipToggle \(msg)")
        let n = NSNumber.init(integerLiteral: aipSelector)
        
        if let dict = aipToOscDictionary[n],
           let oscItem = dict[msg]{
            
            aipToggle2(oscItem)
        }
        
    }
    @objc func aipToggle2(_ msg : String){
        
//        print("aipToggle2 \(msg)")
        let array : [String] = msg.components(separatedBy: "_")
        
        if let arrayNumber = Int(array[0]),
           let button = Int(array[1]){
            delegate?.toggleMatrixButton(arrayNumber,button)
        }
        
    }
    @objc func isMidiCustomFillState()->Bool{
        // check state of bottom right round button
        if let state = micDictionary["90787f"] as? NSNumber.BooleanLiteralType{
            
            return state
        }
        return false
    }
    
    // mic keys are row 1: 9050xx-9057xx, round button (PB Futz) 9058
    //              row 2: 9060xx-9067xx, round button (CP Futz) 9068
    //              row 3: 9070xx-9077xx, round button (Fill) 9078
    // put mics in order, followed by PB Futz, CP Futz
    // table ends with 119, 26 entries -> table starts at 94
    
    var micToAccDictionary: Dictionary<String, UInt8> = [
                        "50":94
                        ,"51":95
                        ,"52":96
                        ,"53":97
                        ,"54":98
                        ,"55":99
                        ,"56":100
                        ,"57":101
                        ,"58":118
                        ,"60":102
                        ,"61":103
                        ,"62":104
                        ,"63":105
                        ,"64":106
                        ,"65":107
                        ,"66":108
                        ,"67":109
                        ,"68":119
                        ,"70":110
                        ,"71":111
                        ,"72":112
                        ,"73":113
                        ,"74":114
                        ,"75":115
                        ,"76":116
                        ,"77":117
                    ]

    @objc func micSendToAcc(_ key : String){
        
        // immediate refresh on button push
        // 2.10.02 cross ref table: mics are cc 94-117, pb futz 118, cp futz 119
        
        let endIndex = key.index(key.endIndex, offsetBy: -2)
        let startIndex = key.index(key.startIndex, offsetBy: 2)
        let subStr = String(key[startIndex..<endIndex])
        //print("\(subStr)")
        
        // only the last 3 rows send to accessory
        if let noteNumber = micToAccDictionary[subStr]{
            
            let state = micDictionary[key] as? NSNumber.BooleanLiteralType
            let micOnOff : UInt8 = state! ? 0x7f : 0x00

            let micBytes : [UInt8] = [0xb0,noteNumber,micOnOff]
            
            // the reason we are here
            let micData = NSData(bytes: micBytes, length: micBytes.count)
            accMidi?.midiClient?.midiTx(micData)
//            print("micBytes \(micBytes[0]) \(micBytes[1]) \(micBytes[2])")
        }

    }
    @objc func micRefresh(){
        
        // send mic MIDI every so often
        for key : String in micDictionary.keys{
            
            self.micSendToAcc(key)

       }
        // 09/06/23 Evan changed his mind on the refresh
        // 01/03/24 revised to send accessory cc's 23, 24, 19, 17, 18 in decimal
        let aleDelegate = NSApp.delegate as? AleDelegate
        aleDelegate?.dialAccessoryRefresh()      //2.10.02

    }
    @objc func micSet(_ msg : String, _ state : Bool){
        
        if micDictionary[msg] is NSNumber.BooleanLiteralType{
            
            micDictionary[msg] = NSNumber(booleanLiteral: state)
            txMic(msg)
            saveMicDictionary()
        }
   }

    @objc func micToggle(_ msg : String){
        
        //print("micToggle \(msg)")
        
        if var state = micDictionary[msg] as? NSNumber.BooleanLiteralType{
            
            state = !state
            micDictionary[msg] = NSNumber(booleanLiteral: state)
            txMic(msg)
            saveMicDictionary()
        }
        
    }
    // MARK: ---------- jump table  ----------------
    
    let midiKeyDictionary : [String : Selector] =
    [
        "b0687f" : #selector(toggleAutoPlay(_:))
        ,"b0697f" : #selector(aipPair(_:))  // actor
        ,"b06a7f" : #selector(aipPair(_:))  // stage
        ,"b06b7f" : #selector(aipPair(_:))  // ISDN
        ,"b06c7f" : #selector(lpUnused(_:))
        ,"b06d7f" : #selector(aipPair(_:))  // editor
        ,"b06e7f" : #selector(aipPair(_:))  // ctl room
        ,"b06f7f" : #selector(lpUnused(_:))
        
        ,"90017f" : #selector(aipToggle(_:)) // beeps ahead    left switcher
        ,"90027f" : #selector(aipToggle(_:)) // beeps in       left switcher
        ,"90037f" : #selector(aipToggle(_:)) // beeps past     left switcher
        
        ,"90057f" : #selector(aipToggle(_:)) // beeps ahead    right switcher
        ,"90067f" : #selector(aipToggle(_:)) // beeps in       right switcher
        ,"90077f" : #selector(aipToggle(_:)) // beeps past     right switcher
        
        ,"90117f" : #selector(aipToggle(_:)) // direct ahead    left switcher
        ,"90127f" : #selector(aipToggle(_:)) // direct in       left switcher
        ,"90137f" : #selector(aipToggle(_:)) // direct past     left switcher
        
        ,"90157f" : #selector(aipToggle(_:)) // direct ahead    right switcher
        ,"90167f" : #selector(aipToggle(_:)) // direct in       right switcher
        ,"90177f" : #selector(aipToggle(_:)) // direct past     right switcher
        
        ,"90217f" : #selector(aipToggle(_:)) // playback ahead    left switcher
        ,"90227f" : #selector(aipToggle(_:)) // playback in       left switcher
        ,"90237f" : #selector(aipToggle(_:)) // playback past     left switcher
        
        ,"90257f" : #selector(aipToggle(_:)) // playback ahead    right switcher
        ,"90267f" : #selector(aipToggle(_:)) // playback in       right switcher
        ,"90277f" : #selector(aipToggle(_:)) // playback past     right switcher
        
        ,"90317f" : #selector(aipToggle(_:)) // comp ahead    left switcher
        ,"90327f" : #selector(aipToggle(_:)) // comp in       left switcher
        ,"90337f" : #selector(aipToggle(_:)) // comp past     left switcher
        
        ,"90357f" : #selector(aipToggle(_:)) // comp ahead    right switcher
        ,"90367f" : #selector(aipToggle(_:)) // comp in       right switcher
        ,"90377f" : #selector(aipToggle(_:)) // comp past     right switcher
        
        ,"90417f" : #selector(aipToggle(_:)) // guide ahead    left switcher
        ,"90427f" : #selector(aipToggle(_:)) // guide in       left switcher
        ,"90437f" : #selector(aipToggle(_:)) // guide past     left switcher
        
        ,"90457f" : #selector(aipToggle(_:)) // guide ahead    right switcher
        ,"90467f" : #selector(aipToggle(_:)) // guide in       right switcher
        ,"90477f" : #selector(aipToggle(_:)) // guide past     right switcher
        
        ,"90087f"   :   #selector(micToggle(_:))    // round right button
        ,"90187f"   :   #selector(micToggle(_:))    // round right button
        ,"90287f"   :   #selector(micToggle(_:))    // round right button
        ,"90387f"   :   #selector(micToggle(_:))    // round right button
        ,"90487f"   :   #selector(micToggle(_:))    // round right button
        ,"90587f"   :   #selector(micToggle(_:))    // round right button
        ,"90687f"   :   #selector(micToggle(_:))    // round right button
        ,"90787f"   :   #selector(micToggle(_:))    // round right button
        
        ,"90507f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90517f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90527f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90537f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90547f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90557f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90567f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90577f"   :   #selector(micToggle(_:))    // mic toggler
        
        ,"90607f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90617f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90627f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90637f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90647f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90657f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90667f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90677f"   :   #selector(micToggle(_:))    // mic toggler
        
        ,"90707f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90717f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90727f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90737f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90747f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90757f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90767f"   :   #selector(micToggle(_:))    // mic toggler
        ,"90777f"   :   #selector(micToggle(_:))    // mic toggler
        
        // additions for Stream Deck, every AIP state
        
        ,"0_0"     :   #selector(aipToggle2(_:))
        ,"0_1"     :   #selector(aipToggle2(_:))
        ,"0_2"     :   #selector(aipToggle2(_:))
        ,"0_3"     :   #selector(aipToggle2(_:))
        ,"0_4"     :   #selector(aipToggle2(_:))
        ,"0_5"     :   #selector(aipToggle2(_:))
        ,"0_6"     :   #selector(aipToggle2(_:))
        ,"0_7"     :   #selector(aipToggle2(_:))
        ,"0_8"     :   #selector(aipToggle2(_:))
        ,"0_9"     :   #selector(aipToggle2(_:))
        ,"0_10"    :   #selector(aipToggle2(_:))
        ,"0_11"    :   #selector(aipToggle2(_:))
        ,"0_12"    :   #selector(aipToggle2(_:))
        ,"0_13"    :   #selector(aipToggle2(_:))
        ,"0_14"    :   #selector(aipToggle2(_:))

        ,"1_0"     :   #selector(aipToggle2(_:))
        ,"1_1"     :   #selector(aipToggle2(_:))
        ,"1_2"     :   #selector(aipToggle2(_:))
        ,"1_3"     :   #selector(aipToggle2(_:))
        ,"1_4"     :   #selector(aipToggle2(_:))
        ,"1_5"     :   #selector(aipToggle2(_:))
        ,"1_6"     :   #selector(aipToggle2(_:))
        ,"1_7"     :   #selector(aipToggle2(_:))
        ,"1_8"     :   #selector(aipToggle2(_:))
        ,"1_9"     :   #selector(aipToggle2(_:))
        ,"1_10"    :   #selector(aipToggle2(_:))
        ,"1_11"    :   #selector(aipToggle2(_:))
        ,"1_12"    :   #selector(aipToggle2(_:))
        ,"1_13"    :   #selector(aipToggle2(_:))
        ,"1_14"    :   #selector(aipToggle2(_:))

        ,"2_0"     :   #selector(aipToggle2(_:))
        ,"2_1"     :   #selector(aipToggle2(_:))
        ,"2_2"     :   #selector(aipToggle2(_:))
        ,"2_3"     :   #selector(aipToggle2(_:))
        ,"2_4"     :   #selector(aipToggle2(_:))
        ,"2_5"     :   #selector(aipToggle2(_:))
        ,"2_6"     :   #selector(aipToggle2(_:))
        ,"2_7"     :   #selector(aipToggle2(_:))
        ,"2_8"     :   #selector(aipToggle2(_:))
        ,"2_9"     :   #selector(aipToggle2(_:))
        ,"2_10"    :   #selector(aipToggle2(_:))
        ,"2_11"    :   #selector(aipToggle2(_:))
        ,"2_12"    :   #selector(aipToggle2(_:))
        ,"2_13"    :   #selector(aipToggle2(_:))
        ,"2_14"    :   #selector(aipToggle2(_:))

        ,"3_0"     :   #selector(aipToggle2(_:))
        ,"3_1"     :   #selector(aipToggle2(_:))
        ,"3_2"     :   #selector(aipToggle2(_:))
        ,"3_3"     :   #selector(aipToggle2(_:))
        ,"3_4"     :   #selector(aipToggle2(_:))
        ,"3_5"     :   #selector(aipToggle2(_:))
        ,"3_6"     :   #selector(aipToggle2(_:))
        ,"3_7"     :   #selector(aipToggle2(_:))
        ,"3_8"     :   #selector(aipToggle2(_:))
        ,"3_9"     :   #selector(aipToggle2(_:))
        ,"3_10"    :   #selector(aipToggle2(_:))
        ,"3_11"    :   #selector(aipToggle2(_:))
        ,"3_12"    :   #selector(aipToggle2(_:))
        ,"3_13"    :   #selector(aipToggle2(_:))
        ,"3_14"    :   #selector(aipToggle2(_:))
        
        ,"4_0"     :   #selector(aipToggle2(_:))
        ,"4_1"     :   #selector(aipToggle2(_:))
        ,"4_2"     :   #selector(aipToggle2(_:))
        ,"4_3"     :   #selector(aipToggle2(_:))
        ,"4_4"     :   #selector(aipToggle2(_:))
        ,"4_5"     :   #selector(aipToggle2(_:))
        ,"4_6"     :   #selector(aipToggle2(_:))
        ,"4_7"     :   #selector(aipToggle2(_:))
        ,"4_8"     :   #selector(aipToggle2(_:))
        ,"4_9"     :   #selector(aipToggle2(_:))
        ,"4_10"    :   #selector(aipToggle2(_:))
        ,"4_11"    :   #selector(aipToggle2(_:))
        ,"4_12"    :   #selector(aipToggle2(_:))
        ,"4_13"    :   #selector(aipToggle2(_:))
        ,"4_14"    :   #selector(aipToggle2(_:))

        ,"5_0"     :   #selector(aipToggle2(_:))
        ,"5_1"     :   #selector(aipToggle2(_:))
        ,"5_2"     :   #selector(aipToggle2(_:))
        ,"5_3"     :   #selector(aipToggle2(_:))
        ,"5_4"     :   #selector(aipToggle2(_:))
        ,"5_5"     :   #selector(aipToggle2(_:))
        ,"5_6"     :   #selector(aipToggle2(_:))
        ,"5_7"     :   #selector(aipToggle2(_:))
        ,"5_8"     :   #selector(aipToggle2(_:))
        ,"5_9"     :   #selector(aipToggle2(_:))
        ,"5_10"    :   #selector(aipToggle2(_:))
        ,"5_11"    :   #selector(aipToggle2(_:))
        ,"5_12"    :   #selector(aipToggle2(_:))
        ,"5_13"    :   #selector(aipToggle2(_:))
        ,"5_14"    :   #selector(aipToggle2(_:))

        ,"6_0"     :   #selector(aipToggle2(_:))
        ,"6_1"     :   #selector(aipToggle2(_:))
        ,"6_2"     :   #selector(aipToggle2(_:))
        ,"6_3"     :   #selector(aipToggle2(_:))
        ,"6_4"     :   #selector(aipToggle2(_:))
        ,"6_5"     :   #selector(aipToggle2(_:))
        ,"6_6"     :   #selector(aipToggle2(_:))
        ,"6_7"     :   #selector(aipToggle2(_:))
        ,"6_8"     :   #selector(aipToggle2(_:))
        ,"6_9"     :   #selector(aipToggle2(_:))
        ,"6_10"    :   #selector(aipToggle2(_:))
        ,"6_11"    :   #selector(aipToggle2(_:))
        ,"6_12"    :   #selector(aipToggle2(_:))
        ,"6_13"    :   #selector(aipToggle2(_:))
        ,"6_14"    :   #selector(aipToggle2(_:))
    ]
    
    var micDictionary : [String : NSNumber] =
    [
        "90087f" : NSNumber(booleanLiteral: false)
        ,"90187f" : NSNumber(booleanLiteral: false)
        ,"90287f" : NSNumber(booleanLiteral: false)
        ,"90387f" : NSNumber(booleanLiteral: false)
        ,"90487f" : NSNumber(booleanLiteral: false)
        ,"90587f" : NSNumber(booleanLiteral: false)
        ,"90687f" : NSNumber(booleanLiteral: false)
        ,"90787f" : NSNumber(booleanLiteral: false)
        ,"90507f" : NSNumber(booleanLiteral: false)
        ,"90517f" : NSNumber(booleanLiteral: false)
        ,"90527f" : NSNumber(booleanLiteral: false)
        ,"90537f" : NSNumber(booleanLiteral: false)
        ,"90547f" : NSNumber(booleanLiteral: false)
        ,"90557f" : NSNumber(booleanLiteral: false)
        ,"90567f" : NSNumber(booleanLiteral: false)
        ,"90577f" : NSNumber(booleanLiteral: false)
        ,"90607f" : NSNumber(booleanLiteral: false)
        ,"90617f" : NSNumber(booleanLiteral: false)
        ,"90627f" : NSNumber(booleanLiteral: false)
        ,"90637f" : NSNumber(booleanLiteral: false)
        ,"90647f" : NSNumber(booleanLiteral: false)
        ,"90657f" : NSNumber(booleanLiteral: false)
        ,"90667f" : NSNumber(booleanLiteral: false)
        ,"90677f" : NSNumber(booleanLiteral: false)
        ,"90707f" : NSNumber(booleanLiteral: false)
        ,"90717f" : NSNumber(booleanLiteral: false)
        ,"90727f" : NSNumber(booleanLiteral: false)
        ,"90737f" : NSNumber(booleanLiteral: false)
        ,"90747f" : NSNumber(booleanLiteral: false)
        ,"90757f" : NSNumber(booleanLiteral: false)
        ,"90767f" : NSNumber(booleanLiteral: false)
        ,"90777f" : NSNumber(booleanLiteral: false)
    ]
    
    var oscToAipDictionary : [NSNumber : [String : String]] = [
        
        NSNumber.init(integerLiteral: 0) : [    // actor-editor
            
            "2_12"  : "90017f"  // beeps ahead      left switcher
            ,"2_13" : "90027f"  // beeps in         left switcher
            ,"2_14" : "90037f"  // beeps ahead      left switcher

            ,"3_12" : "90057f"  // beeps ahead      right switcher
            ,"3_13" : "90067f"  // beeps in         right switcher
            ,"3_14" : "90077f"  // beeps past       right switcher

            ,"2_3"  : "90117f"  // direct ahead    left switcher
            ,"2_4"  : "90127f"  // direct in       left switcher
            ,"2_5"  : "90137f"  // direct past     left switcher

            ,"3_3"  : "90157f"  // direct ahead    right switcher
            ,"3_4"  : "90167f"  // direct in       right switcher
            ,"3_5"  : "90177f"  // direct past     right switcher

            ,"2_6"  : "90217f"  // playback ahead    left switcher
            ,"2_7"  : "90227f"  // playback in       left switcher
            ,"2_8"  : "90237f"  // playback past     left switcher

            ,"3_6"  : "90257f"  // playback ahead    right switcher
            ,"3_7"  : "90267f"  // playback in       right switcher
            ,"3_8"  : "90277f"  // playback past     right switcher

            ,"2_9"  : "90317f"  // comp ahead    left switcher
            ,"2_10" : "90327f"  // comp in       left switcher
            ,"2_11" : "90337f"  // comp past     left switcher

            ,"3_9"  : "90357f"  // comp ahead    right switcher
            ,"3_10" : "90367f"  // comp in       right switcher
            ,"3_11" : "90377f"  // comp past     right switcher

            ,"2_0"  : "90417f"  // guide ahead    left switcher
            ,"2_1"  : "90427f"  // guide in       left switcher
            ,"2_2"  : "90437f"  // guide past     left switcher

            ,"3_0"  : "90457f"  // guide ahead    right switcher
            ,"3_1"  : "90467f"  // guide in       right switcher
            ,"3_2"  : "90477f"  // guide past     right switcher
        ]
        ,NSNumber.init(integerLiteral: 1) : [   // stage/booth
            "1_12"  : "90017f"  // beeps ahead      left switcher
            ,"1_13" : "90027f"  // beeps in         left switcher
            ,"1_14" : "90037f"  // beeps ahead      left switcher

            ,"0_12" : "90057f"  // beeps ahead      right switcher
            ,"0_13" : "90067f"  // beeps in         right switcher
            ,"0_14" : "90077f"  // beeps ahead      right switcher

            ,"1_3"  : "90117f"  // direct ahead    left switcher
            ,"1_4"  : "90127f"  // direct in       left switcher
            ,"1_5"  : "90137f"  // direct past     left switcher

            ,"0_3"  : "90157f"  // direct ahead    right switcher
            ,"0_4"  : "90167f"  // direct in       right switcher
            ,"0_5"  : "90177f"  // direct past     right switcher

            ,"1_6"  : "90217f"  // playback ahead    left switcher
            ,"1_7"  : "90227f"  // playback in       left switcher
            ,"1_8"  : "90237f"  // playback past     left switcher

            ,"0_6"  : "90257f"  // playback ahead    right switcher
            ,"0_7"  : "90267f"  // playback in       right switcher
            ,"0_8"  : "90277f"  // playback past     right switcher

            ,"1_9"  : "90317f"  // comp ahead    left switcher
            ,"1_10" : "90327f"  // comp in       left switcher
            ,"1_11" : "90337f"  // comp past     left switcher

            ,"0_9"  : "90357f"  // comp ahead    right switcher
            ,"0_10" : "90367f"  // comp in       right switcher
            ,"0_11" : "90377f"  // comp past     right switcher
            
            ,"1_0"  : "90417f"  // guide ahead    left switcher
            ,"1_1"  : "90427f"  // guide in       left switcher
            ,"1_2"  : "90437f"  // guide past     left switcher

            ,"0_0"  : "90457f"  // guide ahead    right switcher
            ,"0_1"  : "90467f"  // guide in       right switcher
            ,"0_2"  : "90477f"  // guide past     right switcher
        ]
        ,NSNumber.init(integerLiteral: 2) : [   // ISDN
            "4_12"  : "90017f"   // beeps ahead     left switcher
            ,"4_13"  : "90027f"   // beeps in        left switcher
            ,"4_14"  : "90037f"   // beeps past      left switcher

            ,"4_3"  : "90117f"  // direct ahead    left switcher
            ,"4_4"  : "90127f"  // direct in       left switcher
            ,"4_5"  : "90137f"  // direct past     left switcher

            ,"4_6"  : "90217f"  // playback ahead    left switcher
            ,"4_7"  : "90227f"  // playback in       left switcher
            ,"4_8"  : "90237f"  // playback past     left switcher

            ,"4_9"  : "90317f"  // comp ahead    left switcher
            ,"4_10" : "90327f"  // comp in       left switcher
            ,"4_11" : "90337f"  // comp past     left switcher

            ,"4_0"  : "90417f"  // guide ahead    left switcher
            ,"4_1"  : "90427f"  // guide in       left switcher
            ,"4_2"  : "90437f"  // guide past     left switcher
        ]
        ,NSNumber.init(integerLiteral: 3) : [   // remote actor/remote editor
            "5_12"  : "90017f"   // beeps ahead    left switcher
            ,"5_13"  : "90027f"   // beeps in        left switcher
            ,"5_14"  : "90037f"   // beeps past      left switcher

            ,"6_12" : "90057f"  // beeps ahead      right switcher
            ,"6_13" : "90067f"  // beeps in         right switcher
            ,"6_14" : "90077f"  // beeps past       right switcher

            ,"5_3"  : "90117f"  // direct ahead    left switcher
            ,"5_4"  : "90127f"  // direct in       left switcher
            ,"5_5"  : "90137f"  // direct past     left switcher

            ,"6_3"  : "90157f"  // direct ahead    right switcher
            ,"6_4"  : "90167f"  // direct in       right switcher
            ,"6_5"  : "90177f"  // direct past     right switcher

            ,"5_6"  : "90217f"  // playback ahead    left switcher
            ,"5_7"  : "90227f"  // playback in       left switcher
            ,"5_8"  : "90237f"  // playback past     left switcher

            ,"6_6"  : "90257f"  // playback ahead    right switcher
            ,"6_7"  : "90267f"  // playback in       right switcher
            ,"6_8"  : "90277f"  // playback past     right switcher

            ,"5_9"  : "90317f"  // comp ahead    left switcher
            ,"5_10" : "90327f"  // comp in       left switcher
            ,"5_11" : "90337f"  // comp past     left switcher

            ,"6_9"  : "90357f"  // comp ahead    right switcher
            ,"6_10" : "90367f"  // comp in       right switcher
            ,"6_11" : "90377f"  // comp past     right switcher

            ,"5_0"  : "90417f"  // guide ahead    left switcher
            ,"5_1"  : "90427f"  // guide in       left switcher
            ,"5_2"  : "90437f"  // guide past     left switcher

            ,"6_0"  : "90457f"  // guide ahead    right switcher
            ,"6_1"  : "90467f"  // guide in       right switcher
            ,"6_2"  : "90477f"  // guide past     right switcher
        ]
  ]
    
    var aipToOscDictionary : [NSNumber : [String : String]] = [
        NSNumber.init(integerLiteral: 0) : [    // actor-editor
            
             "90017f" : "2_12" // beeps ahead    left switcher
             ,"90027f" : "2_13" // beeps in    left switcher
             ,"90037f" : "2_14" // beeps past    left switcher

            ,"90057f" : "3_12" // beeps ahead    right switcher
             ,"90067f" : "3_13" // beeps in      right switcher
             ,"90077f" : "3_14" // beeps past    right switcher

            ,"90117f" : "2_3" // direct ahead    left switcher
            ,"90127f" : "2_4" // direct in       left switcher
            ,"90137f" : "2_5" // direct past     left switcher

            ,"90157f" : "3_3" // direct ahead    right switcher
            ,"90167f" : "3_4" // direct in       right switcher
            ,"90177f" : "3_5" // direct past     right switcher

            ,"90217f" : "2_6" // playback ahead    left switcher
            ,"90227f" : "2_7" // playback in       left switcher
            ,"90237f" : "2_8" // playback past     left switcher

            ,"90257f" : "3_6" // playback ahead    right switcher
            ,"90267f" : "3_7" // playback in       right switcher
            ,"90277f" : "3_8" // playback past     right switcher

            ,"90317f" : "2_9"  // comp ahead    left switcher
            ,"90327f" : "2_10" // comp in       left switcher
            ,"90337f" : "2_11" // comp past     left switcher

            ,"90357f" : "3_9"  // comp ahead    right switcher
            ,"90367f" : "3_10" // comp in       right switcher
            ,"90377f" : "3_11" // comp past     right switcher

            ,"90417f" : "2_0" // guide ahead    left switcher
            ,"90427f" : "2_1" // guide in       left switcher
            ,"90437f" : "2_2" // guide past     left switcher

            ,"90457f" : "3_0" // guide ahead    right switcher
            ,"90467f" : "3_1" // guide in       right switcher
            ,"90477f" : "3_2" // guide past     right switcher
        ]
        ,NSNumber.init(integerLiteral: 1) : [   // stage/booth
             "90017f" : "1_12" // beeps ahead   left switcher
             ,"90027f" : "1_13" // beeps in     left switcher
             ,"90037f" : "1_14" // beeps past   left switcher

            ,"90057f" : "0_12" // beeps ahead    right switcher
             ,"90067f" : "0_13" // beeps in    right switcher
             ,"90077f" : "0_14" // beeps past    right switcher

            ,"90117f" : "1_3" // direct ahead    left switcher
            ,"90127f" : "1_4" // direct in       left switcher
            ,"90137f" : "1_5" // direct past     left switcher

            ,"90157f" : "0_3" // direct ahead    right switcher
            ,"90167f" : "0_4" // direct in       right switcher
            ,"90177f" : "0_5" // direct past     right switcher

            ,"90217f" : "1_6" // playback ahead    left switcher
            ,"90227f" : "1_7" // playback in       left switcher
            ,"90237f" : "1_8" // playback past     left switcher

            ,"90257f" : "0_6" // playback ahead    right switcher
            ,"90267f" : "0_7" // playback in       right switcher
            ,"90277f" : "0_8" // playback past     right switcher

            ,"90317f" : "1_9"  // comp ahead    left switcher
            ,"90327f" : "1_10" // comp in       left switcher
            ,"90337f" : "1_11" // comp past     left switcher

            ,"90357f" : "0_9"  // comp ahead    right switcher
            ,"90367f" : "0_10" // comp in       right switcher
            ,"90377f" : "0_11" // comp past     right switcher

            ,"90417f" : "1_0" // guide ahead    left switcher
            ,"90427f" : "1_1" // guide in       left switcher
            ,"90437f" : "1_2" // guide past     left switcher

            ,"90457f" : "0_0" // guide ahead    right switcher
            ,"90467f" : "0_1" // guide in       right switcher
            ,"90477f" : "0_2" // guide past     right switcher
        ]
        ,NSNumber.init(integerLiteral: 2) : [   // ISDN
             "90017f" : "4_12" // beeps ahead    left switcher
             ,"90027f" : "4_13" // beeps ahead    left switcher
             ,"90037f" : "4_14" // beeps ahead    left switcher

            ,"90117f" : "4_3" // direct ahead    left switcher
            ,"90127f" : "4_4" // direct in       left switcher
            ,"90137f" : "4_5" // direct past     left switcher

            ,"90217f" : "4_6" // playback ahead    left switcher
            ,"90227f" : "4_7" // playback in       left switcher
            ,"90237f" : "4_8" // playback past     left switcher

            ,"90317f" : "4_9"  // comp ahead    left switcher
            ,"90327f" : "4_10" // comp in       left switcher
            ,"90337f" : "4_11" // comp past     left switcher

            ,"90417f" : "4_0" // guide ahead    left switcher
            ,"90427f" : "4_1" // guide in       left switcher
            ,"90437f" : "4_2" // guide past     left switcher
        ]
        ,NSNumber.init(integerLiteral: 3) : [   // remote actor/remote editor
             "90017f" : "5_12" // beeps ahead    left switcher
             ,"90027f" : "5_13" // beeps in    left switcher
             ,"90037f" : "5_14" // beeps past    left switcher

            ,"90057f" : "6_12" // beeps ahead    right switcher
             ,"90067f" : "6_13" // beeps ahead    right switcher
             ,"90077f" : "6_14" // beeps ahead    right switcher

            ,"90117f" : "5_3" // direct ahead    left switcher
            ,"90127f" : "5_4" // direct in       left switcher
            ,"90137f" : "5_5" // direct past     left switcher

            ,"90157f" : "6_3" // direct ahead    right switcher
            ,"90167f" : "6_4" // direct in       right switcher
            ,"90177f" : "6_5" // direct past     right switcher

            ,"90217f" : "5_6" // playback ahead    left switcher
            ,"90227f" : "5_7" // playback in       left switcher
            ,"90237f" : "5_8" // playback past     left switcher

            ,"90257f" : "6_6" // playback ahead    right switcher
            ,"90267f" : "6_7" // playback in       right switcher
            ,"90277f" : "6_8" // playback past     right switcher

            ,"90317f" : "5_9"  // comp ahead    left switcher
            ,"90327f" : "5_10" // comp in       left switcher
            ,"90337f" : "5_11" // comp past     left switcher

            ,"90357f" : "6_9"  // comp ahead    right switcher
            ,"90367f" : "6_10" // comp in       right switcher
            ,"90377f" : "6_11" // comp past     right switcher

            ,"90417f" : "5_0" // guide ahead    left switcher
            ,"90427f" : "5_1" // guide in       left switcher
            ,"90437f" : "5_2" // guide past     left switcher

            ,"90457f" : "6_0" // guide ahead    right switcher
            ,"90467f" : "6_1" // guide in       right switcher
            ,"90477f" : "6_2" // guide past     right switcher
        ]
    ]
    @objc func midiIOTimeout(){
        
//        print("midiIOTimeout")
        // send current values to LP Mini
        initAipHead()
        
    }
}
// MARK: ---------- SwiftMidiDelegate ----------------
extension LpMini :SwiftMidiDelegate{
    
    func inputsChanged(_ inputNames : [String], _ sender : SwiftMidi){
//        print("inputsChanged")
        
        // after this settles down, send to LP Mini
        midiIOTimer?.invalidate()
        midiIOTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(midiIOTimeout), userInfo: nil, repeats: false)
    }
    func outputsChanged(_ outputNames : [String], _ sender : SwiftMidi){
//        print("outputsChanged")

        // after this settles down, send to LP Mini
        midiIOTimer?.invalidate()
        midiIOTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(midiIOTimeout), userInfo: nil, repeats: false)
    }
    func didSelectInput(_ input : String, _ sender : SwiftMidi){
        
    }
    func didSelectOutput(_ output : String, _ sender : SwiftMidi){
        
    }
    func noteOnService(_ midi : [UInt8], _ sender : SwiftMidi){
        
        // process 3 bytes of note on
//        print("noteOnService \(midi)")

        if sender == accMidi{
            // accessoryService
            let data = NSData(bytes: midi, length: midi.count)
            DispatchQueue.main.async { [] in
                self.delegate?.accessoryService(data)
            }
            
        }else if midi[2] == 0x7f{   // leading edge
            
            let key = String(format: "90%02x%02x", midi[1],midi[2])
            
            if let selector = midiKeyDictionary[key.lowercased()]{
                DispatchQueue.main.async { [] in
                    self.perform(selector, with: key.lowercased())
                }
            }
        }
        
    }
    func noteOffService(_ midi : [UInt8], _ sender : SwiftMidi){
    }
    func controlChangeService(_ midi : [UInt8], _ sender : SwiftMidi){
        
        // process 2 bytes of control change
//        print("controlChangeService \(midi)")
        
        if sender == accMidi{
            // accessoryService
            let data = NSData(bytes: midi, length: midi.count)
            DispatchQueue.main.async { [] in
                self.delegate?.accessoryService(data)
            }
            
        }else if midi[2] == 0x7f{   // LP Mini key leading edge
            
            let key = String(format: "b0%02x%02x", midi[1],midi[2])
            
            if let selector = midiKeyDictionary[key.lowercased()]{
                DispatchQueue.main.async { [] in
                    self.perform(selector, with: key.lowercased())
                }
            }
        }

    }
    func convert87(_ bytes: [UInt8]) -> [UInt8]{
        
        // can't send top bits in a sysex, we are using UTF8 encoding for text, which has top bits
        // so, top bits for [1-7] are encoded in [0], repeat
        
        var buffer = [UInt8]()
        var topBits : UInt8 = 0

        for i in 0..<bytes.count{
            
            if i % 8 == 0{topBits = bytes[i]; continue}
            buffer.append((topBits & 1 != 0 ? 0x80 : 0) | bytes[i] & 0x7f)
            topBits >>= 1
            
        }
        
//        var s = ""
//
//        for i in 0..<buffer.count{
//            s.append(String(format: "%02X ", buffer[i]))
//        }
//        print("\(s)")
        
        return buffer
    }

    func sysexService(_ midi : [UInt8], _ sender : SwiftMidi){
        
//        if(sender == boomRecorderMidi){
//            
//            var midi = midi
//            
//            // check headers, 6 bytes
//            if midi.count > proToolsHeader.count - 1{
//                
//                let hdr = [UInt8](midi[0..<proToolsHeader.count])
//                let twiHdr = [UInt8](twiHeader[0..<twiHeader.count])  // without SYSEX
//                
//                if hdr == twiHdr{    // a Jim Ketcham UTF8 text command, Time Warner command group
//                    
//                    midi.removeLast() // MIDI_EOX
//                    midi.removeFirst(hdr.count)    // header
//                                    
//                    // utf8 uses top bits, can't have that in MIDI, encode top bits
//                    let buffer87 = convert87(midi)    // 8 bytes -> 7 bytes, top bits of [1-7] are in [0]
//                                    
//                    if let s = String(bytes: buffer87, encoding: .utf8){
//                        
//                        NSLog("string from MIDI SYSEX: \(s)")
//                        // TODO: pass to AdrClient
//                    }
//
//                }
//            
//            }
//        }
        
    }
    func mtcService(_ mtc : UInt8, _ sender : SwiftMidi){
        
        // process 1 byte of mtc
//        print("mtcService")

    }

}

