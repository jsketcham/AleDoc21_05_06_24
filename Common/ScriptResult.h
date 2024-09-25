//
//  ScriptResult.h
//  AdrServer
//
//  Created by WB ADR on 3/16/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ScriptResult : NSObject

@property (nonatomic, strong, readwrite) NSString *     scriptCmd;

@property (nonatomic, strong, readwrite) NSString *     result;

@property (nonatomic, assign, readwrite) double         interval;

@property id connection;
@end
