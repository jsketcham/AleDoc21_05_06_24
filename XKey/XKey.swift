//
//  XKey.swift
//  AleDoc21
//
//  Created by Pro Tools on 1/28/23.
//

import Foundation
import Cocoa

let objUSB = USBConnection.singleton
var objThread : Thread?

@objc class XKey : NSObject{
    
//    var connectTimer : Timer?
    
    override init() {
        super.init()

        objThread = Thread(target: objUSB, selector:#selector(USBConnection.initUsb), object: nil)
        objThread?.start()
   }
    
    @objc func setLEDForUnitID(_ unitID : Int,_ index : Int,_ on : Int){
        
         //can't hurt, can be called from a thread
        DispatchQueue.main.async { [] in
            objUSB.setLEDForUnitID(unitID,index,on)
        }
    }
    
//    @objc func xkeyLedsOff(){
//
//        //can't hurt, can be called from a thread
//        DispatchQueue.main.async { [] in
//            objUSB.setAllBlueOnOff(OnOffVal: false)
//             objUSB.setAllRedOnOff(OnOffVal: false)
//        }
//    }
    
    @objc func getDescriptor(){
        //can't hurt, can be called from a thread
        DispatchQueue.main.async { [] in
            objUSB.doSomething()
        }

    }
    @objc func setUnitID(_ unitID : Int){
        
        DispatchQueue.main.async { [] in
            objUSB.setUnitID(unitID)
        }

    }
    @objc func setGreenIndicatorVal(OnOffFlash: UInt8,_ unitID : Int){
        
        DispatchQueue.main.async { [] in
            objUSB.setGreenIndicatorVal(OnOffFlash: OnOffFlash, unitID)
        }

    }
    @objc func setRedIndicatorVal(OnOffFlash: UInt8,_ unitID : Int){
        
        DispatchQueue.main.async { [] in
            objUSB.setRedIndicatorVal(OnOffFlash: OnOffFlash, unitID)
        }

    }
    
    @objc func setGreenRed(_ green : Bool, _ red : Bool,_ unitID : Int){
        
        DispatchQueue.main.async { [] in
            objUSB.setGreenRed(green,red,unitID)
        }
    }
    
    @objc func setAllBlueOnOff(OnOffVal: Bool,_ unitID : Int){
        
        DispatchQueue.main.async { [] in
            objUSB.setAllBlueOnOff(OnOffVal:OnOffVal,unitID)
        }
   }

}
