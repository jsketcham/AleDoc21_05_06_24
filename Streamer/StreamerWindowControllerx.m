//
//  StreamerWindowController.m
//  Ale_v3xx
//
//  Created by James Ketcham on 3/31/14.
//  Copyright (c) 2014 WB ADR. All rights reserved.
//

#import "StreamerWindowControllerx.h"
//#import "VM15Window.h"
#import "AleDelegate.h"
#import "TcpClientConnection.h"
#import "Document.h"
#import "MatrixWindowController.h"
#import "Annunciator.h"
#import "TcCalculator.h"
#import "TCFormatter.h"
//#import "MidiClient.h"
#import "EditorWindowController.h"
//#import "Chunk.h" // 2.00.00 no more chunks
//#import "NSImage+DrawAttributedString.h"
#import "ColorSupport.h"
#import "MidiClient_v2.h"   // 1.00.12 tx MIDI streamer triggers
#import "AleDoc21-Swift.h"    // must be here to avoid a circular reference

//#import "TextWindowClient.m"

@interface StreamerWindowController (){
    bool didTrigger;    //
}
//#define RESTART_TIMEOUT 20.0
//#define MIN_STREAMER_VERSION @"NE64:4.03.38"

@property MidiClient *streamerClient;    // 1.00.12 tx MIDI streamer triggers

//@property (weak) IBOutlet Annunciator *streamerAnnunciator;
@property TcCalculator *tcc;
@property TCFormatter *tcf;
@property AleDelegate* aleDelegate;

@end

@implementation StreamerWindowController

@synthesize punchEnable = _punchEnable;
@synthesize beepsEnable = _beepsEnable;
@synthesize streamerEnable = _streamerEnable;
@synthesize punchColor = _punchColor;
@synthesize streamerColor = _streamerColor;
@synthesize endBarColor = _endBarColor;
@synthesize tcc = _tcc;
@synthesize tcf = _tcf;
@synthesize inhibitStreamerInPlayback = _inhibitStreamerInPlayback;
@synthesize aleDelegate = _aleDelegate;
@synthesize punchList = _punchList;
@synthesize punchListItem = _punchListItem;

@synthesize topMask = _topMask;
@synthesize bottomMask = _bottomMask;
@synthesize rightMask = _rightMask;
@synthesize leftMask = _leftMask;
@synthesize transparencyMask = _transparencyMask;
@synthesize pictureTag = _pictureTag;
@synthesize fadeSeconds = _fadeSeconds;

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    
    if (self) {
        // Initialization code here.
        
        
//        [self setBmpHeight:31];
//        [self setBmpWidth:32];  // TODO remove after debug
        
        NSDictionary *registrationDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [[NSNumber alloc]initWithBool:true],@"inhibitStreamerInPlayback",
                                              [[NSNumber alloc]initWithDouble:1.0],@"fadeSeconds",
                                              nil];
        [[NSUserDefaults standardUserDefaults] registerDefaults:registrationDefaults];
        
        _tcc = [[TcCalculator alloc] init];
        _tcf = [[TCFormatter alloc]init];
        
        _aleDelegate = (AleDelegate *)[NSApp delegate];
        
        _punchList = _aleDelegate.overlayWindowController.viewController.streamer.punchList;
        
        NSInteger punchIndex = _aleDelegate.overlayWindowController.viewController.streamer.punchIndex;
        _punchListItem = [_punchList objectAtIndex:punchIndex];

        _topMask = _aleDelegate.overlayWindowController.viewController.streamer.topMask;
        _bottomMask = _aleDelegate.overlayWindowController.viewController.streamer.bottomMask;
        _rightMask = _aleDelegate.overlayWindowController.viewController.streamer.rightMask;
        _leftMask = _aleDelegate.overlayWindowController.viewController.streamer.leftMask;
        _transparencyMask = _aleDelegate.overlayWindowController.viewController.streamer.transparency;
        
        [[NSUserDefaults standardUserDefaults]setBool:true forKey:@"enStreamer"];
        
    }
    return self;
}

#define PING_INTERVAL 3.0
- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

-(void)txMidiAsString:(NSData*)midi{
    
//    // work around to avoid mixing MIDI and text
//    NSString *msg = @"midi";
//
//    unsigned char *bytes = (unsigned char *)[midi bytes];
//
//    for(int i = 0; i < midi.length; i++){
//
//        msg = [msg stringByAppendingString:[NSString stringWithFormat:@" %x",bytes[i]]];
//    }
//
////    NSLog(@"%@",msg);
//
//    [self txMsg:msg];
//    NSLog(@"%@",msg);
}
#pragma mark -
#pragma mark ------------ actions ---------------------

- (IBAction)onTextNextScreen:(id)sender {
    [_aleDelegate nextScreen];
}
#pragma mark -
#pragma mark ------------ annunciator routines and bindings ---------------------

- (IBAction)onPunchImage:(id)sender {
    [_aleDelegate.overlayWindowController.viewController.streamer setPunchLayer];
}

- (IBAction)onPunchColor:(id)sender {
    [_aleDelegate.overlayWindowController.viewController.streamer setPunchLayer];
}

//-(void)setModeControl:(int) tag{
//    
//    [(AleDelegate*)[NSApp delegate] setModeControl:tag];    // message to the recorder window (if it exists)
//    
//}
//-(void)forceBlack:(bool) black{
//    
////    NSLog(@"forceBlack %d",black);
//    
//    
//    
//    
//    Byte trigger[] = {0x90,108,64}; // any velocity goes to black
//    
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//    if (delegate.hidePix) black = true;
//    
//    trigger[2] = black; 
//    
//    [self txMidiAsString:[NSData dataWithBytes:trigger length:3]];    // tx data bytes to tcp (vm15 decodes messages that start with top bit set as MIDI)
//    
//    //     Pix show/hide: Note #70
//    trigger[1] = 70;
//    trigger[2] = black ? 0 : 127;
//    [delegate.midiClient txMidi:[NSData dataWithBytes:trigger length:3]];
//    
//}
//- (IBAction)onAnnunciatorPointComboBox:(id)sender {
//
////    // set annunciator point
////    NSComboBox *combo = sender;
////    int point = [[combo objectValueOfSelectedItem] intValue];
////    VM15Window *vm15Window = [_draggableItemView selectWindow:1];   // annunciator is window 1
////    vm15Window.point = point;
////
////    [self txMsg:[vm15Window toString]];
////
////    NSInteger state = 0;
////
////    AleDelegate *aleDelegate = (AleDelegate*)[NSApp delegate];
////    MatrixWindowController *mwc = aleDelegate.matrixWindowController;
////
////    if(mwc)
////        state = mwc.modeControl;
////
////    [self txMsg:[NSString stringWithFormat:@"U %d\n",(int)state]];
////    NSLog(@"onAnnunciatorPointComboBox");
//}
//-(NSInteger)rehRecPbState{
//    
//    return state;
//}

//-(void)sendFaderSettings{
//
////    int pictureIndex = (int)[_pictureFadeFramesComboBox indexOfSelectedItem];
////    int annunciatorIndex = (int)[_fadeFramesComboBox indexOfSelectedItem];
////    int holdFrames = [_holdFramesTextField intValue];
////
////    NSString *msg = [NSString stringWithFormat:@"D %d %d %d\n",pictureIndex,annunciatorIndex,holdFrames];
////    [self txMsg:msg];
//
//}

//- (IBAction)onHoldFramesTextField:(id)sender {
//    [self sendFaderSettings];
//}

//- (IBAction)onFadeFramesComboBox:(id)sender {
//    [self sendFaderSettings];
//}
- (IBAction)onPictureMatrix:(id)sender{
//    NSLog(@"onPictureMatrix");
    switch(self.pictureTag){
        case TAG_ALWAYS_ON:
            [_aleDelegate.overlayWindowController.viewController.streamer fadeToBlack:false :_fadeSeconds];
            break;
        case TAG_FADE_IN:
        case TAG_BLACK_CUE_BLACK:
            if(![_aleDelegate.ptHui isPlay]){
                
                [_aleDelegate.overlayWindowController.viewController.streamer fadeToBlack:true :_fadeSeconds];

            }
            break;
        default: break;
    }
    
    [_aleDelegate setLEDForUnitID:9 :70 :self.pictureTag == TAG_ALWAYS_ON];
    [_aleDelegate setLEDForUnitID:9 :71 :self.pictureTag == TAG_FADE_IN];
    [_aleDelegate setLEDForUnitID:9 :72 :self.pictureTag == TAG_BLACK_CUE_BLACK];

}
//- (IBAction)onPictureFadeFramesComboBox:(id)sender {
//    [self sendFaderSettings];
//}
//-(void)txDataBytes:(NSData*)data{
//    
////    id delegate = [NSApp delegate];
////    
////    if([delegate respondsToSelector:@selector(txDataBytes:)]){
////        
////        [delegate performSelector:@selector(txDataBytes:) withObject:data];
////    }
//    
//    if(_connection)
//    [_connection txData:data];
//}

//- (IBAction)onTriggerPunch:(id)sender {
//
//    Byte trigger[] = {0x90,120,64};     // punch trigger
//
////    [self rehearseMode];
////    [self setPunchEnable:true];  // enable the punch
//    [self txMidiAsString:[NSData dataWithBytes:trigger length:3]];    // tx data bytes to tcp (vm15 decodes messages that start with top bit set as MIDI)
//
//    // fingers crossed, sending MIDI to VM15 telnet port, will work if it does not append to another message (first char determines MIDI/text)
//}
//
//- (IBAction)onTriggerPunch1:(id)sender {
//
//    Byte trigger[] = {0x90,121,64};     // punch trigger
//
////    [self rehearseMode];
////    [self setPunchEnable:true];  // enable the punch
//    [self txMidiAsString:[NSData dataWithBytes:trigger length:3]];    // tx data bytes to tcp (vm15 decodes messages that start with top bit set as MIDI)
//
//    // fingers crossed, sending MIDI to VM15 telnet port, will work if it does not append to another message (first char determines MIDI/text)
//}
//
//- (IBAction)onTriggerPunch2:(id)sender {
//
//    Byte trigger[] = {0x90,122,64};     // punch trigger
//
////    [self rehearseMode];
////    [self setPunchEnable:true];  // enable the punch
//    [self txMidiAsString:[NSData dataWithBytes:trigger length:3]];    // tx data bytes to tcp (vm15 decodes messages that start with top bit set as MIDI)
//
//    // fingers crossed, sending MIDI to VM15 telnet port, will work if it does not append to another message (first char determines MIDI/text)
//}
//
//- (IBAction)onTriggerPunch3:(id)sender {
//
//    Byte trigger[] = {0x90,123,64};     // punch trigger
//
////    [self rehearseMode];
////    [self setPunchEnable:true];  // enable the punch
//    [self txMidiAsString:[NSData dataWithBytes:trigger length:3]];    // tx data bytes to tcp (vm15 decodes messages that start with top bit set as MIDI)
//
//    // fingers crossed, sending MIDI to VM15 telnet port, will work if it does not append to another message (first char determines MIDI/text)
//}
//-(void)setAnnunciatorByTag:(NSInteger)tag{
//    
//    [_draggableItemView setAnnunciatorByTag:tag];
//}

#pragma mark -
#pragma mark -------- setter/getter for fade radio button binding ---------

-(void)setFadeSeconds:(double)fadeSeconds{
    _fadeSeconds = fadeSeconds;
    [[NSUserDefaults standardUserDefaults] setDouble:fadeSeconds forKey:@"fadeSeconds"];
}
-(double)fadeSeconds{
    return [[NSUserDefaults standardUserDefaults]doubleForKey:@"fadeSeconds"];
}

