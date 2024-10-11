 //
//  AleDelegate.m
//  TestDoc
//
//  Created by James Ketcham on 7/16/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
// V1.00.08 11/25/15
// 1) column gains are done in vm15a_madi rather than through the crosspoints (cc 31-38)
// 2) changing tabs in matrixWindowController does not do memory recalls (want to leave current matrix setting alone)
// V1.00.09 12/1/2015
// 1) switcher gain trims are sent using 'row' command (row rr cc vv, rr == row, cc == col, vv == value)
// 2) switcher gain trims are MIDI cc 40-103, see 'switcher_gain_table.xlsx'
// V1.00.13 11/7/2017
// send 'win 0' to micro 4.03.51 to clear window inhibits that were added for Mako
// V1.00.17 monitor matrix output to UFX for Evan
//
/* V1.00.18 09/12/20 Evan's requests:
 
 Feature 1:
 A checkbox to have the auto voice slate speak the take number followed by the cuename.  Unchecked it works as it does now with the just takenumber.  If you can increase the speed of the voice too, so it can speak the take and cuename in the 2 seconds allotted.  If you can't control the speed directly from ALEDOC, if you tell System Events or Finder to speak it via Applescript it should follow the speed in the System Prefs for voice.  That would be a good workaround.  Maybe you want to make the voice slate a script then?

 Feature 2:

 A checkbox in the Matrix setup window "Use Alt Guide in Rec Mode".
 Rename "Spare" on the MADI matrix to "Alt Guide C"
 The way it works, when in Record mode, with the box checked, the matrix Guide source will be assigned based on the "Alt Guide C" instead of the main guide inputs.  Unassign the L/R Guides in this scenario.  This will affect all output groups EXCEPT the actor, which will ALWAYS use the main guide.  So, Editor, Stage, Booth and ISDN will be fed from the Alt Guide in Record Mode ONLY when the box is checked.  In Rehearse and Playback modes everyone hears the main guide as usual.

 Purpose:
 The Alt Guide is delayed to match the sync coming back from the remote system, so this is why we need it in record, but not other modes.  The actor needs to always hear the non-delayed guide because they are the first temporal stop for the signal.

 Let me know if this makes sense.  Thanks.
 
 replaced by 'follow delayed video' checkboxes on each matrix
 
 09/14/20 Feature 3:
    Add an output for the MIDI MTC item. Loop MTC in to MTC out.
 */
/*
 V1.00.19
 1) make the UFX input table be user-settable, like the UFX output table is.
 2) change the UFX table indexing to integers (fader numbers), which is mapped through ufxInput.plist, ufxOutput.plist to channel/CC. Users select fader numbers rather than programming channel/CC. An engineer can edit ufxInput.plist, ufxOutput.plist to change the mapping.
 
 V1.00.20 11/8/20
 1) UFX hardware inputs are faders 'H1'-'H16' (not integers), so we can't calc channels 0xb0 etc
    the MIDI channel is now a dictionary entry in ufxInputDictionary, ufxOutputDictionary
 
 01/16/21 v1.00.21 NOTES ON DELAY FOR ACTOR MONITOR SWITCHING
 
    matrixWindowController.aheadInPastFromTc() is called once per frame to set the monitor state
    there is a global trim on the IN switching, _trimFrames
    Evan wants the actor to have a separate trim
 
 Evan's request-
 I had a feature request for ALEDOC I was hoping you could look at when you get a chance.  We're using a piece of software that analyses the round-trip delay to our remote kits and delays the video/audio for the mixer and clients so they see things in sync when recording.  This all works great.  As part of this, the delay analysis program writes a simple text file containing just the number of frames of delay as text, which I then read using applescript inside the Cut and Paste macro in order to move the recorded audio clip back in to the correct position on the timeline (since it is delayed when recorded).  One side-effect of this is the Ahead-In-Past switching is happening early for everyone but the actor when in record, because it's based on the Pro Tools timeline, not the delayed video/audio position.  Would it be possible to offset the AIP switching for everyone but the actor when in record, using that text file as the source of the delay amount?  Maybe we can drop the text file on a button like you do with the sampler to set the path and make it sticky?  You can link turning this functionality on/off to the "use delayed audio in record" checkbox.
 
 01/29/21 v1.00.21 added accessory cc's 112,113 to set monitor matrix page 'Use alt guide in record' and 'show 16 tracks'
 
 */

#import "AleDelegate.h"
#import "StreamerWindowController.h"
#import "MatrixWindowController.h"
#import "MatrixView.h"
#import "AdrClientWindowController.h"
#import "Document.h"
#import "DocWindow.h"
#import "EditorWindowController.h"
//#import "SamplerWindowController.h"
#import "TcCalculator.h"
#import "TCFormatter.h"
//#import "BoomRecorderClient.h"
//#import "RehearseCaptureWindowController.h"
#import "TcpClientConnection.h"
#import "PreferencesWindowController.h"
#import "ArrayController.h"
#import "ColorSupport.h"
#import "AleDoc21-Swift.h"    // must be here to avoid a circular reference

// 3/31/16 MIDI revision
#import "MidiCommands.h"
//#import "LaunchPadMini.h"
//#import "Accessory.h"

#import "Annunciator.h"
#import "OscServer.h"

// hold the track button this long to copy the track to comp track
#define TRACK_TO_COMP_COPY_TIMEOUT 1.0

// version info
// V1.00.03 2/18/15
// 1)TcpClientConnection revised to use resolving state (disconnect, reconnect is simpler and works reliably now)
// 2) timer_service() routines are consequently much simpler
// 3) keypad entry does not automatically add a cue, use 'grab pt info' to get the cue.
// 4) recordEnable script now has an operand, 0 == off, 1 == on, 2 == toggle, no operand == toggle.
// 5) deselectTracks script modified to bring 'Edit' window to the front (so that 'big counter' entry works correctly)
// V1.00.04 debugging at WB
// 1) 'locate::' ignores the out (locate to in only)
enum{
    WINDOW_EDITOR,
    WINDOW_MONITOR,
    WINDOW_DOCUMENT
};
@interface AleDelegate()<TCFormatterDelegate,AdrClientWindowControllerDelegate,MidiHuiDelegate,MidiHuiMtcDelegate,LpMiniDelegate>

@property TcCalculator *tcc;
@property TCFormatter *tcf;
//@property NSString *entryRegister;
@property bool keyboardIsShifted;
@property NSTimer *keyOneshot;  // to discriminate between long and short key presses
@property NSTimer *showArmedOneshot;
@property NSTimer *trackToCompCopyOneshot;
@property NSTimer *timerBlack;
@property NSTimer *timerFadeAnnunciator;

//@property NSTimer *micTimer;    // every second send the mic toggle states to Evan

@property NSTimer *cycle_timer;
@property NSInteger cycleWindowSelector;

@property NSInteger anchor;
@property NSTimer *appLaunchedTimer;

//@property LaunchPadMini *launchPadMini;
//@property Accessory *accessory;
@property OscServer *oscServer;

@property NSInteger dial1;

//@property NSTimer *connectTimer;

@end

@implementation AleDelegate

@synthesize tcc = _tcc;
@synthesize tcf = _tcf;
@synthesize lastCueID = _lastCueID;
@synthesize currentTrack = _currentTrack;
@synthesize session = _session;
//@synthesize recordCycleDictionary = _recordCycleDictionary;
@synthesize cycleMode = _cycleMode;
@synthesize cycleMotion = _cycleMotion;
//@synthesize startFromPrerollTc = _startFromPrerollTc;
@synthesize overlay = _overlay;
@synthesize lastRecordTrack = _lastRecordTrack;
@synthesize trackForMixerWindow;
@synthesize lastTrack = _lastTrack;
//@synthesize cutAndPasteIsActive = _cutAndPasteIsActive; // TODO do we need a timeout?
//@synthesize hidePix = _hidePix;
@synthesize oscServer = _oscServer;
@synthesize overlayWindowController = _overlayWindowController;
@synthesize ptClient = _ptClient;
//@synthesize micDictionary = _micDictionary;
@synthesize prerollIndex = _prerollIndex;
//@synthesize oscToAipDictionary = _oscToAipDictionary;
@synthesize aipPairSelector = _aipPairSelector;
//@synthesize recDelayState = _recDelayState;
@synthesize xKey = _xKey;
@synthesize snoopAuto = _snoopAuto;
@synthesize snoopState = _snoopState;
@synthesize suggestedTrackName = _suggestedTrackName;
@synthesize lpMini = _lpMini;
@synthesize audioPlayerWindowController = _audioPlayerWindowController;
@synthesize cueIdInSlate = _cueIdInSlate;
@synthesize videoDelayWindowController = _videoDelayWindowController;
@synthesize statusClient = _statusClient;
@synthesize control1Client = _control1Client;
@synthesize control2Client = _control2Client;
@synthesize screenRecorder = _screenRecorder;
@synthesize editorWindowController = _editorWindowController;

-(void)xKeyEdge:(NSNotification *)aNotification{
    
    __weak typeof(self) weakSelf = self;
    
    NSDictionary *dict = aNotification.userInfo;
    
    int key = ((NSString *)dict[@"key"]).intValue;
    int unitId = ((NSString *)dict[@"UnitID"]).intValue;
    
    //NSLog(@"key %d unitId %d",key,unitId);
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [weakSelf xKeyPressed:unitId :key];
    });
    
}
-(void)xKeyDescriptor:(NSNotification *)aNotification{
    
    NSDictionary *dict = aNotification.userInfo;
    NSNumber *n = dict[@"unitID"];
    int unitID = n.intValue;
    NSDictionary *product = dict[@"product"];
    NSString *xKeyProduct = product[@"xKeyProduct"];
    
    NSLog(@"xKeyDescriptor UnitID %d xKeyProduct %@" ,unitID,xKeyProduct);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self initLedsForUnitID:unitID];
    });
    
}
-(void)initLedsForUnitID:(NSInteger) unitID{
    
    // when XKEY connects, init display by unitID
    switch(unitID){
        case 8:
            self.prerollIndex = self.prerollIndex;
            break;
        case 6:
            self.currentTrack = self.currentTrack;
            break;
        case 7:
            self.currentTrack = self.currentTrack;
            break;
        default: break;
    }
    
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(xKeyEdge:) name:@"xKeyEdge" object:nil];
//    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(deviceConnected:) name:@"deviceConnected" object:nil];
//    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(deviceDisconnected:) name:@"deviceDisconnected" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(xKeyDescriptor:) name:@"xKeyDescriptor" object:nil];

    
    // preferences, see preferences window
    NSError *error;
    NSDictionary *registrationDefaults = [NSDictionary dictionaryWithObjectsAndKeys://data,@"colorWells",
        [[NSNumber alloc]initWithBool:true],@"isFirstRun",
        [[NSNumber alloc]initWithBool:false],@"delayFullScreen",
        [[NSNumber alloc]initWithBool:true],@"delayExcludeApp",
//        [[NSNumber alloc]initWithBool:false],@"screenRecorderChanged",   // we hate this
        [[NSNumber alloc]initWithInteger:0],@"videoSourceSelector",
        [[NSNumber alloc]initWithInteger:0],@"videoScreenSelector",
        [[NSNumber alloc]initWithDouble:0.0],@"videoDelaySeconds",
        [[NSNumber alloc]initWithDouble:0.083],@"beepsDuration",
        [[NSNumber alloc]initWithBool:false],@"DialMuteKey_107",    // Remote Editor, may not have Companion dial in some rooms, set to unmute
        [[NSNumber alloc]initWithInteger:104],@"DialValueKey_107",  // Remote Editor, may not have Companion dial in some rooms, set to 0dB
        [[NSNumber alloc]initWithInteger:NSControlStateValueOff],@"enInPastSwitching",
        //          [NSKeyedArchiver archivedDataWithRootObject:_micDictionary requiringSecureCoding:false error:&error],@"micDictionary",
        [NSKeyedArchiver archivedDataWithRootObject:NSColor.clearColor requiringSecureCoding:false error:&error],@"rehearseBgColor",
        [NSKeyedArchiver archivedDataWithRootObject:NSColor.clearColor requiringSecureCoding:false error:&error],@"recordBgColor",
        [NSKeyedArchiver archivedDataWithRootObject:NSColor.clearColor requiringSecureCoding:false error:&error],@"playbackBgColor",
        [NSKeyedArchiver archivedDataWithRootObject:NSColor.blackColor requiringSecureCoding:false error:&error],@"cueIdBgColor",
        [NSKeyedArchiver archivedDataWithRootObject:NSColor.blackColor requiringSecureCoding:false error:&error],@"textBgColor",
        [NSKeyedArchiver archivedDataWithRootObject:NSColor.blackColor requiringSecureCoding:false error:&error],@"progressBarBgColor",
        [NSKeyedArchiver archivedDataWithRootObject:NSColor.greenColor requiringSecureCoding:false error:&error],@"rehearseColor",
        [NSKeyedArchiver archivedDataWithRootObject:NSColor.redColor requiringSecureCoding:false error:&error],@"recordColor",
        [NSKeyedArchiver archivedDataWithRootObject:NSColor.blueColor requiringSecureCoding:false error:&error],@"playbackColor",
        [NSKeyedArchiver archivedDataWithRootObject:NSColor.whiteColor requiringSecureCoding:false error:&error],@"cueIdColor",
        [NSKeyedArchiver archivedDataWithRootObject:NSColor.whiteColor requiringSecureCoding:false error:&error],@"textColor",
        [NSKeyedArchiver archivedDataWithRootObject:NSColor.whiteColor requiringSecureCoding:false error:&error],@"progressBarColor",
        nil];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:registrationDefaults];
    
    // temp set remote editor dial to 0dB, unmute
    [[NSUserDefaults standardUserDefaults] setInteger:104 forKey:@"DialValueKey_107"];
    [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"DialMuteKey_107"];

    _showArmedOneshot = [[NSTimer alloc]init];
    
    _lastRecordTrack = 0;   // so that we do show something before the first record pass
    _suggestedTrackName = @"";
    _lastCueID = @"";
    [self setSession:@""];
    
    
//    _cueCounter = 0;    // count cues entered manually
    _tcc = [[TcCalculator alloc] init]; _tcc.delegate = self;
    _tcf = [[TCFormatter alloc] init];
    
    //    _currentWindow = WINDOW_OFF;    // no window selected
    
    //    NSLog(@"applicationDidFinishLaunching");
    //    tcc = [[TcCalculator alloc] init];
//    keybdChars = [[NSMutableArray alloc] init];
    _streamerWindowController = nil;
    _matrixWindowController = nil;
//    eventChars = @"";
//    eventArray = [[NSMutableArray alloc] init];
    //    _lastCycleType = -1;
    
    //    _midiClient = [[MidiClient alloc] init];    // sets the delegate in 'init'
    //    [_midiClient setDelegate:(id)self];
    // V1.00.18 MTC output is a relay of MTC input
//    _mtcClient = [[MidiClient alloc] initWithTitle:@"MTC" :IN_AND_OUT]; 
    _mtcClient = [[MtcMidi alloc] init];// finds or adds a menu, sets delegate to [NSApp delegate]
    [_mtcClient setMtcMidiDelegate:(id<MtcMidiDelegate> _Nullable)self];
//    _mtcHui = [[MidiHui alloc]init];
//    [_mtcClient setCommandDecoder:_mtcHui];
//    [_mtcHui setMtcDelegate:self];
    
    _ptClient = [[MidiClient alloc] initWithTitle:@"Protools" :IN_AND_OUT];
    _ptHui = [[MidiHui alloc]init];
    [_ptClient setCommandDecoder:_ptHui];
    [_ptHui setDelegate:self];
    
    _lpMini = [[LpMini alloc] init:self];   // 2 LP mini heads, 1 accessory
    // statusClient
    
    _statusClient = [[StatusMidi alloc]init];
    _control1Client = [[ControlMidi alloc]init:@"Control 1" ];
    _control2Client = [[ControlMidi alloc]init:@"Control 2" ];
//    _remoteClient = [[RemoteMidi alloc]init];
    
    // V1.00.17
    // all tx to VM15A-MADI is in MatrixView.m
    // see 'delegate tx' instances, we have txMsg (gains) and txChunk (crosspoint on/off)
    // review how sliders get to VM15A-MADI
    _ufxClient = [[MidiClient alloc] initWithTitle:@"UFX" :OUT_ONLY];   // is it really out only?

    _xKey = [[XKey alloc] init];
    
    //    _safetyRecorderClient = [[SafetyRecorderClient alloc]init];
    
    [self onAdrClientWindow:nil];   // first because we want a debug log available
    [self onOverlayWindow:nil];    // CAAnimation streamers, text. Must be first, gets messages
    [self onStreamerWindow:nil];    // before onMonitorWindow so reh/rec/pb colors are set
    [self onMonitorWindow:nil];
    [self onAudioPlayerWindow:nil]; // start the osaScript thread
    
    // 04/03/24 instantiate dial midi window, don't show it though
    [self OnDialMidiWindow:nil];    // where the dial MIDI lives
    [_dialMidiWindowController.window miniaturize:nil];
    
    _loopMidi = [[LoopMidi alloc]init]; // MIDI loop throughs for Evan
    
    [_overlayWindowController sizeToCurrentScreen]; // why do we need this? but we do.
    [_overlayWindowController deactivateWindow];
    
    //    _textWindowClient = [[TextWindowClient alloc]init];     // v1.00.23, after overlay window is opened
//    _boomRecorderClient = [[BoomRecorderClient alloc]init];
    
    [_adrClientWindowController setDelegate:self];  // not used by AleDoc, used by AleMini
    
    // clear the text windows
    _overlayWindowController.viewController.cueIdTextView.text = @"";
    _overlayWindowController.viewController.textView.text = @"";
    _overlayWindowController.viewController.progressTextView.text = @"";
    
    //    // get the keys first, intercept controller keyboard commands, dispatch from here
    //    //http://stackoverflow.com/questions/6139751/objective-c-listen-to-keyboard-shortcuts-and-act-on-them
    //    [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask
    //                                          handler:monitorHandler];
    
    // PIE keyboard service
    //http://stackoverflow.com/questions/6139751/objective-c-listen-to-keyboard-shortcuts-and-act-on-them
//    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskApplicationDefined
//                                          handler:monitorHandlerPIE];
    
    [self initJumpTables];
    
    // v1.00.23 oscServer
    _oscServer = [[OscServer alloc]init:self];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(appTerminating:)
     name:NSApplicationWillTerminateNotification
     object:nil ];
    
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector (didChangeScreenParameters:)
                                                 name: NSApplicationDidChangeScreenParametersNotification object: nil];
    
    // open editor window last so that editor/doc/matrix windows stack on the right side the first time we open
    [self setAppLaunchedTimer:[NSTimer scheduledTimerWithTimeInterval:0.5 target: self selector:@selector(appLaunchedTimerService) userInfo:nil repeats: NO]];
    
    // 2.00.00 add observers for feedback to Companion
    
    // a dictionary of checkbox items
    // key : [unitID, switchNumber]
    setLEDForUnitIDDictionary = @{
        @"enPunch": @[@9,@43]
        ,@"enBeeps": @[@9,@44]
        ,@"enStreamer": @[@9,@42]
        ,@"inhibitStreamerInPlayback": @[@9,@45]
//        ,@"enBlackCueBlack": @[@9,@36]
//        ,@"useAltGuideInRecord": @[@9,@46]
        ,@"linkCompAndPbRouting": @[@9,@40]
        ,@"enInPastSwitching": @[@9,@37]
        ,@"show16Tracks": @[@9,@34]
        ,@"dialogInClipName": @[@9,@67]
        ,@"notesInClipName": @[@9,@68]
        ,@"characterInTrackName": @[@9,@69]
        ,@"captureFirstLineInRehearse" : @[@9,@76]
        ,@"showAllCols" : @[@9,@79]
        ,@"useAnnunciatorColor" : @[@9,@80]
        ,@"snoopAuto" : @[@9,@81]
        ,@"cueIdInSlate" : @[@9,@82]
        ,@"DialMuteKey_103" : @[@9,@77]
        ,@"linkRemoteActor" : @[@9,@111]
        ,@"linkRemoteEditor" : @[@9,@112]
        ,@"boomRecOnlineLocal" : @[@9,@113]
        ,@"boomRecOnlineRemote" : @[@9,@114]
    };
      
    // add observers for checkbox changes
    for(NSString *key in [setLEDForUnitIDDictionary allKeys]){
        
        [[NSUserDefaults standardUserDefaults] addObserver:self
                                                forKeyPath:key
                                                   options:NSKeyValueObservingOptionNew
                                                   context:NULL];
    }
    // 12/07/23 other observers
    NSArray *otherKeys = @[@"motionZoneByte"];
    
    for(NSString *key in otherKeys){
        
        [[NSUserDefaults standardUserDefaults] addObserver:self
                                                forKeyPath:key
                                                   options:NSKeyValueObservingOptionNew
                                                   context:NULL];

    }
    // after setting observer
    self.snoopAuto = true;  // start with snoop auto on

    bool isFirstRun = [[NSUserDefaults standardUserDefaults] boolForKey:@"isFirstRun"];
    
    if(isFirstRun){
        [_matrixWindowController onLoadDefaults: self];
        // TODO; any thing else that needs to be set the first time

        [[NSUserDefaults standardUserDefaults]setBool:false forKey:@"isFirstRun"];
        
    }
    
    self.snoopState = SNOOP_STATE_FORCE_ON;   // PT has to be present for this to set, see decodeMotionZoneByte()
    
    [self setCycleMotion:CYCLE_MODE_IDLE];  // turn off the button 2.10.02
    
    [self getSession:nil];  // case where PT is present when we open
        
    // https://github.com/apple/swift-corelibs-foundation/issues/4162
    // debugging the intermittent crash v2.10.02, 08/09/23
//    NSThread *thread = [NSThread currentThread];
//    NSInteger threadNumber = [[thread valueForKeyPath:@"private.seqNum"] integerValue];
//    NSLog(@"main thread number: %ld",threadNumber); // the thread that crashes is 1, the main thread.
        
}
// MARK: ------------ observeValueForKeyPath ---------------

NSDictionary *setLEDForUnitIDDictionary;    // checkbox items, send state of checkbox

-(void)initCompanionLeds{
    
    // checkbox states to companion
    
    for(NSString *keyPath in [setLEDForUnitIDDictionary allKeys]){
        
        NSArray *array;
        
        array = (NSArray*)setLEDForUnitIDDictionary[keyPath];
        int unit = [(NSNumber*)array[0] intValue];
        int keyNumber = [(NSNumber*)array[1] intValue];
        
        //        NSLog(@"setLEDForUnitIDDictionary %@",keyPath);
        bool state = [[NSUserDefaults standardUserDefaults] boolForKey:keyPath];
        [self setLEDForUnitID:unit :keyNumber :state]; // 1.00.23
        
    }
    
    [self deleteStreamers:nil];     // clear streamers 2.10.02
    
    // init dial text and values
    // turn off video delay (muted is off)
    [[NSUserDefaults standardUserDefaults]setBool:true forKey:@"DialMuteKey_103"];
    
    for(NSString * key in [dialDictionary allKeys]){
        [self sendDial:key];    // init messages
    }
    
    _matrixWindowController.muteAll = false;    // set OSC mute indicator
}
/*
 setLEDForUnitIDDictionary = @{
 @"enPunch": @[@9,@43]
 ,@"enBeeps": @[@9,@44]
 ,@"enStreamer": @[@9,@42]
 ,@"inhibitStreamerInPlayback": @[@9,@45]
 ,@"enBlackCueBlack": @[@9,@36]
 ,@"useAltGuideInRecord": @[@9,@46]
 };
 */
NSTimer *motionZoneByteTimer;
-(void)motionZoneByteTimerService{
    
    self.snoopState = SNOOP_STATE_ON;
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context{
    
//  moved from showTcDigits:, using observer approach for snoopAuto
    if([keyPath isEqualToString:@"snoopAuto"] || [keyPath isEqualToString:@"motionZoneByte"]){
        
        bool snoopAuto = [[NSUserDefaults standardUserDefaults] boolForKey:@"snoopAuto"];
        NSInteger motionZoneByte = [[NSUserDefaults standardUserDefaults] integerForKey:@"motionZoneByte"];
        
        if(motionZoneByteTimer){
            [motionZoneByteTimer invalidate];
        }
        
        // reduce messages to ufx by timing out on STOP
        if(snoopAuto && (motionZoneByte & 0x30) == 0x30){
            self.snoopState = SNOOP_STATE_OFF;
        }else if(snoopAuto && motionZoneByte == 0x8){
            motionZoneByteTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target: self selector:@selector(motionZoneByteTimerService) userInfo:nil repeats: false];
            
        }
    }
    
    if(setLEDForUnitIDDictionary[keyPath]){
        
        NSArray *array;
        
        array = (NSArray*)setLEDForUnitIDDictionary[keyPath];
        int unit = [(NSNumber*)array[0] intValue];
        int keyNumber = [(NSNumber*)array[1] intValue];
        
        bool state = [[NSUserDefaults standardUserDefaults] boolForKey:keyPath];
//        NSLog(@"setLEDForUnitIDDictionary %@ %d",keyPath,state);
        [self setLEDForUnitID:unit :keyNumber :state]; // 1.00.23
        
        // special cases
        if([keyPath isEqualToString:@"enInPastSwitching"] ||
           [keyPath isEqualToString:@"showAllCols"]){
            
            // topdocument
            Document *doc = [self topDocument];
            [doc sizeTableViewToContents];  // show/hide end tc
            
        }
        if([keyPath isEqualToString:@"DialMuteKey_103"]){
            // puts 'show delay' on the pot button
            if(state){
                [_videoDelayWindowController.window close];
                
            }else{
                [self onVideoDelayWindow:self];
            }

        }
        
        return;
    }
//    if([keyPath isEqualToString:@"beepsTrimFrames"]){
//
//        NSInteger beepsTrimFrames = [[NSUserDefaults standardUserDefaults] integerForKey:@"beepsTrimFrames"];
//        [self txOsc:[NSString stringWithFormat:@"beepsTrim %ld",beepsTrimFrames]];
//        [_xKey setLEDForUnitID:8 :18+80 : beepsTrimFrames < 0]; // BEEPS ARE OFFSET
//        [_xKey setLEDForUnitID:8 :26+80 : beepsTrimFrames > 0]; // BEEPS ARE
////        [self setTrimLeds]; // TODO: 2.00.00 ???
////        [self setDocLEDs];  // TODO: 2.00.00 ???
//
//    }
}

-(void)appLaunchedTimerService{
    
    [self onEditorWindow:nil];
    
}
-(void) didChangeScreenParameters:(NSNotification *)notification{
    
    NSLog(@"NSApplicationDidChangeScreenParametersNotification");
    
    [self onEditorWindow:nil];  // move to widest screen
    
}

-(void)appTerminating:(NSNotification *) notification{
    
    // tell the streamer and MADI box 'bye' so that they are available for telnet right away
    
//    [_streamerWindowController txMsg:@"bye"];
//    [_matrixWindowController txMsg:@"bye"];
}

