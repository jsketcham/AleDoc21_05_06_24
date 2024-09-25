//
//  StreamerObject.h
//  MetalStreamer
//
//  Created by Pro Tools on 1/2/23.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
@import MetalKit;

NS_ASSUME_NONNULL_BEGIN

@interface StreamerObject : NSObject

@property vector_float4 color;
@property NSInteger position;   // 0-119
@property bool isEndBar;
@property NSDate *date;

@end

NS_ASSUME_NONNULL_END
