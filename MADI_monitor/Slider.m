//
//  Slider.m
//  AleDoc
//
//  Created by James Ketcham on 8/18/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import "Slider.h"
#import "Matrix.h"

@implementation Slider

@synthesize item = _item;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

//- (void)drawRect:(NSRect)dirtyRect
//{
//    [super drawRect:dirtyRect];
//    
//    // Drawing code here.
//}

-(void)mouseDown:(NSEvent *)theEvent{
    
//    NSLog(@"_slider %d",(int)self.tag);
    
    // Protools uses option-click for this, we do too
    if(theEvent.modifierFlags & NSEventModifierFlagOption){
        
        self.integerValue = FADER_0dB;  // set to default gain
        Matrix *matrix = (Matrix *)_item.representedObject;
        
        [matrix setToDefaultSliderValue:self.tag];
        
    }else [super mouseDown:theEvent];
    
}

@end
