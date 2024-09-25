//
//  USBConnection.swift
//  XKeyReadData
//
//  Created by Silver Reliable Results on 01/04/21.
//

import Foundation
import IOKit.hid

class USBConnection : NSObject {
    let vendorId = 0x05F3 // XK24 Vendor ID - 1523
//    let productId = 1089// XK80//0x0405 // XK24 Product ID - 1029
    //            let productId =  0x0441 // xk80- 1089== 0x0441,,, XK24- 0x0405
    
    let reportSize = 32 //Device specific
    static let singleton = USBConnection()
//    var device : IOHIDDevice? = nil
    
    static var countDevAttached = 0
    static var countDevRemoved = 0
    
//    let bBytes =  10// XK80//4 // number of button bytes, COl
//    let bBits =  8// XK80//6 // number button bits per byte, ROW
//
//    // For XK-24
    let reportSizeOutput = 35
//    let backLight2offset: Int = 80// XK80//32
//    let maxRows: Int = 8
    
    var products : Array<[String: Any]>?    // product definitions
    // unit ID and its dictionary,["device" : IOHIDDevice,"product" : dictionary]
    var devices = [IOHIDDevice : [String: Any]]()
    
    var setUnitID = false
    var unitID = 0
    
    struct Temp {
        var row: Int
        var col: Int
        
        init(row: Int, col: Int) {
            self.row = row
            self.col = col
        }
    }
    
    func input(_ inResult: IOReturn, inSender: UnsafeMutableRawPointer, type: IOHIDReportType, reportId: UInt32, report: UnsafeMutablePointer<UInt8>, reportLength: CFIndex) {
        
        let device : IOHIDDevice = Unmanaged.fromOpaque(inSender).takeUnretainedValue()

        let message = Data(bytes: report, count: reportLength)
        
        //        print("IN" + getInput())
        print("input: \([UInt8](message))")
       if message.count != 32
        {
            
        }
        
        //===========  XK24 =====612
        if message.count == 32
        {
            let msgBytes = [UInt8](message)
            
            if(msgBytes[1] == 0xd6){
                // getDescriptor
//                print("getDescriptor rx")
                var pid = UInt(msgBytes[12])
                pid <<= 8
                pid += UInt(msgBytes[11])
//                print("pid \(pid)")
                
                if let products = products{
                    
                    for product in products{
                        
                        if let pidArray = product["productId"] as? Array<NSNumber>{
                            
                            for item in pidArray{
                                
                                if item.intValue == pid{
                                    
                                    let dict = product as Dictionary
                                    let unitID = NSNumber(integerLiteral: Int(UInt(msgBytes[0])))
                                    // each device needs a ReadData object, has key change detectors
                                    let objReadData = ReadData(product: dict)
                                    // devices may have the same unitId
                                    devices[device] = ["unitID" : unitID,"product" : dict, "readData" : objReadData] as [String : Any]
                                    
                                    // message to host, we have a unit number and a product
                                    NotificationCenter.default.post(name: Notification.Name(rawValue: "xKeyDescriptor"), object: nil, userInfo: ["unitID" : unitID,"product" : dict])
                                    return

                                }
                                
                            }
                            
                        }
                        
                    }
                }
                return
            }
            
            if(setUnitID){
                setUnitID = false
                setUnitID(NewUnitVal: UInt8(unitID), device)
                getDescriptor(device)   // because unit ID is changing
                return
            }
            
            //************* get readable Data *********************
            
            // use correct bBytes, bBits
            if(devices[device] != nil){
                
                let dict = devices[device]!
                
                let objReadData : ReadData = dict["readData"] as! ReadData
                
                objReadData.getKeyStateNew(message: message, reportLength: reportLength)
            }
        }
    }
    
    
//    func individualBtnSendBacklight(keyNum: Int, lightval: Int)  {
//        if(keyNum > 0)
//        {
//            let t  = findBtnIndex(keyNum: keyNum)
//            if(t.row < 0)
//            {
//                print("Row less thn 0: " + String(t.row))
//                return
//            }
//
//            let ledIndexBlue: Int
//            ledIndexBlue = Int((t.col - 1) * maxRows + (t.row - 1)) // 8 is maxRows value
//
//            let ledIndexRed = ledIndexBlue + backLight2offset
//            print("col \(t.col) row \(t.row) ledIndexRed \(ledIndexRed) ledIndexBlue \(ledIndexBlue)")
//
//            //setToggle()
//            if(ledIndexBlue >= 0)
//            {
//                setIndividualBtnLight(KeyIndex: ledIndexBlue, color: "BLUE", OnOFFFlash: lightval,device)  // 0- off, 1- on, 2- flash
//                //   print("blueindex: " + String(ledIndexBlue))
//            }
//            else
//            {
//                print("error: blueindex : " + String(ledIndexBlue))
//
//            }
//
//            if(ledIndexRed >= 0)
//            {
//                setIndividualBtnLight(KeyIndex: ledIndexRed, color: "RED", OnOFFFlash: lightval,device)  // 0- off, 1- on, 2- flash
//                //  print("ledIndexRed: " + String(ledIndexRed))
//            }
//            else
//            {
//                print("error: ledIndexRed : " + String(ledIndexRed))
//            }
//
//
//        }
//    }
    
    
//    func findBtnIndex(keyNum: Int) -> Temp {
//
//
//        //********************************************
//
//        var row: Int = 0
//        var col: Int = 0
//
//        if (keyNum >= 0) {
//            // program switch is always on index 0 and always R:0, C:0 unless remapped by btnLocaion array
//
//            // program switch is always on index 0 and always R:0, C:0 unless remapped by btnLocaion array
//            //                       location.row = btnIndex - this.product.bBits * (Math.ceil(btnIndex / this.product.bBits) - 1)
//            //                       location.col = Math.ceil(btnIndex / this.product.bBits)
//
//            row = Int(Double(keyNum) - Double(bBits) * ceil( Double(keyNum) / Double(bBits) - 1))
//            //            print("Row " + String(row))
//
//            col = Int(ceil(Double(keyNum) / Double(bBits)))
//            //            print("col  " + String(col))
//
//        }
//        else
//        {
//            print("Error in findBtnIndex() : btnIndex value: " + String(keyNum) )
//        }
//        let location = Temp(row: row, col: col)
//
//        return location
//    }
    
