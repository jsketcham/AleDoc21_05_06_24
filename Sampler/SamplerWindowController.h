//
//  SamplerWindowController.h
//  AleDoc
//
//  Created by James Ketcham on 9/2/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DropButton.h"

@interface SamplerWindowController : NSWindowController<DropButtonDelegate,NSSpeechSynthesizerDelegate>

@property (weak) IBOutlet DropButton *loop0;
@property (weak) IBOutlet DropButton *loop1;
@property (weak) IBOutlet DropButton *loop2;
@property (weak) IBOutlet DropButton *loop3;
@property (weak) IBOutlet DropButton *loop4;
@property (weak) IBOutlet DropButton *loop5;
@property (weak) IBOutlet DropButton *loop6;
@property (weak) IBOutlet DropButton *loop7;
@property (weak) IBOutlet DropButton *loop8;
@property (weak) IBOutlet DropButton *loop9;
@property (weak) IBOutlet DropButton *loop10;
@property (weak) IBOutlet DropButton *loop11;

@property (weak) IBOutlet NSComboBox *voiceComboBox;

@property (strong) IBOutlet NSTextView *textView;

- (IBAction)onPlaybackButton:(id)sender;
- (IBAction)onAnnounceTake:(id)sender;
- (IBAction)onPlaybackButton2:(id)sender;

//- (IBAction)onSamplerRecord:(id)sender;
//- (IBAction)onSamplerPlay:(id)sender;
//- (IBAction)onSamplerPlayLast:(id)sender;
//
//- (IBAction)onBeepsTrim:(id)sender;

//@property NSInteger samplerPlayState;

//@property (weak) IBOutlet NSButton *recordButton;
@property (weak) IBOutlet DropButton *playbackButton;
@property (weak) IBOutlet DropButton *playbackButton2;
//@property (weak) IBOutlet NSButton *playLastButton;
@property bool samplerPlaysInPlayback;

//- (IBAction)onStart:(id)sender;
//- (IBAction)onStop:(id)sender;

@property id osaScript;

@property id objCPlayFile;

- (IBAction)onLoop:(id)sender;

//-(void)loopWithTag:(NSInteger) tag start:(bool)start;
//-(void)recordQuicktime:(bool)start;
//-(void)playbackQuicktime:(bool)start;
//-(void)playbackLastQuicktime:(bool)start;
//-(void)loopFromXKey:(NSInteger)xKey;
//-(bool)getXKeyState:(int)xKey;
-(void)playback:( bool)playbackOn;
-(NSString*)selectedVoice;
//-(void)say:(NSString*)msg :(NSString*)voice;
-(void)say:(NSString*)msg;
-(void)sayTake:(NSString*)msg;
-(void)loopFromOsc:(NSInteger)keyNumber;
-(void)loopToOsc:(DropButton*)btn;
-(void)initLoopButtons;

@end
