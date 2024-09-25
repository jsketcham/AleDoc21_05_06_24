//
//  AdrClient.m
//  AleDoc
//
//  Created by Jim on 9/17/22.
//  Copyright © 2022 James Ketcham. All rights reserved.
//  call OsaScript from a local thread rather than having a client/server
//  AleDoc and AdrServer run on the same computer, this is simpler
//  and means that AdrServer (a separate program) does not have to be installed

#import "AdrClient.h"

@implementation AdrClient

@synthesize adrClientRun = _adrClientRun;
@synthesize delegate = _delegate;
@synthesize inLock = _inLock;
@synthesize inArray = _inArray;

-(void)addToInArray:(NSString*)str{
    
    [self.inArray addObject:str];
    
}

-(void)addToInArrayX:(NSString*)str{
    
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // use weakSelf here
        
        NSDate *d = [[NSDate alloc] initWithTimeInterval:1.0 sinceDate:[NSDate date]];
        
        if ([weakSelf.inLock lockBeforeDate:d]){
            
            [weakSelf.inArray addObject:str];
            [weakSelf.inLock unlock];
            
        }else{
            NSLog(@"failed to get lock, lost item %@",str);
        }
        
    });
}
-(void)processScriptResult:(ScriptResult*)scriptResult{
    
    // copied from AdrServer_v5xx
    NSCharacterSet *trimChars = [NSCharacterSet characterSetWithCharactersInString:@" \t\r\n"];
    //processScriptResult
    NSString *msg = [NSString stringWithFormat:@"%@\t%@\t %.3f\n",scriptResult.scriptCmd,[scriptResult.result stringByTrimmingCharactersInSet:trimChars],scriptResult.interval];
    
    if (_delegate && [_delegate respondsToSelector:@selector(rxMsg:sender:)]){
        
        [_delegate rxMsg:msg sender:self];
        
    }

}
NSTimer *adrClientTimer;

-(void)startAdrClient{
    
    _adrClientRun = true;
    _inArray = [[NSMutableArray alloc] init];
    
    adrClientTimer  = [NSTimer scheduledTimerWithTimeInterval:0.010 target: self selector:@selector(adrClientTimerService) userInfo:nil repeats: YES];

}
-(void)adrClientTimerService{
    
    // 2.10.02 we have a crash every so often, revised adrClient to be simpler and have try/catch
    // if the previous adrClientTimerService dispatch_async(^{}); has not finished, an
    // additional one starts, with its own localArray.
    
    if(!_adrClientRun){
        [adrClientTimer invalidate];
        return;
    }
        
    if(self.inArray.count == 0){
        return; // nothing to send
    }

    NSMutableArray *inArray = [self.inArray copy];  // for passing strings
    [self.inArray removeAllObjects];

    __weak typeof(self) weakSelf = self;

    @try{
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // use weakSelf here
            
            // inArray may be gone in 10 ms, copy it 
            NSMutableArray *localArray = [inArray copy];
            
            for(NSString *str in localArray){
                
                NSMutableArray *args = [[str componentsSeparatedByString:@"\t"]mutableCopy]; // assume tabs
                
                if([str containsString:@"\t"] == false){
                    
                    args = [[str componentsSeparatedByString:@" "]mutableCopy];  // no tabs, separator is ' '
                    
                }
                
                if([args count] == 0){continue;}    // no args
    // tickle github
                ScriptResult *scriptResult = [[ScriptResult alloc] init];
                scriptResult.scriptCmd = args[0];   // the selector, note that we lose any operands, but this has to happen here or in processScriptResult(:)
                
                // moved Scripts to be a resource so that they get installed with the app
//                NSString *s = [[NSString alloc] initWithFormat:@"/Users/%@/Library/Scripts/%@.scpt",NSUserName(),args[0]];
                // /Applications/AleDoc21.app/Contents/Resources
                NSString *s = [[NSString alloc] initWithFormat:@"/Applications/AleDoc21.app/Contents/Resources/%@.scpt",args[0]];

                
                [args replaceObjectAtIndex:0 withObject:s];
                
                NSDate *now = [NSDate date];
                
                NSTask *task = [[NSTask alloc] init];
                task.launchPath = @"/usr/bin/osascript";
                task.arguments  = args;
                task.standardOutput = [[NSPipe alloc] init];    // http://www.raywenderlich.com/36537/nstask-tutorial
                
                //                    NSLog(@"launching osascript: %@",args[0]);
                [task launch];
                [task waitUntilExit];
                NSDate *then = [NSDate date];
                
                scriptResult.interval = [then timeIntervalSinceDate:now];
                
                NSData *output = [[task.standardOutput fileHandleForReading] availableData];
                
                scriptResult.result = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
                
                //                    NSLog(@"%@ result: %@",args[0],scriptResult.result);
                
                [weakSelf performSelectorOnMainThread:@selector(processScriptResult:) withObject:scriptResult waitUntilDone:false];
                
            }
        });
    }
    @catch (NSException *exception){
        NSLog(@"AdrClient exception %@",exception);
        
    }
}