    //    private _findBtnLocation(btnIndex: number): { row: number; col: number } {
    //            let location: { row: number; col: number } = { row: 0, col: 0 }
    //            // derive the Row and Column from the button index for many products
    //            if (btnIndex !== 0) {
    //                // program switch is always on index 0 and always R:0, C:0 unless remapped by btnLocaion array
    //                location.row = btnIndex - this.product.bBits * (Math.ceil(btnIndex / this.product.bBits) - 1)
    //                location.col = Math.ceil(btnIndex / this.product.bBits)
    //            }
    //            // if the product has a btnLocaion array, then look up the Row and Column
    //            if (this.product.btnLocation !== undefined) {
    //                location = {
    //                    row: this.product.btnLocation[btnIndex][0],
    //                    col: this.product.btnLocation[btnIndex][1],
    //                }
    //            }
    //            return location
    //        }
    
    
    
    
    func setToggle(_ device : IOHIDDevice?) {
        var bytes =  [UInt8](repeating: 0, count: 35)
        
        /// TOGGLE========
        bytes[0] = 0xb8  //184
        self.output(Data(bytes),device)
    }
    
    func setUnitID(NewUnitVal: UInt8,_ device : IOHIDDevice?) {
        var bytes =  [UInt8](repeating: 0, count: 35)
        
        // WRITE UNIT ID
        ///        [0] = '\xbd'
        ///        [1] = '\x05'
        bytes[0] = 0xbd //189 //command
        bytes[1] = NewUnitVal // 0x5 //New unit ID value, here 5
        
        self.output(Data(bytes),device)  // ON- 0x01,  OFF - 0x00,  Flash - 0x02
    }
    func setLEDForUnitID(_ unitID : Int,_ index : Int,_ on : Int){
        
        for key in devices.keys{
            
            if let dict = devices[key],
               let n = dict["unitID"] as? NSNumber,
               n == NSNumber(integerLiteral: unitID){
                setIndividualBtnLight(KeyIndex: index, OnOFFFlash: on, key)
            }
            
        }

    }

