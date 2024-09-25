//
//  FileDropTextField.h
//  AleDoc
//
//  Created by Jim on 1/25/21.
//  Copyright © 2021 James Ketcham. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface FileDropTextField : NSTextField<NSDraggingDestination>{
    
    //highlight the drop zone
    BOOL highlight;

}
// using /sampler/dropbutton.h as an example

//-(NSInteger)remoteDelay;    // returns int value of
//-(void)readRemoteDelayFile; // read the file at the start of every record cycle

@property (strong) NSURL *fileUrl;
@property (strong, readonly) NSString *folder;
@property (strong,readonly) NSString *fileName;
@property NSString *key;

@end

NS_ASSUME_NONNULL_END
