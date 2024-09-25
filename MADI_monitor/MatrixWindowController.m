//
//  MatrixWindowController.m
//  Ale_v3xx
//
//  Created by James Ketcham on 4/25/14.
//  Copyright (c) 2014 WB ADR. All rights reserved.
//
// V2.00.00 09/30/22
// we see that the 'overall' matrix display changes when a switcher goes on/off,
// but the switch state is saved somewhere and comes back for switcher 'on'
// we want the 'overall' matrix display to be the crosspoint switches, not gains
// we want the 'detail' matrix to show gains

// UFX notes 2.00.00
// Phones 1 output is 185 106,107   setting either sets both, can't change 'STEREO' setting of phones
// Phones 2 output is 185 108,109   setting either sets both, can't change 'STEREO' setting of phones

// checking ahead/in switching, UFX tx
//aheadInPast 0->1
//Timestamp: 2024-02-02 09:40:27.782393-08:00
// UFX MIDI: 09:40:27.784 -> 09:40:27.808 ~ 50 items

//cycleButton
//Timestamp: 2024-02-02 08:33:40.386461-08:00
//CYCLE_MODE_FINALIZE_RECORD->CYCLE_MODE_IDLE
//Timestamp: 2024-02-02 08:33:43.606674-08:00


#import "MidiCommands.h"
#import "MatrixWindowController.h"
//#import "Chunk.h" // 2.00.00 no more chunks
#import "TcpClientBrowser.h"
#import "TcpClientConnection.h"
#import "AleDelegate.h"
#import "Item.h"
#import "Slider.h"
#import "MatrixView.h"
#import "Document.h"
#import "MidiClient_v2.h"
#import "AdrClientWindowController.h"
//#import "SafetyRecorderClient.h"
#import "StreamerWindowController.h"
//#import "AnnunciatorView.h"
#import "TcCalculator.h"
//#import "ChannelNodeData.h"
#import "EditorWindowController.h"
//#import "SamplerWindowController.h"
#import "EditorTextField.h"
//#import "TextWindowClient.h"
//#import "OsaScript.h"
//#import "RehearseCaptureWindowController.h"
//#import "BoomRecorderClient.h"
#import "FileDropTextField.h"
#import "ArrayController.h"
#import "ColorSupport.h"

#import "AleDoc21-Swift.h"    // must be here to avoid a circular reference

#define SERVER_KEY @"server_madi"
#define UFX_OUTPUT_KEY @"ufxOutputs_3" // v1.00.19
#define UFX_INPUT_KEY @"ufxInputs_3"  // v1.00.19
#define MIDI_PING_TIMEOUT 10.0
#define MADI_RESTART_TIMEOUT 20.0
#define SEND_FADER_TIMEOUT 0.05

// tricky bit to change to ahead monitoring after a delay (protools does not stop as fast as we switch)
#define AHEAD_MONITOR_DELAY 0.5
#define MODE_MONITOR_DELAY 1.0

#define ROW_KEY @"row"
#define COL_KEY @"col"
#define GAIN_KEY @"gain"
#define MSG_KEY @"msg"
#define FIRST_CHANNEL_KEY @"firstChannel"
#define LAST_CHANNEL_KEY  @"lastChannel"

@interface MatrixWindowController ()<AnnunciatorDelegate,NSTableViewDelegate,FileDropButtonDelegate,BoomRecorderMIDIDelegate>{
    NSInteger lastMemoryButton;
//    NSMutableArray *faderMsgArray;  // fader messages are throttled
    
    // the sliders
//    unsigned int masterFaderTarget[64];     // columns are the master gains
//    unsigned int crossPointTarget[64][64];  // individual gains
//
//    // echo from MADI box, send sliders until echo matches
//    unsigned int masterFader[64];       // columns are the master gains
//    unsigned int crossPoint[64][64];    // individual gains
    
}
//@property (strong) IBOutlet NSTableView *ufxOutputTableView;
//@property (strong) IBOutlet NSTableView *ufxInputTableView;

//@property NSString *lastStoreRecallKey;   // commented out v1.00.07

//@property (weak) IBOutlet EditorTextField *prerollTextField;
//@property bool bRecordOn;

//@property Matrix *matrix0;  // easy access to hidex, row titles
@property AleDelegate *aleDelegate;
@property (weak) IBOutlet NSBox *talkbackBox;
@property (weak) IBOutlet NSSlider *tb2Slider;
@property (weak) IBOutlet NSTextField *tb2Label;
@property NSTimer *aheadMonitorTimer;
@property NSTimer *modeMonitorTimer;
//@property NSTimer *playStopTimer;   // debounce MIDI play/stop transition
@property NSTimer *madiTcpRestartTimer;
@property (strong) IBOutlet NSComboBox *boomRecorderFrameRateCombo;
@property bool pingToggle;
//@property (strong) IBOutlet FileDropTextField *remoteDelayTextField;

//@property (strong) TcpClientBrowser *tcpClient;
@property NSTimer *timer;
@property NSTimer *autoSlateTimer;
@property NSTimer *midiTimer;
//@property TcpClientConnection *connection;
//@property NSDate *lastMidiPing; // time out MIDI pings to turn off annunciator

@property TcCalculator *tcc;
@property TCFormatter *tcf;

@property bool hideServers; // one server dropdown for all annunciators, load on annunciator click
@property NSString *serverType; // dropdown label, load on annunciator click
@property (strong) IBOutlet NSComboBox *serverComboBox;
@property id serverID;      // keep track of which annunciator has the dropdown
@property (strong) IBOutlet NSArrayController *serverArrayController;
@property TcpClientBrowser *serverClient;   // bound to combo box, set this to show choices
@property NSString *server;

@property NSArray *boomRecorderFrameRates;
@property NSTimer *sendFaderTimer;    //
@property NSTimer *refreshMatrixTimer;
//@property (strong) IBOutlet NSTextView *rxTextView;
@property NSMutableArray *ufxOutputTableContents;
@property NSMutableArray *ufxInputTableContents;
//@property NSDictionary *ufxInputDictionary;   // not mutable, from ufxInputDictionary.plist
//@property NSDictionary *ufxOutputDictionary;  // not mutable, from ufxOutputDictionary.plist

//@property bool bRefreshUfxFaders;

@property (weak) IBOutlet FileDropButton *fileDropButton;
//@property BoomRecorderMIDI *boomRecorderMIDI;
@property NSString *actorDirectMic;

@end

@implementation MatrixWindowController

NSArray *sampleRateKeys = @[@"48K",@"96K",@"192K"];

//@synthesize numRowsAndCols = _numRowsAndCols;
@synthesize storeState = _storeState;
@synthesize memoryTag = _memoryTag;
//@synthesize segmentedControlTag = _segmentedControlTag;
//@synthesize xkeyMonitorDestination = _xkeyMonitorDestination;
//@synthesize talkbackState = _talkbackState;
//@synthesize tbDim = _tbDim;
//@synthesize tb2Dim = _tb2Dim;
@synthesize shuttleImage = _shuttleImage;
@synthesize jogImage = _jogImage;
//@synthesize safetyRecorderState = _safetyRecorderState;
//@synthesize isArmedForClipName = _isArmedForClipName;
@synthesize adrClientState = _adrClientState;
//@synthesize  modeControl = _modeControl;
//@synthesize preroll = _preroll;
@synthesize trimFrames = _trimFrames;
@synthesize tcc = _tcc;
@synthesize numRecTracksTag = _numRecTracksTag;
//@synthesize show16Tracks = _show16Tracks;
@synthesize captureFirstLineInRehearse = _captureFirstLineInRehearse;
@synthesize ufxOutputTableContents = _ufxOutputTableContents;
//@synthesize bRefreshUfxFaders = _bRefreshUfxFaders;
//@synthesize blackTimerOneShot = _blackTimerOneShot;
//@synthesize numRows = _numRows;
//@synthesize numCols = _numCols;
@synthesize matrixDictionary = _matrixDictionary;
@synthesize rehRecPb = _rehRecPb;   // 2.00.00
@synthesize aheadInPast = _aheadInPast; //2.00.00
//@synthesize fooInt = _fooInt;
@synthesize recTracks = _recTracks;
@synthesize dimA = _dimA;
@synthesize dimB = _dimB;
@synthesize dimC = _dimC;
@synthesize dimD = _dimD;
@synthesize matrixArray = _matrixArray;
@synthesize displayedMatrixArray = _displayedMatrixArray;   // 2.00.00

@synthesize inputArray = _inputArray;
@synthesize outputArray = _outputArray;
@synthesize ufxInputDictionaryArray = _ufxInputDictionaryArray;
@synthesize ufxOutputDictionaryArray = _ufxOutputDictionaryArray;

@synthesize ufxDictionary = _ufxDictionary;
@synthesize sampleRateTag = _sampleRateTag;

@synthesize judderImageView = _judderImageView;
@synthesize talkbackArray = _talkbackArray; // 2.10.02

@synthesize dimControlRoom = _dimControlRoom;
@synthesize muteAll = _muteAll;
@synthesize videoScreenSelector = _videoScreenSelector;
@synthesize videoSourceSelector = _videoSourceSelector;
@synthesize delayedAheadInPast = _delayedAheadInPast;
@synthesize boomRecorderMIDI =  _boomRecorderMIDI;

@synthesize actorDirectMic = _actorDirectMic;
@synthesize motionZoneByte = _motionZoneByte;

//@synthesize muteControlRoom = _muteControlRoom;
//@synthesize muteStage = _muteStage;
//@synthesize muteActor = _muteActor;
//@synthesize muteEditor = _muteEditor;

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"",SERVER_KEY,
                                    @"24 fps",@"boomRecorderFrameRate",
                                    [NSNumber numberWithDouble:-20.0],@"dimDB",
                                    [NSNumber numberWithDouble:0.5],@"monitorDelay",
                                    nil];
        [defaults registerDefaults:dictionary];
        
        //        [self setServer:[defaults objectForKey:SERVER_KEY]];  // 2.00.00
        //        NSLog(@"madi server: %@",_server);    // 2.00.00
        
        [self setHideServers:true];
        [self setServerType:@"Protools server"];    // start with the dropdown hidden
        
        //        [self setLastRecordEdge:[NSDate dateWithTimeIntervalSinceNow:-2]];  // ready to trigger...
        
        _tcc = [[TcCalculator alloc] init];
        _tcf = [[TCFormatter alloc]init];
        
        [_midiRecordAnnunciator setLastEdge:[NSDate dateWithTimeIntervalSinceNow:-2]];
        
        NSDictionary *registrationDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSNumber numberWithInteger:-7],@"trimFrames",
                                              @"0",@"numRecTracks",
                                              [NSNumber numberWithBool:false],@"show16Tracks",
                                              @"1",@"actorDirectMic",
                                              @"1",@"lastActorDirectMic", // change detector for turning off previous output
                                              nil];
        
        [[NSUserDefaults standardUserDefaults] registerDefaults:registrationDefaults];
    }
    
//    _boomRecorderMIDI = [[BoomRecorderMIDI alloc]init];
    return self;
}
-(void)awakeFromNib{
    //    [self positionUnderDocWindow];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    [_collectionView registerClass:[Item class] forItemWithIdentifier:@"Item"];
    [self configureCollectionView]; // spacing for flow layout
    
    _matrixView.delegate = self;
    _fileDropButton.delegate = self;
    
    // 2.00.00 patching drag/drop
    _inputViewController.matrixView = _matrixView;
    _outputViewController.matrixView = _matrixView;
    
    _aleDelegate = (AleDelegate *)[NSApp delegate];
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    [_boomRecorderFrameRateCombo setStringValue:[defaults objectForKey:@"boomRecorderFrameRate"]];
    
    // UFX addition
    [self recallUserDefaults:nil];
    //    [self onLoadDefaults:nil];  // TODO: 2.00.00 recallUserDefaults here
    
    NSBundle *mainBundle = [NSBundle mainBundle];
    
    //    NSImage *greenImage = [[NSImage alloc] initWithContentsOfURL:[mainBundle URLForImageResource:@"green16.png"]];
    //    redImage = [[NSImage alloc] initWithContentsOfURL:[mainBundle URLForImageResource:@"red16.png"]];
    NSImage *clearImage = [[NSImage alloc] initWithContentsOfURL:[mainBundle URLForImageResource:@"clear16.png"]];
    
    [self setShuttleImage:clearImage];
    [self setJogImage:clearImage];
    [_judderImageView setImage:clearImage]; // a debugging indicator for streamer judder
    
    // annunciators
    [self.rehearseAnnunciator setText:@"Rehearse"];
    [self.recordAnnunciator setText:@"Record"];
    [self.playbackAnnunciator setText:@"Playback"];
    
    [_rehearseAnnunciator setOnIndex:GREEN_INDEX];
    [_recordAnnunciator setOnIndex:RED_INDEX];
    [_playbackAnnunciator setOnIndex:BLUE_INDEX];
    [_rehearseAnnunciator setState:true];
    
    // ahead/in/past
    
    [self.aheadAnnunciator setText:@"Ahead"];
    [self.inAnnunciator setText:@"In"];
    [self.pastAnnunciator setText:@"Past"];
    
    self.aheadInPast = MODE_AHEAD;

    // clients
//    [_safetyAnnunciator setText:@"Boom recorder"];
    [_protoolsAnnunciator setText:@"Protools"];
    [_midiAnnunciator setText:@"MIDI"];
//    [_safetyAnnunciator setOffIndex:RED_INDEX];
    [_protoolsAnnunciator setOffIndex:RED_INDEX];
    [_midiAnnunciator setOffIndex:RED_INDEX];
//    [_safetyAnnunciator setState:false];
    [_protoolsAnnunciator setState:false];
    [_midiAnnunciator setState:NSControlStateValueMixed];   // yellow if we forget to connect MIDI
    // MIDI motion status
    [_midiPlayAnnunciator setText:@"Play"];
    [_midiPlayAnnunciator setDelegate:self];    // for PLAY leading edge
    [_midiStopAnnunciator setText:@"Stop"];
    [_midiStopAnnunciator setDelegate:self];    // for STOP leading edge
    [_midiRecordAnnunciator setText:@"Record"];
    
    [_midiRecordAnnunciator setOnIndex:RED_INDEX];
    
    [_midiStopAnnunciator setState:true];
    
    // delegates, show a server dropdown when annunciator is clicked
    
    [_protoolsAnnunciator setDelegate:self];
//    [_safetyAnnunciator setDelegate:self];
    
    [_mtcAnnunciator setText:@"Dropouts"];
    [_mtcAnnunciator setOnIndex:GREEN_INDEX];
    [_mtcAnnunciator setOffIndex:RED_INDEX];
    [_mtcAnnunciator setMixedIndex:CONTROL_INDEX];  // in STOP show gray
    
    _boomRecorderMIDI = [[BoomRecorderMIDI alloc] init];
    _boomRecorderMIDI.delegate = self;  // status indication

    _rehRecPb = MODE_CONTROL_NOT_USED; self.rehRecPb = MODE_CONTROL_REHEARSE;    // cause a change detect
    _aheadInPast = MODE_IN; self.aheadInPast = MODE_AHEAD; // cause a change detect
    
//    [self continueNumRecTracksRename];  // after rename of last track to default (monoRecord, stereoRecord etc.)
    
    [_matrixView autoSlate:false];
    
    // 2.10.02 remote actor, editor switchers can follow actor, editor switchers
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:@"linkRemoteActor"
                                               options:NSKeyValueObservingOptionNew
                                               context:NULL];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:@"linkRemoteEditor"
                                               options:NSKeyValueObservingOptionNew
                                               context:NULL];

}
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context{
    
    if([keyPath isEqualToString:@"linkRemoteActor"] ||
       [keyPath isEqualToString:@"linkRemoteEditor"]){
        
        self.matrixArray = self.matrixArray;
    }
}