    func setIndividualBtnLight(KeyIndex: Int, OnOFFFlash: Int,_ device : IOHIDDevice?) {
        
//        print("setIndividualBtnLight KeyIndex:\(KeyIndex) OnOFFFlash:\(OnOFFFlash)")
        
        var bytes =  [UInt8](repeating: 0, count: 35)
        
        var OnOffFlashVal = UInt8(OnOFFFlash) //= (OnOFF == true) ? 0x01 : 0x00
        
        switch(OnOffFlashVal){
            case 0: break   // off
            case 1: break   // on
            default: OnOffFlashVal = 2; break   // flash
        }
        
        bytes[0] = 0xb5 // 181
        bytes[1] = UInt8(KeyIndex)  // blue < backLight2offset, red >= backLight2offset
        bytes[2] = OnOffFlashVal  // 1 - on, 0- off, 2 flash
        
        self.output(Data(bytes),device)
        
    }
    func setGreenRed(_ green : Bool, _ red : Bool, _ unitID: Int){
        
        for key in devices.keys{
            
            if let dict = devices[key],
               let n = dict["unitID"] as? NSNumber,
               n == NSNumber(integerLiteral: unitID){
                setGreenRed(green,red, key)
            }
            
        }

    }
    func setGreenRed(_ green : Bool, _ red : Bool, _ device : IOHIDDevice?){
        
        var bytes =  [UInt8](repeating: 0, count: 35)
        
        /// TOGGLE========
        //        bytes[0] = 0xb8  //184
        //================================
        // For Green on
        
        bytes[0] = 186 //179 //command
        bytes[1] = (red ? 0x80 : 0) + (green ? 0x40 : 0) //6
        
        self.output(Data(bytes),device)  // ON- 0x01,  OFF - 0x00,  Flash - 0x02

    }
    func setGreenIndicatorVal(OnOffFlash: UInt8,_ unitID : Int){
        
        for key in devices.keys{
            
            if let dict = devices[key],
               let n = dict["unitID"] as? NSNumber,
               n == NSNumber(integerLiteral: unitID){
                setGreenIndicatorVal(OnOffFlash: OnOffFlash, key)
            }
            
        }

    }
    func setGreenIndicatorVal(OnOffFlash: UInt8,_ device : IOHIDDevice?) {
        
        var bytes =  [UInt8](repeating: 0, count: 35)
        
        /// TOGGLE========
        //        bytes[0] = 0xb8  //184
        //================================
        // For Green on
        bytes[0] = 0xb3 //179 //command
        bytes[1] = 0x06 //6
        bytes[2] = OnOffFlash // 0x01
        
        self.output(Data(bytes),device)  // ON- 0x01,  OFF - 0x00,  Flash - 0x02
    }
    
