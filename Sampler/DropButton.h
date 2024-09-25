//
//  DropButton.h
//  AleDoc
//
//  Created by James Ketcham on 9/2/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class DropButton;
@class SamplerWindowController;

@protocol DropButtonDelegate

-(void)stopAudio:(NSString*)folder fileName:(NSString*)fileName;

@end

@interface DropButton : NSButton<NSDraggingDestination>{
    //highlight the drop zone
    BOOL highlight;
    
}

@property SamplerWindowController *delegate;
@property id objCPlayFile;

@property (strong) NSURL *fileUrl;
@property (strong, readonly) NSString *folder;
@property (strong,readonly) NSString *fileName;
@property NSString *key;

@end
