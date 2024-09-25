//
//  Matrix.h
//  AleDoc
//
//  Created by James Ketcham on 8/15/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

// square law taper, 195 is 9.8dB
// V1.00.18 changed to 0 dB
#define FADER_0dB 104
#define FADER_6dB 127
#define FADER_MINUS_3dB 92
#define MAX_FADER_ATTENUATION 0     // 2.00.00 matrix

@class Matrix;
@class MatrixWindowController;
@class Item;

@protocol MatrixDelegate

-(void)saveUserDefaults:(id)sender;
//-(void)sendFader:(id)sender :(NSInteger)faderNumber;
//-(void)sendFader:(NSString*)colTitle :(NSString*) rowTitle :(NSInteger)faderSetting;
-(NSString*)sliderToString:(NSInteger) slider;
-(void)linkRemoteButton:(NSButton*)button :(Matrix*)matrix;
-(void)linkRemoteButton:(int)tag :(int)state :(Matrix*)matrix;
-(void)linkRemoteSlider:(NSSlider*)slider :(Matrix*)matrix;
-(void)linkRemoteDelayedVideo:(bool) state :(Matrix*)matrix;

@end
#define STATE_ROWS 32   // we need room for items past beeps (15)
#define STATE_COLS 4
@interface Matrix : NSObject<NSCoding,NSSecureCoding>{
    
    NSInteger states[STATE_COLS][STATE_ROWS];    // off/reh/rec/pb switches
}

@property(class, readonly) BOOL supportsSecureCoding;

@property NSString *boxTitle;

@property bool buttons;  // 2.00.00 if no buttons, don't add to displayedMatrixArray

@property int state0;
@property int state1;
@property int state2;
@property int state3;
@property int state4;
@property int state5;
@property int state6;
@property int state7;
@property int state8;
@property int state9;
@property int state10;
@property int state11;
@property int state12;
@property int state13;
@property int state14;

@property NSInteger fader0;
@property NSInteger fader1;
@property NSInteger fader2;
@property NSInteger fader3;
@property NSInteger fader4;

@property NSString *tip0;
@property NSString *tip1;
@property NSString *tip2;
@property NSString *tip3;
@property NSString *tip4;

@property bool overlay;

@property (nonatomic,assign) MatrixWindowController *delegate;

@property Item *item;  // our item

@property bool isSelected;  // change background color

@property bool followDelayedVideo;

@property bool controlsDisabled; // when linked to Actor or Editor, disable controls

@property NSMutableArray<NSMutableArray<NSDictionary*>*> *crosspointArrays; // 2.00.00 crosspoint arrays for faders
// access

//-(void)buttonPressed:(id)sender;
-(void)setToDefaultSliderValue:(NSInteger)tag;
-(void)setAllFadersToDefaultSliderValue;

-(int)toggleStates:(int)state;
-(void)refreshCrosspoints;
-(void)stateFromStates; // 2.00.00'
-(NSInteger)stateForRow:(NSInteger)row;
-(void)printStates;
-(NSInteger)stateForTag:(NSInteger)tag; //2.00.00
-(void)setAllStates:(bool)state; // 2.00.00 set all states of hidden switchers
-(id)init:(NSInteger)numInputs;
-(void)forceState:(int) btnTag :(bool)on;
-(void)forceSlider:(NSSlider*)slider;
-(void)copySettingsFromMatrix:(Matrix*)matrix;
//-(void*)statePtr;
@end
