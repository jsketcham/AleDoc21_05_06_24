//
//  Annunciator.m
//  TestAnnunciator
//
//  Created by James Ketcham on 11/15/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import "Annunciator.h"
#import "AleDelegate.h"
#import "MatrixWindowController.h"

@interface Annunciator()

#define LEADING_EDGE_TIMEOUT 0.3

@end

@implementation Annunciator

@synthesize state = _state;
@synthesize text = _text;
@synthesize index = _index;
@synthesize onIndex = _onIndex;
@synthesize offIndex = _offIndex;

- (void)drawRect:(NSRect)dirtyRect {
    
    [super drawRect:dirtyRect];
    
    // Drawing code here.
    
}
// -----------------------------------
// First Responder Methods
// -----------------------------------

- (BOOL)acceptsFirstResponder
{
    return YES;
}
-(void)mouseDown:(NSEvent *)theEvent{
    [super mouseDown:theEvent];
    
    AleDelegate *aleDelegate = (AleDelegate *)[NSApp delegate];
    
    // we needed reh/rec/pb for testing, the reh/rec/pb annunciators have tags
    // added ahead/in/past for testing
    switch(self.tag){
        case 200:
            aleDelegate.matrixWindowController.rehRecPb = MODE_CONTROL_REHEARSE;
            break;  // REHEARSE
        case 201:
            aleDelegate.matrixWindowController.rehRecPb = MODE_CONTROL_RECORD;
            break;  // RECORD
        case 202:
            aleDelegate.matrixWindowController.rehRecPb = MODE_CONTROL_PLAYBACK;
            break;  // PLAYBACK
        case 203:
            aleDelegate.matrixWindowController.aheadInPast = MODE_AHEAD;
            break;  // AHEAD
        case 204:
            aleDelegate.matrixWindowController.aheadInPast = MODE_IN;
            break;  // IN
        case 205:
            aleDelegate.matrixWindowController.aheadInPast = MODE_PAST;
            break;  // PAST
        default: break;
    }
    
//    if(_delegate) [_delegate showDropdown:self];
    
}
-(void)awakeFromNib{
    
//    [self setWantsLayer: YES];  // edit: enable the layer for the view.  Thanks omz
//    
//    self.layer.borderWidth = 1.0;
//    self.layer.cornerRadius = 3.0;
//    self.layer.masksToBounds = YES;

    _point = 13.0;
    _text = @"";
    _onIndex = GREEN_INDEX;
    _offIndex = CONTROL_INDEX;
    _mixedIndex = YELLOW_INDEX;    // we want to show yellow for servers that have not been set
    
    [self setState:NSControlStateValueOff];
}
//-(void)toggleState{
//    
//    if(_state == NSOnState) [self setState:NSControlStateValueOff];
//    else [self setState:NSOnState];
//}
#pragma mark -
#pragma mark ------------- setters/getters ------------------

-(void)setOffIndex:(NSInteger)offIndex{
    
    NSInteger currentOffIndex = _offIndex;
    _offIndex = offIndex;
    if(currentOffIndex == _index) [self setIndex:_offIndex];
}
-(NSInteger)offIndex{
    return _offIndex;
}
-(void)setOnIndex:(NSInteger)onIndex{
    NSInteger currentOnIndex = _onIndex;
    _onIndex = onIndex;
    if(currentOnIndex == _index) [self setIndex:_onIndex];
}
-(NSInteger)onIndex{
    return _onIndex;
}