//-(NSColor*)getAnnunciatorColor:(NSUInteger)index{
//    
//    // legal indices are 1,2,3 (rehearse, record, playback)
////    return [_draggableItemView getColorForTag:index];
//    
//    switch (index) {
//        case 2: return _recordColor;
//
//        case 3: return _playbackColor;
//            
//        default: return _rehearseColor;
//    }
//}

//-(void)setTakeTag:(NSInteger)takeTag{
//    _takeTag = takeTag;
//
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//    Document *doc = [delegate topDocument];
//
////    if(delegate.isAleMini){
////
////        [self txMsg:@"V2"];
////        return;
////
////    }
//
//    if(doc && delegate.recordCycleDictionary) [doc sendTakeToStreamerForDictionary:delegate.recordCycleDictionary];
//
//    else{
//        switch (_takeTag) {
//            case 1:
//
//                [self txMsg:@"V2 Take xx\n"];
//                break;
//            default:
//                [self txMsg:@"V2\n"];
//                break;
//        }
//
//    }
//
//}
//-(NSInteger)takeTag{
//    return _takeTag;
//}

//- (IBAction)onButtonShowProtoolsCounter:(id)sender {
//    
////    [self txMsg:@"ptc 0\n"];    // inhibit pt counter (we use it for take display)
//    [self txMsg:@"V2 Take xx\n"];
//}
//
//- (IBAction)onButtonHideProtoolsCounter:(id)sender {
//    
////    [self txMsg:@"ptc 0\n"];    // disable display of counter
//    [self txMsg:@"V2\n"];
//
//}

- (IBAction)onProtoolsPointComboBox:(id)sender {
    
//    NSComboBox *combo = sender;
//    int i = [[combo objectValueOfSelectedItem] intValue];
//    VM15Window *vm15Window = [_draggableItemView selectWindow:2];   // protools is window 2
//    [vm15Window setPoint:i];
////    vm15Window.point = i;
//
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//    Document *doc = [delegate topDocument];
//
//    if(delegate.isAleMini){
//        [self txMsg:@"V2"];
//        return;
//    }
//
//    if(doc) [doc sendTakeToStreamerForDictionary:delegate.recordCycleDictionary];
//
//    else if(_takeTag == 1){
//
//        [self txMsg:[vm15Window toString]];
//        [self txMsg:@"V2 Take xx"];
//
//    }
    
}

//- (IBAction)onLtcDisplayComboBox:(id)sender {
//
//    // V1.00.05 window 3 is protools counter only
//    // 'ptc' command is protools counter enable
//    [self txMsg:[[self ltcDisplayComboBox] indexOfSelectedItem] ? @"ptc 1\n" : @"ptc 0\n"];
//
//
////    NSString *msg = [NSString stringWithFormat:@"m %d\n",(int)[[self ltcDisplayComboBox] indexOfSelectedItem]];
////    [self txMsg:msg];
//}
//
//- (IBAction)onLtcPointComboBox:(id)sender {
//
////    NSComboBox *combo = sender;
////    int i = [[combo objectValueOfSelectedItem] intValue];
////    VM15Window *vm15Window = [_draggableItemView selectWindow:3];   // ltc is window 3
//////    vm15Window.point = i;
////    [vm15Window setPoint:i];
////
////    [self txMsg:[vm15Window toString]];
////    [self txMsg:@"V3 01:00:00:00" ];
//}

//- (IBAction)onPunchColorCombo:(id)sender {
//}
//-(void)setDialogTag:(NSInteger)dialogTag{
//    _dialogTag = dialogTag;
//    
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//    Document *doc = [delegate topDocument];
//    
//    if(doc && delegate.recordCycleDictionary)[doc sendDialogToStreamerForDictionary:delegate.recordCycleDictionary];
//    else{
//        switch (dialogTag) {
//            case 1:
//                delegate.overlayWindowController.viewController.textView.text = @"Sample dialog";   // 2.00.00
//                //[self txMsg:@"V Sample dialog"];
//                break;
//                
//            default:
//                delegate.overlayWindowController.viewController.textView.text = @"";   // 2.00.00
//                //[self txMsg:@"V"];
//                break;
//        }
//    }
//}
//-(NSInteger)dialogTag{
//    return _dialogTag;
//}

//- (IBAction)onButtonShowTextSample:(id)sender {
//    
//    [self txMsg:@"V sample dialog\n"];
//}
//
//- (IBAction)onButtonClearTextSample:(id)sender {
//    [self txMsg:@"V \n"];
//}

//- (IBAction)onTextPointComboBox:(id)sender {
//
////    NSComboBox *combo = sender;
////    int i = [[combo objectValueOfSelectedItem] intValue];
////    VM15Window *vm15Window = [_draggableItemView selectWindow:0];   // text is window 0
//////    vm15Window.point = i;
////    [vm15Window setPoint:i];
////    [self txMsg:[vm15Window toString]];
////
////    [self setDialogTag:_dialogTag]; // print the message
//}
//- (IBAction)onColorBars:(id)sender {
//
//    NSString *msg = [sender state] == NSControlStateValueOn ? @"G 1\n" : @"G 0\n";
//
//    [self txMsg:msg];
//
//}
-(void)rehearseMode{
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    MatrixWindowController *mwc = delegate.matrixWindowController;
    
    mwc.aheadInPast = MODE_CONTROL_REHEARSE;
//    [mwc setModeControl:MODE_CONTROL_REHEARSE]; // rehearse
}
//- (IBAction)onSdiTestSignalComboBox:(id)sender {
//
//    int i = (int)[_sdiTestSignalComboBox indexOfSelectedItem];
//
//    NSString *msg = [NSString stringWithFormat:@"M %d\n",i];
//    [self txMsg:msg];
//
//}

- (IBAction)onStreamer0:(id)sender {
    
//    Byte trigger[] = {0x90,124,64}; // 12 is annunciator color
    
//    [self rehearseMode];
//    [self setstreamerEnable:true];  // enable the streamer
//    trigger[2] = (unsigned char)[_streamerView streamerImage].colorStreamer0 + 1;
//    [self txMidiAsString:[NSData dataWithBytes:trigger length:3]];
//    [_streamerClient midiTx:[NSData dataWithBytes:trigger length:3]];   // 1.00.12
    [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:self.streamerColor];
}

//- (IBAction)onStreamer1:(id)sender {
//    Byte trigger[] = {0x90,125,64};
//
////    [self rehearseMode];
////    [self setstreamerEnable:true];  // enable the streamer
//    trigger[2] = (unsigned char)[_streamerView streamerImage].colorStreamer1 + 1;
//    [self txMidiAsString:[NSData dataWithBytes:trigger length:3]];
//    [_streamerClient midiTx:[NSData dataWithBytes:trigger length:3]];   // 1.00.12
//}
//
//- (IBAction)onStreamer2:(id)sender {
//    Byte trigger[] = {0x90,126,64};
//
////    [self rehearseMode];
////    [self setstreamerEnable:true];  // enable the streamer
//    trigger[2] = (unsigned char)[_streamerView streamerImage].colorStreamer2 + 1;
//    [self txMidiAsString:[NSData dataWithBytes:trigger length:3]];
//    [_streamerClient midiTx:[NSData dataWithBytes:trigger length:3]];   // 1.00.12
//}
//
//- (IBAction)onStreamer3:(id)sender {
//    Byte trigger[] = {0x90,127,64};
//
////    [self rehearseMode];
////    [self setstreamerEnable:true];  // enable the streamer
//    trigger[2] = (unsigned char)[_streamerView streamerImage].colorStreamer3 + 1;
//    [self txMidiAsString:[NSData dataWithBytes:trigger length:3]];
//    [_streamerClient midiTx:[NSData dataWithBytes:trigger length:3]];   // 1.00.12
//}
#pragma mark -
#pragma mark ------------------- debug tab items ----------------------------
//- (IBAction)onTxTextField:(id)sender {
//
//    NSString *msg = [sender stringValue];
//
//    if([msg rangeOfString:@"\n"].location == NSNotFound)
//        msg = [msg stringByAppendingString:@"\n"];
//
////    if(_connection)
//        [self txMsg:msg];
//}
//- (IBAction)onClearRxTextView:(id)sender {
//
//    [_rxTextView selectAll:sender];
//    [_rxTextView delete:sender];
//
//}
#pragma mark -
#pragma mark ------------------ tcp client delegate methods -------------------------

//-(void)getInitialValues{
//
//    // get initial values
//    [self txMsg:@"A\n"];   // pulldown
//    [self txMsg:@"B\n"];   // build date
//    [self txMsg:@"C\n"];   // streamer
//    [self txMsg:@"D\n"];   // fader 4.02.00
//    [self txMsg:@"E\n"];   // punch
//    //    [self txMsg:@"F\n"];   // punch flags, also carried in 'E' but we wanted a separate command for the flags (fader, black/cue/black logic)
//    [self txMsg:@"G\n"];   // bars/gray scale check boxes
//    [self txMsg:@"H\n"];   // masking
//    [self txMsg:@"I\n"];   // ltc compare control (set to use MIDI motion status and streamer end trigger for black/cue/black)
//    [self txMsg:@"J\n"];   // progress bar duration in seconds (form like 2.000)
//    [self txMsg:@"M\n"];   // V4.01.50 was "M 15" generator off
//    [self txMsg:@"Q\n"];   // get bypass
//    [self txMsg:@"U 0\n"];   // annuciator OFF
//    [self txMsg:@"U1\n"];   // annuciator 24 bit colors
//    [self txMsg:@"V1\n"];  // annuciator no text
//    [self txMsg:@"X\n"];   // pop enables
//    [self txMsg:@"Y\n"];   // color space
//    [self txMsg:@"k\n"];   // // version 3.22 and greater, get state start address, size, micro version, firmware version
//    [self txMsg:@"m\n"];   // tc window, v3.27 or greater
//    [self txMsg:@"n\n"];   // version 3.29 and greater, get COM item (MIDI or Sony)
//    [self txMsg:@"z\n"];   // v4.xx get fonts, before window readbacks so font combo has the values
//    [self txMsg:@"r 0\n"];   // window 0 values
//    [self txMsg:@"r 1\n"];   // window 1 values
//    [self txMsg:@"r 2\n"];   // window 2 values
//    [self txMsg:@"r 3\n"];   // window 3 values, v4.00
//    [self txMsg:@"t\n"];   // version 3.33.3,
//    [self txMsg:@"v\n"];   // version 4.00.3, progress bar
//    [self txMsg:@"c\n"];   // version 4.00.4, rate converter
//    [self txMsg:@"d\n"];   // version 4.03.32, streamer trigger delay from Edicue Play Status
//    [self txMsg:@"version\n"];   // we need version >= 4.03.38 for this version of AleDoc
//    [self txMsg:@"win 0\n"];   // micro 4.03.51, turn off window inhibits that were added for Mako
//
//    // get initial values from text server
//
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//
//    [delegate sendMsgToTextServer:@"H"];    // get mask values maybe
//
//    //    [self txMsg:@"ptc 0\n"];   // inhibit protools counter (we are using V2 for Take xx)
//
//}
//- (void)connectionWillResolveAddress:(TcpClientConnection *)sender{
//
//    // MADI does not always start, keep calling startTcpClient() every 30 seconds until we do
//    if(_tcpRestartTimer && _tcpRestartTimer.isValid){
//        NSLog(@"streamer client will resolve, stopping the restart timer...");
//        [_tcpRestartTimer invalidate];
//    }
//}
//-(void)setDefaultServer:(NSString*)server{
//
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    [defaults setObject:server forKey:SERVER_KEY];
//
//    for(TcpClientConnection *connection in _tcpClient.connections){
//
//        if([server isEqualToString:connection.netService.name]){
//
//            if(_connection && _connection != connection){
//
//                [_connection closeStreams];
//            }
//
//            [self setConnection:connection];
//            [self getInitialValues];
//
//        }
//    }
//
//}
//
//- (void)connectionDidResolveAddress:(TcpClientConnection *)sender{
//
//    if(!_server || _server.length == 0){
//
//        // if we do not have a server assigned take the first one we find
//        // this is for installations with one streamer, why make them
//        // use the dropdown (that is for WB type installations)
//        [self setDefaultServer:sender.netService.name];
//
//    }else if( _server && [_server isEqualToString:sender.netService.name]){
//
//        [self setConnection:sender];
//        [self getInitialValues];
//    }
//
//}
//-(void)processMsgArray:(NSMutableArray *)msgArray :(id)connection{
//    
////    [_streamerAnnunciator setState:NSControlStateValueOn];
////    _lastRx = [NSDate dateWithTimeIntervalSinceNow:10]; // 10 second timeout
//    
//    for(NSString *msg in msgArray){
//        
//        [self rxMsg:msg sender:connection];
//    }
//    
//}

