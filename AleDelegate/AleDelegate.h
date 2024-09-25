//
//  AleDelegate.h
//  TestDoc
//
//  Created by James Ketcham on 7/16/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "TcCalculator.h"
#import "MidiClient_v2.h"
#import "MidiHui.h"

#define DIAL_MUTE_KEY @"DialMuteKey"
#define DIAL_VALUE_KEY @"DialValueKey"
#define DIAL_CLIENT_KEY @"DialClientKey"
#define FIRST_DIAL_INDEX 92
#define LAST_DIAL_INDEX (FIRST_DIAL_INDEX + 16)

//#import "MidiClient.h"
//#import "SafetyRecorderClient.h"

// rev notes
// 6/11/17
// 1) Evan has seen long takes being lost. We added a state, CYCLE_MODE_RECORD_KEEP_TAKE, which is set once we are IN.
//  We commented out CYCLE_MODE_CANCEL_RECORD, and use CYCLE_MODE_RECORD as the decrement take indicator (never got IN)
//  we added a decrement of the record take for CYCLE_MODE_SKIP_PASTE

// V1.00.15 05/06/20
// revised StreamerWindowController.triggerStreamer() so that if PT is offline,
// cue sheet runs. We don't have PT in our office, need to duplicate streamer
// trigger problem at WB.

@class OverlayWindowController;
@class MidiClient;
@class MatrixWindowController;
@class EditorWindowController;
@class AdrClientWindowController;
@class StreamerWindowController;
@class Document;
@class XKey;
@class LpMini;
@class AudioPlayerWindowController;
@class ScreenRecorder;
@class VideoDelayWindowController;
@class DialMidiWindowController;
@class LoopMidi;
@class StatusMidi;
@class ControlMidi;
@class MtcMidi;


enum {
    CYCLE_MOTION_IDLE,
    CYCLE_MOTION_STARTING,
    CYCLE_MOTION_ACTIVE,
    CYCLE_MOTION_STOPPING,
    CYCLE_MOTION_PENDING    // PLAYBACK or REHEARSE after RECORD, RECORD from either
};  // cycleMotion enums

enum{
    CYCLE_MODE_IDLE,
    CYCLE_MODE_RECORD,              // AHEAD
    CYCLE_MODE_RECORD_KEEP_TAKE,    // IN
    CYCLE_MODE_SKIP_PASTE,           // shift-play/stop
    CYCLE_MODE_FINALIZE_RECORD      // for blocking CYCLE button while we are finishing
};  // cycleMode enums

enum{
    ENTRY_IDLE,
    ENTRY_ACTIVE
};

enum {REC_DELAY_OFF,
    REC_DELAY_ON,
    REC_DELAY_CAL
};

enum{
    SNOOP_STATE_OFF,
    SNOOP_STATE_ON,
    SNOOP_STATE_FORCE_OFF,
    SNOOP_STATE_FORCE_ON
    
};

// MIDI and local dims are OR'd
#define DIM_MASK 1
#define DIM_MIDI_MASK 2

// the top row of round buttons is in row [8] so that the index of the others is its note or cc number
#define MICSTATE_SIZE       0x90
#define COLOR_AIP_RED       0xf
#define COLOR_AIP_GREEN     0x3c
#define COLOR_AIP_GREEN_DIM 0x1c
#define COLOR_AIP_AMBER     0x3f
#define COLOR_AIP_OFF       0xc
#define COLOR_AIP_AMBER_DIM 0x1D
#define COLOR_AIP_YELLOW    0x3e
#define COLOR_RED_BLINK     0xb

// colors for 'btn', rgb values
#define COLOR_OSC_ALICE_BLUE 0xF0F8FF
#define COLOR_OSC_POWDER_BLUE 0xB0E0E6
#define COLOR_OSC_WHITE 0xffffff
#define COLOR_OSC_BLACK 0x0
#define COLOR_OSC_OFF 0x404040
#define COLOR_OSC_RED 0xff0000
#define COLOR_OSC_GREEN 0x00ff00
#define COLOR_OSC_BLUE 0x0000ff

