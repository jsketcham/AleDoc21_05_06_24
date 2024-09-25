//
//  RehearseCaptureWindowController.m
//  AleDoc
//
//  Created by James Ketcham on 6/23/15.
//  Copyright (c) 2015 James Ketcham. All rights reserved.
//

#import "RehearseCaptureWindowController.h"
#import "ObjCRecordFile.h"
#import "ObjCPlayFile.h"

#define SAMPLER_FILENAME @"/firstRehearse.wav"
#define FILL_FILENAME @"/customFill.wav"

// WB is doing the fill and rehearse capture with protools plugins, do not do it here

@interface RehearseCaptureWindowController ()

@property ObjCRecordFile *objCRecFile;
@property ObjCPlayFile *objCPlayFile;

@end

@implementation RehearseCaptureWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    _objCPlayFile = [[ObjCPlayFile alloc] init];
    _objCRecFile = [[ObjCRecordFile alloc]init];
    _enableCaptureFill = false;
}
- (IBAction)onPlay:(id)sender {
    
    if(INHIBIT_LOCAL_RECORDING) return; // pt plugins are being used
    
    NSString *path = [[[NSProcessInfo processInfo]environment]objectForKey:@"HOME"];
    path = [path stringByAppendingString:[NSString stringWithFormat:@"/sampler%@",SAMPLER_FILENAME]];
    
    [_objCPlayFile startAudio:path];
}
- (IBAction)onStop:(id)sender {
    
    [_objCPlayFile stopAudio];
}
-(void)startCapture{
    
    // TODO capture recorder residing on another machine
    if(INHIBIT_LOCAL_RECORDING) return; // pt plugins are being used
    
    NSError *error;
    BOOL isDir;
    
    NSString *path = [[[NSProcessInfo processInfo]environment]objectForKey:@"HOME"];
    path = [path stringByAppendingString:@"/sampler"];
    
    NSFileManager *mgr = [[NSFileManager alloc] init];
    
    if(![mgr fileExistsAtPath:path isDirectory:&isDir]){
        
        // create the ~/Logs directory
        [mgr createDirectoryAtPath:path withIntermediateDirectories:false attributes:nil error:&error];
        
    }
    
    path = [path stringByAppendingString:SAMPLER_FILENAME];
    
    [_objCRecFile start:path];
    
}
-(void)stopCapture{
    
    _enableCaptureFill = false; // does not hurt
    [_objCRecFile stop];        
    
}
-(void)startCaptureFill{
    
    // TODO capture recorder residing on another machine
    
    NSError *error;
    BOOL isDir;
    
    if(INHIBIT_LOCAL_RECORDING) return; // pt plugins are being used
    
    if(!_enableCaptureFill) return;
    _enableCaptureFill = false;     // once only
    
    NSString *path = [[[NSProcessInfo processInfo]environment]objectForKey:@"HOME"];
    path = [path stringByAppendingString:@"/sampler"];
    
    NSFileManager *mgr = [[NSFileManager alloc] init];
    
    if(![mgr fileExistsAtPath:path isDirectory:&isDir]){
        
        // create the ~/Logs directory
        [mgr createDirectoryAtPath:path withIntermediateDirectories:false attributes:nil error:&error];
        
    }
    
    path = [path stringByAppendingString:FILL_FILENAME];
    
    [_objCRecFile start:path];
    
}

@end
