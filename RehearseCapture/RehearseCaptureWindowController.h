//
//  RehearseCaptureWindowController.h
//  AleDoc
//
//  Created by James Ketcham on 6/23/15.
//  Copyright (c) 2015 James Ketcham. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#define INHIBIT_LOCAL_RECORDING 1

@interface RehearseCaptureWindowController : NSWindowController

@property bool enableCaptureFill;

- (IBAction)onPlay:(id)sender;
- (IBAction)onStop:(id)sender;
-(void)startCapture;
-(void)stopCapture;
-(void)startCaptureFill;
@end