-(NSArray*)getDocWindows{
    
    NSMutableArray *docWindows = [[NSMutableArray alloc] init];
    
    for (NSWindow *window in [NSApp windows] ){
        
        
        if(window && [window isKindOfClass:[DocWindow class]]){
            
            [docWindows addObject:window];  // collect open documents
            
        }
    }
    
    return docWindows;
    
}
-(Document*)topDocument{
    
    NSWindowNumberListOptions options = NSWindowNumberListAllSpaces;
    NSArray *windowNumbers = [NSWindow windowNumbersWithOptions:options];
    
    NSArray *docWindows = [self getDocWindows];
    
    for(NSNumber *windowNumber in windowNumbers){   // windows in z-order, front to back
        
        for(DocWindow *docWindow in docWindows){
            
            if(docWindow.windowNumber == [windowNumber integerValue]){
                
                return (Document*)[docWindow delegate]; // the top-most document
                
            }
            
        }
        
    }
    
    return nil; // no document found
    
}
-(void)previousCue{
    
    // it takes too long to check the front window, don't  do it here
    
//    [_editorWindowController setPrerollToHere:nil];
    //    [self setStartFromPrerollTc:nil];
    Document *doc = [self topDocument];
    if(doc) [doc previousCue];
    self.prerollIndex = self.prerollIndex;  // reset from 'preroll to here'
    
}
-(void)nextCue{
    
    // it takes too long to check the front window, don't  do it here

//    [self setStartFromPrerollTc:nil];
    Document *doc = [self topDocument];
    if(doc)[doc nextCue];
    self.prerollIndex = self.prerollIndex;  // reset from 'preroll to here'

}
-(void)unmergeCue{
    
    Document *doc = [self topDocument];
    
    if(doc)[doc unmergeCue];
    
    
}
-(void)mergeNextCue{
    
    Document *doc = [self topDocument];
    
    if(doc)[doc mergeNextCue];
    
}
-(void)rehearseMode{
        
    switch(self.cycleMotion){
            
//        case CYCLE_MOTION_ACTIVE:
//        case CYCLE_MOTION_STARTING:
        case CYCLE_MOTION_STOPPING:
            [_ptHui onStop];
//            self.cycleMotion = CYCLE_MOTION_PENDING;
            [_matrixWindowController setRehRecPb:MODE_CONTROL_REHEARSE_PENDING];
            break;
        case CYCLE_MOTION_PENDING:
            [_matrixWindowController setRehRecPb:MODE_CONTROL_REHEARSE_PENDING];
            break;
        case CYCLE_MOTION_IDLE:
            self.cycleMode = CYCLE_MODE_IDLE;
            [_matrixWindowController setRehRecPb:MODE_CONTROL_REHEARSE]; // 2.10.02 too many of these
            break;
        default:
            NSLog(@"MODE_CONTROL_REHEARSE failed to set, cycleMotion %ld",_cycleMotion);
            break;
            
    }
}
-(void)recordMode{

    switch(self.cycleMotion){
            
//        case CYCLE_MOTION_ACTIVE:
//        case CYCLE_MOTION_STARTING:
        case CYCLE_MOTION_STOPPING:
            [_ptHui onStop];
//            self.cycleMotion = CYCLE_MOTION_PENDING;
            [_matrixWindowController setRehRecPb:MODE_CONTROL_RECORD_PENDING];
            break;
        case CYCLE_MOTION_PENDING:
            [_matrixWindowController setRehRecPb:MODE_CONTROL_RECORD_PENDING];
            break;
        case CYCLE_MOTION_IDLE:
            [_matrixWindowController setRehRecPb:MODE_CONTROL_RECORD];
            break;
        default:
            NSLog(@"MODE_CONTROL_RECORD failed to set, cycleMotion %ld",_cycleMotion);
            break;
            
    }
}
-(void)playbackMode{
    
    switch(self.cycleMotion){
            
//        case CYCLE_MOTION_ACTIVE:
//        case CYCLE_MOTION_STARTING:
        case CYCLE_MOTION_STOPPING:
            [_ptHui onStop];
//            self.cycleMotion = CYCLE_MOTION_PENDING;
            [_matrixWindowController setRehRecPb:MODE_CONTROL_PLAYBACK_PENDING];
            break;
        case CYCLE_MOTION_PENDING:
            [_matrixWindowController setRehRecPb:MODE_CONTROL_PLAYBACK_PENDING];
            break;
        case CYCLE_MOTION_IDLE:
            self.cycleMode = CYCLE_MODE_IDLE;
            [_matrixWindowController setRehRecPb:MODE_CONTROL_PLAYBACK];
            break;
        default:
            NSLog(@"MODE_CONTROL_PLAYBACK failed to set, cycleMotion %ld",_cycleMotion);
            break;
            
    }
}
-(void)dialogInClipName{
    
    NSInteger state = ![[NSUserDefaults standardUserDefaults] integerForKey:@"dialogInClipName"];
    
    [[NSUserDefaults standardUserDefaults] setInteger:state forKey:@"dialogInClipName"];
    
}
-(void)notesInClipName{
    
    NSInteger state = ![[NSUserDefaults standardUserDefaults] integerForKey:@"notesInClipName"];
    
    [[NSUserDefaults standardUserDefaults] setInteger:state forKey:@"notesInClipName"];
}
-(void)characterInTrackName{
    
    NSInteger state = ![[NSUserDefaults standardUserDefaults] integerForKey:@"characterInTrackName"];
    
    [[NSUserDefaults standardUserDefaults] setInteger:state forKey:@"characterInTrackName"];
}
-(void)cycleButton{
    
    NSLog(@"cycleButton");
    [_matrixWindowController setMemoryTag:0]; // memory zero
    
    if(_matrixWindowController.protoolsAnnunciator.state != NSControlStateValueOn){
        
        [self alertErr:@"ProTools isn't running" :@""];

        return;

    }
    // check for MIDI, put up an alert if not connected
    if(_matrixWindowController.midiAnnunciator.state!= NSControlStateValueOn){
        
        [self alertErr:@"Protools MIDI not connected" :@""];
        return;

    }
    
//    if(self.cycleMotion != CYCLE_MOTION_IDLE){
//        [_matrixWindowController setRehRecPb:MODE_CONTROL_REHEARSE];
//
//    }
    
    // FIXME: before the loop, don't finalize record
    if(self.cycleMode == CYCLE_MODE_RECORD){
        self.cycleMode = CYCLE_MODE_SKIP_PASTE;
    }

    Document *doc = [self topDocument];

    if(!doc.recordCycleDictionary){
        
        [self alertErr:@"No cue selected" :@""];
        return;
    }
    
    if(doc.recordCycleDictionaryState == RECORD_CYCLE_DICTIONARY_ACTIVE){
        // setup for a new recordCycleDictionary is in progress, wait for it to complete
        self.cycleMotion = CYCLE_MOTION_PENDING;
        return;
        
    }

    // 10/11/22 a state machine that ignores button pushes for in-between states
    [_ptHui onStop];
    [_overlayWindowController.viewController.streamer cancelAllStreamers];
    
    // 01/30/24 refresh Osc REH REC PB, might be in Evan's video switching state
    [self txOsc:[NSString stringWithFormat:@"rehRecPb %d",_matrixWindowController.rehRecPb]];

    switch(_cycleMotion){
        case CYCLE_MOTION_IDLE:
            // put overlays in front of PT
            [self onDocumentWindow:nil];
//            [NSApp activateIgnoringOtherApps:true];
//            [_overlayWindowController.viewController bringToFront];
            
            _overlayWindowController.viewController.annunciatorTextView.fadeDuration = 0.1; // Fast fade in
            _overlayWindowController.viewController.annunciatorTextView.opacity = 1.0;
            switch(_matrixWindowController.rehRecPb){
                case MODE_CONTROL_REHEARSE:
                    _overlayWindowController.viewController.annunciatorTextView.text = @"Rehearse";
                    break;
                case MODE_CONTROL_RECORD:
                    _overlayWindowController.viewController.annunciatorTextView.text = @"Record";
                    break;
                case MODE_CONTROL_PLAYBACK:
                    _overlayWindowController.viewController.annunciatorTextView.text = @"Playback";
                    break;
            }
            self.cycleMotion = CYCLE_MOTION_STARTING;
//            [_matrixWindowController.matrixView autoSlate];
            break;
        case CYCLE_MOTION_ACTIVE:
            self.cycleMotion = CYCLE_MOTION_STOPPING;
            break;
        case CYCLE_MOTION_STARTING: // really fast double push
        case CYCLE_MOTION_PENDING:  // cancels a pending cycle
            _overlayWindowController.viewController.annunciatorTextView.fadeDuration = 0.1; // Fast fade in
            _overlayWindowController.viewController.annunciatorTextView.opacity = 1.0;
            _cycleMotion = CYCLE_MOTION_IDLE;       // no pending->idle action
            self.cycleMotion = CYCLE_MOTION_IDLE;   // to display the button
            break;
        case CYCLE_MOTION_STOPPING:
            self.cycleMotion = CYCLE_MOTION_PENDING;
            switch(_matrixWindowController.rehRecPb){
                case MODE_CONTROL_REHEARSE:
                    _matrixWindowController.rehRecPb = MODE_CONTROL_REHEARSE_PENDING;
                    break;
                case MODE_CONTROL_RECORD:
                    _matrixWindowController.rehRecPb = MODE_CONTROL_RECORD_PENDING;
                    break;
                case MODE_CONTROL_PLAYBACK:
                    _matrixWindowController.rehRecPb = MODE_CONTROL_PLAYBACK_PENDING;
                    break;
            }
            break;
        default:
            break;
    }
}
-(void)renameLastTrack{
    
    Document *doc = [self topDocument];
    
    NSString *cueID = [doc cueIDForDictionary];
    NSString *character = [doc actorForDictionary];

    if(doc.characterInTrackName) cueID = [NSString stringWithFormat:@"%@ %@",character,cueID];  // 2.00.00 ' '
    // maybe add some extra text to the cue ID
    NSString *nameNote = [_editorWindowController nameNote];
    NSInteger beforeAfterTag = [_editorWindowController beforeAfterTag];
    
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
    
    // always call renameLastTrack, it checks for name not changing
    // otherwise you can manually change the name to some bogus value
    [_adrClientWindowController txMsg:[NSString stringWithFormat:@"jxaRenameLastTrack\t0\t%@\t%@",nameNote,_suggestedTrackName]];
    [self setLastCueID:nameNote];

}
-(void)cueToCycleStart{
    
    if(self.cycleMotion != CYCLE_MOTION_IDLE){
        switch(_streamerWindowController.pictureTag){
            case TAG_ALWAYS_ON:
                [_overlayWindowController.viewController.streamer fadeToBlack:false :_streamerWindowController.fadeSeconds];
                break;
            case TAG_FADE_IN:
            case TAG_BLACK_CUE_BLACK:
                if(![_ptHui isPlay]){
                    
                    [_overlayWindowController.viewController.streamer fadeToBlack:true :_streamerWindowController.fadeSeconds];

                }
                break;
            default: break;
        }
    }
    // when a new cue is selected, we are in CYCLE_MOTION_IDLE, don't fade to black
//    if(self.cycleMotion != CYCLE_MOTION_IDLE){
//        [_overlayWindowController.viewController.streamer fadeToBlack:true :0.0];
//    }

    Document *doc = [self topDocument];
    
    if(!doc.recordCycleDictionary){
        return; // nothing to cycle
    }

    [self selectCurrentSixteenTrackMemory]; // moved from record part of case statement
    
    [_adrClientWindowController txMsg:@"prerollOff"]; // turn off PT preroll
    
    NSString *preroll = [_editorWindowController preroll];
    NSString *start = doc.startForDictionary;  // can be ft/fr
    
    start = [_tcc subtractTc:preroll fromTc:start withType:self.getTcType];
    
    [self locate:start : @"2"];    // sends 'getProtoolsPosition 2'

}
-(void)cycleStart{
    
    Document *doc = [self topDocument];
    doc.recordCycleDictionaryState = RECORD_CYCLE_DICTIONARY_IDLE;    // this blocks cycle button

    // TODO: 2.00.00 cycleStart
    if(_cycleMotion != CYCLE_MOTION_STARTING){
        self.cycleMotion = CYCLE_MOTION_IDLE;
        return; // not the right state to start a cycle
    }
    
    // set monitor to AHEAD
    _matrixWindowController.aheadInPast = MODE_AHEAD;   //

    switch (_matrixWindowController.rehRecPb) {
            
        case MODE_CONTROL_RECORD:
            
            [self renameLastTrack]; // rename on record cycle
            //[_adrClientWindowController txMsg:@"armLastTrack"]; // 2.00.00 start sequencer
            
            break;
            
        default:
            
            [_ptHui onPlay];
            
            break;
    }

    
}
-(void)incrementCurrentTrack{
    
    [self setCurrentTrack:([self currentTrack] + 1)];
    
}
-(void)decrementRecordTake{
    
    Document *doc = self.topDocument;
    
    if(doc == nil || !doc.recordCycleDictionary) return;
    //    NSLog(@"decrementRecordTake");
    
    NSString *take = [self.topDocument.recordCycleDictionary objectForKey:@"Take"];
    NSInteger takeNumber = 1;
    
    if(!take){
        take = @"1";    // actually is 1, we incremented from 0
        [doc.recordCycleDictionary setObject:take forKey:@"Take"]; //NSLog(@"KEY  0");
    }else{
        
        @try {
            takeNumber = [take integerValue];
        }
        @catch (NSException *exception) {
            
            for(int i = 0; i < take.length; i++){
                
                unichar aChar = [take characterAtIndex:i];
                NSLog(@"0x%x",aChar);
            }
            
        }
        
        take = [NSString stringWithFormat:@"%ld",takeNumber - 1]; //NSLog(@"incremented take number:%@",take);
        if(take < 0)take = 0;
        [doc.recordCycleDictionary setObject:take forKey:@"Take"]; //NSLog(@"KEY  1");
    }
    
    [doc sendTakeToStreamerForDictionary];
    
}

-(void)incrementRecordTake{
  
    Document *doc = self.topDocument;

    if(doc == nil || !doc.recordCycleDictionary) return;
    
    NSString *take = [doc.recordCycleDictionary objectForKey:@"Take"];
    NSInteger takeNumber = 1;
    
    if(!take){
        take = @"1";    // actually is 1, we incremented from 0
        [doc.recordCycleDictionary setObject:take forKey:@"Take"]; //NSLog(@"KEY  2");
    }else{
        
        @try {
            takeNumber = [take integerValue];
        }
        @catch (NSException *exception) {
            
            for(int i = 0; i < take.length; i++){
                
                unichar aChar = [take characterAtIndex:i];
                NSLog(@"0x%x",aChar);
            }
            
        }
        
        take = [NSString stringWithFormat:@"%ld",takeNumber + 1]; //NSLog(@"incremented take number:%@",take);
        [doc.recordCycleDictionary setObject:take forKey:@"Take"];
    }
}
-(void)incrementRecordTrack{
    
    Document *doc = self.topDocument;

    if(doc == nil || !doc.recordCycleDictionary) return;

    NSString *track = [doc.recordCycleDictionary objectForKey:@"Track"];
    
    if(!track){
        track = @"1";
        [doc.recordCycleDictionary setObject:track forKey:@"Track"];
        [self setCurrentTrack:0]; // the string is +1
        
    }else{
        
        NSInteger trackNumber = [track integerValue];
        [self setCurrentTrack:trackNumber]; // here because the string is +1
        
        trackNumber %= 32;
        trackNumber++;
        track = [NSString stringWithFormat:@"%ld",trackNumber];
        [doc.recordCycleDictionary setObject:track forKey:@"Track"];
    }
    [doc.tableView reloadData];

}
-(void)skipCutAndPaste{
    
    [_ptHui onStop];
    
    switch(_cycleMode){
            
        case CYCLE_MODE_RECORD_KEEP_TAKE:   // in the loop
        case CYCLE_MODE_RECORD: // before the loop
            self.cycleMode = CYCLE_MODE_SKIP_PASTE;
//            [_matrixWindowController setRehRecPb:MODE_CONTROL_REHEARSE];    // paranoia, can't hurt
            break;
        default:
            break;
            
    }
}
-(void)playStop{
    
    [self showWindows];     // unhide windows maybe
    
    if(self.cycleMotion != CYCLE_MOTION_IDLE){
//        [_matrixWindowController setRehRecPb:MODE_CONTROL_REHEARSE];

        // FIXME: before the loop, don't finalize record
        if(self.cycleMode == CYCLE_MODE_RECORD){
            self.cycleMode = CYCLE_MODE_SKIP_PASTE;
        }
        
        [self cycleButton];
    }else{
        
        [_adrClientWindowController txMsg:@"keyCode 49"];   // space bar
        [_overlayWindowController.viewController.streamer cancelAllStreamers];
    }
}
-(void)trimBeeps:(NSInteger)trim{
    
    Document *doc = [self topDocument];
    
    if(doc) [doc trimBeeps:trim];
    
}
-(void)toggleStreamer{
    
    _streamerWindowController.streamerEnable = !_streamerWindowController.streamerEnable;
    
}
-(void)togglePunch{
    _streamerWindowController.punchEnable = !_streamerWindowController.punchEnable;
    
}
-(void)toggleBeeps{
    
    _streamerWindowController.beepsEnable = !_streamerWindowController.beepsEnable;
    
}
// toggleInhibitStreamerInPlayback
-(void)toggleInhibitStreamerInPlayback{
    
    _streamerWindowController.inhibitStreamerInPlayback = !_streamerWindowController.inhibitStreamerInPlayback;
    
}
//
//-(void)toggleUseAltGuideInRecord{
//
//    _matrixWindowController.useAltGuideInRecord = !_matrixWindowController.useAltGuideInRecord;
//
//
//}
#pragma mark -
#pragma mark --------------- actions ----------------------

- (IBAction)onAltGuide:(id)sender {
    // when the preference checkbox is toggled, audio follows
    [_matrixWindowController refreshGuide];
}

#pragma mark -
#pragma mark --------------- monitor matrix xkey routines ----------------------
-(void)setLEDForUnitID:(int)unitID :(int)index :(bool)on{
    
    // companion indicators
    [self txOsc:[NSString stringWithFormat:@"led %d,%d,%@",unitID,index, (on ? @"true" : @"false")]];
}
//-(void)setMemoryLED{
//    
//    // TODO:  2.00.00 setMemoryLED
//    if(_matrixWindowController){
//        
//        int memoryTag = (int)[_matrixWindowController memoryTag];
//        [self setLEDForUnitID:2 :3 :0 == memoryTag];
//        [self setLEDForUnitID:2 :4 :2 == memoryTag];
//        [self setLEDForUnitID:2 :11 :1 == memoryTag];
//        [self setLEDForUnitID:2 :12 :3 == memoryTag];
//        
//    }
//    
//}
//-(void)setDocLEDs{
//
//    Document *doc = [self topDocument];
////    if(doc){
////
////        [self setLEDForUnitID:8 :2+80 : doc.recordToComposite]; // recordToComposite
////
////        bool hidePix = _overlayWindowController.viewController.streamer.hidePix;
////        [self setLEDForUnitID:8 :10+80 : hidePix]; // PIX SHOW HIDE
////
////        NSInteger beepsTrimFrames = [[NSUserDefaults standardUserDefaults] integerForKey:@"beepsTrimFrames"];
////        [self setLEDForUnitID:8 :18+80 : beepsTrimFrames < 0]; // BEEPS ARE OFFSET
////        [self setLEDForUnitID:8 :26+80 : beepsTrimFrames > 0]; // BEEPS ARE OFFSET
////        [self setLEDForUnitID:9 :32 : doc.recordToComposite]; // recordToComposite
////
////    }
//    // items that don't need doc
//
//    Byte trigger[] = {0x90,124,64};
//    //     Comp Track "armed": Note #69
//    trigger[1] = 69;
//    trigger[2] = doc.recordToComposite ? 127 : 0;
//    [_ptClient midiTx:[NSData dataWithBytes:trigger length:3]];
//    //    [_midiClient txMidi:[NSData dataWithBytes:trigger length:3]];
//
//}
-(void)set16TrackLED{
    [self setLEDForUnitID:1 :49 :[_matrixWindowController show16Tracks]];
    [self setLEDForUnitID:8 :62 :[_matrixWindowController show16Tracks]];
    [self setLEDForUnitID:9 :34 :[_matrixWindowController show16Tracks]];
    
}
-(void)initUnit_8_LEDs{
    
    //    [self setTrackLEDs];
    //    [self setRehRecPbLEDs];
//    [self showFmtLEDs];
//    [self setDocLEDs];
    [self set16TrackLED];
    self.prerollIndex = self.prerollIndex;  // sends to heads
    
    // you  don't know the order of the heads connecting, set LEDs in both inits
    Document *doc = [self topDocument];
    doc.recordToComposite = doc.recordToComposite;  // 2.10.02 init XKEY LED, sets unit 8 and 9
    _overlayWindowController.viewController.streamer.hidePix = _overlayWindowController.viewController.streamer.hidePix;    // 2.10.02 init XKEY LED, sets unit 8 and 9
//    [self setPrerollLEDs:_editorWindowController.preroll];
    
}
-(void)initUnit_9_LEDs{
    // companion initialization of non-KVO unit 9 items

    [self txOsc:[NSString stringWithFormat:@"Track %ld",_currentTrack + 1]];    // track selector

    [self txOsc:[NSString stringWithFormat:@"rehRecPb %d",[_matrixWindowController rehRecPb]]];    // mode
    [self txOsc:[NSString stringWithFormat:@"aheadInPast %d",[_matrixWindowController aheadInPast]]];
    _matrixWindowController.sampleRateTag = _matrixWindowController.sampleRateTag;  // set indicators
    _matrixWindowController.numRecTracksTag = _matrixWindowController.numRecTracksTag; // set indicators
    self.cueIdInSlate = self.cueIdInSlate;
    
    // you  don't know the order of the heads connecting, set LEDs in both inits
    Document *doc = [self topDocument];
    doc.recordToComposite = doc.recordToComposite;  // 2.10.02 init XKEY LED, sets unit 8 and 9
    doc.beepsTrimFrames = doc.beepsTrimFrames;// 2.10.02 init
    _overlayWindowController.viewController.streamer.hidePix = _overlayWindowController.viewController.streamer.hidePix;
    
    // did not work earlier in this routine, keep this here
    NSInteger beepsTrimFrames = [[NSUserDefaults standardUserDefaults] integerForKey:@"beepsTrimFrames"];
    [self txOsc:[NSString stringWithFormat:@"beepsTrim %ld",beepsTrimFrames]];
    
    _streamerWindowController.pictureTag = _streamerWindowController.pictureTag;    //2.10.02
    
    [self dialMidiRefresh];
    
}
-(void)stopAndCancelModes{
    // if you have to do this, fix the offending logic that got you here
    [_ptHui onStop];
    [_overlayWindowController.viewController.streamer cancelAllStreamers];
    _cycleMode = CYCLE_MODE_IDLE;       // don't call setCycleMode, no sequencing
    _cycleMotion = CYCLE_MOTION_IDLE;   // don't call setCycleMotion, no sequencing
    _matrixWindowController.rehRecPb = MODE_CONTROL_REHEARSE;
    
    [self sendMidiToClosure];   // 1.00.12
    [self setLEDForUnitID:8 :46 :_cycleMotion]; // set StreamDeck indicator

}
-(void)triggerStreamerCompanion:(NSEvent*)event{
    // 2.00.00 trigger streamer from StreamDeck
    NSColor *color = _streamerWindowController.streamerColor;
    
//    [_overlayWindowController.viewController.streamer triggerStreamer:color];
    [_overlayWindowController triggerStreamer:color];
}
-(void)pictureMode:(NSEvent*)event{
    
    NSInteger keyNumber = event.data1;
    
    [_streamerWindowController setPictureTag:keyNumber - 70];
}
-(void)showAllCols{
    
    Document *doc = ((AleDelegate*)NSApp.delegate).topDocument;
    
    if(doc){
        doc.showAllCols = !doc.showAllCols;
    }
    
}
-(void)useAnnunciatorColor{
    
    bool useAnnunciatorColor = [[NSUserDefaults standardUserDefaults] boolForKey:@"useAnnunciatorColor"];
    [[NSUserDefaults standardUserDefaults]setBool:!useAnnunciatorColor forKey:@"useAnnunciatorColor"];
    
}
// MARK: ----------- readLog -----------
-(void)readLog{
    
    // read the log for all open document windows
    // we do this because it is possible to have an empty document in front,
    // and we want to read the log for the window behind
    for (NSWindow *window in [NSApp windows] ){
        
        if(window && [window isKindOfClass:[DocWindow class]]){
            Document *doc = (Document*)[window delegate];
            [doc readLog];

        }
    }
}

// MARK: ------------ video rec delay routines -------------
- (IBAction)onVideoDelayHotKey:(id)sender {
    
    NSEvent *newEvent = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
                            location:NSMakePoint(0, 0)
                            modifierFlags:0
                            timestamp:0
                            windowNumber:0
                            context:nil
                            subtype:NSEventSubtypeApplicationActivated
                            data1:103
                            data2:0]; // it is not a dial, used in long press of dial set to 0dB
    
    [self dial:newEvent];
}
// MARK: ------------ end of video rec delay routines -------------

-(void)captureFirstLineInRehearse:(NSEvent*)event{
    
    _matrixWindowController.captureFirstLineInRehearse = !_matrixWindowController.captureFirstLineInRehearse;
}
-(void)autoslate:(NSEvent*)event{
//    @"autoslate:",@"75", // autoslate leading edge
//    @"autoslate:",@"-75", // autoslate trailing edge
    
    NSInteger keyNumber = event.data1;
    
    switch(keyNumber){
        case 75:
            [self txOsc:@"led 9,75,true"];
            [_matrixWindowController.matrixView autoSlate:true];
            break;
        default:
            [self txOsc:@"led 9,75,false"];
            [_matrixWindowController.matrixView autoSlate:false];
            break;
    }

}

-(void)talkback:(NSEvent*)event{
    
    // talkback and mute buttons

    NSInteger keyNumber = event.data1;
    
    switch(keyNumber){
        case 73:
            _matrixWindowController.dimA |= DIM_MASK;
            break;
        case 74:
            _matrixWindowController.dimB |= DIM_MASK;
            break;
        case -73:
            _matrixWindowController.dimA &= ~DIM_MASK;
            break;
        case -74:
            _matrixWindowController.dimB &= ~DIM_MASK;
            break;
        case 109:
            _matrixWindowController.dimC |= DIM_MASK;
            break;
        case -109:
            _matrixWindowController.dimC &= ~DIM_MASK;
            break;
        case 110:
            _matrixWindowController.dimD |= DIM_MASK;
            break;
        case -110:
            _matrixWindowController.dimD &= ~DIM_MASK;
            break;
        default:
            _matrixWindowController.dimA = 0;
            _matrixWindowController.dimB = 0;
            _matrixWindowController.dimC = 0;
            _matrixWindowController.dimD = 0;
            break;
    }
}
// MARK: --------------------- dials ---------------------

// there is a taper item if taper is not BlueCat
// 0xb0 is MIDI channel 1, by convention. 0xb0-0xbf are channels 1-16.
NSDictionary *dialDictionary = @{@"92" : @{DIAL_CLIENT_KEY : @"accClient"
                                           ,@"Text" : @"Zoom"
                                           ,@"midiMsgs" : @[@[@"176",@"23"]]
                                        }
                                 ,@"93" : @{DIAL_CLIENT_KEY : @"accClient"
                                            ,@"Text" : @"Source\\nConnect"
//                                            ,@"Routine" : @"dialMuteDim:"
                                            ,@"midiMsgs" : @[@[@"176",@"24"]]
                                            ,@"Name" : @"Source Connect" // the name of the matrix
                                        }
                                 ,@"94" : @{@"Taper" : @"ufx"
                                            ,@"Text" : @"Actor\\nDirect"
                                            ,@"Routine" : @"actorDirect:"
                                         }
                                 ,@"95" : @{@"Text" : @"Actor\\nHP"
                                            ,@"Taper" : @"ufx"
                                            ,@"Routine" : @"dialMuteDim:"
                                            ,@"Name" : @"Actor" // the name of the matrix to mute
                                         }
                                 ,@"96" : @{DIAL_CLIENT_KEY : @"accClient"
                                            ,@"Text" : @"Beeps"
                                            ,@"midiMsgs" : @[@[@"176",@"17"]]
                                         }
                                 ,@"97" : @{DIAL_CLIENT_KEY : @"accClient"
                                            ,@"Text" : @"Mac\\nCPU"
                                            ,@"midiMsgs" : @[@[@"176",@"18"]]
                                         }
                                 ,@"98" : @{DIAL_CLIENT_KEY : @"accClient"
                                            ,@"Text" : @"Guide\\nTo Booth"
                                            ,@"midiMsgs" : @[@[@"176",@"19"]]
                                         }
                                 ,@"99" : @{@"Text" : @"Snoop"
                                            ,@"Taper" : @"ufx"
                                            //,@"Routine" : @"dialSnoopService:"
                                            ,@"Routine" : @"dialMuteDim:"
                                         }
                                 ,@"100" : @{DIAL_CLIENT_KEY : @"remoteClient"
                                            ,@"Taper" : @"ufx"
                                            ,@"Text" : @"Loopback"
                                            ,@"midiMsgs" : @[@[@"188",@"104"],@[@"180",@"102"]]
                                         }
                                 ,@"101" : @{DIAL_CLIENT_KEY : @"remoteClient"
                                            ,@"Taper" : @"ufx"
                                            ,@"Text" : @"Remote\\nActor Dir"
                                            ,@"midiMsgs" : @[@[@"188",@"106"],@[@"176",@"102"]]
                                         }
                                 ,@"102" : @{DIAL_CLIENT_KEY : @"remoteClient"
                                            ,@"Taper" : @"ufx"
//                                             ,@"Routine" : @"dialMuteDim:"
                                            ,@"Text" : @"Remote\\nActor HP"
                                            ,@"midiMsgs" : @[@[@"184",@"104"]]
                                            ,@"Name" : @"Remote Actor" // the name of the matrix
                                         }
                                 ,@"103" : @{DIAL_CLIENT_KEY : @"accClient"
                                             ,@"Text" : @"Video\\nDelay"
                                             ,@"midiMsgs" : @[@[@"176",@"0"]]//0xb0,CC_VIDEO_REC_DELAY
                                             ,@"Routine" : @"VideoDelayService:"
                                         }
                                 ,@"104" : @{@"Text" : @"Control\\nRoom"
                                             ,@"Taper" : @"ufx"
                                             ,@"Routine" : @"dialMuteDim:"
                                             ,@"Name" : @"Control Room" // the name of the matrix to mute
                                         }
                                 ,@"105" : @{@"Text" : @"Stage"
                                             ,@"Taper" : @"ufx"
                                             ,@"Routine" : @"dialMuteDim:"
                                             ,@"Name" : @"Stage" // the name of the matrix to mute
                                         }
                                 ,@"106" : @{@"Text" : @"Editor\\nHP"
                                             ,@"Taper" : @"ufx"
                                             ,@"Routine" : @"dialMuteDim:"
                                             ,@"Name" : @"Editor" // the name of the matrix to mute
                                         }
                                 ,@"107" : @{@"Text" : @"Remote\\nEditor HP"
                                             ,@"Taper" : @"ufx"
//                                             ,@"Routine" : @"dialMuteDim:"
                                             ,@"Name" : @"Remote Editor" // the name of the matrix to mute
                                         }

                                };

