//
//  Document.h
//  TestDoc
//
//  Created by James Ketcham on 7/9/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TCFormatter.h"
#import "TcCalculator.h"
#import "DocWindow.h"
#import "TableView.h"


#define CYCLE_TYPE_STOP 0
#define CYCLE_TYPE_QUICKPUNCH 1
#define CYCLE_TYPE_LOOP_RECORD 2
#define CYCLE_TYPE_UNKNOWN 3
#define MATRIX_HEIGHT 230

enum{
    
    BEHAVIOR_INDEX_MULTIPLE_STREAMERS,
    BEHAVIOR_INDEX_SINGLE_STREAMER,
    BEHAVIOR_INDEX_FOLLOW_CUESHEET
};

enum{
    RECORD_CYCLE_DICTIONARY_IDLE,
    RECORD_CYCLE_DICTIONARY_PENDING,
    RECORD_CYCLE_DICTIONARY_ACTIVE
};

@protocol DocumentDelegate

-(int)getTcType;

@end

@class ArrayController;
@class DocLeftTableViewController;
@class DocRightTableViewController;
@class AleDelegate;

@interface Document : NSDocument<NSTableViewDelegate>{
    
    TCFormatter *tcf;
    TcCalculator *tcc;
}
@property AleDelegate *delegate;

@property (strong) IBOutlet NSComboBox *behaviorCombo;

@property (strong) IBOutlet NSTextField *timeCodeStartTextField;
@property NSString *timeCodeStart;  

@property NSInteger tableContentsDisplayFormat;

@property NSMutableArray *indexArray;   //
@property bool aleMini;
@property bool inhibitGetTrackPos;
//@property bool autoPlay;

@property (strong) NSString *sendButtonTitle;
@property (strong) IBOutlet DocWindow *docWindow;


//@property (readonly) double beepsInterval;

@property (strong) NSMutableArray *tableContents;
@property NSArray *clientTableContents;
@property (strong) NSDictionary *columnSynonymDictionary;
@property (strong) NSMutableDictionary *headerDictionary;
@property (weak) IBOutlet NSComboBox *fpsComboBox;

//@property (strong,readonly) NSString *lastStart;
//@property (strong,readonly) NSString *lastEnd;
//@property NSInteger lastTcType;

@property (weak) IBOutlet NSButton *cueIdCheckBox;
@property (weak) IBOutlet NSButton *dialogCheckBox;
@property (weak) IBOutlet NSButton *notesCheckBox;
//@property (weak) IBOutlet NSButton *streamerCheckBox;
//@property (weak) IBOutlet NSButton *beepsCheckBox;
//@property (weak) IBOutlet NSTextField *beepsTrim;
@property NSInteger beepsTrimFrames;

@property (strong) IBOutlet ArrayController *arrayController;
@property NSMutableArray<NSDictionary*> *titles;
@property NSArray<NSDictionary*> *clientTitles;

//@property bool recordCycleDictionaryActive;

//- (IBAction)onSendCueToProtools:(id)sender;
- (IBAction)onClearScreen:(id)sender;

@property (readonly) int tcType;
//@property bool loopRecord;

@property NSInteger cueCtr; // count added cues
@property bool showAllCols;

//@property NSInteger numRecTracks;  // number of record tracks

// inserting, adding rows and columns
- (IBAction)onInsertRowAbove:(id)sender;
- (IBAction)onAddRow:(id)sender;
- (IBAction)onAddColumn:(id)sender;
- (IBAction)onInsertColumnLeft:(id)sender;
- (IBAction)onRenameColumn:(id)sender;
- (IBAction)onAddCueButton:(id)sender;
@property (strong) IBOutlet TCFormatter *tcFormatterTableView;
// github
// for our save after changes
@property (strong) NSURL *readUrl;
@property (strong) NSString *readTypeName;

// streamer/punch/beeps on the control head
//@property bool streamerEnable;
//@property bool beepsEnable;
//@property bool punchEnable;
//@property bool progressBarEnable;
@property bool recordToComposite;

//@property NSString *cutAndPasteClipName;

@property NSString *dialog;
@property NSString *cueID;
@property NSString *notes;
@property NSMutableDictionary *recordCycleDictionary;  // 2.10.00
@property NSInteger recordCycleDictionaryState;

//@property NSString *session;

//@property NSMutableDictionary *lastCycleRowDictionary;
//@property NSMutableDictionary *circleRowDictionary;  // row to send names to

// access
-(void)deleteRow:(NSInteger)row;
-(void)deleteRows:(NSIndexSet *)selectedRowIndexes;
-(void)deleteCols:(NSIndexSet *)selectedColIndexes;

-(void)previousCue;
-(void)nextCue;
-(void)mergeNextCue;
-(void)unmergeCue;
//-(void)cycle;
-(NSString*)clipName;
//-(void)addCueToDoc:(NSString*)name start:start end:(NSString*)end;
-(void)trimBeeps:(NSInteger)trim;
//-(void)toggleStreamer;
//-(void)toggleBeeps;
//-(void)incrTakeCounter:(NSEvent*)event;
-(NSString*)startTc;
-(NSString*)endTc;
-(void)setEndTc:(NSString*)end;
-(void)setStartTc:(NSString*)start;
//-(void)sendCycleTypeToProtools:(NSInteger)cycleType;

