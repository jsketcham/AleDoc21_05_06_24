//
//  AdrClientWindowController.m
//  Ale_v3xx
//
//  Created by James Ketcham on 3/12/14.
//  Copyright (c) 2014 WB ADR. All rights reserved.
//

#import "AdrClientWindowController.h"
#import "TcpClientConnection.h"
#import "AleDelegate.h"
#import "Document.h"
#import "MatrixWindowController.h"
#import "Annunciator.h"
//#import "EditorWindowController.h"
#import "StreamerWindowController.h"
#import "TcCalculator.h"
#import "AleDoc21-Swift.h"    // must be here to avoid a circular reference


#pragma mark -
#pragma mark AdrClientWindowController class

@interface AdrClientWindowController (){
    
    bool leftPaneClicked;
    bool didInitDisplayFormat;    // toggle once on program start to get all the digits
}
@property (weak) IBOutlet Annunciator *protoolsAnnunciator;
@property NSString *sessionTitle;
//@property NSString *server;
@property TcCalculator *tcc;
@property NSDate *lastMouseUp;    // detect double clicks, restore yPos

@end

@implementation AdrClientWindowController

@synthesize responseField = _responseField;
@synthesize services = _serviceList;
@synthesize sessionTitle = _sessionTitle;
@synthesize yPos = _yPos;
@synthesize xPos = _xPos;
@synthesize adrClient = _adrClient;

NSLock *ioLock;

#define SERVER_KEY @"server_adr"

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        _yPos = @"-1"; // no mouse up yet
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:@"",SERVER_KEY, nil];
        [defaults registerDefaults:dictionary];
        
        //        [self setServer:[defaults objectForKey:SERVER_KEY]];
        
        _tcc = [[TcCalculator alloc]init];
        
        ioLock = [[NSLock alloc] init];
        
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(windowClosing:)
         name:NSWindowWillCloseNotification
         object:nil ];
        
        // commands for rxMsg
        
        _cmdDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
                          @"getProtoolsInfo:",@"getProtoolsInfo"
                          ,@"getProtoolsPosition:",@"getProtoolsPosition"
                          ,@"getProtoolsPosition:",@"jxaGetProtoolsPosition"
                          ,@"getTransportOut:",@"getTransportOut"
                          ,@"cutAndPaste:",@"cutAndPaste"   // fill in circle take column
                          ,@"cutAndPaste:",@"jxaCutAndPaste"   // fill in circle take column
                          //                          ,@"getTrackList:",@"getTrackList"
                          //                          ,@"deselectTracks:",@"deselectTracks"
                          ,@"addCue:",@"addCue"
                          ,@"addCue:",@"jxaAddCue"
                          ,@"setDialog:",@"jxaSetDialog"
                          ,@"setDialog:",@"setDialog"
                          ,@"setCueName:",@"jxaSetCueName"
                          ,@"setCueName:",@"setCueName"
                          ,@"setNote:",@"setNote"   // mixer's note, not cue sheet note FIXME ask Evan
                          ,@"setNote:",@"jxaSetNote"   // mixer's note, not cue sheet note FIXME ask Evan
                          ,@"ping:",@"ping"
                          //                          ,@"getProtoolsPosition:",@"getProtoolsPosition"
                          //                          ,@"getClipList:",@"getClipList"
                          ,@"armLastTrack:",@"armLastTrack"
                          ,@"armLastTrack:",@"jxaArmLastTrack"
                          ,@"armLastTrack:",@"armLastTrackFoley"
                          ,@"getSession:",@"getSession"
                          ,@"getSession:",@"jxaGetSession"
                          ,@"getSampleRate:",@"jxaGetSampleRate"
                          //                          ,@"clipboard:",@"clipboard"
                          //                          ,@"frontWindow:",@"frontWindow"
                          ,@"renameLastTrack:",@"renameLastTrack"
                          ,@"renameLastTrack:",@"renameLastTrackFoley"
                          ,@"renameLastTrack:",@"jxaRenameLastTrack"
                          ,@"copyClipToComp:",@"copyClipToComp"
                          ,@"jxaCopyClipToComp:",@"jxaCopyClipToComp"
                          ,@"copyClipToIndex:",@"copyClipToIndex"
                          ,@"getPreEdit:",@"getPreEdit"
                          //                          ,@"keyCode:",@"keyCode"
                          ,@"zeroFeet:",@"zeroFeet"
                          //                          ,@"locateZeroFeet:",@"locateZeroFeet"
                          ,@"mainCounterFormat:",@"mainCounterFormat"
                          //                          ,@"zeroFeetAtTc:",@"zeroFeetAtTc"
//                          ,@"wildSyncSelect2:",@"jxaWildSyncSelect"
                          ,@"wildSyncSelect:",@"wildSyncSelect"
                          ,@"midiStop:",@"midiStop"
                          ,@"mouseUpCmd:",@"mouseUp"
                          ,@"getTrackPos:",@"getTrackPos"
                          ,@"getRegion:",@"getRegion"
                          ,@"setDialog:",@"setDialogFoley"  // calls same routine as setDialog
                          //                          ,@"lastYPos:",@"lastYPos"
                          ,@"stopSpinner:",@"stopSpinner"
                          ,@"keyWithModifiers:",@"keyWithModifiers" //
                          ,@"yIndex:",@"yIndex"
                          ,@"keyboard:",@"keyboard"
                          ,@"setTargetTrackByLastMouseUp:",@"setTargetTrackByLastMouseUp"
                          ,@"unmuteTargetByLastMouseUp:",@"unmuteTargetByLastMouseUp"
                          ,@"grabAll:",@"grabAll"
                          ,@"isModalDialog:",@"isModalDialog"
                          ,@"isModalDialog:",@"jxaIsModalDialog"
                          ,@"pingProTools:",@"pingProTools"
                          ,@"videoOnline:",@"videoOnline"
//                          ,@"getVideoSyncOffset:",@"jxaGetVideoSyncOffset"

                          ,nil];
    }
    
    return self;
}