- (IBAction)onBoomRecorderFrameRate:(id)sender {
    
    NSComboBox *cb = (NSComboBox *)sender;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setObject:cb.stringValue forKey:@"boomRecorderFrameRate"];
}
//-(void)aipShowOsc{
//    
//    // 2.00.00 reduce number of messages, display ripple
//    
//    [_aleDelegate sendStatesToAip];
//    [_aleDelegate sendToMicAccessoryForKeys:nil];   // defaults to all keys
//    _aleDelegate.aipPairSelector = _aleDelegate.aipPairSelector;    // sends to osc, aip
//}
-(bool)midiAnnunciatorState{
    return _midiAnnunciator.state;
}

- (IBAction)onAnnunciatorOff:(id)sender {
    _aleDelegate.overlayWindowController.viewController.annunciatorTextView.text = @"";
    
}

#pragma mark -
#pragma mark ------------------ tcp client delegate methods -------------------------
-(void)txMsg:(NSString*)msg{
    NSLog(@"txMsg");    // shouldn't get here, find how we were called
}
#pragma mark -
#pragma mark ------------------ timer_service -------------------------
-(void)midiTimer_service{
    
    [_midiAnnunciator setState:false];  // midi ping timed out, a oneshot
}

-(void) storeRecall:(NSString *)key{
    
    @autoreleasepool {
        
        if([key isEqualToString: @"memory4"]){   // being turned off (AHEAD sabotage fix) V1.00.07
            
            return;
        }
        
        NSData *data = [_matrixView getByteMatrix]; // assumption
        
        if(_storeState){
            
            [self setStoreState:NSControlStateValueOff];
            
            [[NSUserDefaults standardUserDefaults] setObject:data forKey:key];
            
        }else{
            
            data = [[NSUserDefaults standardUserDefaults] dataForKey:key];
            Byte tempMatrix[MAX_ROWS_COLS][MAX_ROWS_COLS];
            memset(tempMatrix, FADER_0dB, sizeof(tempMatrix));
            
            if(data == nil || data.length < sizeof(tempMatrix)){
                
                data = [[NSData alloc] initWithBytes:tempMatrix length:sizeof(tempMatrix)];
            }
            
            [_matrixView setByteMatrix:data];
            
        }
        
    }
    
}

- (IBAction)onPresetMatrix:(id)sender {
    
    NSMatrix *m = (NSMatrix*)sender;
    
    int tag = (int)m.selectedTag;
    
    // monitor switching happens in setRehRecPb, setAheadInPast
    self.rehRecPb = (tag / 3) + MODE_CONTROL_REHEARSE;  // because 0 is MODE_CONTROL_OFF
    self.aheadInPast = tag % 3;
    
    //    [self memoryFromMatrix:nil];  // commented out 2.00.00
}

bool matrixWasCleared = false;

- (IBAction)onClearAll:(id)sender {
    
    matrixWasCleared = true;    // flag to setMemoryTag, onMemoryButton
    [_matrixView crossPointsOff];
    
}

- (IBAction)onMemoryButton:(id)sender{
    
    if(_storeState){
        // we get here if the tag doesn't change
        self.storeState = false;
        [self saveMatrixArrayForMemory:_memoryTag]; // saves matrix array and crosspoints
    }
    else if(matrixWasCleared){
        // we get here if the tag doesn't change
        matrixWasCleared = false;   // memory tag did not change, handled here
        [self recallMatrixArrayForMemory:_memoryTag];
        
    }
}

- (IBAction)onIncrProgress:(id)sender {
    
    [self toggleCrosspoints];
    
    // test button mashing
    //
    /*
     shift is 'false'
     'Cycle',       unitId: '9',    key: '66',
     'Play Stop',   unitId: '8',    key: '47',
     'Rehearse',    unitId: '8',    key: '43',
     'Record',      unitId: '8',    key: '44',
     'Playback',    unitId: '8',    key: '45',
     */
//    NSDictionary *buttonDictionary = @{
//        @"Cycle"        : @[@9,@66]
//        ,@"Play Stop"   : @[@8,@47]
//        ,@"Rehearse"    : @[@8,@43]
//        ,@"Record"      : @[@8,@44]
//        ,@"Playback"    : @[@8,@45]
//    };
//
//    NSArray *buttons = @[@"Cycle",@"Playback",@"Cycle",@"Play Stop",@"Record",@"Cycle"];
//
//    for (NSString *button in buttons){
//
//        NSArray *array = buttonDictionary[button];
//
//        if(array){
//            int unit = [(NSNumber*)array[0] intValue];
//            int keyNumber = [(NSNumber*)array[1] intValue];
//
//            [_aleDelegate rxOsc:[NSString stringWithFormat:@"%d,%d,false",unit,keyNumber]];
//        }
//
//
//    }
//
}
- (IBAction)onClearProgress:(id)sender {
    
    lastCrosspoint = 0; // so that toggle starts in a known state
    [_matrixView clearCrosspoints]; // resets change detector, have to do this the first time
    [self refreshCrosspoints];
    
}

#pragma mark -
#pragma -------- motion, mode, and record status ----------------
-(void)txMidiTallies{
    
    Byte trigger[] = {0x90,124,64};
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    
    //    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    
    //     Evan's tallies TODO check this
    //
    //     MIDI NOTE ON (velocity 127) when state is true, OFF (velocity 0) when it's not.
    //
    //     Pro Tools Play Tally: #64
    trigger[1] = 64;
    trigger[2] = _midiPlayAnnunciator.state ? 127 : 0;
    [delegate.ptClient midiTx:[NSData dataWithBytes:trigger length:3]];
    //     Pro Tools Record Tally: #65
    trigger[1] = 65;
    trigger[2] = _recordAnnunciator.state ? 127 : 0;
    [delegate.ptClient midiTx:[NSData dataWithBytes:trigger length:3]];
    //     Pro Tools Stop Tally: #66
    trigger[1] = 66;
    trigger[2] = _midiStopAnnunciator.state ? 127 : 0;
    [delegate.ptClient midiTx:[NSData dataWithBytes:trigger length:3]];
    
}
-(void)takeAnnouncement{
    
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    Document *doc = [delegate topDocument];
    
    // commented out v1.00.18
    //    NSString *selectedVoice = [delegate.samplerWindowController selectedVoice];
    
    // TODO do we want 2 announcers, safety recorder and sampler?
    NSString *take = [NSString stringWithFormat:@"Take %@",[doc take]];
    
    if(delegate.cueIdInSlate){
        take = [NSString stringWithFormat:@"%@ %@",[doc cueIDForDictionary],take];
    }
    
    [delegate.audioPlayerWindowController sayTake:take];    // V1.00.18
    
    //    NSString *takeMsg = [NSString stringWithFormat:@"take %@",take];
    //    if(take && take.length && ![take isEqualToString:@"0"]){
    //
    //        //            [delegate.safetyRecorderClient say:takeMsg :selectedVoice]; // default voice
    //        // commented out v1.00.18
    ////        [delegate.samplerWindowController say:takeMsg :selectedVoice];  // local announcement
    //        [delegate.samplerWindowController say:takeMsg];
    //    }
    
    take = [doc take];  // done with cue in slate
    if(take.length < 2) take = [@"0" stringByAppendingString:take];
    
    // 6/22/15 Boom Recorder
    // -(void)startBoomRecoder:(NSString*)frameRate :(NSString*)takeNumber :(NSString*)trackWidth :(NSString*)cueName :(NSString*)dialog
    //////////////////
    NSString *cueID;
    NSString *character;
    
    cueID = [doc cueIDForDictionary];
    character = [doc actorForDictionary];
    if(doc.characterInTrackName) cueID = [NSString stringWithFormat:@"%@ %@",character,cueID];   // 2.00.00 ' '
    
    // maybe add some extra text to the cue ID
    NSString *nameNote = [delegate.editorWindowController nameNote];
    NSInteger beforeAfterTag = [delegate.editorWindowController beforeAfterTag];
    
    if(nameNote && nameNote.length){
        
        switch (beforeAfterTag) {
            case NAME_BEFORE_TAG:
                nameNote = [NSString stringWithFormat:@"%@ %@",nameNote,cueID]; // 2.00.00 ' '
                break;
                
            default:
                nameNote = [NSString stringWithFormat:@"%@ %@",cueID,nameNote]; // 2.00.00 ' '
                break;
        }
        
    }else nameNote = cueID;
    
    nameNote = [nameNote stringByAppendingString:@"_"];
    nameNote = [nameNote stringByAppendingString:take];
    
    
    //////////////////
    bool boomRecorderIsOnline = [[NSUserDefaults standardUserDefaults] boolForKey:@"boomRecOnlineLocal"] | [[NSUserDefaults standardUserDefaults] boolForKey:@"boomRecOnlineRemote"];
    
    if(boomRecorderIsOnline){
        
        AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
        NSString *session = delegate.session;
        session = [session stringByReplacingOccurrencesOfString:@" " withString:@"_"];
        [_boomRecorderMIDI setBoomRecFolder:session];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *frameRate = [defaults objectForKey:@"boomRecorderFrameRate"]; // like '24 fps', same as boomRecorder dropdown
        // 8/12/15 boom recorder 8.6.2 has frame rate fixed, path fixed
        // note that we do not have 29.97 fps drop in our dropdown
        NSString *trackWidths[] = {@"1",@"2",@"3",@"4",@"6",@"8"};
        NSString *trackWidth = trackWidths[_numRecTracksTag];
        //        NSString *cueName = [doc clipNameForDictionary:delegate.recordCycleDictionary];
        NSString *dialog = [doc dialogForDictionary];
        
        [_boomRecorderMIDI startBoomRecorder:frameRate :take :trackWidth :nameNote :dialog];
    }
    
}
#pragma mark
#pragma mark ------------- playStopTimerService ---------------------
-(void)midiStopDebounceTimerService{
    
    [_aleDelegate captureFillStop]; // MIDI command to stop a recorder plugin
    //    [_aleDelegate.rehearseCaptureWindowController stopCapture]; // local sampler off
    [_boomRecorderMIDI stopBoomRecorder];
    [_aleDelegate.audioPlayerWindowController playback:false];
  
    // FIXME: Evan had some bogus ->REHEARSE switching, seems like it was here, why do we have this?
//    if (_aleDelegate.cycleMotion != CYCLE_MOTION_IDLE &&
//        _aleDelegate.matrixWindowController.rehRecPb < MODE_CONTROL_REHEARSE_PENDING){
//        _aleDelegate.matrixWindowController.rehRecPb = MODE_CONTROL_REHEARSE;
//    }// 12.10.02 12/13
    
    
//    Document *doc = _aleDelegate.topDocument;
    
    // maybe set _recordCycleDictionary, for case of play/stop
//    if(doc){
//        NSNotification *notification;
//        [doc tableViewSelectionDidChange:notification];
//    }
    
    if(_aleDelegate.cycleMotion != CYCLE_MOTION_STARTING){
        [_aleDelegate setCycleMode:CYCLE_MODE_IDLE];    // 2.00.00 RECORD sequencer
    }
    /*
     TAG_ALWAYS_ON = 0,
     TAG_FADE_IN,
     TAG_BLACK_CUE_BLACK
     
     */
    //    switch(_aleDelegate.streamerWindowController.pictureTag){
    //        case TAG_ALWAYS_ON: break;
    //        default:
    //            [_aleDelegate.overlayWindowController.viewController.streamer fadeToBlack :true :_aleDelegate.streamerWindowController.fadeSeconds];
    //            break;
    //    }
}
NSTimer *annunciatorOffTimer;
-(void)annunciatorOffTimerService{
    
    _aleDelegate.overlayWindowController.viewController.annunciatorTextView.fadeDuration = 1.0;
    _aleDelegate.overlayWindowController.viewController.annunciatorTextView.opacity = 0.0;

}

-(void)midiPlayDebounceTimerService{
    
    switch(_aleDelegate.streamerWindowController.pictureTag){
        case TAG_BLACK_CUE_BLACK: break;    // switches at cue start
        default:
            [_aleDelegate.overlayWindowController.viewController.streamer fadeToBlack :false :_aleDelegate.streamerWindowController.fadeSeconds];
            break;
    }
    
    switch (_aleDelegate.cycleMotion) {
            
        case CYCLE_MOTION_STARTING:
            
            _aleDelegate.cycleMotion = CYCLE_MOTION_ACTIVE;
            
            // 2.10.02 fire the annunciator OFF timer
            annunciatorOffTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target: self selector:@selector(annunciatorOffTimerService) userInfo:nil repeats: NO];
            
            if(_aleDelegate.cycleMode == CYCLE_MODE_RECORD){
                
                [self takeAnnouncement];    // take announcement, start boom recorder
                _aleDelegate.cycleMode = CYCLE_MODE_RECORD;
                // V1.00.21 read the remote delay every record cycle start
//                [self.remoteDelayTextField readRemoteDelayFile];
                
            }
            
            switch ([self rehRecPb]) {
                    
                case MODE_CONTROL_PLAYBACK:
                    
                    [_aleDelegate.audioPlayerWindowController playback:true];
                    
                    break;
                    
                default:
                                        
                    break;
            }
            
            break;
            
        case CYCLE_MOTION_IDLE: return;
            
        default:
            NSLog(@"unexpected cycleMotion state on MIDI play: %ld",_aleDelegate.cycleMotion);
            break;
            
    }
    
}
-(void)decodeMotionZoneByte:(unsigned char)zoneByte{
    
    // filter play/stop bouncing
    // ADR 1 we are on IAC driver and get here when going in to PLAY
    /*
     2022-11-07 12:15:02.407297-0800 AleDoc[10156:84786] decodeMotionZoneByte 8
     2022-11-07 12:15:02.407443-0800 AleDoc[10156:84786] decodeMotionZoneByte 0
     2022-11-07 12:15:02.408281-0800 AleDoc[10156:84786] decodeMotionZoneByte 10
     2022-11-07 12:15:02.409307-0800 AleDoc[10156:84786] decodeMotionZoneByte 18
     2022-11-07 12:15:02.410440-0800 AleDoc[10156:84786] decodeMotionZoneByte 18
     2022-11-07 12:15:02.457583-0800 AleDoc[10156:84786] decodeMotionZoneByte 18
     2022-11-07 12:15:02.497507-0800 AleDoc[10156:84786] decodeMotionZoneByte 18
     2022-11-07 12:15:02.677582-0800 AleDoc[10156:84786] decodeMotionZoneByte 8
     2022-11-07 12:15:02.677635-0800 AleDoc[10156:84786] decodeMotionZoneByte 0
     2022-11-07 12:15:02.677990-0800 AleDoc[10156:84786] decodeMotionZoneByte 10
     2022-11-07 12:15:02.678121-0800 AleDoc[10156:84786] decodeMotionZoneByte 10
     forceBlack 0
     2022-11-07 12:15:06.167556-0800 AleDoc[10156:84786] decodeMotionZoneByte 0
     2022-11-07 12:15:06.168572-0800 AleDoc[10156:84786] decodeMotionZoneByte 8
     2022-11-07 12:15:06.169119-0800 AleDoc[10156:84786] decodeMotionZoneByte 8
     2022-11-07 12:15:06.447241-0800 AleDoc[10156:84786] decodeMotionZoneByte 8
     2022-11-07 12:15:06.447519-0800 AleDoc[10156:84786] decodeMotionZoneByte 0
     2022-11-07 12:15:06.447963-0800 AleDoc[10156:84786] decodeMotionZoneByte 8
     2022-11-07 12:15:06.448183-0800 AleDoc[10156:84786] decodeMotionZoneByte 8
     
     ...add a oneshot that retriggers, when it times out evaluate motion
     */
    
    self.motionZoneByte = zoneByte; // wait for flopping to stop
    
     [_midiStopAnnunciator setState: (_motionZoneByte & 0x18) == 0x8];   // stop only
    [_midiPlayAnnunciator setState: (_motionZoneByte & 0x18) == 0x10];  // play only
    [_midiRecordAnnunciator setState: (_motionZoneByte & 0x20) == 0x20];    // show indicators immediately
    
    // 2.10.02 set companion variable 'playStop'
    [_aleDelegate txOsc:[NSString stringWithFormat:@"playStop %@",(_motionZoneByte & 0x18) == 0x10 ? @"1" : @"0"]];
        
//    if(_aleDelegate.snoopAuto){
//        _aleDelegate.snoopState = (_motionZoneByte & 0x30) == 0x30 ? SNOOP_STATE_OFF : SNOOP_STATE_ON;
//    }
}

