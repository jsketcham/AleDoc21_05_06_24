//
//  TextWindowClient.m
//  AleDoc
//
//  Created by James Ketcham on 5/15/15.
//  Copyright (c) 2015 James Ketcham. All rights reserved.
//
// command set:
/*
@"ping"
@"text"             // text to display
@"anchor"            // send point as float
 */

#import "TextWindowClient.h"
#import "AleDelegate.h"
#import "StreamerWindowController.h"
#import "MatrixWindowController.h"
#import "AleDoc21-Swift.h"    // must be here to avoid a circular reference

#define PING_INTERVAL 3.0

@interface TextWindowClient()

@property NSDictionary *cmdDictionary;
@property NSTimer *timer;
@property NSString *server;

@end

@implementation TextWindowClient

#define SERVER_KEY @"server_text"
-(id)init{
    
    self = [super init];
    
    if(self){
        
//        _isVersion2 = true; // 1.00.23 assume not version 1
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:@"",SERVER_KEY, nil];
        [defaults registerDefaults:dictionary];
        
//        [self setServer:[defaults objectForKey:SERVER_KEY]];
//
//        [self setTcpClient:[[TcpClientBrowser alloc] init]] ;
//        [_tcpClient setDelegate:self];
//        [_tcpClient searchForServicesOfType:@"_endpoint_text._tcp." inDomain:@"local"];
        
        // TODO: move commands from streamerWindowController
        _cmdDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
                          @"ping::",@"ping",
                          @"hidePix::",@"hidePix",
                          @"masking::",@"H",
                          @"version::",@"version",                          
                          nil];
        
//        [self setTimer:[NSTimer scheduledTimerWithTimeInterval:PING_INTERVAL target: self selector:@selector(timer_service) userInfo:nil repeats: YES]];
        
        [self setIsOnline: true];   // V1.00.23
//        [self getInitialValues];    // V1.00.23
    }
    
    return self;
}
//-(void)getInitialValues{
//    
////    [self txMsg:@"H"];   // masking
//////    [self txMsg:@"version"];   // we are part of AleDoc 1.00.23
////    [self txMsg:@"V"];
////    [self txMsg:@"V1"];
////    [self txMsg:@"V2"];  // clear text fields
////    
//    // V1.00.23 streamer items
//    
//}
-(void)setDefaultServer:(NSString*)server{
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:server forKey:SERVER_KEY];
    
//    for(TcpClientConnection *connection in _tcpClient.connections){
//
//        if([server isEqualToString:connection.netService.name]){
//
//            if(_connection && _connection != connection){
//                
//                [_connection closeStreams];
//            }
//
//            [self setConnection:connection];
//            [self getInitialValues];
//
//        }
//    }
    
}
//-(void) timer_service
//{
//    @autoreleasepool {
//
//        AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//        [delegate.matrixWindowController showTextServerAnnunciator:true];
////        // TODO Christmas tree for Text Window Client
////        AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
////        if(_connection && _connection.state == DID_RESOLVE){
////            [self setIsOnline: true];
////        }
////        else {
////            [self setIsOnline: _connection ? false : NSControlStateValueMixed];
////        }
////
////        [delegate.matrixWindowController showTextServerAnnunciator:_isOnline];
////
////        for (TcpClientConnection *connection in [_tcpClient.connections copy]) {    // copy or else you get 'was mutated while being enumerated'
////
////            switch (connection.state) {
////                case DID_RESOLVE:
////                    [connection txMsg:@"ping\n"];   // if the unit goes offline this causes a stream error in about 60 seconds, which closes the streams
////                    break;
////                case DID_NOT_RESOLVE:
////                    [connection openStreamsToNetService];   // try to resolve the address
////                    break;
////
////                default:
////                    break;
////            }
////        }
//    }
//}
-(void)masking:(id)connection :(NSArray *)msgItems{
    
    NSLog(@"masking");
    // set streamer
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    
    if(msgItems.count >= 6){
        
        bool skipTx = [delegate.streamerWindowController skipTx];
        
        [delegate.streamerWindowController setSkipTx: 1];   // no endless loop
        
        [delegate.streamerWindowController setTopMask:[[msgItems objectAtIndex:1] integerValue]];
        [delegate.streamerWindowController setBottomMask:[[msgItems objectAtIndex:2] integerValue]];
        [delegate.streamerWindowController setLeftMask:[[msgItems objectAtIndex:3] integerValue]];
        [delegate.streamerWindowController setRightMask:[[msgItems objectAtIndex:4] integerValue]];
        [delegate.streamerWindowController setTransparencyMask:[[msgItems objectAtIndex:5] integerValue]];
        
        [delegate.streamerWindowController setSkipTx: skipTx];  // restore state of skipTx
    }
    
    
    
    
}
-(void)hidePix:(id)connection :(NSArray *)msgItems{
    
//    NSLog(@"hidePix");
    
}
-(void)ping:(id)connection :(NSArray *)msgItems{
    
}
-(void)version:(id)connection :(NSArray *)msgItems{

////    NSLog(@"%@",[msgItems componentsJoinedByString:@" "]);
//
//    NSString *major = [[msgItems objectAtIndex:1]substringToIndex:1];
////    NSLog(@"major: %@",major);
//
//    _isVersion2 = ![major isEqualToString:@"1"];
////    NSLog(@"is version 2: %d",_isVersion2);
}
//-(void)txMsg:(NSString*)msg{
//    
////    if(_connection) [_connection txMsg:msg];
//    AleDelegate *delegate = [NSApp delegate];
//    OverlayWindowController *owc = (OverlayWindowController*)delegate.overlayWindowController;
//    ViewController *vc = (ViewController*)owc.viewController;
//    TextWindowServer *ts = vc.textWindowServer;
//    NSString *result = [ts rxMsg:msg]; // return value
//    
//    if(result){
//        // process the result
//        [self rxMsg:result];
//    }
//    
//    
//}
-(void)rxMsg:(NSString*)msg{

    if (msg == nil || msg.length == 0) return;

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
            [self performSelector:cmd withObject:nil withObject:trimmedMsgArray];
#pragma clang diagnostic pop
        }
