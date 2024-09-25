//
//  EditorWindowController.m
//  WindowController
//
//  Created by ADR2 Utility on 10/27/14.
//  Copyright (c) 2014 ADR2 Utility. All rights reserved.
//

#import "EditorWindowController.h"
#import "AleDelegate.h"
#import "Document.h"
#import "EditorTextField.h"
#import "TcCalculator.h"
#import "TCFormatter.h"

@interface EditorWindowController ()

@property TcCalculator *tcc;
@property TCFormatter *tcf;
//@property (weak) IBOutlet DragDropImageView *dragDropImageView;
@property (strong) IBOutlet NSTextField *session;
@property (strong) IBOutlet NSTextField *cueSheet;

// references to the various fields
@property (weak) IBOutlet EditorTextField *cueID;
@property (weak) IBOutlet EditorTextField *start;
@property (weak) IBOutlet EditorTextField *end;
@property (weak) IBOutlet EditorTextField *dialog;
@property (weak) IBOutlet EditorTextField *notes;
@property (weak) IBOutlet EditorTextField *actor;
@property (weak) IBOutlet NSTextField *take;
@property (weak) IBOutlet NSTextField *track;

@property (strong) IBOutlet AleDelegate *aleDelegate;
@property (weak) IBOutlet NSButton *dialogInClipNameCheck;
//@property (weak) IBOutlet NSButton *actorInFileNameCheck;
@property (strong) IBOutlet NSTextField *beepsTrimFrames;
@property (weak) IBOutlet NSTextField *streamer1;
@property (weak) IBOutlet NSTextField *streamer2;
@property (weak) IBOutlet NSTextField *streamer3;
@property (weak) IBOutlet NSTextField *streamer4;
@property (weak) IBOutlet NSTextField *streamer5;
@property (weak) IBOutlet NSTextField *streamer6;
@property (weak) IBOutlet EditorTextField *mixerNotes;
@property (weak) IBOutlet EditorTextField *prerollTextField;
//@property (weak) IBOutlet EditorTextField *prerollToHereTextField;
@property (weak) IBOutlet NSTextField *recTracks;
//@property (strong) IBOutlet ColorPopupButton *colorStreamer0;
//@property (strong) IBOutlet ColorPopupButton *colorStreamer1;
//@property (strong) IBOutlet ColorPopupButton *colorStreamer2;
//@property (strong) IBOutlet ColorPopupButton *colorStreamer3;
//@property (strong) IBOutlet ColorPopupButton *colorStreamer4;
//@property (strong) IBOutlet ColorPopupButton *colorStreamer5;
//@property (strong) IBOutlet ColorPopupButton *colorStreamer6;
//@property (strong) IBOutlet NSColorWell *colorWell0;
//@property (strong) IBOutlet NSColorWell *colorWell1;
//@property (strong) IBOutlet NSColorWell *colorWell2;
//@property (strong) IBOutlet NSColorWell *colorWell3;
//@property (strong) IBOutlet NSColorWell *colorWell4;
//@property (strong) IBOutlet NSColorWell *colorWell5;
//@property (strong) IBOutlet NSColorWell *colorWell6;

@property NSColor *fooColor;
@property NSColor *barColor;
@property (strong) IBOutlet NSColorWell *fooColorWell;
@property (strong) IBOutlet NSColorWell *barColorWell;


@end

@implementation EditorWindowController

//NSString *kPrivateDragUTI = @"com.endpoint.cocoadraganddrop";   // FIXME will be redundant when we copy file

//@synthesize dragDropImageView = _dragDropImageView;
@synthesize cueID = _cueID;
@synthesize start = _start;
@synthesize end = _end;
@synthesize notes = _notes;
//@synthesize indexStreamer0 = _indexStreamer0;
//@synthesize indexStreamer1 = _indexStreamer1;
//@synthesize indexStreamer2 = _indexStreamer2;
//@synthesize indexStreamer3 = _indexStreamer3;
//@synthesize indexStreamer4 = _indexStreamer4;
//@synthesize indexStreamer5 = _indexStreamer5;
//@synthesize indexStreamer6 = _indexStreamer6;
@synthesize nameNote = _nameNote;
@synthesize preroll = _preroll;
//@synthesize prerollToHere = _prerollToHere;
//@synthesize colorStreamer0 = _colorStreamer0;
@synthesize colorStreamer1 = _colorStreamer1;
@synthesize colorStreamer2 = _colorStreamer2;
@synthesize colorStreamer3 = _colorStreamer3;
@synthesize colorStreamer4 = _colorStreamer4;
@synthesize colorStreamer5 = _colorStreamer5;
@synthesize colorStreamer6 = _colorStreamer6;