-(void)setIndex:(NSInteger)index{
    _index = index;
    switch (index) {
            
        default: [self setTextColor:[NSColor blackColor]]; [self setBackColor:[NSColor clearColor]]; break;
        case GREEN_INDEX: [self setTextColor:[NSColor whiteColor]]; [self setBackColor:[NSColor greenColor]]; break;
        case RED_INDEX: [self setTextColor:[NSColor whiteColor]]; [self setBackColor:[NSColor redColor]]; break;
        case BLUE_INDEX: [self setTextColor:[NSColor whiteColor]]; [self setBackColor:[NSColor blueColor]]; break;  // make this a light blue
        case WHITE_INDEX: [self setTextColor:[NSColor blackColor]]; [self setBackColor:[NSColor whiteColor]]; break;
        case CONTROL_INDEX: [self setTextColor:[NSColor blackColor]]; [self setBackColor:[NSColor controlColor]]; break;
        case YELLOW_INDEX: [self setTextColor:[NSColor blackColor]]; [self setBackColor:[NSColor yellowColor]]; break;
    }
    
    //
    // draw text in backImage
    _backImage = [[NSImage alloc] initWithSize:self.frame.size];
    
    // font background is color of pixel 0,0 of _backImage
    NSFont *font = [NSFont systemFontOfSize:_point];//[NSFont fontWithName:@"Helvetica" size:13.0];
    
    NSDictionary *attrsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                     font,NSFontAttributeName,
                                     _backColor,NSBackgroundColorAttributeName,
                                     _textColor,NSForegroundColorAttributeName,
                                     nil];
    
    if(_text == nil) _text = @"";   // no empty strings
    
    NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:_text attributes:attrsDictionary];
    
    NSBezierPath *path = [[NSBezierPath alloc] init];
    
    [path setLineWidth:1];
    [path appendBezierPathWithRect:NSMakeRect(0, 0, _backImage.size.width, _backImage.size.height)];
    
    @try {
        [_backImage lockFocus];
        [_backColor set];
        [path fill];
        [attrString drawAtPoint:NSMakePoint(6, 2)];    // left justified?
        [_backImage unlockFocus];
        
        [self setImage:_backImage];
        
        NSRect rect = self.frame;
        rect.origin = NSMakePoint(0, 0);
        [self setNeedsDisplayInRect:rect];

    }
    @catch (NSException *exception) {
        NSLog(@"setIndex failed, index: %d",(int)index);
    }

}
-(NSInteger)index{
    return _index;
}
-(void)setText:(NSString *)text{
    _text = text;
    [self setIndex:_index];
}
-(NSString*)text{
    return _text;
}
-(void)leadingEdgeTimeoutService{
    
    //
    [_leadingEdgeTimer invalidate]; // FIXME is this OK? we need it invalid in leadingEdgeService:
    
    if(_delegate && [_delegate respondsToSelector:@selector(leadingEdgeService:)]){
        
        [_delegate performSelector:@selector(leadingEdgeService:) withObject:self];
        
    }
    
}
-(void)setState:(NSInteger)state{
    
    if(_lastEdge){
       _timeSinceLastUpEdge = [_lastEdge timeIntervalSinceNow];
    }
    else _timeSinceLastUpEdge = -10000;
//    NSLog(@"_timeSinceLastUpEdge: %4.3f",_timeSinceLastUpEdge);
    
    if(_state != state){
        
        [self setStateDidChange: true];
        
        if(_leadingEdgeTimer && _leadingEdgeTimer.isValid) [_leadingEdgeTimer invalidate];
        
        switch (state) {
            case NSControlStateValueOn:
                _state = state;
                
                [self setIndex:_onIndex];
                [self setLastEdge:[NSDate date]];   // detect leading edge of toggling indicators
                [self setLeadingEdgeTimer:[NSTimer scheduledTimerWithTimeInterval:LEADING_EDGE_TIMEOUT target: self selector:@selector(leadingEdgeTimeoutService) userInfo:nil repeats: NO]];
                
                break;
            case NSControlStateValueOff:
                _state = state;
                [self setIndex:_offIndex];
                break;
            default:
                _state = NSControlStateValueMixed;
                [self setIndex:_mixedIndex];
                break;
        }
        
    }else [self setStateDidChange: false];
}
-(NSInteger)state{
    return _state;
}


@end