    func setRedIndicatorVal(OnOffFlash: UInt8,_ unitID : Int){
        
        for key in devices.keys{
            
            if let dict = devices[key],
               let n = dict["unitID"] as? NSNumber,
               n == NSNumber(integerLiteral: unitID){
                setRedIndicatorVal(OnOffFlash: OnOffFlash, key)
            }
            
        }

    }
    func setRedIndicatorVal(OnOffFlash: UInt8,_ device : IOHIDDevice?) {
        var bytes =  [UInt8](repeating: 0, count: 35)
        
        /// TOGGLE========
        //        bytes[0] = 0xb8  //184
        //================================
        bytes[0] = 0xb3 //179 //command
        bytes[1] = 0x07 // 7 for red
        bytes[2] = OnOffFlash // ON- 0x01,  OFF - 0x00,  Flash - 0x02
        
        self.output(Data(bytes),device)
    }
    @objc func setAllBlueOnOff(OnOffVal: Bool,_ unitID : Int){
        
        for key in devices.keys{
            
            if let dict = devices[key],
               let n = dict["unitID"] as? NSNumber,
               n == NSNumber(integerLiteral: unitID){
                setAllBlueOnOff(OnOffVal: OnOffVal, key)
            }
            
        }
    }
    func setAllBlueOnOff(OnOffVal: Bool,_ device : IOHIDDevice?) {
//        print("setAllBlueOnOff \(OnOffVal)")
        var bytes =  [UInt8](repeating: 0, count: 35)
        
        var val: UInt8 = 0x00 // Off lights
        if(OnOffVal == true)
        {
            val = 0xff // on lights
        }
        bytes[0] = 0xb6 //182 //command
        bytes[1] = 0x0 //0 - Blue
        bytes[2] = val // 0xff // 255
        
        
        self.output(Data(bytes),device)
    }
    func setAllRedOnOff(OnOffVal: Bool,_ device : IOHIDDevice?) {
//        print("setAllRedOnOff \(OnOffVal)")
        var bytes =  [UInt8](repeating: 0, count: 35)
        
        var val: UInt8 = 0x00 // Off lights
        if(OnOffVal == true)
        {
            val = 0xff // on lights
        }
        bytes[0] = 0xb6 //182 //command
        bytes[1] = 0x1 //1 - Red
        bytes[2] = val // 0xff // 255
        
        self.output(Data(bytes),device)
    }
    
    
    func rebootDevice(_ device : IOHIDDevice?)  {
       
//        print("rebootDevice")
        //21. Reboot Device
        // Send this output report to reboot the device without having to unplug it. After sending this report the device must be re-enumerated.
        //print("Rebooting device..")
        
        var bytes =  [UInt8](repeating: 0, count: self.reportSizeOutput)
        bytes[0] = 0xee //238 to enumerate // 0xd6 // 214  Descriptor Data   //
        
        // same code as Output method, added here just to maintain flag: isEnumerating
        let data = Data(bytes)
        if (data.count > reportSizeOutput) {
            print("output data too large for USB report")
            return
        }
        
        let reportId : CFIndex = CFIndex(0) //data[0])
        if let blink1 = device {
           // print("Senting Reboot output: \([UInt8](data))")
            
            let deviceNameResult:IOReturn
            deviceNameResult = IOHIDDeviceSetReport(blink1, kIOHIDReportTypeOutput, reportId, [UInt8](data), data.count)
            if(deviceNameResult != kIOReturnSuccess) {
                print("Error in sending Data " + String(deviceNameResult))
            }
        }
        
        
    }
    
    //================================
    func output(_ data: Data,_ device : IOHIDDevice?) {
        
        if (data.count > reportSizeOutput) {
            print("output data too large for USB report")
            return
        }
        
        let reportId : CFIndex = CFIndex(0) //data[0])
        if let blink1 = device {
//            print("Sending output: \([UInt8](data))")
            
            let deviceNameResult:IOReturn
            deviceNameResult = IOHIDDeviceSetReport(blink1, kIOHIDReportTypeOutput, reportId, [UInt8](data), data.count)
            if(deviceNameResult != kIOReturnSuccess) {
                print("Error in sending Data " + String(deviceNameResult))
            }
        }
    }
    
    func connected(_ inResult: IOReturn, inSender: UnsafeMutableRawPointer, inIOHIDDeviceRef: IOHIDDevice!)
    {
        if USBConnection.countDevAttached == 0
        {
            let arr = String(inIOHIDDeviceRef.debugDescription).components(separatedBy: " ")
//            print("Device connected \(arr)")
            
//            setAllBlueOnOff(OnOffVal: false)
//            objUSB.setAllRedOnOff(OnOffVal: false)
//
//            NotificationCenter.default.post(name: Notification.Name(rawValue: "deviceConnected"), object: nil, userInfo: nil)
            

//            let st1 = String(inIOHIDDeviceRef.debugDescription)
//             let arr1 = String(inIOHIDDeviceRef.debugDescription).components(separatedBy: " ")
//              print(arr1)
            
            if arr.count > 11
            {
                // at index 11: Product name
                // index 7: Product ID
                // index 6: Vendor ID
                print(arr[11] + " " + arr[7] + " " + arr[6])
            }
            else
            {
                print(inIOHIDDeviceRef.debugDescription)
            }
            
            USBConnection.countDevAttached = 1
            USBConnection.countDevRemoved = 0
        }
        
        // It would be better to look up the report size and create a chunk of memory of that size1234522727272727
        let report = UnsafeMutablePointer<UInt8>.allocate(capacity: reportSize)
        
        //print("report size:" + String(reportSize))
        
        let inputCallback : IOHIDReportCallback = { inContext, inResult, inSender, type, reportId, report, reportLength in
            let this : USBConnection = Unmanaged<USBConnection>.fromOpaque(inContext!).takeUnretainedValue()
            this.input(inResult, inSender: inSender!, type: type, reportId: reportId, report: report, reportLength: reportLength)
        }
        
      
        //Hook up inputcallback
        let this = Unmanaged.passRetained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(inIOHIDDeviceRef!, report, reportSize, inputCallback, this)
        
//        print("USBConnection.count \(USBConnection.count)")
        
        // FIXME: what in the heck is going on here!
        if(USBConnection.count <= 2) // it calls it 3 times when device is connected, when set to 1, enumeration did not worked.. on 2 count it worked, don't know why  yet..to be fis by== Rupee 28 Apr
        {
            rebootDevice(inIOHIDDeviceRef)
            USBConnection.count = USBConnection.count + 1
        }
        else
        {
            USBConnection.count = USBConnection.count + 1
            
            setAllBlueOnOff(OnOffVal: false, inIOHIDDeviceRef)
            objUSB.setAllRedOnOff(OnOffVal: false, inIOHIDDeviceRef)
            self.getDescriptor(inIOHIDDeviceRef)

            NotificationCenter.default.post(name: Notification.Name(rawValue: "deviceConnected"), object: nil, userInfo: nil)
            
        }
        
    }
    
