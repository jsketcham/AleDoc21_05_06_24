//
//  SwiftDropButton.swift
//  AudioPlayer
//
//  Created by Pro Tools on 7/24/23.
// https://stackoverflow.com/questions/31657523/get-file-path-using-drag-and-drop-swift-macos

import Cocoa
import AVFoundation

let SWIFT_DROP_BUTTON_KEY = "SWIFT_DROP_BUTTON_KEY"

class SwiftDropButton: NSButton {

//    var avPlayer: AVAudioPlayer?
    var objCPlayFile = ObjCPlayFile()   // does a cross fade, 2.10.02

    var filePath: String?{
        set{
            
            UserDefaults.standard.set(newValue, forKey: "\(SWIFT_DROP_BUTTON_KEY)\(self.tag)")
            
        }
        get{
            return UserDefaults.standard.value(forKey: "\(SWIFT_DROP_BUTTON_KEY)\(self.tag)") as? String
        }
    }
    let expectedExt = ["caf","wav","mp3","aif"]  //file extensions allowed for Drag&Drop (example: "jpg","png","docx", etc..) added mp3
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        self.wantsLayer = true
//        self.layer?.backgroundColor = NSColor.gray.cgColor
        
        if let path = self.filePath{
            
            let name = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
            
            self.title = name
        }

        registerForDraggedTypes([NSPasteboard.PasteboardType.URL, NSPasteboard.PasteboardType.fileURL])
    }
    
//    override func draw(_ dirtyRect: NSRect) {
//        super.draw(dirtyRect)
//
//        // Drawing code here.
//    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if checkExtension(sender) == true {
//            self.layer?.backgroundColor = NSColor.blue.cgColor
            return .copy
        } else {
            return NSDragOperation()
        }
    }

    fileprivate func checkExtension(_ drag: NSDraggingInfo) -> Bool {
        guard let board = drag.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
              let path = board[0] as? String
        else { return false }

        let suffix = URL(fileURLWithPath: path).pathExtension
        for ext in self.expectedExt {
            if ext.lowercased() == suffix {
                return true
            }
        }
        return false
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
//        self.layer?.backgroundColor = NSColor.gray.cgColor
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
//        self.layer?.backgroundColor = NSColor.gray.cgColor
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let pasteboard = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
              let path = pasteboard[0] as? String
        else { return false }

        //GET YOUR FILE PATH !!!
        self.filePath = path
        Swift.print("FilePath: \(path)")
        let name = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        
        self.title = name

        return true
    }

}
