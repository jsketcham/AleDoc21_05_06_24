//
//  LaunchPadMini.h
//  MtcGenerator
//
//  Created by James Ketcham on 3/31/16.
//  Copyright © 2016 James Ketcham. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LaunchPadMini;

@protocol LaunchPadMiniDelegate

-(void)launchPadKeyPressed:(NSData*)data;
-(void)initAipHead;

@end

@interface LaunchPadMini : NSObject

@property id delegate;

@end
