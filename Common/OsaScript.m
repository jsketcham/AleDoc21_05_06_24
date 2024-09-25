//
//  OsaScript.m
//  AdrServer_V5xx
//
//  Created by James Ketcham on 7/20/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import "OsaScript.h"
//#import "TcpServerConnection.h"

@implementation OsaScript

@synthesize condition = _condition;
@synthesize lock = _lock;

-(id)init{
    
    self = [super init];
    
    if(self){
        
        //http://stackoverflow.com/questions/11550300/how-can-i-read-a-environmental-variable-in-cocoa
        _pathToScripts = [[[NSProcessInfo processInfo]environment]objectForKey:@"HOME"];
        _pathToScripts = [_pathToScripts stringByAppendingString:@"/Library/Scripts"];
        
        _txArray = [[NSMutableArray alloc] init];
        _ioLock = [[NSLock alloc] init];
        _condition = [[NSCondition alloc] init];
        
        _workerThread = [[NSThread alloc] initWithTarget:self selector:@selector(run:) object:nil];
        
    }
    
    return  self;
}

-(void)sendScriptResult:(ScriptResult*)scriptResult{
    
    if([_workerThread isExecuting]){
        
        [[self ioLock] lock];
        [[self txArray] addObject:scriptResult];
        [[self ioLock] unlock];
        
        //        NSLog(@"timer_service items on txArray: %d",(int)_osaScript.txArray.count);
        
        [self setLock:false]; // so that we can get out of the 'wait' section
        [[self condition] signal];
        
    }
    
}

-(void)processMsgArray:(NSMutableArray *)msgArray :(id)connection{
    
    if(msgArray.count == 0) return;
    
    if([_workerThread isExecuting]){
        
        NSMutableArray *array = [[NSMutableArray alloc] init];
        
        for(NSString *s in msgArray){
            
//            if([s rangeOfString:@"ping"].location != NSNotFound){
//                
////                NSLog(@"%@",s);
//                
//                if(connection != nil && [connection respondsToSelector:@selector(txMsg:)]){
//                    
//                    [connection performSelector:@selector(txMsg:) withObject:@"ping\n"];
//                }
//                
//                continue;   // no pings
//                
//            }
            if(s.length == 0) continue; // no empty strings
            
            ScriptResult *sr = [[ScriptResult alloc] init];
            sr.scriptCmd = s;
            sr.connection = connection;
            [array addObject:sr];
            
        }
        
        if(array.count == 0) return;
        
        // add all ScriptResult objects to txArray in one operation
        [[self ioLock] lock];
        [[self txArray] addObjectsFromArray:array];
        [[self ioLock] unlock];
        
        [self setLock:false]; // so that we can get out of the 'wait' section
        [[self condition] signal];
    }
    
    
}
-(void)processMsg:(NSString*)msg{
    
    ScriptResult *sr = [[ScriptResult alloc] init];
    sr.scriptCmd = msg;
    
    [[self ioLock] lock];
    [[self txArray] addObject:sr];
    [[self ioLock] unlock];
    
    [self setLock:false]; // so that we can get out of the 'wait' section
    [[self condition] signal];
    
}

-(void)stop{
    
    if(!_workerThread.isCancelled)
        [_workerThread cancel];
}
-(void)start{
    
    if(!_workerThread.isExecuting)
        [_workerThread start];
    
}

-(void) run: (id)parent{
    
    
        // http://stackoverflow.com/questions/17971717/how-to-wait-in-nsthread-until-some-event-occur-in-ios
        while([[NSThread currentThread] isCancelled] == NO)
        {
            @autoreleasepool {
                
                [self.condition lock];
                
                while(self.lock)            // cleared by the code that loaded txArray, prior to signalling
                {
                    [self.condition wait];  // wait for signal
                }
                
                // read your event from your event queue
                [_ioLock lock];
                NSMutableArray *txArrayCopy = [_txArray copy];
                [_txArray removeAllObjects];
                [_ioLock unlock];
                
                // lock the condition again
                self.lock = YES;
                [self.condition unlock];
                
                for (ScriptResult *scriptResult in txArrayCopy){
                    
                    NSArray *args = nil;
                    
                    if([scriptResult.scriptCmd rangeOfString:@"\t"].location != NSNotFound){
                        
                        // elements separated by tabs
                        // this is true when items can have blanks in them (like file names for instance)
                        args = [scriptResult.scriptCmd componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\t"]];
                        
                    }else {
                        
                        // elements separated by blanks
                        args = [scriptResult.scriptCmd componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    }
                    
                    NSString *script = [NSString stringWithFormat:@"%@/%@.scpt",_pathToScripts,[args objectAtIndex:0]];
                    
                    NSMutableArray *array = [[NSMutableArray alloc] init];
                    [array addObjectsFromArray:args];
                    [array replaceObjectAtIndex:0 withObject:script];   // script name with path and extension
                    
                    NSDate *now = [NSDate date];
                    
                    NSTask *task = [[NSTask alloc] init];
                    task.launchPath = @"/usr/bin/osascript";
                    task.arguments  = array;
                    task.standardOutput = [[NSPipe alloc] init];    // http://www.raywenderlich.com/36537/nstask-tutorial
                    
                    //                NSLog(@"launching osascript: %@",script);
                    [task launch];
                    [task waitUntilExit];
                    NSDate *then = [NSDate date];
                    
                    NSTimeInterval interval = [then timeIntervalSinceDate:now];
                    
                    NSData *output = [[task.standardOutput fileHandleForReading] availableData];
                    
                    scriptResult.result = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
                    scriptResult.interval = interval;
                    
//                    NSLog(@"%@",scriptResult.result);
                    
                    // send the script result to the connection (if there is one)
                    // the osascript thread runs locally to trigger Quicktime playback and there is no 'connection'
                    if(scriptResult.connection != nil){
                        
                        NSCharacterSet *trimChars = [NSCharacterSet characterSetWithCharactersInString:@" \r\n"];
                        NSString *msg = [NSString stringWithFormat:@"%@ %@ %.3f\n",scriptResult.scriptCmd,[scriptResult.result stringByTrimmingCharactersInSet:trimChars],scriptResult.interval];
                        
                        if([scriptResult.connection respondsToSelector:@selector(txMsg:)])
                        {
                            [scriptResult.connection performSelectorOnMainThread:@selector(txMsg:) withObject:msg waitUntilDone:false];
                        }
                    }
                    
                }
            }
        }
    
    printf("osascript thread has stopped");
}

@end
