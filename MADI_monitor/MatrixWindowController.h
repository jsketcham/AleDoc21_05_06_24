 //
//  MatrixWindowController.h
//  Ale_v3xx
//
//  Created by James Ketcham on 4/25/14.
//  Copyright (c) 2014 WB ADR. All rights reserved.
//

#ifndef _MATRIX_WINDOW_CONTROLLER_
#define _MATRIX_WINDOW_CONTROLLER_

#import <Cocoa/Cocoa.h>
#import "MatrixView.h"
#import "RowView.h"
#import "Matrix.h"
#import "Annunciator.h"
#import "LeftTableViewController.h"
#import "RightTableViewController.h"

#define MEMORY_DEFAULT_KEY @"memoryDefault"
#define INPUT_ARRAY_KEY @"inputArrayKey"
#define TALKBACK_ARRAY_KEY @"talkbackArrayKey"
#define OUTPUT_ARRAY_KEY @"outputArrayKey"
#define INPUT_DICT_KEY @"inputDictKey"
#define TALKBACK_DICT_KEY @"talkbackDictKey"
#define OUTPUT_DICT_KEY @"outputDictKey"

#define DIALOG_CLIP_LENGTH 120  // max chars of dialog in jxaCutAndPaste

enum{
    MODE_CONTROL_REHEARSE,
    MODE_CONTROL_RECORD,
    MODE_CONTROL_PLAYBACK,
    MODE_CONTROL_NOT_USED,   
    MODE_CONTROL_REHEARSE_PENDING,
    MODE_CONTROL_RECORD_PENDING,
    MODE_CONTROL_PLAYBACK_PENDING
};

enum{
    MODE_AHEAD = 0, // must start at 0, offsets in getColumnVector
    MODE_IN,
    MODE_PAST
};

enum{
    RECORD_STATE_IDLE,
    RECORD_STATE_PLAY_LEADING_EDGE,
    RECORD_STATE_ARMED,
    RECORD_STATE_DESELECT_TRACKS
    
};

enum{
    TAG_COLUMN,
    TAG_ROW,
    TAG_SMALL_COLUMN,
    TAG_SMALL_ROW
};

@class LeftTableViewController;
@class RightTableViewController;
@class BoomRecorderMIDI;
@class StatusImageView;

@interface MatrixWindowController : NSWindowController<MatrixDelegate,NSTableViewDelegate>

// annunciators
@property (weak) IBOutlet Annunciator *rehearseAnnunciator;
@property (weak) IBOutlet Annunciator *recordAnnunciator;
@property (weak) IBOutlet Annunciator *playbackAnnunciator;

@property (weak) IBOutlet Annunciator *inAnnunciator;
@property (weak) IBOutlet Annunciator *aheadAnnunciator;
@property (weak) IBOutlet Annunciator *pastAnnunciator;

@property (weak) IBOutlet Annunciator *protoolsAnnunciator;
@property (weak) IBOutlet Annunciator *midiAnnunciator;
//@property (weak) IBOutlet Annunciator *safetyAnnunciator;

@property (weak) IBOutlet Annunciator *midiRecordAnnunciator;
@property (weak) IBOutlet Annunciator *midiPlayAnnunciator;
@property (weak) IBOutlet Annunciator *midiStopAnnunciator;
@property (strong) IBOutlet Annunciator *mtcAnnunciator;
@property (weak) IBOutlet NSTabView *tabView;

//@property NSTimer *blackTimerOneShot;

//@property (strong) IBOutlet NSArrayController *arrayController;
@property (weak) IBOutlet NSCollectionView *collectionView;

@property (strong) NSMutableArray<Matrix *> *matrixArray; // all matrices

@property (strong) NSMutableArray<Matrix *> *displayedMatrixArray;    // not all are shown
@property (strong) NSMutableDictionary *matrixDictionary;

//@property NSInteger safetyRecorderState;
@property NSInteger adrClientState;
@property NSInteger streamerState;
@property NSInteger midiState;
@property NSInteger recordState;    // sequencer
@property NSImage *shuttleImage;
@property NSImage *jogImage;

@property NSArray *inputArray;     // 2.00.00
@property NSArray *talkbackArray;     // 2.00.00
@property NSArray *outputArray; // 2.10.02

@property (strong) IBOutlet NSImageView *judderImageView;
@property unsigned char motionZoneByte;


- (IBAction)onTest:(id)sender;

- (IBAction)onDeltaMinus:(id)sender;
- (IBAction)onDeltaPlus:(id)sender;
@property (weak) IBOutlet NSTextField *deltaTextField;

