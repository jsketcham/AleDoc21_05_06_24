//
//  Slider.h
//  AleDoc
//
//  Created by James Ketcham on 8/18/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Item.h"

@class Item;

@interface Slider : NSSlider

@property Item *item;
@end