-(void)dial:(NSEvent*)event{
        
//    NSLog(@"dial %ld %ld",event.data1,event.data2);
    
    // 16 dial buttons 92-107
    // dial pots    192-207 (i.e. button + 100)
    NSInteger dialNumber = labs(event.data1); if(dialNumber >= LAST_DIAL_INDEX) dialNumber -= 100;
    NSString *key = [NSString stringWithFormat:@"%ld", dialNumber];
    NSString *valueKey = [NSString stringWithFormat:@"%@_%@",DIAL_VALUE_KEY,key];
    NSString *muteKey = [NSString stringWithFormat:@"%@_%@",DIAL_MUTE_KEY,key];
    
    NSDictionary *dict = dialDictionary[key];

    if(dict){
        
        if(labs(event.data1) >= LAST_DIAL_INDEX){
            
            // pot, positive for right, negative for left

            NSInteger dialValue = [[NSUserDefaults standardUserDefaults] integerForKey:valueKey];
            dialValue += event.data1 > 0 ? 1 : -1;
            
            dialValue = dialValue < 0 ? 0 : dialValue;  // no negative values
            
            NSInteger clipValue = dialNumber == 103 ? 120 : 127;    // clip video delay at 60
            dialValue = dialValue > clipValue ? clipValue : dialValue;  // video delay is small
            
            [[NSUserDefaults standardUserDefaults] setInteger:dialValue forKey:valueKey];
        }else if(event.data1 > 0 && event.data2 == 9){
            // dials, fire a oneshot, long press sets to 0dB
            [_keyOneshot invalidate];   
            [self setKeyOneshot:[NSTimer scheduledTimerWithTimeInterval:.5 target: self selector:@selector(dialOneShotService) userInfo:key repeats: NO]];

        }else{
            if(_keyOneshot.isValid || event.data2 != 9) {
                // short press, or event from mute button mutes
                [_keyOneshot invalidate];
                NSInteger dialMute = [[NSUserDefaults standardUserDefaults] boolForKey:muteKey] ? false : true;
                [[NSUserDefaults standardUserDefaults] setBool:dialMute forKey:muteKey];
                NSLog(@"%@ %ld",muteKey,(long)dialMute);
            }else{
                return; // sendDial() called from oneshot, don't call it twice
            }
        }
    }
    
    [self sendDial:key];
}
-(void)dialOneShotService{
    // long press sets gain to 0dB

    NSString *key = _keyOneshot.userInfo;
    NSDictionary *dict = dialDictionary[key];
    
    // items w/o taper are blueCat taper
    NSString *taper = dict[@"Taper"];
    NSInteger zerodB = taper && [taper isEqualToString:@"ufx"] ?  104 : 97;
    
    if([key isEqualToString:@"103"]){
        // video delay
        zerodB = 0;
    }
    NSString *valueKey = [NSString stringWithFormat:@"%@_%@",DIAL_VALUE_KEY,key];
    [[NSUserDefaults standardUserDefaults] setInteger:zerodB forKey:valueKey];
    [self sendDial:key];

}
-(void)sendDial:(NSString*)key{
    
    NSString *valueKey = [NSString stringWithFormat:@"%@_%@",DIAL_VALUE_KEY,key];
    NSString *muteKey = [NSString stringWithFormat:@"%@_%@",DIAL_MUTE_KEY,key];

    NSInteger dialMute = [[NSUserDefaults standardUserDefaults] boolForKey:muteKey];
    NSInteger dialValue = [[NSUserDefaults standardUserDefaults] integerForKey:valueKey];
    dialValue = dialValue < 0 ? 0 : dialValue;
    dialValue = dialValue > 127 ? 127 : dialValue;  //

    int fg = btnWhiteColor;
    int bg = dialMute ? aRedColor : btnOffColor;

    NSDictionary *dict = dialDictionary[key];
    
    NSString *dBString;
    
    if([key isEqualToString:@"103"]){
        // video delay is in 1/2 frame increments
        double d = ((double)dialValue) / 2.0;
        dBString = [NSString stringWithFormat:@"%2.1f",d];
        
    }else{
        
        // trims, in dB
        // items w/o taper are blueCat taper

        dBString = [_matrixWindowController bluCatSliderToString:(NSInteger) dialValue];    // default is blueCat

        NSString *taper = dict[@"Taper"];
        if(taper && [taper isEqualToString:@"ufx"]){
            
            dBString = [_matrixWindowController sliderToString:(NSInteger) dialValue];

        }
    }
        
    NSString *msg = [NSString stringWithFormat:@"btn 9_%@,%d,%d,%@\\n%@",key,fg,bg,dict[@"Text"],dBString];
    [self txOsc:msg];
    
    [_dialMidiWindowController.viewController sendConsoleMuteForKey:key];
    
    // optional MIDI tx
    if(dict[DIAL_CLIENT_KEY]){
        [self sendDialMidi:key];   // send MIDI when we update stream deck plus
    }
    
    // optional additional service
    NSString *routine = dict[@"Routine"];
    
    if(routine){
        
        SEL aSelector = sel_registerName((const char*)[routine UTF8String]);
        
        if([self respondsToSelector:aSelector]){
            
            [self performSelectorOnMainThread:aSelector withObject:key waitUntilDone:false];
            
        }
        
    }
}
-(void)sendDialMidi:(NSString*)key{
    
    // send by timer, or on value change
    NSDictionary *dict = dialDictionary[key];
    if(!dict){return;}
    NSString *clientKey = dict[DIAL_CLIENT_KEY];
    if(!clientKey){return;}

    NSString *valueKey = [NSString stringWithFormat:@"%@_%@",DIAL_VALUE_KEY,key];
    NSString *muteKey = [NSString stringWithFormat:@"%@_%@",DIAL_MUTE_KEY,key];

    NSInteger dialMute = [[NSUserDefaults standardUserDefaults] boolForKey:muteKey];
    NSInteger dialValue = [[NSUserDefaults standardUserDefaults] integerForKey:valueKey];

    // MIDI destinations for pots are in midiClientDictionary
    if(_statusClient && _lpMini.accMidi.midiClient && _matrixWindowController.boomRecorderMIDI){
        
        NSDictionary *midiClientDictionary = @{ @"statusClient"     : _statusClient
                                                ,@"accClient"       : _lpMini.accMidi.midiClient
                                                ,@"remoteClient"    : _matrixWindowController.boomRecorderMIDI
        };
        
        MidiClient *client = midiClientDictionary[clientKey];
        NSArray *midiMsgs = dict[@"midiMsgs"];
        
        if(!client || !midiMsgs){
            return;
        }
        
        if([clientKey isEqualToString:@"remoteClient"] ){
            NSLog(@"remoteClient");
            
        }
        
        for (NSArray *midiMsg in midiMsgs){
            
            unsigned char msg[] = {0,0,0};
            msg[0] = [midiMsg[0] integerValue] & 0xff;
            msg[1] = [midiMsg[1] integerValue] & 0x7f;
            // 103 is the delay line value, is not a mute
            msg[2] = dialMute && ![key isEqualToString:@"103"] ? 0 : dialValue & 0x7f;

            // special case for video rec delay
            if(msg[0] == 0xb0 && msg[1] == CC_VIDEO_REC_DELAY){
                
                if(_matrixWindowController.rehRecPb != MODE_CONTROL_RECORD){
                    msg[2] = 0;
                }
                
                // delay seconds
                double delaySeconds = (double)msg[2];
                // depends on frame rate
                switch(_ptHui.mtcType){
                    case 0: delaySeconds    *= 0.041666;   break;
                    case 1: delaySeconds    *= 0.040000;   break;
                    default: delaySeconds   *= 0.033333;   break;

                }
                
                delaySeconds /= 2;  // MIDI is in 1/2 frame increments
                
                [[NSUserDefaults standardUserDefaults]setDouble:delaySeconds forKey:@"videoDelaySeconds"];
                
                // 11/2/23 there is a chirp at the end of REC CYCLE, wait to turn off delay
                if(msg[2] == 0 && self.cycleMode != CYCLE_MODE_IDLE){
                    // audio chirp if we set the audio delay line to zero, delay the message
                    double monitorDelay = [[NSUserDefaults standardUserDefaults]doubleForKey:@"monitorDelay"];
                    [videoRecDelayTimer invalidate];
                    videoRecDelayTimer = [NSTimer scheduledTimerWithTimeInterval:monitorDelay target:self selector:@selector(videoRecDelayTimerService) userInfo:client repeats:false];
                    
                    continue;   // audio delay off gets sent in videoRecDelayTimerService
                }
                
            }
            
            [client midiTx:[NSData dataWithBytes:msg length:3]];
        }
    }
}
NSTimer *videoRecDelayTimer;
-(void)videoRecDelayTimerService{
    
//    tickle github
    unsigned char msg[] = {0xb0,CC_VIDEO_REC_DELAY,0};
    
    MidiClient *client = videoRecDelayTimer.userInfo;
    [client midiTx:[NSData dataWithBytes:msg length:3]];
    
}
-(void)dialAccessoryRefresh{
    
    // 1/3/24 refresh 23, 24, 19, 17, 18 in decimal
    NSArray *array = @[@"92",@"93",@"96",@"97",@"98"];
    
    for(NSString *key in array){
        [self sendDialMidi:key];
    }
}
-(void)dialMidiRefresh{
    // called from lpMini.micRefresh(), periodic send of accessory items
    // 09/06/23 Evan wants changes only, no refresh
    
    for(NSString *key in dialDictionary.allKeys){
        
        // don't refresh ufx
        
        NSDictionary *dict = dialDictionary[key];
        if(dict && ![dict[DIAL_CLIENT_KEY] isEqualToString:@"ufxClient"]){
            [self sendDialMidi:key];   // timer send
        }
    }
}
// MARK: ------------ additional mute buttons for dials -------------
NSDictionary *muteToDialDictionary = @{ @"87" : @"104"      // control room mute button
                                       ,@"88" : @"105"      // stage
                                       ,@"89" : @"95"       // actor
                                       ,@"90" : @"106"      // editor
                                       ,@"77" : @"103"      // video delay line
                                       ,@"108" : @"99"     // snoop
                                    };
NSDictionary *dialToMuteDictionary = @{  @"104" : @"87"     // control room mute button
                                        ,@"105" : @"88"     // stage
                                        ,@"95"  : @"89"     // actor
                                        ,@"106" : @"90"     // editor
                                        ,@"103" : @"77"     // video delay line
                                        ,@"99"  : @"108"     // snoop
                                    };

-(void)muteForDial:(NSEvent*)event{
    
    // buttons 9.87-9.90
    // the commands have an event operand
    
    NSString *dial = muteToDialDictionary[[NSString stringWithFormat:@"%ld",event.data1]];
        
    if(!dial){
        return; // no dial for this button
    }
    NSEvent *newEvent = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
                            location:NSMakePoint(0, 0)
                            modifierFlags:0
                            timestamp:0
                            windowNumber:0
                            context:nil
                            subtype:NSEventSubtypeApplicationActivated
                            data1:[dial integerValue]
                            data2:0]; // it is not a dial, used in long press of dial set to 0dB
    
    [self dial: newEvent];

}
-(void)dimControlRoom{
    // button 9.91
    _matrixWindowController.dimControlRoom = !_matrixWindowController.dimControlRoom;
}
-(void)muteAll{
    
    _matrixWindowController.muteAll = !_matrixWindowController.muteAll;
}
-(void)refreshOutputGains{
    
    for(NSString *key in dialDictionary.allKeys){
        [self dialMuteDim:key];
    }
    
//    self.snoopState = self.snoopState;  // 2.10.02 dim snoop
}

// MARK: ------------ extra routines for dial MIDI service -------------
-(void)VideoDelayService:(NSString*)key{
    [_matrixWindowController refreshCrosspoints];
}
-(void)actorDirect:(NSString*)key{

    // routing an input not in the matrix to the actor HP, add unity gain crosspoint send MIDI
    // Actor Direct mic is assigned in a combo box 2.10.02
    // 12/6/23 multi selection, string is tab separated like 'Mic 1/tMic 2'
    
    NSString *actorDirectMic = [[NSUserDefaults standardUserDefaults] objectForKey:@"actorDirectMic"];  // 'Mic 1' - 'Mic 4', multi, tab separator
    // change detector for turning off the previous output
    NSString *lastActorDirectMic = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastActorDirectMic"];  // 'Mic 1' - 'Mic 4', multi, tab separator
    
    // multiple selection
    NSArray *actorDirectOutputArray = [actorDirectMic componentsSeparatedByString:@"\t"];
    NSArray *lastActorDirectOutputArray = [lastActorDirectMic componentsSeparatedByString:@"\t"];
        
    NSString *valueKey = [NSString stringWithFormat:@"%@_%@",DIAL_VALUE_KEY,key];
    NSString *muteKey = [NSString stringWithFormat:@"%@_%@",DIAL_MUTE_KEY,key];

    NSInteger dialMute = [[NSUserDefaults standardUserDefaults] boolForKey:muteKey];
    NSInteger dialValue = dialMute ? 0 : [[NSUserDefaults standardUserDefaults] integerForKey:valueKey];
    
    // send the crosspoints
    for(NSDictionary *colDict in _matrixWindowController.matrixView.colTitles){
        
        NSString *colTitle = colDict[@"Title"];
        NSRange range = [colTitle rangeOfString:@"Actor"];
        
        if(range.location == 0){
            
            NSString *channel = colDict[@"SelectChannel"];
            NSString *controlChange = colDict[@"SelectControlChange"];
            
            NSString *str;

            // output change detect
            if(![actorDirectMic isEqualToString:lastActorDirectMic]){
                
                // turn off last outputs
                for(NSString *item in lastActorDirectOutputArray){
                    
                    NSString *lastActorDirectOutput = [NSString stringWithFormat:@"%d",([[item componentsSeparatedByString:@" "]lastObject]).intValue + 101];

                    str = [NSString stringWithFormat:@"%@ %@ 0 176 %@ 0",channel,controlChange,lastActorDirectOutput];
                    
                    [self sendUfxString:str];
               }
                
                // turn off change detector
                [[NSUserDefaults standardUserDefaults] setObject:actorDirectMic forKey:@"lastActorDirectMic"];
            }
            
            // turn on outputs
            for(NSString *item in actorDirectOutputArray){
                
                NSString *actorDirectOutput = [NSString stringWithFormat:@"%d",([[item componentsSeparatedByString:@" "]lastObject]).intValue + 101];

                str = [NSString stringWithFormat:@"%@ %@ 0 176 %@ %ld",channel,controlChange,actorDirectOutput,dialValue];
                
                [self sendUfxString:str];
            }
        }
    }
}
-(void)dialMuteDim:(NSString*)key{
    
    NSString *valueKey = [NSString stringWithFormat:@"%@_%@",DIAL_VALUE_KEY,key];
    NSString *muteKey = [NSString stringWithFormat:@"%@_%@",DIAL_MUTE_KEY,key];

    NSInteger dialMute = [[NSUserDefaults standardUserDefaults] boolForKey:muteKey];
    NSInteger dialValue = [[NSUserDefaults standardUserDefaults] integerForKey:valueKey];
    
    NSLog(@"dialMuteDim valueKey %@ value %ld muteKey %@ mute %ld",valueKey,dialValue,muteKey,dialMute);

    NSString *muteButton = dialToMuteDictionary[key];
    
    if (muteButton != nil){
        NSString *oscStr = [NSString stringWithFormat:@"led 9,%@,%@",muteButton,(dialMute ? @"true" : @"false")];

        [self txOsc:oscStr];  // the mute button for this section, tied to dial button
    }

    NSString *matrixName = dialDictionary[key][@"Name"];

    // special case
    bool dimControlRoom = [matrixName isEqualToString:@"Control Room"] && _matrixWindowController.dimControlRoom;
    
    // special case
    // video delay mute, snoop cols don't have a matrix
    // add cols w/o matrix here to be dimmed or muted
    switch(key.intValue){
        case 99:                    // dial 99 is snoop
            matrixName = @"Snoop";  // dim this col, doesn't have a matrix
            dimControlRoom = _matrixWindowController.dimControlRoom;
            // only use snoopState if PT is online, see decodeMotionZoneByte()
            if(_matrixWindowController.midiAnnunciator.state == NSControlStateValueOn){
                dialValue = (_snoopState % 2) == 1 ? dialValue : MAX_FADER_ATTENUATION;
            }
           break;
        default: break;
    }

    dialMute |= _matrixWindowController.muteAll;    // after the txOsc so that the individual mute indications don't follow Mute All
    
    // fixed sends or returns, always 0dB or muted
    NSArray *fixedSendsAndReturns = @[@"93",@"102",@"107"];
    
    if([fixedSendsAndReturns containsObject:key]){
        dialMute = _matrixWindowController.muteAll;
        dialValue = dialMute ? 0 : 104;
    }
    
    double dimDB = [[NSUserDefaults standardUserDefaults] doubleForKey:@"dimDB"];

    if(matrixName){
//        NSLog(@"matrixName %@",matrixName);

        for(int i = 0; i < _matrixWindowController.talkbackArray.count; i++){
            
//            NSLog(@"Name %@",_matrixWindowController.talkbackArray[i][@"Name"]);
            
            if([_matrixWindowController.talkbackArray[i][@"Name"] hasPrefix:matrixName]){
                NSNumber *dimA = _matrixWindowController.talkbackArray[i][DIM_A_KEY];
                NSNumber *dimB = _matrixWindowController.talkbackArray[i][DIM_B_KEY];
                NSNumber *dimC = _matrixWindowController.talkbackArray[i][DIM_C_KEY];
                NSNumber *dimD = _matrixWindowController.talkbackArray[i][DIM_D_KEY];
                
                // dimA.intValue != 0
                if((_matrixWindowController.dimA && dimA.intValue != 0) ||
                   (_matrixWindowController.dimB && dimB.intValue != 0) ||
                   (_matrixWindowController.dimC && dimC.intValue != 0) ||
                   (_matrixWindowController.dimD && dimD.intValue != 0) ||
                   dimControlRoom){
                    
                    dialValue = [_matrixWindowController addDbToFader:dimDB :dialValue];
                    
                }
                
            }
        }
    }else{
        return;
    }

    dialValue = dialValue < 0 ? 0 : dialValue;
    dialValue = dialValue > 127 ? 127 : dialValue;  //
    dialValue = dialMute ? 0 : dialValue;

    for(NSDictionary *colDict in _matrixWindowController.matrixView.colTitles){
        
        NSString *colTitle = colDict[@"Title"];
        
        NSRange range = [colTitle rangeOfString:matrixName];
        
        if(range.location == 0){
            
            NSString *channel = colDict[@"Channel"];
            NSString *controlChange = colDict[@"ControlChange"];
            
            NSString *str = [NSString stringWithFormat:@"%@ %@ %d",channel,controlChange,(int)dialValue];
            [self sendUfxString:str];

        }
    }
}
-(void)dialSnoopService:(NSString*)key{
    
//    self.snoopState = self.snoopState;  // uses dial value for snoop gain
    
    NSString *muteKey = [NSString stringWithFormat:@"%@_%@",DIAL_MUTE_KEY,key];
    NSInteger dialMute = [[NSUserDefaults standardUserDefaults] boolForKey:muteKey];
    
    NSString *muteButton = dialToMuteDictionary[key];
    NSString *oscStr = [NSString stringWithFormat:@"led 9,%@,%@",muteButton,(dialMute ? @"true" : @"false")];

    [self txOsc:oscStr];  // the mute button for this section, tied to dial button

}

// MARK: ------------ end of extra routines for dial MIDI service -------------


-(void)toggleLoop2:(NSEvent*)event{
    // 2.00.00, used by OSC
    NSInteger keyNumber = event.data1;

    if(_audioPlayerWindowController){
        [_audioPlayerWindowController loopFromOsc:keyNumber];

    }
}
//-(void)toggleLoop:(NSEvent*)event{
//
//    // TODO: 2.00.00 remove stub, calls to stub
//    // play quicktime files
//    NSInteger keyNumber = event.data1;
//
//    if(_samplerWindowController){
////        [_samplerWindowController loopFromXKey:keyNumber];
//
//    }
//
//}
//-(void)toggleSelectTake:(NSEvent*)event{
//    // play quicktime files
//    NSInteger keyNumber = event.data1;
//    
//    if(_editorWindowController){
//        [_editorWindowController toggleXKey:keyNumber];
//    }
//    
//    
//}
//-(void)toggleSampler:(NSEvent*)event{
//    
//    // toggleSampler
//    if(_samplerWindowController){
//        
//        NSInteger keyNumber = event.data1;
//        
//        DropButton *db;// = [_samplerWindowController playbackButton];
//        NSInteger currentState;
//        
//        switch(keyNumber){
//            case 4:
//                db = [_samplerWindowController playbackButton2];
//                currentState = [db state];
//                [db setState:currentState ? NSControlStateValueOff : NSControlStateValueOn];
//                [_samplerWindowController onPlaybackButton2:db];
//                break;
//            case 5:
//                
//                db = [_samplerWindowController playbackButton];
//                currentState = [db state];
//                [db setState:currentState ? NSControlStateValueOff : NSControlStateValueOn];
//                [_samplerWindowController onPlaybackButton:db];
//                break;
//                
//            default: return;
//        }
//        
//    }
//    
//}
//-(void)resendCue{
//    
//    Document *doc = [self topDocument];
////    [doc onSendCueToProtools:nil];
//    
//}
-(void)fastRev{
    
    //        [acwc txMsg:@"keyWithModifiers\tz\t1"]; // modifiers in 2nd operand, 0-15, [0] command [1] option [2] control [3] shift
    // 2,1,0,-1,-2 are the states
    // downspace 26, for silence we want to be on last track
    
    if(!_ptHui.isStop){
        [_ptHui onStop];
    }
    [_adrClientWindowController txMsg:@"keyStroke ;;;;;;;;;;;;;;;;;;;;;;;;;;"];   // move off of guide track
    [_adrClientWindowController txMsg:@"keyWithModifiers\t9\t4"];   // default is fwd
    [_adrClientWindowController txMsg:@"keyStroke -"];              // reverse

//    switch (_fastFwdRev) {
//        case 2:
//            [_adrClientWindowController txMsg:@"keyStroke -"];
//            _fastFwdRev = -2;
//            break;
//            
//        case 0:
//        case -1:
//        case 1:
//            
//            [_adrClientWindowController txMsg:@"keyWithModifiers\t9\t4"];
//            [_adrClientWindowController txMsg:@"keyStroke -"];
//            _fastFwdRev = -2;
//            break;
//        case -2:
//            [_adrClientWindowController txMsg:@"keyCode 49"];
//            _fastFwdRev = 0;
//            break;
//    }
    
    
}
-(void)slowFwd{
    // downspace 26, for silence we want to be on last track
    if(!_ptHui.isStop){
        [_ptHui onStop];
    }
    [_adrClientWindowController txMsg:@"keyStroke ;;;;;;;;;;;;;;;;;;;;;;;;;;"];   // move off of guide track
    [_adrClientWindowController txMsg:@"keyWithModifiers\t3\t4"];   // default is fwd

//    switch (_fastFwdRev) {
//        case -1:
//            [_adrClientWindowController txMsg:@"keyStroke +"];
//            _fastFwdRev = 1;
//            break;
//            
//        case 0:
//        case 2:
//        case -2:
//            
//            [_adrClientWindowController txMsg:@"keyWithModifiers\t3\t4"];
//            [_adrClientWindowController txMsg:@"keyStroke +"];
//            _fastFwdRev = 1;
//            break;
//        case 1:
//            [_adrClientWindowController txMsg:@"keyCode 49"];
//            _fastFwdRev = 0;
//            break;
//    }
    
}
-(void)fastFwd{
    // downspace 26, for silence we want to be on last track
    if(!_ptHui.isStop){
        [_ptHui onStop];
    }
    [_adrClientWindowController txMsg:@"keyStroke ;;;;;;;;;;;;;;;;;;;;;;;;;;"];   // move off of guide track
    [_adrClientWindowController txMsg:@"keyWithModifiers\t9\t4"];   // default is fwd

    //        [acwc txMsg:@"keyWithModifiers\tz\t1"]; // modifiers in 2nd operand, 0-15, [0] command [1] option [2] control [3] shift
    
//    switch (_fastFwdRev) {
//        case -2:
//            [_adrClientWindowController txMsg:@"keyStroke +"];
//            _fastFwdRev = 2;
//            break;
//            
//        case 0:
//        case -1:
//        case 1:
//            
//            [_adrClientWindowController txMsg:@"keyWithModifiers\t9\t4"];
//            [_adrClientWindowController txMsg:@"keyStroke +"];
//            _fastFwdRev = 2;
//            break;
//        case 2:
//            [_adrClientWindowController txMsg:@"keyCode 49"];
//            _fastFwdRev = 0;
//            break;
//    }
    
    //    if([_midiClient isStop]) [_adrClientWindowController txMsg:@"fastFwd 1"];
    //    else [_adrClientWindowController txMsg:@"fastFwd 0"];
    
}
-(void)slowRev{
    // downspace 26, for silence we want to be on last track
    if(!_ptHui.isStop){
        [_ptHui onStop];
    }
    [_adrClientWindowController txMsg:@"keyStroke ;;;;;;;;;;;;;;;;;;;;;;;;;;"];   // move off of guide track
    [_adrClientWindowController txMsg:@"keyWithModifiers\t3\t4"];   // default is fwd
    [_adrClientWindowController txMsg:@"keyStroke -"];              // rev

    //        [acwc txMsg:@"keyWithModifiers\tz\t1"]; // modifiers in 2nd operand, 0-15, [0] command [1] option [2] control [3] shift
    
//    switch (_fastFwdRev) {
//        case 1:
//            [_adrClientWindowController txMsg:@"keyStroke -"];
//            _fastFwdRev = -1;
//            break;
//        case 0:
//        case 2:
//        case -2:
//            
//            [_adrClientWindowController txMsg:@"keyWithModifiers\t3\t4"];
//            [_adrClientWindowController txMsg:@"keyStroke -"];
//            _fastFwdRev = -1;
//            break;
//        case -1:
//            [_adrClientWindowController txMsg:@"keyCode 49"];
//            _fastFwdRev = 0;
//            break;
//    }
    
}
//-(void)loopRecord{
//    
//    Document *doc = [self topDocument];
//    
//    if(doc == nil)return;
//    
//    NSString *msg = doc.loopRecord ? @"preroll 00:00:01:00" : @"preroll 00:00:03:00";
//    NSString *msg2 = doc.loopRecord ? @"loopRecord 2" : @"loopRecord 1";
//    
//    if(_adrClientWindowController){
//        
//        [_adrClientWindowController txMsg:msg];
//        [_adrClientWindowController txMsg:msg2];
//    }
//    
//}
//-(void)toggleLoopRecord{
//    
//    Document *doc = [self topDocument];
//    if(doc){
//        [doc setLoopRecord:!doc.loopRecord];
//        [self loopRecord];
//    }
//}
-(void)sortByActor{
    
    Document *doc = [self topDocument];
    if(doc) [doc sortByActor];
    
}
-(void)sortByCueID{
    
    Document *doc = [self topDocument];
    if(doc) [doc sortByCueID];
    
}
-(void)locate:(NSString *)start{
    [self locate:start :@"-1"];   // no action after getProtoolsPosition
}

