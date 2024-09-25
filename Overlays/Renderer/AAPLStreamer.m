//
//  AAPLStreamer.m
//  MetalStreamer
//
//  Created by Pro Tools on 12/30/22.
//

#import "AAPLStreamer.h"

@implementation AAPLStreamer

/// Returns the vertices of one streamer.
/// The default position is centered at the origin.
/// The default color is white.
+(const AAPLVertex *)vertices
{
    const float streamerHeight = 1080.0;
    const float streamerWidth = 38.0;
    static const AAPLVertex streamerVertices[] =
    {
        // Pixel Positions,                          RGBA colors.
        { { -0.25*streamerWidth, -0.5*streamerHeight },  { 1, 1, 1, 1 } },
        { { -0.25*streamerWidth, +0.5*streamerHeight },  { 1, 1, 1, 1 } },
        { { +0.25*streamerWidth, -0.5*streamerHeight },  { 1, 1, 1, 1 } },
        { { -0.25*streamerWidth, +0.5*streamerHeight },  { 1, 1, 1, 1 } },
        { { +0.25*streamerWidth, +0.5*streamerHeight },  { 1, 1, 1, 1 } },
        { { +0.25*streamerWidth, -0.5*streamerHeight },  { 1, 1, 1, 1 } },
    };
    return streamerVertices;
}

/// Returns the number of vertices for each streamer.
+(const NSUInteger)vertexCount
{
    return 6;
}

@end
