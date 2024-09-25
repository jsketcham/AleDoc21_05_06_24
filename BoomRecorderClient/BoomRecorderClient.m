//
//  BoomRecorderClient.m
//  AleDoc
//
//  Created by James Ketcham on 6/25/15.
//  Copyright (c) 2015 James Ketcham. All rights reserved.
//

#import "BoomRecorderClient.h"
#import "AleDelegate.h"
#import "AleDoc21-Swift.h"    // must be here to avoid a circular reference

#define PING_INTERVAL 3.0
#define SERVER_KEY @"server_boom"

@interface BoomRecorderClient ()

@property NSDictionary *cmdDictionary;
@property NSTimer *timer;
@property NSString *server;
@property BoomRecorderMIDI *boomRecorderMIDI;

@end

@implementation BoomRecorderClient

-(id)init{
    
    self = [super init];
    
    if(self){
        
        _boomRecorderMIDI = [[BoomRecorderMIDI alloc]init];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:@"",SERVER_KEY, nil];
        [defaults registerDefaults:dictionary];
        
        [self setServer:[defaults objectForKey:SERVER_KEY]];
        
        [self setTcpClient:[[TcpClientBrowser alloc] init]] ;
        [_tcpClient setDelegate:self];
        [_tcpClient searchForServicesOfType:@"_endpoint_boom._tcp." inDomain:@"local"];
        
        _cmdDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
                          @"ping::",@"ping",
                          @"boomRecStart::",@"boomRecStart",
                          nil];
        
        [self setTimer:[NSTimer scheduledTimerWithTimeInterval:PING_INTERVAL target: self selector:@selector(timer_service) userInfo:nil repeats: YES]];
    }
    
    return self;
}
-(void)setDefaultServer:(NSString*)server{
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:server forKey:SERVER_KEY];
    
    for(TcpClientConnection *connection in _tcpClient.connections){
        
        if([server isEqualToString:connection.netService.name]){
            
            if(_connection && _connection != connection){
                
                [_connection closeStreams];
            }
            
            [self setConnection:connection];
            [self getInitialValues];
            
        }
    }
    
}
-(void) timer_service
{
    @autoreleasepool {
        
        // TODO Christmas tree for Text Window Client
        AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
        if(_connection && _connection.state == DID_RESOLVE){
            [self setIsOnline: true];
        }
        else {
            [self setIsOnline: _connection ? false : NSControlStateValueMixed];
        }
        
//        [delegate showBoomRecorderServerAnnunciator:_isOnline];
        
        for (TcpClientConnection *connection in [_tcpClient.connections copy]) {    // copy or else you get 'was mutated while being enumerated'
            
            switch (connection.state) {
                case DID_RESOLVE:
                    [connection txMsg:@"ping\n"];   // if the unit goes offline this causes a stream error in about 60 seconds, which closes the streams
                    break;
                case DID_NOT_RESOLVE:
                    [connection openStreamsToNetService];   // try to resolve the address
                    break;
                    
                default:
                    break;
            }
        }
    }
}
-(void)ping:(id)connection :(NSArray *)msgItems{
    
}
-(void)boomRecStart:(id)connection :(NSArray *)msgItems{
//    NSLog(@"boomRecStart %ld",msgItems.count);
//    
//    for(int i = 0; i < msgItems.count; i++)
//        NSLog(@"%@",msgItems[i]);
}
-(void)txMsg:(NSString*)msg{
    
    if(_connection) [_connection txMsg:msg];
    
}
-(void)setBoomRecFolder{
    
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    NSString *session = delegate.session;
    session = [session stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    
//    NSString *msg = [NSString stringWithFormat:@"setBoomRecFolder\t%@",session];
//    [self txMsg:msg];   // Evan's script sends MIDI
    [_boomRecorderMIDI setBoomRecFolder: session];

}
-(void)startBoomRecorder:(NSString*)frameRate :(NSString*)takeNumber :(NSString*)trackWidth :(NSString*)cueName :(NSString*)dialog{
    
    [self setBoomRecFolder];
    
    [_boomRecorderMIDI startBoomRecorder:frameRate :takeNumber :trackWidth :cueName :dialog];
    
    // boomRecStart operands: framerate takenumber trackwidth cuename dialog
    // note that as of 6/21/15 'framerate' is commented out in the script because it causes an exception
    // ( the noun 'frameRate' in the appleScript for Boom Recorder does not work)
//    NSString *msg = [NSString stringWithFormat:@"boomRecStart\t%@\t%@\t%@\t%@\t%@",frameRate,takeNumber,trackWidth,cueName,dialog];
//    [self txMsg:msg];   // Evan's script sends MIDI

}
-(void)stopBoomRecorder{
    
    [_boomRecorderMIDI stopBoomRecorder];
    // boomRec can be stopped in 2 ways: 'boomRecStop' and 'boomRecAbort'
//    NSString *msg = @"boomRecStop";
//    [self txMsg:msg];   // Evan's script sends MIDI
}
-(void)abortBoomRecorder{
    
    [_boomRecorderMIDI abortBoomRecorder];
    
    // boomRec can be stopped in 2 ways: 'boomRecStop' and 'boomRecAbort'
//    NSString *msg = @"boomRecAbort";
//    [self txMsg:msg];   // Evan's script sends MIDI
}

#pragma mark -
#pragma mark --------------- TcpClientConnectionDelegate methods ----------------

-(void)getInitialValues{
    
}
-(void)processString:(NSString*)msg :(TcpClientConnection *)connection{
    // dummy added 04/17/20 to get rid of a warning 
}

- (void)connectionDidResolveAddress:(TcpClientConnection *)sender{
    
    // we get here only if the ip address resolved and the NSStreamEventOpenCompleted event has occurred
    // i.e. we actually are connected to the device and not just seeing stale Bonjour cache contents
    // get the version number to demonstrate that we are connected
    
    if( _server && [_server isEqualToString:sender.netService.name]){
        
        [self setConnection:sender];
        [self getInitialValues];
    }
    
}
-(void)connectionWillResolveAddress:(TcpClientConnection *)sender{
    
}

-(void) processMsgArray:(NSMutableArray *)msgArray :(id)connection{
    
    for(NSString *msg in msgArray){
        
        if (msg.length == 0) continue;
        
        NSString *trimmedMsg = [msg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        NSArray *trimmedMsgArray = nil;
        
        if([trimmedMsg rangeOfString:@"\t"].location == NSNotFound){
            
            trimmedMsgArray = [trimmedMsg componentsSeparatedByString:@" "];
            
        }else{
            
            trimmedMsgArray = [trimmedMsg componentsSeparatedByString:@"\t"];
            
        }
        @try {
            
            SEL cmd = NSSelectorFromString([_cmdDictionary objectForKey:[trimmedMsgArray objectAtIndex:0]]);
            if(cmd != nil && [self respondsToSelector:cmd]){
                
                // http://stackoverflow.com/questions/7017281/performselector-may-cause-a-leak-because-its-selector-is-unknown
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [self performSelector:cmd withObject:connection withObject:trimmedMsgArray];
#pragma clang diagnostic pop
            }
//            else{
//
//                // we are taking over streamer commands, send the commands to streamerWindowController
//
//                NSMutableArray *array = [[NSMutableArray alloc] initWithArray:[trimmedMsg componentsSeparatedByString:@"\n"]];   // the unlikely case that we have several lines
//                AleDelegate *delegate = ( AleDelegate *)[NSApp delegate];
//                [delegate.streamerWindowController processMsgArray:array :connection];
//            }
        }
        @catch (NSException *exception) {
            
        }
    }
    
}

@end