-(void) locate:(NSString *)start :(NSString*)msg{
    
    if(start == nil){
        return;
    }
    
    start = [_tcf stringForObjectValue:start];  // ft+fr or tc, depending on display format
    
    // 2.10.02 Ventura, PT11 Ultimate, added jxaLocate script
    start = [start stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    [_adrClientWindowController txMsg:[NSString stringWithFormat:@"jxaLocate %@",start]];
    
    // getProtoolsPosition handles cueup complete
    [_adrClientWindowController txMsg:[NSString stringWithFormat:@"jxaGetProtoolsPosition %@",msg]];
    
}

-(void)selectCurrentSixteenTrackMemory{
    
    // 2.00.00 code at end was unreliable, guessing it was the \n terminator
    
    NSInteger mem = showSixteenTable[[_matrixWindowController numRecTracksTag]][_currentTrack >> 4];
    NSString *msg16 = [NSString stringWithFormat:@"mem %d",(int)mem];
    
    NSInteger numRecTracksTag = [_matrixWindowController numRecTracksTag];
    
    NSInteger track = _currentTrack;    // _currentTrack is zero-based
    
    track += trackBaseTable[numRecTracksTag];
    NSInteger trackMax = trackBaseTable[numRecTracksTag + 1] - 1; //=
    if(track > trackMax) track = trackMax;
    
    NSString *msg1 = [NSString stringWithFormat:@"mem %ld",track];

    NSString *msg = _matrixWindowController.show16Tracks & 1 ? msg16 : msg1;
    [_adrClientWindowController txMsg:msg];
    
    [_adrClientWindowController appendToLog:[NSString stringWithFormat:@"selected track %ld",_currentTrack + 1]];

    // code below should be the same, but it does not work reliably

//    return;
//
//    if([_matrixWindowController show16Tracks]){
//
//        NSInteger mem = showSixteenTable[[_matrixWindowController numRecTracksTag]][_currentTrack >> 4];
//        if(_adrClientWindowController) [_adrClientWindowController txMsg:[NSString stringWithFormat:@"mem %d\n",(int)mem]];
//
//    }else{
//
//        [self selectTrackMemory:_currentTrack];
//    }
    
}
-(void)selectLastSixteenTrackMemory{
    
    // 2.00.00 see selectCurrentSixteenTrackMemory
    
    NSInteger mem = showSixteenTable[[_matrixWindowController numRecTracksTag]][_lastRecordTrack >> 4];
    NSString *msg16 = [NSString stringWithFormat:@"mem %d",(int)mem];
    
    NSInteger numRecTracksTag = [_matrixWindowController numRecTracksTag];
    
    NSInteger track = _lastRecordTrack;
    
    track += trackBaseTable[numRecTracksTag];
    NSInteger trackMax = trackBaseTable[numRecTracksTag + 1] - 1; //=
    if(track > trackMax) track = trackMax;
    
    NSString *msg1 = [NSString stringWithFormat:@"mem %ld",track];

    NSString *msg = _matrixWindowController.show16Tracks & 1 ? msg16 : msg1;
    [_adrClientWindowController txMsg:msg];

//    if([_matrixWindowController show16Tracks]){
//
//        NSInteger mem = showSixteenTable[[_matrixWindowController numRecTracksTag]][_lastRecordTrack >> 4];
//        if(_adrClientWindowController) [_adrClientWindowController txMsg:[NSString stringWithFormat:@"mem %d\n",(int)mem]];
//
//    }else{
//
//        [self selectTrackMemory:_lastRecordTrack];    // if we are not in 16 track mode, show the last record track
//    }
}
-(void)selectCurrentTrackMemory:(NSEvent*)event{
    
    //    NSInteger track = _currentTrack;
    //    if(_trackShift) track += 16;
    
    [self selectTrackMemory:_currentTrack];
    
}
NSInteger showSixteenTable[][2] = {{25,26},{27,28},{29,29},{30,30},{31,31},{32,32}};    //1,2,3,4,6,8 track
-(void)showSixteenTracks:(NSEvent*)event{
    
    NSInteger mem = showSixteenTable[[_matrixWindowController numRecTracksTag]][_currentTrack >> 4];
    if(_adrClientWindowController) [_adrClientWindowController txMsg:[NSString stringWithFormat:@"mem %d",(int)mem]];
    
    //    // TODO: can't check this until we are ate WB
    //    [self set16TrackLED];   // TODO: should this be here or in _matrixWindowController?
    
}
-(void)toggleShowSixteen{
    
    // TODO: ask Evan why isn't showSixteenTracks:() and toggleShowSixteen() a single function?
    // answer: because 'showSixteenTracks' shows 16 now, without toggling the state
    bool state = [[NSUserDefaults standardUserDefaults] boolForKey:@"show16Tracks"];
    state = state ? false : true;
//    NSLog(@"show16Tracks %d",state);
    [[NSUserDefaults standardUserDefaults] setBool:state forKey:@"show16Tracks"];
    [self selectCurrentSixteenTrackMemory];             // show the tracks

//    [_matrixWindowController setShow16Tracks:![_matrixWindowController show16Tracks]];
}
//-(void)companionShowSixteen{
//
//    [self showSixteenTracks: nil];
//
////    // show 16 no matter what state the checkbox is in
////    NSInteger mem = showSixteenTable[[_matrixWindowController numRecTracksTag]][_currentTrack >> 4];
////    if(_adrClientWindowController) [_adrClientWindowController txMsg:[NSString stringWithFormat:@"mem %d\n",(int)mem]];
//
//}
#pragma mark -------------------------------------------------------------------

//NSDictionary *foo = @{ {@"city"     : @"true"},
//                       {@"latitude" : @"true"},
//                       // etc.
//                     };


-(void)initJumpTables{
    // Evan's xk-80, May 10 2015 revision
    NSDictionary *unit_8_dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
                                       
//                                       @"initUnit_8_LEDs",[NSString stringWithFormat:@"%d",REPORT_KEY],   // REPORT_KEY
                                       @"getCueName:",@"0",
                                       @"preroll:",@"1",
                                       //                                       @"getCueName:",@"2",
                                       @"recordToComposite:",@"3",
                                       @"escape:",@"4",
                                       @"nextAnchor:",@"5",//@"inpointPlusOne:",@"5",
                                       @"storeEndTc:",@"6",//@"inpointMinusOne:",@"6",
                                       @"shiftKey:",@"7",
                                       @"shiftKey:",@"-7",
                                       
                                       @"getNote:",@"8",
                                       @"preroll:",@"9",
                                       //                                       @"getNote:",@"10",
                                       @"pixShowHide:",@"11",
                                       @"numberPad5:",@"12",
                                       @"numberPad5:",@"13",
                                       @"numberPad5:",@"14",
                                       @"numberPad5:",@"15",
                                       
                                       @"getDialog:",@"16",
                                       @"preroll:",@"17",
                                       //                                       @"getDialog:",@"18",
                                       @"inpointMinusOne:",@"19",//replaceSelect:
                                       @"numberPad5:",@"20",
                                       @"numberPad5:",@"21",
                                       @"numberPad5:",@"22",
                                       @"stub:",@"23",      // double key (Evan's old dwg does not show it)
                                       
                                       @"inputBussing:",@"24",
                                       @"preroll:",@"25",
                                       @"numberPad5:",@"261",//@"26",    // XKey 26 is 12 second preroll indicator, we get a bogus downedge when xkeys connects. works for Streamdeck only.
                                       @"inpointPlusOne:",@"27",//wildSyncSelect:
                                       @"numberPad5:",@"28",
                                       @"numberPad5:",@"29",
                                       @"numberPad5:",@"30",
                                       @"numberPad5:",@"31",
                                       
                                       @"pbRouting:",@"32",
                                       @"preroll:",@"33",
                                       //                                       @"inputBussing:",@"34",
                                       @"plusFrames:",@"35",
                                       @"stub:",@"36",  // double key, vertical
                                       @"numberPadStore:",@"37",
                                       @"stub:",@"38",  // double key, vertical
                                       @"locateToInpoint:",@"39",
                                       
                                       @"guideMem:",@"40",
                                       @"streamer1:",@"41",
                                       @"streamer4:",@"42",
                                       @"rehearseMode",@"43", // rehearse
                                       @"recordMode",@"44", // record
                                       @"playbackMode",@"45", // playback
                                       @"cycleButton",@"46", // cycle
                                       @"playStop",@"47", // play/stop
                                       
                                       @"verbAndFutz",@"48",
                                       @"streamer2:",@"49",
                                       @"streamer5:",@"50",
                                       @"stub:",@"51",
                                       @"stub:",@"52",
                                       @"stub:",@"53",
                                       @"stub:",@"54",
                                       @"stub:",@"55",  // double keys
                                       
                                       @"mainOutputs",@"56",
                                       @"streamer3:",@"57",
                                       @"streamer6:",@"58",
                                       @"deleteStreamers:",@"59",
                                       @"getPreEdit",@"60",
                                       @"wildSyncSelect:",@"61",
                                       @"showSixteenTracks:",@"62",
                                       @"showArmed:",@"63",
                                       @"showArmedTrailingEdge:",@"-63",
                                       
                                       @"showMono:",@"64",
                                       @"showLCR:",@"65",
                                       @"slowRev",@"66",//show6x
                                       @"fastRev",@"67",//fastRev
                                       @"sample:",@"68",
                                       @"sampleTrailingEdge:",@"-68",
                                       @"quickPreview:",@"69",
                                       @"quickPreviewTrailingEdge:",@"-69",
                                       @"previousCue",@"70",
                                       @"overlayKey:",@"71",
                                       @"overlayKey:",@"-71",
                                       
                                       @"showStereo:",@"72",
                                       @"show4x:",@"73",
                                       @"slowFwd",@"74",//show8x
                                       @"fastFwd",@"75",
                                       @"stub",@"76",   // double key 'sample'
                                       @"stub:",@"77",  // double key 'quick preview'
                                       @"nextCue",@"78",
                                       @"stub:",@"79",  // double key
                                       nil];
    
    NSDictionary *unit_8_dictionary_shifted = [[NSDictionary alloc] initWithObjectsAndKeys:
                                               
                                               //                                               @"trackMem5:",@"0",
                                               //                                               @"trackMem5:",@"1",
                                               @"deleteCurrentCue:",@"1",   // 1.00.23, was "2"
                                               //                                               @"missingMethod:",@"3",
//                                               @"cycleAlignment",@"4",
                                               @"toggleOpaque",@"5",
                                               @"cycleWindows:",@"6",
                                               @"shiftKey:",@"7",
                                               @"shiftKey:",@"-7",
                                               
                                               //                                               @"trackMem5:",@"8",
                                               //                                               @"trackMem5:",@"9",
                                               @"missingMethod:",@"10",
                                               //toggleInhibitStreamerInPlayback
                                               @"toggleInhibitStreamerInPlayback",@"11",
                                               //@"inhibitStreamerToggle",@"11",
                                               @"theHour:",@"12", // 7
                                               @"theHour:",@"13", // 4
                                               @"theHour:",@"14", // 1
                                               @"theHour:",@"15", // 0
                                               
                                               //                                               @"trackMem5:",@"16",
                                               @"trimBeepsMinusOne",@"17",
                                               //                                               @"missingMethod:",@"18",
                                               @"inpointMinusTen:",@"19",
                                               @"theHour:",@"20", // 8  //
                                               @"theHour:",@"21", // 5
                                               @"theHour:",@"22", // 2
                                               @"missingMethod:",@"23",      // double key (Evan's old dwg does not show it)
                                               
                                               //                                               @"trackMem5:",@"24",
                                               @"trimBeepsPlusOne",@"25",
                                               //                                               @"onEditorWindow:",@"26",
                                               @"inpointPlusTen:",@"27",
                                               @"theHour:",@"28", // 9
                                               @"theHour:",@"29", // 6
                                               @"theHour:",@"30", // 3
                                               @"zeroFeet",@"31",
                                               
                                               //                                               @"trackMem5:",@"32",
                                               //                                               @"trackMem5:",@"33",
                                               //                                               @"pbRouting:",@"34",
                                               @"missingMethod:",@"35",
                                               @"missingMethod:",@"36",  // double key, vertical
                                               //@"storeEndTc:",@"37",
                                               @"missingMethod:",@"38",  // double key, vertical
                                               @"onAddCue",@"39",   // locate to inpoint
                                               
                                               //                                               @"trackMem5:",@"40",
                                               @"streamer1Locate:",@"41",
                                               @"streamer4Locate:",@"42",
                                               @"onAhead",@"43", // ahead
                                               @"onIn",@"44", // in
                                               @"onPast",@"45", // past, for setting up AIP head when stopped
                                               @"missingMethod:",@"46", // cycle
                                               @"skipCutAndPaste",@"47", // play/stop
                                               
                                               //                                               @"trackMem5:",@"48",
                                               @"streamer2Locate:",@"49",
                                               @"streamer5Locate:",@"50",
                                               //                                               @"missingMethod:",@"51",
                                               //                                               @"missingMethod:",@"52",
                                               //                                               @"missingMethod:",@"53",
                                               //                                               @"missingMethod:",@"54",
                                               //                                               @"missingMethod:",@"55",  // double keys
                                               
                                               //                                               @"trackMem5:",@"56",
                                               @"streamer3Locate:",@"57",
                                               @"streamer6Locate:",@"58",
                                               @"missingMethod:",@"59",
                                               @"missingMethod:",@"60",
                                               @"missingMethod:",@"61",
                                               @"toggleShowSixteen",@"62",
                                               @"missingMethod:",@"63",
                                               
                                               @"cleanupMono",@"64",
                                               @"show6x:",@"65",
                                               @"missingMethod:",@"66",
                                               @"missingMethod:",@"67",
                                               @"captureSample:",@"68",
                                               @"captureFill:",@"69",
                                               @"unmergeCue",@"70",
                                               @"missingMethod:",@"71",
                                               
                                               @"cleanupStereo",@"72",
                                               @"show8x:",@"73",
                                               @"outputMem:",@"74",
                                               @"missingMethod:",@"75",
                                               //                                               @"slowFwd",@"76",
                                               @"missingMethod:",@"77",
                                               @"mergeNextCue",@"78",
                                               @"missingMethod:",@"79",
                                               nil];
    
    // Companion dictionary
    // keys 0-31 are tracks 0-31, so we don't have to cross-map keys to tracks
    // other fns where we have shift/unshift logic problems should go here
    NSDictionary *unit_9_dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
//
//                                       @"initUnit_9_LEDs",[NSString stringWithFormat:@"%d",REPORT_KEY],   // REPORT_KEY
                                       @"trackMem9:",@"0",
                                       @"clearCopyDown",@"-128",
                                       @"trackMem9:",@"1",
                                       @"clearCopyDown",@"-1",
                                       @"trackMem9:",@"2",
                                       @"clearCopyDown",@"-2",
                                       @"trackMem9:",@"3",
                                       @"clearCopyDown",@"-3",
                                       @"trackMem9:",@"4",
                                       @"clearCopyDown",@"-4",
                                       @"trackMem9:",@"5",
                                       @"clearCopyDown",@"-5",
                                       @"trackMem9:",@"6",
                                       @"clearCopyDown",@"-6",
                                       @"trackMem9:",@"7",
                                       @"clearCopyDown",@"-7",
                                       @"trackMem9:",@"8",
                                       @"clearCopyDown",@"-8",
                                       @"trackMem9:",@"9",
                                       @"clearCopyDown",@"-9",
                                       @"trackMem9:",@"10",
                                       @"clearCopyDown",@"-10",
                                       @"trackMem9:",@"11",
                                       @"clearCopyDown",@"-11",
                                       @"trackMem9:",@"12",
                                       @"clearCopyDown",@"-12",
                                       @"trackMem9:",@"13",
                                       @"clearCopyDown",@"-13",
                                       @"trackMem9:",@"14",
                                       @"clearCopyDown",@"-14",
                                       @"trackMem9:",@"15",
                                       @"clearCopyDown",@"-15",
                                       @"trackMem9:",@"16",
                                       @"clearCopyDown",@"-16",
                                       @"trackMem9:",@"17",
                                       @"clearCopyDown",@"-17",
                                       @"trackMem9:",@"18",
                                       @"clearCopyDown",@"-18",
                                       @"trackMem9:",@"19",
                                       @"clearCopyDown",@"-19",
                                       @"trackMem9:",@"20",
                                       @"clearCopyDown",@"-20",
                                       @"trackMem9:",@"21",
                                       @"clearCopyDown",@"-21",
                                       @"trackMem9:",@"22",
                                       @"clearCopyDown",@"-22",
                                       @"trackMem9:",@"23",
                                       @"clearCopyDown",@"-23",
                                       @"trackMem9:",@"24",
                                       @"clearCopyDown",@"-24",
                                       @"trackMem9:",@"25",
                                       @"clearCopyDown",@"-25",
                                       @"trackMem9:",@"26",
                                       @"clearCopyDown",@"-26",
                                       @"trackMem9:",@"27",
                                       @"clearCopyDown",@"-27",
                                       @"trackMem9:",@"28",
                                       @"clearCopyDown",@"-28",
                                       @"trackMem9:",@"29",
                                       @"clearCopyDown",@"-29",
                                       @"trackMem9:",@"30",
                                       @"clearCopyDown",@"-30",
                                       @"trackMem9:",@"31",
                                       @"clearCopyDown",@"-31",
                                       
                                       @"recordToComposite:",@"32",
                                       @"pixShowHide:",@"33",
                                       @"toggleShowSixteen",@"34",    //
                                       @"overlayKey:",@"35",
                                       @"overlayKey:",@"-35",
//                                       @"blackCueBlack",@"36",
                                       @"inPastSwitching",@"37",
                                       @"nextScreen",@"38",
//                                       @"nextPunch",@"39",
                                       @"linkCompAndPbRouting",@"40",
                                       @"toggleOpaque",@"41",
                                       
                                       @"toggleStreamer",@"42", //1.00.23
                                       @"togglePunch",@"43",    //1.00.23
                                       @"toggleBeeps",@"44",    //1.00.23
                                       @"toggleInhibitStreamerInPlayback",@"45",    //1.00.23
//                                       @"toggleUseAltGuideInRecord",@"46",    //1.00.23
//                                       @"showSixteenTracks:",@"47",    //1.00.23, does work with :
                                       
                                       @"toggleLoop2:",@"60",   // button tag 60
                                       @"toggleLoop2:",@"61",   // button tag 61
                                       @"triggerStreamerCompanion:",@"62",   // trigger streamer from StreamDeck
                                       @"testButton:",@"63",   // checking X-Key LEDS
                                       @"offMode",@"64",   // Reh/Rec/PB off
                                       @"stopAndCancelModes",@"65",   // logic is hung, get out of it (if this happens, fix the problem)
                                       @"cycleButton",@"66", // cycle
                                       @"dialogInClipName",@"67", // cycle
                                       @"notesInClipName",@"68", // cycle
                                       @"characterInTrackName",@"69", // cycle
                                       @"pictureMode:",@"70", // cycle
                                       @"pictureMode:",@"71", // cycle
                                       @"pictureMode:",@"72", // cycle
                                       @"talkback:",@"73", // talkback a
                                       @"talkback:",@"-73", // talkback a trailing edge
                                       @"talkback:",@"74", // talkback b
                                       @"talkback:",@"-74", // talkback b trailing edge
                                       @"autoslate:",@"75", // autoslate
                                       @"autoslate:",@"-75", // autoslate trailing edge
                                       @"captureFirstLineInRehearse:",@"76", // talkback a trailing edge
                                       @"muteForDial:",@"77",
//                                       @"remoteDelay:",@"-77",
                                       @"readLog",@"78",
                                       @"showAllCols",@"79",
                                       @"useAnnunciatorColor",@"80",
                                       @"toggleSnoopAuto",@"81",
                                       @"toggleCueIdInSlate",@"82",    //CueID
                                       @"sampleRate:",@"83",    //CueID
                                       @"sampleRate:",@"84",    //CueID
                                       @"sampleRate:",@"85",    //CueID
                                       @"muteAll",@"86", // mute all
                                       @"muteForDial:",@"87", // mute control room
                                       @"muteForDial:",@"88", // mute stage
                                       @"muteForDial:",@"89", // mute actor
                                       @"muteForDial:",@"90", // mute editor
                                       @"dimControlRoom",@"91", // dim control room
                                       @"dial:",@"92", // dial 1 service, button down
                                       @"dial:",@"-92", // dial 1 service, button up
                                       @"dial:",@"192", // dial 1 service, rotate right
                                       @"dial:",@"-192", // dial 1 service, rotate left
                                       @"dial:",@"93", // dial 1 service, button down
                                       @"dial:",@"-93", // dial 1 service, button up
                                       @"dial:",@"193", // dial 1 service, rotate right
                                       @"dial:",@"-193", // dial 1 service, rotate left
                                       @"dial:",@"94", // dial 1 service, button down
                                       @"dial:",@"-94", // dial 1 service, button up
                                       @"dial:",@"194", // dial 1 service, rotate right
                                       @"dial:",@"-194", // dial 1 service, rotate left
                                       @"dial:",@"95", // dial 1 service, button down
                                       @"dial:",@"-95", // dial 1 service, button up
                                       @"dial:",@"195", // dial 1 service, rotate right
                                       @"dial:",@"-195", // dial 1 service, rotate left
                                       @"dial:",@"96", // dial 1 service, button down
                                       @"dial:",@"-96", // dial 1 service, button up
                                       @"dial:",@"196", // dial 1 service, rotate right
                                       @"dial:",@"-196", // dial 1 service, rotate left
                                       @"dial:",@"97", // dial 1 service, button down
                                       @"dial:",@"-97", // dial 1 service, button up
                                       @"dial:",@"197", // dial 1 service, rotate right
                                       @"dial:",@"-197", // dial 1 service, rotate left
                                       @"dial:",@"98", // dial 1 service, button down
                                       @"dial:",@"-98", // dial 1 service, button up
                                       @"dial:",@"198", // dial 1 service, rotate right
                                       @"dial:",@"-198", // dial 1 service, rotate left
                                       @"dial:",@"99", // dial snoop service, button down
                                       @"dial:",@"-99", // dial snoop service, button up
                                       @"dial:",@"199", // dial snoop service, rotate right
                                       @"dial:",@"-199", // dial snoop service, rotate left
                                       @"dial:",@"100", // dial 1 service, button down
                                       @"dial:",@"-100", // dial 1 service, button up
                                       @"dial:",@"200", // dial 1 service, rotate right
                                       @"dial:",@"-200", // dial 1 service, rotate left
                                       @"dial:",@"101", // dial 1 service, button down
                                       @"dial:",@"-101", // dial 1 service, button up
                                       @"dial:",@"201", // dial 1 service, rotate right
                                       @"dial:",@"-201", // dial 1 service, rotate left
                                       @"dial:",@"102", // dial 1 service, button down
                                       @"dial:",@"-102", // dial 1 service, button up
                                       @"dial:",@"202", // dial 1 service, rotate right
                                       @"dial:",@"-202", // dial 1 service, rotate left
                                       @"dial:",@"103", // dial 1 service, button down
                                       @"dial:",@"-103", // dial 1 service, button up
                                       @"dial:",@"203", // dial 1 service, rotate right
                                       @"dial:",@"-203", // dial 1 service, rotate left
                                       @"dial:",@"104", // dial 1 service, button down
                                       @"dial:",@"-104", // dial 1 service, button up
                                       @"dial:",@"204", // dial 1 service, rotate right
                                       @"dial:",@"-204", // dial 1 service, rotate left
                                       @"dial:",@"105", // dial 1 service, button down
                                       @"dial:",@"-105", // dial 1 service, button up
                                       @"dial:",@"205", // dial 1 service, rotate right
                                       @"dial:",@"-205", // dial 1 service, rotate left
                                       @"dial:",@"106", // dial 1 service, button down
                                       @"dial:",@"-106", // dial 1 service, button up
                                       @"dial:",@"206", // dial 1 service, rotate right
                                       @"dial:",@"-206", // dial 1 service, rotate left
                                       @"dial:",@"107", // dial 1 service, button down
                                       @"dial:",@"-107", // dial 1 service, button up
                                       @"dial:",@"207", // dial 1 service, rotate right
                                       @"dial:",@"-207", // dial 1 service, rotate left

                                       @"muteForDial:",@"108", // mute snoop
                                       
                                       @"talkback:",@"109", // talkback c
                                       @"talkback:",@"-109", // talkback c trailing edge
                                       @"talkback:",@"110", // talkback d
                                       @"talkback:",@"-110", // talkback d trailing edge
                                       @"linkRemoteActorToggle",@"111",
                                       @"linkRemoteEditorToggle",@"112",
                                       @"boomRecOnlineLocalToggle",@"113",
                                       @"boomRecOnlineRemoteToggle",@"114",
                                       
                                       // skip 128 because XKeys uses -128 to signal -0

                                       nil];
    
    // make dictionary of jump tables
    _unitIDDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
                         unit_8_dictionary,@"8",
                         unit_9_dictionary,@"9",
                         nil];
    
    _unitIDDictionary_shifted = [[NSDictionary alloc] initWithObjectsAndKeys:
                                 unit_8_dictionary_shifted,@"8",
                                 nil];
    
}
-(void)boomRecOnlineLocalToggle{
    
    bool state = [[NSUserDefaults standardUserDefaults] boolForKey:@"boomRecOnlineLocal"];
    [[NSUserDefaults standardUserDefaults] setBool:!state forKey:@"boomRecOnlineLocal"];

}
-(void)boomRecOnlineRemoteToggle{
    
    bool state = [[NSUserDefaults standardUserDefaults] boolForKey:@"boomRecOnlineRemote"];
    [[NSUserDefaults standardUserDefaults] setBool:!state forKey:@"boomRecOnlineRemote"];
}
-(void)linkRemoteActorToggle{
    
    bool state = [[NSUserDefaults standardUserDefaults] boolForKey:@"linkRemoteActor"];
    [[NSUserDefaults standardUserDefaults] setBool:!state forKey:@"linkRemoteActor"];
    
}
-(void)linkRemoteEditorToggle{
    
    bool state = [[NSUserDefaults standardUserDefaults] boolForKey:@"linkRemoteEditor"];
    [[NSUserDefaults standardUserDefaults] setBool:!state forKey:@"linkRemoteEditor"];

}
-(void)linkCompAndPbRouting{
    NSString *key = @"linkCompAndPbRouting";
    NSInteger state = [[NSUserDefaults standardUserDefaults] boolForKey:key];
    
    state = state == true ? false : true;
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:state forKey:key];
    
    // refresh the text for Playback keys
//    [_matrixWindowController aipShowOsc];
    
//    [self onLinkCompAndPbRouting: nil];
}
//-(void)nextPunch{
//    // select TextWindowServer next punch
//    [_textWindowClient txMsg:@"nextPunch"]; // v1.00.23
//}
-(void)nextScreen{
    // move TextWindowServer to the next monitor
    // this is the only place it is stored, don't want missing monitor
    // causing a store
    NSInteger sel = _overlayWindowController.screenSelector + 1;
    sel %= NSScreen.screens.count;
 
    [[NSUserDefaults standardUserDefaults]setInteger:sel forKey:@"OVERLAY_KEYscreenSelector"];
    
    _overlayWindowController.screenSelector = sel;   // v2.00.00
}
-(void)inPastSwitching{
    
    NSString *key = @"enInPastSwitching";
    NSInteger state = [[NSUserDefaults standardUserDefaults] boolForKey:key];
    
    state = state == true ? false : true;
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:state forKey:key];

//    [self onEnInPastSwitching:nil];
}

-(void)onAddCue{
    
    Document *doc = [self topDocument];
    [doc onAddCueButton:nil];
}