-(void)recallUserDefaults:(id)sender{
    // v2.10.02
    // all tables and arrays are derived from 'inputs.plist' and 'outputs.plist'
    // in particular, _matrixView.rowTitles and _matrixView.colTitles are derived, and are not saved to defaults
    NSError *error;
    
    @try {
        
        NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:INPUT_ARRAY_KEY];
        NSKeyedUnarchiver *unarch = [[NSKeyedUnarchiver alloc]initForReadingFromData:data error:&error];
        NSSet *set = [NSSet setWithObjects:[NSDictionary class],[NSString class],[NSNumber class],[NSArray class], nil];
        
        [self willChangeValueForKey:@"inputArray"];
        _inputArray = [unarch decodeObjectOfClasses:set forKey:INPUT_ARRAY_KEY];    // no save
        if(!_inputArray){
            
            _inputArray = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"inputs" ofType: @"plist"]];
        }
        [self didChangeValueForKey:@"inputArray"];
        
        
        data = [[NSUserDefaults standardUserDefaults] objectForKey:OUTPUT_ARRAY_KEY];
        unarch = [[NSKeyedUnarchiver alloc]initForReadingFromData:data error:&error];
        
        [self willChangeValueForKey:@"outputArray"];
        _outputArray = [unarch decodeObjectOfClasses:set forKey:OUTPUT_ARRAY_KEY];  // no save
        if(!_outputArray){
            _outputArray = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"outputs" ofType: @"plist"]];
        }
        // change 'ISDN' to 'Source Connect'
        for (int i = 0; i < _outputArray.count; i++){
             
            NSString *name = [_outputArray[i] objectForKey:@"Name"];
            if([name isEqualToString:@"ISDN"]){
                [_outputArray[i] setObject:@"Source Connect" forKey:@"Name"];
                break;
            }
        }

        [self didChangeValueForKey:@"outputArray"];
        
        data = [[NSUserDefaults standardUserDefaults] objectForKey:TALKBACK_ARRAY_KEY];
        unarch = [[NSKeyedUnarchiver alloc]initForReadingFromData:data error:&error];
        
        [self willChangeValueForKey:@"talkbackArray"];
        _talkbackArray = [unarch decodeObjectOfClasses:set forKey:TALKBACK_ARRAY_KEY];
        if(!_talkbackArray){
            _talkbackArray = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"outputs" ofType: @"plist"]];
        }
        [self didChangeValueForKey:@"talkbackArray"];
    }
    @catch (NSException *exception) {
        
        // FIXME: can't have a circular arrangement
        //        _matrixArray = nil; // we failed, init from .plists
        //        [self onLoadDefaults:nil];
        
    }
    
    [self recallMatrixArrayForMemory:0];    // last used
    [self makeRowColTitles];    // makes crosspoints
    
    // TODO: is this the place for this?
//    self.dimA = false;
//    self.dimB = false;  // set the talkback faders
    
}
- (IBAction)onLoadDefaults:(id)sender{
    
    // v2.10.02
    // all tables and arrays are derived from 'inputs.plist' and 'outputs.plist'
    // in particular, _matrixView.rowTitles and _matrixView.colTitles are derived, and are not saved to defaults
    
    [self setInputArray:[NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"inputs" ofType: @"plist"]]];
    [self setOutputArray:[NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"outputs" ofType: @"plist"]]];
    [self setTalkbackArray:[NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"outputs" ofType: @"plist"]]];
    
    [self initMatrixArray: _inputArray.count];
    
    // set memory 0 to have a decodable matrixArray that includes any plist changes
    _memoryTag = 0; [self saveMatrixArrayForMemory:0]; // saves matrix array and crosspoints
    
    [self recallUserDefaults: nil];
    
}

-(int)aIPFromTc:(NSString*)tc :(NSString*)start :(NSString*)end :(int)tcType :(int)trim {  // helper function
    int aheadInPast = MODE_AHEAD;
    
    int startFrames = [_tcc tcToBinary:start withType:tcType] + trim;
    start = [_tcc binaryToTc:startFrames withType:tcType];
    
    // some open out cases
    bool isOpenOut = (!end ||
                      [end isEqualToString:@""] ||
                      [end isEqualToString:@"00:00:00:00"] ||
                      [_tcc compareTc:start fromTc:end withType:tcType] >= 0);
    
    if(!isOpenOut && [_tcc compareTc:tc fromTc:end withType:tcType] >= 0){
        aheadInPast = MODE_PAST; // we are past
    }else if([_tcc compareTc:tc fromTc:start withType:tcType] >= 0){
        aheadInPast = MODE_IN; // we are in
    }
    return aheadInPast;
}
int lastAheadInPast;    // change detector
-(void)aheadInPastFromTc:(NSString*)tc{
    
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    Document *doc = [delegate topDocument];
    
    if(!doc || delegate.cycleMotion == CYCLE_MOTION_IDLE){
        
        self.aheadInPast = MODE_AHEAD;  // AHEAD if not in cycle
        return;
        
    }
    
    // ahead/in/past
    
    int aheadInPast = MODE_AHEAD; // assume ahead
    NSString *start,*end;
    
    start = [_tcf tcForString: [doc startForDictionary]];
    if(!start) return;
    end = [_tcf tcForString:[doc endForDictionary]];
    if(!end) end = @"";   // open out if no out
    
    aheadInPast = [self aIPFromTc:tc :start :end :(int)doc.tcType :(int)self.trimFrames];
    
    if(aheadInPast != MODE_AHEAD && delegate.cycleMode == CYCLE_MODE_RECORD){
        // 6/11/17 Evan says there is a way for long takes to be lost
        delegate.cycleMode = CYCLE_MODE_RECORD_KEEP_TAKE;
    }
    // tickle github
    self.aheadInPast = (int)aheadInPast;    // does monitor switching
    
    // black/cue/black, change detector to keep calls down
    if(aheadInPast != lastAheadInPast){
        
        // black/cue/black is before 'enable in/past switching' logic
        if(_aleDelegate.cycleMotion == CYCLE_MOTION_ACTIVE && _aleDelegate.streamerWindowController.pictureTag == TAG_BLACK_CUE_BLACK){
            
           if(aheadInPast == MODE_IN){
               
                [_aleDelegate.overlayWindowController.viewController.streamer fadeToBlack:false :0.0];
               
           }else if (aheadInPast == MODE_PAST){
               
               [_aleDelegate.overlayWindowController.viewController.streamer fadeToBlack:true :0.0];
           }
            
        }
    }
    
    lastAheadInPast = aheadInPast;  // change detector
    
}
// code prior to v1.00.21
//-(void)aheadInPastFromTc:(NSString*)tc{
//
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//    Document *doc = [delegate topDocument]; if(!doc) return;
//
//    // ahead/in/past
//
//    NSInteger aheadInPast = MODE_AHEAD; // assume ahead
//    NSString *start,*end;
//
//    if(delegate.cycleMotion != CYCLE_MOTION_IDLE){  // ahead if idle
//
////        start = [_tcf tcForString:[delegate.recordCycleDictionary objectForKey:@"Start"]];
//        start = [_tcf tcForString: [doc startForDictionary:delegate.recordCycleDictionary]];
//        if(!start) return;
//
//        // advance the in by the trim amount
//        int startFrames = [_tcc tcToBinary:start withType:(int)doc.tcType];
//        startFrames -= abs((int)[self trimFrames]);
//        start = [_tcc binaryToTc:startFrames withType:(int)doc.tcType];
//
//
//        if([_tcc compareTc:tc fromTc:start withType:(int)doc.tcType] >= 0){
//
//            aheadInPast = MODE_IN; // we are at least in
//
//            // 6/11/17 Evan says there is a way for long takes to be lost. We added CYCLE_MODE_RECORD_KEEP_TAKE
//            // so that can't happen.
//            if(delegate.cycleMode == CYCLE_MODE_RECORD){
//                NSLog(@"CYCLE_MODE_RECORD_KEEP_TAKE");
//                [delegate setCycleMode:CYCLE_MODE_RECORD_KEEP_TAKE];    // is a keeper, do not erase
//            }
//        }
//
//        // TODO v1.00.21 set delayedAheadInPast
//
//
////        end = [_tcf tcForString:[delegate.recordCycleDictionary objectForKey:@"End"]];
//        end = [_tcf tcForString:[doc endForDictionary:delegate.recordCycleDictionary]];
//
//        if(end && [_tcc isTc:end] && ![end isEqualToString:@"00:00:00:00"]){
//
//            if([_tcc compareTc:tc fromTc:end withType:(int)doc.tcType] >= 0){
//                aheadInPast = MODE_PAST; // we are past
//            }
//        }
//    }
//
//    _delayedAheadInPast = aheadInPast;    // TODO v1.00.21 additional delay for actor, for now it follows
//
////    NSLog(@"aheadInPast %ld %@ %@ %@",aheadInPast,tc,start,end);
//
//    [self aheadInPastByte:aheadInPast];  // set ahead/in/past state
//
//}
#pragma mark
#pragma mark ------------- v1.00.06 ---------------------
//-(void)showTextServerAnnunciator:(NSInteger)online{
//
//    [_textAnnunciator setState:online];
//
//}
//-(void)showBoomRecorderServerAnnunciator:(NSInteger)online{
//
//    [_safetyAnnunciator setState:online];
//
//}
-(void)captureGuide:(NSString*)tc{
    
//    if(!_captureGuide){
//        return; // 2.10.02, capture first line always when in point changes
//    }
    // also called 'parrot'
    /*
     Evan, 10/16/23
     Capturing the parrot in record mode seems to cause pro tools errors sometimes. I think we need to nix that. So, capture parrot only in rehearse not rehearse or record.
     */
    if(!_captureGuide || self.rehRecPb != MODE_CONTROL_REHEARSE){
        return;
    }
    
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    Document *doc = [delegate topDocument]; if(!doc) return;
    
    NSString *start = [_tcf tcForString:[doc startForDictionary]];
    int frs = [_tcc tcToBinary:start withType:(int)doc.tcType] + (int)self.trimFrames;  // trimFrames is a small negative number
    start = [_tcc binaryToTc:(int)frs withType:(int)doc.tcType];
    
    if([start isEqualToString:tc]){
        
        //        NSLog(@"captured first line in rehearse");
//
        _captureGuide = false;  // once only
        unsigned char msg[] = {0xb0,CC_CAPTURE_SAMPLE,127};    // plugin sampler on
        [delegate.lpMini.accMidi.midiClient midiTx:[NSData dataWithBytes:msg length:3]];
//        [delegate.accClient midiTx:[NSData dataWithBytes:msg length:3]];
        
        // 6/23/15 local capture recorder
        //        RehearseCaptureWindowController *rcwc = (RehearseCaptureWindowController *)delegate.rehearseCaptureWindowController;
        //
        //        [rcwc startCapture];
    }
    
    
}


//-(void)toggleToTc{
//    
//    [[_prerollTextField window]endEditingFor:nil];
//    
//    NSString *t = _prerollTextField.stringValue;    // with : and +
//    
//    if(t && t.length/* && [_tcc isFtFr:t]*/){
//        
//        t = [_tcf formatAsFeet:t];
//        
//        int frames = [_tcc ftToBinary:t];
//        t = [_tcc binaryToTc:frames withType:TCTYPE_24];// FIXME
//        [self setPreroll:t];
//        
//    }
//    
//    [_prerollTextField setNeedsDisplay];
//    
//}
//-(void)toggleToFt{
//    
//    [[_prerollTextField window]endEditingFor:nil];
//    
//    NSString *t = _prerollTextField.stringValue;    // with : and +
//    
//    if(t && t.length/* && [_tcc isTc:t]*/){
//        t = [_tcf formatAsTc:t];
//        
//        int frames = [_tcc tcToBinary:t withType:TCTYPE_24];    // FIXME
//        t = [_tcc binaryToFt:frames];
//        [self setPreroll:t];
//    }
//    
//    [_prerollTextField setNeedsDisplay];
//}

#pragma mark
#pragma mark ------------- v2.10.02 ---------------------
-(void)saveMatrixArrayForMemory:(NSInteger)memory{
    
    // save matrix switches for reh/rec/pb
    
    NSString *key = [ NSString stringWithFormat: @"matrixArray_%ld",memory];
    
    NSKeyedArchiver *arch = [[NSKeyedArchiver alloc]initRequiringSecureCoding:false];
    [arch encodeObject:_matrixArray forKey:key];
    [arch finishEncoding];
    
    [[NSUserDefaults standardUserDefaults] setObject:arch.encodedData forKey:key];
    
    // save crosspoints
    
    key = [ NSString stringWithFormat: @"crosspoints_%ld",memory];
    
    arch = [[NSKeyedArchiver alloc]initRequiringSecureCoding:false];
    [arch encodeObject:[self.matrixView getByteMatrix] forKey:key]; // NSData
    [arch finishEncoding];
    
    [[NSUserDefaults standardUserDefaults] setObject:arch.encodedData forKey:key];

    
}
-(void)recallMatrixArrayForMemory:(NSInteger)memory{
    
    NSError *error;

    NSString *key = [ NSString stringWithFormat: @"matrixArray_%ld",memory];
    
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    NSKeyedUnarchiver *unarch = [[NSKeyedUnarchiver alloc]initForReadingFromData:data error:&error];
    NSSet *set = [NSSet setWithObjects:[NSMutableArray class],[Matrix class],[NSDictionary class],[NSString class], nil];
    
    if(error == noErr){
        self.matrixArray = [unarch decodeObjectOfClasses:set forKey:key];
    }
    
    key = [ NSString stringWithFormat: @"crosspoints_%ld",memory];
    data = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    unarch = [[NSKeyedUnarchiver alloc]initForReadingFromData:data error:&error];
    set = [NSSet setWithObjects:[NSData class], nil];
    
    if(error == noErr){
        [self.matrixView setByteMatrix:[unarch decodeObjectOfClasses:set forKey:key]];
    }
}

-(void)initMatrixArray:(NSInteger)numInputs{
    
    NSMutableArray *matrixArray = [[NSMutableArray alloc] init];   // 2.00.00

    // column names are the matrix names
    for (int i = 0; i < _outputArray.count; i++){
        
        Matrix *matrix = [[Matrix alloc] init:numInputs];
        matrix.delegate = self;
        
        matrix.buttons = [_outputArray[i] integerForKey:@"Buttons"];
        matrix.boxTitle = [_outputArray[i] objectForKey:@"Name"];
        [matrix setAllFadersToDefaultSliderValue];
        
        [matrixArray addObject:matrix];
    }
    
    self.matrixArray = matrixArray;

}
-(void)muteCrosspoints{
    [self setPatchedCrosspoints:0];
    lastCrosspoint = 0; // so that toggle starts in a known state
}
int lastCrosspoint = 0;
-(void)toggleCrosspoints{
    
    // 192K time to set all crosspoints 0.07603
    // 48K time to set all crosspoints 0.09241
    // we see uncleard 192K->48K crosspoints
    
    lastCrosspoint = lastCrosspoint ? 0 : 1;
    [self setPatchedCrosspoints:lastCrosspoint ? 1 : 0];
}
-(void)setAllCrosspoints:(int)gain{
    // mute the crosspoints for the new matrix MIDI assigments

    for(NSDictionary *colDict in self.ufxOutputDictionaryArray){
        
        NSString *selectChannel = colDict[@"SelectChannel"];
        NSString *selectControlChange = colDict[@"SelectControlChange"];
        
        for(NSDictionary *rowDict in self.ufxInputDictionaryArray){
            
            NSString *channel = rowDict[@"Channel"];
            NSString *controlChange = rowDict[@"ControlChange"];
            
            NSString *str = [NSString stringWithFormat:@"%@ %@ 0 %@ %@ %d",selectChannel,selectControlChange,channel,controlChange,gain];
                        
            [_aleDelegate sendUfxStringThrottled:str];
//            NSLog(@"%@",str);
        }
    }
}
-(void)setPatchedCrosspoints:(int)gain{
    
    // set all patched crosspoints to gain
    // setPatchedCrosspoints 0.04369
    // setPatchedCrosspoints 0.02237
    
//    NSDate *now = [[NSDate alloc]init];
    
    for(NSDictionary *colDict in _matrixView.colTitles){
        
        NSString *selectChannel = colDict[@"SelectChannel"];
        NSString *selectControlChange = colDict[@"SelectControlChange"];
        
        for(NSDictionary *rowDict in _matrixView.rowTitles){
            
            NSString *channel = rowDict[@"Channel"];
            NSString *controlChange = rowDict[@"ControlChange"];
            
            NSString *str = [NSString stringWithFormat:@"%@ %@ 0 %@ %@ %d",selectChannel,selectControlChange,channel,controlChange,gain];
                        
            [_aleDelegate sendUfxString:str];
//            NSLog(@"%@",str);
        }
    }
//    NSTimeInterval ti = [[[NSDate alloc]init] timeIntervalSinceDate:now];
//    NSLog(@"setPatchedCrosspoints %2.5f",ti);

}

