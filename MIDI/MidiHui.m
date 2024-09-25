//
//  MidiHui.m
//  MtcGenerator
//
//  Created by James Ketcham on 1/14/16.
//  Copyright © 2016 James Ketcham. All rights reserved.
//
//  this is a HUI MIDI command decoder.

#import "MidiHui.h"
#import "MidiCommands.h"
#import "MidiClient_v2.h"
#import <Cocoa/Cocoa.h>

// count of downcount frames in mtc dropout detector
#define NUM_DROPOUT_FRAMES 15

#define NUM_FREEWHEEL_FRAMES 15

#define NUM_QUARTER_FRAMES 8

// freewheeler periods
#define FRAME_PERIOD_0 .04166
#define FRAME_PERIOD_1 .04000
#define FRAME_PERIOD_2 .03333
#define FRAME_PERIOD_3 .03333

const char proToolsHeader[] = {SYSTEM_EXCLUSIVE,0x00,0x00,0x66,0x05,0x00,0x11}; // timecode display

@interface MidiHui(){
    
    Byte midiBuffer[MIDI_BUFFER_SIZE];
    Byte midiBufferIndex;
    Byte lastMtcIndex;
    
    Byte tcType;
    Byte controlTable[0x20]; // table of decoded control bits
    
//    MIDI_MOTION midi_motion;
//    MIDI_DISPLAY_FMT midi_display_fmt;
    
    int quarterFrameDowncount;
    
    Byte zone;   // the zone of LEDs being set (see hui.pdf)
    Byte mtc[4];            //hh,mm,ss,ff rx
    Byte mtcLast[4];        //hh,mm,ss,ff sequential check
    Byte mtcLastGood[4];    //hh,mm,ss,ff filtered
    Byte tcDigits[8];
    
    NSDate *frameDate;
    
    int freewheelDownCtr;

}
//
@property NSString *tcString;
@property NSString *ptCtrString;
@property NSTimer *mtcFreewheelTimer;   // freewheel for NUM_FREEWHEEL_FRAMES over dropoouts

@end

@implementation MidiHui

@synthesize commandDecoder = _commandDecoder;
@synthesize frameDate = _frameDate;
@synthesize mtcType = _mtcType;

-(id)init{
    
    self = [super init];
    
    if(self){
        // other initialization goes here
        //        midi_display_fmt.tc = 1;    // assume tc format
        
        [self initMtcTimeouts];
        
    }
    
    return self;
}

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
#pragma mark ------------ HUI MIDI command decoder ------------------

