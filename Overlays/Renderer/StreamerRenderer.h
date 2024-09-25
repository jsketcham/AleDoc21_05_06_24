//
//  StreamerRenderer.h
//  MetalStreamer
//
//  Created by Pro Tools on 12/30/22.
//

@import MetalKit;
#import <Foundation/Foundation.h>
#import "StreamerObject.h"
#define NUM_DRAWTIMES 128

@class StreamerWindowController;
@class MtkWindowController;


NS_ASSUME_NONNULL_BEGIN

#define METAL_PIPELINE_FRAMES 3

@interface StreamerRenderer : NSObject<MTKViewDelegate>

@property NSLock *lock;   // access to _streamerObjects
@property NSMutableArray<StreamerObject*> *streamerObjects;   // we need color and position, but not vertices
@property NSColor *endBarColor;
@property NSDate *drawDate;

@property NSDate *firstDrawDate;
@property NSInteger drawCounter;
@property double fractionalPart;
@property bool streamerDidFinish;
@property int numStreamerFields;
@property MTKView *mtkView;

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView;
-(void)addStreamer:(NSColor*)color;
-(bool)streamerIsActive;
-(void)cancelStreamers;
//-(void)analyzeJudder: (double[_Nonnull]) vSyncArray : (int) vSyncArraySize : (int) vCtr;

@end

NS_ASSUME_NONNULL_END
