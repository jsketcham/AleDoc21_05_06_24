//
//  StreamerObject.m
//  MetalStreamer
//
//  Created by Pro Tools on 1/2/23.
//

#import "StreamerObject.h"

@implementation StreamerObject

- (instancetype)init{
    self = [super init];
    
    if(self){
        vector_float4 color = {1,1,1,1}; // white
        self.color = color;
        self.position = 0;
    }
    return self;
}

@end