-(void)decodeData:(NSData*)data{
    
//    NSLog(@"HUI decodeData %ld",data.length);
    
    unsigned char *buffer = (unsigned char *)[data bytes];
    
//    NSString *str = @"";
//    
//    for(int i = 0; i < data.length; i++){
//        str = [str stringByAppendingFormat:@"%02x ",buffer[i]];
//    }
//    
//    if(buffer[0] == 0xf1){
//        NSLog(@"HUI decodeData %@",str);
//    }
    
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
            if(midiBufferIndex < 3) break;
            [self noteOffService:midiBuffer];
            midiBufferIndex = 1;
            
            return 0;
            
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
            
            //printf("%02x ",c);
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
                    [self mtcService:midiBuffer]; // some of the ARC problem is here, uses 4% of CPU time
                    
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
// MARK: -------- NoteOffService -----------

-(void) noteOffService:(Byte *)buffer {
    
    // 2.00.00 11/1/22 PT Ultimate we see 80 00 40 for ping, this
    // keeps the PT HUI error dialog from appearing
    Byte pingResponse[] = {0x90,0x00,0x7f};
    
    if(_commandDecoder && buffer[1] == 0 && buffer[2] == 0x40){
        
        [_commandDecoder midiTx:[NSData dataWithBytes:pingResponse length:3]];
        
        if(_delegate && [_delegate respondsToSelector:@selector(didRxPing)]){
            
            [_delegate performSelectorOnMainThread:@selector(didRxPing) withObject:nil waitUntilDone:false];
        }
    }

    
}

/************************************************************
                noteOnService
 *************************************************************/
-(void) noteOnService:(Byte *)buffer {
    
    Byte pingResponse[] = {0x90,0x00,0x7f};
    
    switch(buffer[1]){
            
        case 0:
            
            if(_commandDecoder && buffer[2] == 0) [_commandDecoder midiTx:[NSData dataWithBytes:pingResponse length:3]];  // NOTE_ON note 0, velocity 0 is a polling request (see /components/hui.pdf)
            if(_delegate && [_delegate respondsToSelector:@selector(didRxPing)]){
                
                [_delegate performSelectorOnMainThread:@selector(didRxPing) withObject:nil waitUntilDone:false];
            }
            break;
            
    }
}
/************************************************************
            controlChangeService
 *************************************************************/
-(void) controlChangeService:(Byte *)buffer {
    
    Byte mask = 1;
    Byte shiftCount = buffer[2] & 7;
    Byte mute[2];
    
//    NSLog(@"controlChangeService %02x %02x %02x",buffer[0],buffer[1],buffer[2]);
    
    mask <<= shiftCount;
    
    // 0xb0 0xc 0xe 0xb0 0x2c aa 0x2c bb
    
//    NSLog(@"controlChangeService %02x %02x %02x",buffer[0],buffer[1],buffer[2]);
    
    switch(buffer[1]){
            
        case 0xc:
            zone = buffer[2];
            if(_delegate && zone == ZONE_DISPLAY)
                [_delegate relayMidiData:[NSData dataWithBytes:buffer length:3]];   // relay display fmt only 1/7/16
            
            break;   // see hui.pdf re. zones, MIDI spec says control +0x20 is the lsb of the control
        case 0x2c:
            
            if(zone > 0x1d) return; // illegal zone
            
            if(buffer[2] & 0x40)    controlTable[zone] |= mask;     // setting the bit
            else                    controlTable[zone] &= ~mask;    // clearing the bit
            
            if(_delegate){
                
                switch (zone) {
                        
                    case ZONE_FADER0:   // for a simple ADR switcher, guide and pb on faders
                    case ZONE_FADER1:
                    case ZONE_FADER2:
                    case ZONE_FADER3:
                    case ZONE_FADER4:
                    case ZONE_FADER5:
                    case ZONE_FADER6:
                    case ZONE_FADER7:
                        
                        if(shiftCount == 2){    // mute bit changed
                            
                            mute[0] = zone; // fader number 0-7
                            mute[1] = controlTable[zone];   // mute bit is [2]
                            
                            [_delegate performSelectorOnMainThread:@selector(showMutes:) withObject:[NSData dataWithBytes:&mute length:2] waitUntilDone:false];
                        }
                        
                        break;
                        
                    case ZONE_MOTION:
                        
                        [_delegate performSelectorOnMainThread:@selector(showMotionStatus:) withObject:[NSData dataWithBytes:&controlTable[ZONE_MOTION] length:1] waitUntilDone:false];
                        
                        break;
                        
                    case ZONE_DISPLAY:
                        
                        [_delegate performSelectorOnMainThread:@selector(relayMidiData:) withObject:[NSData dataWithBytes:buffer length:3] waitUntilDone:false];
                        [_delegate performSelectorOnMainThread:@selector(showDisplayStatus:) withObject:[NSData dataWithBytes:&controlTable[ZONE_DISPLAY] length:1] waitUntilDone:false];
                        
                        break;
                        
                    default:
                        break;
                }
            }
            
            break;
            
        default:
            break;
    }
    
}
/************************************************************
                        mtcService
 *************************************************************/
-(void)mtcFreewheelTimerService{
    
    if(!freewheelDownCtr) return;
    
//    NSLog(@"mtcFreewheelTimerService %d",freewheelDownCtr);

    // when we start freewheeling, cause the reader to get 8 quarter frames
    if(freewheelDownCtr == NUM_FREEWHEEL_FRAMES) lastMtcIndex = 0xff;   // causes 'missing 1/4 frame' always
    
    freewheelDownCtr--;
    [self incrTc:mtcLastGood];   
    
    if(_mtcDelegate){
        
//        [self setTcString: [NSString stringWithFormat:@"%02d:%02d:%02d:%02d",
//                            (mtcLastGood[0] & 0x1f),mtcLastGood[1],mtcLastGood[2],mtcLastGood[3]]];  // tctype is top 2 bits of hh
        [self setTcString: [self tcToString: mtcLastGood]]; // 12/3/19
        
//        NSLog(@"mtcFreewheelTimerService %@",_tcString);
        [_mtcDelegate performSelectorOnMainThread:@selector(showTcDigits:) withObject:_tcString waitUntilDone:false];
    }
    
    if(!freewheelDownCtr) [self initMtcTimeouts];   // timed out, reset for next mtc run
    
    // while freewheeling, set the lock indicator to NSOffState. When freewheeling times out,
    // set the lock indicator to NSMixedState.
    NSNumber *lockState = [NSNumber numberWithInteger:freewheelDownCtr ? NSControlStateValueOff : NSControlStateValueMixed];
    
    if(_mtcDelegate)[_mtcDelegate performSelectorOnMainThread:@selector(mtcLocked:) withObject:lockState waitUntilDone:false];
    
}
-(void)freewheelerService:(NSDate*)date{
    
    freewheelDownCtr = NUM_FREEWHEEL_FRAMES;
    
    NSTimeInterval ti;
    
    // freewheeler period depends on tcType
    
    switch (tcType) {
            
        case 0: ti = FRAME_PERIOD_0; break;
        case 1: ti = FRAME_PERIOD_1; break;
        default: ti = FRAME_PERIOD_3; break;
    }
    
//    NSLog(@"freewheelerService frame period: %f",ti);
    
    if(_mtcFreewheelTimer && _mtcFreewheelTimer.isValid){
        
//        NSLog(@"invalidating _mtcFreewheelTimer, %3.3f",ti);
        [ _mtcFreewheelTimer invalidate];
    }
    
    [self setMtcFreewheelTimer:[NSTimer scheduledTimerWithTimeInterval:ti target: self selector:@selector(mtcFreewheelTimerService) userInfo:nil repeats: YES]];   // freewheel
    
    date = [date dateByAddingTimeInterval:(ti + ti / 4)]; // 1.25 periods from now
    [_mtcFreewheelTimer setFireDate:date];
    
    
}
-(void) mtcService:(Byte *) buffer{
    
//    NSLog(@"mtcService %02x %02x",buffer[0],buffer[1]);
    
    // v1.00.18 relay MTC to output
#ifndef SKIP_RELAY
    if(_commandDecoder)[_commandDecoder midiTx:[NSData dataWithBytes:buffer length:2]];
#endif
    
    if(quarterFrameDowncount > 0) quarterFrameDowncount--;  // mtc is not valid for 8 1/4 frames after PLAY leading edge
    
    Byte mtcIndex = buffer[1] >> 4; //NSLog(@"%d",mtcIndex);
    
    if(mtcIndex != lastMtcIndex){   // logging missing 1/4 frames
        
        quarterFrameDowncount = NUM_QUARTER_FRAMES;
//        NSLog(@"missing 1/4 frame, expected %d, rx'd %d",lastMtcIndex,mtcIndex);
        
    }
    
    lastMtcIndex = mtcIndex;
    lastMtcIndex++; lastMtcIndex &= 7;  // after compare so we can do 0xff message from mtcFreewheelTimerService
    
//    NSLog(@"mtcIndex: %d buffer[1]: %02x",mtcIndex,buffer[1]);
        
    switch(mtcIndex){
        case 0:
            
            mtc[3] &= 0x10;
            mtc[3] += buffer[1] & 0xf;
            break;
            
        case 1:
            
            mtc[3] &= 0xf;
            mtc[3] += (buffer[1] & 1) << 4; // 000 yyyyy
            break;
            
        case 2:
            
            mtc[2] &= 0x30;
            mtc[2] += buffer[1] & 0xf;
            break;
            
        case 3:
            
            mtc[2] &= 0xf;
            mtc[2] += (buffer[1] & 3) << 4; // 00 yyyyyy
            
            [self tcFilter:mtc];
            break;
            
        case 4:

            
            mtc[1] &= 0x30;
            mtc[1] += buffer[1] & 0xf;
            break;
            
        case 5:

            mtc[1] &= 0xf;
            mtc[1] += (buffer[1] & 3) << 4; // 00 yyyyyy
            break;
            
        case 6:

            mtc[0] &= 0x70;
            mtc[0] += buffer[1] & 0xf;
            break;
            
        case 7:
            mtc[0] &= 0xf;
            mtc[0] += (buffer[1] & 7) << 4; // 0 xx yyyyy, xx is tc type
//            tcType = (mtc[0] >> 5) & 3; // convenience copy
//            NSLog(@"tcType: %d hh: %d",tcType, mtc[0]);
            
            [self tcFilter:mtc];
            break;
    }
}
-(void) incrTc:(Byte*)t{
    
    // the tctype is in[6-5] of t[0]
    Byte mtcType = (t[0] >> 5) & 3;
    
    self.mtcType = mtcType;

    t[3]++;
    
    switch (mtcType) {
        case 0:
            // 24 fps
            if(t[3] < 24) return;
            break;
            
        case 1:
            
            if(t[3] < 25) return;
            break;
            
        default:
            
            if(t[3] < 30) return;
            break;
    }
    
    t[3] = 0;
    t[2]++;
    
    if(t[2] < 60) return;
    
    t[2] = 0;
    t[1]++;
    
    // df?
    if(mtcType == 2){
        
        if(t[1] % 10) t[3] = 2; // every minute except the 10's
        
    }
    
    if(t[1] < 60) return;
    
    t[1] = 0;
    Byte hh = t[0] & 0x1f;
    hh++;
    hh %= 24;
    
    t[0] = hh | (t[0] & 0x60);  // retain tc type
    
}

-(NSString*)tcToString:(Byte*)t{    // a debug helper
    
    // 12/3/19 DF frs delimiter is ';'
    unsigned char type = (t[0] >> 5) & 3;  // tctype is [5:6]
    unsigned char frsDelimiter = type == 2 ? ';' : ':';

    return [NSString stringWithFormat:@"%02d:%02d:%02d%c%02d",
            (t[0] & 0x1f),t[1],t[2],frsDelimiter,t[3]];
    
}

-(void)tcFilter:(Byte*)t{

    _frameDate = [NSDate date]; // when the frame arrived FIXME: debug temp
    
//    if (frameDate != nil) {NSLog(@"%f",frameDate.timeIntervalSinceNow);}
    frameDate = NSDate.date;    // when the frame was rx'd
    
//    NSLog(@"tcFilter last, rx: %@ %@",[self tcToString:mtcLast],[self tcToString:t]);
    
//    NSLog(@"hh: %d tctype: %d",t[0], tcType);  // 11/22/2019 Evan sees a DF bug
    bool isSequential = !memcmp(mtcLast, t, 4); // compare rx to last rx to see if tc is sequential
//       NSLog(@"isSequential: %d t:%02x:%02x:%02x:%02x mtcLast:%02x:%02x:%02x:%02x ",isSequential,t[0],t[1],t[2],t[3],mtcLast[0],mtcLast[1],mtcLast[2],mtcLast[3]);  // 11/22/2019 Evan sees a DF bug
    
    memcpy(mtcLast, t, 4);
   
    [self incrTc:mtcLast];[self incrTc:t];      // what we expect
    
    if(quarterFrameDowncount) return;
    
    if(isSequential){
        
        memcpy(mtcLastGood, t, 4);
        tcType = (t[0] >> 5) & 3;   // filtered
        
        [self performSelectorOnMainThread:@selector(freewheelerService:) withObject:[NSDate date] waitUntilDone:false];
        
        if(_mtcDelegate){
            
//            [self setTcString: [NSString stringWithFormat:@"%02d:%02d:%02d:%02d",
//                                (t[0] & 0x1f),t[1],t[2],t[3]]];  // tctype is top 2 bits of hh
            
            [self setTcString: [self tcToString: t]]; // 12/3/19
            
//            NSLog(@"%@",_tcString);
            
            [_mtcDelegate performSelectorOnMainThread:@selector(showTcDigits:) withObject:_tcString waitUntilDone:false];
        }
        
    }else{
        
        _dropoutDownCtr = NUM_DROPOUT_FRAMES;
        
    }
    
    if(_dropoutDownCtr) _dropoutDownCtr--;
    
    NSNumber *lockState = [NSNumber numberWithInteger:_dropoutDownCtr ? NSControlStateValueOff : NSControlStateValueOn];
    
    if(_mtcDelegate) [_mtcDelegate performSelectorOnMainThread:@selector(mtcLocked:) withObject:lockState waitUntilDone:false];

}

/************************************************************
            sysexService
 *************************************************************/
-(void) sysexService:(Byte *)buffer{
    
    Byte hdr[] = {0x7f,0x1,0x1};
    
    if(!memcmp(hdr, &buffer[1], sizeof(hdr))){
        
        // MTC full message
        memcpy(mtc,&buffer[5],4);
        
        if(_delegate){
            
//            [self setTcString: [NSString stringWithFormat:@"%02d:%02d:%02d:%02d",
//                                (mtc[0] & 0x1f),mtc[1],mtc[2],mtc[3]]];  // tctype is top 2 bits of hh
            
                [self setTcString: [self tcToString: mtc]]; // 12/3/19
            
            [_delegate performSelectorOnMainThread:@selector(showTcDigits:) withObject:_tcString waitUntilDone:false];
        }
        
        return;
        
    }
    
    int i,j;
    
    if(!memcmp(proToolsHeader,buffer,sizeof(proToolsHeader))){   // if proTools position...
        
        j = 0; // index ff
        
        i = sizeof(proToolsHeader);
        
        for(j = 7; (j >= 0) && (buffer[i] != MIDI_EOX); j--){
            
            tcDigits[j] = buffer[i++];  // lsb is tcDigits[7]
        }
        
        [self show_hui]; // format hui segments based on current format selector
        
        // relay Protools counter
        if(_delegate)[_delegate relayMidiData:[NSData dataWithBytes:buffer length:++i]];
        
    }
    
}
/************************************************************
 getTcType
 *************************************************************/
-(int)getTcType{
    return tcType; // 0-3
}

/************************************************************
 tcDigitsFromTc
 *************************************************************/
-(void)tcDigitsFromTc:(NSString *)tc{
    
    // preload tcDigits with what we expect
    NSArray *t = [tc componentsSeparatedByString:@":"];
    
    if([t count] != 4) return;
    
//    midi_display_fmt.tc = true;
//    midi_display_fmt.ft_fr = false;
//    midi_display_fmt.bar_beat = false;
    
    int hh = [[t objectAtIndex:0] intValue];
    int mm = [[t objectAtIndex:1] intValue];
    int ss = [[t objectAtIndex:2] intValue];
    int ff = [[t objectAtIndex:3] intValue];
    
    tcDigits[0] = hh / 10;
    tcDigits[1] = 0x10 | (hh % 10);
    
    tcDigits[2] = mm / 10;
    tcDigits[3] = 0x10 | (mm % 10);
    
    tcDigits[4] = ss / 10;
    tcDigits[5] = 0x10 | (ss % 10);
    
    tcDigits[6] = ff / 10;
    tcDigits[7] = ff % 10;
    
    [self show_hui];    // display the tc
}
/************************************************************
 getDisplayFmt
 *************************************************************/
-(unsigned char)getDisplayFmt{
    
    return controlTable[ZONE_DISPLAY];
}
/************************************************************
    show_hui
 *************************************************************/

-(void) show_hui{
    
    int i,sign;
    char ascii[16];
    long hh;  // many samples
    int mm,ss,ff;
    unsigned char num_separators = 0;
    
    /* trace from Fox 2/4/2013
     
     fmt tcDigits
     02  20 20 20 11 11 00 00 00 1|1         bar/beat, 2 separators
     00  20 20 10 00 10 00 00 00 0.00.000    min/sec, 2 separators
     00  00 10 05 18 00 10 00 00 00:58:00:00 timecode, 3 separators
     01  20 20 20 20 20 10 00 00 0.00        ft/fr, 1 separator
     00  20 20 20 20 20 20 20 00 0           samples, no separators
     
     */
    
//    NSLog(@"%02x %02x %02x %02x %02x %02x %02x %02x ",tcDigits[0],tcDigits[1],tcDigits[2],tcDigits[3],tcDigits[4],tcDigits[5],tcDigits[6],tcDigits[7]);
    
    // shutdown message: f0 00 00 66 05 00 11 20 20 20 20  20 f7
    ascii[0] = 0;
    
    if(!memcmp(&tcDigits[3],"     ",5)){
        
        if(_delegate){
            [_delegate performSelectorOnMainThread:@selector(showProtoolsCtr:) withObject:@"" waitUntilDone:false];
        }
        
        return; // shutdown, leave display blank TODO
    }
    
    hh = 0;
    mm = 0;
    ss = 0;
    ff = 0;
    sign = 1;
    num_separators = 0;
    
    for(i = 0; i < 8; i++){
        
        switch(tcDigits[i]){
                
            case ' ': break;
            case '-': sign = -1; break;
            default:
                
                switch(num_separators){
                        
                    case 0:
                        hh *= 10;
                        hh += tcDigits[i] & 0xf;
                        break;
                    case 1:
                        mm *= 10;
                        mm += tcDigits[i] & 0xf;
                        break;
                    case 2:
                        ss *= 10;
                        ss += tcDigits[i] & 0xf;
                        break;
                    case 3:
                        ff *= 10;
                        ff += tcDigits[i] & 0xf;
                        break;
                    default: break;
                        
                }
                
                if(tcDigits[i] & 0x10) num_separators++;
                
        }
        
    }
    
    hh *= sign;
    
    MIDI_DISPLAY_FMT midi_display_fmt = *(pMIDI_DISPLAY_FMT)&controlTable[ZONE_DISPLAY];
    
    if(midi_display_fmt.bar_beat){
        
        // char 0x81 is a blank that is digit width
        (void)sprintf(ascii,"%ld|",hh);
        
        if(mm >= 10) strcat(ascii," ");
        else strcat(ascii,"  ");  // digit monospace blanks TODO monospace
        
        (void)sprintf(&ascii[strlen(ascii)],"%d",mm);
        
    }else if (midi_display_fmt.ft_fr){
        
        (void)sprintf(ascii,"%d+%02d",(int)hh,mm);
        
    }else if(midi_display_fmt.tc){
        
        hh %= 24;
        mm %= 60;
        ss %= 60;
        ff %= 30;
        
        (void)sprintf(ascii,"%02d:%02d:%02d:%02d",(int)hh,mm,ss,ff);
        
    }else{
        
        // min/sec,samples
        
        if(tcDigits[4] & 0x10){
            
            mm %= 60;
            
            
            (void)sprintf(ascii,"%d.%02d",(int)hh,mm);
            
        }else{
            
            // samples
            (void)sprintf(ascii,"%ld",hh);
            
        }
    }
    while(strlen(ascii) < 9){
        
        for(i = 14; i >= 0; i--) ascii[i + 1] = ascii[i];
        ascii[0] = ' ';  // TODO monospace font
        
    }
    
    //return; // TODO ARC debugging
    //http://stackoverflow.com/questions/10003962/breakpoint-pointing-out-objc-autoreleasenopool
    
    if(_delegate && [_delegate respondsToSelector:@selector(showProtoolsCtr:)]){
        
        [self setPtCtrString: [NSString stringWithFormat:@"%s",ascii]];
        [_delegate performSelectorOnMainThread:@selector(showProtoolsCtr:) withObject:_ptCtrString waitUntilDone:false];
        
//        NSLog(@"_ptCtrString: %@",_ptCtrString);
        
    }
    
}

#pragma mark --
#pragma mark --------- utilities ------------------
-(void)onStop{
    
    Byte msg[] = {
        0xb0,0xf,0x0e,    // zone select
        0xb0,0x2f,0x43
        
    };
    
    if(_commandDecoder)[_commandDecoder midiTx:[NSData dataWithBytes:msg length:sizeof(msg)]];
    //    NSLog(@"onStop");
    
}
-(void)onPlay{
    
    Byte msg[] = {
        0xb0,0xf,0x0e,    // zone select
        0xb0,0x2f,0x44
        
    };
    
    if(_commandDecoder)[_commandDecoder midiTx:[NSData dataWithBytes:msg length:sizeof(msg)]];
}
-(void)onRecord{
    
    Byte msg[] = {
        0xb0,0xf,0x0e,    // zone select
        0xb0,0x2f,0x45
        
    };
    
    if(_commandDecoder)[_commandDecoder midiTx:[NSData dataWithBytes:msg length:sizeof(msg)]];
    
}
-(bool)isStop{
    
    MIDI_MOTION midi_motion = *(pMIDI_MOTION)&controlTable[ZONE_MOTION];

    return  midi_motion.stop;
}
-(BOOL)isPlay{
    
    MIDI_MOTION midi_motion = *(pMIDI_MOTION)&controlTable[ZONE_MOTION];
    return  midi_motion.play;
    
}
-(bool)isRecord{
    
    MIDI_MOTION midi_motion = *(pMIDI_MOTION)&controlTable[ZONE_MOTION];
    return  midi_motion.record;
    
}
-(void)onShuttle{
    
    Byte msg[] = {
        0xb0,0xf,0x0d,    // zone select
        0xb0,0x2f,0x46
        
    };
    
    if(_commandDecoder)[_commandDecoder midiTx:[NSData dataWithBytes:msg length:sizeof(msg)]];
    
}
-(void)onJog{
    
    Byte msg[] = {
        0xb0,0xf,0x0d,    // zone select
        0xb0,0x2f,0x45
        
    };
    
    if(_commandDecoder)[_commandDecoder midiTx:[NSData dataWithBytes:msg length:sizeof(msg)]];
    
}
-(void)onTransport{
    
    Byte msg[] = {
        0xb0,0xf,0x0d,    // zone select
        0xb0,0x2f,0x6,
        0xb0,0x2f,0x5   // jog and shuttle off
        
    };
    
    if(_commandDecoder)[_commandDecoder midiTx:[NSData dataWithBytes:msg length:sizeof(msg)]];
    
}
-(void)initMtcTimeouts{
    
    _dropoutDownCtr = NUM_DROPOUT_FRAMES;
    quarterFrameDowncount = NUM_QUARTER_FRAMES;
    
}
-(bool)isFreewheeling{
    
    return !(freewheelDownCtr == 0);
}
-(void)onMute:(Byte)index{
    
    // we don't understand this- different than what HUI.pdf says
    // this message toggles the selected mute
    // we are in sync with PT because we got a 'control change'
    
    Byte msg[] = {
        
        0xb0,0xf,index,    // zone select
        0xb0,0x2f,0x42     // assume off
        
    };
    
//    NSLog(@"onMute  [%02x %02x %02x %02x %02x %02x]",msg[0],msg[1],msg[2],msg[3],msg[4],msg[5]);
    
    if(_commandDecoder)[_commandDecoder midiTx:[NSData dataWithBytes:msg length:sizeof(msg)]];
}
@end