//-(void)rxMsg:(NSString *)msg/* sender:(TcpClientConnection *)sender*/{
//
//    if(msg == nil || msg.length == 0) return;
//
//    AleDelegate *aleDelegate = (AleDelegate *)[NSApp delegate];
//    MatrixWindowController *mwc = [aleDelegate matrixWindowController];
//    Document *doc = [aleDelegate topDocument];
////    if( _server && [_server isEqualToString:sender.netService.name]) [mwc setStreamerState:true];
//
//    if([msg rangeOfString:@"ping"].location != NSNotFound) return;
//
//    // remove prompt if any
//    NSCharacterSet *trimSet = [NSCharacterSet characterSetWithCharactersInString:@">\r\n"];
//    msg = [msg stringByTrimmingCharactersInSet:trimSet];
//
//    // show the rx'd string in textViewDebugRx
//
//    if([msg rangeOfString:@"ping"].location == NSNotFound
//       && [msg rangeOfString:@"midi"].location == NSNotFound
//       && msg.length){
//
//        NSTextStorage * sto = [_rxTextView textStorage];
//        NSAttributedString *ats = [[NSAttributedString alloc] initWithString:[msg stringByAppendingString:@"\n"]];
//        [sto appendAttributedString:ats];
//        // scroll to end of document
//        [_rxTextView scrollToEndOfDocument:nil];
//    }
////    if([msg rangeOfString:@"ping"].location != NSNotFound) {
//////        ping_downctr = 2;
////
////        return;
////    }
//
//    NSArray *items = [msg componentsSeparatedByString:@" "];
//
//    NSObject *currentObjectForKey = [_vm15State objectForKey:[items objectAtIndex:0]];
//    [_vm15State setObject:items forKey:[items objectAtIndex:0]]; // current state ('r' has a fudge, look at case 'r' )
//
//    //    VM15Window *vm15Window;
//    int windowIndex;
//    int operand;
//    unsigned int result;
////    VM15Window *vm15Window;
//    double d;
//
//    NSScanner *scan;
//    NSString *txMsg = @"";
//
//    if(items.count > 0){
//
//        _skipTx = true; // avoid an infinite loop
//
//        NSString *cmd = [items firstObject];
//        if(cmd.length == 1){
//
//            // commands of 1 character, we can use a case statement
//
//            switch ([cmd characterAtIndex:0]) {
////                case 'A':   // pulldown
////                    [self willChangeValueForKey:@"frameRateTag"];
////                    [self willChangeValueForKey:@"inputPriorityTag"];
////                    [self willChangeValueForKey:@"endPunch"];
////                   [_streamerView frameRateFromString:msg];
////                    [self didChangeValueForKey:@"frameRateTag"];
////                    [self didChangeValueForKey:@"inputPriorityTag"];
////                    [self didChangeValueForKey:@"endPunch"];
////                   break;
////                case 'B':   // build date
////                    break;
////                case 'C':   // streamer
////                    [self willChangeValueForKey:@"colorStreamer0"];
////                    [self willChangeValueForKey:@"colorStreamer1"];
////                    [self willChangeValueForKey:@"colorStreamer2"];
////                    [self willChangeValueForKey:@"colorStreamer3"];
////                    [self willChangeValueForKey:@"colorEndBar"];
////                    [self willChangeValueForKey:@"width"];
////                    [self willChangeValueForKey:@"top"];
////                    [self willChangeValueForKey:@"bottom"];
////                    [self willChangeValueForKey:@"transparency"];
////                    [self willChangeValueForKey:@"colorMsb"];
////                    [self willChangeValueForKey:@"duration"];
////
////                    [[_streamerView streamerImage] fromString:msg];
////
////                    [self didChangeValueForKey:@"colorStreamer0"];
////                    [self didChangeValueForKey:@"colorStreamer1"];
////                    [self didChangeValueForKey:@"colorStreamer2"];
////                    [self didChangeValueForKey:@"colorStreamer3"];
////                    [self didChangeValueForKey:@"colorEndBar"];
////                    [self didChangeValueForKey:@"width"];
////                    [self didChangeValueForKey:@"top"];
////                    [self didChangeValueForKey:@"bottom"];
////                    [self didChangeValueForKey:@"transparency"];
////                    [self didChangeValueForKey:@"colorMsb"];
////                    [self didChangeValueForKey:@"duration"];
////
////                    break;
////                case 'D':   // fader
////
////                    @try {
//////                        [_pictureFadeFramesComboBox selectItemAtIndex:[[items objectAtIndex:1] intValue]];
//////                        [_fadeFramesComboBox selectItemAtIndex:[[items objectAtIndex:2] intValue]];
//////                        [_holdFramesTextField setStringValue:[items objectAtIndex:3]];
////
////                    }
////                    @catch (NSException *exception) {
////                        // set to defaults, got bad index probably
////                        // D 7 4 30
////                        if(currentObjectForKey == nil) [self txMsg:@"D 7 4 30\n"];
//////                        alreadyTriedOnce = true;    // don't get trapped in an infinite loop
////
////                    }
////
////                    break;
//                case 'E':   // punch
//
////                    [self willChangeValueForKey:@"colorIndex0"];
////                    [self willChangeValueForKey:@"colorIndex1"];
////                    [self willChangeValueForKey:@"colorIndex2"];
////                    [self willChangeValueForKey:@"colorIndex3"];
////                    [self willChangeValueForKey:@"x"];
////                    [self willChangeValueForKey:@"y"];
////                    [self willChangeValueForKey:@"diameter"];
////                    [self willChangeValueForKey:@"durationFrames"];
////                    [self willChangeValueForKey:@"repeatSeconds"];
////                    [self willChangeValueForKey:@"repeatCount"];
////                    [self willChangeValueForKey:@"punchEnable"];
////                    [self willChangeValueForKey:@"beepsEnable"];
////                    [self willChangeValueForKey:@"blackCueBlack"];
////                    [self willChangeValueForKey:@"pictureWhenStopped"];
////                    [self willChangeValueForKey:@"streamerTriggersBeeps"];
////                    [self willChangeValueForKey:@"rgbFadeEnable"];
////                    [self willChangeValueForKey:@"pictureTag"];
////                    [self willChangeValueForKey:@"reverseVideo"];
////                    [self willChangeValueForKey:@"streamerEnable"];
////
//////                    [[_draggableItemView punchImage] fromString:msg];
////
////                    [self didChangeValueForKey:@"colorIndex0"];
////                    [self didChangeValueForKey:@"colorIndex1"];
////                    [self didChangeValueForKey:@"colorIndex2"];
////                    [self didChangeValueForKey:@"colorIndex3"];
////                    [self didChangeValueForKey:@"x"];
////                    [self didChangeValueForKey:@"y"];
////                    [self didChangeValueForKey:@"diameter"];
////                    [self didChangeValueForKey:@"durationFrames"];
////                    [self didChangeValueForKey:@"repeatSeconds"];
////                    [self didChangeValueForKey:@"repeatCount"];
////                    [self didChangeValueForKey:@"punchEnable"];
////                    [self didChangeValueForKey:@"beepsEnable"];
////                    [self didChangeValueForKey:@"blackCueBlack"];
////                    [self didChangeValueForKey:@"pictureWhenStopped"];
////                    [self didChangeValueForKey:@"streamerTriggersBeeps"];
////                    [self didChangeValueForKey:@"rgbFadeEnable"];
////                    [self didChangeValueForKey:@"pictureTag"];
////                    [self didChangeValueForKey:@"reverseVideo"];
////                    [self didChangeValueForKey:@"streamerEnable"];
//
//                    if(doc){
//                        [doc enablesFromStreamer];
//
////                        [doc willChangeValueForKey:@"punchEnable"];
////                        [doc willChangeValueForKey:@"beepsEnable"];
////                        [doc willChangeValueForKey:@"streamerEnable"];
////
////                        [self didChangeValueForKey:@"punchEnable"];
////                        [self didChangeValueForKey:@"beepsEnable"];
////                        [self didChangeValueForKey:@"streamerEnable"];
//                    }
//
//                    // refresh the punch/beep enables for the top document
////                    [self enablesFromStreamer];
//
//
//                    break;
//                    //                case 'F':   // punch flags (for fader, black/cue/black)
//                    //                    [self fadeTag]; // decodes fade tag from punchFlags
//                    //                    [self setFadeTag:_fadeTag]; // triggers the binding
//                    //                   break;
//                case 'G':   // bars/gray scale check boxes
////                    @try {
////
////                        operand = [[items objectAtIndex:1]intValue];
////
////                        [[self colorBarCheckBox] setState:operand & 1 ? NSControlStateValueOn : NSControlStateValueOff ];
////                    }
////                    @catch (NSException *exception) {
////
////                    }
//
//                    break;
////                case 'H':   // masking
////
////                    // if the textWindowServer is online, reject messages from the streamer
//////                    if([aleDelegate senderIsBlocked:sender])
//////                        return;
////
////                    [self willChangeValueForKey:@"topMask"];
////                    [self willChangeValueForKey:@"bottomMask"];
////                    [self willChangeValueForKey:@"leftMask"];
////                    [self willChangeValueForKey:@"rightMask"];
////                    [self willChangeValueForKey:@"transparencyMask"];
////
////                    [[_streamerView streamerImage] maskingFromString:msg];
////
////                    [self didChangeValueForKey:@"topMask"];
////                    [self didChangeValueForKey:@"bottomMask"];
////                    [self didChangeValueForKey:@"leftMask"];
////                    [self didChangeValueForKey:@"rightMask"];
////                    [self didChangeValueForKey:@"transparencyMask"];
////                    break;
//                case 'I':   // ltc compare control, set low 2 bits to 2'd2 (midi motion status and streamer end trigger control black/cue/black)
//
//
//                    @try {
//                        scan = [NSScanner scannerWithString:[items objectAtIndex:1]];
//                        [scan scanHexInt:&result];
//
//                        if((result & 3) != 2){
//
//                            result &= 0xfc;
//                            result += 2;
//
//                            txMsg = [NSString stringWithFormat:@"I %x\n",result];
//                            [self txMsg:txMsg];
//
//                        }
//                    }
//                    @catch (NSException *exception) {
//
//                    }
//
//
//                    break;
//                case 'J':   // trim
//                    break;
//
//                case 'M':   // V4.01.50 was "M 15" generator off
//
////                    @try {
////
////                        operand = [[items objectAtIndex:1]intValue];
////                        [_sdiTestSignalComboBox selectItemAtIndex:operand];
////
////                    }
////                    @catch (NSException *exception) {
////
////                    }
//
//                    break;
//                case 'Q':   // get bypass
//                    break;
//                case 'U':   // annunciator
//
//// inhStreamerInPB is done locally, leave the bit at the streamer cleared (cleared by rx uf U1 command)
////                    if(items.count > 1){
////
////                        [self willChangeValueForKey:@"inhStreamerInPB"];
////                        _inhStreamerInPB =[[items objectAtIndex:2]intValue];
////                        [self didChangeValueForKey:@"inhStreamerInPB"];
////
////                    }
//
//                    result = items.count ? [[items objectAtIndex:1]intValue] : 0;
//
//                    if(mwc) [mwc setRehRecPb:result];
//
////                    switch (result) {
////                        case 2:
////                            [_draggableItemView setAnnunciatorColorAndText:_recordColor :@"Record"];
////                           break;
////                        case 3:
////                            [_draggableItemView setAnnunciatorColorAndText:_playbackColor :@"Playback"];
////                            break;
////
////                        default:
////                            [_draggableItemView setAnnunciatorColorAndText:_rehearseColor :@"Rehearse"];
////                            break;
////                    }
////                    [_draggableItemView setAnnunciatorByTag:result];
//
//                    break;
//                case 'X':   // pop enables
//
////                    [self willChangeValueForKey:@"popTag"];
////                    [self willChangeValueForKey:@"popStreamerAccum"];
////                    [self willChangeValueForKey:@"popStreamer"];
////                    [self willChangeValueForKey:@"popPunch"];
//
////                    [_streamerView popEnablesFromString:msg];
//
//
////                    [self didChangeValueForKey:@"popTag"];
////                    [self didChangeValueForKey:@"popStreamerAccum"];
////                    [self didChangeValueForKey:@"popStreamer"];
////                    [self didChangeValueForKey:@"popPunch"];
//
//                    break;
//                case 'Y':   // color space
//                    break;
//                case 'k':   // // version 3.22 and greater, get state start address, size, micro version, firmware version
//                    break;
//                case 'm':   // tc window, v3.27 or greater
//
//                    @try {
//
//                        operand = [[items objectAtIndex:1]intValue];
//                        [[self ltcDisplayComboBox] selectItemAtIndex:operand];
//
//                    }
//                    @catch (NSException *exception) {
//
//                    }
//
//                    break;
//                case 'n':   // version 3.29 and greater, get COM item (MIDI or Sony)
//                    break;
//                case 'z':   // v4.xx get fonts, before window readbacks so font combo has the values
//
////                    [[self textPointComboBox] removeAllItems];
////                    [[self annunciatorPointComboBox] removeAllItems];
////                    [[self protoolsPointComboBox] removeAllItems];
////                    [[self ltcPointComboBox] removeAllItems];
//
////                    for(int i = 1; i < items.count; i++){
////                        [[self textPointComboBox] addItemWithObjectValue:[items objectAtIndex:i]];
////                        [[self annunciatorPointComboBox] addItemWithObjectValue:[items objectAtIndex:i]];
////                        [[self protoolsPointComboBox] addItemWithObjectValue:[items objectAtIndex:i]];
////                        [[self ltcPointComboBox] addItemWithObjectValue:[items objectAtIndex:i]];
////                    }
//
//                    //                    [self selAnnunciatorCombo];
//
//                    break;
////                case 'r':   // window n values
////
////                    if(items.count != 6) break; // wrong number of items
////
////                    cmd = [cmd stringByAppendingString:[items objectAtIndex:5]];
////                    [_vm15State setObject:items forKey:cmd]; // r0,r1,r2,r3 (need to keep state of each window)
////
////                    windowIndex = [[items objectAtIndex:5] intValue];
////                    if(windowIndex >= 4) break;
////
//////                    vm15Window = [_draggableItemView.vm15WindowArray objectAtIndex:windowIndex];
////////                    [vm15Window.delegate needsDisplayInRect:vm15Window.calculatedItemBounds];  // old rect
//////
//////                    [vm15Window fromString:msg];
////
////                    switch (windowIndex) {
////
////                        case 0:
////
////                            [[self textPointComboBox] setIntValue:(int)vm15Window.point];
//////                            [[self textPointComboBox] setNeedsDisplay];
////                            [self textPointComboBox].needsDisplay = YES;
////
////                            [self willChangeValueForKey:@"colorDialogBackground"];
////                            [self willChangeValueForKey:@"colorDialogForeground"];
////                            [self didChangeValueForKey:@"colorDialogBackground"];
////                            [self didChangeValueForKey:@"colorDialogForeground"];
////
////                            break;
////
////                        case 1:
////
//////                            [[self annunciatorPointComboBox] setIntValue:(int)vm15Window.point];
////////                            [[self annunciatorPointComboBox] setNeedsDisplay];
//////                            [self annunciatorPointComboBox].needsDisplay = YES;
////
////                            break;
////
////                        case 2:
////
////                            [[self protoolsPointComboBox] setIntValue:(int)vm15Window.point];
////                            //[[self protoolsPointComboBox] setNeedsDisplay];
////                            [self protoolsPointComboBox].needsDisplay = YES;
////
////                            [self willChangeValueForKey:@"colorTakeBackground"];
////                            [self willChangeValueForKey:@"colorTakeForeground"];
////                            [self didChangeValueForKey:@"colorTakeBackground"];
////                            [self didChangeValueForKey:@"colorTakeForeground"];
////
////                            break;
////
////                        case 3:
////
////                            [[self ltcPointComboBox] setIntValue:(int)vm15Window.point];
////                            //[[self ltcPointComboBox] setNeedsDisplay];
////                            [self ltcPointComboBox].needsDisplay = YES;
////
////                            [self willChangeValueForKey:@"colorLtcBackground"];
////                            [self willChangeValueForKey:@"colorLtcBackground"];
////                            [self didChangeValueForKey:@"colorLtcBackground"];
////                            [self didChangeValueForKey:@"colorLtcBackground"];
////
////                            break;
////
////                        default:
////                            break;
////                    }
////
//////                    [vm15Window drawTextImage];
//////                    [vm15Window.delegate needsDisplayInRect:vm15Window.calculatedItemBounds];  // new rect
////
////
////                    break;
//                case 't':   // annunciator colors, primary palette, not used
//
//                    break;
////                case 'v':   // version 4.00.3, progress bar
////
////                    [self willChangeValueForKey:@"progressX"];
////                    [self willChangeValueForKey:@"progressY"];
////                    [self willChangeValueForKey:@"progressWidth"];
////                    [self willChangeValueForKey:@"progressHeight"];
////                    [self willChangeValueForKey:@"colorProgressForeground"];
////                    [self willChangeValueForKey:@"colorProgressBackground"];
////                    [self willChangeValueForKey:@"progressBarEnable"];
////
////                    [[_streamerView streamerImage]progressBarFromString:msg];
////
////                    [self didChangeValueForKey:@"progressX"];
////                    [self didChangeValueForKey:@"progressY"];
////                    [self didChangeValueForKey:@"progressWidth"];
////                    [self didChangeValueForKey:@"progressHeight"];
////                    [self didChangeValueForKey:@"colorProgressForeground"];
////                    [self didChangeValueForKey:@"colorProgressBackground"];
////                    [self didChangeValueForKey:@"progressBarEnable"];
////
////                    if(doc){
////
////                        [doc enablesFromStreamer];
////
//////                        [doc willChangeValueForKey:@"progressBarEnable"];
//////                        [doc didChangeValueForKey:@"progressBarEnable"];
////                    }
////
////                    break;
//                case 'c':   // version 4.00.4, rate converter
////                    [self willChangeValueForKey:@"frameRateConverter"];
////                    [_streamerView frameRateConverterFromString:msg];
////                    [self didChangeValueForKey:@"frameRateConverter"];
//                    break;
//
////                    case 'd':
////
////                    if(items.count < 2) break;
////
////                    d = (double)[[items objectAtIndex:1]intValue];    // play to streamer delay in 10 ms increments
////                    d /= 100;
////                    [self setPlayToStreamerSeconds:d];
////
////                    if(items.count < 3) break;
////
////                    d = (double)[[items objectAtIndex:2]intValue];    // streamer to mute delay in 10 ms increments
////                    d /= 100;
////                    [self setStreamerToMuteSeconds:d];
////
////                    if(items.count < 4) break;
////
////                    d = (double)[[items objectAtIndex:3]intValue];    // streamer to mute delay in 10 ms increments
////                    d /= 100;
////                    [self setMuteToRecordSeconds:d];
////
////                    break;
//
//                default:
//                    break;
//            }
//
//        }else{
//            // commands of more than 1 character, can't use case statement
//
//            if([cmd rangeOfString:@"U1"].location == 0 && items.count >= 10){
//
//                // annunciator colors, set the color wells
//                // rgb for rehearse, record, playback
//
////                for(int i = 0; i < items.count; i++){
////
////                    NSLog(@"%d",[[items objectAtIndex:i] intValue]);
////                }
//
//                 _rehearseColor = colorFromRgb([[items objectAtIndex:1]intValue],[[items objectAtIndex:2]intValue],[[items objectAtIndex:3]intValue]);
//                _recordColor = colorFromRgb([[items objectAtIndex:4]intValue],[[items objectAtIndex:5]intValue],[[items objectAtIndex:6]intValue]);
//                _playbackColor = colorFromRgb([[items objectAtIndex:7]intValue],[[items objectAtIndex:8]intValue],[[items objectAtIndex:9]intValue]);
//
//                [_rehearseColorWell setColor:_rehearseColor];
//                [_recordColorWell setColor:_recordColor];
//                [_playbackColorWell setColor:_playbackColor];
//            }
////            else if([cmd rangeOfString:@"version"].location == 0){
////
////                // 1 NE64:4.03.38
////                if([MIN_STREAMER_VERSION compare:items[1]] > 0){
////
////                    [NSApp activateIgnoringOtherApps:YES];  // brings our alert to the front
////                   NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:@"update streamer to %@ or greater",MIN_STREAMER_VERSION] defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
////
////                    [alert runModal];
////                }
////
////            }
//
//
//
//
//        }
//
//        _skipTx = false;
//
//    }
//}
//NSColor *colorFromRgb(int red, int green, int blue){
//
//    double r = ((double)red)/255;
//    double g = ((double)green)/255;
//    double b = ((double)blue)/255;
//
//    NSColor *color = [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0];
//
//    return color;
//}
#pragma mark -
#pragma mark ------------ send annunciator ---------------------
//-(void)sendAnnunciatorByTag:(NSInteger)tag{
//    
//    // streamer v4.03.38 has the 24 bit colors stored with the 'U1' message
//    
////    NSColor *color;
//    NSString *msg =  @"Missing state";
//    NSColor *color = NSColor.whiteColor;
//    NSColor *bgColor = NSColor.yellowColor;
//
//    switch (tag) {
//        case MODE_CONTROL_OFF:
//            msg = @"";
//            color = NSColor.clearColor;
//            break;
//        case MODE_CONTROL_REHEARSE:
//            msg =  @"Rehearse";
//            color = _rehearseColor;
//            bgColor = _rehearseBgColor;
//            break;
//        case MODE_CONTROL_RECORD:
//            msg = @"Record";
//            color = _recordColor;
//            bgColor = _recordBgColor;
//            break;
//        case MODE_CONTROL_PLAYBACK:
//            msg = @"Playback";
//            color = _playbackColor;
//            bgColor = _playbackBgColor;
//            break;
//        case MODE_CONTROL_REHEARSE_PENDING:
//            msg =  @"Rehearse pending";
//            color = _rehearseColor;
//            bgColor = _rehearseBgColor;
//            break;
//        case MODE_CONTROL_RECORD_PENDING:
//            msg =  @"Record pending";
//            color = _recordColor;
//            bgColor = _recordBgColor;
//            break;
//        case MODE_CONTROL_PLAYBACK_PENDING:
//            msg =  @"Playback pending ";
//            color = _playbackColor;
//            bgColor = _playbackBgColor;
//            break;
//        default:
//            break;
//    }
//    
//    if(color == nil){
//        return;         // TODO: 2.00.00 happens on initialization
//    }
//    
//    _aleDelegate.overlayWindowController.viewController.annunciatorTextView.fadeDuration = [NSUserDefaults.standardUserDefaults doubleForKey:@"fadeSeconds"];
//    _aleDelegate.overlayWindowController.viewController.annunciatorTextView.backgroundColor = bgColor;
//    _aleDelegate.overlayWindowController.viewController.annunciatorTextView.textColor = color;
//    _aleDelegate.overlayWindowController.viewController.annunciatorTextView.text = msg;
//    
////    NSLog(@"sendAnnunciatorByTag %@",msg);
//
//}
//-(void)sendAnnunciator24BitColors{
//    
//    if(_skipTx) return;
//    
//    NSColor *color;
//    
//    color = _rehearseColorWell.color;//_draggableItemView.rehearseColor;
//    
//    
//    color = [color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
//
//    int redReh = 255 * [color redComponent];
//    int greenReh = 255 * [color greenComponent];
//    int blueReh = 255 * [color blueComponent];
//    
//    color = _recordColorWell.color;//_draggableItemView.recordColor;
//    
//    color = [color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
//
//    int redRec = 255 * [color redComponent];
//    int greenRec = 255 * [color greenComponent];
//    int blueRec = 255 * [color blueComponent];
//    
//    color = _playbackColorWell.color;//_draggableItemView.playbackColor;
//    
//    color = [color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
//
//    int redPb = 255 * [color redComponent];
//    int greenPb = 255 * [color greenComponent];
//    int bluePb = 255 * [color blueComponent];
//    
//    NSString *msg = [NSString stringWithFormat:@"U1 %d %d %d %d %d %d %d %d %d",
//                     redReh,greenReh,blueReh,
//                     redRec,greenRec,blueRec,
//                     redPb,greenPb,bluePb
//                     ];
//    
//    [self txMsg:msg];
//    
//}
//-(void)sendAnnunciatorx:(NSInteger)tag{
//
//    NSColor *color;
//    NSString *msg;
//    
//    
//    switch (tag) {
//        case 0:
//            
//            color = [NSColor clearColor];
//            msg = @"V1\n";
////            NSLog(@"MSG 3");
//            
//            break;
//            
//        case MODE_CONTROL_REHEARSE:
//            
//            color = _draggableItemView.rehearseColor;
//            msg =  @"U1 100 255 100\nV1 Rehearse\n";
//
//            break;
//        case MODE_CONTROL_RECORD:
//            
//            color = _draggableItemView.recordColor;
//            msg = @"U1 255 50 50\nV1 Record\n";
//            
//            break;
//        case MODE_CONTROL_PLAYBACK:
//            
//            color = _draggableItemView.playbackColor;
//            msg = @"U1 50 100 255\nV1 Playback\n";
//            
//            break;
//            
//        default:
//            break;
//    }
//    
//    // sending text and U message one after the other does not work FIXME
//    // the work around is to send them at different times (colors go when rehearse/record/playback is selected)
//    // convert to rgb
//    color = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
//    
//    int red = 255 * [color redComponent];
//    int green = 255 * [color greenComponent];
//    int blue = 255 * [color blueComponent];
//    NSString *uMsg = [NSString stringWithFormat:@"U1 %d %d %d\n",red,green,blue];
//    [self txMsg:uMsg];  // sending r,g,b sets annunciator to 24 bit color
//    
//    [self txMsg:msg];
//// sending color right away does not work, why?
////    NSLog(@"sendAnnunciator, %@,%@",uMsg,msg);
//    
//    // show current reh/rec/pb in draggable item view
//    VM15Window *vm15Window = [_draggableItemView.vm15WindowArray objectAtIndex:1];
//    vm15Window.foreColor = color;
//    vm15Window.backColor = [NSColor clearColor];
//    [vm15Window setText:msg]; 
//    
//    // set XKey LEDs
//    AleDelegate *aleDelegate = (AleDelegate*)[NSApp delegate];
//    [aleDelegate setRehRecPbLEDs];
//    
//}
//-(void)txDelays{
//    
//    int i = (int)(100 * _playToStreamerSeconds);
//    int j = (int)(100 * _streamerToMuteSeconds);
//    int k = (int)(100 * _streamerToMuteSeconds);
//    
//    [self txMsg:[NSString stringWithFormat:@"d %d %d %d",i,j,k]];
//    
//}
#pragma mark -
#pragma mark ------------ setters/getters ---------------------