#define CUSTOM_FILL_INDEX 0x78


@interface AleDelegate : NSObject<NSApplicationDelegate>

@property NSInteger entryState;
@property bool cancelCurrentCycle; // FIXME
//@property NSInteger cueCounter; // manual entry of cues

@property (readonly) NSColor *rehearseColor;
@property (readonly) NSColor *recordColor;
@property (readonly) NSColor *playbackColor;

@property NSInteger  currentWindow;

- (IBAction)onStreamerWindow:(id)sender;
- (IBAction)onMonitorWindow:(id)sender;
- (IBAction)onAdrClientWindow:(id)sender;
- (IBAction)onEditorWindow:(id)sender;
- (IBAction)onAudioPlayerWindow:(id)sender;
- (IBAction)onDocumentWindow:(id)sender;

@property OverlayWindowController *overlayWindowController;
@property StreamerWindowController *streamerWindowController;
@property MatrixWindowController *matrixWindowController;
@property AdrClientWindowController *adrClientWindowController;
@property EditorWindowController *editorWindowController;
@property AudioPlayerWindowController *audioPlayerWindowController;
@property VideoDelayWindowController *videoDelayWindowController;
@property ScreenRecorder *screenRecorder;
@property DialMidiWindowController *dialMidiWindowController;

@property id rehearseCaptureWindowController;
@property id preferencesWindowController;

// jump tables
@property NSDictionary *unitIDDictionary;
@property NSDictionary *unitIDDictionary_shifted;
@property NSDictionary *midiKeyDictionary;

//@property id objCPIUtilities;

@property NSInteger currentTrack;
@property NSInteger lastRecordTrack;
@property NSInteger trackForMixerWindow;

@property NSInteger cycleMode;
@property NSInteger cycleMotion;    // only 4 motion states...

@property NSString *lastCueID;

//@property NSMutableDictionary *recordCycleDictionary; // the dictionary for this record cycle, captured at start of cycle
@property NSString *session;

@property bool overlay;

//@property NSString *startFromPrerollTc;
@property NSString *suggestedTrackName; // result of renameLastTrack
@property NSInteger fastFwdRev;
// 2.10.02 remoteClient
@property MidiClient /* *mtcClient,*/*ptClient,*ufxClient;    // 12/14/16 2 Launch Pad Minis for Tommy
@property StatusMidi *statusClient;
@property ControlMidi *control1Client,*control2Client;
@property MtcMidi *mtcClient;

@property MidiHui *mtcHui,*ptHui;

@property NSInteger prerollIndex;   // 2.00.00

// this keeps picture hidden
//@property (nonatomic) bool hidePix; // If you are writing your own accessor methods, the property must be set to be nonatomic (meaning, there is no thread locking). https://mobiarch.wordpress.com/2013/09/09/writing-a-custom-property-getter-and-setter-in-objective-c/
//@property bool cutAndPasteIsActive;
@property NSString *tcInClip,*editStart;   // must be like aleMin

//@property bool startCycleOnMidiStopTimeout; // fast button push kludge


////////////// MIDI keyboard vars ///////////
@property NSInteger aipPairSelector;
#define MIC_ON @"true"
#define MIC_OFF @"false"
//@property NSMutableDictionary *micDictionary;
//@property NSDictionary *oscToAipDictionary;

@property NSInteger lastTrack;
@property bool snoopAuto;
@property NSInteger snoopState;
@property XKey *xKey;
@property LpMini *lpMini;
@property bool cueIdInSlate;
@property LoopMidi *loopMidi;

// access

-(void)trimBeeps:(NSInteger)trim;

