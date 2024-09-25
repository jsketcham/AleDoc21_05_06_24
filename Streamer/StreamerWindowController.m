//
//  StreamerWindowController.m
//  AleDoc21
//
//  Created by Pro Tools on 8/31/23.
//  we had to replace the XIB to get 'bring window to front' to work

#import "StreamerWindowController.h"
#import "AleDelegate.h"
#import "MatrixWindowController.h"
#import "EditorWindowController.h"
#import "Document.h"
#import "ColorSupport.h"

#import "TcCalculator.h"
#import "TCFormatter.h"

#import "AleDoc21-Swift.h"    // must be here to avoid a circular reference

@interface StreamerWindowController ()

@property AleDelegate* aleDelegate;
@property TcCalculator *tcc;
@property TCFormatter *tcf;
@property NSArray *punchList;
@property NSString *punchListItem;
// masking
@property NSInteger topMask;
@property NSInteger bottomMask;
@property NSInteger leftMask;
@property NSInteger rightMask;
@property NSInteger transparencyMask;

@property NSColor *punchColor;
@property NSColor *endBarColor;
@property NSArray *pictureModeList;
@property NSString *pictureMode;

@end

@implementation StreamerWindowController

// local vars
@synthesize aleDelegate = _aleDelegate;
@synthesize pictureTag = _pictureTag;
@synthesize streamerColor = _streamerColor;
@synthesize streamerEnable = _streamerEnable;
@synthesize punchEnable = _punchEnable;
@synthesize beepsEnable = _beepsEnable;
@synthesize inhibitStreamerInPlayback = _inhibitStreamerInPlayback;
@synthesize tcc = _tcc;
@synthesize tcf = _tcf;
@synthesize punchList = _punchList;
@synthesize punchListItem = _punchListItem;
@synthesize topMask = _topMask;
@synthesize bottomMask = _bottomMask;
@synthesize leftMask = _leftMask;
@synthesize rightMask = _rightMask;
@synthesize transparencyMask = _transparencyMask;
@synthesize punchColor = _punchColor;
@synthesize endBarColor = _endBarColor;

@synthesize pictureModeList = _pictureModeList;
@synthesize pictureMode = _pictureMode;

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    NSDictionary *registrationDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [[NSNumber alloc]initWithBool:true],@"inhibitStreamerInPlayback",
                                          [[NSNumber alloc]initWithBool:true],@"enStreamer",
                                          [[NSNumber alloc]initWithBool:true],@"enPunch",
                                          [[NSNumber alloc]initWithBool:true],@"enBeeps",
                                          [[NSNumber alloc]initWithDouble:1.0],@"fadeSeconds",
                                          @"Always On",@"pictureMode",
                                          nil];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:registrationDefaults];

    self.aleDelegate = (AleDelegate*)NSApp.delegate;
    
    self.tcc = [[TcCalculator alloc]init];
    self.tcf = [[TCFormatter alloc]init];

    NSInteger punchIndex = _aleDelegate.overlayWindowController.viewController.streamer.punchIndex;
    
    // trigger bindings
    self.punchList = _aleDelegate.overlayWindowController.viewController.streamer.punchList;
    self.punchListItem = [_punchList objectAtIndex:punchIndex];
    self.topMask = _aleDelegate.overlayWindowController.viewController.streamer.topMask;
    self.bottomMask = _aleDelegate.overlayWindowController.viewController.streamer.bottomMask;
    self.rightMask = _aleDelegate.overlayWindowController.viewController.streamer.rightMask;
    self.leftMask = _aleDelegate.overlayWindowController.viewController.streamer.leftMask;
    self.transparencyMask = _aleDelegate.overlayWindowController.viewController.streamer.transparency;
    
    self.pictureModeList = @[@"Always On",@"Fade In",@"Blk/Cue/Blk"];
    self.pictureMode = self.pictureMode;
}
// MARK: ------ actions ----------
- (IBAction)onTextNextScreen:(id)sender {
    [_aleDelegate nextScreen];
}

- (IBAction)onStreamer0:(id)sender {
    [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:self.streamerColor];
}

// MARK: ------ streamer trigger ----------

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
}

