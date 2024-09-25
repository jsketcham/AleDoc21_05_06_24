//
//  StreamerRenderer.m
//  MetalStreamer
//
//  Created by Pro Tools on 12/30/22.
//
/*
    looking for judder, still seen after increasing MaxFramesInFlight to 6 (should cover 100 ms delay in calling drawInMTKView)
 2023-01-24 08:56:53.829186-0800 AleDoc21[12789:108654] -6.0015 // remainder should not drift
 2023-01-24 08:56:54.828807-0800 AleDoc21[12789:108654] -7.0011
 2023-01-24 08:56:55.536339-0800 AleDoc21[12789:108654] drawInMTKView period 0.07384
 2023-01-24 08:56:55.878837-0800 AleDoc21[12789:108654] -8.0512 // .05 drift, 3 fields, -> there are missing calls to drawInMTKView
 2023-01-24 08:56:56.878969-0800 AleDoc21[12789:108654] -9.0513
 
 2023-01-24 09:01:33.977195-0800 AleDoc21[12789:108654] -286.1495
 2023-01-24 09:01:34.977133-0800 AleDoc21[12789:108654] -287.1495
 2023-01-24 09:01:35.319179-0800 AleDoc21[12789:108654] drawInMTKView period 0.02571
 2023-01-24 09:01:35.579543-0800 AleDoc21[12789:108654] drawInMTKView period 0.02599
 2023-01-24 09:01:35.993264-0800 AleDoc21[12789:108654] -288.1656   // 1 field drift
 2023-01-24 09:01:36.993456-0800 AleDoc21[12789:108654] -289.1658
 
 There are missing calls to drawInMTKView. Does drawInMTKView fill all available buffer slots?
 */
/*
 Sanity check 08/07/23, does CAAnimation work better? We ran AleDoc2, which uses CAAnimation
 streamers, and found that it, too, has judder sometimes. So, no. We would like to find a way
 to run streamers as a detached GPU program. 
 */

#import "StreamerRenderer.h"
#import "AAPLStreamer.h"
#import "AAPLShaderTypes.h"
#import "ColorSupport.h"
#import "AleDelegate.h"
#import "MatrixWindowController.h"
#import "StreamerWindowController.h"
#import "AleDoc21-Swift.h"    // must be here to avoid a circular reference

// The maximum number of frames in flight. No greater than 3, the maximum number of CAMetalLayer drawables.
static const NSUInteger MaxFramesInFlight = METAL_PIPELINE_FRAMES;

// The number of streamers in the scene, determined to fit the screen.
static const NSUInteger NumStreamers = 16;  // max streamers on screen at once
#define END_BAR_POSITION 0.95  // in screen percent

@implementation StreamerRenderer
{
    // A semaphore used to ensure that buffers read by the GPU are not simultaneously written by the CPU.
    dispatch_semaphore_t _inFlightSemaphore;

    // A series of buffers containing dynamically-updated vertices.
    id<MTLBuffer> _vertexBuffers[MaxFramesInFlight];

    // The index of the Metal buffer in _vertexBuffers to write to for the current frame.
    NSUInteger _currentBuffer;

    id<MTLDevice> _device;

    id<MTLCommandQueue> _commandQueue;

    id<MTLRenderPipelineState> _pipelineState;

    vector_uint2 _viewportSize;

    NSUInteger _totalVertexCount;
    
    float scale;
    
    NSMutableArray<StreamerObject*> *_drawStreamerObjects;
    
//    int _numStreamerFields;
    
    bool cancelStreamers;
    
    NSInteger slip;
    
//    double streamerStartTime;
//    double streamerEndTime;
    int drawTimesEndIndex;
    
    double drawTimes[NUM_DRAWTIMES];
    int drawTimesIndex;
    
    double lastDrawTime;    // determine frame rate
    double drawPeriod;      // an averager
    
    NSDate *lastDrawDate;   // determine count of vertical syncs in 2 seconds
    int vertSyncsPerStreamer;

}

@synthesize numStreamerFields = _numStreamerFields;
@synthesize lock = _lock;
@synthesize streamerObjects = _streamerObjects;
@synthesize endBarColor = _endBarColor;
@synthesize drawDate = _drawDate;
@synthesize firstDrawDate = _firstDrawDate;
@synthesize drawCounter = _drawCounter;
@synthesize streamerDidFinish = _streamerDidFinish; // debugging flag
@synthesize mtkView = _mtkView;

