//
//  AudioPlayerViewController.swift
//  AleDoc21
//
//  Created by Pro Tools on 7/25/23.
//

import Cocoa
import AVFoundation

class AudioPlayerViewController: NSViewController{

    @IBOutlet weak var voiceCombo: NSComboBox!
    
    let synth = AVSpeechSynthesizer()
    @objc let speechVoices = AVSpeechSynthesisVoice.speechVoices()
    var speechVoicesUsed = Array<AVSpeechSynthesisVoice>()
    
    @IBOutlet weak var standardFillButton: SwiftDropButton!
    @IBOutlet weak var customFillButton: SwiftDropButton!
    
    // we have a speed problem with 'Rocko', 'Shelley', 'Eddy'
    // these are the two best voices
    let allowedVoices = ["Nicky","Aaron"]

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        synth.delegate = self
        
        voiceCombo.removeAllItems()
        
        for voice in speechVoices{
            
            if !voice.language.isEqual("en-US"){continue}
            if !allowedVoices.contains(voice.name){continue}
            
            print("\(voice.language) \(voice.name)")
            
            speechVoicesUsed.append(voice)
            voiceCombo.addItem(withObjectValue: voice.name)
            
        }
    }
    
    @IBAction func onVoiceCombo(_ sender: Any) {
        
        self.sayTake("This is a test of the \(voiceCombo.stringValue) voice" as NSString)

    }
    
    @IBAction func onSpeakButton(_ sender: Any) {
        
        self.sayTake("This is a test of the \(voiceCombo.stringValue) voice" as NSString)
    }
    
    @IBAction func onFillButton(_ sender: Any) {
        
        let button = sender as! SwiftDropButton
        
        let aleDelegate = NSApp.delegate as? AleDelegate
        aleDelegate?.setLEDForUnitID(9, Int32(button.tag), button.state == .on ? true : false)

        if  button.state == .on{
            
            var url : URL?
            
            if button.filePath == nil{
                (sender as! NSButton).state = .off
                return
            }
            
            url = URL(fileURLWithPath: button.filePath!)
            
            if url != nil{
                
                if let path = url?.path{
                    print("audio path: \(path)")
                    button.objCPlayFile.startAudio(path)
                    return
                }
                
                
//                do {
//                    button.avPlayer = try AVAudioPlayer(contentsOf: url!)
//                    button.avPlayer?.numberOfLoops = -1 // repeats
//                    button.avPlayer?.play()
//                } catch {
//                    // couldn't load file :(
//                    print("couldn't load file")
//                    (sender as! NSButton).state = .off
//                }
            }else{
                (sender as! NSButton).state = .off
            }
        }else{
            
            button.objCPlayFile.stopAudio()
            //button.avPlayer?.stop()
            
        }
    }
    
    @objc func sayTake(_ text : NSString){
        
        let aleDelegate = NSApp.delegate as? AleDelegate
        aleDelegate?.matrixWindowController.matrixView.autoSlate(true)
        
        let utterance = AVSpeechUtterance(string: text as String)
        // slider is 0-100, default speech rate is 0.5, range is 0.0 to 1.0
        // set speech rate from 1x go 2x (0.5 to 1.0)
        let rate = 0.5 + Double(UserDefaults.standard.integer(forKey: "speechRate")) / 600
        utterance.rate = Float(rate)
        print("rate \(utterance.rate)")

        for voice in speechVoicesUsed{
            
            if voice.name.isEqual(voiceCombo.stringValue){
                
                utterance.voice = voice
                synth.speak(utterance)
                return
           }
        }

    }

}
extension AudioPlayerViewController : AVSpeechSynthesizerDelegate{
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        
        let aleDelegate = NSApp.delegate as? AleDelegate
        aleDelegate?.matrixWindowController.matrixView.autoSlate(false)

    }
}
