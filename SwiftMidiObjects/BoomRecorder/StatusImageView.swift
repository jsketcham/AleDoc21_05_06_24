//
//  StatusImageView.swift
//  AleDoc21
//
//  Created by Pro Tools on 9/5/23.
//

import Cocoa

class StatusImageView: NSImageView {
    
    var timer : Timer?
    var state = 0

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        timer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(timerService), userInfo: nil, repeats: true)
        
        self.image = NSImage.init(contentsOf: Bundle.main.urlForImageResource("yellow16.png")!)
        
        state = 3   // so we can watch a down count
    }
    @objc func timerService(){
        
        if state > 0{
            state -= 1
        }
        
        let blue = NSImage.init(contentsOf: Bundle.main.urlForImageResource("blue16.png")!)
        let clear = NSImage.init(contentsOf: Bundle.main.urlForImageResource("clear16.png")!)

        switch state{
        case 0: self.image = clear; break;
        case 1: self.image = blue; break;
        default: break;
        }
        
    }
    @objc func status(_ status : Int){
        
        let red = NSImage.init(contentsOf: Bundle.main.urlForImageResource("red16.png")!)
        let green = NSImage.init(contentsOf: Bundle.main.urlForImageResource("green16.png")!)
        let yellow = NSImage.init(contentsOf: Bundle.main.urlForImageResource("yellow16.png")!)

        switch status{
        case BOOM_REC_STATUS.IDLE.rawValue: self.image = yellow; break
        case BOOM_REC_STATUS.ONLINE.rawValue: self.image = green; break
        case BOOM_REC_STATUS.RECORD.rawValue: self.image = red; break
        default: break
        }
        
        state = 4   // down counter
        
        
    }
    
}
