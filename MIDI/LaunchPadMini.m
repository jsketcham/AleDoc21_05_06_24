//
//  LaunchPadMini.m
//  MtcGenerator
//
//  Created by James Ketcham on 3/31/16.
//  Copyright © 2016 James Ketcham. All rights reserved.
//

#import "LaunchPadMini.h"
#import "MidiCommands.h"
#import "MidiClient_v2.h"

@interface LaunchPadMini()

@property MidiClient* commandDecoder;    // our parent, where tx lives

@end


@implementation LaunchPadMini

@synthesize commandDecoder = _commandDecoder;

#pragma mark --
#pragma mark ------------ setters/getters ------------------

-(void)setCommandDecoder:(id)commandDecoder{
    
    // this is called 'command decoder' to match an available prototype in MidiClient
    // (to keep the compiler from flagging it)
    _commandDecoder = (MidiClient*)commandDecoder;   // our parent, where tx lives
}
-(id)commandDecoder{
    
    return _commandDecoder;
}
#pragma mark --
#pragma mark ------------ LaunchPadMini command decoder ------------------

-(void)decodeData:(NSData*)data{
    
    // note that we are counting on LaunchPad Mini to send 3 byte packets
    
    if(_delegate && [_delegate respondsToSelector:@selector(launchPadKeyPressed:)])
        [_delegate performSelectorOnMainThread:@selector(launchPadKeyPressed:) withObject:data waitUntilDone:false];
}
#pragma mark -------- initializer -------------------
-(void)initState{
    
//    NSLog(@"initState");
    
    if(_delegate && [_delegate respondsToSelector:@selector(initAipHead)])
        [_delegate performSelectorOnMainThread:@selector(initAipHead) withObject:nil waitUntilDone:false];
}

@end
