//
//  PixelBufferDelay.swift
//  VideoDelay
//
//  Created by Pro Tools on 8/20/23.
//  is there a way to avoid deep copies?

import Cocoa

let STREAMING_DELAY = 0.00//0.166666  // the delay before we get the pixel buffer, for sync to audio

struct DelayItem{
    var pixelBuffer : CVPixelBuffer?
    var date : Date?
}
// try making NSimage, avoid the copy back of the CVPixelBuffer
struct ImageDelayItem{
    var nsImage : NSImage?
    var date : Date?
}

class PixelBufferDelay: NSObject {
    //
    var delayLine = [DelayItem]()
    var imageDelayLine = [ImageDelayItem]()
    var delaySeconds = 0.0
    
    override init() {
        super.init()
        
        // so we don't have to learn publish/subscribe
        UserDefaults.standard.addObserver(self, forKeyPath: "videoDelaySeconds", context: nil)
        delaySeconds = UserDefaults.standard.double(forKey: "videoDelaySeconds")
        print("PixelBufferDelay init")
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == "videoDelaySeconds"{
//            print("set delaySeconds from observeValue")
            delaySeconds = UserDefaults.standard.double(forKey: "videoDelaySeconds")
            
        }
    }
    
    var delayCtr = 0

    func delay(_ pixelBuffer : CVPixelBuffer?){
        
        
        if delaySeconds == 0.0{   // no delay, skip deep copies
            delayCtr = 0
            return
        }
        let now = Date()

        if let pixelBuffer = pixelBuffer{
            delayLine.append(DelayItem(pixelBuffer: pixelBuffer.copy(),date: Date()))  // a deep copy
        }
        
        if delayLine.count > 120{
            
            let countToRemove = delayLine.count - 120
            //
            delayLine.removeFirst(countToRemove)
            
        }
        
        self.overWrite(pixelBuffer) // another deep copy
        
        if delayCtr < 10{
            delayCtr += 1
            print("\(delayCtr) \(Date().timeIntervalSince(now))")
        }
    }
    
    func getDelayed() -> CVPixelBuffer?{
        
        if delayLine.count == 0{
            return nil
        }
        
        // check that the last few delayed items are late
        // reduce bouncing, we expect to remove 1 item.
        
        while Date().timeIntervalSince((delayLine.first?.date)!) > delaySeconds && delayLine.count > 1{
            
            delayLine.removeFirst() // the normal case, remove 1 item
            
            // if the next one is less than 20 ms, don't remove it
            // noise will ratchet down the delay line, then it will sit
            if (Date().timeIntervalSince((delayLine.first?.date)!) - delaySeconds) < 0.02{
                break
            }
            
        }
//        ctr += 1; ctr %= 60; if ctr == 0{print("delayLine.count \(delayLine.count)")}
        UserDefaults.standard.set(delayLine.count, forKey: "delayLineCount")
        return delayLine.first?.pixelBuffer
    }
    var ctr = 0
    
    func overWrite(_ imageBuffer : CVPixelBuffer?){
        
        if let imageBuffer = imageBuffer,
           let delayedPixelBuffer = getDelayed(){
            
            CVPixelBufferLockBaseAddress(delayedPixelBuffer, .readOnly)
            CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags())
            
            let srcPlanes = CVPixelBufferGetPlaneCount(delayedPixelBuffer)
            let destPlanes = CVPixelBufferGetPlaneCount(imageBuffer)
            
            // source and dest must have the same number of planes, bytes per row, and height
            if(srcPlanes == destPlanes){
                
                for plane in 0 ..< CVPixelBufferGetPlaneCount(delayedPixelBuffer) {
                    let dest = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, plane)
                    let source = CVPixelBufferGetBaseAddressOfPlane(delayedPixelBuffer, plane)
                    let height = CVPixelBufferGetHeightOfPlane(delayedPixelBuffer, plane)
                    let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(delayedPixelBuffer, plane)
                    let destHeight = CVPixelBufferGetHeightOfPlane(imageBuffer, plane)
                    let destBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, plane)
                    
                    if (height == destHeight) && (bytesPerRow == destBytesPerRow){
                        memcpy(dest, source, height * bytesPerRow)
                    }
                }
            }
            
            CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags())
            CVPixelBufferUnlockBaseAddress(delayedPixelBuffer, .readOnly)

        }
    }
    
    func delayImage(_ pixelBuffer : CVPixelBuffer?) -> NSImage?{
        // we want to avoid the 2nd copy
        // CALayer.content can be set from NSImage, with scaling
        // this has only a slight improvement over the 2 copy method, not worth the trouble
        // 4 ms for 2 copy, 3.3 ms for this
        
        if delaySeconds == 0.0{   // no delay, skip deep copies
            delayCtr = 0
            return nil
        }
        let now = Date()
        
        if let pixelBuffer = pixelBuffer{
            
            // make a NSImage from pixelBuffer
            // CALayer.content can be set from NSimage
            //https://stackoverflow.com/questions/10318260/cvpixelbufferref-to-nsimage
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext(options: nil)
            
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            
            let cgImage = context.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height))!
            
            let nsImage = NSImage(cgImage: cgImage, size: CGSize(width: width, height: height))
            
            imageDelayLine.append(ImageDelayItem(nsImage: nsImage, date: Date()))
        }
        
        
        // remove items that are older than now plus delaySeconds
        while Date().timeIntervalSince((imageDelayLine.first?.date)!) > delaySeconds && imageDelayLine.count > 1{
            
            imageDelayLine.removeFirst()
            
            // if the next one is less than 20 ms, don't remove it
            // noise will ratchet down the delay line, then it will sit
            if (Date().timeIntervalSince((imageDelayLine.first?.date)!) - delaySeconds) < 0.02{
                break
            }

        }
        if delayCtr < 10{
            delayCtr += 1
            print("\(delayCtr) \(Date().timeIntervalSince(now))")
        }

        return imageDelayLine.count > 0 ? imageDelayLine.first?.nsImage : nil
    }

}
// https://stackoverflow.com/questions/38335365/pulling-data-from-a-cmsamplebuffer-in-order-to-create-a-deep-copy
extension CVPixelBuffer {
func copy() -> CVPixelBuffer {
    precondition(CFGetTypeID(self) == CVPixelBufferGetTypeID(), "copy() cannot be called on a non-CVPixelBuffer")

    var _copy : CVPixelBuffer?
    CVPixelBufferCreate(
            nil,
            CVPixelBufferGetWidth(self),
            CVPixelBufferGetHeight(self),
            CVPixelBufferGetPixelFormatType(self),
            nil,
            &_copy)
    guard let copy = _copy else { fatalError() }

    CVBufferPropagateAttachments(self, copy)

    CVPixelBufferLockBaseAddress(self, .readOnly)
    CVPixelBufferLockBaseAddress(copy, CVPixelBufferLockFlags())

    for plane in 0 ..< CVPixelBufferGetPlaneCount(self) {
        let dest = CVPixelBufferGetBaseAddressOfPlane(copy, plane)
        let source = CVPixelBufferGetBaseAddressOfPlane(self, plane)
        let height = CVPixelBufferGetHeightOfPlane(self, plane)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(self, plane)

        memcpy(dest, source, height * bytesPerRow)
    }

    CVPixelBufferUnlockBaseAddress(copy, CVPixelBufferLockFlags())
    CVPixelBufferUnlockBaseAddress(self, .readOnly)

    return copy
  }
}