-(void)onAhead{
    
    if (_cycleMotion == CYCLE_MOTION_IDLE) {    // locked out if cycling
        [_matrixWindowController setAheadInPast:MODE_AHEAD];

    }
    
}
-(void)onIn{
    // github tickle
    if (_cycleMotion == CYCLE_MOTION_IDLE) {    // locked out if cycling
        [_matrixWindowController setAheadInPast:MODE_IN];

    }
    
}
-(void)onPast{
    
    if (_cycleMotion == CYCLE_MOTION_IDLE) {    // locked out if cycling
        [_matrixWindowController setAheadInPast:MODE_PAST];

    }
}
-(void)showWindows{
    
    NSWindow *window = [_editorWindowController window];
    
    if(window.isVisible) return;
    
    [self onDocumentWindow:nil];
    [self onEditorWindow:nil];
    [self onMonitorWindow:nil];
    [self onOverlayWindow:nil];
    
}
-(void)inhibitStreamerToggle{
    
    [_editorWindowController setInhibitStreamer:![_editorWindowController inhibitStreamer]];
}
-(void)zeroFeet{
    
    // set current location to zero feet
    //    [_adrClientWindowController txMsg:@"mainCounterFormat 0"];  // set main counter to tc
    [_adrClientWindowController txMsg:[NSString stringWithFormat:@"zeroFeet"]]; // set feet to zero
    
}
//-(void)toggleAutoPlay:(NSString*)msg{
//    
//    Document *doc = [self topDocument];
//    
//    [doc setAutoPlay:!doc.autoPlay];    
//    
//}
-(void)mainOutputs{
    
    [_adrClientWindowController txMsg:@"mem 19"];
    
}
-(void)verbAndFutz{
    
    [_adrClientWindowController txMsg:@"mem 21"];
    
}
-(void)cleanupMono{
    
    [_adrClientWindowController txMsg:@"mem 300"];
    
}
-(void)cleanupStereo{
    
    [_adrClientWindowController txMsg:@"mem 301"];
    
}
//-(void)zeroFeetAtTc:(NSString*)tc{
//    
//    // if we are in ft/fr, calculate the tc for our current position, set tc
//    
////    unsigned char displayFmt = [_midiClient getControlTableByte:0x16];
////    Document *doc = [self topDocument];
//    //[doc setTimeCodeStart:tc];
//    
////    if(displayFmt & 2){   // we are in ft/fr, set tc
//    
////        [self setTimeCodeStart:tc];
//    
////        int frs = [_tcc ftToBinary:doc.ctr];
////        frs += [_tcc tcToBinary:tc withType:TCTYPE_24]; // FIXME
////        NSString *tc = [_tcc binaryToTc:frs withType:TCTYPE_24];    // FIXME
//        NSArray *array = [tc componentsSeparatedByString:@":"];
//       
//        [_adrClientWindowController txMsg:[NSString stringWithFormat:@"setZeroFeetAtTc %@%@%@%@",array[0],array[1],array[2],array[3]]];
//        
////    }
//}
-(void)theHour:(NSEvent*)event{
    
    if(![_ptHui isStop]) return;   // exit if we are not stopped or there is no cue
    Document *doc = [self topDocument];
    
    NSInteger keyNumber = event.data1;
    
    // set the hour for feet/frame cue sheets
    unsigned char displayFmt = [_ptHui getDisplayFmt];  // [0] tc [1] ft/fr
    
    switch (keyNumber) {
            
            // only set tc starts if in feet/frame
        case 14: if(displayFmt & 2) [doc setTimeCodeStart:@"01:00:00:00"]; break;
        case 13: if(displayFmt & 2) [doc setTimeCodeStart:@"04:00:00:00"]; break;
        case 12: if(displayFmt & 2) [doc setTimeCodeStart:@"07:00:00:00"]; break;
        case 22: if(displayFmt & 2) [doc setTimeCodeStart:@"02:00:00:00"]; break;
        case 21: if(displayFmt & 2) [doc setTimeCodeStart:@"05:00:00:00"]; break;
        case 20: if(displayFmt & 2) [doc setTimeCodeStart:@"08:00:00:00"]; break;
        case 30: if(displayFmt & 2) [doc setTimeCodeStart:@"03:00:00:00"]; break;
        case 29: if(displayFmt & 2) [doc setTimeCodeStart:@"06:00:00:00"]; break;
        case 28: if(displayFmt & 2) [doc setTimeCodeStart:@"09:00:00:00"]; break;
        case 15:
            
            if(displayFmt & 2){
                
                [_adrClientWindowController txMsg:@"mainCounterFormat\t0"];
                
            }else {
                
                [_adrClientWindowController txMsg:@"mainCounterFormat\t1"];
                
            }
            
        default:
            break;
    }
    
}
-(void)captureSample:(NSEvent*)event{
    // turn off loop playback 7/23/15
    [_adrClientWindowController txMsg:@"loopPlaybackOff"];
    
    // v1.00.19
    //    unsigned char msg[] = {0xb0,12,0};//before PT 11, V1.00.19
    unsigned char msg[] = {0xb0,CC_CAPTURE_SAMPLE,0};//after PT 11, V1.00.19
    // FIXME midi fix should there be a launch pad tx here?
    //    msg[0] = 0xb0; msg[1] = 12; msg[2] = 0;
    [_lpMini.accMidi.midiClient midiTx:[NSData dataWithBytes:msg length:3]];
    //    [_midiClient txMidiToAcc:[NSData dataWithBytes:msg length:3]];
    [_ptHui onPlay];
}
-(void)captureFill:(NSEvent*)event{
    /*
     Select area you want to use for fill in Pro Tools
     
     Shift+"Quick Preview" pressed
     
     Set "custom fill" flag to ON and LIGHT the last round button on the MIDI panel (the one we couldn't use for our mute toggling) "H" on the panel in red
     
     Send MIDI CC13 with value 0, and then send play command to Pro Tools.  (The 0 value puts the recorder plug-in in to an "auto mode" where it will start recording when Pro Tools goes in to play).
     
     Pro Tools will stop when it reaches end of selection, and the plug-in recorder will stop on its own.
     
     Send MIDI CC13, with value 55 when you get a stop tally from Pro Tools. (This takes the plug-in out of "auto mode" and puts it in a hard stop.)
     
     */
    
    // turn off loop playback 7/23/15
    [_adrClientWindowController txMsg:@"loopPlaybackOff"];
    [_lpMini micSet:@"90787f" :true];
    //_micDictionary[@"90787f"] = MIC_ON;
//    [self sendToMicAccessoryForKey:@"90787f"];
//    micState[CUSTOM_FILL_INDEX] = 127;    // 2.00.00 state is in _micDictionary[@"90787f"] = MIC_ON;
//    unsigned char msg[] = {0x90,CUSTOM_FILL_INDEX,COLOR_AIP_RED};
//    //    [_launchPadMiniClient midiTx:[NSData dataWithBytes:msg length:3]]; // 12/14/16 change to have 2 heads for Tommy
//    [self launchPadMiniTx:[NSData dataWithBytes:msg length:3]];
    //    [_midiClient txMidiToHead:[NSData dataWithBytes:msg length:3]];  // light the 'H' button (custom fill indicator)
    unsigned char msg[] = {0xb0,CC_CAPTURE_FILL,0};
//    msg[0] = 0xb0; msg[1] = 13; msg[2] = 0;
    [_lpMini.accMidi.midiClient midiTx:[NSData dataWithBytes:msg length:3]];
    //    [_midiClient txMidiToAcc:[NSData dataWithBytes:msg length:3]];
    
//    if(_rehearseCaptureWindowController) [((RehearseCaptureWindowController*)_rehearseCaptureWindowController) setEnableCaptureFill:true];   // 6/22/15
    
    [_ptHui onPlay];
    
}
-(void)captureFillStop{
    
    //    NSLog(@"captureFillStop");
    
    unsigned char msg[] = {0xb0,CC_CAPTURE_FILL,55};
    [_lpMini.accMidi.midiClient midiTx:[NSData dataWithBytes:msg length:3]];
    //    [_midiClient txMidiToAcc:[NSData dataWithBytes:msg length:3]];  // stop the plug-in recorder
    
    msg[1] = CC_CAPTURE_SAMPLE;
    [_lpMini.accMidi.midiClient midiTx:[NSData dataWithBytes:msg length:3]];
    //    [_midiClient txMidiToAcc:[NSData dataWithBytes:msg length:3]];  // stop the plug-in recorder
    
    // 6/22/15
    
//    if(_rehearseCaptureWindowController) [((RehearseCaptureWindowController*)_rehearseCaptureWindowController) stopCapture];
    
}
//-(void)setPrerollLEDs:(NSString*)preroll{
//    
//    [self txOsc:[NSString stringWithFormat:@"prerollIndex %ld",(long)_prerollIndex]];    //
//}
-(void)preroll:(NSEvent*)event{
    
    switch (event.data1) {
            
        case 1: self.prerollIndex = 0;  break;
        case 9: self.prerollIndex = 1;  break;
        case 17: self.prerollIndex = 2;  break;
        case 25: self.prerollIndex = 3;  break;
        case 33: self.prerollIndex = 4;  break;
            
        default:
            break;
    }

}
-(void)calcPrerollToHere:(NSString*)tc{
    
    Document *doc = [self topDocument];
    if(doc == nil || doc.recordCycleDictionary == nil){
        return;
    }
    
    NSString *start = [_tcf tcForString:[doc startForDictionary]];
    tc = [_tcf tcForString:tc];
    
    NSString *preroll = [_tcc subtractTc:tc fromTc:start withType:self.getTcType];

    NSString *prerollFt = [_tcc tcToFt:preroll];
    [_editorWindowController setPreroll:[self getDisplayFormat] == DISPLAY_FMT_FT ? prerollFt : preroll];
    
}


-(void)clearCopyDown{
    // trailing edge of track selector came before key timeout, do not copy down
    if(_trackToCompCopyOneshot.isValid)[_trackToCompCopyOneshot invalidate];
}
// guideMem: outputMem:
-(void)guideMem:(NSEvent*)event{
    [_adrClientWindowController txMsg:@"mem 82"];
}
-(void)outputMem:(NSEvent*)event{
    [_adrClientWindowController txMsg:@"mem 19"];
}
-(void)storeEndTc:(NSEvent*)event{
    
    // capture current position to end tc
    [_adrClientWindowController txMsg:@"jxaGetProtoolsPosition 7"];
    
}
-(void)deleteCurrentCue:(NSEvent*)event{
    
    Document *doc = [self topDocument];
    if(doc == nil){return;}

    [doc deleteSelectedRows];
}
// : streamer1:
-(void)streamer1Locate:(NSEvent*)event{
    
    Document *doc = [self topDocument];
    if(doc == nil){return;}

    NSString *tc = [doc.recordCycleDictionary objectForKey:@"streamer1"];
    [self locate:tc];

}
-(void)streamer2Locate:(NSEvent*)event{
    
    Document *doc = [self topDocument];
    if(doc == nil){return;}

    NSString *tc = [doc.recordCycleDictionary objectForKey:@"streamer2"];
    [self locate:tc];

}
-(void)streamer3Locate:(NSEvent*)event{
    
    Document *doc = [self topDocument];
    if(doc == nil){return;}

    NSString *tc = [doc.recordCycleDictionary objectForKey:@"streamer3"];
    [self locate:tc];

}
-(void)streamer4Locate:(NSEvent*)event{
    
    Document *doc = [self topDocument];
    if(doc == nil){return;}

    NSString *tc = [doc.recordCycleDictionary objectForKey:@"streamer4"];
    [self locate:tc];

}
-(void)streamer5Locate:(NSEvent*)event{
    
    Document *doc = [self topDocument];
    if(doc == nil){return;}

    NSString *tc = [doc.recordCycleDictionary objectForKey:@"streamer5"];
    [self locate:tc];

}
-(void)streamer6Locate:(NSEvent*)event{
    
    Document *doc = [self topDocument];
    if(doc == nil){return;}

    NSString *tc = [doc.recordCycleDictionary objectForKey:@"streamer6"];
    [self locate:tc];

}

-(void)streamer1:(NSEvent*)event{
    
    [_adrClientWindowController txMsg:@"jxaGetProtoolsPosition 8"];

}
-(void)streamer2:(NSEvent*)event{
    
    [_adrClientWindowController txMsg:@"jxaGetProtoolsPosition 9"];

}
-(void)streamer3:(NSEvent*)event{
    
    [_adrClientWindowController txMsg:@"jxaGetProtoolsPosition 10"];
}
-(void)streamer4:(NSEvent*)event{
    
    [_adrClientWindowController txMsg:@"jxaGetProtoolsPosition 11"];
}
-(void)streamer5:(NSEvent*)event{
    
    [_adrClientWindowController txMsg:@"jxaGetProtoolsPosition 12"];
}
-(void)streamer6:(NSEvent*)event{
    
    [_adrClientWindowController txMsg:@"jxaGetProtoolsPosition 13"];
}

-(void)deleteStreamers:(NSEvent*)event{
    
    Document *doc = [self topDocument];
    if(doc == nil){return;}

    [doc.recordCycleDictionary setObject:@"" forKey:@"streamer1"];
    [doc.recordCycleDictionary setObject:@"" forKey:@"streamer2"];
    [doc.recordCycleDictionary setObject:@"" forKey:@"streamer3"];
    [doc.recordCycleDictionary setObject:@"" forKey:@"streamer4"];
    [doc.recordCycleDictionary setObject:@"" forKey:@"streamer5"];
    [doc.recordCycleDictionary setObject:@"" forKey:@"streamer6"];
    
    [self txOsc:@"led 8,41,false"];
    [self txOsc:@"led 8,49,false"];
    [self txOsc:@"led 8,57,false"];
    [self txOsc:@"led 8,42,false"];
    [self txOsc:@"led 8,50,false"];
    [self txOsc:@"led 8,58,false"];
}
-(void)pbRouting:(NSEvent*)event{
    
    [_adrClientWindowController txMsg:@"mem 18"];
    
}
-(void)prerollDown:(NSEvent*)event{
    // decrement preroll by 1 second, clip at 3 seconds
    Document *doc = [self topDocument];
    if(!doc) return;
    
    NSString *preroll = [_tcf tcForString:[_editorWindowController preroll]];
    preroll = [_tcc subtractTc:@"00:00:01:00" fromTc:preroll withType:(int)doc.tcType];
    NSLog(@"new preroll: %@",preroll);
    if([_tcc compareTc:preroll fromTc:@"00:00:03:00" withType:(int)doc.tcType] < 0) preroll = @"00:00:03:00";   // 2 seconds minimum
    
    [_editorWindowController setPreroll:preroll];
    
    
}
-(void)prerollUp:(NSEvent*)event{
    
//    if([_editorWindowController startFromPrerollTc]){
//
//        [_editorWindowController setStartFromPrerollTc:nil];   // preroll up button clears the startFromPrerollTc if there is one
//        return;
//    }
    
    // increment preroll by 1 second, clip at 10 seconds
    Document *doc = [self topDocument];
    if(!doc) return;
    
    NSString *preroll = [_tcf tcForString:[_editorWindowController preroll]];
    preroll = [_tcc addTc:@"00:00:01:00" toTc:preroll withType:(int)doc.tcType];
    NSLog(@"new preroll: %@",preroll);
    //    if([_tcc compareTc:preroll fromTc:@"00:00:10:00" withType:(int)doc.tcType] > 0) preroll = @"00:00:10:00";   // 10 seconds max
    
    [_editorWindowController setPreroll:preroll];
}
-(void)plusFrames:(NSEvent*)event{
    
    // send -> to protools, key code 124
    [_adrClientWindowController txMsg:@"keyCode 124"];
    
}
-(void)locateToInpoint:(NSEvent*)event{
    
    Document *doc = [self topDocument];
    
    if(doc == nil || doc.recordCycleDictionary == nil){return;}
    
    NSString *start = doc.startForDictionary;  // can be ft/fr
    if(start){
        [self locate:start];
    }
    
}
-(void)inputBussing:(NSEvent*)event{
    
    // Recall memory Location 11
    [_adrClientWindowController txMsg:@"mem 11"];
    
}
-(void)wildSyncSelect:(NSEvent*)event{
    
    Document *doc = [self topDocument];
    if (!doc.recordCycleDictionary) return;
    
    NSString *start = doc.startTc;

    [_adrClientWindowController txMsg:[NSString stringWithFormat:@"jxaWildSyncSelect %@",start]];   // cmd-c script to start the wild sync select process
}
-(void)replaceSelect:(NSEvent*)event{
    
    [_adrClientWindowController txMsg:@"replaceSelect"];
}
-(void)pixShowHide:(NSEvent*)event{
    
    bool hidePix = !_overlayWindowController.viewController.streamer.hidePix;
    _overlayWindowController.viewController.streamer.hidePix = hidePix;
//    [self setLEDForUnitID:9 :33 :hidePix]; // 2.00.00
//    [_xKey setLEDForUnitID:8 :10+80 :hidePix]; // 2.10.02

}

-(void)keyOneshotService{
    
    Document *doc = [self topDocument];
    
    if(doc && doc.recordCycleDictionary){
        
        NSString *start = [_tcc addBinary:(int)_matrixWindowController.trimFrames toTc:doc.startForDictionary withType:(int)doc.tcType];
        
        [self locate:start :@"6"];  // locate -> getProtoolsPosition -> quick preview
    }
}
-(void)sample:(NSEvent*)event{
    // TODO
    unsigned char msg[] = {0xb0,CC_PLAY_SAMPLE,127};    // on
    [_lpMini.accMidi.midiClient midiTx:[NSData dataWithBytes:msg length:3]];
    //    [_midiClient txMidiToAcc:[NSData dataWithBytes:msg length:3]];
    
    // 6/22/15
    
//    if(_rehearseCaptureWindowController) [(RehearseCaptureWindowController*)_rehearseCaptureWindowController onPlay:nil];
    
}
-(void)sampleTrailingEdge:(NSEvent*)event{
    
    unsigned char msg[] = {0xb0,CC_PLAY_SAMPLE,55}; // off
    [_lpMini.accMidi.midiClient midiTx:[NSData dataWithBytes:msg length:3]];
    //    [_midiClient txMidiToAcc:[NSData dataWithBytes:msg length:3]];
    
//    if(_rehearseCaptureWindowController) [(RehearseCaptureWindowController*)_rehearseCaptureWindowController onStop:nil];
}

-(void)quickPreview:(NSEvent*)event{
    
    // locate to the in point minus the trim frames at clip start, play
    //--Hold down for half a second, it locates to the pre-edit location and plays (may need to stop first before the locate for that to work, not sure).  Press and hold again and it repeats the play from the pre-edit location.  Tap the Quick Preview button while it's playing, it stops.

    // no quick preview if in cycle
    if(_cycleMode != CYCLE_MODE_IDLE){
        return;
    }
    
    [_ptHui onStop];    // always stops 
    
    [self setKeyOneshot:[NSTimer scheduledTimerWithTimeInterval:.3 target: self selector:@selector(keyOneshotService) userInfo:nil repeats: NO]];
    
}
-(void)quickPreviewTrailingEdge:(NSEvent*)event{
    
    [_keyOneshot invalidate];
}

-(void)showAheadInPast{
    // v1.00.23
    int aip = [_matrixWindowController aheadInPast];
    [self txOsc:[NSString stringWithFormat:@"aheadInPast %d",aip]];    // track selector
    
    
}
//-(void)showFmtLEDs{
//    
////    [self setLEDForUnitID:5 :64 :[_matrixWindowController numRecTracksTag] == 0];
////    [self setLEDForUnitID:5 :65 :[_matrixWindowController numRecTracksTag] == 1];
////    [self setLEDForUnitID:5 :66 :[_matrixWindowController numRecTracksTag] == 2];
////    [self setLEDForUnitID:5 :72 :[_matrixWindowController numRecTracksTag] == 3];
////    [self setLEDForUnitID:5 :73 :[_matrixWindowController numRecTracksTag] == 4];
////    [self setLEDForUnitID:5 :74 :[_matrixWindowController numRecTracksTag] == 5];
//    
////    [self setLEDForUnitID:8 :64 :[_matrixWindowController numRecTracksTag] == 0];
////    [self setLEDForUnitID:8 :72 :[_matrixWindowController numRecTracksTag] == 1];
////    [self setLEDForUnitID:8 :65 :[_matrixWindowController numRecTracksTag] == 2];
////    [self setLEDForUnitID:8 :73 :[_matrixWindowController numRecTracksTag] == 3];
////    [self setLEDForUnitID:8 :66 :[_matrixWindowController numRecTracksTag] == 4];
////    [self setLEDForUnitID:8 :74 :[_matrixWindowController numRecTracksTag] == 5];
//    // TODO: 66,74 are actually on the shifted page
//    [self txOsc:[NSString stringWithFormat:@"monitor %ld",[_matrixWindowController numRecTracksTag]]];    // track selector
//    
//}
//-(void)showFmt:(NSInteger)fmt{
//
//    if (_cycleMotion != CYCLE_MOTION_IDLE) {
//
//        [NSApp activateIgnoringOtherApps:YES];  // brings our alert to the front
//
//        NSAlert *alert =  [[NSAlert alloc] init];
//        alert.messageText = @"select monitor format only when stopped";
////        NSAlert *alert = [NSAlert alertWithMessageText:@"select monitor format only when stopped" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
//        [alert runModal];
//
//        return;
//    }
//    // rename the track
//    [_matrixWindowController setNumRecTracksTag:fmt];
//}

-(void)showMono:(NSEvent*)event{
    
    _matrixWindowController.numRecTracksTag = 0;
}
-(void)showStereo:(NSEvent*)event{
    _matrixWindowController.numRecTracksTag = 1;
}
-(void)showLCR:(NSEvent*)event{
    _matrixWindowController.numRecTracksTag = 2;
}
-(void)show4x:(NSEvent*)event{
    _matrixWindowController.numRecTracksTag = 3;
}
-(void)show6x:(NSEvent*)event{
    _matrixWindowController.numRecTracksTag = 4;
}
-(void)show8x:(NSEvent*)event{
    _matrixWindowController.numRecTracksTag = 5;
}
-(void)stub:(NSEvent*)event{
    
}
//inpointPlusOne inpointMinusOne
-(void)inpointPlusOne:(NSEvent*)event{
    
    Document *doc = [self topDocument];
    if(doc)[doc inpointTrimFrames:1];
    
}
-(void)inpointMinusOne:(NSEvent*)event{
    
    Document *doc = [self topDocument];
    if(doc)[doc inpointTrimFrames:-1];
    
}
-(void)inpointPlusTen:(NSEvent*)event{
    
    Document *doc = [self topDocument];
    if(doc)[doc inpointTrimFrames:10];
    
}
-(void)inpointMinusTen:(NSEvent*)event{
    
    Document *doc = [self topDocument];
    if(doc)[doc inpointTrimFrames:-10];
    
}
-(void)numberPadStore:(NSEvent*)event{
    
    if(_entryState == ENTRY_ACTIVE){
        
        _entryState = ENTRY_IDLE;
        [_adrClientWindowController txMsg:@"keyStroke \r"];
        
    }
    Document *doc = [self topDocument];
    
    if(doc.tableContents.count == 0){
        // no items, add a cue
        // cueCtr
        [self getCueName:nil];
        return;
    }

    [_adrClientWindowController txMsg:@"jxaGetProtoolsPosition 0"];    // 0 is msg to do the store when the value is returned
}
-(void)numberPad5:(NSEvent*)event{
    
    // unitID 8 is the only one with a keyboard
    NSDictionary *dict = @{
         @12    :    @"7"
        ,@13    :    @"4"
        ,@14    :    @"1"
        ,@15    :    @"0"
        ,@20    :    @"8"
        ,@21    :    @"5"
        ,@22    :    @"2"
        ,@28    :    @"9"
        ,@29    :    @"6"
        ,@30    :    @"3"
        ,@261   :    @"00"
        ,@31    :    @"\r"
    };
    
    NSNumber *num = [NSNumber numberWithInteger:event.data1];   // key number
    
    NSString *digits = dict[num];
    
    if(digits){
        
        bool isReturnKey = [digits isEqualToString:@"\r"];
        
        if(_entryState == ENTRY_IDLE && !isReturnKey){
            [_adrClientWindowController txMsg:[NSString stringWithFormat:@"keyStroke *%@",digits]];
            _entryState = ENTRY_ACTIVE;
        }else if(_entryState == ENTRY_ACTIVE){
            [_adrClientWindowController txMsg:[NSString stringWithFormat:@"keyStroke %@",digits]];
        }
        if(isReturnKey){
            _entryState = ENTRY_IDLE;
        }
    }
}

-(void)showArmedService{
    
    [_matrixWindowController setRehRecPb:MODE_CONTROL_PLAYBACK];    // 2.10.02 because changing REH/REC/PB selects memory 0
    // Evan: I’m using rehRecPb to control the video switcher that feeds zoom.
    // that is MODE_CONTROL_PLAYBACK_PENDING
    [self txOsc:[NSString stringWithFormat:@"rehRecPb %d",MODE_CONTROL_PLAYBACK_PENDING]];    // Tami special request 2.10.02

    [_matrixWindowController setMemoryTag:1];   // long push of 'show armed'
}
-(void)showArmed:(NSEvent*)event{
    
    //    NSLog(@"showArmed");
    // delay shortened from .3 to .2 8/13/15
    // but we get a call to memoryFromMatrix:
    // it has something to do with bringing PT to the front
    [self setShowArmedOneshot:[NSTimer scheduledTimerWithTimeInterval:0.3 target: self selector:@selector(showArmedService) userInfo:nil repeats: NO]];
    
    // perform normal function, there is an additional function if the button is held
    [self selectTrackMemory:_lastRecordTrack];
    [_adrClientWindowController txMsg:@"keyCode 19"];   // recall zoom memory 2
    //showArmedOneshot
    
}
-(void)showArmedTrailingEdge:(NSEvent*)event{
    
    //    NSLog(@"showArmedTrailingEdge");
    if(_showArmedOneshot.isValid){
        
        [_showArmedOneshot invalidate];
    }
    
}
//-(void)prerollHere:(NSEvent*)event{
//
//    Document *doc = [self topDocument];
//
//    NSString *ctr = doc.ctr;
//    ctr = [ctr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//
////    NSLog(@"ctr %@",ctr);
//
//    [_editorWindowController setPrerollToHere:ctr];
//}
-(void)recordToComposite:(NSEvent*)event{
    
    Document *doc = [self topDocument];
    doc.recordToComposite = !doc.recordToComposite;
}
-(void)getSession:(NSEvent*)event{
    
    // clear the session so that this does load the log
    _session = nil;
    [self txMsgToAdrClient:@"jxaGetSession"];  // get the session title, may load the log
}
-(void)overlayKey:(NSEvent*)event{
    
    self.overlay = event.data1 > 0;
    
}

-(void)shiftKey:(NSEvent*)event{
    // keyboardIsShifted
    //NSLog(@"_keyboardIsShifted before %d",_keyboardIsShifted);

    if(event.data1 > 0){
        
        _keyboardIsShifted = true;
        [self setLEDForUnitID:(int)event.data2 :(int)event.data1 :true];
        
    }else{
        
        _keyboardIsShifted = false;
        [self setLEDForUnitID:(int)event.data2 :abs((int)event.data1) :false];
        
    }
    //NSLog(@"_keyboardIsShifted after %d",_keyboardIsShifted);

//    [self initUnit_5_LEDs]; // state changes when shifted
}
-(void)escape:(NSEvent*)event{
    // ESCAPE cancels * mode and sends an ESC to protools
    
    
    if(_entryState != ENTRY_IDLE){
        
        _entryState = ENTRY_IDLE;
        
        [self txMsgToAdrClient:@"keyCode 53"];  // ESC 0x35
        
    }
    
    //    [_streamerWindowController forceBlack:false];
    //    [_textWindowClient txMsg:@"hidePix 0"];
//    _overlayWindowController.viewController.streamer.forceBlack = false;
    _overlayWindowController.viewController.streamer.hidePix = false;
    
    [self setCycleMode:CYCLE_MODE_IDLE];
    [_ptHui onStop];
    [self setCycleMotion:CYCLE_MOTION_IDLE];    // do not get hung in CYCLE_MOTION_STOPPING
    
    //    _cutAndPasteIsActive = false;   // need to be able to clear this somewhere
    
}
-(void)getNote:(NSEvent*)event{
    
    NSString *note = [self topDocument].cueNote;
    [self txMsgToAdrClient:[NSString stringWithFormat:@"setNote\t%@",note]];
    
}
-(void)getPreEdit{
    
    NSInteger trimFrames = [_matrixWindowController trimFrames];
    
    [_adrClientWindowController txMsg:[NSString stringWithFormat:@"getPreEdit\t%ld",trimFrames]];
    
}
-(void)getCueName:(NSEvent*)event{
    
    Document *doc = [self topDocument];
    
//    [self setStartFromPrerollTc:nil];
    
    if(!doc) return;
    //NSString *ctr = [doc ctr];
    //if(!ctr || ![_tcc isTc:ctr])
//    [_adrClientWindowController txMsg:@"getProtoolsPosition 3"];    // no action
//
//    [self txMsgToAdrClient:[NSString stringWithFormat:@"setCueName\t%@",[doc cueID]]];
    
    [_adrClientWindowController txMsg:[NSString stringWithFormat:@"setCueName\t%@",[doc cueID]]];   // TODO: 2.00.00 check this
    
}
-(void)getDialog:(NSEvent*)event{
    
    Document *doc = [self topDocument];
    
    if(!doc) return;
    
//    if([doc inhibitGetTrackPos]){
//        
//        [doc setInhibitGetTrackPos:false];  // per Evan 2/11/16
//    }
    
    NSString *dlg = doc.dialogForDictionary;    // dialog for current cue
    
    [self txMsgToAdrClient:[NSString stringWithFormat:@"setDialog\t%@",dlg]];
//    [self txMsgToAdrClient:[NSString stringWithFormat:@"setDialog\t%@",dlg]];
    
}
-(void)missingMethod:(NSEvent*)event{
    NSLog(@"missingMethod key:%d unitID:%d",(int)event.data1,(int)event.data2);
    
}
-(void)txMsgToAdrClient:(NSString*)msg{
    
    if(_adrClientWindowController) [_adrClientWindowController txMsg:msg];
}

-(void)selectTrackMemory:(NSInteger)track{
    
    if(!_adrClientWindowController) return;
    
    NSInteger numRecTracksTag = [_matrixWindowController numRecTracksTag];
    
    track += trackBaseTable[numRecTracksTag];
    NSInteger trackMax = trackBaseTable[numRecTracksTag + 1] - 1; //=
    if(track > trackMax) track = trackMax;
    
    NSString *msg = [NSString stringWithFormat:@"mem %ld",track];
    [_adrClientWindowController txMsg:msg];
    
}
// 2.10.02 16 track display for 6 and 8 track
NSInteger trackBaseTable[] = {41,91,131,151,171,191,211};   //1,2,3,4,6,8 track, end

-(void)trackMem9:(NSEvent*)event{
    
    // companion keys 0-31 are the track selectors, so we don't need to re-map
    
    NSInteger track = event.data1;
//    NSLog(@"trackMem9 track %ld",track);

    [self setCurrentTrack:track];

    [self setLastRecordTrack:track]; // V1.00.10 for Tommy, pressing 'show single track' will show the track just selected on the stick
    // 02/05/23 we do want the track selector to work if there is no cue selected, this avoids 'no cue selected' error messages
    Document *doc = self.topDocument;
    if(!doc || !doc.recordCycleDictionary){
        return;
    }
    
    // turned off 2.10.02, Evan says no one uses this, he needs long press for something else
    // a oneshot to copy the track to the comp track if the button is held for more than .3 seconds
    //trackToCompCopyOneshot
//    if(_trackToCompCopyOneshot && _trackToCompCopyOneshot.isValid) [_trackToCompCopyOneshot invalidate];
//    [self setTrackToCompCopyOneshot:[NSTimer scheduledTimerWithTimeInterval:TRACK_TO_COMP_COPY_TIMEOUT target:self selector:@selector(trackToCompCopyOneshotService) userInfo:nil repeats:NO]];
}