//        else{
//
//            // we are taking over streamer commands, send the commands to streamerWindowController
//
//            NSMutableArray *array = [[NSMutableArray alloc] initWithArray:[trimmedMsg componentsSeparatedByString:@"\n"]];   // the unlikely case that we have several lines
//            AleDelegate *delegate = ( AleDelegate *)[NSApp delegate];
//            [delegate.streamerWindowController processMsgArray:array :connection];
//        }
    }
    @catch (NSException *exception) {

    }

    
}
#pragma mark -
//#pragma mark --------------- TcpClientConnectionDelegate methods ----------------
//
//-(void)getInitialValues{
//    [_connection txMsg:@"H"];   // masking
//    [_connection txMsg:@"version"];   // we want to support 1.0 and 2.0
//    [_connection txMsg:@"V"];
//    [_connection txMsg:@"V1"];
//    [_connection txMsg:@"V2"];  // clear text fields
//    [_connection txMsg:@"win 0"];  // micro 4.03.51, turn off window inhibits (avoid sabotage from feature for Mako)
//
//    // clear the masking on the streamer
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//    TcpClientConnection *streamerConnection = (TcpClientConnection *)[[delegate streamerWindowController] connection];
//
//    if(streamerConnection)
//        [streamerConnection txMsg:@"H 0 0 0 0 0\n"];
//
//}
//
//- (void)connectionDidResolveAddress:(TcpClientConnection *)sender{
//
//    // we get here only if the ip address resolved and the NSStreamEventOpenCompleted event has occurred
//    // i.e. we actually are connected to the device and not just seeing stale Bonjour cache contents
//    // get the version number to demonstrate that we are connected
//
//    if( _server && [_server isEqualToString:sender.netService.name]){
//
//        [self setConnection:sender];
//        [self getInitialValues];
//    }
//
//}
//-(void)connectionWillResolveAddress:(TcpClientConnection *)sender{
//
//}
//-(void) processMsgArray:(NSMutableArray *)msgArray :(id)connection{
//
//    for(NSString *msg in msgArray){
//
//        if (msg.length == 0) continue;
//
//        NSString *trimmedMsg = [msg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//
//        NSArray *trimmedMsgArray = nil;
//
//        if([trimmedMsg rangeOfString:@"\t"].location == NSNotFound){
//
//            trimmedMsgArray = [trimmedMsg componentsSeparatedByString:@" "];
//
//        }else{
//
//            trimmedMsgArray = [trimmedMsg componentsSeparatedByString:@"\t"];
//
//        }
//        @try {
//
//            SEL cmd = NSSelectorFromString([_cmdDictionary objectForKey:[trimmedMsgArray objectAtIndex:0]]);
//            if(cmd != nil && [self respondsToSelector:cmd]){
//
//                // http://stackoverflow.com/questions/7017281/performselector-may-cause-a-leak-because-its-selector-is-unknown
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
//                [self performSelector:cmd withObject:connection withObject:trimmedMsgArray];
//#pragma clang diagnostic pop
//            }else{
//
//                // we are taking over streamer commands, send the commands to streamerWindowController
//
//                NSMutableArray *array = [[NSMutableArray alloc] initWithArray:[trimmedMsg componentsSeparatedByString:@"\n"]];   // the unlikely case that we have several lines
//                AleDelegate *delegate = ( AleDelegate *)[NSApp delegate];
//                [delegate.streamerWindowController processMsgArray:array :connection];
//            }
//        }
//        @catch (NSException *exception) {
//
//        }
//    }
//
//}
//// TODO: put something in stub
//- (void)processString:(NSString *)msg :(TcpClientConnection *)connection {
//
//}


@end
