//
//  RowView.h
//  Ale_v3xx
//
//  Created by James Ketcham on 4/26/14.
//  Copyright (c) 2014 WB ADR. All rights reserved.
//

#import <Cocoa/Cocoa.h>
//#import "ChannelNodeData.h"

@interface RowView : NSView

@property (strong,readwrite) NSImage *backImage;
-(void)drawBackImage:(NSArray*)titles :(bool) isRow;   // 2.00.00

@end
