//
//  Accessory.m
//  MtcGenerator
//  rx cc commands from a controller, other sorts of commands are rx'd but are stubbed out
//
//  Created by James Ketcham on 3/31/16.
//  Copyright © 2016 James Ketcham. All rights reserved.
//

#import "Accessory.h"
#import "MidiCommands.h"
#import "MidiClient_v2.h"

@interface Accessory(){
    
    Byte midiBuffer[MIDI_BUFFER_SIZE];
    Byte midiBufferIndex;
    
}

//
@property MidiClient* commandDecoder;    // our parent, where tx lives

@end

@implementation Accessory

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
#pragma mark ------------ Accessory command decoder ------------------

-(void)decodeData:(NSData*)data{
    
    // this decoder can take packets with multiple commands in them
    // unlike the LauunchPad Mini decoder which must have 1 command per packet
    
    unsigned char *buffer = (unsigned char *)[data bytes];
    
    for(int i = 0; i < data.length; i++){
        
        [self rxMidiByte:*buffer++];
    }
}
/************************************************************
 rxMidiByte
 *************************************************************/

-(int) rxMidiByte:(Byte) c{
    
    //    printf("%02x ",c);
    
    if(c & 0x80 && c != MIDI_EOX){
        
        midiBuffer[0] = c;
        midiBufferIndex = 1;
        if(c < 0xF0) return -1;  // return 'not success' if not a system common message
        
    }else{
        
        midiBuffer[midiBufferIndex++] = c;  // index wraps, buffer is 256 bytes
    }
    
    
    // 'running status' repeats the last command
    
    switch(midiBuffer[0] & 0xf0) {
            
        case NOTE_OFF:
        case POLY_PRESSURE: //0xa0
        case PITCH_BEND: //0xe0
            // unused commands with two operands
            
            if(midiBufferIndex < 3) break;
            midiBufferIndex = 1;
            
            return 0;
            
        case NOTE_ON:
            
            if(midiBufferIndex < 3) break;
            [self noteOnService:midiBuffer];
            midiBufferIndex = 1;
            
            return 0;
            
            
        case CONTROL_CHANGE:
            
            if(midiBufferIndex < 3) break;
            [self controlChangeService:midiBuffer];
            midiBufferIndex = 1;
            
            return 0;
            
        case PROG_CHANGE: //0xc0
        case CHANNEL_PRESSURE: //0xd0
            // unused commands with one operand
            
            if(midiBufferIndex < 2) break;
            midiBufferIndex = 1;
            
            return 0;
            
            
        case SYSTEM_EXCLUSIVE:   // actually 0xf0-0xff, system common messages
            
            switch(midiBuffer[0]){
                    
                case SYSTEM_EXCLUSIVE:
                    
                    if(c != MIDI_EOX) break;
                    [self sysexService:midiBuffer]; // some of the ARC problem is here, uses 4% of CPU time FIXME
                    midiBufferIndex = 0;
                    
                    return 0;
                    
                case MTC_QUARTER_FRAME: // one operand
                    
                    if(midiBufferIndex < 2) break;
                    midiBufferIndex = 0;
                    
                    return 0;
                    
                case SONG_POSITION_PTR:
                    // two operands
                    if(midiBufferIndex < 3) break;
                    midiBufferIndex = 0;
                    
                    return 0;
                    
                case SONG_SELECT:
                    // one operand
                    if(midiBufferIndex < 2) break;
                    midiBufferIndex = 0;
                    
                    return 0;
                    
                default:
                    // system common messages with no operands
                    
                    midiBufferIndex = 0;
                    
                    return 0;
                    
            }
            break;
            
        default:
            // mystery messages, no operands :-(
            midiBufferIndex = 0;
            
            return -1;
    }
    
    return -1;  // not success if we get this far
}
/************************************************************
 noteOnService
 *************************************************************/
-(void) noteOnService:(Byte *)buffer {
}
/************************************************************
 controlChangeService
 *************************************************************/

-(void) controlChangeService:(Byte *)buffer {
    
    // Evan's surfaces send 'control change'
    
    if(_delegate && [_delegate respondsToSelector:@selector(accessoryService:)]){
        
        [_delegate performSelectorOnMainThread:@selector(accessoryService:) withObject:[NSData dataWithBytes:buffer length:3] waitUntilDone:false];
    }
}
/************************************************************
 sysexService
 *************************************************************/
-(void) sysexService:(Byte *)buffer{
}

@end