//-(void)trackMem:(NSEvent*)event{
//
//    NSInteger track;
//
//    switch (event.data1) {
//        case 27: track = 0; break;
//        case 35: track = 1; break;
//        case 43: track = 2; break;
//        case 51: track = 3; break;
//        case 28: track = 4; break;
//        case 36: track = 5; break;
//        case 44: track = 6; break;
//        case 52: track = 7; break;
//        case 29: track = 8; break;
//        case 37: track = 9; break;
//        case 45: track = 10; break;
//        case 53: track = 11; break;
//        case 30: track = 12; break;
//        case 38: track = 13; break;
//        case 46: track = 14; break;
//        case 54: track = 15; break;
//        default: return;
//    }
//    // shift toggles between banks
//
//    NSInteger mask = _keyboardIsShifted ? 0x10 : 0;
//
//    track = track | ((_currentTrack & 0x10) ^ mask);
//
//    [self setCurrentTrack:track];
//    [self setLastRecordTrack:track]; // V1.00.10 for Tommy, pressing 'show single track' will show the track just selected on the stick
//
//}
-(void) trackToCompCopyOneshotService{
    // 2.00.00
    // a oneshot to copy the track to the comp track if the button is held for more than .3 seconds
    // if there is no cue, there is no action
    Document *doc = [self topDocument];
    
    if(!doc){return;}
    
    if(!doc.recordCycleDictionary){
        
        [self alertErr:@"No cue selected" :@""];
        return;
    }

    [self selectTrackMemory:_currentTrack]; // not 16 track for this operation
    // cue to start, assume we will be in the clip
    // startForDictionary:delegate.recordCycleDictionary
    NSString *start = [doc startForLogTrack:_currentTrack];
    // we will be in the cue. ctl-tab to get to start, shift-tab to select
    [_adrClientWindowController txMsg:@"videoOnline 0"];    // offline for the edit
    [self locate:start :@"5"];
}
-(void) trackToCompCopyOneshotServicex{
    
    //    NSLog(@"track to copy to comp: %ld",_currentTrack);
    [self selectTrackMemory:_currentTrack];
    [self setCurrentTrack:_lastTrack];
    // locate to clip start
    
    //    [[self topDocument] locateToCurrentCue];
    Document *doc = [self topDocument];
    
    // park at the start plus a programmable number of frames (which is a minus number always)
    //    int tcType = (int)[[doc fpsComboBox] indexOfSelectedItem];
    // 9/23/15 losing fpsComboBox
    int tcType = [_mtcHui getTcType];
    
    if(tcType < 0) tcType = 0;  // 24fps if none selected
    NSString *start = [doc startForLogTrack:_lastTrack];    // we go to the log to find the start (it may be changing every take)
    
    if(start == nil) return;    // error
    
    NSInteger trimFrames = [_matrixWindowController trimFrames];
    trimFrames += [_tcc tcToBinary:start withType:tcType];
    start = [_tcc binaryToTc:(int)trimFrames withType:tcType];
    [self locate:start];
    
    // copyClipToComp
    [_adrClientWindowController txMsg:@"copyClipToComp"];
    
}
//-(void)trackMem5:(NSEvent*)event{
//
//    NSInteger key;
//
//    // map unit 5 track mem keys to unit 1
//    switch (event.data1) {
//        case 0: key = 27; break;    //  trk 1/17
//        case 8: key = 35; break;
//        case 16: key = 43; break;
//        case 24: key = 51; break;
//        case 32: key = 28; break;
//        case 40: key = 36; break;
//        case 48: key = 44; break;
//        case 56: key = 52; break;
//        case 1: key = 29; break;    // trk 9/25
//        case 9: key = 37; break;
//        case 17: key = 45; break;
//        case 25: key = 53; break;
//        case 33: key = 30; break;
//        case 41: key = 38; break;
//        case 49: key = 46; break;
//        case 57: key = 54; break;
//
//        default: return;
//    }
//
//    NSEvent *newEvent = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
//                                           location:NSMakePoint(0, 0)
//                                      modifierFlags:0
//                                          timestamp:0
//                                       windowNumber:0
//                                            context:nil
//                                            subtype:event.subtype
//                                              data1:key
//                                              data2:1];    // spoofing keyboard 1
//
//    [self trackMem:newEvent];
//
//    // a oneshot to copy the track to the comp track if the button is held for more than .3 seconds
//    //trackToCompCopyOneshot
//    if(_trackToCompCopyOneshot && _trackToCompCopyOneshot.isValid) [_trackToCompCopyOneshot invalidate];
//    [self setTrackToCompCopyOneshot:[NSTimer scheduledTimerWithTimeInterval:TRACK_TO_COMP_COPY_TIMEOUT target:self selector:@selector(trackToCompCopyOneshotService) userInfo:nil repeats:NO]];
//
//}

//-(void)trackMem6:(NSEvent*)event{
//    // map unit 6 track mem keys to unit 1 (an 8 button stick, tracks 1-8)
//
//    NSInteger key;
//
//    // map unit 6 track mem keys to unit 1
//    switch (event.data1) {
//        case 0: key = 27; break;    //  trk 1/17
//        case 8: key = 35; break;
//        case 16: key = 43; break;
//        case 24: key = 51; break;
//        case 1: key = 28; break;
//        case 9: key = 36; break;
//        case 17: key = 44; break;
//        case 25: key = 52; break;
//
//        default: return;
//    }
//
//    NSEvent *newEvent = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
//                                           location:NSMakePoint(0, 0)
//                                      modifierFlags:0
//                                          timestamp:0
//                                       windowNumber:0
//                                            context:nil
//                                            subtype:event.subtype
//                                              data1:key
//                                              data2:1];    // spoofing keyboard 1
//
//    [self trackMem:newEvent];
//
//    // a oneshot to copy the track to the comp track if the button is held for more than .3 seconds
//    //trackToCompCopyOneshot
//    if(_trackToCompCopyOneshot && _trackToCompCopyOneshot.isValid) [_trackToCompCopyOneshot invalidate];
//    [self setTrackToCompCopyOneshot:[NSTimer scheduledTimerWithTimeInterval:TRACK_TO_COMP_COPY_TIMEOUT target:self selector:@selector(trackToCompCopyOneshotService) userInfo:nil repeats:NO]];
//}
//-(void)trackMem7:(NSEvent*)event{
//    // map unit 7 track mem keys to unit 1 (an 8 button stick, tracks 9-16)
//
//    NSInteger key;
//
//    // map unit 5 track mem keys to unit 1
//    switch (event.data1) {
//        case 0: key = 29; break;    // trk 9/25
//        case 8: key = 37; break;
//        case 16: key = 45; break;
//        case 24: key = 53; break;
//        case 1: key = 30; break;
//        case 9: key = 38; break;
//        case 17: key = 46; break;
//        case 25: key = 54; break;
//
//        default: return;
//    }
//
//    NSEvent *newEvent = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
//                                           location:NSMakePoint(0, 0)
//                                      modifierFlags:0
//                                          timestamp:0
//                                       windowNumber:0
//                                            context:nil
//                                            subtype:event.subtype
//                                              data1:key
//                                              data2:1];    // spoofing keyboard 1
//
//    [self trackMem:newEvent];
//
//    // a oneshot to copy the track to the comp track if the button is held for more than .3 seconds
//    //trackToCompCopyOneshot
//    if(_trackToCompCopyOneshot && _trackToCompCopyOneshot.isValid) [_trackToCompCopyOneshot invalidate];
//    [self setTrackToCompCopyOneshot:[NSTimer scheduledTimerWithTimeInterval:TRACK_TO_COMP_COPY_TIMEOUT target:self selector:@selector(trackToCompCopyOneshotService) userInfo:nil repeats:NO]];
//}
//-(void)toggleTrackShift{
//
//    // go to the other bank on a 16 boundary
//    _currentTrack ^= 16;
//    _currentTrack &= 16;
//    [self setCurrentTrack:_currentTrack];
//}
-(void)grabInfoFromProtools{
    if(_adrClientWindowController){
        [_adrClientWindowController setForceAddCue:true];  //add duplicate starts
        [_adrClientWindowController txMsg:@"getProtoolsInfo"];
    }
}
-(void)trimBeepsMinusOne{
    
    [self trimBeeps:-1];
    
}
-(void)trimBeepsMinusFive{
    [self trimBeeps:-5];
    
}
-(void)trimBeepsPlusOne{
    [self trimBeeps:1];
    
}
-(void)trimBeepsPlusFive{
    [self trimBeeps:5];
    
}
//#pragma mark -
//#pragma mark ---------------------------- micTimerService --------------------------------
//-(void)micTimerService{
//    // 2.10.00 mic refresh
////    [self sendToMicAccessoryForKeys: nil];  // 2.00.00
//    [_lpMini micRefresh];
//}

//-(void)aipPair:(NSString*)msg{  // select the pair of ahead/in/past switchers shown on the LaunchPad
//
//    unsigned int result;
//    NSLog(@"msg %@",msg);
//    [[NSScanner scannerWithString:msg] scanHexInt:&result];
//
//    // TODO: 2.00.00 a new case for _aipPairSelector
//
//    switch (result) {
//
//        default:
//            self.aipPairSelector = 0; break;     // show actor/editor
//
//        case 0xb06a7f:
//        case 0xb06e7f:
//            self.aipPairSelector = 1; break;     // show stage/booth
//
//        case 0xb06b7f:
//        case 0xb06f7f:
//            self.aipPairSelector = 2; break;     // show ISDN
//        case 0xb06d7f:
//            self.aipPairSelector = 3; break;     // show r.actor r.editor
//
//    }
//
////    [self aipShow];     // show the selected switchers TODO: 2.00.00
//
//}
//-(void)aipToggle2:(NSString*)msg{
//
//    NSArray<NSString*> *array = [msg componentsSeparatedByString:@"_"];
//
//    if(array.count == 2){
//        //matrixNumber_buttonTag
//        int matrixNumber = (int)[array[0] integerValue];
//        int buttonTag = (int)[array[1] integerValue];
//
//        Matrix *matrix = [_matrixWindowController.displayedMatrixArray objectAtIndex:matrixNumber];
//
//        [matrix toggleStates:buttonTag];
//        [_matrixWindowController saveUserDefaults:self];
//
//    }
//}
//-(void)aipToggle:(NSString*)msg{
//
//    unsigned int result;
//    [[NSScanner scannerWithString:msg] scanHexInt:&result];
//
//    unsigned int row = (result >>12) & 0x7; if (row > 4) return;
//    unsigned int col = (result >> 8) & 0x7;
//
//    NSArray *pair = [_aipPairs objectAtIndex:_aipPairSelector]; // actor-editor, stage-booth, ISDN-nada
//    NSString *left = [pair objectAtIndex:0];
//    NSString *right = [pair objectAtIndex:1];
//    NSString *dest = col < 4 ? left : right;
//
//    NSString *src = [_aipRows objectAtIndex:row];
//
//    NSInteger aheadInPast = 0;
//
//    switch (col) {
//        default:
//            aheadInPast = 0;
//            break;
//        case 2:
//        case 6:
//            if([src isEqualToString:@"Beeps"]) return;  // no in/past for beeps
//            aheadInPast = 1;
//            break;
//        case 3:
//        case 7:
//            if([src isEqualToString:@"Beeps"]) return;  // no in/past for beeps
//            aheadInPast = 2;
//            break;
//    }
//
//    if(dest.length){
//        [_matrixWindowController toggleAip:dest :src :aheadInPast]; // does the show
//    }
//
//}
//-(NSData*)aipStateMessageData{
//
//    // we split this out so that aipPairSelector changes can send to lp mini, not to osc
//
//    unsigned char hdr[] = {0x90};
//    NSMutableData *aipData = [[NSMutableData alloc]initWithBytes:hdr length:1];
//
//    for(int i = 0; i < _matrixWindowController.matrixArray.count; i++){
//        // matrices
//
//        for(int j = 0; j <= 15; j++){
//            // tags
//            NSInteger state = [_matrixWindowController.matrixArray[i] stateForTag:j];
//
//            unsigned char color = COLOR_AIP_OFF;   // OFF color
//
//            int rrpb = _matrixWindowController.rehRecPb % 4;  // state indexes are not-pending
//
//            if(state){
//                switch (rrpb) {
//                    case MODE_CONTROL_REHEARSE:
//                    case MODE_CONTROL_REHEARSE_PENDING:
//                    default:
//                        color = COLOR_AIP_AMBER; // amber
//                        break;/Applications/Companion.app/Contents/Resources/app.asar/assets/bitfocus-logo.png
//                    case MODE_CONTROL_RECORD:
//                    case MODE_CONTROL_RECORD_PENDING:
//                        color = COLOR_AIP_RED; // red
//                        break;
//                    case MODE_CONTROL_PLAYBACK:
//                    case MODE_CONTROL_PLAYBACK_PENDING:
//                        color = COLOR_AIP_GREEN; // green
//                        break;
//                }
//            }
//
//            NSString *key = [NSString stringWithFormat:@"%d_%d",i,j];
//
//            switch(i){
//                case 0:
//                case 1:
//                    if(_aipPairSelector != 1) continue;
//                    break;
//                case 2:
//                case 3:
//                    if(_aipPairSelector != 0) continue;
//                    break;
//                case 4:
//                    if(_aipPairSelector != 2) continue;
//                    break;
//                case 5:
//                case 6:
//                    if(_aipPairSelector != 3) continue;   // TODO: 2.00.00 a new case for _aipPairSelector
//                    break;
//                default: continue;
//            }
//
//            if(_oscToAipDictionary[key] != nil){
//                // there is a value
//                NSString *aipStr = _oscToAipDictionary[key];
//
//                unsigned int result;
//                [[NSScanner scannerWithString:aipStr] scanHexInt:&result];
//
//                unsigned char tx[] = {0,0};
//                tx[0] = (result >> 8) & 0xff;
//                tx[1] = color;
//                [aipData appendBytes:tx length:2];
//            }
//
//        }
//    }
//
//    return aipData;
//}
//-(void)sendStatesToAip{
//
//    // TODO: 2.00.00 replace aipShowOsc with calls to sendStatesToAip, sendToMicAccessoryForKeys
//    // sendStatesToAip, sendToMicAccessoryForKeys replaces aipShow also
//
//    NSString *msg = @"lpMini ";
//    NSData *aipData = [self aipStateMessageData];   // built separately so it can be sent by setAipPairSelector
//
//    for(int i = 0; i < _matrixWindowController.matrixArray.count; i++){
//        // matrices
//
//        for(int j = 0; j <= 15; j++){
//            // tags
//            NSInteger state = [_matrixWindowController.matrixArray[i] stateForTag:j];
//
//            unsigned char color = COLOR_AIP_OFF;   // OFF color
//
//            int rrpb = _matrixWindowController.rehRecPb % 4;  // state indexes are not-pending
//
//            if(state){
//                switch (rrpb) {
//                    case MODE_CONTROL_REHEARSE:
//                    case MODE_CONTROL_REHEARSE_PENDING:
//                    default:
//                        color = COLOR_AIP_AMBER; // amber
//                        break;
//                    case MODE_CONTROL_RECORD:
//                    case MODE_CONTROL_RECORD_PENDING:
//                        color = COLOR_AIP_RED; // red
//                        break;
//                    case MODE_CONTROL_PLAYBACK:
//                    case MODE_CONTROL_PLAYBACK_PENDING:
//                        color = COLOR_AIP_GREEN; // green
//                        break;
//                }
//            }
//
//            NSString *key = [NSString stringWithFormat:@"%d_%d",i,j];
//            msg = [msg stringByAppendingFormat:@"%@,%02x\t",key,color];    // tab index,value
//
//        }
//    }
//
//    [self launchPadMiniTx:aipData];
//    [self txOsc:msg];
//}
//-(void)sendStateToAip:(int)tag :(int)state :(int)matrixNumber{
//    // 2.00.00 trying to cut down on the MIDI traffic to aip
//    // don't call 'aipShow' to send a single button
//
//    unsigned char color = COLOR_AIP_OFF;//COLOR_AIP_GREEN_DIM;   // OFF color
//
//    int rrpb = _matrixWindowController.rehRecPb % 4;  // state indexes are not-pending
//
//    if(state){
//        switch (rrpb) {
//            case MODE_CONTROL_REHEARSE:
//            case MODE_CONTROL_REHEARSE_PENDING:
//            default:
//                color = COLOR_AIP_AMBER; // amber
//                break;
//            case MODE_CONTROL_RECORD:
//            case MODE_CONTROL_RECORD_PENDING:
//                color = COLOR_AIP_RED; // red
//                break;
//            case MODE_CONTROL_PLAYBACK:
//            case MODE_CONTROL_PLAYBACK_PENDING:
//                color = COLOR_AIP_GREEN; // green
//                break;
//        }
//    }
//
//    // companion
//    // 2.00.00 for AIP buttons, key is 'matrixNumber_tag'
//    NSString *key = [NSString stringWithFormat:@"%d_%d",matrixNumber,tag];
//    NSString *msg = [NSString stringWithFormat:@"lpMini %@,%02x",key,color];
//
//    [self txOsc:msg];
//
//    // 2.00.00 aip single button changed
//
//    // TODO: 2.00.00 filter by _aipPairSelector
//    // _aipPairSelector l-r actor-editor, stage-booth, ISDN-nada, rem actor-editor
//
//
//    switch(matrixNumber){
//        case 0:
//        case 1:
//            if(_aipPairSelector != 1) return;
//            break;
//        case 2:
//        case 3:
//            if(_aipPairSelector != 0) return;
//            break;
//        case 4:
//            if(_aipPairSelector != 2) return;
//            break;
//        case 5:
//        case 6:
//            if(_aipPairSelector != 3) return;   // TODO: 2.00.00 a new case for _aipPairSelector
//            break;
//        default:
//            return;
//    }
//
//    if(_oscToAipDictionary[key] != nil){
//        // there is a value
//
//        NSString *aipStr = _oscToAipDictionary[key];
//
//        unsigned int result;
//        [[NSScanner scannerWithString:aipStr] scanHexInt:&result];
//
//        unsigned char tx[] = {0x90,0,0};
//        tx[1] = (result >> 8) & 0xff;
//        tx[2] = color;
//
//        [self launchPadMiniTx:[NSData dataWithBytes:tx length:3]];
//
//    }
//}
//-(void)sendToMicAccessoryForKeys:(NSArray*)keys{
//
//    if(keys == nil){
//        keys = _micDictionary.allKeys;   // default
//    }
//
//    // send messages containing all values
//    // we assume that the MIDI message can be a single command byte followed by pairs
//
//    NSString *msg = @"lpMini "; //
//    unsigned char hdr[] = {0xb0};
//    NSMutableData *micData = [[NSMutableData alloc]initWithBytes:hdr length:1];
//    hdr[0] = 0x90;
//    NSMutableData *aipData = [[NSMutableData alloc]initWithBytes:hdr length:1];
//
//    unsigned char tx[] = {0,0};
//
//    for(NSString *key in keys){
//
//        unsigned int result;
//        [[NSScanner scannerWithString:key] scanHexInt:&result];
//
//        unsigned char index = (result >> 8) & 0xff;
////        if(index > sizeof(micState)){
////            NSLog(@"");
////            continue; // bad index
////        }
//
//        Byte sendByte = [_micDictionary[key]  isEqualToString: MIC_ON] ? 0x7f : 0; // full scale or off
////        micState[index] = sendByte; // for aipShow
//
//        tx[0] = index;   // selector
//        tx[1] = sendByte; // on/off
//
//        // append mic bytes
//        [micData appendBytes:tx length:2];
//
//        // round buttons send complement in next channel
//        if(tx[0] & 8){
//
//            tx[0]++;
//            tx[1] = tx[1] ? 0 : 0x7f;
//            [micData appendBytes:tx length:2];
//
//        }
//
//        // append aip bytes
//        unsigned char color = sendByte ? COLOR_AIP_RED : COLOR_AIP_OFF;
//
//        tx[0] = index;
//        tx[1] = color;
//
//        [aipData appendBytes:tx length:2];
//
//        // append osc string
//        // LaunchPad keys are like b0697f, append 7f for Companion so keys match
//        msg = [msg stringByAppendingFormat:@"%@,%02x\t",key,color];    // tab index,value
//    }
//
//    [_lpMini.accMidi.midiClient midiTx:micData];
//    [self launchPadMiniTx:aipData];
//    [self txOsc:msg];
//
//}
//-(void)sendToMicAccessoryForKey:(NSString*)key{
//
//    unsigned int result;
//    [[NSScanner scannerWithString:key] scanHexInt:&result];
//
//    unsigned char index = (result >> 8) & 0xff;
////    if(index > sizeof(micState)){
////        return; // bad index
////    }
//
//    Byte sendByte = [_micDictionary[key]  isEqualToString: MIC_ON] ? 0x7f : 0; // full scale or off
////    micState[index] = sendByte; // for aipShow
//
//    unsigned char tx[3] = {0xb0,0,0};
//    tx[1] = index;   // selector
//    tx[2] = sendByte; // on/off
//
//    [_lpMini.accMidi.midiClient midiTx:[NSData dataWithBytes:tx length:3]];
//
//    // round buttons send complement in next channel
//
//    if(tx[1] & 8){
//
//        tx[1]++;
//        tx[2] = tx[2] ? 0 : 0x7f;
//        [_lpMini.accMidi.midiClient midiTx:[NSData dataWithBytes:tx length:3]];
//
//    }
//
//    // transmit to companion
//
//    unsigned char color = sendByte ? COLOR_AIP_RED : COLOR_AIP_OFF;
//
//    NSString * str = [NSString stringWithFormat:@"lpMini %@,%02x",key,color];
//
//    [self txOsc:str];
//
//    // 2.00.00 transmit to lp mini
//
//    tx[0] = 0x90;
//    tx[1] = index;
//    tx[2] = color;
//    [self launchPadMiniTx:[NSData dataWithBytes:tx length:3]];
//
//}
//-(void)micToggle:(NSString*)msg{
//
//    if(_micDictionary[msg]){
//
//        _micDictionary[msg] = [_micDictionary[msg]  isEqualToString: MIC_ON] ? MIC_OFF : MIC_ON;
//
//    }else{
//
//        _micDictionary[msg] = MIC_ON;
//
//    }
//
//    NSError *error;
//
//    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_micDictionary requiringSecureCoding:false error:&error];
//    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
//    [defaults setObject:data forKey:@"micDictionary"];
//
//    // transmit to accessory, lp mini
//
//    [self sendToMicAccessoryForKey:msg];
//}

//-(void)micTogglex:(NSString*)msg{
//
//    // toggle a mic indicator
//    unsigned int result;
//    [[NSScanner scannerWithString:msg] scanHexInt:&result];
//
//    unsigned char tx[3] = {0x90,0,0};
//
//    unsigned char index = (result >> 8) & 0xff;
////    if(index > sizeof(micState)) return;    // illegal index
//
//    tx[1] = index;
//
//    micState[index] = micState[index] ? 0 : 0x7f;   // full scale or off
//
//    if(index & 8)   tx[2] = micState[index] ? COLOR_AIP_RED   : COLOR_AIP_GREEN_DIM;
//    else            tx[2] = micState[index] ? COLOR_AIP_RED : COLOR_AIP_GREEN_DIM;
//
//    // show on control head
//    //    [_launchPadMiniClient midiTx:[NSData dataWithBytes:tx length:3]];   // 12/14/16 change to have 2 heads for Tommy
//    [self launchPadMiniTx:[NSData dataWithBytes:tx length:3]];
//    //    [_midiClient txMidiToHead:[NSData dataWithBytes:tx length:3]];
//
//    // send to plugin as a control change
//    tx[0] = 0xb0;
//    tx[2] = micState[index]; // 0 or 0x7f
//
//    [_lpMini.accMidi.midiClient midiTx:[NSData dataWithBytes:tx length:3]];
//    //    [_midiClient txMidiToAcc:[NSData dataWithBytes:tx length:3]];        // relay to Evan
//
//    // round buttons send complement in next channel
//
//    if(index & 8){
//
//        tx[1]++;
//        tx[2] = tx[2] ? 0 : 0x7f;
//        [_lpMini.accMidi.midiClient midiTx:[NSData dataWithBytes:tx length:3]];
//        //       [_midiClient txMidiToAcc:[NSData dataWithBytes:tx length:3]];        // relay to Evan
//    }
//
//    // save state for power up if not the round button column, do save custom fill state
//
//    if(~index & 8 || index == CUSTOM_FILL_INDEX){
//
//        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
//        NSData *data = [NSData dataWithBytes:micState length:sizeof(micState)];
//        [defaults setObject:data forKey:@"micState"];
//
//    }
//
//
//}

-(void)futzOff{
    
    [_lpMini micSet:@"90087f" :false];
    [_lpMini micSet:@"90187f" :false];
    [_lpMini micSet:@"90287f" :false];
    [_lpMini micSet:@"90387f" :false];
    [_lpMini micSet:@"90487f" :false];
    [_lpMini micSet:@"90587f" :false];
    [_lpMini micSet:@"90687f" :false];
    [_lpMini micSet:@"90787f" :false];
//
//    _micDictionary[@"90087f"] = MIC_OFF;
//    _micDictionary[@"90187f"] = MIC_OFF;
//    _micDictionary[@"90287f"] = MIC_OFF;
//    _micDictionary[@"90387f"] = MIC_OFF;
//    _micDictionary[@"90487f"] = MIC_OFF;
//    _micDictionary[@"90587f"] = MIC_OFF;
//    _micDictionary[@"90687f"] = MIC_OFF;
//    _micDictionary[@"90787f"] = MIC_OFF;  // round right buttons
//
//    NSArray *array = @[
//        @"90087f",
//        @"90187f",
//        @"90287f",
//        @"90387f",
//        @"90487f",
//        @"90587f",
//        @"90687f",
//        @"90787f"
//    ];
//
//    [self sendToMicAccessoryForKeys:array]; // clear round right buttons, send to accessories

}
-(void)nextAnchor:(NSEvent*)event{
    
    [_overlayWindowController.viewController bringToFront];
    [_overlayWindowController.viewController.textView nextAnchor];

}

- (IBAction)onOverlayWindow:(id)sender{
    
    // v1.00.23 CAAnimation streamer, punch overlays, text overlays in Swift
    if(_overlayWindowController == nil){
        
        _overlayWindowController = [[OverlayWindowController alloc]initWithWindowNibName:@"OverlayWindowController"];
    }
    
    [_overlayWindowController activateWindow];  // turn on title bar, accept mouse clicks
    
    [[_overlayWindowController window] makeKeyAndOrderFront:nil];   // give it the focus
    //    [NSApp activateIgnoringOtherApps:YES];
    
    
}

- (IBAction)onStreamerWindow:(id)sender {
    //
    if(_streamerWindowController == nil){
        
        _streamerWindowController = [[StreamerWindowController alloc]initWithWindowNibName:@"StreamerWindowController"];
    }
    
    [NSApp activateIgnoringOtherApps:YES];
    [_streamerWindowController.window makeKeyAndOrderFront:nil];   // give it the focus
}

- (IBAction)onMonitorWindow:(id)sender {
    
    if(_matrixWindowController == nil){
        
        _matrixWindowController = [[MatrixWindowController alloc]initWithWindowNibName:@"MatrixWindowController"];
    }
    
    [[_matrixWindowController window] makeKeyAndOrderFront:nil];   // give it the focus
    [NSApp activateIgnoringOtherApps:YES];
}
- (IBAction)onAdrClientWindow:(id)sender {
    
    if(_adrClientWindowController == nil){
        
        _adrClientWindowController = [[AdrClientWindowController alloc]initWithWindowNibName:@"AdrClientWindowController"];
    }
    
    [[_adrClientWindowController window] makeKeyAndOrderFront:nil];   // give it the focus
    [NSApp activateIgnoringOtherApps:YES];
}
-(NSScreen*)rightmostScreen{
    
    NSArray *screens = [NSScreen screens];
    
    // choose the screen with the farthest right origin
    NSScreen *rightmostScreen;
    for(NSScreen *screen in screens){
        
        if((!rightmostScreen || screen.frame.origin.x > rightmostScreen.frame.origin.x) && screen.frame.size.width >= 1920)
            // full size screens only
            rightmostScreen = screen;
        
    }
    
    return rightmostScreen;
    
}
-(NSScreen*)widestScreen{
    
    NSArray *screens = [NSScreen screens];
    
    // choose the widest screen or rightmost screen of same size screens (WB uses a 3440 wide monitor for the primary display)
    //
    NSScreen *widestScreen;
    for(NSScreen *screen in screens){
        
        if(!widestScreen || screen.frame.size.width > widestScreen.frame.size.width || (screen.frame.size.width == widestScreen.frame.size.width && screen.frame.origin.x > widestScreen.frame.origin.x))
            // full size screens only
            widestScreen = screen;
        
    }
    
    return widestScreen;
    
}

- (IBAction)onEditorWindow:(id)sender {
    
    Document *doc = [self topDocument];
    
    if(_editorWindowController == nil){
        
        [self setEditorWindowController:[[EditorWindowController alloc]initWithWindowNibName:@"EditorWindowController"]];
    }
    
    [[_editorWindowController window] makeKeyAndOrderFront:nil];   // give it the focus
    if(doc && doc.recordCycleDictionary)[doc bindEditorWindowFields:doc.recordCycleDictionary];
    [NSApp activateIgnoringOtherApps:YES];    
    
}