-(void)initJumpTables; 
-(void)txOsc:(NSString *)str;
-(void)setLEDForUnitID:(int)unitID :(int)index :(bool)on;
//-(void)setMemoryLED;
-(void)txMsgToAdrClient:(NSString*)msg;
//-(void)setDocLEDs;
-(Document*)topDocument;
-(void)rehearseMode;
-(void)recordMode;
-(void)playbackMode;
-(void)onAhead;
-(void)onIn;
-(void)onPast;
-(bool)isAleMini;
-(void)locate:(NSString*)start;
-(void) locate:(NSString *)start :(NSString*)msg;
-(void)selectCurrentTrackMemory:(NSEvent*)event;
-(void)selectCurrentSixteenTrackMemory;
-(void)incrementRecordTrack;
-(void)incrementRecordTake;
-(NSString*)stripNonAscii:(NSString*)cmd;
-(void)sendMidiToClosure;
//-(void)setTrimLeds;
-(void)decrementRecordTake;
-(void)set16TrackLED;
-(void)selectLastSixteenTrackMemory;
//-(void)showFmtLEDs;
-(void)selectTrackMemory:(NSInteger)track;
//-(NSInteger)midiKeyboardService:(NSString*)msg;
//-(void)initAipHead;
-(void)futzOff;
-(float)maxDocWindowWidth;
-(NSScreen*)rightmostScreen;
-(NSScreen*)widestScreen;
//-(unsigned char)midiCustomFillState;
-(void)captureFillStop;
//-(void)setPrerollLEDs:(NSString*)preroll;
-(void)toggleToTc;
-(void)toggleToFt;
//-(void)showBoomRecorderServerAnnunciator:(NSInteger)online;
-(void)grabAllTimeout;
-(void)initGrabAllTimeout;
//-(void)midiKeyboardServiceAfterQueue:(NSString*)msg;
-(bool)testGrabAllTimeout;

// 3/31/16 helpers, revising MIDI
-(bool)isStop;
-(BOOL)isPlay;
-(bool)isRecord;
-(int)getTcType;
-(int)getDropoutDownCtr;
-(unsigned char)getDisplayFmt;

-(void)onMidiRecord;
-(void)onMidiStop;
-(void)onMidiShuttle;
-(void)onMidiJog;
-(void)onMidiPlay;
-(void)onMidiTransport;
//-(void)txMidi:(NSData*)data;
//-(void)txMidiToAcc:(NSData*)data;
-(void)sendUfxString:(NSString*)str;
-(void)sendUfxStringThrottled:(NSString*)str;
//-(void)aipShowOverlay:(int)row :(NSInteger*)state;

// v1.00.23
-(void)showAheadInPast;

// 2.00.00
-(void)cueToCycleStart;
-(void)cycleStart;
-(void)calcPrerollToHere:(NSString*)tc;
-(void)cycleButton;

//TcCalculatorDelegate
-(bool)ignoreTcStartHours;
-(void)xKeyPressed:(NSInteger)unitID :(NSInteger)key;
-(void)getSession:(NSEvent*)event;  // 2.10.00
-(void)getDialog:(NSEvent*)event;   // 2.10.00
-(void)renameLastTrack;

// 2.10.02
-(void)nextCue;
-(void)dialMidiRefresh;
-(void)refreshOutputGains;
-(void)showSixteenTracks:(NSEvent*)event;
//-(void)txToMidiAccessory:(NSData*)data;
//-(NSInteger)recDelayState;
-(void)locateToInpoint:(NSEvent*)event;
-(void)nextScreen;
-(void)rxOsc:(NSString *)str;
-(void)alertErr:(NSString*) msg : (NSString*) info;
- (IBAction)onVideoDelayWindow:(id)sender;
-(void)onFullScreen;

- (IBAction)onVideoDelayHotKey:(id)sender;
-(void)sendDial:(NSString*)key; // DialMidiViewControllerDelegate
-(void)triggerStreamer;
-(void)midiToOsc:(NSData*)data :(NSString*)title;
-(void)actorDirect:(NSString*)key;
-(void)dialAccessoryRefresh;
@end