-(void)makeRowColTitles{
    
    _ufxDictionary = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ufxDictionary" ofType: @"plist"]]; // 2.10.01
    
    // ufx MIDI
    NSString *sampleRateKey = sampleRateKeys[self.sampleRateTag];

    self.ufxInputDictionaryArray = self.ufxDictionary[sampleRateKey][@"input"];     // sets ufx MIDI
    self.ufxOutputDictionaryArray = self.ufxDictionary[sampleRateKey][@"output"];   // sets ufx MIDI
    
    // make row and column titles
    NSMutableArray *rowTitles = [[NSMutableArray alloc] init];
    NSMutableArray *colTitles = [[NSMutableArray alloc] init];

    // column names
    for (int i = 0; i < self.outputArray.count; i++){
        
        NSDictionary *dict = (NSDictionary*)self.outputArray[i];
        NSArray *children = [dict objectForKey:CHILDREN_KEY];
        
        NSString *smallName = [dict objectForKey:@"Name"];
        
        //
        for(int j = 0; j < children.count; j++){
            
            NSString *ufxItem = [children[j] objectForKey:@"ufxDictionaryItem"];
            
            // clip to 0..count-1
            NSInteger ufxIndex = ufxItem.integerValue;
            ufxIndex = ufxIndex >= _ufxOutputDictionaryArray.count ? _ufxOutputDictionaryArray.count - 1 : ufxIndex;
            ufxIndex = ufxIndex < 0 ? 0 : ufxIndex;
            
            NSDictionary *ufxDict = _ufxOutputDictionaryArray[ufxIndex];
            NSString *lcr = [children[j] objectForKey:@"Name"];
            NSString *name = [NSString stringWithFormat:@"%@ %@",smallName,lcr];
            
            // the one and only place that colTitles is made
            // Dim A, Dim B being 1 means the col can be dimmed

            NSDictionary *colDict = @{
                @"Title":name
                ,@"UfxTitle" : [ufxDict objectForKey:@"Title"]
                ,@"SelectChannel" : [ufxDict objectForKey:@"SelectChannel"]
                ,@"SelectControlChange" : [ufxDict objectForKey:@"SelectControlChange"]
                // for group fader gain, not used currently
                ,@"Channel" : [ufxDict objectForKey:@"Channel"]
                // for group fader gain, not used currently
                ,@"ControlChange" : [ufxDict objectForKey:@"ControlChange"]
                ,@"Feedback" : [dict objectForKey:@"Feedback"]
            };
            
            [colTitles addObject:colDict];
        }
    }
    
    // row names
    for (int i = 0; i < self.inputArray.count; i++){
        
        NSDictionary *dict = (NSDictionary*)self.inputArray[i];
        NSArray *children = [dict objectForKey:CHILDREN_KEY];
        
        NSString *smallName = [dict objectForKey:@"Name"];
        
        for(int j = 0; j < children.count; j++){
            
            NSString *ufxItem = [children[j] objectForKey:@"ufxDictionaryItem"];
            
            // clip to 0..count-1
            NSInteger ufxIndex = ufxItem.integerValue;
            ufxIndex = ufxIndex >= _ufxInputDictionaryArray.count ? _ufxOutputDictionaryArray.count - 1 : ufxIndex;
            ufxIndex = ufxIndex < 0 ? 0 : ufxIndex;

            NSDictionary *ufxDict = _ufxInputDictionaryArray[ufxIndex];
            NSString *lcr = [children[j] objectForKey:@"Name"];
            NSString *name = [NSString stringWithFormat:@"%@ %@",smallName,lcr];
            
//            NSLog(@"%@",ufxDict);
            
            // the one and only place that rowTitles is made or changed

            NSDictionary *rowDict = @{@"Title":name
                                      ,@"UfxTitle" : [ufxDict objectForKey:@"Title"]
                                      ,@"Channel" : [ufxDict objectForKey:@"Channel"]
                                      ,@"ControlChange" : [ufxDict objectForKey:@"ControlChange"]
                                      ,@"Feedback" : [dict objectForKey:@"Feedback"]
                                           ,@"InputArray" : [NSString stringWithFormat:@"%d",i] // for feedback toggle
                                    };
            
//            NSLog(@"%@",rowDict);

            [rowTitles addObject:rowDict];
        }
    }
    _matrixView.colTitles = colTitles;  // titles and MIDI dictionary
    _matrixView.rowTitles = rowTitles;  // titles and MIDI dictionary
    
//    NSLog(@"sample rate %@ rowTitles\n%@\ncolTitles\n%@",sampleRateKey,rowTitles,colTitles);
        
    // each fader in each matrix has its own crosspoint array
    // matrix.fader0 does the 'follow delayed video' logic, with two crosspoint arrays
    
    // we need matrix with titles
    if(_matrixArray == nil){
        [self initMatrixArray:_inputArray.count];
    }

    for (int i = 0; i < _outputArray.count; i++){
        
        Matrix *matrix = _matrixArray[i];
        [matrix.crosspointArrays removeAllObjects];

        NSArray *outChildren = [_outputArray[i] objectForKey:CHILDREN_KEY];

        for(int j = 0; j < _inputArray.count; j++){
            
//            NSLog(@"%@",[_inputArray[j] objectForKey:NAME_KEY]);

            NSArray *inChildren = [_inputArray[j] objectForKey:CHILDREN_KEY];
            
            // LCR->LR
            // 2.10.02 -3dB only if C is assigned to L and R
            // Evan wants to have mono assigns (LCR -> R only, for instance) not have C -3dB
            bool isLCRToLR = inChildren.count == 3 && outChildren.count == 2;
            
            NSMutableArray *crosspointArray = [[NSMutableArray alloc]init];
            
            for(int k = 0; k < outChildren.count; k++){

                for(int l = 0; l < inChildren.count; l++){
                    
                    // x indexes _matrixView.colTitles for column MIDI
                    // y indexes _matrixView.rowTitles for row MIDI
                    
                    // for LCR->LR, trim C by -3 (ignore LR->LCR cases, not used)
                    bool isCenter = [[inChildren[l] objectForKey:@"Name"] isEqualToString:@"C"] && ([[outChildren[k] objectForKey:@"Name"] isEqualToString:@"L"] | [[outChildren[k] objectForKey:@"Name"] isEqualToString:@"R"]);
                    
                    NSString *trim = isLCRToLR && isCenter ? @"-3" : @"0";

                    NSDictionary *crosspoint = @{@"x":[outChildren[k] objectForKey:@"Channel"]
                                                ,@"y":[inChildren[l] objectForKey:@"Channel"]
                                                ,@"trim":trim
                    };
                    
                    [crosspointArray addObject:crosspoint];

                }
            }
            [matrix.crosspointArrays addObject:crosspointArray];    // crosspoints for fader[j]
        }
    }
    [_matrixView clearCrosspoints]; // resets change detector, have to do this the first time
    [self refreshCrosspoints];  // crosspoint gains may have changed
    [self setAdatCrosspoints];  // 2.10.02 Evan wants fixed routing programmed after change to 48K
    
    
}
-(void)setAdatCrosspoints{
    
    if(self.sampleRateTag == 0){
        // 2.10.02 Evan wants ADAT5-16 IN/OUT cleared, programmed on the diagonal, if 48K
        // CC 177,104 to CC 177,115 are inputs HW19-30
        // CC 181,104 to CC 181,115 are inputs SW19-30 (Evan wants these only)
        // CC 189,106 to CC 189,117 are outputs 19-30
        
        for(int i = 104; i <= 115; i++){
            for(int j = 106; j <= 117; j++){
                
                NSString *str = [NSString stringWithFormat:@"189 %d 0 181 %d 0",j,i];
                [_aleDelegate sendUfxString:str];
            }
            NSString *str = [NSString stringWithFormat:@"189 %d 0 181 %d 104",i+2,i]; // the diagonal
            [_aleDelegate sendUfxString:str];
       }
    }
}
- (IBAction)exportPatchingAsTextFile:(id)sender {
    
//    NSDictionary *ioDict = @{ @"rowTitles" : _matrixView.rowTitles,
//                              @"colTitles" : _matrixView.colTitles
//                         };
    NSDictionary *ioDict = @{ @"inputArray" : self.inputArray,
                              @"outputArray" : self.outputArray,
                              @"talkbackArray" : self.talkbackArray
                         };

//https://stackoverflow.com/questions/18437168/nssavepanel-file-path

    // Set the default name for the file and show the panel.
    NSSavePanel*    panel = [NSSavePanel savePanel];
    
    [panel setNameFieldStringValue:@"aleDocPatchFile.plist"];
    [panel setAllowsOtherFileTypes:YES];
    [panel setExtensionHidden:YES];
    [panel setCanCreateDirectories:YES];

    NSInteger result = [panel runModal];
    
    if (result == NSModalResponseOK) {
        
        result = [ioDict writeToURL:[panel URL] atomically:true];
        
        NSLog(@"result %ld",result);
    }
    
}

// MARK: ----- FileDropButtonDelegate and helpers ------

-(NSDictionary*)makeChannelToUfxDictionary:(NSArray*)array{
    
    // make a channel to ufx dictionary
    // input is the new patch configuration

    NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
    
    for(NSDictionary *item in array){

        for(NSDictionary *child in [item objectForKey:CHILDREN_KEY]){
            
            dict[child[@"Channel"]] = child[@"ufxDictionaryItem"];
        }
    }
    
    return [NSDictionary dictionaryWithDictionary:dict];
}
-(NSArray*)patchForDictionary: (NSDictionary*)dict to:(NSArray*)current{
    
    // change one or more connections, up to number of dict keys
    
    NSMutableArray *mutableArray = [NSMutableArray arrayWithArray:current]; // copy to modify
    
    for(NSDictionary *item in [mutableArray copy]){
        
        NSMutableDictionary *mutableItem = [NSMutableDictionary dictionaryWithDictionary:item];
        NSMutableArray *mutableChildren = [NSMutableArray arrayWithArray:[item objectForKey:CHILDREN_KEY]];
        
        for(NSDictionary *child in [mutableChildren copy]){
            
            if(dict[child[@"Channel"]]){
                
                NSMutableDictionary *mutableChild = [NSMutableDictionary dictionaryWithDictionary:child];
                mutableChild[@"ufxDictionaryItem"] = dict[child[@"Channel"]];
                [mutableChildren replaceObjectAtIndex:[mutableChildren indexOfObject:child] withObject:[NSDictionary dictionaryWithDictionary:mutableChild]];
                
            }
        }
        mutableItem[CHILDREN_KEY] = [NSArray arrayWithArray:mutableChildren];
        
        [mutableArray replaceObjectAtIndex:[mutableArray indexOfObject:item] withObject:[NSDictionary dictionaryWithDictionary:mutableItem]];
    }
   
    return [NSArray arrayWithArray:mutableArray];

}
-(NSArray*)patch:(NSArray*)patch to:(NSArray*)current{
    
    // only the ufxDictionaryItem is changed
    // so no conflict between newer and older plists, newer plist structure is kept
    
    NSDictionary *dict = [self makeChannelToUfxDictionary:patch];   // all channels
    
    return [self patchForDictionary:dict to:current]; // set for all channels
}
-(void)fileWasDropped:(NSURL*)url{
    
    NSDictionary *ioDict = [[NSDictionary alloc] initWithContentsOfURL:url];
    
    if(ioDict[@"inputArray"] != nil){
        
        self.inputArray = [self patch:ioDict[@"inputArray"] to:self.inputArray];
        
    }
    
    if(ioDict[@"outputArray"] != nil){
        
        self.outputArray = [self patch:ioDict[@"outputArray"] to:self.outputArray];
    }
    
    if(ioDict[@"talkbackArray"] != nil){
        
        self.talkbackArray = ioDict[@"talkbackArray"];
        
    }
    
    [self makeRowColTitles];
    

}

#pragma mark
#pragma mark ------------- MatrixDelegate methods ---------------------

-(void)refreshGuide{
    // altGuideInRecord
    for(Matrix *matrix in _matrixArray){
        
        [matrix setFader0:matrix.fader0];   // guide is fader0 
    }
}
-(void)refreshCrosspoints{
    
    // aip items
    // 2.10.02 Link Actor Remote, Link Editor Remote
    // we also need to have individual button presses work
    
//    NSLog(@"refreshCrosspoints rehRecPb %d cycleMode %ld",_rehRecPb,(long)_aleDelegate.cycleMode);

    for(Matrix *matrix in _displayedMatrixArray){

//        if([matrix.boxTitle isEqualToString: @"Actor"]){
//            NSLog(@"Actor column");
//        }
        [matrix refreshCrosspoints];    // mixer ahead/in/past buttons gate audio
    }
    // other items
//    [_matrixView autoSlate];
    
}
-(NSString*)sliderToString:(NSInteger) slider{
    
    return [self sliderToString:slider :ufxTaperTable]; // default taper is ufx
    
}
int ctr = 0;
-(void)saveUserDefaults:(id)sender{
//    NSLog(@"saveUserDefaults %d",ctr++);
    [self saveMatrixArrayForMemory:_memoryTag];  // current memory
    
}
-(void)linkRemoteButton:(int)tag :(int)state :(Matrix*)matrix{
    
    // link Actor to Remote Actor
    
    if([_matrixArray indexOfObject:matrix] == 2 && [[NSUserDefaults standardUserDefaults] boolForKey:@"linkRemoteActor"]){
        
        //
         Matrix *dest = _matrixArray[5];
        // we haven't figured out why calling forceState first works
        [dest forceState :tag :state];
//        [dest buttonPressed:button];

    }
    
    // link Editor to Remote Editor
    
    if([_matrixArray indexOfObject:matrix] == 3 && [[NSUserDefaults standardUserDefaults] boolForKey:@"linkRemoteEditor"]){
        
        //
        Matrix *dest = _matrixArray[6];
        [dest forceState :tag :state];
//        [dest buttonPressed:button];

    }
}

