//
//  MtcMidi.swift
//  MultiMidi
//
//  Created by Pro Tools on 10/19/23.
//

import Cocoa

@objc protocol MtcMidiDelegate{
    
    @objc optional func showTcDigits(_ tc : String)
    @objc optional func showTcDigits(_ tc : String, _ tcType : Int)
    @objc optional func mtcLocked(_ lockState : NSNumber)
    
}

class MtcMidi: NSObject {
    
    var swiftMidi : SwiftMidi?
    @objc var mtcMidiDelegate : MtcMidiDelegate?
    
    var rxMtc : [UInt8] = [0,0,0,0] // hhmmssff
    var lastGoodRx : [UInt8] = [0,0,0,0]{
        didSet{
            
            let tcType = self.lastGoodRx[0] >> 5
            
            DispatchQueue.main.async { [] in

                let delim = tcType == 2 ? ";" : ":"
                                
                let str = String(format: "%02d:%02d:%02d%@%02d", (self.lastGoodRx[0] & 0x1f),self.lastGoodRx[1],self.lastGoodRx[2],delim,self.lastGoodRx[3])
                
                self.mtcMidiDelegate?.showTcDigits!(str)
            }
       }
        
    }
    var filterMtc : [UInt8] = [0,0,0,0]
    var isLocked = NSNumber(0){
        didSet{
            
            DispatchQueue.main.async { [] in
                
                self.mtcMidiDelegate?.mtcLocked!(self.isLocked)
            }

        }
    }
    var timer : Timer?  // time out in 1/2 second

    override init() {
        super.init()
        
        swiftMidi = SwiftMidi(self, "MTC", .IN_AND_OUT)
        swiftMidi?.loopInToOut = true;
        
    }
}
// MARK: ---------- SwiftMidiDelegate ----------------
extension MtcMidi :SwiftMidiDelegate{
    
    func mtcService(_ mtc : UInt8, _ sender : SwiftMidi){
        
        let mtcIndex = Int(mtc >> 4) & 7
        
        switch(mtcIndex){
            case 0:
                
            rxMtc[3] &= 0x10
            rxMtc[3] += mtc & 0xf
                break
                
            case 1:
                
            rxMtc[3] &= 0xf
            rxMtc[3] += (mtc & 1) << 4 // 000 yyyyy
                break
                
            case 2:
                
            rxMtc[2] &= 0x30
            rxMtc[2] += mtc & 0xf
                break
                
            case 3:
                
                rxMtc[2] &= 0xf
                rxMtc[2] += (mtc & 3) << 4 // 00 yyyyyy
                rxMtc = incrTc(rxMtc)
                tcFilter()
                break
                
            case 4:
                
                rxMtc[1] &= 0x30
                rxMtc[1] += mtc & 0xf
                break
                
            case 5:

                rxMtc[1] &= 0xf
                rxMtc[1] += (mtc & 3) << 4 // 00 yyyyyy
                break
                
            case 6:

                rxMtc[0] &= 0x70
                rxMtc[0] += mtc & 0xf
                break
                
            case 7:
                rxMtc[0] &= 0xf
                rxMtc[0] += (mtc & 7) << 4 // 0 xx yyyyy, xx is tc type
                    
                rxMtc = incrTc(rxMtc)
                tcFilter()
                break
            
        default:
            break
        }

    }
    
    func incrTc(_ tc : [UInt8]) -> [UInt8]{
        
        let tcType = (tc[0] >> 5) & 3
        
        var hh : UInt8 = tc[0] & 0x1f
        var mm : UInt8 = tc[1] & 0x3f
        var ss : UInt8 = tc[2] & 0x3f
        var ff : UInt8 = tc[3] & 0x1f
        
        ff += 1
        
        switch(tcType){

        case 1: // 25
            
            if(ff >= 25){
                ff = 0
                ss += 1
            }
            break
        case 0: // 24
            if(ff >= 24){
                ff = 0
                ss += 1
            }
            break
        default:
            if(ff >= 30){
                ff = 0
                ss += 1
            }
            break
        }
        
        if(ss >= 60){
            ss = 0
            mm += 1
            
            if tcType == 2{
                ff = (mm % 10 == 0) ? 0 : 2 // every minute except the 10's
            }
       }
        
        if(mm >= 60){
            mm = 0
            hh += 1
        }
        
        if(hh >= 24){
            hh = 0
        }
        
        hh = (tc[0] & 0x60) + hh    // put tc type in hh
        
        return [hh,mm,ss,ff]
    }
    
    func tcFilter(){
        
        filterMtc = incrTc(filterMtc)
        
        if filterMtc == rxMtc{
            lastGoodRx = rxMtc
            isLocked = NSNumber(1)
        }else{
            isLocked = NSNumber(0)
        }
        
        filterMtc = rxMtc
        
        timer?.invalidate()
        
        // if there is no mtc for 0.5 seconds, clear the lock indicator
        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(timerService), userInfo: nil, repeats: false)

        return;
    }
    @objc func timerService(){
        
        isLocked = NSNumber(0)
    }
}
