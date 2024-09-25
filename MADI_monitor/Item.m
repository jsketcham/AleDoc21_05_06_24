//
//  Item.m
//  AleDoc
//
//  Created by James Ketcham on 8/15/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import "Item.h"
#import "Matrix.h"
//#import "ChannelNodeData.h"


@interface Item ()

@end

@implementation Item

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
        // Initialization code here.
    }
    return self;
}
-(void)awakeFromNib{
    
    self.slider0.item = self;
    self.slider1.item = self;
    self.slider2.item = self;
    self.slider3.item = self;
    self.slider4.item = self;
//    self.slider5.item = self;
//    self.slider6.item = self;
//    self.slider7.item = self;
//    self.sliderMaster.item = self;
}

//- (IBAction)onButton:(id)sender {
//    
//    Matrix *matrix = self.representedObject;
//    
////    [matrix buttonPressed:sender];    // matrix delegate uses the button tag
//}
-(void)mouseDown:(NSEvent *)theEvent{
    
    // testing
    NSLog(@"Item mouseDown");
}

@end