    static var count = 1
    
    func removed(_ inResult: IOReturn, inSender: UnsafeMutableRawPointer, inIOHIDDeviceRef: IOHIDDevice!) {
        
        // 3 because-- on re-run program Reboots device 3-4 times,  on reconnect mannualy Reboots device 1 time..Rupee 29 Apr 2021
        if USBConnection.count > 3 // USBConnection.countDevRemoved == 0
        {
            print("Device removed")
            print(inIOHIDDeviceRef.debugDescription)
            
            USBConnection.countDevAttached = 0
            USBConnection.countDevRemoved = 1
            
//            if(USBConnection.count > 3)
//            {
                USBConnection.count = 1
//            }
            
        }
        USBConnection.countDevAttached = 0
        NotificationCenter.default.post(name: Notification.Name(rawValue: "deviceDisconnected"), object: nil, userInfo: ["class": NSStringFromClass(type(of: self))])
    }
    func doSomething(){
        // TODO: all descriptors
        print("devices.count \(devices.count)")
    }
    func getDescriptor(_ device : IOHIDDevice?){
        
//        print("getDescriptor")
        var bytes =  [UInt8](repeating: 0, count: 35)
        bytes[0] = 0xd6 // 214  Descriptor Data
        self.output(Data(bytes),device)
    }
    func setUnitID(_ unitID : Int){
        
        self.unitID = unitID
        self.setUnitID = true
        // press any key to set unit ID
        
    }
    
    @objc func initUsb() {
        
        // get plist of supported products
        let url = Bundle.main.url(forResource: "xKeyProducts", withExtension: "plist")!
        
        if let array = NSArray(contentsOf: url) as? [[String : Any]] {
            products = array
            print("array.count \(array.count)")
        }

        // MARK: looking for PIE products, any will do
        let deviceMatch = [/*kIOHIDProductIDKey: productId,*/ kIOHIDVendorIDKey: vendorId]
        let managerRef = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        
        IOHIDManagerSetDeviceMatching(managerRef, deviceMatch as CFDictionary?)
        IOHIDManagerScheduleWithRunLoop(managerRef, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(managerRef, 0)
        
        let matchingCallback : IOHIDDeviceCallback = { inContext, inResult, inSender, inIOHIDDeviceRef in
            let this : USBConnection = Unmanaged<USBConnection>.fromOpaque(inContext!).takeUnretainedValue()
            this.connected(inResult, inSender: inSender!, inIOHIDDeviceRef: inIOHIDDeviceRef)
        }
        
        let removalCallback : IOHIDDeviceCallback = { inContext, inResult, inSender, inIOHIDDeviceRef in
            let this : USBConnection = Unmanaged<USBConnection>.fromOpaque(inContext!).takeUnretainedValue()
            this.removed(inResult, inSender: inSender!, inIOHIDDeviceRef: inIOHIDDeviceRef)
        }
        
        let this = Unmanaged.passRetained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(managerRef, matchingCallback, this)
        IOHIDManagerRegisterDeviceRemovalCallback(managerRef, removalCallback, this)
        
        RunLoop.current.run()
        
    }
}




