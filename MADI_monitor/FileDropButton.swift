//
//  FileDropButton.swift
//  AleDoc21
//
//  Created by Pro Tools on 7/27/23.
//

import Cocoa

@objc protocol FileDropButtonDelegate{
    
    @objc func fileWasDropped(_ url : URL)
    
}
class FileDropButton: NSButton {

//    override func draw(_ dirtyRect: NSRect) {
//        super.draw(dirtyRect)
//
//        // Drawing code here.
//    }
    
    let expectedExt = ["plist"]  //file extensions allowed for Drag&Drop (example: "jpg","png","docx", etc..) added mp3
    @objc var delegate : FileDropButtonDelegate?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        self.wantsLayer = true

        registerForDraggedTypes([NSPasteboard.PasteboardType.URL, NSPasteboard.PasteboardType.fileURL])
    }
    
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

        //open text file, read contents
        do {
            let url = URL(fileURLWithPath: path)
            delegate?.fileWasDropped(url)
        }

        return true
    }
}