/// Initializes the renderer with the MetalKit view from which you obtain the Metal device.
- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView
{
    self = [super init];
    if(self)
    {
        self.mtkView = mtkView; // we sometimes need to change our window level
        _lock = [NSLock new];
        _streamerObjects = [NSMutableArray<StreamerObject*> new];       // streamers to add to display
        _drawStreamerObjects = [NSMutableArray<StreamerObject*> new];   // streamers being displayed
        _endBarColor = self.endBarColor;
        
        vertSyncsPerStreamer = 120;   // gets calculated
        _numStreamerFields = 120;   // drawPeriod < 0.018333 ? 120 : 100;
        
        drawPeriod = 0.016666;  // assume 60 field per second
        
        _device = mtkView.device;

        _inFlightSemaphore = dispatch_semaphore_create(MaxFramesInFlight);

        // Load all the shader files with a metal file extension in the project.
        id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

        // Load the vertex shader.
        id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];

        // Load the fragment shader.
        id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];

        // Create a reusable pipeline state object.
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"MyPipeline";
        pipelineStateDescriptor.rasterSampleCount = mtkView.sampleCount;
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        pipelineStateDescriptor.vertexBuffers[AAPLVertexInputIndexVertices].mutability = MTLMutabilityImmutable;

        NSError *error;

        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        
        NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error);
        
        // Create the command queue.
        _commandQueue = [_device newCommandQueue];

        // Calculate vertex data and allocate vertex buffers.
        const NSUInteger streamerVertexCount = [AAPLStreamer vertexCount];
        _totalVertexCount = streamerVertexCount * NumStreamers;//_streamers.count;
        const NSUInteger streamerVertexBufferSize = _totalVertexCount * sizeof(AAPLVertex);

        for(NSUInteger bufferIndex = 0; bufferIndex < MaxFramesInFlight; bufferIndex++)
        {
            _vertexBuffers[bufferIndex] = [_device newBufferWithLength:streamerVertexBufferSize
                                                               options:MTLResourceStorageModeShared];
            _vertexBuffers[bufferIndex].label = [NSString stringWithFormat:@"Vertex Buffer #%lu", (unsigned long)bufferIndex];
        }
    }
    return self;
}
-(bool)streamerIsActive{
    return _drawStreamerObjects.count != 0;
}
-(void)cancelStreamers{
    
    cancelStreamers = true;
    
}

-(void)streamerFinished{
    
    // check slip at end of streamer, change means we slipped that many fields
    [[NSUserDefaults standardUserDefaults] setInteger:drawTimesEndIndex forKey:@"delta"];   // indicator
    
    // assume success
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSImage *image = [[NSImage alloc] initWithContentsOfURL:[mainBundle URLForImageResource:@"green16.png"]];
    
    // look for skipped frame, not good, but maybe not fatal
    double greatestTimeInterval = 0.0;
    int indexOfgreatestTimeInterval = 0;
    
    for (int i = 1; i < drawTimesEndIndex; i++){
        
        double timeInterval = drawTimes[i] - drawTimes[i - 1];
        if(timeInterval > greatestTimeInterval){
            greatestTimeInterval = timeInterval;
            indexOfgreatestTimeInterval = i;
        }

    }
//    NSLog(@"greatestTimeInterval[%d] %3.4f",indexOfgreatestTimeInterval,greatestTimeInterval);

    if(greatestTimeInterval > (2 * .01666)){
        image = [[NSImage alloc] initWithContentsOfURL:[mainBundle URLForImageResource:@"yellow16.png"]];
        
//        for(int i = indexOfgreatestTimeInterval - 1; i < indexOfgreatestTimeInterval + 3; i++){
//
//            if(i >= 0 && i < drawTimesEndIndex){
//                NSLog(@"drawTimes[%d] %3.4f",i,drawTimes[i]);
//            }
//
//        }
    }
    
    AleDelegate *delegate = (AleDelegate*)NSApp.delegate;
    [delegate.matrixWindowController.judderImageView setImage:image];
    
    if(delegate.matrixWindowController.streamerEndString.length == 0){
        delegate.matrixWindowController.streamerEndString = delegate.matrixWindowController.mtcString;
    }

}

