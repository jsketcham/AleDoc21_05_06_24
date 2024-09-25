//
//  Accessory.h
//  MtcGenerator
//
//  Created by James Ketcham on 3/31/16.
//  Copyright © 2016 James Ketcham. All rights reserved.
//

#import <Foundation/Foundation.h>

// CC for capture sample, 12 before v1.00.19
// Evan say PT11 sends CC 12 when the timeline is clicked
// we don't know how it gets to the accessory
#define CC_CAPTURE_SAMPLE 14
#define CC_VIDEO_REC_DELAY 15

@class Accessory;

@protocol AccessoryDelegate

-(void)accessoryService:(NSData*)data;

@end

@interface Accessory : NSObject

@property id delegate;

@end
