//
//  ItemView.m
//  AleDoc
//
//  Created by James Ketcham on 10/16/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//  ItemView is a view with a background color
//

#import "ItemView.h"

@implementation ItemView
@synthesize isSelected = _isSelected;
@synthesize backImage = _backImage;

-(id)init{
    
    self = [super init];
    if(self){
        
        
    }
    return self;
}
-(void)awakeFromNib{
    
    [self invalidateRect];
    
}

- (void)drawRect:(NSRect)dirtyRect {
    
    [_backImage drawInRect:dirtyRect fromRect:dirtyRect operation:NSCompositingOperationCopy fraction:1.0];    // background color
    
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}
-(void)drawBackImage:(NSSize)size{
    
    NSBezierPath *path = [[NSBezierPath alloc] init];
    NSRect rect = NSMakeRect(0, 0, size.width, size.height);
    [path appendBezierPathWithRect:rect];
    
    NSColor *theSelectedColor = [NSColor colorWithCalibratedRed:.7 green:.85 blue:1 alpha:1];   // a light blue color if we are selected
    
    [self setBackImage:[[NSImage alloc] initWithSize:size]];
    [[self backImage] lockFocus];
    [(_isSelected ? theSelectedColor : [NSColor controlColor]) set];    // controlColor if we are not selected
    [path fill];
    [[self backImage] unlockFocus];
}
-(void)invalidateRect{
    
    [self drawBackImage:self.frame.size];
    
    NSRect rect = self.frame;
    rect.origin = NSMakePoint(0, 0);
    [self setNeedsDisplayInRect:rect];  // redraw the entire view
    
}
-(void)mouseDown:(NSEvent *)event
{
//    NSLog(@"mouseDown in ItemView");
//    [self setIsSelected:!_isSelected];    // TODO we would like to click on the item view to select it
}
#pragma mark -
#pragma mark ----------------- setters/getters

-(void)setIsSelected:(bool)isSelected{
    _isSelected = isSelected;
    [self invalidateRect];  // redraw on selection/deselection
}
-(bool)isSelected{
    
    return _isSelected;
    
}

@end
