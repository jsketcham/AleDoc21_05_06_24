//
//  TextView.swift
//  TextView
//
//  Created by Jim on 7/25/22.
//  Font panel: text color changes only if selected
// because we want to show the text where it will be, not
// at the top

import Cocoa

struct TextRect{
    
    var rect : NSRect?
    var alignment : NSTextAlignment
}

enum Anchor : Int32{
    case TOP_LEFT,BOTTOM_LEFT,TOP_RIGHT,BOTTOM_RIGHT,HIDDEN
}
// resizing choices
enum Resize : Int32{
    case NONE,LEFT,RIGHT,TOP,BOTTOM,TOP_LEFT,BOTTOM_LEFT,TOP_RIGHT,BOTTOM_RIGHT
}

class TextView: NSTextView {
    
    // 2.10.02
    var progressLayer = CALayer()
    @objc var progress : Double = 0.0{
        
        // if non-zero,show progress (duration in seconds)
        didSet{
            
            if self.isFullFrame{
                return
            }
            
            if progress == 0.0{
                
                progressLayer.removeFromSuperlayer()
                backingLayer.removeFromSuperlayer()
                
            }else{
                
                if progressLayer.superlayer == nil{
                    
                    backingLayer.frame = textRect.rect!
                    backingLayer.zPosition = BACKING_Z
                    backingLayer.backgroundColor = self.backgroundColor.cgColor

                    let height = backingLayer.frame.size.height
                    let width = backingLayer.frame.size.width
                            
                    let anim = CABasicAnimation(keyPath: #keyPath(CALayer.bounds))
                    anim.fromValue = CGRect(x: 0, y: 0, width: 0, height: height)
                    anim.toValue = CGRect(x: 0, y: 0, width: width, height: height)
                    anim.duration = progress
                    anim.repeatCount = 1
                    
                    progressLayer.anchorPoint = CGPoint(x: 0.0, y: 0.0)
                    progressLayer.frame = backingLayer.frame
                    progressLayer.zPosition = backingLayer.zPosition + 0.1
                    progressLayer.backgroundColor = self.textColor?.cgColor

                    progressLayer.removeAllAnimations()
                    backingLayer.removeAllAnimations()
                    
                    scrollView?.superview!.layer?.addSublayer(backingLayer)
                    scrollView?.superview!.layer?.addSublayer(progressLayer)
                    
                    // from CATransaction documentation
                    CATransaction.setCompletionBlock {
                        self.onKillProgressBar(self)
                    }
                    CATransaction.begin()
                    progressLayer.add(anim, forKey: #keyPath(CALayer.bounds))
                    CATransaction.commit()
               }
                
            }
            
        }
    }
    @IBAction func onKillProgressBar(_ sender: Any) {
        
        progressLayer.removeFromSuperlayer()
        backingLayer.removeFromSuperlayer()
    }

    @objc var opacity : Double = 1.0{
        didSet{
            
            if opacity == Double(self.layer!.opacity){return}
            
            let anim = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
            anim.fromValue = self.layer?.opacity
            anim.toValue = opacity // sets how quickly the image fades out
            anim.duration = fadeDuration
            anim.isRemovedOnCompletion = true

            CATransaction.begin()
            self.layer?.removeAllAnimations()
            self.layer?.add(anim, forKey: #keyPath(CALayer.opacity))
            CATransaction.commit()
            
            self.layer?.opacity = Float(opacity)    // where it ends after animation

        }
    }
    
    var context = 0
    
    var backingLayer = CALayer()
    var isAnimated = true
    
    var scrollView : NSScrollView?   // our parent view, for positioning and sizing
    var dragStart : NSPoint?
    var resize : Resize = .NONE
    
    var isFullFrame = false{
        didSet{
            
            if(isFullFrame && text.count == 0){
                self.string = key   // show something in the text box for setting font
            }else{
//                print("\(text)")
                self.string = text
            }
            setTextBounds()
        }
    }
    var key = "none"
    @objc var text : String = "none"{
        didSet{

//            print("TextView \(key) \(text)")
//            // Last take: 1
//            if text.contains("Last take: 1"){
//                print("two take counts?")
//            }
            
            // no fade if text does not change
            if !self.string.isEqual(text){
                self.string = text
                setTextBounds()
            }
            
            self.fadeDuration = 0.1 // fast fadein
//            self.opacity = 1.0  // we want to see the text
        }
    }
    var fontName = "Arial"{
        didSet{
            UserDefaults.standard.set(fontName, forKey: "\(key)fontName")
        }
    }
    var fontTraitMask = NSFontTraitMask(){
        didSet{
            UserDefaults.standard.set("\(fontTraitMask.rawValue)", forKey: "\(key)fontTraitMask")
        }
    }
    var point = 24.0{
        
        didSet{
            UserDefaults.standard.set("\(point)", forKey: "\(key)point")
        }
    }
    var anchor : Anchor = .TOP_LEFT{
        didSet{
            
            // don't store .HIDDEN, so it is never used on power up
            if anchor != .HIDDEN{
                UserDefaults.standard.set("\(anchor.rawValue)", forKey: "\(key)anchor")
            }
            
            setTextBounds()

        }
    }
    var topLeftRect : TextRect = TextRect(rect: NSRect(x: 100.0, y: 100.0, width: 400.0, height: 400.0), alignment: .left){
    
        didSet{
            
            UserDefaults.standard.set(NSStringFromRect(topLeftRect.rect!), forKey: "\(key)topLeftRect")
            UserDefaults.standard.set("\(topLeftRect.alignment.rawValue)", forKey: "\(key)topLeftRectAlignment")

        }
    }
    var bottomLeftRect : TextRect = TextRect(rect: NSRect(x: 100.0, y: 100.0, width: 400.0, height: 400.0), alignment: .left){
    
        didSet{
            
            UserDefaults.standard.set(NSStringFromRect(bottomLeftRect.rect!), forKey: "\(key)bottomLeftRect")
            UserDefaults.standard.set("\(bottomLeftRect.alignment.rawValue)", forKey: "\(key)bottomLeftRectAlignment")

        }
    }
    var topRightRect : TextRect = TextRect(rect: NSRect(x: 100.0, y: 100.0, width: 400.0, height: 400.0), alignment: .left){
    
        didSet{
            
            UserDefaults.standard.set(NSStringFromRect(topRightRect.rect!), forKey: "\(key)topRightRect")
            UserDefaults.standard.set("\(topRightRect.alignment.rawValue)", forKey: "\(key)topRightRectAlignment")
        }
        
    }
    var bottomRightRect : TextRect = TextRect(rect: NSRect(x: 100.0, y: 100.0, width: 400.0, height: 400.0), alignment: .left){
    
        didSet{
            
            UserDefaults.standard.set(NSStringFromRect(bottomRightRect.rect!), forKey: "\(key)bottomRightRect")
            UserDefaults.standard.set("\(bottomRightRect.alignment.rawValue)", forKey: "\(key)bottomRightRectAlignment")

        }
    }
    
    var textRect : TextRect{
        get{
            switch anchor{
            case .TOP_LEFT : return topLeftRect
            case .TOP_RIGHT: return topRightRect
            case .BOTTOM_LEFT: return bottomLeftRect
            case .BOTTOM_RIGHT: return bottomRightRect
            default: return topLeftRect
            }
        }
        set{
            switch anchor{
            case .TOP_LEFT : topLeftRect = newValue; break
            case .TOP_RIGHT: topRightRect = newValue; break
            case .BOTTOM_LEFT: bottomLeftRect = newValue; break
            case .BOTTOM_RIGHT: bottomRightRect = newValue; break
            default: break
            }
            
            setTextBounds() // after setting rects because setTextBounds uses textRect

        }
    }
    
    @objc var fadeDuration : Double = 0.2{
        didSet{
            UserDefaults.standard.set("\(fadeDuration)", forKey: "\(key)fadeDuration")
        }
    }
    
    func setKey(_ key : String){

        self.key = key
        self.wantsLayer = true  // because we want a backing layer
        self.layer?.cornerRadius = 7.0  // looks better with rounded corners
        self.layer?.zPosition = TEXT_Z
        
        if let sv = superview?.superview as? NSScrollView{
            scrollView = sv // a fact, if we are in scrollview/clipview/textview
        }

//        self.usesFontPanel = true // already set in IB
//        self.allowsDocumentBackgroundColorChange = true   // already set in IB
//        self.isEditable = false // keeps us from typing in the window
        
        addMenuItems()
        
        // we want to be notified when the font panel is dismissed
//        NotificationCenter.default.addObserver(self, selector: #selector(panelOcclusionChanged(_:)), name: NSFontPanel.didChangeOcclusionStateNotification, object: nil)

        // set defaults
        
        let dict : [String : Any] = [
            "\(key)topLeftRect" : NSStringFromRect(topLeftRect.rect!),
            "\(key)topLeftRectAlignment" : "\(bottomLeftRect.alignment.rawValue)",
            "\(key)bottomLeftRect" : NSStringFromRect(bottomLeftRect.rect!),
            "\(key)bottomLeftRectAlignment" : "\(topLeftRect.alignment.rawValue)",
            "\(key)topRightRect" : NSStringFromRect(topRightRect.rect!),
            "\(key)topRightRectAlignment" : "\(topRightRect.alignment.rawValue)",
            "\(key)bottomRightRect" : NSStringFromRect(bottomRightRect.rect!),
            "\(key)bottomRightRectAlignment" : "\(bottomRightRect.alignment.rawValue)",
            "\(key)fontName" : fontName,
            "\(key)point" : "\(point)",
            "\(key)fontTraitMask" : "\(fontTraitMask.rawValue)",
            "\(key)color_r" : "1.0",
            "\(key)color_g" : "1.0",
            "\(key)color_b" : "1.0",
            "\(key)color_a" : "1.0",
            "\(key)bgcolor_r" : "0.0",
            "\(key)bgcolor_g" : "0.0",
            "\(key)bgcolor_b" : "0.0",
            "\(key)bgcolor_a" : "1.0",
            "\(key)anchor" : "\(anchor.rawValue)",
            ]
        let defaults = UserDefaults.standard
        defaults.register(defaults: dict)
        // recall settings
        
        recallDefaults()

        // finish setup
        
        // set to stored colors, font
//        self.textColor = color
//        self.backgroundColor = bgColor
        self.font = NSFont(name: fontName, size: point)
        self.font = NSFontManager.shared.convert(self.font!, toHaveTrait: fontTraitMask)
        
        text = key  // erased when AleDoc connects

    }
    func recallDefaults(){
        
        let defaults = UserDefaults.standard
        
        if let s = defaults.string(forKey: "\(key)topLeftRect")
           ,let s2 = defaults.string(forKey: "\(key)topLeftRectAlignment"){
            
            topLeftRect = TextRect( rect: NSRectFromString(s),alignment: NSTextAlignment(rawValue: Int(s2)!) ?? .left)
        }
        if let s = defaults.string(forKey: "\(key)bottomLeftRect")
           ,let s2 = defaults.string(forKey: "\(key)bottomLeftRectAlignment"){
            
            bottomLeftRect = TextRect( rect: NSRectFromString(s),alignment: NSTextAlignment(rawValue: Int(s2)!) ?? .left)
        }
        if let s = defaults.string(forKey: "\(key)topRightRect")
           ,let s2 = defaults.string(forKey: "\(key)topRightRectAlignment"){
            
            topRightRect = TextRect( rect: NSRectFromString(s),alignment: NSTextAlignment(rawValue: Int(s2)!) ?? .left)
        }
        if let s = defaults.string(forKey: "\(key)bottomRightRect")
           ,let s2 = defaults.string(forKey: "\(key)bottomRightRectAlignment"){
            
            bottomRightRect = TextRect( rect: NSRectFromString(s),alignment: NSTextAlignment(rawValue: Int(s2)!) ?? .left)
        }
        if let s = defaults.string(forKey: "\(key)fontName"){
            
            fontName = s
        }
        if let s = defaults.string(forKey: "\(key)point"){
            
            point = Double(s)!
        }
        if let s = defaults.string(forKey: "\(key)fontTraitMask"){
            
            fontTraitMask = NSFontTraitMask(rawValue: UInt(s)!)
        }

        if  let r = defaults.string(forKey: "\(key)color_r"),
            let g = defaults.string(forKey: "\(key)color_g"),
            let b = defaults.string(forKey: "\(key)color_b"),
            let a = defaults.string(forKey: "\(key)color_a"){
            
            textColor = NSColor(red: Double(r)!, green: Double(g)!, blue: Double(b)!, alpha: Double(a)!)
            
        }
        if  let r = defaults.string(forKey: "\(key)bgcolor_r"),
            let g = defaults.string(forKey: "\(key)bgcolor_g"),
            let b = defaults.string(forKey: "\(key)bgcolor_b"),
            let a = defaults.string(forKey: "\(key)bgcolor_a"){
            
            backgroundColor = NSColor(red: Double(r)!, green: Double(g)!, blue: Double(b)!, alpha: Double(a)!)
            
        }
        if let s = defaults.string(forKey: "\(key)anchor"){
            
            anchor = Anchor(rawValue: Int32(s)!) ?? .TOP_LEFT
        }
        if let s = defaults.string(forKey: "\(key)fadeDuration"){
            
            fadeDuration = Double(s) ?? 0.0
        }

    }
    
    override func didChangeText() {
        super.didChangeText()
        setTextBounds() // for the case where we are manually entering text
    }
    
    func setTextBounds(text : String,textColor : NSColor,backgroundColor : NSColor){
        
        self.textColor = textColor   // sets self.textColor
        self.backgroundColor = backgroundColor   // sets self.backgroundColor
        self.string = text
        
        setTextBounds()
    }
    
    func putTextOnScreen(){
        
        // force on-screen, for when we 'text next screen' to different sized monitors
        
        // keep origin on-screen
        if((textRect.rect?.origin.x)! < 0){

//            print("offscreen left")
            var rect = textRect.rect
            rect?.origin.x = 0
            textRect.rect = rect
        }
        if((textRect.rect?.origin.y)! < 0){

//            print("offscreen bottom")
            var rect = textRect.rect
            rect?.origin.y = 0
            textRect.rect = rect
        }
        
        // check for textRect inside the window frame
        
        // avoid an error if there is no window
        if let frameSize = self.window?.frame.size,
        var point = textRect.rect?.origin{
            
            point.x += textRect.rect!.width
            point.y += textRect.rect!.height

            // keep below the title bar
            if(point.y > (frameSize.height - self.window!.titlebarHeight)){
    //            print("offscreen top")
                var rect = textRect.rect
                rect?.origin.y -= point.y - (frameSize.height - self.window!.titlebarHeight)
                textRect.rect = rect
            }
            if(point.x > frameSize.width){
                
    //            print("offscreen right")
                var rect = textRect.rect
                rect?.origin.x -= point.x - frameSize.width
                textRect.rect = rect

            }
        }
    }
    
    func setTextBounds(){
        
        setSelectedRange(NSRange(location: string.count, length: 0))    // deselect text
                
        backingLayer.removeFromSuperlayer()    // can't hurt

        let alignmentSetting = NSMutableParagraphStyle()
        alignmentSetting.alignment = textRect.alignment
        alignment = textRect.alignment

        // font name, size, and attributes have already been set
        let attrs : [NSAttributedString.Key : Any] = [NSAttributedString.Key.font: self.font as Any,
                                                      NSAttributedString.Key.foregroundColor : textColor as Any,
                                                      NSAttributedString.Key.backgroundColor : backgroundColor as Any,
                                                      NSAttributedString.Key.paragraphStyle : alignmentSetting]
        
        let size = NSSize(width: (textRect.rect?.size.width)!, height: Double.greatestFiniteMagnitude)

        var bounds = NSString(string: self.string).boundingRect(
            with: size,
            options: NSString.DrawingOptions.usesLineFragmentOrigin,
            attributes: attrs,
            context: nil)
        
        // we are in a scrollview/clipview, add the vertical scroll bar width to our width
        let scrollerWidth = NSScroller.scrollerWidth(for: NSControl.ControlSize(rawValue: (scrollView?.verticalScroller?.controlSize)!.rawValue) ?? NSControl.ControlSize.regular, scrollerStyle: NSScroller.Style.overlay)
        
        bounds.size.width += scrollerWidth
        bounds.origin = textRect.rect!.origin   // origin of boundingRect() is (0,0)
//        print("scrollerWidth \(scrollerWidth)")
        
        bounds.size.width += scrollerWidth / 2
        bounds.size.height += scrollerWidth / 2 // get rid of flashing scroll bar
        
        if bounds.size.width > textRect.rect!.size.width{
            bounds.size.width = textRect.rect!.size.width
        }
        
        // position by anchor setting
        switch anchor {
        case .TOP_LEFT:
            bounds.origin.y += textRect.rect!.size.height
            bounds.origin.y -= bounds.size.height
            
            if textRect.alignment == .center{
                
                bounds.origin.x += textRect.rect!.size.width / 2
                bounds.origin.x -= bounds.size.width / 2

            }
            
            break
        case .BOTTOM_LEFT:
            
            if textRect.alignment == .center{
                
                bounds.origin.x += textRect.rect!.size.width / 2
                bounds.origin.x -= bounds.size.width / 2

            }
            
            break
        case .TOP_RIGHT:
            bounds.origin.y += textRect.rect!.size.height
            bounds.origin.y -= bounds.size.height
            
            bounds.origin.x += textRect.rect!.size.width
            bounds.origin.x -= bounds.size.width
            
            if textRect.alignment == .center{
                
                bounds.origin.x -= textRect.rect!.size.width / 2
                bounds.origin.x += bounds.size.width / 2

            }

            break
        case .BOTTOM_RIGHT:
            bounds.origin.x += textRect.rect!.size.width
            bounds.origin.x -= bounds.size.width
            if textRect.alignment == .center{
                
                bounds.origin.x -= textRect.rect!.size.width / 2
                bounds.origin.x += bounds.size.width / 2

            }
            break
            
        case .HIDDEN:
            break
        }
                
        // set this after all calcs are done, or it jumps around

        if string.isEmpty || anchor == .HIDDEN{
            // no string or hidden, hide content
            bounds.size = NSSize(width: 0.0, height: 0.0)
        }

        scrollView?.frame = bounds
        scrollView?.borderType = .noBorder
        scrollView?.hasVerticalScroller = false

        // fade animation
        
        let anim = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        anim.fromValue = 0.0
        anim.toValue = 1.0
        anim.duration = fadeDuration
        anim.isRemovedOnCompletion = true
        
        CATransaction.begin()
        
        if fadeDuration == 0.0 || !isAnimated{
            layer!.removeAllAnimations()   // no fade in or no animation
        }else{
            layer!.add(anim, forKey: #keyPath(CALayer.opacity))
        }
       
        CATransaction.commit()

        // backing layer
        
        if isFullFrame{
            backingLayer.frame = textRect.rect!
            backingLayer.backgroundColor = NSColor.lightGray.cgColor
            backingLayer.zPosition = BACKING_Z
            
            CATransaction.begin()
            backingLayer.removeAllAnimations()   // no animations
            CATransaction.commit()
            
            scrollView?.superview!.layer?.addSublayer(backingLayer)

        }

    }
    func saveSettings(){
        
        // settings don't get saved by NSFontPanel or NSColorPanel

        let fontManager = NSFontManager.shared

        fontTraitMask = fontManager.traits(of: self.font!)
        point = Double(self.font!.pointSize)
        fontName = font!.fontName
//        textColor = super.textColor
//        backgroundColor = super.backgroundColor

    }
    @objc func nextAnchor(){
        
        switch(anchor){
        case .TOP_LEFT: anchor = .BOTTOM_LEFT; break
        case .BOTTOM_LEFT: anchor = .BOTTOM_RIGHT; break
        case .BOTTOM_RIGHT: anchor = .TOP_RIGHT; break
        case .TOP_RIGHT: anchor = .HIDDEN; break
        default: anchor = .TOP_LEFT; break
        }
        
    }
    // MARK: ------- actions ------------
    
    // MARK: ------- mouse ------------

    override func mouseEntered(with event: NSEvent) {
//        print("mouse entered")
        setPopupMenuState() // show our settings
        
        super.mouseEntered(with: event)
    }
    override func mouseDown(with event: NSEvent) {

        print("\(key) mouseDown \(event.locationInWindow)")
        
        if NSEvent.modifierFlags.contains(.control){
            Swift.print("control key pressed")
            
        }

        dragStart = event.locationInWindow
        isAnimated = false
        
        resize = .NONE  // default
        
        if isOnTopBorder(dragStart!){
            
            if isOnleftBorder(dragStart!) || isOnRightBorder(dragStart!){
                
                NSCursor.crosshair.set()
                resize = isOnleftBorder(dragStart!) ? .TOP_LEFT : .TOP_RIGHT
                
            }else{
                
                NSCursor.resizeUpDown.set()
                resize = .TOP
            }
            
        }else if isOnBottomBorder(dragStart!){
            
            if isOnleftBorder(dragStart!) || isOnRightBorder(dragStart!){
                
                NSCursor.crosshair.set()
                resize = isOnleftBorder(dragStart!) ? .BOTTOM_LEFT : .BOTTOM_RIGHT
                
            }else{
                
                NSCursor.resizeUpDown.set()
                resize = .BOTTOM
            }

        }else if (isOnleftBorder(dragStart!) || isOnRightBorder(dragStart!)){
            
            NSCursor.resizeLeftRight.set()
            resize = isOnleftBorder(dragStart!) ? .LEFT : .RIGHT
        }else{
            
            resize = .NONE
            NSCursor.openHand.set() // window is being dragged
        }

    }
    override func mouseDragged(with event: NSEvent) {
        
        if let _ = self.dragStart{
            let xDelta = event.locationInWindow.x - dragStart!.x
            let yDelta = event.locationInWindow.y - dragStart!.y
            
            onResize(CGPoint(x: xDelta, y: yDelta))
            putTextOnScreen()
        }
        self.dragStart = event.locationInWindow

    }
    override func mouseUp(with event: NSEvent) {
        print("mouseUp in \(key)")
        isAnimated = true
        NSCursor.arrow.set()
    }
    let MIN_SIZE = 20.0   // don't let windows have negative width or height
    
    func onResize(_ delta : CGPoint){
        
        // resize by the delta
        
        guard var rect = textRect.rect else{
            return
        }
        
        switch resize{
            
        case .NONE:
            // moving the frame
            rect.origin.x += delta.x;
            rect.origin.y += delta.y

            break
        case .LEFT:
            rect.origin.x += delta.x;
            rect.size.width -= delta.x;
            break
        case .RIGHT:
            rect.size.width += delta.x;
            break
        case .TOP:
            rect.size.height += delta.y;
            break
        case .BOTTOM:
            rect.size.height -= delta.y;
            rect.origin.y += delta.y;
            
            break
        case .TOP_LEFT:
            rect.origin.x += delta.x;
            rect.size.width -= delta.x;
            rect.size.height += delta.y;
            break
        case .BOTTOM_LEFT:
            
            rect.size.height -= delta.y;
            rect.origin.y += delta.y;
            rect.size.width -= delta.x;
            rect.origin.x += delta.x;

            break
        case .TOP_RIGHT:
            rect.size.width += delta.x;
            rect.size.height += delta.y;
            break
        case .BOTTOM_RIGHT:
            rect.size.width += delta.x;
            rect.size.height -= delta.y;
            rect.origin.y += delta.y;
            break
        }
        
        if rect.size.width >= MIN_SIZE && rect.size.height >= MIN_SIZE{
            
            textRect.rect = rect   // calls textRec set
            
        }
    }

    var border = 15.0
    func isOnRightBorder(_ point : NSPoint) -> Bool{
        
        if !isFullFrame{return false}
        
        var rect = NSRect()
        
        rect.origin = backingLayer.frame.origin
        rect.origin.x -= border
        rect.origin.y -= border
        rect.origin.x += textRect.rect!.size.width
        rect.size .width = 2 * border
        rect.size.height = textRect.rect!.size.height + 2 * border
        
        return rect.contains(point)
    }
    func isOnTopBorder(_ point : NSPoint) -> Bool{
        
        if !isFullFrame{return false}
        
        var rect = NSRect()
        rect.origin = backingLayer.frame.origin
        rect.origin.x -= border
        rect.origin.y -= border
        rect.origin.y  += textRect.rect!.height
        rect.size .width = textRect.rect!.width + 2 * border
        rect.size.height = 2 * border
        
        return rect.contains(point)
    }
    func isOnBottomBorder(_ point : NSPoint) -> Bool{
        
        if !isFullFrame{return false}
        
        var rect = NSRect()
        rect.origin = backingLayer.frame.origin
        rect.origin.x -= border
        rect.origin.y -= border
        rect.size .width = textRect.rect!.width + 2 * border
        rect.size.height = 2 * border
        
        return rect.contains(point)
    }
    func isOnleftBorder(_ point : NSPoint) -> Bool{
        
        if !isFullFrame{return false}
        
        var rect = NSRect()
        rect.origin = backingLayer.frame.origin
        rect.origin.x -= border
        rect.origin.y -= border
        rect.size .width = 2 * border
        rect.size.height = textRect.rect!.height + 2 * border
        
        return rect.contains(point)
    }
    // MARK: ------- menu ------------
    @objc func leftAlign(_ sender: Any?){
        
//        print("leftAlign")
        textRect.alignment = .left

    }
    @objc func rightAlign(_ sender: Any?){
        
//        print("rightAlign")
        textRect.alignment = .right

    }
    @objc func centerAlign(_ sender: Any?){
        
//        print("centerAlign")
        textRect.alignment = .center

    }
    @objc func anchorTopLeft(_ sender: Any){
//        print("anchorTopLeft")
        self.string = "Anchor top left"
        anchor = .TOP_LEFT  // after string setting so size works
    }
    @objc func anchorTopRight(_ sender: Any){
//        print("anchorTopRight")
        self.string = "Anchor top right"
        anchor = .TOP_RIGHT
    }
    @objc func anchorBottomLeft(_ sender: Any){
//        print("anchorBottomLeft")
        self.string = "Anchor bottom left"
        anchor = .BOTTOM_LEFT
    }
    @objc func anchorBottomRight(_ sender: Any){
//        print("anchorBottomRight")
        self.string = "Anchor bottom right"
        anchor = .BOTTOM_RIGHT
    }
    @objc func showTextFrame(_ sender: Any){
//        print("showTextFrame")
        isFullFrame = !isFullFrame
        if isFullFrame{
            text = "Show text frame"
        }
    }
    @objc func toggleFadeIn(_ sender: Any){
        
        fadeDuration = fadeDuration == 0.0 ? 0.2 : 0.0
        
    }
    @objc func colorDidChange(sender:AnyObject) {
        if let cp = sender as? NSColorPanel {
            print("colorDidChange \(key) \(cp.color)")
//            punchColor = cp.color
//            showPunchFrame()
        }
    }

    // MARK: ------- add to our popup menu ------------
    
    //https://developer.apple.com/forums/thread/658198 is an interesting example
    
    let TOP_LEFT_LABEL = "Top left"
    let TOP_RIGHT_LABEL = "Top right"
    let BOTTOM_LEFT_LABEL = "Bottom left"
    let BOTTOM_RIGHT_LABEL = "Bottom right"
    let SHOW_TEXT_FRAME_LABEL = "Show text frame"
    let ANCHOR_LABEL = "Anchor"
    let ALIGNMENT_LABEL = "Alignment"
    let ALIGN_LEFT_LABEL = "Left"
    let ALIGN_CENTER_LABEL = "Center"
    let ALIGN_RIGHT_LABEL = "Right"
    let FADE_IN_LABEL = "Fade in"
    
    // add Anchor and isFullFrame to our menu

    func setAlignMenuState(_ item : NSMenuItem, _ alignment : NSTextAlignment){
        
        if let item = item.submenu?.item(withTitle: ALIGNMENT_LABEL){
            
            if let item = item.submenu?.item(withTitle: ALIGN_LEFT_LABEL){
                
                item.state = alignment == .left ? NSControl.StateValue.on : NSControl.StateValue.off
                
            }
            if let item = item.submenu?.item(withTitle: ALIGN_CENTER_LABEL){
                
                item.state = alignment == .center ? NSControl.StateValue.on : NSControl.StateValue.off
                
            }
            if let item = item.submenu?.item(withTitle: ALIGN_RIGHT_LABEL){
                
                item.state = alignment == .right ? NSControl.StateValue.on : NSControl.StateValue.off
                
            }

        }
        
    }
    
    func setPopupMenuState(){
        
        // set the state of the items we added
        if let item = menu?.item(withTitle: ANCHOR_LABEL){
            
            let topLeftItem = item.submenu?.item(withTitle: TOP_LEFT_LABEL)
            let topRightItem = item.submenu?.item(withTitle: TOP_RIGHT_LABEL)
            let bottomLeftItem = item.submenu?.item(withTitle: BOTTOM_LEFT_LABEL)
            let bottomRightItem = item.submenu?.item(withTitle: BOTTOM_RIGHT_LABEL)

            topLeftItem!.state = anchor == .TOP_LEFT ? NSControl.StateValue.on : NSControl.StateValue.off
            topRightItem!.state = anchor == .TOP_RIGHT ? NSControl.StateValue.on : NSControl.StateValue.off
            bottomLeftItem!.state = anchor == .BOTTOM_LEFT ? NSControl.StateValue.on : NSControl.StateValue.off
            bottomRightItem!.state = anchor == .BOTTOM_RIGHT ? NSControl.StateValue.on : NSControl.StateValue.off
            
            setAlignMenuState(topLeftItem!,topLeftRect.alignment)
            setAlignMenuState(topRightItem!,topRightRect.alignment)
            setAlignMenuState(bottomLeftItem!,bottomLeftRect.alignment)
            setAlignMenuState(bottomRightItem!,bottomRightRect.alignment)
            
        }
        
        if let item = menu?.item(withTitle: SHOW_TEXT_FRAME_LABEL){
            
            item.state = isFullFrame ? NSControl.StateValue.on : NSControl.StateValue.off
        }
        
        if let item = menu?.item(withTitle: FADE_IN_LABEL){
            
            item.state = fadeDuration != 0.0 ? NSControl.StateValue.on : NSControl.StateValue.off
        }
    }
    
    func alignItem(_ alignment : NSTextAlignment)-> NSMenuItem{
        
        let alignmentMenuItem = NSMenuItem(title: ALIGNMENT_LABEL, action: nil, keyEquivalent: "")
        let alignmentMenu = NSMenu(title: ALIGNMENT_LABEL)
        
        let leftItem = NSMenuItem(title: ALIGN_LEFT_LABEL, action: #selector(leftAlign(_:)), keyEquivalent: "")
        let centerItem = NSMenuItem(title: ALIGN_CENTER_LABEL, action: #selector(centerAlign(_:)), keyEquivalent: "")
        let rightItem = NSMenuItem(title: ALIGN_RIGHT_LABEL, action: #selector(rightAlign(_:)), keyEquivalent: "")

        alignmentMenu.addItem(leftItem)
        alignmentMenu.addItem(centerItem)
        alignmentMenu.addItem(rightItem)
        
        alignmentMenuItem.submenu = alignmentMenu
        
        return alignmentMenuItem

    }

    func addMenuItems(){
        
        if let _ = menu?.item(withTitle: ANCHOR_LABEL){
            return  // items already added (one menu for multiple TextView instances)
        }
        
        var itemSeparator = NSMenuItem.separator()
        menu?.addItem(itemSeparator)

        // anchor menu item
        let anchorMenuItem = NSMenuItem(title: ANCHOR_LABEL, action: nil, keyEquivalent: "")
        let anchorMenu = NSMenu(title: ANCHOR_LABEL)
        
        let topLeftMenuItem = NSMenuItem(title: TOP_LEFT_LABEL, action: #selector(anchorTopLeft(_:)), keyEquivalent: "")
        let topRightMenuItem = NSMenuItem(title: TOP_RIGHT_LABEL, action: #selector(anchorTopRight(_:)), keyEquivalent: "")
        let bottomLeftMenuItem = NSMenuItem(title: BOTTOM_LEFT_LABEL, action: #selector(anchorBottomLeft(_:)), keyEquivalent: "")
        let bottomRightMenuItem = NSMenuItem(title: BOTTOM_RIGHT_LABEL, action: #selector(anchorBottomRight(_:)), keyEquivalent: "")
        
        topLeftMenuItem.submenu = NSMenu(title: ALIGNMENT_LABEL)
        topLeftMenuItem.submenu?.addItem(alignItem(topLeftRect.alignment))
        topRightMenuItem.submenu = NSMenu(title: ALIGNMENT_LABEL)
        topRightMenuItem.submenu?.addItem(alignItem(topRightRect.alignment))
        bottomLeftMenuItem.submenu = NSMenu(title: ALIGNMENT_LABEL)
        bottomLeftMenuItem.submenu?.addItem(alignItem(bottomLeftRect.alignment))
        bottomRightMenuItem.submenu = NSMenu(title: ALIGNMENT_LABEL)
        bottomRightMenuItem.submenu?.addItem(alignItem(bottomRightRect.alignment))

        anchorMenu.addItem(topLeftMenuItem)
        anchorMenu.addItem(topRightMenuItem)
        anchorMenu.addItem(bottomLeftMenuItem)
        anchorMenu.addItem(bottomRightMenuItem)
        
        anchorMenuItem.submenu = anchorMenu
        menu?.addItem(anchorMenuItem)
        
        // show text frame menu item
        let showTextFrameItem = NSMenuItem(title: SHOW_TEXT_FRAME_LABEL, action: #selector(showTextFrame(_:)), keyEquivalent: "")
        
        menu?.addItem(showTextFrameItem)
        
        // show fade in item
        let fadeInItem = NSMenuItem(title: FADE_IN_LABEL, action: #selector(toggleFadeIn(_:)), keyEquivalent: "")
        
        menu?.addItem(fadeInItem)
        
        itemSeparator = NSMenuItem.separator()
        menu?.addItem(itemSeparator)
        
        Swift.print("addMenuItems did finish")

    }
    //MARK: -------- notifications ------------
    
//    @objc func panelOcclusionChanged(_ notification: Notification) {
//
//        // when NSFontPanel is dismissed, save the settings
//        // we would prefer a notification when the font changes, then we could not need this
//        // and changes would be saved when they happen
//
//        if let panel = notification.object as? NSFontPanel,
//           !panel.isVisible{
//
//            NSColorPanel.shared.orderOut(self)  // close the color panel, if any
//            saveSettings()                      // save our settings when font panel closes
//
//        }
//
//    }
    
//    // TODO: we may use this to rx notifications posted by AppDelegate
//    @objc override class func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
//
//        print("observeValue \(keyPath ?? "keyPath missing")")
//    }
    
}
extension NSWindow {
    // https://stackoverflow.com/questions/28955483/how-do-i-get-default-title-bar-height-of-a-nswindow
    var titlebarHeight: CGFloat {
        frame.height - contentRect(forFrameRect: frame).height
    }
}

