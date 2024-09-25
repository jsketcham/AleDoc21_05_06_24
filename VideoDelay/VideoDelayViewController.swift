//
//  VideoDelayViewController.swift
//  AleDoc21
//
//  Created by Pro Tools on 7/26/23.
//

import Cocoa
import AppKit
import SwiftUI

class VideoDelayViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        print("VideoDelayViewController viewDidLoad")
        // Do view setup here.
    }
    
}
class ContentViewController: NSHostingController<ContentView> {
    
    //https://stackoverflow.com/questions/69316938/nshostingcontroller-view-does-not-respect-hosted-content-size

    required init?(coder: NSCoder) {
        super.init(coder: coder, rootView: ContentView())
    }
}