//-(void)setRehearseColor:(NSColor *)rehearseColor{
//    // let color = newValue!.usingColorSpace(.genericRGB)
//    _rehearseColor = [rehearseColor colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
//    [[NSUserDefaults standardUserDefaults]setColor:rehearseColor forKey:@"rehearseColor"];
//    
//    NSColor *color = [[NSUserDefaults standardUserDefaults]colorForKey:@"rehearseColor"];
//    
//    NSLog(@"r %1.3f %1.3f",color.redComponent,_rehearseColor.redComponent);
//    NSLog(@"g %1.3f %1.3f",color.greenComponent,_rehearseColor.greenComponent);
//    NSLog(@"b %1.3f %1.3f",color.blueComponent,_rehearseColor.blueComponent);
//    NSLog(@"a %1.3f %1.3f",color.alphaComponent,_rehearseColor.alphaComponent);
//    
//}
//-(NSColor *)rehearseColor{
//    
//    _rehearseColor = [[NSUserDefaults standardUserDefaults]colorForKey:@"rehearseColor"];
//    
//    NSLog(@"r %1.3f",_rehearseColor.redComponent);
//    NSLog(@"g %1.3f",_rehearseColor.greenComponent);
//    NSLog(@"b %1.3f",_rehearseColor.blueComponent);
//    NSLog(@"a %1.3f",_rehearseColor.alphaComponent);
//
//    return _rehearseColor;
//}
//-(void)setRecordColor:(NSColor *)recordColor{
//    
//    _recordColor = [recordColor colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
//    [[NSUserDefaults standardUserDefaults]setColor:recordColor forKey:@"recordColor"];
//
//}
//-(NSColor *)recordColor{
//    _recordColor = [[NSUserDefaults standardUserDefaults]colorForKey:@"recordColor"];
//    return _recordColor;
//}
//-(void)setPlaybackColor:(NSColor *)playbackColor{
//    
//    _playbackColor = [playbackColor colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
//    [[NSUserDefaults standardUserDefaults]setColor:playbackColor forKey:@"playbackColor"];
//
//}
//-(NSColor *)playbackColor{
//    _playbackColor =  [[NSUserDefaults standardUserDefaults]colorForKey:@"playbackColor"];
//    return _playbackColor;
//}
//-(void)setRehearseBgColor:(NSColor *)rehearseBgColor{
//    _rehearseBgColor = [rehearseBgColor colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
//    [[NSUserDefaults standardUserDefaults]setColor:rehearseBgColor forKey:@"rehearseBgColor"];
//}
//-(NSColor *)rehearseBgColor{
//    _rehearseBgColor = [[NSUserDefaults standardUserDefaults]colorForKey:@"rehearseBgColor"];
//    return _rehearseBgColor;
//}
//-(void)setRecordBgColor:(NSColor *)recordBgColor{
//    _recordBgColor = [recordBgColor colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
//    [[NSUserDefaults standardUserDefaults]setColor:recordBgColor forKey:@"recordBgColor"];
//}
//-(NSColor *)recordBgColor{
//    _recordBgColor = [[NSUserDefaults standardUserDefaults]colorForKey:@"recordBgColor"];
//    return _recordBgColor;
//}
//-(void)setPlaybackBgColor:(NSColor *)playbackBgColor{
//    _playbackBgColor = [playbackBgColor colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
//    [[NSUserDefaults standardUserDefaults]setColor:playbackBgColor forKey:@"playbackBgColor"];
//
//}
//-(NSColor *)playbackBgColor{
//    _playbackBgColor = [[NSUserDefaults standardUserDefaults]colorForKey:@"playbackBgColor"];
//    return _playbackBgColor;
//}
//-(void)setTextColor:(NSColor *)textColor{
//    _textColor = [textColor colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
//    [[NSUserDefaults standardUserDefaults]setColor:textColor forKey:@"textColor"];
//}
//-(NSColor *)textColor{
//    _textColor = [[NSUserDefaults standardUserDefaults]colorForKey:@"textColor"];
//    return _textColor;
//}
//-(void)setTextBgColor:(NSColor *)textBgColor{
//    _textBgColor = [textBgColor colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
//    [[NSUserDefaults standardUserDefaults]setColor:textBgColor forKey:@"textBgColor"];
//
//}
//-(NSColor *)textBgColor{
//    _textBgColor = [[NSUserDefaults standardUserDefaults]colorForKey:@"textBgColor"];
//    return _textBgColor;
//}
//-(void)setCueIdColor:(NSColor *)cueIdColor{
//    _cueIdColor = [cueIdColor colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
//    [[NSUserDefaults standardUserDefaults]setColor:cueIdColor forKey:@"cueIdColor"];
//
//}
//-(NSColor *)cueIdColor{
//    _cueIdColor = [[NSUserDefaults standardUserDefaults]colorForKey:@"cueIdColor"];
//    return _cueIdColor;
//}
//-(void)setCueIdBgColor:(NSColor *)cueIdBgColor{
//    _cueIdBgColor = [cueIdBgColor colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
//    [[NSUserDefaults standardUserDefaults]setColor:cueIdBgColor forKey:@"cueIdBgColor"];
//}
//-(NSColor *)cueIdBgColor{
//    return [[NSUserDefaults standardUserDefaults]colorForKey:@"cueIdBgColor"];
//}
-(void)setPunchColor:(NSColor *)punchColor{
    _punchColor = punchColor;
    [[NSUserDefaults standardUserDefaults]setColor:punchColor forKey:@"punchColor"];
}
-(NSColor*)punchColor{
    return [[NSUserDefaults standardUserDefaults]colorForKey:@"punchColor"];
}
-(void)setStreamerColor:(NSColor *)streamerColor{
    _streamerColor = streamerColor;
    [[NSUserDefaults standardUserDefaults]setColor:streamerColor forKey:@"streamerColor"];

}
-(NSColor*)streamerColor{
    return [[NSUserDefaults standardUserDefaults]colorForKey:@"streamerColor"];
}
-(void)setEndBarColor:(NSColor *)endBarColor{
    _endBarColor = endBarColor;
    [[NSUserDefaults standardUserDefaults]setColor:endBarColor forKey:@"endBarColor"];
}
-(NSColor*)endBarColor{
    return [[NSUserDefaults standardUserDefaults]colorForKey:@"endBarColor"];
}
-(void)setPunchListItem:(NSString*)punchListItem{
    
    _punchListItem = punchListItem;
    NSUInteger i = [_punchList indexOfObject:_punchListItem];
    NSLog(@"setPunchListItem %lu %@",(unsigned long)i,_punchListItem);
    _aleDelegate.overlayWindowController.viewController.streamer.punchIndex = i;

    
}
- (IBAction)punchListCombo:(id)sender {
}