//-(void)cutAndPaste:(NSArray *)msgArray;
//-(void)renameClips:(NSArray *)msgArray;
-(void)textDidEndEditing:(NSNotification *)aNotification;
-(void)makeFrontmost;
//-(void)selectionDidChange:(bool)updateEd;
-(void)writeChanges;    // our 'autosave'
//-(void)enablesFromStreamer; // punch/beeps check boxes

//-(NSString*) dialog;
-(NSString*)actor;
-(NSString*)take;

-(NSString*)clipNameWithDialog;
-(void)sortByActor;
-(void)sortByCueID;

-(void)cueWithRowIndex:(NSInteger)row;
// access

-(bool)existsRowWithStart:(NSString*)start;
-(void)locateToCurrentCue;
//-(NSString*)cueID;

// mtc and protools counter 
@property NSString *tc;
@property NSString *ctr;
@property bool dialogInClipName;
@property bool  characterInTrackName;
@property bool notesInClipName;
@property NSString *cueNote;
//@property bool tableViewSelectionDidChange; // when protools stops, go to new cue maybe
@property (weak) IBOutlet TableView *tableView;

@property NSDictionary *encodings; // string encoding dictionaries
@property NSArray *encodingKeys;
@property NSString *encodingKey;


//-(void)incrementTake;

//-(void)locateOrAddCue:(NSString*)cueID;
-(void)takeFromClipList:(NSArray*)clipList;
//-(NSMutableDictionary*)dictionary;
-(NSString*)clipNameForDictionary;  // 2.10.00
-(NSString*) dialogForDictionary;   // 2.10.00
-(NSString*) dialogForDictionary:(NSDictionary*)dict;   // for didCueToTrimFrames
-(NSString*)actorForDictionary;     // 2.10.00
-(NSString*)cueIDForDictionary;     // 2.10.00
-(NSString*)cueIDForDictionary:(NSDictionary*)dict; // for readLog
-(void)incrementTakeForDictionary;  // 2.10.00
-(NSString*)takeForDictionary:(NSDictionary*)dict;      // 2.10.00
-(NSString*)takeForDictionary;      // 2.10.00
-(NSString*) notesForDictionary;    // 2.10.00
-(NSString*)trackForDictionary;
-(NSString*)trackForDictionary:(NSDictionary*)dict;
-(NSString*)startForDictionary;     // 2.10.00
-(NSString*)startForDictionary:(NSDictionary*)dict;     // needed to index to row in tableview
-(NSString*)endForDictionary;       // 2.10.00
-(NSString*)clipNameWithDialogForDictionary;    // 2.10.00
//-(void)onCycleMotionIdle;
-(void)saveToLog;
-(void)readLog;
-(void)sendDialogToStreamerForDictionary:(NSDictionary*)dict;   // 2.10.00
-(void)sendDialogToStreamerForDictionary;   // 2.10.00
-(void)sendTakeToStreamerForDictionary:(NSDictionary*)dict;     // 2.10.00
-(void)sendTakeToStreamerForDictionary;     // 2.10.00
-(void)bindEditorWindowFields:(NSDictionary*)dict;              // 2.10.00
-(void)sizeTableViewToContents;
-(void)deleteSelectedRows;
-(NSString*)startForLogTrack:(NSInteger)track;
-(void)positionUnderMixerWindow;
-(NSString*)stripNonLatin1:(NSString*)cmd;
//-(void)autoPlaySelectFirstCue;
-(NSIndexSet*)selectedRowIndexes;
-(void)calcTableContentsForNewTcStart:(NSInteger)displayFormat;
-(void)toggleToFt;
-(void)toggleToTc;
//-(void)trimFeetByTcDelta:(NSString*)oldTimeCodeStart :(NSString*)newTimeCodeStart;
//-(void)inpointPlusOne;
//-(void)inpointMinusOne;
-(void)inpointTrimFrames:(NSInteger)trimFrames;
-(NSInteger)currentRow;
//-(void)onStop;
-(bool)cueSheetFollowsMtc;
-(void)selectRow:(NSInteger)row;
-(NSArray*)selectedContents;
-(void)addRow: (NSString*)start :(NSString*)end :(NSString*)dialog;
-(void)addRowToSelection: (NSString*)start :(NSString*)end :(NSString*)dialog;
-(void)locateOrAddCue:(NSString*)cueID :(NSString*)start;
-(void)addCueWithDialogAndStart:(NSString*) dialog :(NSString*)start;   // 2.10.02

#pragma mark -
#pragma mark ---------------- additions for start/end dropdowns -----------------------
-(void)setStartTc:(NSString*)tc ForDictionary:(NSMutableDictionary*)dictionary;
-(void)setEndTc:(NSString*)tc ForDictionary:(NSMutableDictionary*)dictionary;
@end