#define PING_INTERVAL 5.0
- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    //    _tcpClient = [[TcpClientBrowser alloc] init];
    //    [_tcpClient setDelegate:self];
    //
    //    [_tcpClient searchForServicesOfType:@"_endpoint_adr._tcp." inDomain:@"local"];
    
    _yIndex = -1; _lastYIndex = -1; _mutedYIndex = -1;
    
    [self setShowTimeOfDay:true];   // trigger bindings
    
    _adrClient = [[AdrClient alloc] init];
    _adrClient.delegate = self;
    [_adrClient startAdrClient];    // a local thread instead of a tcp server/client
    
    //    [self startTcpClient];
    
    [_protoolsAnnunciator setOffIndex:RED_INDEX];
    [_protoolsAnnunciator setText:@"Protools"];
    [_protoolsAnnunciator setState:NSControlStateValueOff];
    
    //    NSBundle *mainBundle = [NSBundle mainBundle];
    //
    //    greenImage = [[NSImage alloc] initWithContentsOfURL:[mainBundle URLForImageResource:@"green16.png"]];
    //    redImage = [[NSImage alloc] initWithContentsOfURL:[mainBundle URLForImageResource:@"red16.png"]];
    //    [self setConnectionStatusImage:redImage];
    
    [self setTimer:[NSTimer scheduledTimerWithTimeInterval:PING_INTERVAL target: self selector:@selector(timer_service) userInfo:nil repeats: YES]];
}
//-(void)startTcpClient{
//
//    // start the tcp client
//    [self setTcpClient:[[TcpClientBrowser alloc] init]] ;
//    [_tcpClient setDelegate:self];
//    [_tcpClient searchForServicesOfType:@"_endpoint_adr._tcp." inDomain:@"local"];
//
//}

-(void)windowClosing: (NSNotification *) notification
{
    NSWindow *window = [notification object];   // ref NSNotification Class Reference
    NSWindow *myWindow = [self window];         // ref NSView Class Reference
    
    // is our window closing?
    
    if(window == myWindow){
        
    }
}
bool bInitializePtCtr = false;

-(void)rxMsgFromAdrServer:(NSString *)msg{
    
    //    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    //
    //    [delegate rxMsgFromAdrServer:msg];
}
-(void) timer_service
{
    [_adrClient addToInArray:@"pingProTools"];
}

#pragma mark -
#pragma mark User interface action methods

- (IBAction)requestTextFieldReturnAction:(id)sender {
    
    [self txMsg:[sender stringValue]];
}

//-(void)addCueToDoc:(NSString*)name start:start end:(NSString*)end{
//    
//    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
//    
//    Document *doc = [delegate topDocument];
//    [doc addCueToDoc:name start:start end:end];
//
//}
-(NSInteger)getIndexForYPos:(NSString*)yPos{
    
    // returns the index from the bottom track for copyClipToIndex.scpt
    
    float menuBarHeight = 0;//[[[NSApplication sharedApplication] mainMenu] menuBarHeight];//14.0;  // default is 22.0
    
    float yValue = [yPos floatValue];
    
    for (NSDictionary *dict in _trackPos) {
        
        if([_trackPos indexOfObject:dict] == 0){    // Edit:
            
            // captured Edit: origin (which is menuBarHeight if it is up against the menu bar)
            menuBarHeight = [[dict objectForKey:Y_KEY] floatValue];
            continue;
        }
        
        float y = [[dict objectForKey:Y_KEY] floatValue];
        float h = [[dict objectForKey:H_KEY] floatValue];
        
        y -= menuBarHeight;
        
        // Edit: is at y = 22 when it is all the way at the top
        // mouse clicks in Edit: window are relative to Edit: upper left
        
        if (yValue < y + h){
            
            return [_trackPos indexOfObject:dict];   // applescript indices start at 1, Edit: is _trackPos[0], first audio track is _trackPos[1]
        }
    }
    
    return -1;  // error return
}