- (IBAction)onAudioPlayerWindow:(id)sender {
    
    if(_audioPlayerWindowController == nil){
        
//        _samplerWindowController = [[SamplerWindowController alloc]initWithWindowNibName:@"SamplerWindowController"];
        _audioPlayerWindowController = [[AudioPlayerWindowController alloc]initWithWindowNibName:@"AudioPlayerWindowController"];
    }
    
    if(_audioPlayerWindowController.window != nil){
        
        [_audioPlayerWindowController.window makeKeyAndOrderFront:nil];   // give it the focus
    }
    // http://stackoverflow.com/questions/1740412/how-to-bring-nswindow-to-front-and-to-the-current-space
    [NSApp activateIgnoringOtherApps:YES];  //
}
-(void)cycleWindows:(NSEvent*)event{
    
    _cycleWindowSelector++;
    switch (_cycleWindowSelector) {
        default:
            _cycleWindowSelector = WINDOW_EDITOR;
            [self onEditorWindow:nil];
            break;
        case WINDOW_DOCUMENT:
            [self onDocumentWindow:nil];
            break;
        case WINDOW_MONITOR:
            [self onMonitorWindow:nil];
            break;
    }
    
}
- (IBAction)onVideoDelayWindow:(id)sender {
    
    if(_videoDelayWindowController == nil){
        
        _videoDelayWindowController = (VideoDelayWindowController*)[PrefsWindowObjCBridge makePrefsWindow];
//        [_videoDelayWindowController showWindow:self];
    }
    
    if(_videoDelayWindowController.window != nil){

        // this window can't be key, we get a warning if we try, so silence the warning
        [_videoDelayWindowController.window orderFront:nil];
//        [_videoDelayWindowController.window makeKeyAndOrderFront:nil];   // give it the focus
    }
    // http://stackoverflow.com/questions/1740412/how-to-bring-nswindow-to-front-and-to-the-current-space
//    [NSApp activateIgnoringOtherApps:YES];  // Evan wants the program w/focus to keep the focus
    
    // 2.10.02 when this window opens, set 'use alt guide in record'
//    [[NSUserDefaults standardUserDefaults]setBool:true forKey:@"useAltGuideInRecord"];
    
    // status message indicating delay window is open
    unsigned char bytes[] = {0xb0,5,127};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    [_statusClient midiTx:data];
}

- (IBAction)onDocumentWindow:(id)sender { //
    
    Document *doc = [self topDocument];
    
    [doc makeFrontmost];
    // http://stackoverflow.com/questions/1740412/how-to-bring-nswindow-to-front-and-to-the-current-space
    [NSApp activateIgnoringOtherApps:YES];
    
}
- (IBAction)OnDialMidiWindow:(id)sender {
    
    if(_dialMidiWindowController == nil){
        
        _dialMidiWindowController = [[DialMidiWindowController alloc]initWithWindowNibName:@"DialMidiWindowController"];
//        [_videoDelayWindowController showWindow:self];
    }
    
    if(_dialMidiWindowController.window != nil){

        // this window can't be key, we get a warning if we try, so silence the warning
        [_dialMidiWindowController.window orderFront:nil];
//        [_videoDelayWindowController.window makeKeyAndOrderFront:nil];   // give it the focus
    }
    // http://stackoverflow.com/questions/1740412/how-to-bring-nswindow-to-front-and-to-the-current-space
    [NSApp activateIgnoringOtherApps:YES];  //
}

//-(void)setAdrClientStatusImage:(NSImage*)image{
//
//    if(_matrixWindowController) [_matrixWindowController setAdrClientStatusImage:image];
//
//}
//-(void)loopTimeInterval:(NSDate*)time{
//    
//    if(_midiClient && [_midiClient loopDate]){
//        
//        NSTimeInterval interval = [time timeIntervalSinceDate:[_midiClient loopDate]];
//        
//        if (interval < .5)  NSLog(@"loopTimeInterval: %5.3f",interval); // mask out loop starts etc
//        
//    }
//    
//}

//-(void)setTrackLEDs{
//
//    // for XK-24, add 32 for red LEDs
//    // for XK-60 and XK-80, add 80 for red LEDs
//
//    [self setLEDForUnitID:1 :0 :_currentTrack & 16];    // track shift
//
//    // show 1-16 in red, 17-32 in blue
//
//    // red LEDs head 1
//    [self setLEDForUnitID:1 :27+80 :_currentTrack == 0];
//    [self setLEDForUnitID:1 :35+80 :_currentTrack == 1];
//    [self setLEDForUnitID:1 :43+80 :_currentTrack == 2];
//    [self setLEDForUnitID:1 :51+80 :_currentTrack == 3];
//    [self setLEDForUnitID:1 :28+80 :_currentTrack == 4];
//    [self setLEDForUnitID:1 :36+80 :_currentTrack == 5];
//    [self setLEDForUnitID:1 :44+80 :_currentTrack == 6];
//    [self setLEDForUnitID:1 :52+80 :_currentTrack == 7];
//    [self setLEDForUnitID:1 :29+80 :_currentTrack == 8];
//    [self setLEDForUnitID:1 :37+80 :_currentTrack == 9];
//    [self setLEDForUnitID:1 :45+80 :_currentTrack == 10];
//    [self setLEDForUnitID:1 :53+80 :_currentTrack == 11];
//    [self setLEDForUnitID:1 :30+80 :_currentTrack == 12];
//    [self setLEDForUnitID:1 :38+80 :_currentTrack == 13];
//    [self setLEDForUnitID:1 :46+80 :_currentTrack == 14];
//    [self setLEDForUnitID:1 :54+80 :_currentTrack == 15];
//
//    // blue LEDs head 1
//    [self setLEDForUnitID:1 :27 :_currentTrack == 16];
//    [self setLEDForUnitID:1 :35 :_currentTrack == 17];
//    [self setLEDForUnitID:1 :43 :_currentTrack == 18];
//    [self setLEDForUnitID:1 :51 :_currentTrack == 19];
//    [self setLEDForUnitID:1 :28 :_currentTrack == 20];
//    [self setLEDForUnitID:1 :36 :_currentTrack == 21];
//    [self setLEDForUnitID:1 :44 :_currentTrack == 22];
//    [self setLEDForUnitID:1 :52 :_currentTrack == 23];
//    [self setLEDForUnitID:1 :29 :_currentTrack == 24];
//    [self setLEDForUnitID:1 :37 :_currentTrack == 25];
//    [self setLEDForUnitID:1 :45 :_currentTrack == 26];
//    [self setLEDForUnitID:1 :53 :_currentTrack == 27];
//    [self setLEDForUnitID:1 :30 :_currentTrack == 28];
//    [self setLEDForUnitID:1 :38 :_currentTrack == 29];
//    [self setLEDForUnitID:1 :46 :_currentTrack == 30];
//    [self setLEDForUnitID:1 :54 :_currentTrack == 31];
//
//
//    // show 1-16 in red, 17-32 in blue
//
//    // red LEDs head 5
//    [self setLEDForUnitID:5 :0+80 :_currentTrack == 0];
//    [self setLEDForUnitID:5 :8+80 :_currentTrack == 1];
//    [self setLEDForUnitID:5 :16+80 :_currentTrack == 2];
//    [self setLEDForUnitID:5 :24+80 :_currentTrack == 3];
//    [self setLEDForUnitID:5 :32+80 :_currentTrack == 4];
//    [self setLEDForUnitID:5 :40+80 :_currentTrack == 5];
//    [self setLEDForUnitID:5 :48+80 :_currentTrack == 6];
//    [self setLEDForUnitID:5 :56+80 :_currentTrack == 7];
//    [self setLEDForUnitID:5 :1+80 :_currentTrack == 8];
//    [self setLEDForUnitID:5 :9+80 :_currentTrack == 9];
//    [self setLEDForUnitID:5 :17+80 :_currentTrack == 10];
//    [self setLEDForUnitID:5 :25+80 :_currentTrack == 11];
//    [self setLEDForUnitID:5 :33+80 :_currentTrack == 12];
//    [self setLEDForUnitID:5 :41+80 :_currentTrack == 13];
//    [self setLEDForUnitID:5 :49+80 :_currentTrack == 14];
//    [self setLEDForUnitID:5 :57+80 :_currentTrack == 15];
//
//    // blue LEDs head 5
//    [self setLEDForUnitID:5 :0 :_currentTrack == 16];
//    [self setLEDForUnitID:5 :8 :_currentTrack == 17];
//    [self setLEDForUnitID:5 :16 :_currentTrack == 18];
//    [self setLEDForUnitID:5 :24 :_currentTrack == 19];
//    [self setLEDForUnitID:5 :32 :_currentTrack == 20];
//    [self setLEDForUnitID:5 :40 :_currentTrack == 21];
//    [self setLEDForUnitID:5 :48 :_currentTrack == 22];
//    [self setLEDForUnitID:5 :56 :_currentTrack == 23];
//    [self setLEDForUnitID:5 :1 :_currentTrack == 24];
//    [self setLEDForUnitID:5 :9 :_currentTrack == 25];
//    [self setLEDForUnitID:5 :17 :_currentTrack == 26];
//    [self setLEDForUnitID:5 :25 :_currentTrack == 27];
//    [self setLEDForUnitID:5 :33 :_currentTrack == 28];
//    [self setLEDForUnitID:5 :41 :_currentTrack == 29];
//    [self setLEDForUnitID:5 :49 :_currentTrack == 30];
//    [self setLEDForUnitID:5 :57 :_currentTrack == 31];
//
//    // stick, dictionary 6, tracks 1-8
//    // the LEDs do not correspond to the key numbers
//
//    // blue LEDs head 6
//    [self setLEDForUnitID:6 :0 :_currentTrack % 16 == 0];
//    [self setLEDForUnitID:6 :1 :_currentTrack % 16 == 1];
//    [self setLEDForUnitID:6 :2 :_currentTrack % 16 == 2];
//    [self setLEDForUnitID:6 :3 :_currentTrack % 16 == 3];
//    [self setLEDForUnitID:6 :4 :_currentTrack % 16 == 4];
//    [self setLEDForUnitID:6 :5 :_currentTrack % 16 == 5];
//    [self setLEDForUnitID:6 :8 :_currentTrack % 16 == 6];
//    [self setLEDForUnitID:6 :9 :_currentTrack % 16 == 7];
//
//    // V1.00.23, feedback for OSC
//    [self txOsc:[NSString stringWithFormat:@"Track %ld",_currentTrack + 1]];
//
//    // set green for 1-16, red for 17-32
////    bool isRed = _currentTrack > 15;
//
////    [_objCPIUtilities onRedGreen:6 :1 :isRed];  // unit, red/green, on/off
////    [_objCPIUtilities onRedGreen:6 :0 :!isRed];
//
//    // blue LEDs head 7
//    [self setLEDForUnitID:7 :0 :_currentTrack % 16 == 8];
//    [self setLEDForUnitID:7 :1 :_currentTrack % 16 == 9];
//    [self setLEDForUnitID:7 :2 :_currentTrack % 16 == 10];
//    [self setLEDForUnitID:7 :3 :_currentTrack % 16 == 11];
//    [self setLEDForUnitID:7 :4 :_currentTrack % 16 == 12];
//    [self setLEDForUnitID:7 :5 :_currentTrack % 16 == 13];
//    [self setLEDForUnitID:7 :8 :_currentTrack % 16 == 14];
//    [self setLEDForUnitID:7 :9 :_currentTrack % 16 == 15];
//
////    [_objCPIUtilities onRedGreen:7 :1 :isRed];
////    [_objCPIUtilities onRedGreen:7 :0 :!isRed];
//}
//-(void)setTrimLeds{
//
//    NSInteger beepsTrimFrames = [[NSUserDefaults standardUserDefaults] integerForKey:@"beepsTrimFrames"];
//    bool ledsOn = beepsTrimFrames != 0;
//
//    [self setLEDForUnitID:1 :17 :ledsOn];
//    [self setLEDForUnitID:1 :25 :ledsOn];
//    [self setLEDForUnitID:1 :33 :ledsOn];
//    [self setLEDForUnitID:1 :41 :ledsOn];
//
//}

#pragma -
#pragma mark ------------- MidiClientDelegate -----------------

//-(void)switcherGain:(NSData*)data{
//    
//    [_matrixWindowController switcherGain:data];
//    
//}
-(void)toggleToTc{
    
    Document *doc = [self topDocument];
    [doc setTableContentsDisplayFormat:DISPLAY_FMT_TC];
    //    [doc toggleToTc];   // TODO other fields, preroll and ?
    [_editorWindowController toggleToTc];
    
}
-(void)toggleToFt{
    
    Document *doc = [self topDocument];
    [doc setTableContentsDisplayFormat:DISPLAY_FMT_FT];
    
    //    [doc toggleToFt];   // TODO other fields, preroll and ?
    [_editorWindowController toggleToFt];
    
}
//-(NSInteger)midiKeyboardService:(NSString*)msg{
//
//
//    NSString *methodString = [_midiKeyDictionary objectForKey:msg];
//
//    //    NSLog(@"midiKeyboardService msg:%@ methodString:%@",msg,methodString);
//
//    if(methodString){
//
//        SEL someSelector = sel_registerName((const char*)[methodString UTF8String]);
//
//        if([self respondsToSelector:someSelector]){
//
//            // http://stackoverflow.com/questions/7017281/performselector-may-cause-a-leak-because-its-selector-is-unknown
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
//            [self performSelector:someSelector withObject:msg];
//#pragma clang diagnostic pop
//
//            return 0;
//        }
//    }
//    return -1;
//}

#pragma -
#pragma mark ------------- setters/getters -----------------
-(void)setScreenRecorder:(ScreenRecorder *)screenRecorder{
    
    _screenRecorder = screenRecorder;
    
    if(_videoDelayWindowController){
        [_videoDelayWindowController setScreenRecorder:_screenRecorder];
    }
}
-(ScreenRecorder *)screenRecorder{
    return _screenRecorder;
}
-(void)setRecDelayState:(NSInteger)recDelayState{
    
    [[NSUserDefaults standardUserDefaults]setInteger:recDelayState forKey:@"recDelayState"];
    
    [self setLEDForUnitID:9 :77 :recDelayState];

}
-(NSInteger)recDelayState{
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"recDelayState"];
}
-(void)setCueIdInSlate:(bool)cueIdInSlate{
    
    [[NSUserDefaults standardUserDefaults]setBool:cueIdInSlate forKey:@"cueIdInSlate"];
    [self setLEDForUnitID: 9 : 82 : cueIdInSlate];
    
}
-(bool)cueIdInSlate{
    
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"cueIdInSlate"];
}
-(void)setSuggestedTrackName:(NSString *)suggestedTrackName{
    _suggestedTrackName = [suggestedTrackName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}
-(NSString *)suggestedTrackName{
    return _suggestedTrackName;
}
-(void)setSnoopState:(NSInteger)snoopState{
    
    //    SNOOP_STATE_OFF,
    //    SNOOP_STATE_ON,
    //    SNOOP_STATE_FORCE_OFF,
    //    SNOOP_STATE_FORCE_ON
        
//    if(snoopState == _snoopState || !self.snoopAuto){
//        return; // no change, or not enabled
//    }
    
    if(snoopState != _snoopState){
        
        _snoopState = snoopState & 1;
        [self dialMuteDim:@"99"];   // special-case dialMuteDim for '99'
    }

}
-(NSInteger)snoopState{
    return _snoopState;
}
-(void)setSnoopAuto:(bool)snoopAuto{
    
    _snoopAuto = snoopAuto;
    [[NSUserDefaults standardUserDefaults]setBool:snoopAuto forKey:@"snoopAuto"];
    self.snoopState = self.snoopState + 2;  // FORCE_ON, FORCE_OFF

}
-(bool)snoopAuto{
    return _snoopAuto;
}
-(void)toggleSnoopAuto{
    self.snoopAuto = !self.snoopAuto;
}
-(void)toggleCueIdInSlate{
    
    self.cueIdInSlate = !self.cueIdInSlate;

}
-(void)sampleRate:(NSEvent*)event{
    
    // 83,84,85 48K,96K,192K
    //event.data1
    _matrixWindowController.sampleRateTag = event.data1 - 83;
    
}
//-(void)setAipPairSelector:(NSInteger)aipPairSelector{
//    _aipPairSelector = aipPairSelector;
//    
//    unsigned char colors[] = {COLOR_AIP_OFF,COLOR_AIP_OFF,COLOR_AIP_OFF,COLOR_AIP_OFF};
////    unsigned char colors[] = {COLOR_AIP_GREEN_DIM,COLOR_AIP_GREEN_DIM,COLOR_AIP_GREEN_DIM,COLOR_AIP_GREEN_DIM};
//
//    if(aipPairSelector < sizeof(colors)){
//        colors[aipPairSelector] = COLOR_AIP_AMBER;
//    }
//    // send to osc
//    /*
//     @"aipPair:",@"b0697f",   // show actor/editor
//     @"aipPair:",@"b06a7f",   // show stage/booth
//     @"aipPair:",@"b06b7f",   // show ISDN
//     // we need a selector for remote actor/remote editor
//     @"aipPair:",@"b06d7f",   // 2.00.00 show r.actor r.editor// show
//     */
//    // TODO: why are we skipping b06c7f
//    NSString *msg = [NSString stringWithFormat:@"lpMini b0697f,%02x\tb06a7f,%02x\tb06b7f,%02x\tb06d7f,%02x",colors[0],colors[1],colors[2],colors[3]];
//    
//    [self txOsc:msg];
//    
//    // send round buttons to lp Mini. osc
//    unsigned char tx[] = {0xb0,0x69,colors[0],0x6a,colors[1],0x6b,colors[2],0x6d,colors[3]};    // NOTE: missing 0x6c
//    [self launchPadMiniTx:[NSData dataWithBytes:tx length:sizeof(tx)]];
//    
//    // send aip buttons to lp Mini
//    NSData *aipData = [self aipStateMessageData];
//    [self launchPadMiniTx:aipData]; // only launch pad mini changes, no need to send to osc
//    
//}
//-(NSInteger)aipPairSelector{
//    return _aipPairSelector;
//}
-(void)setPrerollIndex:(NSInteger)prerollIndex{
    
    NSArray *tcPreroll = @[@"00:00:04:00"
                           ,@"00:00:06:00"
                           ,@"00:00:08:00"
                           ,@"00:00:12:00"
                            ];
    NSArray *ftPreroll = @[@"6+00"
                           ,@"9+00"
                           ,@"12+00"
                           ,@"18+00"
                            ];
    
    _prerollIndex = prerollIndex;
    [self txOsc:[NSString stringWithFormat:@"prerollIndex %ld",(long)_prerollIndex]];    //
    
    [_xKey setLEDForUnitID:8 :2     :_prerollIndex == 0];
    [_xKey setLEDForUnitID:8 :10    :_prerollIndex == 1];
    [_xKey setLEDForUnitID:8 :18    :_prerollIndex == 2];
    [_xKey setLEDForUnitID:8 :26    :_prerollIndex == 3];
    [_xKey setLEDForUnitID:8 :34    :_prerollIndex == 4];

    switch(prerollIndex){
        case 0:
        case 1:
        case 2:
        case 3:
            [_editorWindowController setPreroll: [self getDisplayFormat] == DISPLAY_FMT_FT ? ftPreroll[prerollIndex] : tcPreroll[prerollIndex]];
            break;
        case 4: // preroll to here, calc preroll based on cue start and current position.
                // Don't save to user defaults, next cue resets to user default
            [_adrClientWindowController txMsg:@"jxaGetProtoolsPosition 4"]; // 2.00.00 calc preroll to here
            return;
        default:   // bad index, default to 4 seconds
            _prerollIndex = 0;
            [_editorWindowController setPreroll: [self getDisplayFormat] == DISPLAY_FMT_FT ? @"6+00" : @"00:00:04:00"];

            break;
            
    }
    
    [[NSUserDefaults standardUserDefaults] setInteger:_prerollIndex forKey:@"prerollIndex"];

}
-(NSInteger)prerollIndex{
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"prerollIndex"];
}
-(void)setHidePix:(bool)hidePix{
    
    _overlayWindowController.viewController.streamer.hidePix = hidePix;
    
}
-(bool)hidePix{
    return _overlayWindowController.viewController.streamer.hidePix;
}

//-(void)setHidePix:(bool)hidePix{
//    _hidePix = hidePix;
//    //     NSLog(@"hidePix: %d",_hidePix);
//
//    [self setDocLEDs];
//
//    // changes for checkbox that toggles hidePix 7/13/20 V1.00.16
//    if(_timerBlack)[_timerBlack invalidate];    //
//
//    //    if(((TextWindowClient*)_textWindowClient).isOnline == NSControlStateValueOn){
//
//    // text and hide pix is done by TextWindowServer
//    NSString *msg = [ NSString stringWithFormat:@"hidePix %d",_hidePix];
//    [_textWindowClient txMsg:msg];   // toggles
//    [_streamerWindowController txMsg: @"midi 90 6c 0"];  // streamer black off TODO: 1.00.23
//
//    //    }else{
//    //        [self forceBlack:false];
//    //    }
//
//}
//-(bool)hidePix{
//    return _hidePix;
//}
-(void)setSession:(NSString *)session{
    
    NSLog(@"setSession: %@",session);
    
    if(session != nil && ![_session isEqualToString:session]){
        
        _session = session;
        [self selectCurrentSixteenTrackMemory];
//        [self sendToMicAccessoryForKeys:nil];    // defaults to all keys. micTimerService says we need to do this on new session, why?
        [self readLog]; // reads the log for all open document windows
        
        // get the video delay
        // jxaGetVideoSyncOffset
//        [_adrClientWindowController txMsg:@"jxaGetVideoSyncOffset"];
    }
}
-(NSString *)session{
    return _session;
}
-(void)setOverlay:(bool)overlay{
    
    if(_overlay ^ overlay){
        
        _overlay = overlay;
        
        for(Matrix *matrix in _matrixWindowController.matrixArray){
            matrix.overlay = overlay;  // 2.00.00 where the overlay logic is
        }
        
        [self setLEDForUnitID:8 :71 :_overlay];
        [self setLEDForUnitID:8 :79 :_overlay];
        [self setLEDForUnitID:9 :35 :_overlay];
    }
}
-(bool)overlay{
    return _overlay;
}
-(void)setCycleMode:(NSInteger)cycleMode{
    
    NSInteger lastValue = _cycleMode;
    
    NSLog(@"setCycleMode %ld -> %ld",(long)_cycleMode,cycleMode);
    
    _cycleMode = cycleMode;
    

    // RECORD sequencer
    
    if(cycleMode == CYCLE_MODE_IDLE){
        switch(lastValue){
            case CYCLE_MODE_RECORD: // we didn't get into the loop
            case CYCLE_MODE_SKIP_PASTE: // cancelled after getting into the loop
                [self decrementRecordTake];
                [self.adrClientWindowController txMsg:@"keyWithModifiers\tz\t1"]; // [0] command [1] option [2] control [3] shift
                self.cycleMotion = CYCLE_MOTION_IDLE;   

                break;
            case CYCLE_MODE_RECORD_KEEP_TAKE:
                
                _cycleMode = CYCLE_MODE_FINALIZE_RECORD;    // inhibit CYCLE button until clips are copied
                
                [_matrixWindowController cueToTrimFrames];      // a sequencer
                break;
            default:
                self.cycleMotion = CYCLE_MOTION_IDLE;
                break;
        }
    }
}

-(NSInteger)cycleMode{
    return _cycleMode;
}
int btnOnColor    = 588022;   // a light blue or cyan color for 'button on'
int aYellowColor  = 0xF1F704;
int aRedColor     = 0xEE0522;
int aGreenColor   = 0x40FF40;
int aBlueColor    = 0x8080FF;
int btnWhiteColor = 0xffffff;
int aliceBlue     = 0xF0F8FF;
int powderBlue    = 0xB0E0E6;

int cycleStartColor = 0x808080;
int cycleColor = 0x8080FF;
int cycleStopColor = 0x000080;
int btnOffColor = 0x404040;

-(void)setCycleMotion:(NSInteger)cycleMotion{
    
    NSLog(@"setCycleMotion %ld -> %ld",_cycleMotion,cycleMotion);
// tickle github
    NSInteger lastValue = _cycleMotion;
    _cycleMotion = cycleMotion;
    [self sendMidiToClosure];   // 1.00.12
    NSString *txt = @"Cycle";
    int fg = 0xffffff;
    int bg = 0x000080;

    switch (cycleMotion){
        case CYCLE_MOTION_IDLE:
            txt = @"Cycle";
//            if(lastValue != CYCLE_MOTION_IDLE){
//                _matrixWindowController.rehRecPb = MODE_CONTROL_REHEARSE;
//            }
            break;
        case CYCLE_MOTION_STARTING:
            txt = @"Cycle Start";
            fg = 0;
            bg = cycleStartColor;
            break;
        case CYCLE_MOTION_ACTIVE:
            txt = @"Cycle";
            fg = 0;
            bg = cycleColor;
            break;
        case CYCLE_MOTION_STOPPING:
            txt = @"Cycle Stop";
            //fg = 0xffffff;
            bg = cycleStopColor;
            break;
        case CYCLE_MOTION_PENDING:
            txt = @"Cycle Pending";
            fg = 0;
            bg = cycleStartColor;
            // TODO: can we hang in this state?
            break;
    }
    NSString *msg = [NSString stringWithFormat:@"btn 9_66,%d,%d,%@",fg,bg,txt];
    [self txOsc:msg];
    
    switch(cycleMotion){
        case CYCLE_MOTION_IDLE:
            [_overlayWindowController.viewController.streamer cancelAllStreamers];
            _matrixWindowController.aheadInPast = MODE_AHEAD;   // 2.00.00 no longer using timeout
            switch(_matrixWindowController.rehRecPb){
                case MODE_CONTROL_REHEARSE_PENDING:
                    _matrixWindowController.rehRecPb = MODE_CONTROL_REHEARSE;
                    break;
                case MODE_CONTROL_RECORD_PENDING:
                    _matrixWindowController.rehRecPb = MODE_CONTROL_RECORD;
                    break;
                case MODE_CONTROL_PLAYBACK_PENDING:
                    _matrixWindowController.rehRecPb = MODE_CONTROL_PLAYBACK;
                    break;
                default:
                    // go back to REHEARSE if there wasn't a fast button push
                    // TODO: pressing PLAY/STOP shouldn't change modes
//                    _matrixWindowController.rehRecPb = MODE_CONTROL_REHEARSE;
                    break;
            }
            break;
            
        case CYCLE_MOTION_STARTING:
            [_adrClientWindowController txMsg:@"jxaIsModalDialog\t2"];  // cycle sequencer

            break;
        case CYCLE_MOTION_STOPPING:
            _matrixWindowController.rehRecPb = MODE_CONTROL_REHEARSE;
            break;
        default:
            break;
    }
    
    if(lastValue == CYCLE_MOTION_PENDING && _cycleMotion == CYCLE_MOTION_IDLE){
        [self cycleButton];
    }
}
-(NSInteger)cycleMotion{
    return _cycleMotion;
}
// LCR and greater have 16 tracks max
//1,2,3,4,6,8 track, end
NSInteger maxTracks[] = {32,32,16,16,16,16};
-(void)setCurrentTrack:(NSInteger)currentTrack{
    
    if(currentTrack < 0)currentTrack = 0;   // clip
    
    // clip to max for this format
    NSInteger numRecTracksTag = [_matrixWindowController numRecTracksTag];
    if(currentTrack >= maxTracks[numRecTracksTag]){
        currentTrack = maxTracks[numRecTracksTag] - 1;
    }

    Document *doc = self.topDocument;
    
//    NSLog(@"setCurrentTrack lastTrack: %d currentTrack is %d will be %d",_lastTrack,_currentTrack,currentTrack);
    
    _lastTrack = _currentTrack; // for restoring after track copy operation, see trackToCompCopyOneshotService()
    
    _currentTrack = currentTrack % 32;
    
//    [self setTrackLEDs];    // show the active track and shift
    
    if(doc && doc.recordCycleDictionary)
        
        [doc.recordCycleDictionary setObject:[NSString stringWithFormat:@"%ld",_currentTrack + 1] forKey:@"Track"];
        [doc.tableView reloadData];

    [self txOsc:[NSString stringWithFormat:@"Track %ld",_currentTrack + 1]];
    
    // track selection (mem xx) happens ***after*** record complete. FIXME: Check 'show armed'
//    [self selectCurrentSixteenTrackMemory];
    
    bool green = _currentTrack < 16;
    bool red = !green;

    [self.xKey setGreenRed:green :red :6];
    [self.xKey setGreenRed:green :red :7];

    [self.xKey setAllBlueOnOffOnOffVal:false :6];
    [self.xKey setAllBlueOnOffOnOffVal:false :7];
    
    int unitId = (currentTrack % 16) < 8 ? 6 : 7;
    
    UInt8 array[] = {0,1,2,3,4,5,8,9};
    
    UInt8 index = array[_currentTrack % 8];
    
    [self.xKey setLEDForUnitID:unitId :index :1];

}

-(NSInteger)currentTrack{
    return  _currentTrack;
}
#pragma mark -
#pragma mark -------------- v1.00.06 -----------------------

-(void)toggleOpaque{
    
    _overlayWindowController.viewController.opaque = !_overlayWindowController.viewController.opaque;
//    [self setLEDForUnitID:9 :41 :_overlayWindowController.viewController.opaque]; // 1.00.23
    
//    [_overlayWindowController.viewController bringToFront];

    
}
//-(void)showBoomRecorderServerAnnunciator:(NSInteger)online{
//    
//    [_matrixWindowController showBoomRecorderServerAnnunciator:online];
//    
//}
-(NSInteger)tcType{
    
    // this is for the TcFormatters
    
    Document *doc = [self topDocument];
    if(doc) return doc.tcType;
    else return TCTYPE_24;  // default is 24fps
    
}
#pragma mark -
#pragma mark -------------- preferences -----------------------