-(NSString*)punchListItem{
    return _punchListItem;
}

//-(void)setMuteToRecordSeconds:(double)muteToRecordSeconds{
//
//    _muteToRecordSeconds = muteToRecordSeconds;
//    [self txDelays];
//
//}
//-(void)setPlayToStreamerSeconds:(double)playToStreamerSeconds{
//    _playToStreamerSeconds = playToStreamerSeconds;
//
//    [self txDelays];
//
//}
//-(double)playToStreamerSeconds{
//    return _playToStreamerSeconds;
//}
//-(void)setStreamerToMuteSeconds:(double)streamerToMuteSeconds{
//
//    _streamerToMuteSeconds = streamerToMuteSeconds;
//    [self txDelays];
//
//}
//-(double)muteToRecordSeconds{
//    return _muteToRecordSeconds;
//}
//-(double)streamerToMuteSeconds{
//    return _streamerToMuteSeconds;
//}
//-(void)setPasteBlackTimeout:(double)pasteBlackTimeout{
//    
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    [defaults setObject:[NSNumber numberWithDouble:pasteBlackTimeout] forKey:@"pasteBlackTimeout"];
//    
//}
//-(double)pasteBlackTimeout{
//    
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    return [defaults doubleForKey:@"pasteBlackTimeout"];
//    
//}