-(void)muteTrackForIndex:(NSInteger)index :(bool)mute{
    
    if(index < 1) return; // not a legal index
    
    [self txMsg:[NSString stringWithFormat:@"muteTrackWithIndex\t%d\t%d",(int)index,mute]];
    
}
//-(NSInteger)yIndexForYPos{
//
//    NSInteger index = [self getIndexForYPos:_yPos];
//
//    if(index <= 0){
//
//        [NSApp activateIgnoringOtherApps:YES];  // brings our alert to the front
//
//        NSAlert *alert =  [[NSAlert alloc] init];
//        alert.messageText = @"click on track again, repeat the operation";
//        //        NSAlert *alert = [NSAlert alertWithMessageText:@"click on track again, repeat the operation" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
//        [alert runModal];
//
//        return -1;
//    }else if(index == _trackPos.count - 1){
//
//        [NSApp activateIgnoringOtherApps:YES];  // brings our alert to the front
//
//        NSAlert *alert =  [[NSAlert alloc] init];
//        alert.messageText = @"can't select record track as the target";
//        //        NSAlert *alert = [NSAlert alertWithMessageText:@"can't select record track as the target" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
//        [alert runModal];
//
//        return -1;
//    }else if(_trackPos == nil){
//
//        [NSApp activateIgnoringOtherApps:YES];  // brings our alert to the front
//
//        NSAlert *alert =  [[NSAlert alloc] init];
//        alert.messageText = @"no track layout";
//        //        NSAlert *alert = [NSAlert alertWithMessageText:@"no track layout" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
//        [alert runModal];
//
//        return -1;
//    }
//
//    _lastYIndex = _yIndex;  // the only place this is set...
//    _yIndex = index;
//
//    NSDictionary *dict = _trackPos[index];
//    if(_delegate) [_delegate showTargetTrackTitle:dict[@"title"]];
//
//    return 0;   // success
//
//}
#pragma mark -
#pragma mark ------------------ setters/getters ---------------------
-(void)setYPos:(NSString *)yPos{
    
    _lastYPos = _yPos;
    _yPos = yPos;
}
-(NSString*)yPos{
    
    return _yPos;
}
-(void)setXPos:(NSString *)xPos{
    
    _lastXPos = _xPos;
    _xPos = xPos;
}
-(NSString*)xPos{
    return _xPos;
}
#pragma mark -
#pragma mark ------------------ Adr client response handlers ---------------------
//videoOnline
//-(void)getVideoSyncOffset:(NSArray*)msgArray{
//    
////    NSLog(@"getVideoSyncOffset %@",msgArray[0]);
//    // [0] is in 1/4 frs, [1] is in ms
//    NSInteger ofs = ((NSString *)msgArray[0]).intValue;
//    [[NSUserDefaults standardUserDefaults]setInteger:ofs forKey:@"videoSyncOffset"];
//    ofs = ((NSString *)msgArray[1]).intValue;
//    [[NSUserDefaults standardUserDefaults]setInteger:ofs forKey:@"videoSyncOffsetMs"];
//}
-(void)videoOnline:(NSArray*)msgArray{
    
    //    NSLog(@"videoOnline");
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    [delegate.overlayWindowController.viewController bringToFront];
    
}
-(void)pingProTools:(NSArray*)msgArray{
    
    //    NSLog(@"pingProTools %@",msgArray[0]);
    
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    MatrixWindowController *mwc = [delegate matrixWindowController];
    
    [self txMsg:@"jxaGetSampleRate"];
    
//    unsigned char tx[] = {0x90,0,0};    // ping boom recorder
//    [delegate.lpMini.boomRecorderMidi.midiClient midiTx:[NSData dataWithBytes:tx length:sizeof(tx)]];
    
    if(msgArray.count > 0 && [msgArray[0] isEqual: @"true"]){
        
        [_protoolsAnnunciator setState:NSControlStateValueOn];
        if(mwc) [mwc setAdrClientState:NSControlStateValueOn];
        
        // case where cue sheet is open before PT starts, this reads log
        if(delegate.session == nil || delegate.session.length == 0){
            [self txMsg:@"jxaGetSession"];
        }
        
    }else{
        [_protoolsAnnunciator setState:NSControlStateValueMixed];
        if(mwc) [mwc setAdrClientState:NSControlStateValueMixed];
        
    }
    

}
-(void)isModalDialog:(NSArray*)msgArray{
    
    // [0] operand
    // [1] "dialog" if modal dialog is in front
    // [2] execution time
    
    //    NSLog(@"isModalDialog");
    
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    
    if(msgArray.count != 3){    // 2.00.00
        
        delegate.cycleMotion = CYCLE_MOTION_IDLE;
        
        [delegate alertErr:@"isModalDialog wrong number of fields" :@""]; // 2.10.02
        
        return; // 2.00.00 2 fields is enough
    }
    
    
    if([msgArray[1] isEqualToString:@"1"]){
        
        delegate.cycleMotion = CYCLE_MOTION_IDLE;
        [delegate alertErr:@"Protools has a modal dialog up" :@""]; // 2.10.02
        
        return;
    }
    
    switch ([msgArray[0] integerValue]) {
            
        case 2: // AleDoc2
            
            if(delegate.cycleMotion == CYCLE_MOTION_STARTING){
                [delegate cueToCycleStart];
            }
            
            break;
            
        default: break;
    }
    
}
-(void)setTargetTrackByLastMouseUp:(NSArray*)msgArray{
    
    if(_delegate){
        
        if([_delegate testGrabAllTimeout]){
            
            [self txMsg:@"setTargetTrackByLastMouseUp"];
            
        }else{
            
            [_delegate setTargetTrackByLastMouseUpAfterQueue];
            
        }
        
    }
}
-(void)unmuteTargetByLastMouseUp:(NSArray*)msgArray{
    
    if(_delegate){
        
        if([_delegate testGrabAllTimeout]){
            
            [self txMsg:@"unmuteTargetByLastMouseUp"];
            
        }else{
            
            [_delegate unmuteTargetByLastMouseUpAfterQueue];
            
        }
        
    }
}
-(void)grabAll:(NSArray*)msgArray{
    
    if(_delegate){
        
        if([_delegate testGrabAllTimeout]){
            
            [self txMsg:@"grabAll"];
            
        }else{
            
            [_delegate grabAllAfterQueue];
            
        }
        
    }
}

//-(void)keyboard:(NSArray*)msgArray{
//    // if the spinner is going, send it again
//
//    if(_delegate){
//
//        if([_delegate testGrabAllTimeout]){  // getTrackPos is in progress, wait for track layout to be correct
//
//            [self txMsg:[NSString stringWithFormat:@"keyboard\t%@",msgArray[0]]];
//
//        }else{
//            [_delegate performSelector:@selector(midiKeyboardServiceAfterQueue:) withObject:msgArray[0]];
//        }
//
//    }
//}
-(void)yIndex:(NSArray*)msgArray{
    // check the name of the target track
    // [0] yIndex
    // [1] position
    // [2] size
    // [3] name
    // [5] execution time
    
    if(msgArray.count < 5) return;
    
    if(_delegate && [_delegate getTrackPosIsInhibited]) return; // Foley mixer wants layout feature disabled at this time
    
    NSInteger theIndex = [msgArray[0] integerValue];
    
    if(theIndex < _trackPos.count){
        
        NSDictionary *dict = _trackPos[theIndex];
        
        //        NSLog(@"%@ %@",msgArray[3],dict[@"title"]);
        NSCharacterSet *charSet = [NSCharacterSet characterSetWithCharactersInString:@", "];
        
        NSString *pos = [msgArray[1] stringByTrimmingCharactersInSet:charSet];
        NSArray *posArray = [pos componentsSeparatedByString:@","];
        
        NSString *size = [msgArray[2] stringByTrimmingCharactersInSet:charSet];
        NSArray *sizeArray = [size componentsSeparatedByString:@","];
        
        if(![[posArray[1] stringByTrimmingCharactersInSet:charSet] isEqualToString:dict[Y_KEY]]
           || ![[sizeArray[1] stringByTrimmingCharactersInSet:charSet] isEqualToString:dict[H_KEY]]){
            
            if(_delegate){
                
                if([_delegate testGrabAllTimeout]){
                    
                    leftPaneClicked = true; // call getTrackPos again when the current one completes
                }
                else{
                    
                    [_delegate initGrabAllTimeout];
                    [self txMsg:@"getTrackPos"]; //NSLog(@"getTrackPos from yIndex");
                }
            }
        }
    }
    
}
-(void)keyWithModifiers:(NSArray*)msgArray{
    
    if(_punchDate){
        
        NSTimeInterval timeInterval = [_punchDate timeIntervalSinceNow];
        [self appendToLog:[NSString stringWithFormat:@"punch delay: %3.3f",-timeInterval]];
        [self setPunchDate:nil];
        
    }
}
-(void)stopSpinner:(NSArray*)msgArray{
    
    if(_delegate)[_delegate grabAllTimeout];  // stop the spinner
}