-(void)addStreamer:(NSColor*)color{
    
    AleDelegate *delegate = (AleDelegate*)NSApp.delegate;
    delegate.matrixWindowController.streamerStartString = delegate.matrixWindowController.mtcString;
    delegate.matrixWindowController.streamerEndString = @"";    // enables capture

    cancelStreamers = false;    
    
    // we have a period averager, calculate numStreamerFields
    // two cases, 60 hz and 50 hz
    // ignore 48hz case
    
//    _numStreamerFields = drawPeriod < 0.018333 ? 120 : 100;
    
//    if(drawPeriod != 0){
//
//        _numStreamerFields = 2 * (int)round(1/drawPeriod);
//        NSLog(@"_numStreamerFields %d",_numStreamerFields);
//
//    }
    
    // show slip at streamer start
    NSInteger slip = [[NSUserDefaults standardUserDefaults] integerForKey:@"slip"];
    [[NSUserDefaults standardUserDefaults]setInteger:slip forKey:@"slipAtAddStreamer"];
    
    // clear the judder indicator
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSImage *image = [[NSImage alloc] initWithContentsOfURL:[mainBundle URLForImageResource:@"clear16.png"]];
    [delegate.matrixWindowController.judderImageView setImage:image];

    __weak typeof(self) weakSelf = self;
    
    @try{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // use weakSelf here
            StreamerObject *streamerObject = [StreamerObject new];
            
            NSColorSpace *space = NSColorSpace.genericRGBColorSpace;
            NSColor *c = [color colorUsingColorSpace:space];
            
            vector_float4 colorVector = {   c.redComponent,
                c.greenComponent,
                c.blueComponent,
                c.alphaComponent};
            
            streamerObject.color = colorVector;
            // correct for pipeline delay, add in video sync offset (which is in fields)
            streamerObject.date = [NSDate date];
            
            NSDate *d = [[NSDate alloc] initWithTimeInterval:0.016 sinceDate:[NSDate date]];    // 60 fps, 1 frame of delay max
            
            if ([weakSelf.lock lockBeforeDate:d]){
                
                [weakSelf.streamerObjects addObject:streamerObject];
                [weakSelf.lock unlock];
                
            }else{
                NSLog(@"failed to get lock, lost streamer");
            }
            
        });
    }
    @catch (NSException *exception){
        NSLog(@"StreamerRenderer exception %@",exception);
        
    }

}

/// Updates the position of each streamer and also updates the vertices for each streamer in the current buffer.
- (void)updateState
{
//    CFTimeInterval mediaTime = CACurrentMediaTime();    // looking for skipped drawInMTKView()
    
    if([_lock tryLock]){
        // if we get the lock, move new streamers to our draw list
        if(_streamerObjects.count > 0){
            
//            streamerStartTime = mediaTime;
            drawTimesIndex = 0;
            _streamerDidFinish = false;   // debugging flag

            if(_drawStreamerObjects.count == 0){
                // no streamers, add end bar
                // useAnnunciatorColor 2.10.02
                bool useAnnunciatorColor = [[NSUserDefaults standardUserDefaults] boolForKey:@"useAnnunciatorColor"];
                
                // capture this when we set the end bar, do not change while showing streamers
                // PT has a non-standard frame rate
                _numStreamerFields = vertSyncsPerStreamer;

                StreamerObject *endBar = [StreamerObject new];

                NSColorSpace *space = NSColorSpace.genericRGBColorSpace;
                NSColor *c = [self.endBarColor colorUsingColorSpace:space];

                vector_float4 colorVector = {   c.redComponent,
                                                c.greenComponent,
                                                c.blueComponent,
                                                c.alphaComponent};

                endBar.color = useAnnunciatorColor ? _streamerObjects[0].color : colorVector;   // 2.10.02
                
                endBar.isEndBar = true;
                endBar.position = _numStreamerFields; //_numStreamerFields;
                
                [_drawStreamerObjects addObject:endBar];

            }
            
            [_drawStreamerObjects addObjectsFromArray:_streamerObjects];
            [_streamerObjects removeAllObjects];
            
            while(_drawStreamerObjects.count > NumStreamers){
                // too many streamers, remove some
                [_drawStreamerObjects removeLastObject];
            }
        }
        [_lock unlock];
    }
    
//    drawTimesIndex %= NUM_DRAWTIMES;
//    drawTimes[drawTimesIndex] = mediaTime;
//    drawTimesIndex++;
    
    if(_numStreamerFields < 48){
        _numStreamerFields = 48;    // never less than 24fps, 2 seconds
    }

    // Vertex data for a single default streamer.
    const AAPLVertex *streamerVertices = [AAPLStreamer vertices];
    const NSUInteger streamerVertexCount = [AAPLStreamer vertexCount];

    // Vertex data for the current streamers.
    AAPLVertex *currentStreamerVertices = _vertexBuffers[_currentBuffer].contents;
    
    for(NSUInteger streamer = 0; streamer < _drawStreamerObjects.count; streamer++){
        
        for(NSUInteger vertex = 0; vertex < streamerVertexCount; vertex++){
            
            NSUInteger currentVertex = vertex + (streamer * streamerVertexCount);
            
            currentStreamerVertices[currentVertex] = streamerVertices[vertex];  // middle of screen
            currentStreamerVertices[currentVertex].position *= scale;
            currentStreamerVertices[currentVertex].position[0] -= _viewportSize.x/2.0;  // right edge
            // The streamer starts at the left edge, and finishes at END_BAR_POSITION
            currentStreamerVertices[currentVertex].position[0] += END_BAR_POSITION * _viewportSize.x * _drawStreamerObjects[streamer].position / _numStreamerFields;    // motion
            currentStreamerVertices[currentVertex].color = _drawStreamerObjects[streamer].color;
        }
    }
    
    _totalVertexCount = streamerVertexCount * _drawStreamerObjects.count;
    
    NSArray<StreamerObject*> *soCopy = [_drawStreamerObjects copy];
    
    // end bar is soCopy[0]
    for(int i = 1; i < soCopy.count; i++){
        
        soCopy[i].position++;
        
        if(soCopy[i].position > _numStreamerFields){
            
            [_drawStreamerObjects removeObject:soCopy[i]];
            
        }
    }
    
    if(_drawStreamerObjects.count == 1 || cancelStreamers){    // the end bar
        
        [_drawStreamerObjects removeAllObjects];    // remove end bar
        cancelStreamers = false;
        _streamerDidFinish = true;   // debugging flag
//        streamerEndTime = mediaTime;
        drawTimesEndIndex = drawTimesIndex;
        
        // look for draw() slippage on main thread so we can display it
        __weak typeof(self) weakSelf = self;

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf streamerFinished];
        });
    }
}
// MARK: ----------- setters/getters ----------------
-(void)setEndBarColor:(NSColor *)endBarColor{
    _endBarColor = endBarColor;
    [[NSUserDefaults standardUserDefaults]setColor:endBarColor forKey:@"endBarColor"];
}
-(NSColor *)endBarColor{
    return [[NSUserDefaults standardUserDefaults] colorForKey:@"endBarColor"];
}