//-(void)setBlackHoldTime:(double)blackHoldTime{
//    
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    [defaults setObject:[NSNumber numberWithDouble:blackHoldTime] forKey:@"blackHoldTime"];
//    
//    
//}
//-(double)blackHoldTime{
//    
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    return [defaults doubleForKey:@"blackHoldTime"];
//}

-(void)setInhibitStreamerInPlayback:(bool)inhibitStreamerInPlayback{
    
 //   NSLog(@"setInhibitStreamerInPlayback");
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:inhibitStreamerInPlayback forKey:@"inhibitStreamerInPlayback"];
    
}
-(bool)inhibitStreamerInPlayback{
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"inhibitStreamerInPlayback"];
}

-(void)setPictureTag:(NSInteger)pictureTag{
    _pictureTag = pictureTag;
    [[NSUserDefaults standardUserDefaults]setInteger:pictureTag forKey:@"pictureTag"];
    [self onPictureMatrix:nil];

}
-(NSInteger)pictureTag{
    return [[NSUserDefaults standardUserDefaults]integerForKey:@"pictureTag"];
}
//
//- (IBAction)onSortByActor:(id)sender {
//}
//
//- (IBAction)onSortByCueID:(id)sender {
//}
//
//-(void)setReverseVideo:(bool)reverseVideo{
////    [_draggableItemView.punchImage setReverseVideo:reverseVideo];
//}
//-(bool)reverseVideo{
////    return _draggableItemView.punchImage.reverseVideo;
//    return false;
//}
//
//-(void)setColorIndex0:(NSInteger)colorIndex0{
////    [_draggableItemView.punchImage setColorIndex0:colorIndex0];
//}
//-(NSInteger)colorIndex0{
////    return _draggableItemView.punchImage.colorIndex0;
//    return 0;
//}
//-(void)setColorIndex1:(NSInteger)colorIndex1{
////    [_draggableItemView.punchImage setColorIndex1:colorIndex1];
//}
//-(NSInteger)colorIndex1{
////    return _draggableItemView.punchImage.colorIndex1;
//    return 0;
//}
//-(void)setColorIndex2:(NSInteger)colorIndex2{
////    [_draggableItemView.punchImage setColorIndex2:colorIndex2];
//}
//-(NSInteger)colorIndex2{
////    return _draggableItemView.punchImage.colorIndex2;
//    return 0;
//}
//-(void)setColorIndex3:(NSInteger)colorIndex3{
////    [_draggableItemView.punchImage setColorIndex3:colorIndex3];
//}
//-(NSInteger)colorIndex3{
////    return _draggableItemView.punchImage.colorIndex3;
//    return 0;
//}
//-(void)setX:(NSInteger)x{
//    [_draggableItemView.punchImage setX:x];
//}
//-(NSInteger)x{
//    return _draggableItemView.punchImage.x;
//}
//-(void)setY:(NSInteger)y{
//    [_draggableItemView.punchImage setY:y];
//}
//-(NSInteger)y{
//    return _draggableItemView.punchImage.y;
//}

-(void)setDiameter:(NSInteger)diameter{
//    [_draggableItemView.punchImage setDiameter:diameter];
}
-(NSInteger)diameter{
//    return _draggableItemView.punchImage.diameter;
    return 100;
}
//[self didChangeValueForKey:@"repeatSeconds"];
//[self didChangeValueForKey:@"repeatCount"];
//[self didChangeValueForKey:@"punchEnable"];
//[self didChangeValueForKey:@"beepsEnable"];
//[self didChangeValueForKey:@"durationFrames"];
//-(void)setStreamerTriggersBeeps:(bool)streamerTriggersBeeps{
//
////    [self.draggableItemView.punchImage setStreamerTriggersBeeps:streamerTriggersBeeps];
//
//}
//-(bool)streamerTriggersBeeps{
//
////    return [self.draggableItemView.punchImage streamerTriggersBeeps];
//    return false;
//}
-(void)setPunchEnable:(bool)punchEnable{
    [[NSUserDefaults standardUserDefaults]setBool:punchEnable forKey:@"enPunch"];
}
-(bool)punchEnable{
    
    return [[NSUserDefaults standardUserDefaults]boolForKey:@"enPunch"];
}
-(void)setBeepsEnable:(bool)beepsEnable{
    
    [[NSUserDefaults standardUserDefaults]setBool:beepsEnable forKey:@"enBeeps"];

}
-(bool)beepsEnable{
    
    return [[NSUserDefaults standardUserDefaults]boolForKey:@"enBeeps"];

}
-(void)setStreamerEnable:(bool)streamerEnable{
    [[NSUserDefaults standardUserDefaults]setBool:streamerEnable forKey:@"enStreamer"];
}
-(bool)streamerEnable{
//    return self.draggableItemView.punchImage.streamerEnable;
    return [[NSUserDefaults standardUserDefaults]boolForKey:@"enStreamer"];
}

////draggableItemView.punchImage.repeatSeconds
//-(void)setRepeatSeconds:(double)repeatSeconds{
////    [self.draggableItemView.punchImage setRepeatSeconds:repeatSeconds];
//}
//
//-(double)repeatSeconds{
//    
////    return self.draggableItemView.punchImage.repeatSeconds;
//    return 0.666;
//    
//}
//-(void)setBeepsRepeatCount:(NSInteger)repeatCount{
////    [_draggableItemView.punchImage setBeepsRepeatCount:repeatCount];
//}
//-(NSInteger)beepsRepeatCount{
////    return _draggableItemView.punchImage.beepsRepeatCount;
//    return 2;
//}
//-(void)setDurationFrames:(NSInteger)durationFrames{
////    [_draggableItemView.punchImage setDurationFrames:durationFrames];
//}
//-(NSInteger)durationFrames{
////    return _draggableItemView.punchImage.durationFrames;
//    return 1;
//}

//[self willChangeValueForKey:@"topMask"];
//[self willChangeValueForKey:@"bottomMask"];
//[self willChangeValueForKey:@"leftMask"];
//[self willChangeValueForKey:@"rightMask"];
//[self willChangeValueForKey:@"transparencyMask"];

-(void)setTopMask:(NSInteger)topMask{
    _aleDelegate.overlayWindowController.viewController.streamer.topMask = topMask;
    
}
-(NSInteger)topMask{
    return _aleDelegate.overlayWindowController.viewController.streamer.topMask;
}
-(void)setBottomMask:(NSInteger)bottomMask{
    
    _aleDelegate.overlayWindowController.viewController.streamer.bottomMask = bottomMask;
}
-(NSInteger)bottomMask{
    return _aleDelegate.overlayWindowController.viewController.streamer.bottomMask;
}
-(void)setRightMask:(NSInteger)rightMask{
    _aleDelegate.overlayWindowController.viewController.streamer.rightMask = rightMask;
}
-(NSInteger)rightMask{
    return _aleDelegate.overlayWindowController.viewController.streamer.rightMask;
}
-(void)setLeftMask:(NSInteger)leftMask{
    _aleDelegate.overlayWindowController.viewController.streamer.leftMask = leftMask;
}
-(NSInteger)leftMask{
    return _aleDelegate.overlayWindowController.viewController.streamer.leftMask;
}
-(void)setTransparencyMask:(NSInteger)transparencyMask{
    _aleDelegate.overlayWindowController.viewController.streamer.transparency = transparencyMask;
}
-(NSInteger)transparencyMask{
    return _aleDelegate.overlayWindowController.viewController.streamer.transparency;
}
//[self willChangeValueForKey:@"popTag"];
//[self willChangeValueForKey:@"popStreamerAccum"];
//[self willChangeValueForKey:@"popStreamer"];
//[self willChangeValueForKey:@"popPunch"];
//-(void)setPopPunch:(bool)popPunch{
//    [_streamerView setPopPunch:popPunch];
//}
//-(bool)popPunch{
//    return _streamerView.popPunch;
//}
//-(void)setPopTag:(NSInteger)popTag{
//    [_streamerView setPopTag:popTag];
//}
//-(NSInteger)popTag{
//    return _streamerView.popTag;
//}
//-(void)setPopStreamerAccum:(bool)popStreamerAccum{
//    [_streamerView setPopStreamerAccum:popStreamerAccum];
//}
//-(bool)popStreamerAccum{
//    return _streamerView.popStreamerAccum;
//}
//-(void)setPopStreamer:(bool)popStreamer{
//    [_streamerView setPopStreamer:popStreamer];
//}
//-(bool)popStreamer{
//    return _streamerView.popStreamer;
//}

//[self willChangeValueForKey:@"frameRateConverter"];
//-(void)setFrameRateConverter:(bool)frameRateConverter{
//    [_streamerView setFrameRateConverter:frameRateConverter];
//}
//-(bool)frameRateConverter{
//    return _streamerView.frameRateConverter;
//}

//[self willChangeValueForKey:@"frameRateTag"];
//[self willChangeValueForKey:@"inputPriorityTag"];
//[self willChangeValueForKey:@"endPunch"];
//-(void)setFrameRateTag:(NSInteger)frameRateTag{
//    [_streamerView setFrameRateTag:frameRateTag];
//}
//-(NSInteger)frameRateTag{
//    return _streamerView.frameRateTag;
//}
//-(void)setInputPriorityTag:(NSInteger)inputPriorityTag{
//    [_streamerView setInputPriorityTag:inputPriorityTag];
//}
//-(NSInteger)inputPriorityTag{
//    return _streamerView.inputPriorityTag;
//}
//-(void)setEndPunch:(bool)endPunch{
//    [_streamerView setEndPunch:endPunch];
//}
//-(bool)endPunch{
//    return _streamerView.endPunch;
//}


// items to make bindings to streamerView.streamerImage work
//[self willChangeValueForKey:@"progressX"];
//[self willChangeValueForKey:@"progressY"];
//[self willChangeValueForKey:@"progressWidth"];
//[self willChangeValueForKey:@"progressHeight"];
//[self willChangeValueForKey:@"colorProgressForeground"];
//[self willChangeValueForKey:@"colorProgressBackground"];
//[self willChangeValueForKey:@"progressEnable"];

//-(void)setProgressX:(NSInteger)progressX{
//    [_streamerView.streamerImage setProgressX:progressX];
//}
//-(NSInteger)progressX{
//    return _streamerView.streamerImage.progressX;
//}
//-(void)setProgressY:(NSInteger)progressY{
//
//    [_streamerView.streamerImage setProgressY:progressY];
//}
//-(NSInteger)progressY{
//    return _streamerView.streamerImage.progressY;
//}
//-(void)setProgressWidth:(NSInteger)progressWidth{
//    [_streamerView.streamerImage setProgressWidth:progressWidth];
//}
//-(NSInteger)progressWidth{
//    return _streamerView.streamerImage.progressWidth;
//}
//-(void)setProgressHeight:(NSInteger)progressHeight{
//    [_streamerView.streamerImage setProgressHeight:progressHeight];
//}
//-(NSInteger)progressHeight{
//    return _streamerView.streamerImage.progressHeight;
//}
//-(void)setColorProgressForeground:(NSInteger)colorProgressForeground{
//
//    [_streamerView.streamerImage setColorProgressForeground:colorProgressForeground];
//}
//-(NSInteger)colorProgressForeground{
//    return _streamerView.streamerImage.colorProgressForeground;
//}
//-(void)setColorProgressBackground:(NSInteger)colorProgressBackground{
//
//    [_streamerView.streamerImage setColorProgressBackground:colorProgressBackground];
//}
//-(NSInteger)colorProgressBackground{
//    return _streamerView.streamerImage.colorProgressBackground;
//}
//-(void)setProgressEnable:(bool)progressEnable{
//    [_streamerView.streamerImage setProgressEnable:progressEnable];
//}
//-(bool)progressEnable{
//    return _streamerView.streamerImage.progressEnable;
//}