//@synthesize lastTake = _lastTake;
//@synthesize rowDictionary = _rowDictionary;
//@synthesize selectedTrack = _selectedTrack;

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        _tcc = [[TcCalculator alloc]init];
        _tcf = [[TCFormatter alloc]init];
        
//        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
//        NSDictionary *registrationDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
//                                              @"04:00:00:00",@"preroll",    // TODO: 2.00.00 does this go away?
//                                              [NSNumber numberWithInt:0],@"prerollIndex",   // 2.00.00
////                                              [NSNumber numberWithInt:DISPLAY_FMT_TC],@"displayFormat",
//                                              nil];
//
//        [defaults registerDefaults:registrationDefaults];
        
        if(!_aleDelegate){
            
            [self setAleDelegate:(AleDelegate*)[NSApp delegate]];
        }
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
   
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(windowClosing:)
     name:NSWindowWillCloseNotification
     object:nil ];
    
//    [[_start cell] setFormatter:[[TCFormatter alloc]init]];
//    [[_end cell] setFormatter:[[TCFormatter alloc]init]];
//    
////    [[_preroll cell] setFormatter:[[TCFormatter alloc]initAsPreroll]];
//    [[_preroll cell] setFormatter:[[TCFormatter alloc]init]];
//    [[_prerollToHere cell] setFormatter:[[TCFormatter alloc]init]]; // hours matter for this 'preroll', it is a marker
//
//    [[_streamer1 cell] setFormatter:[[TCFormatter alloc]init]];
//    [[_streamer2 cell] setFormatter:[[TCFormatter alloc]init]];
//    [[_streamer3 cell] setFormatter:[[TCFormatter alloc]init]];
//    [[_streamer4 cell] setFormatter:[[TCFormatter alloc]init]];
//    [[_streamer5 cell] setFormatter:[[TCFormatter alloc]init]];
//    [[_streamer6 cell] setFormatter:[[TCFormatter alloc]init]];

//    [[_end window]endEditingFor:nil];
//    [[_preroll window]endEditingFor:nil];
//    [[_prerollToHere window]endEditingFor:nil];
    
}
-(void)windowClosing: (NSNotification *) notification
{
    NSWindow *window = [notification object];   // ref NSNotification Class Reference
    NSWindow *myWindow = [self window];         // ref NSView Class Reference
    
    // is our window closing?
    
    if(window == myWindow){
        
        // 2.00.00 preroll is saved by setPreroll()
        // save the preroll when we exit
//        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
//        [defaults setObject:_preroll forKey:@"preroll"];
//        [defaults setObject:[NSNumber numberWithInteger:_displayFormat] forKey:@"displayFormat"];
    }
}

