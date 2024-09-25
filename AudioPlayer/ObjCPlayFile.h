//
//  PlayFile.h
//  AleDoc
//
//  Created by James Ketcham on 9/17/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

// http://philjordan.eu/article/mixing-objective-c-c++-and-objective-c++

#ifndef AleDoc_PlayFile_h
#define AleDoc_PlayFile_h

#import <Foundation/Foundation.h>

@interface ObjCPlayFile: NSObject

-(int) stopAudio;
-(int) startAudio: (NSString*)fName;

@end

#endif
