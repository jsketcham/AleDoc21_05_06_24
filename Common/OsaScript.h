//
//  OsaScript.h
//  AdrServer_V5xx
//
//  Created by James Ketcham on 7/20/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ScriptResult.h"

@class OsaScript;

@protocol OsaScriptDelegate

-(void)txMsg:(NSString*)msg;

@end

@interface OsaScript : NSObject

@property (strong) NSString *pathToScripts;

@property (nonatomic) BOOL lock;
@property (strong, nonatomic) NSCondition *condition;
@property (strong) NSLock *ioLock;
@property (strong) NSMutableArray *txArray;
@property (strong) NSThread *workerThread;

@property id delegate;

// access
-(void)stop;
-(void)start;
-(void)sendScriptResult:(ScriptResult*)scriptResult;
-(void)processMsgArray:(NSMutableArray *)msgArray :(id)connection;
-(void)processMsg:(NSString*)msg;
@end