-(void)startAdrClientx{
    
    _adrClientRun = true;
    _inLock = [[NSLock alloc] init];
    _inArray = [[NSMutableArray alloc] init];
    
    // https://stackoverflow.com/questions/46115131/dispatchqueue-main-async-weak-self-in-in-objective-c
    // https://stackoverflow.com/questions/12693197/dispatch-get-global-queue-vs-dispatch-get-main-queue
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // use weakSelf here
        
//        NSThread *thread = [NSThread currentThread];
//        NSInteger threadNumber = [[thread valueForKeyPath:@"startAdrClient private.seqNum"] integerValue];
//        NSLog(@"main thread number: %ld",threadNumber);
        
        while (weakSelf.adrClientRun){
            
            usleep(10000);  // 10 ms sleep between checks
            
            NSDate *d = [[NSDate alloc] initWithTimeInterval:1.0 sinceDate:[NSDate date]];

            if ([weakSelf.inLock lockBeforeDate:d]){
                
                NSMutableArray *localArray = [weakSelf.inArray copy];
                [weakSelf.inArray removeAllObjects];
                [weakSelf.inLock unlock];
                
                for(NSString *str in localArray){
                    
                    NSMutableArray *args = [[str componentsSeparatedByString:@"\t"]mutableCopy]; // assume tabs
                    
                    if([str containsString:@"\t"] == false){
                        
                        args = [[str componentsSeparatedByString:@" "]mutableCopy];  // no tabs, separator is ' '
                        
                    }
                    
                    if([args count] == 0){continue;}    // no args
                    
                    ScriptResult *scriptResult = [[ScriptResult alloc] init];
                    scriptResult.scriptCmd = args[0];   // the selector, note that we lose any operands, but this has to happen here or in processScriptResult(:)

                    NSString *s = [[NSString alloc] initWithFormat:@"/Users/%@/Library/Scripts/%@.scpt",NSUserName(),args[0]];
                    
                    
                    [args replaceObjectAtIndex:0 withObject:s];
                    
                    NSMutableArray *osaArgs;
                    
                    // jxa scripts are named like jxaSomething.scpt
                    if([scriptResult.scriptCmd hasPrefix:@"jxa"]){
                        
                        osaArgs = [[NSMutableArray alloc] initWithObjects:@"-l JavaScript", nil];
                        [osaArgs addObjectsFromArray:args];
                        
                    }else{
                        
                        osaArgs = args;
                        
                    }
                    
                    NSDate *now = [NSDate date];
                    
                    NSTask *task = [[NSTask alloc] init];
                    task.launchPath = @"/usr/bin/osascript";
                    task.arguments  = args;
                    task.standardOutput = [[NSPipe alloc] init];    // http://www.raywenderlich.com/36537/nstask-tutorial
                    
//                    NSLog(@"launching osascript: %@",args[0]);
                    [task launch];
                    [task waitUntilExit];
                    NSDate *then = [NSDate date];
                    
                    scriptResult.interval = [then timeIntervalSinceDate:now];
                    
                    NSData *output = [[task.standardOutput fileHandleForReading] availableData];
                    
                    scriptResult.result = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
                    
//                    NSLog(@"%@ result: %@",args[0],scriptResult.result);
                    
                    [weakSelf performSelectorOnMainThread:@selector(processScriptResult:) withObject:scriptResult waitUntilDone:false];

                }
                
                
            }else{
                NSLog(@"OsaScriptThread failed to get lock");
            }
        }
        
        NSLog(@"OsaScriptThread terminating");
    });
}

@end