@property (weak) IBOutlet MatrixView *matrixView;
//@property (weak) IBOutlet RowView *rowView;
//@property (weak) IBOutlet RowView *columnView;

@property (weak) IBOutlet NSMatrix *presetMatrix;

- (IBAction)onPresetMatrix:(id)sender;

@property NSInteger storeState; // we need a setter/getter to set XKey LED
@property NSInteger memoryTag;
@property Byte lastZoneByte;

@property NSString *mtcString;
@property NSString *streamerStartString;
@property NSString *streamerEndString;

@property NSArray *ufxInputDictionaryArray;     // 2.00.00 changed from dictionary to array
@property NSArray *ufxOutputDictionaryArray;     // 2.00.00 changed from dictionary to array
@property NSDictionary *ufxDictionary;          // 2.10.01 multiple sample rates, dictionary of inputs/outputs by sample rate

// 2.00.00 added for patching drag/drop
@property (strong) IBOutlet LeftTableViewController *inputViewController;
@property (strong) IBOutlet RightTableViewController *ufxInputViewController;
@property (strong) IBOutlet LeftTableViewController *outputViewController;
@property (strong) IBOutlet RightTableViewController *ufxOutputViewController;
@property (weak) IBOutlet NSTableView *dimTableView;

- (IBAction)onMemoryButton:(id)sender;
//- (IBAction)onShuttle:(id)sender;
//- (IBAction)onJog:(id)sender;
//- (IBAction)onTransport:(id)sender;

//- (IBAction)onTest:(id)sender;

@property NSDictionary *cmdDictionary;
@property NSInteger numRecTracksTag;
@property NSInteger sampleRateTag;  // 0,1,2 48K, 96K, 192K

//@property NSString *preroll;

@property NSInteger trimFrames;
@property NSInteger remoteDelay;
//@property bool useAltGuideInRecord;

@property NSString *recTracks;
@property bool captureGuide;    // capture first rehearse pass

@property bool ignoreTcStartHours;
@property bool captureFirstLineInRehearse;

// V2.00.00, the only instance of these modes
@property int rehRecPb;
@property int aheadInPast;
@property (nonatomic) int delayedAheadInPast;   // V2.10.02, switchers can offset by video videoDelaySeconds
@property int dimA;
@property int dimB;
@property int dimC;
@property int dimD;
@property bool dimControlRoom;
@property bool muteAll;

@property NSInteger videoScreenSelector;
@property NSInteger videoSourceSelector;

@property BoomRecorderMIDI *boomRecorderMIDI;
@property (weak) IBOutlet StatusImageView *boomRec1Status;
@property (weak) IBOutlet StatusImageView *boomRec2Status;

- (IBAction)onClearAll:(id)sender;

-(void)decodeMotionZoneByte:(unsigned char)zoneByte;
-(bool)midiAnnunciatorState;

-(void)aheadInPastFromTc:(NSString*)tc;
-(void) storeRecall:(NSString *)key;
//-(void)toggleAip:(NSString*)dest :(NSString*)src :(NSInteger)aheadInPast;   // MIDI keyboard service
//-(NSInteger)aipStateForDest:(NSString*)dest :(NSString*)src :(NSInteger)aheadInPast;

//-(void)showBoomRecorderServerAnnunciator:(NSInteger)online;
-(void)captureGuide:(NSString*)tc;
//-(void)switcherGain:(NSData*)data;
-(void)positionUnderDocWindow;
-(bool)show16Tracks;
-(void)setShow16Tracks:(bool)show16Tracks;
// 2.00.00
-(void)refreshCrosspoints;
-(void)refreshGuide;
-(NSInteger)dBToFader:(double)db;
-(NSInteger)addDbToFader:(double)db :(NSInteger)fader;
-(NSInteger)addFaders:(NSInteger) fader0 :(NSInteger) fader1;
-(NSString*)sliderToString:(NSInteger) slider;
//-(void)aipShowOsc;
-(void)cueToTrimFrames;     // 2.00.00
-(void)didCueToTrimFrames;  // 2.00.00
//-(void)continueNumRecTracksRename;  // 2.00.00
-(void)cueToTrimFrames:(NSString*)theIndex; //2.00.00
- (IBAction)onLoadDefaults:(id)sender;  // 2.00.00
- (IBAction)recallUserDefaults:(id)sender;
-(void)makeRowColTitles;
-(void)saveUserDefaults:(id)sender;
-(NSString*)bluCatSliderToString:(NSInteger) slider;
-(void)saveMatrixArrayForMemory:(NSInteger)memory;
-(void)recallMatrixArrayForMemory:(NSInteger)memory;
-(void)fileWasDropped:(NSURL*)url;

@end
#endif