-(void)linkRemoteButton:(NSButton*)button :(Matrix*)matrix{
    
    // link Actor to Remote Actor
    
    if([_matrixArray indexOfObject:matrix] == 2 && [[NSUserDefaults standardUserDefaults] boolForKey:@"linkRemoteActor"]){
        
        //
         Matrix *dest = _matrixArray[5];
        // we haven't figured out why calling forceState first works
        [dest forceState :(int)button.tag :button.state];
//        [dest buttonPressed:button];

    }
    
    // link Editor to Remote Editor
    
    if([_matrixArray indexOfObject:matrix] == 3 && [[NSUserDefaults standardUserDefaults] boolForKey:@"linkRemoteEditor"]){
        
        //
        Matrix *dest = _matrixArray[6];
        [dest forceState :(int)button.tag :button.state];
//        [dest buttonPressed:button];

    }

}
-(void)linkRemoteSlider:(NSSlider*)slider :(Matrix*)matrix{
    
    // link Actor to Remote Actor
    
    if([_matrixArray indexOfObject:matrix] == 2 && [[NSUserDefaults standardUserDefaults] boolForKey:@"linkRemoteActor"]){
        
        //
         Matrix *dest = _matrixArray[5];
        // we haven't figured out why calling forceState first works
        [dest forceSlider :slider];

    }
    
    // link Editor to Remote Editor
    
    if([_matrixArray indexOfObject:matrix] == 3 && [[NSUserDefaults standardUserDefaults] boolForKey:@"linkRemoteEditor"]){
        
        //
        Matrix *dest = _matrixArray[6];
        [dest forceSlider :slider];

    }
}
-(void)linkRemoteDelayedVideo:(bool) state :(Matrix*)matrix{
    
    // link Actor to Remote Actor
    
    if([_matrixArray indexOfObject:matrix] == 2 && [[NSUserDefaults standardUserDefaults] boolForKey:@"linkRemoteActor"]){
        
        //
         Matrix *dest = _matrixArray[5];
        dest.followDelayedVideo = state;

    }
    
    // link Editor to Remote Editor
    
    if([_matrixArray indexOfObject:matrix] == 3 && [[NSUserDefaults standardUserDefaults] boolForKey:@"linkRemoteEditor"]){
        
        //
        Matrix *dest = _matrixArray[6];
        dest.followDelayedVideo = state;

    }
}


#pragma mark
#pragma mark ------------- AnnunciatorDelegate methods ---------------------
#define PROTOOLS_SERVER @"Protools server"
#define TEXT_SERVER @"Text server"
#define STREAMER_SERVER @"Streamer server"
#define MADI_SERVER @"MADI server"
#define SAFETY_SERVER @"Boom recorder server"

-(void)dropdownHelper:(NSString*)label :(TcpClientBrowser*)client :(TcpClientConnection*)connection{
    
    if(!_hideServers && [_serverType isEqualToString:label]){
        
        [self setHideServers:true];
        return;
    }
    
    [self setHideServers:false];
    
    [self setServerType:label ];
    [self setServerClient:client];  // combo box is bound to serverClient, this shows the selection
    
    [_serverComboBox setStringValue:@"---"];    // clear any old text with this string
    
    if(connection) {
        
        @try {
            [_serverComboBox selectItemWithObjectValue:connection.netService.name]; // show current connection
        }
        @catch (NSException *exception) {
            
        }
        
    }
    
}
//-(void)showDropdown:(id)sender{
//    
//    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
//    
////    if(sender == _protoolsAnnunciator){
////
////        _serverID = _protoolsAnnunciator;   // so we know what the dropdown refers to
////
////        [self dropdownHelper:PROTOOLS_SERVER :[delegate.adrClientWindowController tcpClient] :(TcpClientConnection*)[delegate.adrClientWindowController connection]];
////
////    }
////    else if(sender == _textAnnunciator){
////
////        _serverID = _textAnnunciator;   // so we know what the dropdown refers to
////        TextWindowClient *textWindowClient = (TextWindowClient*)delegate.textWindowClient;
////        [self dropdownHelper:TEXT_SERVER :[textWindowClient tcpClient] :[textWindowClient connection]];
////    }
////    else if(sender == _streamerAnnunciator){
////
////        _serverID = _streamerAnnunciator;
////        [self dropdownHelper:STREAMER_SERVER :[delegate.streamerWindowController tcpClient] :(TcpClientConnection*)[delegate.streamerWindowController connection]];
////    }
////    else if(sender == _madiAnnunciator){
////
////        _serverID = _madiAnnunciator;   // so we know what the dropdown refers to
////        [self dropdownHelper:MADI_SERVER :_tcpClient :_connection];
////    }
////    if(sender == _safetyAnnunciator){
////
////        _serverID = _safetyAnnunciator; // so we know what the dropdown refers to
////        [self dropdownHelper:SAFETY_SERVER :[(BoomRecorderClient*)delegate.boomRecorderClient tcpClient] :[(BoomRecorderClient*)delegate.boomRecorderClient connection]];
////    }
//}
-(void)leadingEdgeService:(id)sender{
    
    if(sender == _midiStopAnnunciator){
        
        [self midiStopDebounceTimerService];
        
    }
    
    if(sender == _midiPlayAnnunciator){
        
        [self midiPlayDebounceTimerService];
        
    }
}

- (IBAction)onServerDropdown:(id)sender {
    
//    NSString *server = [_serverComboBox stringValue];
//    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    
//    if(_serverID == _textAnnunciator){
//
//        TextWindowClient *textWindowClient = (TextWindowClient*)delegate.textWindowClient;
//        [textWindowClient setDefaultServer:server];
//
//    }
//    else if(_serverID == _streamerAnnunciator){
//
//         [delegate.streamerWindowController setDefaultServer:server];
//    }
//    if(_serverID == _madiAnnunciator){
//
//        [self setDefaultServer:server];
//    }
//    if(_serverID == _safetyAnnunciator){
//
//        [(BoomRecorderClient*)delegate.boomRecorderClient setDefaultServer:server];
//
//    }
//    else if(_serverID == _protoolsAnnunciator){
//        
//        [delegate.adrClientWindowController setDefaultServer:server];
//        
//    }
}
- (IBAction)onDirectMic:(id)sender {
    
    NSString *str = [[NSUserDefaults standardUserDefaults]boolForKey:@"mic1"] ? @"Mic 1\t" : @"";
    
    str =[[NSUserDefaults standardUserDefaults]boolForKey:@"mic2"] ? [str stringByAppendingString:@"Mic 2\t"] : str;
    str =[[NSUserDefaults standardUserDefaults]boolForKey:@"mic3"] ? [str stringByAppendingString:@"Mic 3\t"] : str;
    str =[[NSUserDefaults standardUserDefaults]boolForKey:@"mic4"] ? [str stringByAppendingString:@"Mic 4"] : str;

    [self setActorDirectMic:[str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
}

#pragma mark
#pragma mark ------------- setters/getters ---------------------
-(void)setMotionZoneByte:(unsigned char)motionZoneByte{
    _motionZoneByte = motionZoneByte;
    // 12/07/23 observer for snoopAuto
    [[NSUserDefaults standardUserDefaults]setInteger:(NSInteger)motionZoneByte forKey:@"motionZoneByte"];
}
-(unsigned char)motionZoneByte{
    NSInteger i = [[NSUserDefaults standardUserDefaults] integerForKey:@"motionZoneByte"];
    
    return (unsigned char)i;
}

-(void)setActorDirectMic:(NSString *)actorDirectMic{
    
    NSLog(@"setActorDirectMic %@",actorDirectMic);
    
    // keep track of the previous one so that we can turn it off
    [[NSUserDefaults standardUserDefaults]setObject:self.actorDirectMic forKey:@"lastActorDirectMic"];

    [[NSUserDefaults standardUserDefaults]setObject:actorDirectMic forKey:@"actorDirectMic"];
    
    [_aleDelegate actorDirect:@"94"];  // set the new UFX output
}
-(NSString*)actorDirectMic{
    return [NSUserDefaults.standardUserDefaults objectForKey:@"actorDirectMic"];
}
-(void)setVideoScreenSelector:(NSInteger)videoScreenSelector{
    
    _videoScreenSelector = videoScreenSelector;
//    [NSUserDefaults.standardUserDefaults setInteger:(videoScreenSelector % NSScreen.screens.count) forKey:@"videoScreenSelector"];
    
}
-(NSInteger)videoScreenSelector{
    return [NSUserDefaults.standardUserDefaults integerForKey:@"videoScreenSelector"];
}
-(void)setVideoSourceSelector:(NSInteger)videoSourceSelector{
    _videoSourceSelector = videoSourceSelector;
//    [NSUserDefaults.standardUserDefaults setInteger:(videoSourceSelector % NSScreen.screens.count) forKey:@"videoSourceSelector"];
}
-(NSInteger)videoSourceSelector{
    return [NSUserDefaults.standardUserDefaults integerForKey:@"videoSourceSelector"];
}

-(void)setTalkbackArray:(NSArray *)talkbackArray{
    
    // 2.10.02 DIM and MUTE outputs
    // remove items without talkback values
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    for(int i = 0; i < talkbackArray.count; i++){
        
        NSDictionary *dict = (NSDictionary*)talkbackArray[i];
        
        if( [dict objectForKey:DIM_A_KEY] != nil){
            [array addObject:dict];
        }
        
    }
    _talkbackArray = [[NSArray alloc]initWithArray:array];
    
    NSKeyedArchiver *arch = [[NSKeyedArchiver alloc] initRequiringSecureCoding:false];
    [arch encodeObject:_talkbackArray forKey:TALKBACK_ARRAY_KEY];
    [arch finishEncoding];
    [[NSUserDefaults standardUserDefaults] setObject:arch.encodedData forKey:TALKBACK_ARRAY_KEY];

}
-(NSArray *)talkbackArray{
    return _talkbackArray;
}
-(void)setOutputArray:(NSArray *)outputArray{
    _outputArray = outputArray;
    
    NSKeyedArchiver *arch = [[NSKeyedArchiver alloc] initRequiringSecureCoding:false];
    [arch encodeObject:_outputArray forKey:OUTPUT_ARRAY_KEY];
    [arch finishEncoding];
    [[NSUserDefaults standardUserDefaults] setObject:arch.encodedData forKey:OUTPUT_ARRAY_KEY];
}
-(NSArray*)outputArray{
    return _outputArray;
}
-(void)setInputArray:(NSArray *)inputArray{
    
    _inputArray = inputArray;
    
     NSKeyedArchiver *arch = [[NSKeyedArchiver alloc] initRequiringSecureCoding:false];
     [arch encodeObject:_inputArray forKey:INPUT_ARRAY_KEY];
     [arch finishEncoding];
     [[NSUserDefaults standardUserDefaults] setObject:arch.encodedData forKey:INPUT_ARRAY_KEY];
     
}
-(NSArray *)inputArray{
    
    return _inputArray;
    
}

-(void)setMatrixArray:(NSMutableArray *)matrixArray{
    _matrixArray = matrixArray;
    
    // 2.10.02 show/hide remote actor/editor
//    if(matrixArray.count > 6){
//        ((Matrix*)_matrixArray[5]).buttons = ![[NSUserDefaults standardUserDefaults] boolForKey:@"linkRemoteActor"];
//        
//        ((Matrix*)_matrixArray[6]).buttons = ![[NSUserDefaults standardUserDefaults] boolForKey:@"linkRemoteEditor"];
//    }
//    ((Matrix*)_matrixArray[5]).buttons = true;  // show Remote Actor
//    ((Matrix*)_matrixArray[6]).buttons = true;  // show Remote Editor
    ((Matrix*)_matrixArray[4]).boxTitle = @"Source Connect";
    
    ((Matrix*)_matrixArray[5]).controlsDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"linkRemoteActor"];
    ((Matrix*)_matrixArray[6]).controlsDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"linkRemoteEditor"];
    
    if(((Matrix*)_matrixArray[5]).controlsDisabled){
        
        // copy [5] from [2]
        [((Matrix*)_matrixArray[5]) copySettingsFromMatrix:((Matrix*)_matrixArray[2])];
        
    }
    if(((Matrix*)_matrixArray[6]).controlsDisabled){
        
        // copy [6] from [3]
        [((Matrix*)_matrixArray[6]) copySettingsFromMatrix:((Matrix*)_matrixArray[3])];

    }

    _displayedMatrixArray = [[NSMutableArray alloc] init];
    
    for(Matrix *matrix in matrixArray){
        
        matrix.delegate = self; // the one and only place this is set
        
        if(matrix.buttons != 0){
            [_displayedMatrixArray addObject:matrix];
//            [matrix stateFromStates];
        }else{
            // set all states (buttons) for switchers that aren't shown
            // FIXME: 2.00.00 do we want hidden matrix buttons on?
            [matrix setAllStates:true];
        }
    }
    
    [_collectionView reloadData];
        
}
-(NSMutableArray*)matrixArray{
    return _matrixArray;
}
-(void)showDimCtlRoomForTalkbacks{
    
    // Evan wants control room dim indicator lit if control room is dimmed by talkbacks
    NSNumber *ctlDimA = _talkbackArray[0][DIM_A_KEY];
    NSNumber *ctlDimB = _talkbackArray[0][DIM_B_KEY];
    NSNumber *ctlDimC = _talkbackArray[0][DIM_C_KEY];
    NSNumber *ctlDimD = _talkbackArray[0][DIM_D_KEY];
    
    bool ctlRoomIsDimmed = _dimControlRoom
                            || (ctlDimA.intValue != 0 && _dimA)
                            || (ctlDimB.intValue != 0 && _dimB)
                            || (ctlDimC.intValue != 0 && _dimC)
                            || (ctlDimD.intValue != 0 && _dimD);
    
    [_aleDelegate txOsc:ctlRoomIsDimmed ? @"led 9,91,true" :  @"led 9,91,false"];

}
NSTimer *dimTimer;
-(void)dimTimerService{
//    NSLog(@"dimTimerService");
    [_aleDelegate refreshOutputGains];  // 2.10.02 dim and mute are done on
}
-(void)dimTrailingEdgeDelay:(bool)dim{
    
    [ dimTimer invalidate];
    
    if(dim){
        
        [self dimTimerService];  // leading edge, no delay
        
    }else{
        // trailing edge, delay
//        NSLog(@"dim delay");
        dimTimer = [NSTimer scheduledTimerWithTimeInterval:0.03 target:self selector:@selector(dimTimerService) userInfo:nil repeats:false];
    }
}
-(void)setDimA:(int)dimA{
    _dimA = dimA;
    
    [_aleDelegate txOsc:_dimA ? @"led 9,73,true" :  @"led 9,73,false"];
//    [_aleDelegate txOsc: (_dimA | _dimB) ? @"led 9,91,true" :  @"led 9,91,false"]; // dim indicator
    
    // 2.10.02 'dim control room' indicator
    [self showDimCtlRoomForTalkbacks];
    
    unsigned char gain = dimA ? FADER_0dB : MAX_FADER_ATTENUATION;
    // send Talkback A Channel/CC/gain
    // Mic Talkback A
    for(int i = 0; i < _matrixView.colTitles.count; i++){
        
        NSString *title = _matrixView.colTitles[i][@"Title"];
        if([title hasPrefix:@"Talkback A"]){
            
            NSString *channel = _matrixView.colTitles[i][@"Channel"];
            NSString *controlChange = _matrixView.colTitles[i][@"ControlChange"];

            NSString *str = [NSString stringWithFormat:@"%@ %@ %ld",channel,controlChange,(long)gain];
            
            [_aleDelegate sendUfxString:str];
//            NSLog(@"setDimA %@",str);

            break;
            
        }
        
    }

//    [_matrixView invalidateRect];
//    [self refreshCrosspoints];
    
    [self dimTrailingEdgeDelay:dimA];

}
-(int)dimA
{
    return _dimA;
}
-(void)setDimB:(int)dimB{
    _dimB = dimB;
    
    [_aleDelegate txOsc:_dimB ? @"led 9,74,true" :  @"led 9,74,false"];
//    [_aleDelegate txOsc: (_dimA | _dimB) ? @"led 9,91,true" :  @"led 9,91,false"]; // dim indicator
    
    // 2.10.02 'dim control room' indicator
    [self showDimCtlRoomForTalkbacks];

   unsigned char gain = dimB ? FADER_0dB : MAX_FADER_ATTENUATION;
    // send Talkback B Channel/CC/gain
    // Mic Talkback B
    for(int i = 0; i < _matrixView.colTitles.count; i++){
        
        NSString *title = _matrixView.colTitles[i][@"Title"];
        if([title hasPrefix:@"Talkback B"]){
            
            NSString *channel = _matrixView.colTitles[i][@"Channel"];
            NSString *controlChange = _matrixView.colTitles[i][@"ControlChange"];

            NSString *str = [NSString stringWithFormat:@"%@ %@ %ld",channel,controlChange,(long)gain];

            [_aleDelegate sendUfxString:str];
//            NSLog(@"setDimB %@",str);
            
            break;
            
        }
        
    }

    [self dimTrailingEdgeDelay:dimB];
}
-(int)dimB
{
    return _dimB;
}
-(void)setDimC:(int)dimC{
    _dimC = dimC;
    [_aleDelegate txOsc:_dimC ? @"led 9,109,true" :  @"led 9,109,false"];
    
    // 2.10.02 'dim control room' indicator
    [self showDimCtlRoomForTalkbacks];

    unsigned char gain = dimC ? FADER_0dB : MAX_FADER_ATTENUATION;
     // send Talkback C Channel/CC/gain
     // Mic Talkback C
     for(int i = 0; i < _matrixView.colTitles.count; i++){
         
         NSString *title = _matrixView.colTitles[i][@"Title"];
         if([title hasPrefix:@"Talkback C"]){
             
             NSString *channel = _matrixView.colTitles[i][@"Channel"];
             NSString *controlChange = _matrixView.colTitles[i][@"ControlChange"];

             NSString *str = [NSString stringWithFormat:@"%@ %@ %ld",channel,controlChange,(long)gain];

             [_aleDelegate sendUfxString:str];
 //            NSLog(@"setDimB %@",str);
             
             break;
             
         }
         
     }

    [self dimTrailingEdgeDelay:dimC];
}
-(int)dimC{
    return _dimC;
}
-(void)setDimD:(int)dimD{
    
    _dimD = dimD;
    [_aleDelegate txOsc:_dimD ? @"led 9,110,true" :  @"led 9,110,false"];
    
    // 2.10.02 'dim control room' indicator
    [self showDimCtlRoomForTalkbacks];

    unsigned char gain = dimD ? FADER_0dB : MAX_FADER_ATTENUATION;
    // send Talkback A Channel/CC/gain
    // Mic Talkback A
    for(int i = 0; i < _matrixView.colTitles.count; i++){
        
        NSString *title = _matrixView.colTitles[i][@"Title"];
        if([title hasPrefix:@"Talkback D"]){
            
            NSString *channel = _matrixView.colTitles[i][@"Channel"];
            NSString *controlChange = _matrixView.colTitles[i][@"ControlChange"];

            NSString *str = [NSString stringWithFormat:@"%@ %@ %ld",channel,controlChange,(long)gain];
            
            [_aleDelegate sendUfxString:str];
//            NSLog(@"setDimA %@",str);

            break;
            
        }
        
    }

    [self dimTrailingEdgeDelay:dimD];
}
-(int)dimD{
    return _dimD;
}
-(void)setDimControlRoom:(bool)dimControlRoom{
    _dimControlRoom = dimControlRoom;
    [self showDimCtlRoomForTalkbacks];  // might be dimmed by talkback
    [_aleDelegate refreshOutputGains];

}
-(bool)dimControlRoom{
    return _dimControlRoom;
}
-(void)setMuteAll:(bool)muteAll{
    _muteAll = muteAll;
    [_aleDelegate txOsc:_muteAll ? @"led 9,86,true" :  @"led 9,86,false"];
    [_aleDelegate refreshOutputGains];
}
-(bool)muteAll{
    return _muteAll;
}
//-(void)setMuteControlRoom:(bool)muteControlRoom{
//    _muteControlRoom = muteControlRoom;
//    [_aleDelegate txOsc:_muteControlRoom ? @"led 9,87,true" :  @"led 9,87,false"];
//    [_aleDelegate refreshOutputGains];
//
//}
//-(bool)muteControlRoom{
//    return _muteControlRoom;
//}
//-(void)setMuteStage:(bool)muteStage{
//    _muteStage = muteStage;
//    [_aleDelegate txOsc:_muteStage ? @"led 9,88,true" :  @"led 9,88,false"];
//    [_aleDelegate refreshOutputGains];
//
//}
//-(bool)muteStage{
//    return _muteStage;
//}
//-(void)setMuteActor:(bool)muteActor{
//    _muteActor = muteActor;
//    [_aleDelegate txOsc:_muteActor ? @"led 9,89,true" :  @"led 9,89,false"];
//    [_aleDelegate refreshOutputGains];
//}
//-(bool)muteActor{
//    return _muteActor;
//}
//-(void)setMuteEditor:(bool)muteEditor{
//    _muteEditor = muteEditor;
//    [_aleDelegate txOsc:_muteEditor ? @"led 9,90,true" :  @"led 9,90,false"];
//    [_aleDelegate refreshOutputGains];
//
//}
//-(bool)muteEditor{
//    return _muteEditor;
//}
-(void)setTrimFrames:(NSInteger)trimFrames{
    _trimFrames = trimFrames;
    [[NSUserDefaults standardUserDefaults]setInteger:trimFrames forKey:@"trimFrames"];
}
-(NSInteger)trimFrames{
    return [[NSUserDefaults standardUserDefaults]integerForKey:@"trimFrames"];
}
-(void)rehRecPbOneshot{
    
//    NSLog(@"rehRecPbOneshot");

    // set the matrix buttons when rehRecPb changes
    for(Matrix *matrix in _matrixArray){
        [matrix stateFromStates];   // sets buttons, faders, refreshes crosspoints
    }
//    [self refreshCrosspoints];  // 2.10.02
 
}
NSTimer *rehRecPbOneshotTimer;