#pragma mark - MetalKit View Delegate

/// Handles view orientation or size changes.
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{

    // Save the size of the drawable as you'll pass these
    // values to the vertex shader when you render.
    
    // by inspection, view.drawableSize is 2x view.frame.size
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
    
    scale = _viewportSize.y / 1080.0;

}
/*
 4/7/23 we see judder when no drawInMTKView() was skipped, try tracing 
 */
/// Handles view rendering for a new frame.
- (void)drawInMTKView:(nonnull MTKView *)view
{
    
    if (lastDrawDate == nil){
        lastDrawDate = [NSDate date];
    }
    
    // capture the count of vert syncs for a 2 second streamer
    if ([[NSDate date] timeIntervalSinceDate:lastDrawDate] >= 2.0){
        
        vertSyncsPerStreamer = (int)_drawCounter;
        _drawCounter = 0;
        lastDrawDate = [NSDate date];
        
    }
    _drawCounter += 1;  // check for slippage in Streamer.renderCallback()

    // Wait to ensure only `MaxFramesInFlight` number of frames are getting processed
    // by any stage in the Metal pipeline (CPU, GPU, Metal, Drivers, etc.).
    dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);

    // Iterate through the Metal buffers, and cycle back to the first when you've written to the last.
    _currentBuffer = (_currentBuffer + 1) % MaxFramesInFlight;

    // Update buffer data.
    [self updateState]; // 2.10.00 TODO: calls for missing drawInMTKView calls? Queuing more than 1 drawable?

    // Create a new command buffer for each rendering pass to the current drawable.
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"StreamerCommandBuffer";

    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    
    // log when we get renderPassDescriptor
    CFTimeInterval mediaTime = CACurrentMediaTime();    // looking for skipped drawInMTKView()
    if(lastDrawTime != 0){
        double period = mediaTime - lastDrawTime;
        
        drawPeriod += 0.1 * (period - drawPeriod);
    }
    lastDrawTime = mediaTime;
    
    drawTimesIndex %= NUM_DRAWTIMES;
    drawTimes[drawTimesIndex] = mediaTime;
    drawTimesIndex++;

    if(renderPassDescriptor != nil)
    {
        // Create a render command encoder to encode the rendering pass.
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"StreamerRenderEncoder";

        // Set render command encoder state.
        [renderEncoder setRenderPipelineState:_pipelineState];

        // Set the current vertex buffer.
        [renderEncoder setVertexBuffer:_vertexBuffers[_currentBuffer]
                                offset:0
                               atIndex:AAPLVertexInputIndexVertices];

        // Set the viewport size.
        [renderEncoder setVertexBytes:&_viewportSize
                               length:sizeof(_viewportSize)
                              atIndex:AAPLVertexInputIndexViewportSize];

        // Draw the streamer vertices.
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:_totalVertexCount];

        // Finalize encoding.
        [renderEncoder endEncoding];

        // Schedule a drawable's presentation after the rendering pass is complete.
        [commandBuffer presentDrawable:view.currentDrawable];
    }

    // Add a completion handler that signals `_inFlightSemaphore` when Metal and the GPU have fully
    // finished processing the commands that were encoded for this frame.
    // This completion indicates that the dynamic buffers that were written-to in this frame, are no
    // longer needed by Metal and the GPU; therefore, the CPU can overwrite the buffer contents
    // without corrupting any rendering operations.
    __block dispatch_semaphore_t block_semaphore = _inFlightSemaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer)
     {
         dispatch_semaphore_signal(block_semaphore);
     }];

    // Finalize CPU work and submit the command buffer to the GPU.
    [commandBuffer commit];
}