-(void)triggerStreamer:(NSString*)tc{
    
    // we are on the main thread
    // this is called for every tc frame
    // we are not stopped
    // set snoop from PT motion if snoopAuto is on
    // 12/6/23 was latching if snoopAuto is turned off
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
        
    bool enBeeps = [[NSUserDefaults standardUserDefaults]boolForKey:@"enBeeps"];

    // trigger streamers 1-6
    
    NSString *streamer1 = [_tcf tcForString:[doc.recordCycleDictionary objectForKey:@"streamer1"]];
    NSString *streamer2 = [_tcf tcForString:[doc.recordCycleDictionary objectForKey:@"streamer2"]];
    NSString *streamer3 = [_tcf tcForString:[doc.recordCycleDictionary objectForKey:@"streamer3"]];
    NSString *streamer4 = [_tcf tcForString:[doc.recordCycleDictionary objectForKey:@"streamer4"]];
    NSString *streamer5 = [_tcf tcForString:[doc.recordCycleDictionary objectForKey:@"streamer5"]];
    NSString *streamer6 = [_tcf tcForString:[doc.recordCycleDictionary objectForKey:@"streamer6"]];
    
    // ignore the hours for triggering
    // TODO: there is no beeps trim on these
    
    if(streamer1 && [_tcc compareTc:streamer1 fromTc:tc withType:tcType] == NSOrderedSame){
        [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:useAnnunciatorColor ? annunciatorColor : [ed colorStreamer1] : enBeeps];
    }
    else if(streamer2 && [_tcc compareTc:streamer2 fromTc:tc withType:tcType] == NSOrderedSame){
        [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:useAnnunciatorColor ? annunciatorColor : [ed colorStreamer2] : enBeeps];
    }
    else if(streamer3 && [_tcc compareTc:streamer3 fromTc:tc withType:tcType] == NSOrderedSame){
        [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:useAnnunciatorColor ? annunciatorColor : [ed colorStreamer3] : enBeeps];
    }
    else if(streamer4 && [_tcc compareTc:streamer4 fromTc:tc withType:tcType] == NSOrderedSame){
        [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:useAnnunciatorColor ? annunciatorColor : [ed colorStreamer4] : enBeeps];
    }
    else if(streamer5 && [_tcc compareTc:streamer5 fromTc:tc withType:tcType] == NSOrderedSame){
        [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:useAnnunciatorColor ? annunciatorColor : [ed colorStreamer5] : enBeeps];
    }
    else if(streamer6 && [_tcc compareTc:streamer6 fromTc:tc withType:tcType] == NSOrderedSame){
        [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:useAnnunciatorColor ? annunciatorColor : [ed colorStreamer6] : enBeeps];
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
        [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:color :enBeeps]; return; // 2.00.00
    }
    
    NSArray *array = [doc selectedContents];    //
    
    if(array.count == 0) return;    // nothing to test
    
    if(behaviorIndex == BEHAVIOR_INDEX_SINGLE_STREAMER){
        
        return; // triggered on
        
    }

    for (NSMutableDictionary *dict in array){
        
        NSString *start = [_tcf tcForString:[doc startForDictionary:dict]];
        
        if([_tcc compareTc:start fromTc:tc withType:tcType] == NSOrderedSame){
            
//            // FIXME: logic for annunciator fadeout is blocked
//
//            _aleDelegate.overlayWindowController.viewController.annunciatorTextView.fadeDuration = 1.0;
//            _aleDelegate.overlayWindowController.viewController.annunciatorTextView.opacity = 0.0;
            // 2.10.00 streamer can follow annunciator color
            bool useAnnunciatorColor = [[NSUserDefaults standardUserDefaults] boolForKey:@"useAnnunciatorColor"];
            NSColor *annunciatorColor = delegate.overlayWindowController.viewController.annunciatorTextView.textColor;

            [_aleDelegate.overlayWindowController.viewController.streamer triggerStreamer:useAnnunciatorColor ? annunciatorColor : self.streamerColor :enBeeps]; 
            
            return; // 2.00.00

        }
    }
}
// MARK: ------ setters/getters ----------
-(void)setPictureMode:(NSString *)pictureMode{
    
    _pictureMode = pictureMode;
    [[NSUserDefaults standardUserDefaults]setObject:pictureMode forKey:@"pictureMode"];
    
    NSInteger pictureTag = [_pictureModeList indexOfObject:_pictureMode];
    
    [_aleDelegate setLEDForUnitID:9 :70 :pictureTag == TAG_ALWAYS_ON];
    [_aleDelegate setLEDForUnitID:9 :71 :pictureTag == TAG_FADE_IN];
    [_aleDelegate setLEDForUnitID:9 :72 :pictureTag == TAG_BLACK_CUE_BLACK];
}
-(NSString*)pictureMode{
    
    return [[NSUserDefaults standardUserDefaults]objectForKey:@"pictureMode"];
}
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
    
    if(pictureTag < _pictureModeList.count){
        self.pictureMode = [_pictureModeList objectAtIndex:pictureTag];
    }
//    _pictureTag = pictureTag;
//    [[NSUserDefaults standardUserDefaults]setInteger:pictureTag forKey:@"pictureTag"];
//    
//    NSLog(@"pictureTag %ld",pictureTag);
//    [_aleDelegate setLEDForUnitID:9 :70 :self.pictureTag == TAG_ALWAYS_ON];
//    [_aleDelegate setLEDForUnitID:9 :71 :self.pictureTag == TAG_FADE_IN];
//    [_aleDelegate setLEDForUnitID:9 :72 :self.pictureTag == TAG_BLACK_CUE_BLACK];

}
-(NSInteger)pictureTag{
    
    return [_pictureModeList indexOfObject:_pictureMode];
//    return [[NSUserDefaults standardUserDefaults]integerForKey:@"pictureTag"];
}
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

@end