-(void)awakeFromNib{
    
    // why do the tc formatters not get 'init'-ed?
    // just being in the nib is not enough, have to do alloc,init here...
    
    [_start setFormatter:[[TCFormatter alloc]init]];
    [_end setFormatter:[[TCFormatter alloc]init]];
    [_prerollTextField setFormatter:[[TCFormatter alloc]init]];
//    [_prerollToHereTextField setFormatter:[[TCFormatter alloc]init]];
//
    [_streamer1 setFormatter:[[TCFormatter alloc]init]];
    [_streamer2 setFormatter:[[TCFormatter alloc]init]];
    [_streamer3 setFormatter:[[TCFormatter alloc]init]];
    [_streamer4 setFormatter:[[TCFormatter alloc]init]];
    [_streamer5 setFormatter:[[TCFormatter alloc]init]];
    [_streamer6 setFormatter:[[TCFormatter alloc]init]];
    
//    [self setColorStreamer0:[[ColorPopupButton alloc] init]];
//    [self setColorStreamer1:[[ColorPopupButton alloc] init]];
//    [self setColorStreamer2:[[ColorPopupButton alloc] init]];
//    [self setColorStreamer3:[[ColorPopupButton alloc] init]];
//    [self setColorStreamer4:[[ColorPopupButton alloc] init]];
//    [self setColorStreamer5:[[ColorPopupButton alloc] init]];
//    [self setColorStreamer6:[[ColorPopupButton alloc] init]];
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *registrationDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [[NSNumber alloc] initWithInteger: 0],@"indexStreamer0",
                                          [[NSNumber alloc] initWithInteger: 0],@"indexStreamer1",
                                          [[NSNumber alloc] initWithInteger: 0],@"indexStreamer2",
                                          [[NSNumber alloc] initWithInteger: 0],@"indexStreamer3",
                                          [[NSNumber alloc] initWithInteger: 0],@"indexStreamer4",
                                          [[NSNumber alloc] initWithInteger: 0],@"indexStreamer5",
                                          [[NSNumber alloc] initWithInteger: 0],@"indexStreamer6",
//                                          @"00:00:04:00",@"preroll",
                                          @"1.0 1.0 1.0 1.0",@"colorStreamer0String",
                                          @"1.0 1.0 1.0 1.0",@"colorStreamer1String",
                                          @"1.0 1.0 1.0 1.0",@"colorStreamer2String",
                                          @"1.0 1.0 1.0 1.0",@"colorStreamer3String",
                                          @"1.0 1.0 1.0 1.0",@"colorStreamer4String",
                                          @"1.0 1.0 1.0 1.0",@"colorStreamer5String",
                                          @"1.0 1.0 1.0 1.0",@"colorStreamer6String",
//                                          [NSNumber numberWithInt:DISPLAY_FMT_TC],@"displayFormat",
                                          nil];
    
    [defaults registerDefaults:registrationDefaults];
    
    [self recallDefaults];
    
//    [self setDisplayFormat:[[defaults objectForKey:@"displayFormat"] integerValue]];
    
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    
//    [_prerollToHereTextField bind:@"value" toObject:delegate withKeyPath:@"startFromPrerollTc" options:nil];    // FIXME only copy should be here
//    [_prerollTextField bind:@"value" toObject:delegate.matrixWindowController withKeyPath:@"preroll" options:nil];
    