-(void)getRegion:(NSArray*)msgArray{
    
    // [0] operand, 0 for rename and new row, 1 for skip rename
    // [1] edit selection start
    // [2] edit selection end
    // [3] clip name
    
    if(msgArray.count < 4) return;  // not enough items
    
    int operand = [msgArray[0] intValue];
    
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    Document *doc = [delegate topDocument];
    
    NSString *start = msgArray[1];
    
    if(didInitDisplayFormat == false && start){
        
        didInitDisplayFormat = true;  // once only
        
        if([start rangeOfString:@":"].location == NSNotFound){
            
            if(_delegate)[_delegate initDisplayFormat:DISPLAY_FMT_FT];
            
        }else{
            
            if(_delegate)[_delegate initDisplayFormat:DISPLAY_FMT_TC];
        }
        
    }
    
    
    switch(operand){
            
        case 0: // grabAll  FIXME: 2.00.00
            
            [doc addRow:msgArray[1] :msgArray[2] :msgArray[3]];
            [self txMsg:[NSString stringWithFormat:@"jxaRenameLastTrackFoley\t0\t%@\t%@",msgArray[3],msgArray[3]]];
            delegate.suggestedTrackName = msgArray[3];
            
            if(_yIndex != _lastYIndex)[self muteTrackForIndex:_lastYIndex :true];
            [self muteTrackForIndex:_yIndex :false];
            _mutedYIndex = _lastYIndex;
            
            [delegate setEditStart:msgArray[1]];
            
            break;
            
        case 1: // grabInOut
            
            // set start/end of current cue
            [doc setStartTc:msgArray[1]];
            [doc setEndTc:msgArray[2]];
            
            [delegate setEditStart:msgArray[1]];
            
            break;
            
        case 2: // mark inpoint TODO we think this means set start, end to edit start
            
            [doc setStartTc:msgArray[1]];
            [doc setEndTc:msgArray[1]];
            
            [delegate setEditStart:msgArray[1]];
            
            break;
            
        case 3: // add a streamer row to selected rows
            
            [doc addRowToSelection:msgArray[1] :msgArray[1] :@""];
            
            break;
            
        case 4: // program start, toggle display format so we have all digits
            
            
            //            // if edit start tc is greater than tc, use edit start tc
            //
            //            [delegate setEditStart:msgArray[1]];
            //
            //            if(_delegate)[_delegate grabAllTimeout];  // stop the spinner
            
            return;
            
    }
    
    [self txMsg:@"armLastTrackFoley"];
}
-(void)getTrackPos:(NSArray*)msgArray{
    
    // we get the track positions once and then send indexes to toggle mutes
    
    if(leftPaneClicked){
        
        leftPaneClicked = false;    // once only
        [self txMsg:@"getTrackPos"]; //NSLog(@"getTrackPos from getTrackPos");    // repeat until clicks stop
        return;
        
    }
    
    if(_delegate)[_delegate grabAllTimeout];  // stop the spinner
    
    if(!msgArray || (msgArray.count % 3) != 1) return;
    
    //    NSLog(@"%ld",msgArray.count);
    //    [self appendToLog:[NSString stringWithFormat:@"getTrackPos items returned: %ld",msgArray.count]];
    NSCharacterSet *charSet = [NSCharacterSet characterSetWithCharactersInString:@", "];
    
    NSString *currentTitle = nil;
    if(_delegate) currentTitle = [_delegate getTargetTrackTitle];
    
    [self setTrackPos:[[NSMutableArray alloc]init]];
    
    for(int i = 0; i < msgArray.count - 1; i += 3){
        
        NSString *pos = [msgArray[i + 0] stringByTrimmingCharactersInSet:charSet];
        NSArray *posArray = [pos componentsSeparatedByString:@","];
        
        NSString *size = [msgArray[i + 1] stringByTrimmingCharactersInSet:charSet];
        NSArray *sizeArray = [size componentsSeparatedByString:@","];
        
        NSString *title = [msgArray[i + 2] stringByTrimmingCharactersInSet:charSet];
        NSRange range = [title rangeOfString:@" audio track"];
        if(range.location != NSNotFound) title = [title substringToIndex:range.location];
        
        NSDictionary *dict = @{X_KEY:[posArray[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
                               ,Y_KEY:[posArray[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
                               ,W_KEY:[sizeArray[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
                               ,H_KEY:[sizeArray[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
                               ,TITLE_KEY:title};
        
        [_trackPos addObject:dict];
    }
    
   // NSLog(@"items in trackPos: %ld",_trackPos ? _trackPos.count : -1);
    
    if(currentTitle){
        _yIndex = -1;   // assume failure
        
        for(NSDictionary *dict in _trackPos){
            
            if([currentTitle isEqualToString:dict[TITLE_KEY]]){
                
                _yIndex = [_trackPos indexOfObject:dict];
                break;
                
            }
        }
        
        AleDelegate *delegate = (AleDelegate*)NSApp.delegate;
        
        if(_yIndex < 0){
            
            [delegate alertErr:@"track is hidden, select a target track" :@""]; //
            
        }
    }
    
}
//-(void)lastYPos:(NSArray*)msgArray{
//    
//    if(msgArray.count < 3) return;
//    
//    // every mouseUp in the Edit: window checks the yPos of the last track
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//    
//    if(delegate.isAleMini){
//        
//        NSString *yString = [msgArray[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//        NSString *hString = [msgArray[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//        
//        if(!_trackPos
//           || _trackPos.count == 0
//           || ![yString isEqualToString:[[_trackPos lastObject] objectForKey:Y_KEY]]
//           || ![hString isEqualToString:[[_trackPos lastObject] objectForKey:H_KEY]]){
//            
//            [self txMsg:@"getTrackPos"];
//            [delegate initGrabAllTimeout];  // show the spinner while we get the layout
//        }
//        
//    }
//}
-(void)leftPaneService{
    
    if(_delegate){
        
        if([_delegate getTrackPosIsInhibited]) return; // Foley mixer wants layout feature disabled at this time
        
        if([_delegate testGrabAllTimeout]){ // getTrackPos is in process, wait
            
            leftPaneClicked = true; // message to getTrackPos to repeat
            
        }else{
            
            [_delegate initGrabAllTimeout];
            [self txMsg:@"getTrackPos"]; //NSLog(@"getTrackPos from left pane click");// left pane click gets track layout
        }
        
    }
    
}
#define COLUMN_VISIBLE_CHECK 35.0
-(void)mouseUpCmd:(NSArray*)msgArray{
    
    // unsolicited mouse up info frome mouseServer
    if(msgArray == nil || [[msgArray class] isKindOfClass:[NSEvent class]] || msgArray.count < 4){
        
        [self appendToLog:[NSString stringWithFormat:@"mouseUp, not enough operands: %d",(int)msgArray.count]];
        return;
        
    }
    
    @try {
        
        
        NSString *theApp = msgArray[2];
        NSString *theWindow = msgArray[3];
        
        bool isEditWindow = false;
        bool isProtoolsApp = false;
        
        theWindow = [theWindow uppercaseString];
        // OSX 9.5 throws an exception for containsString:, must use rangeOfString:
        isEditWindow = [theWindow rangeOfString:@"EDIT"].location != NSNotFound;
        
        theApp = [theApp uppercaseString];
        // OSX 9.5 throws an exception for containsString:, must use rangeOfString:
        isProtoolsApp = [theApp rangeOfString:@"PRO TOOLS"].location != NSNotFound;
        
        if(isEditWindow && isProtoolsApp){
            
            if(_lastMouseUp && [_lastMouseUp timeIntervalSinceNow] > -.5){
                
                _yPos = _lastYPos;
                _xPos = _lastXPos;
                //                NSLog(@"restored yPos after double click: %@ %5.3f",_yPos,[_lastMouseUp timeIntervalSinceNow]);
                
            }else{
                
                [self setXPos:msgArray[0]]; //NSLog(@"yPos: %@",_yPos);   // capture yPos in Protools edit window only
                [self setYPos:msgArray[1]]; //NSLog(@"yPos: %@",_yPos);   // capture yPos in Protools edit window only
                
                if(_delegate && [_delegate getTrackPosIsInhibited]) return; // Foley mixer wants layout feature disabled at this time
                
                if(!_trackPos){
                    
                    if(_delegate && !leftPaneClicked){
                        
                        if([_delegate testGrabAllTimeout]){
                            
                            leftPaneClicked = true; // repeat
                            
                        }else{
                            
                            [_delegate initGrabAllTimeout];
                            [self txMsg:@"getTrackPos"]; //NSLog(@"getTrackPos from _trackPos == nil");// first mouse click gets track layout
                            
                        }
                    }
                }
                else{   // there are tracks
                    
                    // if click is in the left pane, assume a track was hidden/unhidden
                    
                    if([_xPos floatValue] < COLUMN_VISIBLE_CHECK){
                        
                        [self leftPaneService];
                        
                    }else{
                        
                        NSInteger index = [self getIndexForYPos:msgArray[1]];
                        
                        if(index > 0){
                            
                            [self txMsg:[NSString stringWithFormat:@"yIndex\t%ld",index]];    // check track layout each mouse up
                            
                        }
                        
                    }
                    
                }
            }
            
            [self setLastMouseUp:[NSDate date]];
            
        }
        
    }
    @catch (NSException *exception) {
        
        NSLog(@"mouseUp exception");
        
    }
    
}

-(void)midiStop:(NSArray*)msgArray{
    
    //    NSLog(@"midiStop");
    
    // we put this on the queue so that it comes after any pending play commands
    // this lets the fast double push of cycle do the right thing
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    [delegate onMidiStop];
}
-(void)wildSyncSelect:(NSArray*)msgArray{
    
    // locate to start of cue
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    Document *doc = [delegate topDocument];
    [doc locateToCurrentCue];   // put ourselves back in position
    // call 2nd script to do many downs, one up, paste
    [self txMsg:@"wildSyncSelect2"];
}
//-(void)zeroFeetAtTc:(NSArray*)msgArray{
//    "wild
//    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
//    
////    [delegate setTimeCodeStart:[msgArray objectAtIndex:0]];
//    
//    [delegate toggleToFt];
//    Document *doc = [delegate topDocument];
//    [doc locateToCurrentCue];   // put ourselves back in position
//
//}
-(void)mainCounterFormat:(NSArray*)msgArray{
    
    // resize the cue sheet (must be after MIDI display format has arrived)
    //sizeTableViewToContents
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    Document *doc = [delegate topDocument];
    [doc sizeTableViewToContents];
}
//-(void)locateZeroFeet:(NSArray*)msgArray{
//
//    // we are here because timeCodeStart is nil and needed to be refreshed
//    // 0: the format we will be in next
//    // 1: timeCodeStart
//    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
//    
////    [delegate setTimeCodeStart:[msgArray objectAtIndex:1]];
//
//    NSInteger displayFormat = [[msgArray objectAtIndex:0] integerValue];
//    
//    Document *doc = [delegate topDocument];
//    [doc setTimeCodeStart:[msgArray objectAtIndex: 1]];
//    [doc calcTableContentsForNewTcStart: displayFormat];   // adjust tableContents when a new start arrives
//    [doc locateToCurrentCue];
//    if(displayFormat == DISPLAY_FMT_FT)[delegate toggleToFt];
//    else [delegate toggleToTc];
//    
//    
//}
-(void)zeroFeet:(NSArray*)msgArray{
    
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    [delegate toggleToFt];  // setting to zero feet puts protools in feet
    
}
//-(void)keyCode:(NSArray*)msgArray{
//    // we have to wait for the entry register to stop blinking before capturing the tc start (STORE function)
//    
////    if(msgArray.count > 0 && [[msgArray objectAtIndex:0] isEqualToString:@"76"]){
////        
////        AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
////        [delegate finalizePositionEntry];
////        
////    }
//}
-(void)getPreEdit:(NSArray*)msgArray{
    
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    NSInteger trimFrames = [[msgArray objectAtIndex:0] integerValue];
    
    //    [delegate.matrixWindowController setTrimFrames:-abs((int)trimFrames)];
    [delegate.matrixWindowController setTrimFrames:trimFrames];   // V1.00.22, signed value for Evan
    
}
-(void)copyClipToIndex:(NSArray*)msgArray{
    
    // update the cue start to the current counter position
    
    
    AleDelegate *delegate = [NSApp delegate];
    delegate.overlayWindowController.viewController.streamer.hidePix = false;
    //    [delegate setHidePix:false];
    //    [delegate fireBlackService:.3]; // move the black timer along
    //    [delegate.streamerWindowController txMsg: @"midi 90 6c 0"];  // streamer black off
    
    
}
-(void)jxaCopyClipToComp:(NSArray*)msgArray{
    [self txMsg:@"videoOnline 1"];
    AleDelegate *delegate = [NSApp delegate];
    [delegate setCurrentTrack:delegate.lastTrack];
    [delegate selectCurrentSixteenTrackMemory];

}
-(void)copyClipToComp:(NSArray*)msgArray{
    
//    NSLog(@"copyClipToComp items in msgArray: %ld",msgArray.count);
    @try {
        
        AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
        [delegate selectLastSixteenTrackMemory];    // show what we recorded
        
        NSInteger status = [[msgArray objectAtIndex:0] integerValue];
        
        if(status < 0) [self txMsg:@"showAlert\ttrack did not copy, is it empty?"];
        
    }
    @catch (NSException *exception) {
        
    }

}
-(void)getProtoolsPosition:(NSArray*)msgArray{
    
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    Document *doc = [delegate topDocument];
    
    if(msgArray.count > 2) {    // getProtoolsPosition 1 01:06:57:13 1.350 (note the command has been removed from msgArray)
        
        NSString *tc = [[msgArray objectAtIndex:msgArray.count - 2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        // if the string contains a '+' we are in ft/fr
        
        if([tc rangeOfString:@"+"].location != NSNotFound) {
            
            [doc setTableContentsDisplayFormat:DISPLAY_FMT_FT];
            
        }else{
            [doc setTableContentsDisplayFormat:DISPLAY_FMT_TC];
            
        }
        
        [doc setCtr:tc];
        
        switch ([[msgArray objectAtIndex:0] integerValue]) {
            case 0: // 'store' command
                [doc setStartTc:tc];
                break;
            case 1: // add a new cue at the current position
                
                [doc onAddRow:nil];
                break;
                
            case 2: // continue cycle
                [delegate cycleStart];
                break;
                
            case 3: // continue recordOffService
                
                [delegate.matrixWindowController didCueToTrimFrames];
                break;
                
            case 4:     // continue preroll to here
                [delegate calcPrerollToHere:tc];
                break;
                
            case 5: // continue copyClipToComp
                [self txMsg:@"jxaCopyClipToComp"];  // option tab, shift tab, ctrl-c, ';', ctrl-v
                break;
                
            case 6: // continue quick preview
                [delegate.ptHui onPlay];
                break;
                
            case 7: // capture out time
                /*
                 Document *doc = [self topDocument];
                 if(doc == nil){return;}
                 
                 [doc setEndTc:_matrixWindowController.mtcString ForDictionary:doc.recordCycleDictionary];

                 */
                
                if(doc.recordCycleDictionary){
                    
                    doc.recordCycleDictionary[@"End"] = tc; // works for ft/fr
                    [doc sizeTableViewToContents];  // the first time we capture an out, col may be narrow
                    
                }
                
                
                break;
                
            case 8: // streamer 1
                [delegate txOsc:@"led 8,41,true"];
                [doc.recordCycleDictionary setObject:tc forKey:@"streamer1"];
                break;
            case 9: // streamer 2
                [delegate txOsc:@"led 8,49,true"];
                [doc.recordCycleDictionary setObject:tc forKey:@"streamer2"];
                break;
            case 10:    // streamer 3
                [delegate txOsc:@"led 8,57,true"];
                [doc.recordCycleDictionary setObject:tc forKey:@"streamer3"];
                break;
            case 11:    // streamer 4
                [delegate txOsc:@"led 8,42,true"];
                [doc.recordCycleDictionary setObject:tc forKey:@"streamer4"];
                break;
            case 12:    // streamer 5
                [delegate txOsc:@"led 8,50,true"];
                [doc.recordCycleDictionary setObject:tc forKey:@"streamer5"];
                break;
            case 13:    // streamer 6
                [delegate txOsc:@"led 8,58,true"];
                [doc.recordCycleDictionary setObject:tc forKey:@"streamer6"];
                break;
                
            default:    // no post action
                break;
        }
    }
    
}
-(void)getSampleRate:(NSArray*)msgArray{
    
    // checking TotalMix sample rate
    if(msgArray.count < 1){return;}
    
    NSString *rate = [msgArray objectAtIndex:0];
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];

    if(([rate rangeOfString:@"192"].location == 0 || 
        [rate rangeOfString:@"176"].location == 0) && delegate.matrixWindowController.sampleRateTag != 2){
        
        delegate.matrixWindowController.sampleRateTag = 2;
        
    }
    else if(([rate rangeOfString:@"96"].location == 0 || 
             [rate rangeOfString:@"88"].location == 0) && delegate.matrixWindowController.sampleRateTag != 1){
        
        delegate.matrixWindowController.sampleRateTag = 1;
        
    }
    if(([rate rangeOfString:@"48"].location == 0 || 
        [rate rangeOfString:@"44"].location == 0) && delegate.matrixWindowController.sampleRateTag != 0){
        
        delegate.matrixWindowController.sampleRateTag = 0;
        
    }
}
-(void)getSession:(NSArray*)msgArray{
    
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
//    Document *doc = [delegate topDocument];
    
//    NSLog(@"getSession");
    if(msgArray.count < 1 || [[msgArray objectAtIndex:0]isEqualToString:@"-1"]){
        return;
    }
    
    delegate.session = [msgArray objectAtIndex:0];    // loads the log when session changes
    // 2.10.02 jxaGetSession gets the sample rate
    
    if(msgArray.count > 2){
        
        if([msgArray[1] containsString:@"192"] || [msgArray[1] containsString:@"176"]){
            
            delegate.matrixWindowController.sampleRateTag = 2;
            
        }else if([msgArray[1] containsString:@"96"] || [msgArray[1] containsString:@"88"]){
            
            delegate.matrixWindowController.sampleRateTag = 1;
        }else{
            
            delegate.matrixWindowController.sampleRateTag = 0;
        }
        
        
    }
}
-(void)renameLastTrack:(NSArray*)msgArray{
    
    // renameLastTrack	nada 	0	nada2	 2.085
    // 0 switch
    // 1 old name if no error, name that failed if error
    // 2 t
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    
    NSString *msg = [NSString stringWithFormat:@"Can't rename last track to '%@'",msgArray[1]];
//    NSAlert *alert =  [[NSAlert alloc] init];
//    alert.messageText = msg;


    switch( [msgArray[0] integerValue]){
        case -1:
            // TODO: 2.00.00 error
            [delegate  alertErr:msg :@""];
            break;
        case 0:
            // normal naming
            break;
//        case 1:
//            // track format has changed, continue
//            [delegate.matrixWindowController continueNumRecTracksRename];
//            break;
        default:
            break;
    }
    
}
-(void)armLastTrack:(NSArray*)msgArray{
    
    // [0] status
    // [1] session
    // [2] track name
    // [3] script execution time
    
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    Document *doc = [delegate topDocument];
    
    // handle grab all timeout
    if(_delegate)[_delegate grabAllTimeout];  // TODO: 2.00.00 what is this
    
    if(msgArray.count < 4 || (msgArray.count > 0 && [msgArray[0] integerValue] < 0))
    {
        delegate.cycleMotion = CYCLE_MOTION_IDLE;
        
        [delegate alertErr:@"can't arm last track" :@""];

        [delegate setLastCueID: nil];   // must rename track, select tracks
        return;
    }
    
    NSString *trackName = @"";
    
    trackName = msgArray[2];
    NSRange range = [trackName rangeOfString:@" - Audio Track"];    // 1.00.17 PT later version has this
    
    if(range.location != NSNotFound){
        trackName = [trackName substringToIndex:range.location];
    }

    if(![trackName isEqualToString:[delegate suggestedTrackName]] && [[delegate suggestedTrackName] length]){
        
        NSString *msg =[NSString stringWithFormat:@"track is named %@, expected %@, do record cycle again. Do you have the right monitor format?",trackName,[delegate suggestedTrackName]];
        
        delegate.suggestedTrackName = @"";
        [delegate setCycleMotion:CYCLE_MOTION_IDLE];
        
        [delegate alertErr:msg :@""];

        [delegate setLastCueID: nil];   // must rename track, select tracks
        return;
        
    }
    
    [delegate setSession:[msgArray objectAtIndex:1]];    // loads the log when session changes
    
    [delegate incrementRecordTake];
    [doc sendTakeToStreamerForDictionary];
    
    delegate.cycleMode = CYCLE_MODE_RECORD;
    [delegate.ptHui onRecord];
    [delegate.ptHui onPlay];

}
-(void)addCue:(NSArray *)msgArray{
    
    if(msgArray.count == 0){
        return; // error
    }
 
    if(msgArray.count >= 2){
        AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
        Document *doc = [delegate topDocument];
        [doc addCueWithDialogAndStart:msgArray[0] :msgArray[1]];
    }

}
-(void)setDialog:(NSArray *)msgArray{
    
    if(msgArray.count == 0 || [msgArray[0] isEqualToString:@"error"]){
        return; // error
    }

    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    Document *doc = [delegate topDocument];
    [doc setDialog:msgArray[0]];
    
}

-(void)setCueName:(NSArray *)msgArray{
    
    if(msgArray.count >= 3)    // new name, old name, current position
    {
        
        AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
        Document *doc = [delegate topDocument];
        // from setCueName script- return tab & newCue & tab & currentCue & tab & pos & tab
        [doc locateOrAddCue:[msgArray objectAtIndex:0] :[msgArray objectAtIndex:1]];    //2.00.00 why was it objectAtIndex:1?
   }
    
}
-(void)setNote:(NSArray *)msgArray{
    
    if(msgArray.count == 0 || [msgArray[0] isEqualToString:@"error"]){
        return; // error
    }

    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    Document *doc = [delegate topDocument];
   
    NSString *item = [msgArray objectAtIndex:0];
    [doc setCueNote:item];

}

-(void)cutAndPaste:(NSArray *)msgArray{
    
//    NSLog(@"cutAndPaste callback, msgArray count: %ld",msgArray.count);
    
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    Document *doc = delegate.topDocument;
    if(doc == nil || doc.recordCycleDictionary == nil){return;}
//    [delegate setCutAndPasteIsActive:false]; // locks out play/stop while we are cutting and pasting
    
//    if(msgArray.count != 4) return; // bad number of operands, tracking down extra call

    @autoreleasepool {
        
        
        // split the last item in msgArray, take is next to last
        @try {
            NSString *take = [msgArray objectAtIndex:msgArray.count - 2]; // actually file name like 'Group_AQ 109 1_05-01'
            NSArray *array = [take componentsSeparatedByString:@"_"];
            take = [array objectAtIndex:array.count - 1];
            array = [take componentsSeparatedByString:@"-"];
            take = [array objectAtIndex:0];
            // TODO check for out of sequence take numbers, put up a dialog maybe
            NSNumberFormatter* numberFormatter = [[NSNumberFormatter alloc] init];
            
            NSNumber* number = [numberFormatter numberFromString:take];
            
            if(number && [number integerValue]){
                
                [doc.recordCycleDictionary setObject:[NSString stringWithFormat:@"%ld",[number integerValue]] forKey:@"Take"];
                [doc.tableView reloadData];
            }
        }
        @catch (NSException *exception) {
        }
        
//        [delegate selectCurrentSixteenTrackMemory]; // maybe show 16 tracks during the pass
        [self txMsg:@"videoOnline 1"];

        // TODO: 2.00.00 from AleDoc finalizeRecord:, there may be more
        delegate.lastRecordTrack = delegate.currentTrack;
        [delegate selectLastSixteenTrackMemory];    // show what we recorded
        [delegate incrementRecordTrack]; // incr the track after showing
        [delegate.topDocument saveToLog]; // save to log after the track increment

        delegate.cycleMode = CYCLE_MODE_IDLE;       // CYCLE_MODE_FINALIZE_RECORD is finished
        NSLog(@"CYCLE_MODE_FINALIZE_RECORD->CYCLE_MODE_IDLE");
    }
}
-(void)getProtoolsInfo:(NSArray *)msgArray{
    
    if(msgArray.count < 4) return;
    
    NSString *start = [msgArray objectAtIndex:0];
    NSString *end = [msgArray objectAtIndex:2];
    
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    Document *doc = [delegate topDocument];
    
    if(![doc existsRowWithStart:start] || _forceAddCue){
        
        [doc addRow:start :end :@"add dialog here"];
//        [doc addCueToDoc:[NSString stringWithFormat:@"cue_%ld",doc.cueCtr++] start:start end:end];
    }
    _forceAddCue = false;
    
//    [delegate sendMidiEventList:start :end];
    [delegate locate:start];   // we have to send MIDI notes, then start/end (leave this alone!)
}
-(void)getTransportOut:(NSArray *)msgArray{
    
    NSString *end = [msgArray objectAtIndex:0];
    // set the out
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    Document *doc = [delegate topDocument];
    if(doc){
        [doc setEndTc:end];
    }

}

-(void)ping:(NSArray*)msgArray{
    
}

-(void)rxMsg:(NSString*)msg sender:sender{
    
    NSCharacterSet *trimSet = [NSCharacterSet characterSetWithCharactersInString:@">\r\n"];
    msg = [msg stringByTrimmingCharactersInSet:trimSet];
    
//    NSLog(@"rxMsg %@",msg);
    
    if(msg.length == 0) return;
    
    // getProtoolsInfo 01:00:39:15, 01:00:39:15
    // get the command (separated by first blank
    
    if([msg rangeOfString:@"getTrackPos"].location == 0){
        // special case, parse here (we wanted to not do string stuff in AppleScript so that it was faster)
        [self appendToLog:msg];
        NSMutableArray *array = [NSMutableArray arrayWithArray:[ msg componentsSeparatedByString:@"\t"]];
        [array removeObjectAtIndex:0];
        [self getTrackPos:(NSArray*)array];
        
        return;
    }
    
    NSRange range = [msg rangeOfString:@"\t"];
    NSArray *array;
    NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@" ,"];
    if(range.location != NSNotFound) set = [NSCharacterSet characterSetWithCharactersInString:@"\t"];
    
    array = [msg componentsSeparatedByCharactersInSet:set];
    NSString *cmdString = [[array objectAtIndex:0] stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSMutableArray *msgArray = [[NSMutableArray alloc] initWithArray:array];
    [msgArray removeObjectAtIndex:0];
    
    // command table, borrowed from RemoteCurrency
    @try {
        
        SEL cmd = NSSelectorFromString([_cmdDictionary objectForKey:cmdString]);
        if(cmd != nil && [self respondsToSelector:cmd]){
            
            // http://stackoverflow.com/questions/7017281/performselector-may-cause-a-leak-because-its-selector-is-unknown
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self performSelector:cmd withObject:msgArray];
#pragma clang diagnostic pop
        }
        
    }
    @catch (NSException *exception) {
        
    }
    
    [self appendToLog:msg];
    
}
NSArray *hidePing = @[@"jxaGetSampleRate"
                      ,@"pingProTools"];

-(void)appendToLog:(NSString*)msg{
    
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"hidePing"] == true){
        for(NSString *str in hidePing){
            if([msg rangeOfString:str].location != NSNotFound){
                return;
            }
        }
    }
    
    if(_showTimeOfDay){
        
        NSDate *now = [NSDate date];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
        [dateFormatter setDateStyle:NSDateFormatterNoStyle];
        
        NSString *t = [dateFormatter stringFromDate:now];
        NSArray *array = [t componentsSeparatedByString:@" "];
        
        NSTimeInterval timeInterval = [NSDate timeIntervalSinceReferenceDate];
        timeInterval *= 1000;
        NSInteger millisecs = (NSInteger)timeInterval % 1000;
        
        msg = [array[0] stringByAppendingString:[NSString stringWithFormat:@".%03ld %@",millisecs,msg]];
    }
    
    NSTextStorage * sto = [_rxTextView textStorage];
    NSAttributedString *ats = [[NSAttributedString alloc] initWithString:[msg stringByAppendingString:@"\n"]];
    [sto appendAttributedString:ats];
    // scroll to end of document
    [_rxTextView scrollToEndOfDocument:nil];
    
}

-(void)txMsg:(NSString *)msg{
    
//    NSLog(@"txMsg: %@",msg);
    
//    if([msg rangeOfString:@"mem 0"].location == 0){
//        NSLog(@"mem 0");
//    }
    
    if(_showTimeOfDay){
        // v1.00.18 show tx in log, Evan is debugging a 3 second delay
                [self appendToLog:[NSString stringWithFormat:@"txMsg: %@",msg]];

    }
    
    [_adrClient addToInArray:msg];
    
//    if(_connection){
//    [_connection txMsg: msg];
//    }else{
//
//        NSMutableArray *array = [[NSMutableArray alloc]initWithObjects:msg, nil];
//        [self processMsgArray:array :nil];  // loop back if there is no connection (to work without adrServer running)
//    }
}

- (IBAction)onClearRxText:(id)sender {
    
    [_rxTextView selectAll:sender];
    [_rxTextView delete:sender];
}

//#pragma mark -
//#pragma mark -------------- TcpClientBrowserDelegate methods ----------------------
//-(void)addService:(NSNetService*)service{
//    
//    NSLog(@"AdrClientWindowController addService");
//    
//}
//-(void)removeService:(NSNetService*)service{
//    
//    NSLog(@"AdrClientWindowController removeService");
//    
//}
#pragma mark -
#pragma mark --------------- TcpClientConnectionDelegate methods ----------------
//
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
//
//        }
//    }
//
//}
//
//- (void)connectionDidResolveAddress:(TcpClientConnection *)sender{
//
//    bool isAleMini = false;
//
//    if(_delegate) isAleMini = [_delegate isAleMini];
//    else{
//
//        id delegate = [NSApp delegate];
//        if(delegate && [delegate respondsToSelector:@selector(isAleMini)]){
//            isAleMini = [delegate isAleMini];
//        }
//    }
//
//    [sender txMsg:[NSString stringWithFormat:@"mouseUp %d",isAleMini]]; // AleDoc leaves mouseUp turned off
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
//    }
//
//}
//-(void) processMsgArray:(NSMutableArray *)msgArray :(id)connection{
//
////    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
////    if([delegate isAleMini]) return;    // quick and dirty, do nothing for AleMini
//
//    for(NSString *msg in msgArray){
//
//        [self rxMsg:msg sender:connection];
//    }
//
//}


@end
