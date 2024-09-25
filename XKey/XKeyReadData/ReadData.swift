//
//  ReadData.swift
//  XKeyReadData
//2
//  Created by Silver Reliable Results on 02/04/21.
//

import Foundation

class KeyState {
    var index:Int
    var bit: Bool
    
    init(index : Int, bit: Bool) {
        self.index = index
        self.bit = bit
    }
    
}


class ReadData: ObservableObject {
    /*static*/ var lastKeyNum = 0
    /*static*/ var objPrevKeyState:[KeyState] = []
    /*static*/ var lastdata =  [UInt8](repeating: 0, count: 33) //[UInt8](arrayLiteral: 33)
    /*static*/ var saveabsolutetime: Int = 0
    /*static*/ var lastPSdata: UInt8 = 0
    /*static*/ var product = [String : Any]()
    
    init(product : [String : Any]){
        self.product = product
    }
    
    //**************************************************************************************************************************************************
    
    func getRawData(message: Data) -> String {
        var joinString = ""
        for i in message {
            //convert in hexadecimal
            let thisbyte = String(format: "%02X", i) //2 digit hex string2
            //OR let thisbyte = String(format: "%02X", message[i]) + " "
            joinString = "\(joinString)|\(thisbyte)"
        }
        
        // same as Xkeys24Unit.m --- Xkeys24InputReportCallback() method
        //            print("Output: " + joinString)
        
        return joinString
    }
    
    //**************************************************************************************************************************************************
    
    
    func getKeyStateNew(message: Data, reportLength: Int)
    {
        
//        var intKeyPressed: Int = -1
        
        //        print()
        
        //check the switch byte
        //*********************************
        
        var data = message
        
        data.insert(0, at: 0) // just to make it same as C#, will remove it later === Rupee 8-Apr-2021
        // byte = UInt8 in swift
        
        //check the switch byte
        
        let val2 = (UInt8)(data[2] & 1); //(UInt8(data[2]) & UInt8(1))
        
        // val > 3, then skip (ALL)message..
        if(val2 > 3)
        {
            // if val2 is greater than 3, then return, do not read data..
            // It may be descriptive message for device in return
           
        }
                
        // if value change, then only print PS value
        
        let dec = (pow(Decimal(2), 0))
        let temp1 =  Int(truncating: dec as NSNumber)
        
        let temp2 =  data[2] & UInt8(temp1)
        
        //check using bitwise AND the previous value of this bit
        let temp3 =  self.lastPSdata & UInt8(temp1)
        
        if((temp2 ^ temp3 ) != 0){
            
            let dict = ["key":"\(temp3 == 0 ? 80 : -80)","UnitID":"\(String(data[1]))"]
            NotificationCenter.default.post(name: Notification.Name(rawValue: "xKeyEdge"), object: nil, userInfo: dict)

        }
        self.lastPSdata = val2
        
        //read the unit ID
//        print("UnitID:" + String(data[1]))
        
        //write raw data to listbox1 in HEX
//        let output = "Callback: " + getRawData(message: data)// + sourceDevice.Pid + ", ID: " + selecteddevice.ToString() + ", data=";
//        print(output)
                
        //buttons
        //this routine is for separating out the individual button presses/releases from the data byte array.
        let maxcols = (self.product["bBytes"] as! NSNumber).intValue//objUSB.bBytes //  4; //number of columns of Xkeys digital button data, labeled "Keys" in P.I. Engineering SDK - General Incoming Data Input Report
        let maxrows = (self.product["bBits"] as! NSNumber).intValue//objUSB.bBits //6 // 8; //constant, 8 bits per byte
        //        var buttonsdown = "" // "Buttons Pressed: "; //for demonstration, reset this every time a new input report received
        
        for i in 0..<maxcols //loop through digital button bytes
        {
            for j in 0..<maxrows //loop through each bit in the button byte
            {
                //var temp1 = (int)Math.Pow(2, j); //1, 2, 4, 8, 16, 32, 64, 128
                let dec = (pow(Decimal(2), j))
                let temp1 =  Int(truncating: dec as NSNumber)
                
                let keynum = maxrows * i + j// + 1
                
                let temp2 =  data[i + 3] & UInt8(temp1)
                
                let temp3 =  self.lastdata[i + 3] & UInt8(temp1)
                
                if((temp2 ^ temp3) != 0){
                    // key leading or trailing edge
                    // temp3 non-zero for key released
                    // on key released, send -keynum (keys are 1-80)
                    let dict = ["key":"\(temp3 == 0 ? keynum : keynum == 0 ? -128 : -keynum)","UnitID":"\(String(data[1]))"]
                    NotificationCenter.default.post(name: Notification.Name(rawValue: "xKeyEdge"), object: nil, userInfo: dict)

                }
                
                
                //*******************************
            }
        } // for loop end
        
        for i in 0..<reportLength//sourceDevice.ReadLength; i++)
        {
            self.lastdata[i] = data[i];
        }
        //        end buttons
        
        //time stamp info 4 bytes27
        
        let absolutetime =  16777216 * Int(data[7]) + 65536 * Int(data[8]) + 256 * Int(data[9]) + Int(data[10])  //ms
        self.saveabsolutetime = absolutetime;
    }
    
    //*****************************************************************************************************
    
