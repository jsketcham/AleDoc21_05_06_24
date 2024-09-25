//
//  ObjCRecordFile.h
//  Sampler
//
//  Created by James Ketcham on 6/22/15.
//  Copyright (c) 2015 James Ketcham. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ObjCRecordFile : NSObject

-(void)start:(NSString*)fName;
-(void)stop;
-(void)cleanup;

@end
