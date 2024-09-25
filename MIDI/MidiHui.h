//
//  MidiHui.h
//  MtcGenerator
//
//  Created by James Ketcham on 1/14/16.
//  Copyright © 2016 James Ketcham. All rights reserved.
//

#import <Foundation/Foundation.h>


@class MidiHui;
@class MidiClient;

@protocol MidiHuiDelegate

-(void)showProtoolsCtr:(NSString*)ctr;
-(void)showMotionStatus:(NSData*)data;  // to indicator
-(void)showDisplayStatus:(NSData*)data; // to indicator
-(void)relayMidiData:(NSData*)data;
-(void)didRxPing;
-(void)showMutes:(NSData*)data; // test for Fox 

@end

// there is a separate mtc delegate because we want
// to have separate menu items for mtc and protools

@protocol MidiHuiMtcDelegate

-(void)showTcDigits:(NSString*)ctr;
//-(void)mtcNotLocked;    // to indicator
-(void)mtcLocked:(NSNumber*)lockState;       // to indicator

@end

@interface MidiHui : NSObject

@property id delegate;
@property id mtcDelegate;
@property (readonly) int dropoutDownCtr;
@property NSDate *frameDate;    // when the frame arrived
@property MidiClient* commandDecoder;    // our parent, where tx lives
@property Byte mtcType; // 2.10.02 need to know mtc type to calc video delays

-(bool)isStop;
-(BOOL)isPlay;
-(bool)isRecord;

-(void)onStop;
-(void)onPlay;
-(void)onRecord;
-(void)onShuttle;
-(void)onJog;
-(void)onTransport;

-(void)tcDigitsFromTc:(NSString *)tc;
-(int)getTcType;
-(unsigned char)getDisplayFmt;
-(void)onMute:(Byte)index;  // toggle the mute for selected fader
//-(void)initMtcTimeouts;

@end
