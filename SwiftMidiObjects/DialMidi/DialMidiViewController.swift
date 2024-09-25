//
//  DialMidiViewController.swift
//  AleDoc21
//
//  Created by Pro Tools on 9/7/23.
//

import Cocoa

let DIAL_MUTE_KEY = "DialMuteKey"
let DIAL_VALUE_KEY = "DialValueKey"

@objc class DialMidiViewController: NSViewController {
    
    @IBOutlet weak var statusImageView: StatusImageView!
    let DIAL_DICTIONARY_KEY = "dialDictionaryKey"
    
    @objc var dialMidiDictionaryArray = NSMutableArray()
    var swiftMidi : SwiftMidi?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        swiftMidi = SwiftMidi(self, "Dials", .IN_AND_OUT)

        // initialize from a plist
        willChangeValue(forKey: "dialMidiDictionaryArray")
        dialMidiDictionaryArray = NSMutableArray.init(array: NSArray.init(contentsOfFile: Bundle.main.path(forResource: "dialMidi", ofType: "plist")!)!)
        didChangeValue(forKey: "dialMidiDictionaryArray")
        
        if let data = UserDefaults.standard.data(forKey: DIAL_DICTIONARY_KEY){
            do{
                let unarch = try NSKeyedUnarchiver(forReadingFrom: data)

                willChangeValue(forKey: "dialMidiDictionaryArray")
                let array = unarch.decodeObject(of: [NSDictionary.self,NSArray.self,NSString.self], forKey: DIAL_DICTIONARY_KEY) as! NSMutableArray

                // set the cc's from stored values
                for i in 0..<dialMidiDictionaryArray.count{

                    for item in array{

                        if let title = (item as! NSDictionary)["Title"] as? String
                          ,let cc = (item as! NSDictionary)["CC"] as? String
                          ,let title2 = (dialMidiDictionaryArray[i] as! NSDictionary)["Title"] as? String
                          ,title == title2{

                            (dialMidiDictionaryArray[i] as! NSMutableDictionary)["CC"] = cc

                            break

                        }

                        break
                    }

                }

                didChangeValue(forKey: "dialMidiDictionaryArray")


            }catch{

            }
        }
        
    }
    @objc func sendConsoleMuteForKey(_ key : NSString){
        
        let muteKey = String(format: "%@_%@", DIAL_MUTE_KEY,key)
        let mute = UserDefaults.standard.bool(forKey: muteKey)

        for item in dialMidiDictionaryArray{
            
            let dict = item as! NSDictionary
            
            if (dict["key"] as! NSString) == key{
                
                let cc = UInt8((dict["CC"] as! NSString).intValue)
                let txMidi : [UInt8] = [0x90,cc,mute ? 127 : 0]
                swiftMidi?.midiClient?.midiTx(NSData(bytes: txMidi, length: txMidi.count))    // mute indication
//                print("sendConsoleMuteForKey \(txMidi[1]) \(txMidi[2])");
                
                break

            }
        }
        
    }
   //
}
// MARK: ------------ table view delegate ------------
extension DialMidiViewController : NSTableViewDelegate{
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        print("tableViewSelectionDidChange")
    }
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        print("textShouldEndEditing \(fieldEditor.string)")
        
        if let cc = Int(fieldEditor.string),
           cc >= 0 && cc <= 127{
            
            return true
        }
        return false
    }
    func controlTextDidEndEditing(_ obj: Notification) {
        
        // save the cc table
        let arch = NSKeyedArchiver(requiringSecureCoding: false)
        arch.encode(dialMidiDictionaryArray, forKey: DIAL_DICTIONARY_KEY)
        arch.finishEncoding()
        UserDefaults.standard.set(arch.encodedData, forKey: DIAL_DICTIONARY_KEY)

    }
    
}
// MARK: ---------- SwiftMidiDelegate ----------------
extension DialMidiViewController :SwiftMidiDelegate{
    
    @objc func noteOnService(_ midi : [UInt8], _ sender : SwiftMidi){
        //     Byte pingResponse[] = {0x90,0x00,0x7f};
        
        if midi[1] == 0{
            // ping response
            statusImageView.status(1)
            let bytes : [UInt8] = [0x90,0,0x7f]
            swiftMidi?.midiClient?.midiTx(NSData(bytes: bytes, length: bytes.count))    // ping response
           return
        }

        
        let cc = "\(midi[1])"   // cc as a string
        
      for item in dialMidiDictionaryArray{
            
            let dict = item as! NSDictionary
            
          if (dict["CC"] as! String) == cc{
              
              let key = dict["key"] as! String
              
              let muteKey = String(format: "%@_%@", DIAL_MUTE_KEY,key)
              let mute = !UserDefaults.standard.bool(forKey: muteKey)
              UserDefaults.standard.set(mute, forKey: muteKey)
              
              let aleDelegate = NSApp.delegate as! AleDelegate
              aleDelegate.sendDial(key)   // indicate on streamdeck, sends to console
              
//              var txMidi = midi; txMidi[2] = mute ? 127 : 0
//              swiftMidi?.midiClient?.midiTx(NSData(bytes: txMidi, length: txMidi.count))    // mute indication
              
              break
              
          }
        }
   }
    @objc func noteOffService(_ midi : [UInt8], _ sender : SwiftMidi){
        
        if midi[1] == 0{
            // ping response
            statusImageView.status(1)
            let bytes : [UInt8] = [0x90,0,0x7f]
            swiftMidi?.midiClient?.midiTx(NSData(bytes: bytes, length: bytes.count))    // ping response
           return
        }
    }
    @objc func controlChangeService(_ midi : [UInt8], _ sender : SwiftMidi){
        
        let cc = "\(midi[1])"   // cc as a string
        
      for item in dialMidiDictionaryArray{
            
            let dict = item as! NSDictionary
            
          if (dict["CC"] as! String) == cc{
              
              let key = dict["key"] as! String
              
              let valueKey = String(format: "%@_%@", DIAL_VALUE_KEY,key)
              UserDefaults.standard.set(midi[2], forKey: valueKey)
              
              let aleDelegate = NSApp.delegate as! AleDelegate
              aleDelegate.sendDial(key)
              break
              
          }
        }
        
    }

}