//-(void)analyzeJudder: (double[_Nonnull]) vSyncArray : (int) vSyncArraySize : (int) vCtr{
//
//    /*
//     04/24/23 turning off vert sync part of test, we can get all the info we need from draw times
//     */
//
//    int didFail = 0;        // green,yellow,red 0,1,2
//
//    double v0 = vSyncArray[vCtr % vSyncArraySize];
//
//    for(int i = 0; i < vSyncArraySize; i++){
//
//        double v1 = vSyncArray[(vCtr + 1 + i) % vSyncArraySize];
//
//        if(drawTimes[0] > v0 && drawTimes[0] < v1){
//
//            int numBadBins = 0;
//
//            for(int j = 0; j < drawTimesIndex; j++){
//
//                if( j < drawTimesIndex - 1){
//
//                    double t0 = drawTimes[j];
//                    double t1 = drawTimes[(j + 1)];
//
//                    if(t1 -t0 > 0.033){
//                        didFail = 2;
//                        NSLog(@"missed a draw");
//
//                    }
//                }
//
//                if(v1 - v0 > 0.033){
//                    didFail = 2;
//                    NSLog(@"bad vsync period");
//                }
//
//                if(drawTimes[j] < v0 || drawTimes[j] > v1){
//                    numBadBins++;
//                    didFail = 2;
////                    NSLog(@"bad bin %d v0 %3.4f v1 %3.4f t %3.4f ",j,v0,v1,drawTimes[j]);
//                }
//
//                v0 = v1;
//                v1 = vSyncArray[(vCtr + 2 + i + j) % vSyncArraySize];
//
//            }
//
//            NSLog(@"numBadBins %d",numBadBins);
//            break;
//        }
//        v0 = v1;
//
//        /*
//         results from this test are inconclusive.
//
//         1) we see judder sometimes with 0 bad bins.
//         2) we see good streamers with 120 bad bins (1st one wrong)
//         3) we see cases of 34 bad bins, etc, doesn't always judder.
//
//         the only 'conclusion' is that the judder can sometimes be a GPU problem,
//         where CPU timing is fine.
//         */
//    }
//
//    NSImage *image;
//    NSBundle *mainBundle = [NSBundle mainBundle];
//
//    switch(didFail){
//        case 0: image = [[NSImage alloc] initWithContentsOfURL:[mainBundle URLForImageResource:@"green16.png"]]; break;
//        case 1: image = [[NSImage alloc] initWithContentsOfURL:[mainBundle URLForImageResource:@"yellow16.png"]]; break;
//        default: image = [[NSImage alloc] initWithContentsOfURL:[mainBundle URLForImageResource:@"red16.png"]]; break;
//
//    }
//
//    AleDelegate *delegate = (AleDelegate*)NSApp.delegate;
//    [delegate.matrixWindowController.judderImageView setImage:image];
//
//
//    /*
//     even though timing looks good, we saw judder
//
//     1) no vertical syncs are missed
//     2) no draws are missed
//     3) draws are between vsyncs
//
//     analyzeJudder greatest vSync period 0.0201, vCtr 209
//     greatestTimeInterval 0.0176
//     startIndex 87
//     least timeToNextVSync 0.0042
//
//     analyzeJudder greatest vSync period 0.0185, vCtr 55
//     greatestTimeInterval 0.0176
//     startIndex 189
//     least timeToNextVSync 0.0067
//
//     */
//
//}

@end
