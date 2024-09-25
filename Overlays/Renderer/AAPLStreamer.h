//
//  AAPLStreamer.h
//  MetalStreamer
//
//  Created by Pro Tools on 12/30/22.
//
/*
    Abstract: a single streamer
    there is one end bar (a fixed position streamer) and n streamers at any one time
    A streamer is two triangles (6 vertices), making a rectangle
    not decided yet: how to identify
 
 */

#import <Foundation/Foundation.h>
@import MetalKit;
#import "AAPLShaderTypes.h"

//#define endBarFraction 0.90         // from AleDoc2.overlays.streamer
#define streamerWidthFraction 0.01  // from AleDoc2.overlays.streamer

NS_ASSUME_NONNULL_BEGIN

@interface AAPLStreamer : NSObject

@property (nonatomic) vector_float2 position;
@property (nonatomic) vector_float4 color;
@property int positionCounter;  // 0-119, 2 second streamer, 60 fps

+(const AAPLVertex*)vertices;
+(NSUInteger)vertexCount;

@end

NS_ASSUME_NONNULL_END