//[self willChangeValueForKey:@"colorStreamer0"];
//[self willChangeValueForKey:@"colorStreamer1"];
//[self willChangeValueForKey:@"colorStreamer2"];
//[self willChangeValueForKey:@"colorStreamer3"];
//[self willChangeValueForKey:@"colorEndBar"];
//[self willChangeValueForKey:@"width"];
//[self willChangeValueForKey:@"top"];
//[self willChangeValueForKey:@"bottom"];
//[self willChangeValueForKey:@"transparency"];
//[self willChangeValueForKey:@"colorMsb"];
//[self willChangeValueForKey:@"duration"];

//-(void)setColorStreamer0:(NSInteger)colorStreamer0{
//
//    [_streamerView.streamerImage setColorStreamer0:colorStreamer0];
//}
//-(NSInteger)colorStreamer0{
//    return _streamerView.streamerImage.colorStreamer0;
//}
//-(void)setColorStreamer1:(NSInteger)colorStreamer1{
//
//    [_streamerView.streamerImage setColorStreamer1:colorStreamer1];
//
//}
//-(NSInteger)colorStreamer1{
//    return _streamerView.streamerImage.colorStreamer1;
//}
//-(void)setColorStreamer2:(NSInteger)colorStreamer2{
//
//    [_streamerView.streamerImage setColorStreamer2:colorStreamer2];
//
//}
//-(NSInteger)colorStreamer2{
//    return _streamerView.streamerImage.colorStreamer2;
//}
//-(void)setColorStreamer3:(NSInteger)colorStreamer3{
//
//    [_streamerView.streamerImage setColorStreamer3:colorStreamer3];
//
//}
//-(NSInteger)colorStreamer3{
//    return _streamerView.streamerImage.colorStreamer3;
//}
//-(void)setColorEndBar:(NSInteger)colorEndBar{
//
//    [_streamerView.streamerImage setColorEndBar:colorEndBar];
//
//}
//-(NSInteger)colorEndBar{
//    return _streamerView.streamerImage.colorEndBar;
//}
//
//-(void)setWidth:(NSInteger)width{
//    [_streamerView.streamerImage setWidth:width];
//}
//-(NSInteger)width{
//    return _streamerView.streamerImage.width;
//}
//-(void)setTop:(NSInteger)top{
//    [_streamerView.streamerImage setTop:top];
//}
//-(NSInteger)top{
//    return _streamerView.streamerImage.top;
//}
//-(void)setBottom:(NSInteger)bottom{
////    NSLog(@"setBottom: %d",(int)bottom);
//    [_streamerView.streamerImage setBottom:bottom];
//}
//-(NSInteger)bottom{
//
//    NSInteger bottom = _streamerView.streamerImage.bottom;
////    NSLog(@"bottom: %d",(int)bottom);
//    return bottom;
//}
//-(void)setTransparency:(NSInteger)transparency{
//
//    [_streamerView.streamerImage setTransparency:transparency];
//}
//-(NSInteger)transparency{
//    return _streamerView.streamerImage.transparency;
//}
//-(void)setColorMsb:(NSInteger)colorMsb{
//    [_streamerView.streamerImage setColorMsb:colorMsb];
//}
//-(NSInteger)colorMsb{
//    return _streamerView.streamerImage.colorMsb;
//}
//-(void)setDuration:(double)duration{
//    [_streamerView.streamerImage setDuration:duration];
//}
//-(double)duration{
//    return _streamerView.streamerImage.duration;
//}

// end of items to make bindings to streamerView.streamerImage work

-(void)setColorLtcForeground:(NSInteger)colorLtcForeground{
    
//    VM15Window *vm15Window = [[_draggableItemView vm15WindowArray] objectAtIndex:3];  // ltc is window 3
//    NSInteger aColor = vm15Window.color & 0xf0; aColor += colorLtcForeground;
//    [vm15Window setColor:aColor];
}
-(NSInteger)colorLtcForeground{
    
//    VM15Window *vm15Window = [[_draggableItemView vm15WindowArray] objectAtIndex:3];    // ltc is window 3
//    return vm15Window.color & 7;
    return 0;
}
-(void)setColorLtcBackground:(NSInteger)colorLtcBackground{
    
//    VM15Window *vm15Window = [[_draggableItemView vm15WindowArray] objectAtIndex:3];   // ltc is window 3
//    NSInteger aColor = colorLtcBackground <<= 4; aColor += vm15Window.color & 0x7;
//    [vm15Window setColor:aColor];
//    [self txMsg:[vm15Window toString]];
    
}
-(NSInteger)colorLtcBackground{
    
//    VM15Window *vm15Window = [[_draggableItemView vm15WindowArray] objectAtIndex:3];    // ltc is window 3
//    return (vm15Window.color >> 4);
    return 0;
}
-(void)setColorDialogForeground:(NSInteger)colorDialogForeground{
    
//    VM15Window *vm15Window = [[_draggableItemView vm15WindowArray] objectAtIndex:0];  // dialog is window 0
//    NSInteger aColor = vm15Window.color & 0xf0; aColor += colorDialogForeground;
//    [vm15Window setColor:aColor];
//    [self txMsg:[vm15Window toString]];
//
//    [self setDialogTag:_dialogTag];     // show text

}
-(NSInteger)colorDialogForeground{
    
//    VM15Window *vm15Window = [[_draggableItemView vm15WindowArray] objectAtIndex:0]; // dialog is window 0
//    return vm15Window.color & 7;
    return 0;
}
-(void)setColorDialogBackground:(NSInteger)colorDialogBackground{
    
//    VM15Window *vm15Window = [[_draggableItemView vm15WindowArray] objectAtIndex:0];   // dialog is window 0
//    NSInteger aColor = colorDialogBackground <<= 4; aColor += vm15Window.color & 0x7;
//    [vm15Window setColor:aColor];
//    [self txMsg:[vm15Window toString]];
//
//    [self setDialogTag:_dialogTag];     // show text
}
-(NSInteger)colorDialogBackground{
    
//    VM15Window *vm15Window = [[_draggableItemView vm15WindowArray] objectAtIndex:0];    // dialog is window 0
//    return (vm15Window.color >> 4);
    return 0;

}
-(void)setColorTakeForeground:(NSInteger)colorTakeForeground{
    
//    VM15Window *vm15Window = [[_draggableItemView vm15WindowArray] objectAtIndex:2];  // take is window 2
//    NSInteger aColor = vm15Window.color & 0xf0; aColor += colorTakeForeground;
//    [vm15Window setColor:aColor];
//    [self txMsg:[vm15Window toString]];
//
//    [self setTakeTag:_takeTag]; // show take
}
-(NSInteger)colorTakeForeground{
//    VM15Window *vm15Window = [[_draggableItemView vm15WindowArray] objectAtIndex:2];    // take is window 2
//    return vm15Window.color & 7;
    return 0;
}
-(void)setColorTakeBackground:(NSInteger)colorTakeBackground{
    
//    VM15Window *vm15Window = [[_draggableItemView vm15WindowArray] objectAtIndex:2];   // take is window 2
//    NSInteger aColor = colorTakeBackground <<= 4; aColor += vm15Window.color & 0x7;
//    [vm15Window setColor:aColor];
//    [self txMsg:[vm15Window toString]];
//
//    [self setTakeTag:_takeTag]; // show take
}
-(NSInteger)colorTakeBackground{
    
//    VM15Window *vm15Window = [[_draggableItemView vm15WindowArray] objectAtIndex:2];    // take is window 2
//    return (vm15Window.color >> 4);
    return 0;
}
//-(void)setProgressBarEnable:(bool)progressBarEnable{
//    [self.streamerView.streamerImage setProgressEnable:progressBarEnable];
//}
//-(bool)progressBarEnable{
//    
//    return self.streamerView.streamerImage.progressEnable;
//}

//- (IBAction)onClearText:(id)sender {
//}
//-(void)setRehearseColor:(NSColor *)rehearseColor{
//
////    [_draggableItemView setAnnunciatorColorAndText:rehearseColor :@"Rehearse"];
//////    [_draggableItemView setRehearseColor:rehearseColor];
////    _rehearseColor = rehearseColor;
//
//    _aleDelegate.overlayWindowController.viewController.textWindowServer.rehearseColor = rehearseColor;
////
////    [self sendAnnunciator24BitColors];
//}
//-(NSColor*)rehearseColor{
//
////    return _draggableItemView.rehearseColor;
//    return [[NSUserDefaults standardUserDefaults]colorForKey:@"rehearseColor"];
////    _aleDelegate.overlayWindowController.viewController.textWindowServer.rehearseColor;//_rehearseColor;
//}
//-(void)setRecordColor:(NSColor *)recordColor{
//
////    [_draggableItemView setAnnunciatorColorAndText:recordColor :@"Record"];
////    [_draggableItemView setRecordColor:recordColor];
////    _recordColor = recordColor;
//    _aleDelegate.overlayWindowController.viewController.textWindowServer.recordColor = recordColor;
////    [self sendAnnunciator24BitColors];
//}
//-(NSColor*)recordColor{
//
////    return _draggableItemView.recordColor;
//    return [[NSUserDefaults standardUserDefaults]colorForKey:@"recordColor"];
////    _aleDelegate.overlayWindowController.viewController.textWindowServer.recordColor;//_recordColor;
//}
//-(void)setPlaybackColor:(NSColor *)playbackColor{
////    [_draggableItemView setAnnunciatorColorAndText:playbackColor :@"Playback"];
////    [_draggableItemView setPlaybackColor:playbackColor];
////    _playbackColor = playbackColor;
//    _aleDelegate.overlayWindowController.viewController.textWindowServer.playbackColor = playbackColor;
////    [self sendAnnunciator24BitColors];
//}
//-(NSColor*)playbackColor{
//    return [[NSUserDefaults standardUserDefaults]colorForKey:@"playbackColor"];
//}
////-(void)setRehearseBgColor:(NSColor *)rehearseBgColor{
////    NSLog(@"setRehearseBgColor");
////    [[NSUserDefaults standardUserDefaults] setColor:rehearseBgColor forKey: @"key"];
////}
////-(NSColor *)rehearseBgColor{
////    return _aleDelegate.overlayWindowController.viewController.textWindowServer.rehearseBgColor;
////}
#pragma mark -
#pragma mark ------------ debug 1.00.14 05/06/20 ---------------------

- (IBAction)onArmBeeps:(id)sender {
    NSLog(@"onArmBeeps");
    _armBeeps = true;
}

#pragma mark -
#pragma mark ------------ v1.00.04 additions ---------------------

-(void)firstCueGreaterThan:(NSString*)tc{
    
    // on play debounce go to first cue greater than
    // actually should be on first filtered MTC
    
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    Document *doc = [delegate topDocument]; if(!doc) return;
    
    if([doc.behaviorCombo indexOfSelectedItem] != BEHAVIOR_INDEX_FOLLOW_CUESHEET) return;
    
//    if(![doc cueSheetFollowsMtc]) return;
    
    // check all cue sheet rows
    
    for(NSMutableDictionary *dict in doc.tableContents){
        
        NSString *t = [_tcf tcForString:[doc startForDictionary:dict]];
        
        if([_tcc compareTc:tc fromTc:t withType:TCTYPE_30] < 0){     // select this row, triggerStreamer() will do the trigger
            
            NSInteger index = [doc.tableContents indexOfObject:dict];   // the row to select
            [doc selectRow:index];  // 2.10.00 TODO: does this set recordCycleDictionary?
            doc.recordCycleDictionary = dict;
            
            return;
        }
        
    }
    
}