//    // register for display format change notification
//    [(NSNotificationCenter *)[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayFmtDidChange:) name:@"displayFmtDidChange" object:nil];
    
    
    
}
-(NSColor*)colorFromString:(NSString*)str{
    // r g b a
    NSScanner *scan = [[NSScanner alloc] initWithString:str];
    
    double r,g,b,a;
    
    if([scan scanDouble:&r]
       && [scan scanDouble:&g]
       && [scan scanDouble:&b]
       && [scan scanDouble:&a]
       ){
        
        return [NSColor colorWithRed:r green:g blue:b alpha:a];
        
    }
    
    return NSColor.whiteColor;  // default is white
}
-(NSString*)colorToString:(NSColor*)color{
    
    NSColor *c = [color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    
    NSString *result = [[NSString alloc] initWithFormat:@"%1.3f %1.3f %1.3f %1.3f ",[c redComponent],[c greenComponent],[c blueComponent],[c alphaComponent]];
    return result;//    @"1.0 1.0 1.0 1.0";  // r g b a
}
-(void)recallDefaults{
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    // trigger bindings so that color wells show the colors
    // we don't know why this isn't necessary in StreamerWindowController
    
//    [self willChangeValueForKey:@"colorStreamer0"];
//    _colorStreamer0 = [self colorFromString:[defaults stringForKey:@"colorStreamer0String"]];
//    [self didChangeValueForKey:@"colorStreamer0"];
    
    [self willChangeValueForKey:@"colorStreamer1"];
    _colorStreamer1 = [self colorFromString:[defaults stringForKey:@"colorStreamer1String"]];
    [self didChangeValueForKey:@"colorStreamer1"];
    
    [self willChangeValueForKey:@"colorStreamer2"];
    _colorStreamer2 = [self colorFromString:[defaults stringForKey:@"colorStreamer2String"]];
    [self didChangeValueForKey:@"colorStreamer2"];
    
    [self willChangeValueForKey:@"colorStreamer3"];
    _colorStreamer3 = [self colorFromString:[defaults stringForKey:@"colorStreamer3String"]];
    [self didChangeValueForKey:@"colorStreamer3"];
    
    [self willChangeValueForKey:@"colorStreamer4"];
    _colorStreamer4 = [self colorFromString:[defaults stringForKey:@"colorStreamer4String"]];
    [self didChangeValueForKey:@"colorStreamer4"];
    
    [self willChangeValueForKey:@"colorStreamer5"];
    _colorStreamer5 = [self colorFromString:[defaults stringForKey:@"colorStreamer5String"]];
    [self didChangeValueForKey:@"colorStreamer5"];
    
    [self willChangeValueForKey:@"colorStreamer6"];
    _colorStreamer6 = [self colorFromString:[defaults stringForKey:@"colorStreamer6String"]];
    [self didChangeValueForKey:@"colorStreamer6"];

//    [self willChangeValueForKey:@"preroll"];
//    _preroll = [defaults objectForKey:@"preroll"];
//    [self didChangeValueForKey:@"preroll"];
//    [self setPreroll:[defaults objectForKey:@"preroll"]];
    
    _aleDelegate.prerollIndex = _aleDelegate.prerollIndex;  // sets preroll

}
//- (void)displayFmtDidChange:(NSNotification *)note
//{
//    [[_preroll window]endEditingFor:nil];
//    [[_prerollToHere window]endEditingFor:nil];
//    [[_start window]endEditingFor:nil];
//    [[_end window]endEditingFor:nil];
//
//    [[_streamer1 window]endEditingFor:nil];
//    [[_streamer2 window]endEditingFor:nil];
//    [[_streamer3 window]endEditingFor:nil];
//    [[_streamer4 window]endEditingFor:nil];
//    [[_streamer5 window]endEditingFor:nil];
//    [[_streamer6 window]endEditingFor:nil]; // display does not change if we are editing
//
//    [_start setNeedsDisplay];
//    [_end setNeedsDisplay];
//    [_prerollToHere setNeedsDisplay];
//    [_preroll setNeedsDisplay];
//    
//    [_streamer1 setNeedsDisplay];
//    [_streamer2 setNeedsDisplay];
//    [_streamer3 setNeedsDisplay];
//    [_streamer4 setNeedsDisplay];
//    [_streamer5 setNeedsDisplay];
//    [_streamer6 setNeedsDisplay];   // items that show tc or ft/frs
//}
//-(void)dealloc{
//    
//    // http://stackoverflow.com/questions/5668752/post-of-nsnotificationcenter-causing-exc-bad-access-exception
//    [(NSNotificationCenter *)[NSNotificationCenter defaultCenter] removeObserver:self];
//    
//}

//-(void)saveBackingImage{
//    
//    NSMutableData *data = [[NSMutableData alloc] init];
//    NSKeyedArchiver *arch = [[NSKeyedArchiver alloc]initForWritingWithMutableData:data];
//    [arch encodeObject:[_dragDropImageView image] forKey:@"_image"];
//    [arch finishEncoding];
//    
//    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"customerImage"];
//    
//}
-(void) bindFields:(NSString*)cueID :(NSString*)dialog :(NSString*)notes :(NSString*)actor :(NSString*)start :(NSString*)end :(NSDictionary*)dictionary{
    // https://developer.apple.com/library/mac/samplecode/NSTableViewBinding/Listings/MyWindowController_m.html
    // software binding of cols
    
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    [_session bind:@"value" toObject:delegate withKeyPath:@"session" options:nil];

    _cueID.stringValue     = @"";
    _start.stringValue     = @"";
    _end.stringValue       = @"";
    _dialog.stringValue    = @"";
    _notes.stringValue     = @"";
    _actor.stringValue     = @"";
    _take.stringValue      = @"";
    _track.stringValue     = @"";
    _streamer1.stringValue = @"";
    _streamer2.stringValue = @"";
    _streamer3.stringValue = @"";
    _streamer4.stringValue = @"";
    _streamer5.stringValue = @"";
    _streamer6.stringValue = @"";
    
    if(dictionary == nil){return;}

    @autoreleasepool {
        
        [_cueID bind:@"value" toObject:dictionary withKeyPath:cueID options:nil];
        [_start bind:@"value" toObject:dictionary withKeyPath:start options:nil];
        [_end bind:@"value" toObject:dictionary withKeyPath:end options:nil];
        [_dialog bind:@"value" toObject:dictionary withKeyPath:dialog options:nil];
        [_notes bind:@"value" toObject:dictionary withKeyPath:notes options:nil];
        [_actor bind:@"value" toObject:dictionary withKeyPath:actor options:nil];
        [_take bind:@"value" toObject:dictionary withKeyPath:@"Take" options:nil];
        [_track bind:@"value" toObject:dictionary withKeyPath:@"Track" options:nil];  // done through delegate below
        [_streamer1 bind:@"value" toObject:dictionary withKeyPath:@"streamer1" options:nil];
        [_streamer2 bind:@"value" toObject:dictionary withKeyPath:@"streamer2" options:nil];
        [_streamer3 bind:@"value" toObject:dictionary withKeyPath:@"streamer3" options:nil];
        [_streamer4 bind:@"value" toObject:dictionary withKeyPath:@"streamer4" options:nil];
        [_streamer5 bind:@"value" toObject:dictionary withKeyPath:@"streamer5" options:nil];
        [_streamer6 bind:@"value" toObject:dictionary withKeyPath:@"streamer6" options:nil];

    }
    
}
-(void)bindChecks:(id)sender{
    
    if([sender isKindOfClass:[Document class]]){
        
        Document *doc = (Document*)sender;
        AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
        
//        [_actorInFileNameCheck bind:@"value" toObject:doc withKeyPath:@"actorInFileName" options:nil];
//        [_dialogInClipNameCheck bind:@"value" toObject:doc withKeyPath:@"dialogInClipName" options:nil];
//        [_beepsTrimFrames bind:@"value" toObject:doc withKeyPath:@"beepsTrimFrames" options:nil];
        [_cueSheet bind:@"value" toObject:doc withKeyPath:@"tableView.window.title" options:nil];
        [_mixerNotes bind:@"value" toObject:doc withKeyPath:@"cueNote" options:nil];

//        [_track bind:@"value" toObject:delegate withKeyPath:@"trackForMixerWindow" options:nil];
        
        [_recTracks bind:@"value" toObject:delegate.matrixWindowController withKeyPath:@"recTracks" options:nil];
        
   }
    
}
//#pragma mark -
//#pragma mark -------------- TCFormatterDelegate methods ---------------
//
//-(NSString*)getTcStart{
//    
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//    Document *doc = [delegate topDocument];
//    
//    return [doc timeCodeStart];
//    
//}// each doc has its own
//-(NSInteger)getDisplayFormat{
//    
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//    return [[delegate topDocument] tableContentsDisplayFormat];//_displayFormat;
//    
//}
//-(Byte)getTcType{
//    
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//    return [delegate.midiClient getTcType];
//    
//}
#pragma mark -
#pragma mark -------------- NSTableViewDelegate methods ---------------
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification{
    
//    [self circleTakesFromRows];
    
}

#pragma mark -
#pragma mark -------------- NSWindow delegate methods ---------------


- (void)windowDidBecomeMain:(NSNotification *)notification{
    
//    AleDelegate *aleDelegate = (AleDelegate *)[NSApp delegate];
//    Document *doc = [aleDelegate topDocument];
//    [doc selectionDidChange:true];  // causes bindings to editor to update
}
-(void)windowDidMove:(NSNotification *)notification{
    
    
}
-(void)windowDidResize:(NSNotification *)notification{
    
}

#pragma mark -
#pragma mark ------------------ setters/getters -----------------------
//-(void)setColorStreamer0:(NSColor *)color{
//    _colorStreamer0 = color;
//
//    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
//    NSString *str = [self colorToString:color];
//    [defaults setObject:str forKey:@"colorStreamer0String"];
//}
//-(NSColor*)colorStreamer0{
//    return _colorStreamer0;
//}
-(void)setColorStreamer1:(NSColor *)color{
    _colorStreamer1 = color;

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString *str = [self colorToString:color];
    [defaults setObject:str forKey:@"colorStreamer1String"];
}
-(NSColor*)colorStreamer1{
    return _colorStreamer1;
}
-(void)setColorStreamer2:(NSColor *)color{
    _colorStreamer2 = color;

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString *str = [self colorToString:color];
    [defaults setObject:str forKey:@"colorStreamer2String"];
}
-(NSColor*)colorStreamer2{
    return _colorStreamer2;
}
-(void)setColorStreamer3:(NSColor *)color{
    _colorStreamer3 = color;

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString *str = [self colorToString:color];
    [defaults setObject:str forKey:@"colorStreamer3String"];
}
-(NSColor*)colorStreamer3{
    return _colorStreamer3;
}
-(void)setColorStreamer4:(NSColor *)color{
    _colorStreamer4 = color;

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString *str = [self colorToString:color];
    [defaults setObject:str forKey:@"colorStreamer4String"];
}
-(NSColor*)colorStreamer4{
    return _colorStreamer4;
}
-(void)setColorStreamer5:(NSColor *)color{
    _colorStreamer5 = color;

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString *str = [self colorToString:color];
    [defaults setObject:str forKey:@"colorStreamer5String"];
}
-(NSColor*)colorStreamer5{
    return _colorStreamer5;
}
-(void)setColorStreamer6:(NSColor *)color{
    _colorStreamer6 = color;

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString *str = [self colorToString:color];
    [defaults setObject:str forKey:@"colorStreamer6String"];
}
-(NSColor*)colorStreamer6{
    return _colorStreamer6;
}
-(void)setPreroll:(NSString *)preroll{
    
    if(preroll == nil){
        return;        
    } // no preroll
    _preroll = preroll;
}
-(NSString*)preroll{
    return _preroll;
}
-(void)setNameNote:(NSString *)nameNote{
    _nameNote = nameNote;
    NSLog(@"setNameNote %@",_nameNote);
}
-(NSString*)nameNote{
    return _nameNote;
}
#pragma mark -
#pragma mark -------------- ft/fr additions ---------------------
-(void)fmtDidChange{
    
    _start.needsDisplay = YES;
    _end.needsDisplay = YES;
//    _prerollToHereTextField.needsDisplay = YES;
    _prerollTextField.needsDisplay = YES;
//
//    [_start setNeedsDisplay];
//    [_end setNeedsDisplay];
//    [_prerollToHereTextField setNeedsDisplay];
//    [_prerollTextField setNeedsDisplay];  // setNeedsDisplay is deprecated
    
    _streamer1.needsDisplay = YES;
    _streamer2.needsDisplay = YES;
    _streamer3.needsDisplay = YES;
    _streamer4.needsDisplay = YES;
    _streamer5.needsDisplay = YES;
    _streamer6.needsDisplay = YES;

//    [_streamer1 setNeedsDisplay];
//    [_streamer2 setNeedsDisplay];
//    [_streamer3 setNeedsDisplay];
//    [_streamer4 setNeedsDisplay];
//    [_streamer5 setNeedsDisplay];
//    [_streamer6 setNeedsDisplay];   // items that show tc or ft/frs

}
-(void)endEditing{
    
    [[_prerollTextField window]endEditingFor:nil];
//    [[_prerollToHereTextField window]endEditingFor:nil];
    [[_start window]endEditingFor:nil];
    [[_end window]endEditingFor:nil];
    
    [[_streamer1 window]endEditingFor:nil];
    [[_streamer2 window]endEditingFor:nil];
    [[_streamer3 window]endEditingFor:nil];
    [[_streamer4 window]endEditingFor:nil];
    [[_streamer5 window]endEditingFor:nil];
    [[_streamer6 window]endEditingFor:nil]; // display does not change if we are editing
    
}
-(void)toggleToTc{
    
//    if(_displayFormat == DISPLAY_FMT_TC) return; // already TC
//    _displayFormat = DISPLAY_FMT_TC;
    
    [self endEditing];
    
    NSString *t = _preroll;
    
    if(t && t.length && [_tcc isFtFr:t]){
        
        t = [_tcf formatAsFeet:t];
        
        int frames = [_tcc ftToBinary:t];
        t = [_tcc binaryToTc:frames withType:TCTYPE_24];// FIXME
        [self setPreroll:t];
        
    }
    
    [self fmtDidChange];
}
-(void)toggleToFt{
    
//    if(_displayFormat == DISPLAY_FMT_FT) return; // already ft/fr
//    _displayFormat = DISPLAY_FMT_FT;
    
    [self endEditing];
    
    NSString *t = _preroll;
    
    if(t && t.length && [_tcc isTc:t]){
        t = [_tcf formatAsTc:t];
        
        int frames = [_tcc tcToBinary:t withType:TCTYPE_24];    // FIXME
        t = [_tcc binaryToFt:frames];
        [self setPreroll:t];
        
    }
    
    [self fmtDidChange];
    
}

@end