- (IBAction)onPreferences:(id)sender {
    
    if(_preferencesWindowController == nil){
        
        _preferencesWindowController = [[PreferencesWindowController alloc]initWithWindowNibName:@"PreferencesWindowController"];
        
        [[_preferencesWindowController window] makeKeyAndOrderFront:nil];   // give it the focus
        [NSApp activateIgnoringOtherApps:YES];
    }else{
        
        [[_preferencesWindowController window] performClose:nil];
        _preferencesWindowController = nil;
        
    }
}
//- (IBAction)onEnBlackCueBlack:(id)sender {
//
//    NSString *key = @"enBlackCueBlack";
//    NSInteger state = [[NSUserDefaults standardUserDefaults] integerForKey:key];
//
//    if(_streamerWindowController){
//
//        NSInteger pictureTag = [_streamerWindowController pictureTag];
//        if(pictureTag == 3 && state == 0)   // black/cue/black, but black/cue/black inhibited
//            [_streamerWindowController setPictureTag:2];    // set to rgb fade
//
//
//    }
//    [self setLEDForUnitID:9 :36 :state == NSControlStateValueOn];
//}

#pragma mark -
#pragma mark -------------- XKey helpers -----------------------
-(void)unit67Service:(NSInteger)unitID :(NSInteger)key{
    
    if(key < 0){
        // trailing edge service
        [self clearCopyDown];
        return;
    }
    
    NSInteger track = self.currentTrack & 0x10; // stay in the group of 16
    
    if(self.keyboardIsShifted){
        track ^= 0x10;  // go to the other group of 16
    }
    track += unitID == 6 ? 0 : 8;
    
    switch(key){
        case 0:  break;
        case 6:  track += 1; break;
        case 12: track += 2; break;
        case 18: track += 3; break;
        case 1:  track += 4; break;
        case 7:  track += 5; break;
        case 13: track += 6; break;
        case 19: track += 7; break;
        default: break;
    }
    NSEvent *event = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
                                    location:NSMakePoint(0, 0)
                                    modifierFlags:0
                                    timestamp:0
                                    windowNumber:0
                                    context:nil
                                    subtype:NSEventSubtypeApplicationActivated
                                    data1:track
                                    data2:9];
    
    [self trackMem9:event];

}
-(void)xKeyPressed:(NSInteger)unitID :(NSInteger)key{
    // leading edges are positive, trailing edges are negative
    // the only jump table we use is unit_8_dictionary,unit_8_dictionary_shifted
    
    // items in string are unitId, key, shift
    
    NSString *str = [NSString stringWithFormat:@"%ld,%ld,0",unitID,key];
    switch(unitID){
            // unit 8 jump table has not changed
        case 8: [self rxOsc:str]; break;
        case 7: [self unit67Service:unitID :key]; break;
        case 6: [self unit67Service:unitID :key]; break;
        default: break;
    }
    

}
#pragma mark -
#pragma mark -------------- helper fns -----------------------
-(NSString*)stripNonAscii:(NSString*)cmd{
    
    // we see non-ascii text at times
    // 2019 '
    // 201c "
    // 201d "
    
    NSString *result = @"";
    
    for(NSInteger i = 0; i < cmd.length; i++){
        
        if([cmd characterAtIndex:i] > 127) {
            NSLog(@"non-ascii char: %0x",(unichar)[cmd characterAtIndex:i]);
            continue;    // keep ASCII, Latin 1
        }
        
        result = [result stringByAppendingString:[cmd substringWithRange:NSMakeRange(i, 1)]];
    }
    
    return result;   //
}

-(bool)isAleMini{
    return false;
}
-(float)maxDocWindowWidth{
    
    NSRect rect = [[_editorWindowController window] frame];
    
    return rect.size.width;
}
//-(unsigned char)midiCustomFillState{
//    // the last micState (round button lower right) is the 'custom fill' state
//
//    return [_micDictionary[@"90787f"] isEqualToString:MIC_ON];
//
////    return micState[CUSTOM_FILL_INDEX];
//
//}
#pragma mark -
#pragma mark --------------------- MIDI messages to MIDI to closure converter -------------------------
-(void)sendMidiToClosure{
    
    /*
     Evan request 6/19/17
     Would you be willing to add a few more MIDI output state status indicators to ALEDOC?  Specifically, Reh, Rec, PB modes, Cycle, and "in cue".
     */
    
      //     Comp Track "armed": Note #69
  
//     Logic output tied to the beeps (blinks on with each beep): Note #68
//aheadinpast
    Byte trigger[] = {0xb0,1,0};    // CC, aheadInPast
    
    trigger[2] = (Byte)[_matrixWindowController aheadInPast];
    [_statusClient midiTx:[NSData dataWithBytes:trigger length:3]]; // aheadInPast

    trigger[1] = 2; // Rehearse Record Playback
    trigger[2] = (Byte)(_matrixWindowController.rehRecPb % 4);
    [_statusClient midiTx:[NSData dataWithBytes:trigger length:3]]; // OFF Rehearse Record Playback
    
    trigger[1] = 3; // CYCLE closure
    trigger[2] = _cycleMotion != CYCLE_MOTION_IDLE ? 127 : 0;
    [_statusClient midiTx:[NSData dataWithBytes:trigger length:3]]; // cycle closure
    //2.10.02
    trigger[1] = 4; // REC + CYCLE
    trigger[2] = self.cycleMotion != CYCLE_MOTION_IDLE && _matrixWindowController.rehRecPb == MODE_CONTROL_RECORD ? 127 : 0;
    [_statusClient midiTx:[NSData dataWithBytes:trigger length:3]]; //
    
    // 2.00.00 move all MIDI status outputs here
    trigger[1] = 5; // Delay window visible
    trigger[2] = _videoDelayWindowController.window.isVisible ? 127 : 0;
    [_statusClient midiTx:[NSData dataWithBytes:trigger length:3]]; //


    int rrpb = _matrixWindowController.rehRecPb % 4;  // state indexes are not-pending

    // Evan's MIDI tallies FIXME these should not be going to PT?
    trigger[0] = 0x90;
    //     Rehearse Mode: Note #60
    trigger[1] = 60;
    trigger[2] = rrpb == MODE_CONTROL_REHEARSE ? 127 : 0;
    [_ptClient midiTx:[NSData dataWithBytes:trigger length:3]];
    //     Record Mode: Note #61
    trigger[1] = 61;
    trigger[2] = rrpb == MODE_CONTROL_RECORD ? 127 : 0;
    [_ptClient midiTx:[NSData dataWithBytes:trigger length:3]];
    //     Playback Mode: Note #62
    trigger[1] = 62;
    trigger[2] = rrpb == MODE_CONTROL_PLAYBACK ? 127 : 0;
    [_ptClient midiTx:[NSData dataWithBytes:trigger length:3]];

    
}
#pragma mark -
#pragma mark ---------------- TcCalculatorDelegate -----------------------

-(bool)ignoreTcStartHours{
    return true;
}

#pragma mark -
#pragma mark ---------------- TCFormatterDelegate -----------------------
-(NSString*)getTcStartForObject:(id)obj{
    
    return [self getTcStart];
}
-(NSString*)getTcStart{
    
    Document *doc = [self topDocument];
    
    return [doc timeCodeStart];

}
-(NSInteger)getDisplayFormat{
    
    Document *doc = [self topDocument];
    return doc.tableContentsDisplayFormat;
}
-(bool)headerInTc{
    
    Document *doc = [self topDocument];
    
    NSString *fmtString = [doc.headerDictionary objectForKey:@"DISPLAY_FORMAT"];
    
    if(!fmtString || [fmtString isEqualToString:@"TC"]) return true; // default is tc
    
    return false;
    
}

#pragma mark -
#pragma mark ---------------- AdrClientWindowControllerDelegate -----------------------
// stubs, used by AleMini
-(void)showTargetTrackTitle:(NSString *)title{}
-(NSString*)getTargetTrackTitle{return @"";}
-(void)setTargetTrackByLastMouseUpAfterQueue{}
-(void)unmuteTargetByLastMouseUpAfterQueue{}
-(void)grabAllAfterQueue{}
-(bool)testGrabAllTimeout{return false;}
//-(void)midiKeyboardServiceAfterQueue:(NSString*)msg{}
-(void)initGrabAllTimeout{}
-(void)grabAllTimeout{}
-(bool) getTrackPosIsInhibited{return false;}
-(void) initDisplayFormat:(NSInteger)fmt{}

#pragma mark -
#pragma mark ----------- MidiHuiDelegate -----------------

-(void)didRxPing{
    // set the blinker in MADI monitor to green
    
    [_matrixWindowController setMidiState:true];
}

-(void)showProtoolsCtr:(NSString*)ctr{
    
    Document *doc = [self topDocument];
    [doc setCtr:ctr];
    
    // this causes us to go to Ahead, Evan wants that to happen only in CYCLE
    
    //    if([_tcc isFtFr:ctr]) return;   // FIXME temp punt
    //
    //    if (_cycleMotion == CYCLE_MOTION_IDLE) {
    //        [_matrixWindowController aheadInPastFromTc:ctr];    // set from here when not running
    //
    //    }
    
}

-(void)showMotionStatus:(NSData*)motionData{
    
    unsigned char * theBytes = (unsigned char *)[motionData bytes];
    [self.matrixWindowController decodeMotionZoneByte:theBytes[0]];
    
    // 3/4/16 first streamer has beeps
//    if([_ptHui isStop]){
//        [_streamerWindowController setArmBeeps:true];
//    }
    
}

-(void)showDisplayStatus:(NSData*)data{
    
    //   16 |timecode|feet    |beats   |rudesolo|
    Byte fmt = *(Byte *)[data bytes];
    
//    NSLog(@"showDisplayStatus %x",fmt);
    
    // we need for these to not give AleDoc the focus
    // on 1 computer, Protools needs to keep the focus to
    // set the tc at zero feet
    
    switch(fmt){
        case 1: [self toggleToTc]; break;
        case 2: [self toggleToFt]; break;
        default:
            break;
            
    }
    
}
-(void)relayMidiData:(NSData*)data{}

-(void)showMutes:(NSData*)data{}

// there is a separate mtc delegate because we want
// to have separate menu items for mtc and protools


#pragma mark -
#pragma mark ----------- MidiHuiMtcDelegate -----------------

-(void)showTcDigits:(NSString*)ctr{
    
    // checking timing between Metal and mtc at :00 frame 
    // we see that mtc and vertical sync are not synchronized
    // we expect, then, a 1 field variance in streamer starts
//    NSString *trimmedString=[ctr substringFromIndex:MAX((int)[ctr length]-2, 0)]; //in case string is less than 4 characters long.
//    if([trimmedString isEqualToString:@"00"]){
//        // using values captured not in the main thread...
//        [_overlayWindowController.viewController tiSinceLastDraw:_mtcHui.frameDate];
//
//
//
//    }
    
    // we are on the main thread
    Document *doc = [self topDocument];
    [doc setTc:ctr];
    [_matrixWindowController setMtcString:ctr];
    
    // moved from decodeMotionZoneByte because there is no status
    // sent while running
//    NSLog(@"motionZoneByte %d snoopAuto %d",_matrixWindowController.motionZoneByte,_snoopAuto);
//    if(_snoopAuto && (_matrixWindowController.motionZoneByte & 0x30) == 0x30){
//        self.snoopState = SNOOP_STATE_OFF;
//    }else{
//        self.snoopState = SNOOP_STATE_ON;
//    }

    // streamers only in cycle
    if(_cycleMotion != CYCLE_MOTION_IDLE && doc.recordCycleDictionary){

        [_streamerWindowController triggerStreamer:ctr];    // MTC timing is far better than pt counter timing
    }
}
-(void)mtcLocked:(NSNumber*)lockState{     // to indicator
    
    NSInteger state = [lockState integerValue];
    
    [[_matrixWindowController mtcAnnunciator] setState:state];
    
}
-(void)triggerStreamer{
    [_overlayWindowController.viewController.streamer triggerStreamer:_streamerWindowController.streamerColor];
}

//-(void)mtcNotLocked{}    // to indicator
//-(void)mtcLocked{}      // to indicator

//#pragma mark -
//#pragma mark ----------- LaunchPadMiniDelegate -----------------

//-(void)launchPadKeyPressed:(NSData*)data{
//
//    // we are in the main thread
//
//    if(data.length != 3) return;
//    unsigned char *buffer = (unsigned char*)[data bytes];
//
//    NSString *msg = [NSString stringWithFormat:@"%02x%02x%02x",buffer[0],buffer[1],buffer[2]];  // like '90287f'
//
//    NSInteger status =  [self midiKeyboardService:msg];
//
//    if(status < 0 && buffer[2])[_ptClient midiTx:data]; // relay unused 'on' key presses to output
//
//}
//-(void)initAipHead{
//
//    // micDictionary has to be valid by this point
//    [self sendToMicAccessoryForKeys:nil];   // defaults to all keys
//    [self futzOff]; // calls aipShow
//
//}

#pragma mark -
#pragma mark ----------- AccessoryDelegate -----------------

-(void)accessoryService:(NSData*)data{
    
    unsigned char bytes[data.length];
    [data getBytes:bytes length:data.length];
// tickle github
    switch(bytes[0]){
        case 0xb0:
            switch(bytes[1]){
                case 31:    // talkback A
                    _matrixWindowController.dimA = bytes[2] ? _matrixWindowController.dimA | DIM_MIDI_MASK : _matrixWindowController.dimA & ~DIM_MIDI_MASK;
                    break;
                case 32:    // talkback B
                    _matrixWindowController.dimB = bytes[2] ? _matrixWindowController.dimB | DIM_MIDI_MASK : _matrixWindowController.dimB & ~DIM_MIDI_MASK;
                    break;
                case 33:    // talkback C
                    _matrixWindowController.dimC = bytes[2] ? _matrixWindowController.dimC | DIM_MIDI_MASK : _matrixWindowController.dimC & ~DIM_MIDI_MASK;
                    break;
                case 34:    // talkback D
                    _matrixWindowController.dimD = bytes[2] ? _matrixWindowController.dimD | DIM_MIDI_MASK : _matrixWindowController.dimD & ~DIM_MIDI_MASK;
                    break;
                default:
                    break;
            }
            break;
        default:
            break;
    }
    
    
}
#pragma mark ----------- lpMiniDelegate -----------------
-(void)toggleMatrixButton:(NSInteger)index :(NSInteger)buttonTag{
    
    Matrix *matrix = [_matrixWindowController.displayedMatrixArray objectAtIndex:index];
    
    if(matrix.controlsDisabled){
        return; // 2.10.02, Remote Actor, Remote Editor can be disabled
    }
    
 
//    [matrix toggleStates:(int)buttonTag];
    
    // 2.10.02 'Link Comp, PB Routing' and 'Enable In/Past Switching'
    // make the states of the linked buttons follow
    
    NSInteger state = [matrix toggleStates:(int)buttonTag];//[matrix stateForTag:buttonTag];
    
//    NSButton *button = [[NSButton alloc] init];
//    button.tag = buttonTag;
//    button.state = state;
//    [matrix buttonPressed:button];
    
    [_matrixWindowController saveUserDefaults:self];

}
-(bool)getMatrixButton:(NSInteger)index :(NSInteger)buttonTag{
    
    Matrix *matrix = [_matrixWindowController.displayedMatrixArray objectAtIndex:index];
    return (bool)[matrix stateForTag:buttonTag];
}
#pragma mark ----------- OscServerDelegate -----------------
-(void)txOsc:(NSString *)str{
    
    // looking for lpmini
    if([str containsString:@"lpMini"]){
        if([str containsString:@"-"]){
            NSLog(@"bad lpMini index");
            
        }
    }
    
    // remove trailing whitespace
    NSString *msg = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    msg = [msg stringByAppendingString:@"\n"];  // make sure there is a terminator
    
    if(_oscServer){
//        NSLog(@"txOsc %@",msg);
        [_oscServer transmit:msg];
        
    }
}
NSMutableDictionary *midiFilterDictionary;

-(void) performActions:(NSString*)str{
    
    // items that are not button jump table items
    
    str = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if([str containsString:@"\n"]){
        // multiline messages
        NSArray *array = [str componentsSeparatedByString:@"\n"];
        
        if([array[0] isEqualToString:@"filterItems"]){
            
            // MIDI strings that set, clear Companion indicators
        
        midiFilterDictionary = [[NSMutableDictionary alloc] init];
        
            for(int i = 1; i < array.count; i++){
                
                NSArray *filterItemArray = [array[i] componentsSeparatedByString:@"\t"];
                
                if(filterItemArray.count == 4){
                    
                    midiFilterDictionary[filterItemArray[0]] = @{
                        @"midiRxPort"       : filterItemArray[1],
                        @"midiMessageSet"   : filterItemArray[2],
                        @"midiMessageClear" : filterItemArray[3]
                    };
                    
                }
            }
            
        }
        return;

    }
    
    // not multiline
    // there is no command table, because we don't have many cases
        
    NSArray *array = [str componentsSeparatedByString:@"\t"];
    
    if([array[0] isEqualToString:@"filterItemChanged"]){
        
        // when Companion feedbacks are edited, we get a change message
        
        if(array.count == 5){
            
            midiFilterDictionary[array[1]] = @{
                @"midiRxPort"       : array[2],
                @"midiMessageSet"   : array[3],
                @"midiMessageClear" : array[4]
            };
            
        }
        return;
    }

    if(array.count == 3 && [array[0] isEqualToString:@"MIDI_TX"]){
        
        // Companion is sending MIDI
        
        //    { id: '0', label: 'Accessory' },
        //    { id: '1', label: 'Status' },
        //    { id: '2', label: 'Remote' },
        //    { id: '3', label: 'UFX' },
        //    { id: '4', label: 'Control 1' },
        //    { id: '5', label: 'Control 2' },

            NSDictionary *portDictionary = @{
                @"0" : _lpMini.accMidi.midiClient
                ,@"1" : _statusClient
                ,@"2" : _matrixWindowController.boomRecorderMIDI
                ,@"3" : _ufxClient
                ,@"4" : _control1Client
                ,@"5" : _control2Client
            };

        MidiClient *client = portDictionary[array[1]];

        array = [array[2] componentsSeparatedByString:@","];
        NSMutableData *data = [[NSMutableData alloc]init];
        
        for (int i = 0; i < array.count; i++){
            
            unsigned char bytes[] = {(unsigned char)[((NSString*)array[i]) intValue]};//{(unsigned char)[((NSString*)array[i]) intValue]};
            
            [data appendBytes:bytes length:1];
            
        }
        
        if(client){
            [client midiTx:data];
        }
        
    }

}
-(void)midiToOsc:(NSData*)data :(NSString*)title{
    
    //    { id: '0', label: 'Accessory' },
    //    { id: '1', label: 'Status' },
    //    { id: '2', label: 'Remote' },
    //    { id: '3', label: 'UFX' },
    //    { id: '4', label: 'Control 1' },
    //    { id: '5', label: 'Control 2' },
    
    NSDictionary *dict = @{
        @"Accessory" : @"0",
        @"Status" : @"1",
        @"Remote" : @"2",
        @"UFX" : @"3",
        @"Control 1" : @"4",
        @"Control 2" : @"5",
    };
    
    if(dict[title]){    // this MIDI port is in the Companion dropdown
        
        unsigned char bytes[data.length];
        [data getBytes:bytes length:data.length];
        
        NSString *midiStr = @"";
        
        // append midi bytes, separated by commas
        for(int i = 0; i < data.length; i++){
            
            midiStr = [midiStr stringByAppendingFormat:@"%d,",bytes[i]];
            
        }
        // trim the last comma
        midiStr = [midiStr stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]];
        
        // only send messages that Companion responds to
        // if midiStr is in midiFilterDictionary, send it
        for(NSString *key in [midiFilterDictionary allKeys]){
            
            NSDictionary *filterDictionary = midiFilterDictionary[key];
            
            if(![dict[title] isEqualToString:filterDictionary[@"midiRxPort"]]){
                continue;   // not our port
            }
            
            if([midiStr isEqualToString:filterDictionary[@"midiMessageSet"]] ||
               [midiStr isEqualToString:filterDictionary[@"midiMessageClear"]]){
                
                // send the port number and the midi string, match sets or clears indicator
                [self txOsc:[NSString stringWithFormat:@"midiRx\t%@\t%@",dict[title],midiStr]];
                break;
           }
        }
    }

}
-(void)rxOsc:(NSString *)str{
    
//    NSLog(@"rxOsc: %@",str);   // 8,64,false
    
    NSArray *array;
    
    // messages with CR or TAB are not jump table messages
    
    if([str rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\t\n"]].location != NSNotFound){
        
        [self performActions:str];  // not a jump table message
        return;

    }
    // jump table message
    // items in string are unitId, key, shift
    array = [str componentsSeparatedByString:@","];
    
    if(array.count != 3){
        return;
    }
    
//    NSLog(@"rxOsc %@ cycleMode %ld",str, _cycleMode);
    
    // 2.10.02 12/4/23
    // if FINALIZE_RECORD, the only buttons allowed are  Debug Stop/Cancel, REHEARSE, RECORD, PLAYBACK, CYCLE, and talkbacks
    if( _cycleMode == CYCLE_MODE_FINALIZE_RECORD){
        
        NSArray *btns = @[@"9,65,false",
                          @"9,66,false",
                          @"8,43,false",
                          @"8,44,false",
                          @"8,45,false",
                          
                          // 12/19/23 added talkbacks to exceptions
                          @"9,73,false",
                          @"9,-73,false",    // dimA
                          @"9,74,false",
                          @"9,-74,false",    // dimB
                          @"9,109,false",
                          @"9,-109,false",    // dimC
                          @"9,110,false",
                          @"9,-110,false",    // dimD
        ];
        
        
        if(![btns containsObject:[str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]){
            
            return; // not a button allowed in CYCLE_MODE_FINALIZE_RECORD
            
        }
//        NSLog(@"CYCLE_MODE_FINALIZE_RECORD allowed %@",str);
        
    }
    
    bool isShifted = [array[2] isEqualToString:@"true"] || self.keyboardIsShifted;
    NSString *unitID = array[0];
    NSString *key = array[1];
    
    switch(unitID.integerValue){
        case 10:
            [_lpMini cmdDecoder:array[1]];  // 02/06/23 better organized lp mini
            return;
        default: break;
    }

    // the commands have an event operand
    NSEvent *event = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
                                           location:NSMakePoint(0, 0)
                                      modifierFlags:0
                                          timestamp:0
                                       windowNumber:0
                                            context:nil
                                            subtype:NSEventSubtypeApplicationActivated
                                              data1:[key integerValue]
                                              data2:[unitID integerValue]];
    
//        NSLog(@"event nil: %d",event == nil);
//        if(event){
//            NSLog(@"event.data1,data2: %ld,%ld",event.data1,event.data2);
//        }

    NSDictionary *dictionary = isShifted ? [_unitIDDictionary_shifted objectForKey:unitID] : [_unitIDDictionary objectForKey:unitID];  // jump table
    
    if(dictionary){
        
        NSString *methodString = [dictionary objectForKey:key];
        
        if(methodString){
            
            SEL aSelector = sel_registerName((const char*)[methodString UTF8String]);
            
            if([self respondsToSelector:aSelector]){

                // http://stackoverflow.com/questions/7017281/performselector-may-cause-a-leak-because-its-selector-is-unknown
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                // _midiKeyDictionary passes the key, not the event
                id anObject = dictionary == _midiKeyDictionary ? key : event;
                [self performSelectorOnMainThread:aSelector withObject:anObject waitUntilDone:false];
//#pragma clang diagnostic pop

            }
            
        }
        
    }

    
}
-(void)connectionReady:(nw_connection_t) connection{
    
//    NSLog(@"connectionReady %@",connection);
    // when ready, initialize companion indicators
    [_audioPlayerWindowController initLoopButtons];
    [self initCompanionLeds];   // KVO items
    [self initUnit_8_LEDs]; // initialize unit 8 companion indicators
    [self initUnit_9_LEDs]; // initialize unit 9 companion indicators
    [_lpMini initAipHead];     // AIP buttons are also done in companion
    [self txOsc:@"filterItems 0"];    // get MIDI feedbacks (companion needs an operand)
    
}

#pragma mark -
#pragma mark ----------- MIDI helpers -----------------
-(bool)isStop{
    
    return [_ptHui isStop];
    
}
-(BOOL)isPlay{
    
    return [_ptHui isPlay];
    
}
-(bool)isRecord{
    
    return [_ptHui isRecord];
    
}

-(int)getTcType{
    
    return [_mtcHui getTcType];
    
}

-(int)getDropoutDownCtr{
    
    return [_mtcHui dropoutDownCtr];
}
-(void)onMidiRecord{
    
    [_ptHui onRecord];
}

-(void)onMidiStop{
    
    [_ptHui onStop];
}

-(unsigned char)getDisplayFmt{
    
    return [_ptHui getDisplayFmt];
}

-(void)onMidiShuttle{
    
    [_ptHui onShuttle];
    
}
-(void)onMidiJog{
    
    [_ptHui onJog];
    
}
-(void)onMidiPlay{
    
    [_ptHui onPlay];
    
}
-(void)onMidiTransport{
    
    [_ptHui onTransport];
}
//-(void)txMidi:(NSData*)data{
//    
//    [_ptClient midiTx:data];
//    
//}
//-(void)txMidiToAcc:(NSData*)data{
//
//    [_lpMini.accMidi.midiClient midiTx:data];
//
//}
// throttle test for UFX send
// we have a UFX rx problem when we send all crosspoints
NSTimer *ufxThrottleTimer;
NSMutableArray *ufxStringArray;
-(void)ufxThrottleTimerService{
    
    if(ufxStringArray.count > 0){
        
        NSString *str = ufxStringArray[0];
        [ufxStringArray removeObjectAtIndex:0];
        
        NSScanner *scanner = [NSScanner scannerWithString:[str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        
        int result;
        NSMutableData *data = [[NSMutableData alloc] init];

        while([scanner scanInt:&result]){
    //        NSLog(@"%d",result);
            
            unsigned char c = result;
            [data appendBytes:&c length:1];
        }
        
        
        unsigned char *bytePtr = (unsigned char *)[data bytes];
        
        // check for missing outputs (1st test), missing inputs (2nd test)
        if((data.length > 0 && bytePtr[0] == 0) || (data.length > 3 && bytePtr[3] == 0)){
            return; // unused channels at 192K have 0
        }
        
    //    NSLog(@"%@",str);
        [_ufxClient midiTx:data];
    }
    
}
-(void)sendUfxStringThrottled:(NSString*)str{
    
    if(!ufxStringArray){
        ufxStringArray = [[NSMutableArray alloc]init];
    }
    
    [ufxStringArray addObject:str];
    
    if(!ufxThrottleTimer || !ufxThrottleTimer.isValid){
        
        ufxThrottleTimer = [NSTimer scheduledTimerWithTimeInterval:0.0003 target:self selector:@selector(ufxThrottleTimerService) userInfo:nil repeats:true];
        
    }

}
-(void)sendUfxString:(NSString*)str{
    
//    if([str containsString:@"180 116"]){
//        NSLog(@"sendUfxString: %@",str);
//    }
//    NSLog(@"sendUfxString: %@",str);
    
    NSScanner *scanner = [NSScanner scannerWithString:[str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    
    int result;
    NSMutableData *data = [[NSMutableData alloc] init];

    while([scanner scanInt:&result]){
//        NSLog(@"%d",result);
        
        unsigned char c = result;
        [data appendBytes:&c length:1];
    }
    
    unsigned char *bytePtr = (unsigned char *)[data bytes];
    
    // check for missing outputs (1st test), missing inputs (2nd test)
    if((data.length > 0 && bytePtr[0] == 0) || (data.length > 3 && bytePtr[3] == 0)){
        return; // unused channels at 192K have 0
    }
    
//    NSLog(@"%@",str);
    [_ufxClient midiTx:data];
    
}
-(void)alertErr:(NSString*) msg : (NSString*) info{
    
    [NSApp activateIgnoringOtherApps:YES];  // brings our alert to the front

    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleCritical;
    alert.messageText = msg;
    alert.informativeText = info;
    
    Document* doc = [self topDocument];
    
    if(doc){
        [alert beginSheetModalForWindow:doc.docWindow completionHandler:^(NSInteger result) {
            NSLog(@"Success");
        }];
    }else{
        [alert runModal];   // case where there is no document
    }
}

// MARK: ---------- swiftUI helpers ------------

// SwiftUI calls aleDelegate to get at XIB stuff
// AleDelegate has a reference to screenRecorder so set SwiftUI stuff

-(void)onFullScreen{
    
    if(!_videoDelayWindowController || _videoDelayWindowController.window.isVisible == false){
        return;
    }
    
    NSWindow *window = _videoDelayWindowController.window;
    
    bool fullScreen = [[NSUserDefaults standardUserDefaults]boolForKey:@"delayFullScreen"];
    NSInteger screenSelector = [[NSUserDefaults standardUserDefaults]integerForKey:@"videoScreenSelector"];
    screenSelector %= NSScreen.screens.count;
    
    NSScreen *screen = NSScreen.screens[screenSelector];
    
    [window setFrameOrigin:screen.frame.origin];
    
    if(fullScreen){
        
        window.styleMask = NSWindowStyleMaskFullSizeContentView;
        window.titlebarAppearsTransparent = true;
        window.titleVisibility = NSWindowTitleHidden;
        [window setFrame:screen.frame display:true];
        
    }else{
        
        window.styleMask = NSWindowStyleMaskTitled + NSWindowStyleMaskClosable;
        window.titlebarAppearsTransparent = false;
        
        NSRect frame = screen.frame;
        frame.size.width /= 2;
        frame.size.height /= 2;
        [window setFrame:frame display:true];
        
    }
}
-(void)doSomething{
}


@end