-(void)docFollowsTc:(NSString *)tc{
    
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    Document *doc = [delegate topDocument]; if(!doc) return;
    
    // check all cue sheet rows
    
    for(NSMutableDictionary *dict in doc.tableContents){
        
        NSString *t = [_tcf tcForString:[doc startForDictionary:dict]];
        
        if([t isEqualToString:tc]){     // select this row, triggerStreamer() will do the trigger
            
//            NSLog(@"row change at trigger: %@ mtc: %@",t, tc);
            
            NSInteger index = [doc.tableContents indexOfObject:dict];   // the row to select
            // will call tableViewSelectionDidChange, sends dialog and take
            [doc selectRow:index];
            
            [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:self.streamerColor];
            
            return;
        }
        
    }
//    
//    
//    
//    // check only selected items in _tableView for streamer triggers
//    NSIndexSet* set = [doc selectedRowIndexes];
//    
//    if(set == nil) return;
//    //    if(doc.autoPlay && mwc.modeControl != MODE_CONTROL_PLAYBACK) [    // TODO monitor switching only in playback
//    
////    NSInteger firstIndex = doc.autoPlay ? 0 : set.firstIndex;
////    NSInteger lastIndex = doc.autoPlay ? doc.tableContents.count - 1 : set.lastIndex;
//    NSInteger firstIndex = set.firstIndex;
//    NSInteger lastIndex = set.lastIndex;
////
////    if(doc.autoPlay){
////        // in autoPlay use all cues
////        set = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, doc.tableContents.count)];
////    }
//    
//    if(!set.count || set.count == 1) return;
//    
//    // if we are in autoPlay, at tc - trimFrames set recordCycleDictionary
//    int autoPlayFrames = [_tcc tcToBinary:tc withType:(int)doc.tcType];
//    int trimFrames = (int)[delegate.matrixWindowController trimFrames]; //NSLog(@"trimFrames: %d",trimFrames);
//    autoPlayFrames += abs(trimFrames);
////    NSString *autoPlayTc = [_tcc binaryToTc:autoPlayFrames withType:(int)doc.tcType];
//    
//    for(NSInteger i = firstIndex; i <= lastIndex; i++){
//         
//        NSMutableDictionary *dict = [doc.tableContents objectAtIndex:i];
//        NSInteger indexOfObject = [doc.tableContents indexOfObject:dict];
//        
//        streamerTc = [_tcc subtractTc:trimFramesTc fromTc:streamerTc withType:(int)doc.tcType];
//        NSString *start = [_tcf tcForString:[doc startForDictionary:dict]];
//        
////        if(doc.autoPlay && [autoPlayTc isEqualToString:start] && [delegate.matrixWindowController modeControl] == MODE_CONTROL_PLAYBACK){
////            delegate.recordCycleDictionary = dict;
//////            NSLog(@"set recordCycleDictionary with start %@ at %@",start,autoPlayTc);
////        }
//        
//        if([t isEqualToString:start]) continue; // do not double trigger on recordCycleDictionary
//        
//        if([start isEqualToString:streamerTc]
//           && [delegate.matrixWindowController modeControl ] != MODE_CONTROL_PLAYBACK
//           && indexOfObject >= set.firstIndex && indexOfObject <= set.lastIndex){
//            
//            // fire the accumulating
//            NSMutableData *data = [[NSMutableData alloc] init];
//            
//            Byte trigger[] = {0x90,119,1}; // accum streamer
//            
//            [data appendBytes:trigger length:sizeof(trigger)];
//            
//            if(data.length) [self txMidiAsString:data];
//        }
//    }
}
-(void)triggerStreamer:(NSString*)tc{
    
    // we are on the main thread
    // this is called for every tc frame
    // we are not stopped
    
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    Document *doc = [delegate topDocument]; if(!doc) return;
    MatrixWindowController *mwc = ((AleDelegate*)[NSApp delegate]).matrixWindowController; if(!mwc) return;
    EditorWindowController *ed = delegate.editorWindowController; if(!ed) return;
    
    bool inhStreamer = (self.inhibitStreamerInPlayback && mwc.rehRecPb == MODE_CONTROL_PLAYBACK);
    
    // 2.10.00 streamer can follow annunciator color
    bool useAnnunciatorColor = [[NSUserDefaults standardUserDefaults] boolForKey:@"useAnnunciatorColor"];
    NSColor *annunciatorColor = delegate.overlayWindowController.viewController.annunciatorTextView.textColor;

    int tcType = (int)[delegate getTcType];

    // 2.10.02 select the first row when a cue sheet is loaded, which sets recordCycleDictionary
    if(!doc.recordCycleDictionary) return; // no values for comparison
    
    [mwc captureGuide:tc];         // maybe capture the guide track on the first rehearse pass
    [mwc aheadInPastFromTc:tc];    // set from here when running
    
    // add the streamer duration
    CFTimeInterval duration = _aleDelegate.overlayWindowController.viewController.streamer.globalDuration;
    NSString *streamerTc = [_tcc timeIntervalToTc:duration withType:tcType];
    tc = [_tcc addTc:tc toTc:streamerTc withType:tcType];
    
    // calc streamer delay
//    NSInteger delay = [[NSUserDefaults standardUserDefaults]integerForKey:@"videoSyncOffsetMs"];
//    double delayMs = (double)delay / 1000.0;
//
//    // add in 1/4 frame delay
//    delay = [[NSUserDefaults standardUserDefaults]integerForKey:@"videoSyncOffset"];    // 1/4 frs
//    switch(tcType){
//        case TCTYPE_24:
//            delayMs += (double)delay / 96.0;
//            break;
//        case TCTYPE_25:
//            delayMs += (double)delay / 100.0;
//            break;
//        default:
//            delayMs += (double)delay / 120.0;
//            break;
//    }
    
    double delayMs = 0.0;   // TODO: is this ever used? Video Sync Offset and Video Sync Offset, ms are gone
    
    
    bool enBeeps = [[NSUserDefaults standardUserDefaults]boolForKey:@"enBeeps"];

    if(!inhStreamer){
        
        // trigger the extra streamers if not ale_mini
        
        NSString *streamer1 = [_tcf tcForString:[doc.recordCycleDictionary objectForKey:@"streamer1"]];
        NSString *streamer2 = [_tcf tcForString:[doc.recordCycleDictionary objectForKey:@"streamer2"]];
        NSString *streamer3 = [_tcf tcForString:[doc.recordCycleDictionary objectForKey:@"streamer3"]];
        NSString *streamer4 = [_tcf tcForString:[doc.recordCycleDictionary objectForKey:@"streamer4"]];
        NSString *streamer5 = [_tcf tcForString:[doc.recordCycleDictionary objectForKey:@"streamer5"]];
        NSString *streamer6 = [_tcf tcForString:[doc.recordCycleDictionary objectForKey:@"streamer6"]];
        
        // ignore the hours for triggering
        // TODO: there is no beeps trim on these
        
        if(streamer1 && [_tcc compareTc:streamer1 fromTc:tc withType:tcType] == NSOrderedSame){
            
            // fire the next available streamer
            [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:useAnnunciatorColor ? annunciatorColor : [ed colorStreamer1] : enBeeps :delayMs]; // 2.00.00 no punch or beeps for Foley streamers
        }
        else if(streamer2 && [_tcc compareTc:streamer2 fromTc:tc withType:tcType] == NSOrderedSame){
            [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:useAnnunciatorColor ? annunciatorColor : [ed colorStreamer2] : enBeeps :delayMs]; // 2.00.00 no punch or beeps for Foley streamers
        }
        else if(streamer3 && [_tcc compareTc:streamer3 fromTc:tc withType:tcType] == NSOrderedSame){
            [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:useAnnunciatorColor ? annunciatorColor : [ed colorStreamer3] : enBeeps :delayMs]; // 2.00.00 no punch or beeps for Foley streamers
        }
        else if(streamer4 && [_tcc compareTc:streamer4 fromTc:tc withType:tcType] == NSOrderedSame){
            [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:useAnnunciatorColor ? annunciatorColor : [ed colorStreamer4] : enBeeps :delayMs]; // 2.00.00 no punch or beeps for Foley streamers
        }
        else if(streamer5 && [_tcc compareTc:streamer5 fromTc:tc withType:tcType] == NSOrderedSame){
            [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:useAnnunciatorColor ? annunciatorColor : [ed colorStreamer5] : enBeeps :delayMs]; // 2.00.00 no punch or beeps for Foley streamers
        }
        else if(streamer6 && [_tcc compareTc:streamer6 fromTc:tc withType:tcType] == NSOrderedSame){
            [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:useAnnunciatorColor ? annunciatorColor : [ed colorStreamer6] : enBeeps :delayMs]; // 2.00.00 no punch or beeps for Foley streamers
        }
    }
    
    // _recordCycleDictionary is the first of the rows selected in _tableView
    
    // subtract the beeps offset TODO: what about editor streamers? Should they be offset?
    
    // negative beepsTrimFrames is an advance
    // increasing tc triggers sooner, so subtracting a negative triggers sooner
    NSString *trimFramesTc = [_tcc binaryToTc:(int)doc.beepsTrimFrames withType:tcType];
    tc = [_tcc subtractTc:trimFramesTc fromTc:tc withType:tcType];

    NSInteger behaviorIndex = [doc.behaviorCombo indexOfSelectedItem];
    
    if(behaviorIndex == BEHAVIOR_INDEX_FOLLOW_CUESHEET){
        
        [self docFollowsTc:tc];  // cue sheet follows mtc
       
    }
        
    NSColor *color = useAnnunciatorColor ? annunciatorColor : self.streamerColor;

    // always trigger off of recordCycleDictionary
    NSString *start = [_tcf tcForString:[doc startForDictionary]];
    
    if([_tcc compareTc:start fromTc:tc withType:tcType] == NSOrderedSame){
   
        // 2.10.02 moved to annunciatorOffTimerService
//        _aleDelegate.overlayWindowController.viewController.annunciatorTextView.fadeDuration = 1.0;
//        _aleDelegate.overlayWindowController.viewController.annunciatorTextView.opacity = 0.0;
        
        if(!inhStreamer){
            [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:color :enBeeps :delayMs]; return; // 2.00.00
        }
    }
    
    NSArray *array = [doc selectedContents];    //
    
    if(array.count == 0) return;    // nothing to test
    
    if(behaviorIndex == BEHAVIOR_INDEX_SINGLE_STREAMER){
        
        return; // triggered on
        
    }

    for (NSMutableDictionary *dict in array){
        
        NSString *start = [_tcf tcForString:[doc startForDictionary:dict]];
        
        if([_tcc compareTc:start fromTc:tc withType:tcType] == NSOrderedSame){
            
            // FIXME: logic for annunciator fadeout is blocked
            
            _aleDelegate.overlayWindowController.viewController.annunciatorTextView.fadeDuration = 1.0;
            _aleDelegate.overlayWindowController.viewController.annunciatorTextView.opacity = 0.0;
            
            if(!inhStreamer){
                [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:self.streamerColor :enBeeps :delayMs]; return; // 2.00.00
            }

        }
    }
    
}

- (IBAction)onTest:(id)sender {
    
    NSLog(@"onArmBeeps");
    _armBeeps = true;

//    unsigned char msg[] = {'V',' ','c','a','f',0xe9,'\n'};
//    
//    NSMutableData *data = [[NSMutableData alloc] initWithBytes:msg length:sizeof(msg)];
//    [_connection txData:data];
    
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//
//    if([delegate respondsToSelector:@selector(onTest:)]){
//
//        [delegate performSelector:@selector(onTest:) withObject:sender];
//
//    }
   
}
@end
