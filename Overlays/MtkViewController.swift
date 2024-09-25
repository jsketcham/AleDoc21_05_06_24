//
//  MtkViewController.swift
//  AleDoc21
//
//  Created by Pro Tools on 1/23/23.
//

import Cocoa

class MtkViewController: NSViewController {

    @objc var streamerRenderer : StreamerRenderer?
    @objc var mtkView : MTKView?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        mtkView = self.view as? MTKView // less judder (nearly none)

        // clear background
        mtkView!.layer?.isOpaque = false
        mtkView!.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)

        mtkView!.device = MTLCreateSystemDefaultDevice()
        assert((mtkView!.device != nil), "Metal is not supported on this device")

        streamerRenderer = StreamerRenderer.init(metalKitView: mtkView!)
        assert((streamerRenderer != nil), "Renderer failed initialization")

        mtkView!.delegate = streamerRenderer
        mtkView!.wantsLayer = true  // layer-backed view (streamers, text, punches are layers)
    }
    
}
