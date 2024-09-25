//
//  ScriptResult.m
//  AdrServer
//
//  Created by WB ADR on 3/16/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import "ScriptResult.h"

@implementation ScriptResult
@synthesize scriptCmd = _scriptCmd;
@synthesize result = _result;
@synthesize interval = _interval;

- (id)init
{
    self = [super init];
    
    if (self != nil) {
        
        _scriptCmd = @"";
        _result = @"";
        _interval = 0.0;
        _connection = nil;  // who gets the response
        
    }
    return self;
}


@end
