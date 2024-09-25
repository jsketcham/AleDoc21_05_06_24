//
//  Item.h
//  AleDoc
//
//  Created by James Ketcham on 8/15/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Slider.h"

@class Slider;
@interface Item : NSCollectionViewItem
//- (IBAction)onButton:(id)sender;

@property (weak) IBOutlet Slider *slider0;
@property (weak) IBOutlet Slider *slider1;
@property (weak) IBOutlet Slider *slider2;
@property (weak) IBOutlet Slider *slider3;
@property (weak) IBOutlet Slider *slider4;
//@property (weak) IBOutlet Slider *slider5;
//@property (weak) IBOutlet Slider *slider6;
//@property (weak) IBOutlet Slider *slider7;
//@property (strong) IBOutlet Slider *sliderMaster;

@property (weak) IBOutlet NSButton *button0;
@property (weak) IBOutlet NSButton *button1;
@property (weak) IBOutlet NSButton *button2;
@property (weak) IBOutlet NSButton *button3;
@property (weak) IBOutlet NSButton *button4;
@property (weak) IBOutlet NSButton *button5;
@property (weak) IBOutlet NSButton *button6;
@property (weak) IBOutlet NSButton *button7;
@property (weak) IBOutlet NSButton *button8;
@property (weak) IBOutlet NSButton *button9;
@property (weak) IBOutlet NSButton *button10;
@property (weak) IBOutlet NSButton *button11;
@property (weak) IBOutlet NSButton *button12;
//@property (weak) IBOutlet NSButton *button13;
//@property (weak) IBOutlet NSButton *button14;
//@property (weak) IBOutlet NSButton *button15;
//@property (weak) IBOutlet NSButton *button18;
//@property (weak) IBOutlet NSButton *button21;


@end