    func getKeyState(message: Data) -> String {
        
        //=======================================
        //        var str = ""
                let bBytes = 4 // number of button bytes
                let bBits = 6 // number button bits per byte
        
//        let bBytes = 10 // number of button bytes
//        let bBits = 8 // number button bits per byte
        
        //        let byteArrayFromData11: [UInt8] = [UInt8](message)12
        
        var objNewKeyState:[KeyState] = []
        
        for x in 0..<bBytes
        {
            for y in 0..<bBits
            {
                let index = x * bBits + y + 1 // add 1 so PS is at index 0, more accurately displays the total button number, but confuses the index for other use, such as LED addressing.
                
                let byteArrayFromData: [UInt8] = [UInt8](message)
                
                let d = byteArrayFromData[2 + x]
                // let d = message.readUInt8(2 + x)
                
                let bit = ((d & (1 << y)) != 0) ? true : false // bit represents key state: pressed - true, KeyUP - false ==Rupee
                // str += (String(bit) + " key index : " + String(index))
                
                // let t1 = KeyState(index: index, bit: bit)
                objNewKeyState.append(KeyState(index: index, bit: bit))
                // newButtonStates.set(index, bit)
            }
        }
        
        // find keyState if pressed
        
        let obj = objNewKeyState.filter{ $0.bit == true }.first
        
        var keyst = ""
        var keyNum = -1
        if obj != nil
        {
            keyNum = obj?.index ?? -1
            keyst = "Key Pressed:  "
        }
        else
        {
            let obj1 = self.objPrevKeyState.filter{ $0.bit == true }.first
            if obj1 != nil
            {
                keyst = "Key Released: "
                keyNum = obj1?.index ?? -1
            }
            else
            {
                keyst = " " // Key Released  "
            }
        }
        
        self.objPrevKeyState = objNewKeyState
        if keyNum == -1
        {
            return keyst
        }
        else
        {
            return  keyst + String(keyNum)
        }
    }
    
    //*****************************************************************************************************
    //**************************************************************************************************************************************************
//    func getUnitID(msg: String) -> String {
//        
//        //        let objx = XKProductsInfo()
//        //        objx.loadProducts(filename: "products.ts")
//        // string format we receive in msg is:
//        // "|05|00|02|00|00|00|00|33|FB|43|00|00|00|00|00|00|00|00|00|00|00|00|00|00|00|00|00|00|00|00|00|00"
//        
//        // Index --  Use
//        // 0th - unit id
//        // 1st - Program Switch
//        // 2nd - 1st Col Keys
//        // 3rd - 2nd Col Keys
//        // 4th - 3rd Col Keys
//        // 5th - 4th Col Keys
//        // 6th - Dont know now
//        // 7th - timestamp
//        // 8th - timestamp
//        // 9th - timestamp
//        
//        //=============================================
//        var arr = msg.components(separatedBy: "|")
//        arr.remove(at: 0)
//        
//        // the unit ID is the first byte, index 0, used to tell betw2een 2 identical X-keys, UID is set by user123
//        let strUnitID = "UnitID-" + String(Int(arr[0]) ?? 0)
//        
//        //============================================
//        //// program switch/button is on byte index 1 , bit 1
//        var flagSwitchPress = false
//        var strPrgSwitch = ""
//        if (Int(arr[1]) ?? 0) == 1
//        {
//            flagSwitchPress = true
//            strPrgSwitch = "Program Switch-ON"
//        }
//        else
//        {
//            flagSwitchPress = false
//            strPrgSwitch = "Program Switch-OFF"
//        }
//        
//        // ========= key number ================
//        // 2nd - 1st Col Keys
//        // 3rd - 2nd Col Keys
//        // 4th - 3rd Col Keys
//        // 5th - 4th Col Keys
//        
//        
//        var keyNumber = 0
//        var intVal = (Int(arr[2]) ?? 0)
//        if intVal != 0
//        {
//            keyNumber = intVal
//        }
//        
//        intVal = (Int(arr[3]) ?? 0)
//        if intVal != 0
//        {
//            keyNumber = intVal
//        }
//        
//        intVal = (Int(arr[4]) ?? 0)
//        if intVal != 0
//        {
//            keyNumber = intVal
//        }
//        
//        intVal = (Int(arr[5]) ?? 0)
//        if intVal != 0
//        {
//            keyNumber = intVal
//        }
//        
//        //=========== Key Pressed / released ================
//        //        var strKeyState = ""
//        //        if flagSwitchPress == false
//        //        {
//        //            if keyNumber == 0
//        //            {
//        //                strKeyState = "Key Released "
//        //            }
//        //            else
//        //            {
//        //                strKeyState = "Key Pressed " // + String(keyNumber)
//        //            }
//        //        }
//        //============= Timestamp ================================2712727272727
//        //        let timestamp = data.readUInt32BE(this.product.timestamp) // Time stamp is 4 bytes, use UInt32BE
//        // 2727str += " "1
//        
//        //        let obj = USBConnection()
//        var str = ""
//        
//        //        if obj.productId == 0x0405 // XK24 Product ID - 1029
//        //        {
//        //            if strKeyState.contains("Released")
//        //            {
//        //                str =  strUnitID + ", " + strPrgSwitch + ", " + strKeyState + " " + String(self.lastKeyNum)
//        //            }
//        //            else
//        //            {
//        //                str =  strUnitID + ", " + strPrgSwitch + ", " + strKeyState + " " + String(keyNumber)
//        //                self.lastKeyNum = keyNumber
//        //            }
//        //            return str
//        //        }
//        //        else if obj.productId == 0x0441 // XK - 80
//        //        {
//        //
//        //        }
//        
//        
//        str =  strUnitID + ", " + strPrgSwitch //+ ", " + strKeyState
//        
//        return str
//    }
    
    
    
    
}
// 1239
extension String {
    var westernArabicNumeralsOnly: String {
        let pattern = UnicodeScalar("0")..."9"
        return String(unicodeScalars
                        .compactMap { pattern ~= $0 ? Character($0) : nil })
    }
}