-(void)setRehRecPb:(int)rehRecPb{
    
    NSLog(@"setRehRecPb %d -> %d",_rehRecPb,rehRecPb);
    
//    if(_rehRecPb == 5 && rehRecPb == 0){
//        NSLog(@"wassa matta u?");
//    }
    
    [self setMemoryTag:0]; // memory zero
    
    switch(rehRecPb){
            
        case MODE_CONTROL_REHEARSE:break;
        case MODE_CONTROL_RECORD: break;
        case MODE_CONTROL_PLAYBACK: break;
        case MODE_CONTROL_REHEARSE_PENDING:break;
        case MODE_CONTROL_RECORD_PENDING: break;
        case MODE_CONTROL_PLAYBACK_PENDING: break;
        default: return;    // used for indexing states[], reject bad indices
            
    }
    
    _rehRecPb = rehRecPb;   // done early so that new state is available
    
    [_aleDelegate dialMidiRefresh];   // 2.00.00
//    [_aleDelegate.streamerWindowController sendAnnunciatorByTag:rehRecPb];
    _aleDelegate.overlayWindowController.viewController.rehRecPb = rehRecPb;
   
    [_aleDelegate txOsc:[NSString stringWithFormat:@"rehRecPb %d",rehRecPb]];    // mode
        
    [_aleDelegate sendMidiToClosure];   // send MIDI status messages
    
    switch(rehRecPb){
        case MODE_CONTROL_PLAYBACK_PENDING:
        case MODE_CONTROL_RECORD_PENDING:
        case MODE_CONTROL_REHEARSE_PENDING: // indicators
            if(_aleDelegate.streamerWindowController.pictureTag != TAG_ALWAYS_ON){
                [_aleDelegate.overlayWindowController.viewController.streamer fadeToBlack:true :_aleDelegate.streamerWindowController.fadeSeconds];
                
            }
            break;
        default:
            break;
    }
    
    int row = _rehRecPb;
    int col = (int)(_presetMatrix.selectedTag % 3);
    NSCell *cell = [_presetMatrix cellWithTag:(row * 3) + col];
    
    if(cell){
        [_presetMatrix selectCell:cell];
    }
    
    [_rehearseAnnunciator setState:(rehRecPb % 4) == MODE_CONTROL_REHEARSE];   // rehearse
    [_recordAnnunciator setState:(rehRecPb % 4) == MODE_CONTROL_RECORD];
    [_playbackAnnunciator setState:(rehRecPb % 4) == MODE_CONTROL_PLAYBACK];

    [_aleDelegate txOsc:[NSString stringWithFormat:@"rehRecPb %d",_rehRecPb]];    // mode
    
    Document *doc = [_aleDelegate topDocument];
    
    if(doc && doc.recordCycleDictionaryState == RECORD_CYCLE_DICTIONARY_IDLE){
        [doc sendDialogToStreamerForDictionary]; // for case where we had been in playback
        [doc sendTakeToStreamerForDictionary];
    }
    
    // monitor switching
    // preset matrix (rectangle of radio buttons) follows
    [rehRecPbOneshotTimer invalidate];
    
    if(_aleDelegate.cycleMotion != CYCLE_MOTION_IDLE){
        
        double monitorDelay = [[NSUserDefaults standardUserDefaults] doubleForKey:@"monitorDelay"];
        
//        NSLog(@"triggering rehRecPbOneshot, delay %3.2f",monitorDelay);

        
        // delay in cycle monitor switching 9/05/23
        rehRecPbOneshotTimer = [NSTimer scheduledTimerWithTimeInterval:monitorDelay target:self selector:@selector(rehRecPbOneshot) userInfo:nil repeats:false];

    }else{
        
        [self rehRecPbOneshot]; // no delay
   }
    
}
-(int)rehRecPb{
    return _rehRecPb;
}
NSTimer *aipTimer;
-(void)aipTimerService{
    // github tickle
    self.delayedAheadInPast = self.aheadInPast;
    // refresh the crosspoints on delayed aip
    [self refreshCrosspoints];  // calls autoSlate()
}
-(void)setAheadInPast:(int)aheadInPast{
    
//    NSLog(@"setAheadInPast");
    
    switch(aheadInPast){
        case MODE_AHEAD: break;
        case MODE_IN: break;
        case MODE_PAST: break;
        default: return;    // used for indexing states[], reject bad indices
    }
    
    // v1.00.23 no in/past switching unless enabled
    NSString *key = @"enInPastSwitching";
    NSInteger state = [[NSUserDefaults standardUserDefaults] integerForKey:key];
    if(state == NSControlStateValueOff && aheadInPast == MODE_PAST){
        aheadInPast = MODE_IN;
    }
    
    // we are called every frame, act on changes only
    if(_aheadInPast == aheadInPast){return;}   // no change, no actions
        NSLog(@"aheadInPast %d->%d",_aheadInPast,aheadInPast);
    _aheadInPast = aheadInPast;

//    NSDate *now = [[NSDate alloc]init];
    
    bool delayOff =  [[NSUserDefaults standardUserDefaults]boolForKey:@"DialMuteKey_103"];
    
    if(self.rehRecPb == MODE_CONTROL_RECORD && !delayOff){
        // delay by videoDelaySeconds
        double delay = [[NSUserDefaults standardUserDefaults]doubleForKey:@"videoDelaySeconds"];
        aipTimer = [NSTimer scheduledTimerWithTimeInterval:delay target: self selector:@selector(aipTimerService) userInfo:nil repeats: NO];
        
    }else{
        self.delayedAheadInPast = aheadInPast;   // no delay
    }
    
    
    // preset matrix (rectangle of radio buttons) follows
    int row = (int)_presetMatrix.selectedTag / 3;
    int col = aheadInPast;
    NSCell *cell = [_presetMatrix cellWithTag:(row * 3) + col];
    
    if(cell){
        [_presetMatrix selectCell:cell];
    }

    [_aheadAnnunciator setState:aheadInPast == MODE_AHEAD];
    [_inAnnunciator setState:aheadInPast == MODE_IN];
    [_pastAnnunciator setState:aheadInPast == MODE_PAST];
    
    [self refreshCrosspoints];  // approx. 6 milliseconds, calls autoSlate()

    // show on Companion
    [_aleDelegate txOsc:[NSString stringWithFormat:@"aheadInPast %d",_aheadInPast]];    // track selector
    [_aleDelegate sendMidiToClosure];   // send MIDI status messages

}
-(int)aheadInPast{
    return _aheadInPast;
}
-(void)setRemoteDelay:(NSInteger)remoteDelay{

    // FIXME is this needed? What should it do?
}
-(NSInteger)remoteDelay{
    
    // return videoDelaySeconds as frames
    if(_aleDelegate.topDocument && self.rehRecPb == MODE_CONTROL_RECORD){
        double t = [[NSUserDefaults standardUserDefaults]doubleForKey:@"videoDelaySeconds"];
        switch(_aleDelegate.topDocument.tcType)
        {
            case TCTYPE_24: return (NSInteger)round((t * 24.0));
            case TCTYPE_25:return (NSInteger)round((t * 25.0));
            default: return (NSInteger)round((t * 30.0));
        }
    }
    return 0;
}
-(void)setCaptureFirstLineInRehearse:(bool)captureFirstLineInRehearse{
    
    [[NSUserDefaults standardUserDefaults]setBool:captureFirstLineInRehearse forKey:@"captureFirstLineInRehearse"];
    _captureGuide = captureFirstLineInRehearse;   // assume checking the box means we want to capture the guide track
}
-(bool)captureFirstLineInRehearse{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"captureFirstLineInRehearse"];
}

//-(void)setUseAltGuideInRecord:(bool)useAltGuideInRecord{
//    // FIXME does this trigger bindings?
//    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:useAltGuideInRecord] forKey:@"useAltGuideInRecord"];
//
//    [self refreshGuide];
//
//}
//-(bool)useAltGuideInRecord{
//    return [[[NSUserDefaults standardUserDefaults] objectForKey:@"useAltGuideInRecord"] boolValue]; //1.00.21
//}
- (IBAction)onShow16Tracks:(id)sender {
    // TODO: v1.00.23 check with Evan, is this what he wants? There was no action on checking the box
    // how did it work? Answer: we had a @property bool show16Tracks in the .h file, and we implemented a setter and getter rather than doing @synthesize. We commented that out because we have a user defaults var of the same name and want to avoid confusion. Check triggering of bindings.
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    [delegate set16TrackLED];
    [delegate selectCurrentSixteenTrackMemory];             // show the tracks

}

-(void)setShow16Tracks:(bool)show16Tracks{
    
    // FIXME does this trigger bindings?
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:show16Tracks] forKey:@"show16Tracks"];

    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    [delegate set16TrackLED];
    
}
-(bool)show16Tracks{
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [[defaults objectForKey:@"show16Tracks"] boolValue]; //1.00.21
   
}
// V1.00.21
// end of v1.00.21 additions
bool isFirstNumRecTracksTag = true;

-(void)setNumRecTracksTag:(NSInteger)numRecTracksTag{
    
    // must wait for record operation to complete (logging can get corrupted otherwise)
    
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    
    if([delegate cycleMotion] != CYCLE_MOTION_IDLE){
        
        [delegate alertErr:@"change monitor formats only when stopped" :@""];
        
//        [NSApp activateIgnoringOtherApps:YES];  // brings our alert to the front
//
//        NSAlert *alert =  [[NSAlert alloc] init];
//        alert.messageText = @"change monitor formats only when stopped";
//
//        [alert runModal];

        return;
        
    }

    if(!isFirstNumRecTracksTag){
        NSArray *formatString = @[@"monoRecord",@"stereoRecord",@"lcrRecord",@"4TrackRecord",@"6TrackRecord",@"8TrackRecord"];
        
        //     rename to the default name, switch '1' will continue
        [delegate selectCurrentSixteenTrackMemory]; // 2.00.00 guide routing etc may leave us in the wrong memory for naming the last track
        [delegate.adrClientWindowController txMsg:[NSString stringWithFormat:@"jxaRenameLastTrack\t1\t%@",formatString[self.numRecTracksTag]]];
    }
    
    _numRecTracksTag = numRecTracksTag; // new value
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSString stringWithFormat:@"%ld",numRecTracksTag] forKey:@"numRecTracksTag"];
    
    NSArray *trackString = @[@"Mono",@"Stereo",@"LCR",@"4X",@"6X",@"8X"];
    [self setRecTracks:trackString[self.numRecTracksTag]];  // editor rec tracks field is bound to this, do not comment this out
    [delegate txOsc:[NSString stringWithFormat:@"monitor %ld", numRecTracksTag]];
    
    // 2.10.02 recall the proper memory for this format, 0,5 -> 33-38
    
    if(isFirstNumRecTracksTag){
        
        isFirstNumRecTracksTag = false;
        [delegate showSixteenTracks:nil];   // Evan request 2.10.02
        
    }else{
        NSString *msg = [NSString stringWithFormat:@"mem %ld",numRecTracksTag + 33];
        [delegate.adrClientWindowController txMsg:msg];
    }

}
-(NSInteger)numRecTracksTag{
    return [[NSUserDefaults standardUserDefaults]integerForKey:@"numRecTracksTag"];;
}
-(void)setSampleRateTag:(NSInteger)sampleRateTag{
    
    NSLog(@"sampleRateTag %ld",sampleRateTag);
    
    [NSUserDefaults.standardUserDefaults setInteger:sampleRateTag forKey:@"sampleRateTag"];
    [_aleDelegate txOsc:[NSString stringWithFormat:@"sampleRate %ld",sampleRateTag]];
    
    [self makeRowColTitles];
    
}
-(NSInteger)sampleRateTag{
    return [NSUserDefaults.standardUserDefaults integerForKey:@"sampleRateTag"];
}
- (IBAction)onSampleRateRadioButton:(id)sender {
    
    self.sampleRateTag = self.sampleRateTag;    // perform associated actions
}
- (IBAction)onNumRecTracksRadioButton:(id)sender {
    
    self.numRecTracksTag = self.numRecTracksTag;    // perform associated actions
}

//-(void)continueNumRecTracksRename{
//
//    return;
//
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//
//    // 2.10.02 commented out so that narrow tracks are shown (mem 33-38)
//    // mixers use narrow view to enable/disable tracks
////    [delegate selectTrackMemory:delegate.currentTrack]; // get in the right bank
////
////    [delegate selectCurrentSixteenTrackMemory];
//
//    [delegate.adrClientWindowController txMsg:@"jxaGetSession"];    // reads the log
//}

-(void)setMidiState:(NSInteger)midiState{
    
    [_midiAnnunciator setState:midiState];
    
    if(_midiTimer && _midiTimer.isValid)[_midiTimer invalidate];
    [self setMidiTimer:[NSTimer scheduledTimerWithTimeInterval:MIDI_PING_TIMEOUT target: self selector:@selector(midiTimer_service) userInfo:nil repeats: NO]] ;
    
}
-(NSInteger)midiState{
    return _midiAnnunciator.state;
}
-(void)setAdrClientState:(NSInteger)adrClientState{
    
    [_protoolsAnnunciator setState:adrClientState];

}
-(NSInteger)adrClientState{
    return _protoolsAnnunciator.state;
}
- (NSString *)sanitizeFileNameString:(NSString *)fileName {
    NSCharacterSet* illegalFileNameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>.^\r\n\t"];   // added '^' 10/12/15 per Evan
    // 12/7/23 replace instances of \\r with \n
    // see sample:
    // /Users/protools/FooFolder/CLR Tom Adam Scott 120523.txt
    
    return [[fileName componentsSeparatedByCharactersInSet:illegalFileNameCharacters] componentsJoinedByString:@" "];
}
//-(void)finalizeRecord:(bool)cutAndPaste{
//
//    NSLog(@"finalizeRecord cutAndPaste %d",cutAndPaste);
//    return; // TODO: manual finalize of record
//
//
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//    AdrClientWindowController *acwc = delegate.adrClientWindowController;
//    Document *doc = [delegate topDocument];
//
//    [(BoomRecorderClient*)delegate.boomRecorderClient stopBoomRecorder];
//
//    @autoreleasepool {
//
//        NSString *cmd = nil;
//
//        if(cutAndPaste){
//
//            [delegate forceBlack:true];
//            [acwc txMsg:@"videoOnline 0"];
//            [delegate selectCurrentTrackMemory:nil];
//
//        }
//
//        NSString *dlg = [doc dialogForDictionary:delegate.recordCycleDictionary];
//
//        NSIndexSet *set = [doc selectedRowIndexes];
//
//        // if we have merged lines, use them for the name
//        if(set && set.count){
//
//            dlg = @"";
//
//            for(NSInteger i = set.firstIndex; i <= set.lastIndex; i++){
//
//                NSDictionary *dict = [doc.tableContents objectAtIndex:i];
//                if(dlg.length) dlg = [dlg stringByAppendingString:@" "];
//                dlg = [dlg stringByAppendingString:[doc dialogForDictionary:dict]];
//
//            }
//        }
//
//        if(dlg.length > 200) dlg = [dlg substringToIndex:200];
//
//
//        //                NSString *clipName = [doc clipNameForDictionary:delegate.recordCycleDictionary];
//
//        //int tcType = (int)[[doc fpsComboBox] indexOfSelectedItem];
//        // losing fpsComboBox
//        int tcType = [delegate getTcType];
//
//        if(tcType < 0) tcType = 0;  // 24fps if none selected
//
//        // park at the start plus a programmable number of frames (which is a minus number always)
//        NSString *start = [_tcf tcForString:[doc startForDictionary:delegate.recordCycleDictionary]];
//
//        NSInteger trimFrames = [self trimFrames];
//        trimFrames += [_tcc tcToBinary:start withType:tcType];
//        start = [_tcc binaryToTc:(int)trimFrames withType:tcType];
//
//        [delegate.adrClientWindowController txMsg:@"linkTimelineAndEditSelection 1"]; // so that locates load the edit in/out points
//
//        [delegate locate:start];
//        // key stroke a (trims the front per Evan Daum)
//        //                [acwc txMsg:@"keyStroke a"];
//
//        // cutAndPaste actor dialog trackNumber
//        dlg = [self sanitizeFileNameString:dlg];
//
//        if(!doc.dialogInClipName) dlg = @"";
//
//        NSString *cueNote;
//
//        if(doc.notesInClipName){
//            cueNote = [[delegate topDocument] cueNote];
//            cueNote = [self sanitizeFileNameString:cueNote];
//        }
//
//        NSString *recordToComposite = [NSString stringWithFormat:@"%d",doc.recordToComposite];
//
//        delegate.lastRecordTrack = delegate.currentTrack;
//        [delegate incrementRecordTrack]; // after cut and paste is started, incr the track
//        [delegate.topDocument saveToLog]; // save to log after the track increment
//
//        if(cutAndPaste){
//
//            // we see bouncing in ADR1, 'videoOnline 1' and mem xx being called twice fast
//            if (cueNote && cueNote.length) {
//                cmd = [NSString stringWithFormat:@"cutAndPaste\t%@ %@\t%@",cueNote,dlg,recordToComposite];
//            }else{
//                cmd = [NSString stringWithFormat:@"cutAndPaste\t%@\t%@",dlg,recordToComposite];
//            }
//            cmd = [cmd stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//
//            if(cmd.length > 120) cmd = [cmd substringToIndex:120];    // pt takes too long to name clips otherwise
//
//            cmd = [delegate stripNonAscii:cmd];  // helper to remove non-ascii chars, FIXME will not work for Latin 1
//
//            [acwc txMsg:cmd];   // rename clip, copy to composite and the target track
//
//        }
//
//    }
//}
-(void)cueToTrimFrames{
    
    [self cueToTrimFrames:@"3"];
    
}
-(void)cueToTrimFrames:(NSString*)theIndex{
    // 2.00.00 recordOffService
    // calc trim frame cuepoint
    // locate
    // get PT position
    // copy clip up
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    Document *doc = [delegate topDocument];
    
    // check for recordCycleDictionary
    if(!doc.recordCycleDictionary){
        
        return;
    }

    int tcType = [delegate getTcType];

    if(tcType < 0) tcType = 0;  // 24fps if none selected
    
    // park at the start plus a programmable number of frames (which is a minus number always)
    NSString *start = [_tcf tcForString:[doc startForDictionary]];

    NSInteger trimFrames = [self trimFrames];
    trimFrames += [_tcc tcToBinary:start withType:tcType];
    start = [_tcc binaryToTc:(int)trimFrames withType:tcType];
    
    [delegate.adrClientWindowController txMsg:@"videoOnline 0"];
    [delegate.adrClientWindowController txMsg:@"linkTimelineAndEditSelection 1"]; // so that locates load the edit in/out points
    [delegate selectCurrentSixteenTrackMemory];     // might have changed banks
    
    [delegate locate:start :theIndex];  // locate for recordOffService, copyClipToComp
}
-(void)didCueToTrimFrames{
    
    // 2.00.00 continue recordOffService
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    AdrClientWindowController *acwc = delegate.adrClientWindowController;
    Document *doc = [delegate topDocument];
    
    NSString *dlg = doc.dialogInClipName ?  doc.dialog : @"";
    NSString *notes = doc.notesInClipName ? doc.notes :  @"";
    
    // only the first line is in the clip name
    
    if(dlg.length > DIALOG_CLIP_LENGTH) dlg = [dlg substringToIndex:DIALOG_CLIP_LENGTH];
    
    dlg = [self sanitizeFileNameString:dlg];
    notes = [self sanitizeFileNameString:notes];
    
    // 2.00.00 if we are showing 16 tracks, we have to move up some tracks to copy the clip
    // 2.10.02 track selector can change during RECORD cycle

    NSLog(@"currentTrack %ld",delegate.currentTrack);
    NSInteger tracksUp  = 16 - ((delegate.currentTrack) % 16);
    
    if (!self.show16Tracks){
        [delegate selectCurrentTrackMemory:nil];    // show a single track for the jxaCutAndPaste. This lets us change the target track during CYCLE record
        tracksUp = 1;
    }

    NSString *cmd;
    
    // delay is in 1/2 frames
    NSInteger d = [[NSUserDefaults standardUserDefaults]integerForKey:@"DialValueKey_103"] / 2;
    bool delayOff =  [[NSUserDefaults standardUserDefaults]boolForKey:@"DialMuteKey_103"];  // 'mute' for delay

    NSInteger remoteDelayInRecord =  delayOff ? 0 : (int)d;
    
    if (notes.length) {
        cmd = [NSString stringWithFormat:@"jxaCutAndPaste\t%@ %@\t%d\t%ld\t%ld",notes,dlg,doc.recordToComposite,tracksUp,remoteDelayInRecord];
    }else{
        cmd = [NSString stringWithFormat:@"jxaCutAndPaste\t%@\t%d\t%ld\t%ld",dlg,doc.recordToComposite,tracksUp,remoteDelayInRecord];
    }
    cmd = [cmd stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
//    if(cmd.length > 120) cmd = [cmd substringToIndex:120];    // pt takes too long to name clips otherwise
    
    cmd = [delegate stripNonAscii:cmd];  // helper to remove non-ascii chars, FIXME will not work for Latin 1

    [acwc txMsg:cmd];   // rename clip, copy to composite and the target track

}
//-(void)recordOffService:(NSInteger)cycleMode :(NSInteger)cycleMotion{
//
////    NSLog(@"recordOffService");
//
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//    AdrClientWindowController *acwc = delegate.adrClientWindowController;
//    Document *doc = [delegate topDocument];
//
//    // if there is no cue sheet or nothing is selected, do not execute any macros
//
//    if(doc.tableContents.count == 0 || !delegate.recordCycleDictionary){
//
//        return;
//    }
//
//    switch (cycleMode) {
//
////        case CYCLE_MODE_CANCEL_RECORD:
//        case CYCLE_MODE_RECORD: // we are not in the loop yet...
//
//            [(BoomRecorderClient*)delegate.boomRecorderClient abortBoomRecorder];
//
//            [acwc txMsg:@"keyWithModifiers\tz\t1"]; // modifiers in 2nd operand, 0-15, [0] command [1] option [2] control [3] shift
//            [delegate decrementRecordTake];
////            [delegate setCycleMode:CYCLE_MODE_IDLE];  // redundant
////            [self setModeControl:MODE_CONTROL_REHEARSE];
//
//            break;
//
////        case CYCLE_MODE_RETRY_RECORD:
////
////            [(BoomRecorderClient*)delegate.boomRecorderClient abortBoomRecorder];
////
////            [acwc txMsg:@"keyWithModifiers\tz\t1"]; // modifiers in 2nd operand, 0-15, [0] command [1] option [2] control [3] shift
////            [delegate decrementRecordTake];
////            [delegate reCycle];//cycle];   // FIXME ISDN
////
////            break;
//
//        case CYCLE_MODE_RECORD_KEEP_TAKE:
//
//            [self finalizeRecord:true];  // start cut and paste et cetera
//            if(cycleMotion == CYCLE_MOTION_ACTIVE) [self setRehRecPb:MODE_CONTROL_REHEARSE]; // stopped at Protools keyboard
////            [delegate setCycleMode:CYCLE_MODE_IDLE];  // redundant
//
//            break;
//
////        case CYCLE_MODE_ARM: // addition 3/6/16 to go from REH or PB to REC
////
////            [delegate reCycle];//cycle];   // FIXME ISDN
////
////            break;
//
////        case CYCLE_MODE_RECORD_STACK:
////
////            [self finalizeRecord:true];  // start cut and paste et cetera
//////            [delegate setCycleMode:CYCLE_MODE_IDLE]; // redundant
////
////            switch ([self rehRecPb]) {
////
////                case MODE_CONTROL_REHEARSE:
////                case MODE_CONTROL_PLAYBACK: // stacked commands...
////
////                    [delegate reCycle];//cycle];   // FIXME ISDN
////
////                    break;
////
////                default:
////
//////                    [self setModeControl:MODE_CONTROL_REHEARSE];
////
////                    break;
////            }
////
////
////            break;
//
////        case  CYCLE_MODE_REARM_RECORD:
////
////            [self finalizeRecord:true];  // start cut and paste et cetera
////            [delegate reCycle];//cycle];   // FIXME ISDN
////
////            break;
//
//        case CYCLE_MODE_SKIP_PASTE:
//
//            [self finalizeRecord:false];
//            [delegate setCycleMode:CYCLE_MODE_RECORD];
//            [delegate reCycle];//cycle];   // FIXME ISDN
//
//            break;
//
//        default:
////            [self setModeControl:MODE_CONTROL_REHEARSE];    // go to rehearse after playback cycle
//            break;
//    }
//
//}
//-(void)setSafetyRecorderState:(NSInteger)safetyRecorderState{
//
////    _safetyRecorderState = safetyRecorderState;
////    [_safetyAnnunciator setState:safetyRecorderState];
////    [self setSafetyRecorderImage:(safetyRecorderState ? greenImage : redImage)];
//
//}
//-(NSInteger)safetyRecorderState{
////    return _safetyRecorderState;
////    return [_safetyAnnunciator state];
//}
//-(void)setTbDim:(NSInteger)tbDim{
//    _tbDim = tbDim;
//    [self memoryFromMatrix:nil];
//    [self saveDefaults];
//
//}
//-(NSInteger)tbDim{
//    return _tbDim;
//}

//-(void)setTalkbackState:(NSInteger)talkbackState{
//    
//    if(_numRowsAndCols == 16) talkbackState = 0;    // no talkback for 192k
//    if(_numRowsAndCols == 32 && talkbackState == 2) talkbackState = 0;    // no talkback2 for 96k
//    
//    _talkbackState = talkbackState;
//    
//    switch (_talkbackState) {
//        case 0: break;
//        case 1: if(((Matrix*)[_matrixArray objectAtIndex:0]).hide7) _talkbackState = 0; break;  // no tb1
////        case 2: if(((Matrix*)[_matrixArray objectAtIndex:0]).hide7) _talkbackState = 0; break;  // no tb2
//        default: _talkbackState = 0;    // set to an allowed state
//            break;
//    }
//    
//    [self memoryFromMatrix:nil];
//    
//}
//-(NSInteger)talkbackState{
//    return _talkbackState;
//}
//-(void)setSegmentedControlTag:(NSInteger)segmentedControlTag{
//    
//    _segmentedControlTag = segmentedControlTag;
//    
//    for(Matrix *matrix in _matrixArray){
//        
//        [matrix setRehRecPb:_segmentedControlTag];  // so mixers follow the segmented control
//    }
//    
//    [self memoryFromMatrix:nil];
//    
////    [self matrixFromMemory:nil];
//    
//    [_aleDelegate setSegmentedControlLeds];
////    [_aleDelegate setAheadInPastKeys];
//
//}
//-(NSInteger)segmentedControlTag{
//    return _segmentedControlTag;
//}
//-(void)setNumRowsAndCols:(NSInteger)numRowsAndCols{
//
//
//    bool numRowsAndColsDidChange = _numRowsAndCols != numRowsAndCols;
//    _numRowsAndCols = numRowsAndCols;
//    // redraw
//    if(!numRowsAndColsDidChange) return;    // no change, no redraw
//
//    if(numRowsAndCols == 64){
//
////        NSLog(@"setNumRowsAndCols %ld",numRowsAndCols); // FIXME 1.00.05
//
//    }
//
////    // we can only have 5 mixers for 96khz, 192khz
////
////    if(numRowsAndCols < 64){
////
////        [self willChangeValueForKey:@"matrixArray"];
////        while (_matrixArray.count > 5) {
////            NSInteger index = _matrixArray.count - 1;
////            [_outputTableContents removeObjectAtIndex:index];
////            [_matrixArray removeObjectAtIndex:index];
////        }
////        [self didChangeValueForKey:@"matrixArray"];
////    }
//
//
//    if(_rowView)[_rowView invalidateRect];          // draws backImage also
//    if(_columnView)[_columnView invalidateRect];    // draws backImage also
//    [self memoryFromMatrix:nil];                    // loads the big matrix according to the new sample rate
//    if(_matrixView)[_matrixView invalidateRect];    // keep this here, redraws the background once
//
////    [self.talkbackBox setHidden:_matrix0.hideTbBox];    // refresh the binding after changing sample rates
////    [self.tb2Label setHidden:_matrix0.hideTb2];
////    [self.tb2Slider setHidden:_matrix0.hideTb2];
//
//}
//-(NSInteger)numRowsAndCols{
//    return _numRowsAndCols ? _numRowsAndCols : 1;
//}
-(void)setStoreState:(NSInteger)storeState{
    
    _storeState = storeState;
    // set the XKey LED to match
    [_aleDelegate setLEDForUnitID:2 :5 :_storeState];
    [_aleDelegate setLEDForUnitID:2 :13 :_storeState];
    
}
-(NSInteger)storeState{
    return _storeState;
}

-(void)setMemoryTag:(NSInteger)memoryTag{
//    NSLog(@"setMemoryTag");   // happens before onMemoryButton

    // legal memory tags are 0-4
    memoryTag = (memoryTag > 4 || memoryTag < 0) ? 0 : memoryTag;
    
    matrixWasCleared = false;   // tag changed, handled here

    if(_storeState){
        self.storeState = false;
        _memoryTag = memoryTag;
        [self saveMatrixArrayForMemory:_memoryTag]; // saves matrix array and crosspoints
    }else{
        
        if(memoryTag != _memoryTag){
            // don't recall unless memory selector changes
            _memoryTag = memoryTag;
            [self recallMatrixArrayForMemory:memoryTag];   // recalls matrix array and crosspoints
        }
    }
}
-(NSInteger)memoryTag{
    return _memoryTag;
}
//-(void)setXkeyMonitorDestination:(NSInteger)xkeyMonitorDestination{
//    _xkeyMonitorDestination = xkeyMonitorDestination;
//    
//    NSInteger mixerToSelect = 0;
//    
//    switch (xkeyMonitorDestination) {
//            
//        case 16: mixerToSelect = 0; break;  // actor
//        case 24: mixerToSelect = 1; break;  // editor
//        case 32: mixerToSelect = 2; break;  // stage
//        case 40: mixerToSelect = 3; break;  // control room
//        case 48: mixerToSelect = 4; break;  // aux/ISDN
//            
//        default:
//            break;
//    }
//    
//    for(int i = 0; i < _matrixArray.count; i++){
//        
//        Matrix *matrix = [_matrixArray objectAtIndex:i];
//        
//        [matrix setIsSelected:i == mixerToSelect];  // highlights the selected mixer only
//        
//    }
//
//}
//-(NSInteger)xkeyMonitorDestination{
//    return _xkeyMonitorDestination;
//}

#pragma mark -
#pragma mark ------------------ actions -------------------------
//- (IBAction)onGetOffset:(id)sender {
//
//    [_aleDelegate.adrClientWindowController txMsg:@"jxaGetVideoSyncOffset"];
//
//}
- (IBAction)onTest:(id)sender {
    
    // Evan 1/5/24 Found an interesting bug. If you press the knobs to mute zoom and source connect at the same time aledoc crashes.
    // zoom @"9,92,false" @"9,-92,false" source connect @"9,93,false" @"9,-93,false"
    //_aleDelegate
    
    [_aleDelegate rxOsc:@"9,92,false"];
    [_aleDelegate rxOsc:@"9,93,false"];
    [_aleDelegate rxOsc:@"9,-92,false"];
    [_aleDelegate rxOsc:@"9,-93,false"];

    
}
unsigned char adatGain = 1;

- (IBAction)onDeltaMinus:(id)sender {
    // readFeedbacks
    
    [_aleDelegate txOsc:@"filterItems 0"];
    
//    [self setAdatCrosspoints];
//
//    adatGain = adatGain ? 0 : 1;
    
//    [_aleDelegate.lpMini.boomRecorderMidi.midiClient midiTxString:@"this is a test"];

//    [_boomRecorderMIDI doSomething];
    
//    unsigned char bytes[] = {0x90,0x50,0x1c};
//    NSData *data = [[NSData alloc]initWithBytes:bytes length:sizeof(bytes)];
//    [_aleDelegate.lpMini lpMidiTx:data];

    NSLog(@"onDeltaMinus");
    
}

- (IBAction)onDeltaPlus:(id)sender {
    
    unsigned char bytes[] = {0x90,0x50,0xf};
    NSData *data = [[NSData alloc]initWithBytes:bytes length:sizeof(bytes)];
    [_aleDelegate.lpMini lpMidiTx:data];
    
    NSLog(@"onDeltaPlus");
}


// 2.10.02 BlueCat taper table
double blueCatTaperTable[] = {
     -126.0,-121.6,-117.5,-113.6,-110.0,-106.6,-103.4,-100.4                    // 0-7
     ,-97.5,-94.7,-92.1,-89.6,-87.2,-84.8,-82.6,-80.5// 8-15
     ,-78.4,-76.4,-74.5,-72.6,-70.8,-69.0,-67.3,-65.7// 16-23
     ,-64.0,-62.5,-60.9,-59.5,-58.0,-56.6,-55.2,-53.9// 24-31
     ,-52.5,-51.2,-50.0,-48.7,-47.5,-46.3,-45.2,-44.0// 32-39
     ,-42.9,-41.8,-40.7,-39.7,-38.6,-37.6,-36.6,-35.6// 40-47
     ,-34.7,-33.7,-32.8,-31.9,-30.9,-30.0,-29.2,-28.3// 48-55
     ,-27.4,-26.6,-25.8,-24.9,-24.1,-23.3,-22.5,-21.8// 56-63
     ,-21.0,-20.3,-19.5,-18.8,-18.0,-17.3,-16.6,-15.9// 64-71
     ,-15.2,-14.5,-13.9,-13.2,-12.5,-11.9,-11.2,-10.6// 72-79
     ,-9.9,-9.3,-8.7,-8.1,-7.5,-6.9,-6.3,-5.7// 80-87
     ,-5.1,-4.5,-4.0,-3.4,-2.8,-2.3,-1.7,-1.2// 88-95
     ,-0.6,0.0,0.4,0.9,1.5,2.0,2.5,3.0  // 96-103, 0.0 is actually -0.1, we want a 0.0
     ,3.5,4.0,4.5,5.0,5.5,5.9,6.4,6.9// 104-111
     ,7.4,7.8,8.3,8.8,9.2,9.7,10.1,10.6// 112-119
     ,11.0,11.4,11.9,12.3,12.7,13.2,13.6,14.0 // 120-127
    ,14.4// 128 paranoia for conversion
};

// 2.00.00 UFX taper table
// input every value, read the attenuation on the UFX fader
double ufxTaperTable[] = {
    -120.0,-63.2,-62.0,-60.9,-59.7,-58.6,-57.5,-56.3,   // 0-7
    -55.2,-54.1,-53.1,-52.0,-50.9,-49.9,-48.9,-47.8,    // 8-15
    -46.8,-45.8,-44.8,-43.8,-42.9,-41.9,-41.0,-40.1,    // 16-23
    -39.1,-38.2,-37.3,-36.4,-35.6,-34.7,-33.9,-33.0,    // 24-31
    -32.2,-31.4,-30.6,-29.8,-29.0,-28.2,-27.5,-26.7,    // 32-39
    -26.0,-25.3,-24.6,-23.9,-23.2,-22.5,-21.8,-21.2,    // 40-47
    -20.5,-19.9,-19.3,-18.7,-18.1,-17.5,-16.9,-16.4,    // 48-55
    -15.8,-15.3,-14.8,-14.3,-13.8,-13.3,-12.8,-12.3,    // 56-63
    -11.9,-11.4,-11.0,-10.6,-10.2,-9.8,-9.4,-9.0,       // 64-71
    -8.6,-8.3,-8.0,-7.6,-7.3,-7.0,-6.7,-6.4,            // 72-79
    -6.2,-5.9,-5.6,-5.4,-5.1,-4.9,-4.6,-4.4,            // 80-87
    -4.1,-3.9,-3.6,-3.3,-3.1,-2.8,-2.6,-2.3,            // 88-95
    -2.1,-1.8,-1.5,-1.3,-1.0,-0.8,-0.5,-0.3,            // 96-103
    0.0,0.3,0.5,0.8,1.0,1.3,1.5,1.8,                    // 104-111
    2.1,2.3,2.6,2.8,3.1,3.3,3.6,3.9,                    // 112-119
    4.1,4.4,4.6,4.9,5.1,5.4,5.6,6.0,                     // 120-127
    6.3                                                 // 128 paranoia for conversion
};

-(NSInteger)dBToFader:(double)db{
    
    if(db < ufxTaperTable[1]){ return 0;}       // out of table bounds
    if(db >= ufxTaperTable[127]){return 127;}   // out of table bounds
    
    int index = 64;
    int step = 32;
    
    while(step){

        if(db >= ufxTaperTable[index + 1]){
            
            index += step;
            
        }else if(db < ufxTaperTable[index]){
            
            index -= step;
            
        }else{ break;}  // we have the bin
        
        step /= 2;
    }

    return index;

}
-(NSInteger)addDbToFader:(double)db :(NSInteger)fader{
    
    if(fader < 0){
        fader = 0;
        
    }else if(fader > 127){
        fader = 127;
    }
    
    db = db + ufxTaperTable[fader];
    return [self dBToFader:db];
    
}
-(NSInteger)addFaders:(NSInteger) fader0 :(NSInteger) fader1{
    
    // 2.00.00 UFX fader addition
    // add the db of the faders
    // return the index of the db in ufxTaperTable
    if(fader0 < 0 || fader0 > 127 || fader1 < 0 || fader1 > 127){
        NSLog(@"addFaders out of bounds: fader0 %ld fader1 %ld",fader0,fader1);
        return 104; // FIXME: out of bounds, return unity gain
    }
    
    double db = ufxTaperTable[fader0] + ufxTaperTable[fader1];
    
    return [self dBToFader:db];
}
// helper fn for tooltips
-(NSString*)sliderToString:(NSInteger) slider :(double[])taperTable{
    
    if(slider < 0) slider = 0;
    if(slider > 127) slider = 127;
    
    int numItems = sizeof(ufxTaperTable)/sizeof(ufxTaperTable[0]);
    
    if(slider < numItems){
        
        return [NSString stringWithFormat:@"%3.1f dB",taperTable[slider]];

    }
    return [NSString stringWithFormat:@"bad slider value: %ld",slider];
    
}
-(NSString*)bluCatSliderToString:(NSInteger) slider{
    
    return [self sliderToString:slider :blueCatTaperTable]; // default taper is ufx
    
}

#pragma mark ------------V1.00.09 -------------
-(void)positionUnderDocWindow{
    
    AleDelegate *delegate = [NSApp delegate];
    Document *doc = [delegate topDocument];
    if(!doc) return;
    
    DocWindow *window = doc.docWindow;
    if(!window)return;
    
    NSWindow *matrixWindow = [self window];
    
    NSRect matrixRect = matrixWindow.frame;
    matrixRect.size.width = window.frame.size.width;
    matrixRect.size.height = MATRIX_HEIGHT;
    matrixRect.origin = window.frame.origin;
    matrixRect.origin.y -= MATRIX_HEIGHT;
    
    [[delegate.matrixWindowController window] setFrame:matrixRect display:true];
    [[delegate.matrixWindowController window] makeKeyAndOrderFront:nil];   // give it the focus
    [NSApp activateIgnoringOtherApps:YES];

    
}
#pragma mark
// MARK: ------------ NSCollectionView -------------
// 2.00.00 see CollectionViewTester
-(void)configureCollectionView{
    
    // https://www.kodeco.com/1246-collection-views-in-os-x-tutorial
    // 240x96 item
    
    NSCollectionViewFlowLayout *layout = [[NSCollectionViewFlowLayout alloc]init];
    layout.itemSize = NSMakeSize(424, 210.0); // size of our graphic
    layout.sectionInset = NSEdgeInsetsMake(10.0, 20.0, 10.0, 20.0);
    layout.minimumInteritemSpacing = 20.0;
    layout.minimumLineSpacing = 20.0;
    
    _collectionView.collectionViewLayout = layout;
}

// MARK: ---------------- NSCollectionViewDataSource ---------------

-(NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView{
    return 1;
}
- (nonnull NSCollectionViewItem *)collectionView:(nonnull NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(nonnull NSIndexPath *)indexPath {
    // https://www.kodeco.com/1246-collection-views-in-os-x-tutorial
    Item *item = [_collectionView makeItemWithIdentifier:@"Item" forIndexPath:indexPath];
    
    _displayedMatrixArray[indexPath.item].item = item;
    
    return item;
}

- (NSInteger)collectionView:(nonnull NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
//    NSLog(@"numberOfItemsInSection %ld",_matrixArray.count);
    return _displayedMatrixArray.count;
}

//- (BOOL)commitEditingAndReturnError:(NSError *__autoreleasing  _Nullable * _Nullable)error {
//    return false;
//}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    
}
#pragma mark
#pragma mark ------------video delay line -------------

- (IBAction)onDelayNextScreen:(id)sender {
    
    // set next intentionally, not because monitor was turned off
    NSInteger sel = self.videoScreenSelector + 1;
    sel %= NSScreen.screens.count;
    
    [NSUserDefaults.standardUserDefaults setInteger:sel forKey:@"videoScreenSelector"];

    
}
- (IBAction)onDelayNextSource:(id)sender {

    // set next intentionally, not because monitor was turned off
    NSInteger sel = self.videoSourceSelector + 1;
    sel %= NSScreen.screens.count;
    
    [NSUserDefaults.standardUserDefaults setInteger:sel forKey:@"videoSourceSelector"];
}
- (IBAction)onDelayShowHide:(id)sender {
    
    [_aleDelegate onVideoDelayHotKey:nil];
}

#pragma mark
#pragma mark ------------testing -------------
- (IBAction)onButton:(id)sender {
    
    NSArray *array = [[NSUserDefaults standardUserDefaults] arrayForKey:UFX_OUTPUT_KEY];
    
    NSLog(@"OUTPUTS");
    for(int i = 0; i < array.count; i++){
        NSLog(@"%@",array[i]);
    }
    
    array = [[NSUserDefaults standardUserDefaults] arrayForKey:UFX_INPUT_KEY];
    
    NSLog(@"INPUTS");
    for(int i = 0; i < array.count; i++){
        NSLog(@"%@",array[i]);
    }}
#pragma mark
#pragma mark ------------NSTableView helpers -------------

- (IBAction)onDimCheckbox:(id)sender {
    
    self.talkbackArray = self.talkbackArray;  // saves to nsuserdefaults
}
#pragma mark
#pragma mark ------------ BoomRecorderMIDIDelegate -------------

-(void)boomRecorderStatus:(NSInteger) status :(NSInteger) channel{
    
    switch(channel){
        case 0: [_boomRec1Status status:status]; break;
        case 1: [_boomRec2Status status:status]; break;
        default: break;
    }
    
}
@end
