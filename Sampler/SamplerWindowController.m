//
//  SamplerWindowController.m
//  AleDoc
//
//  Created by James Ketcham on 9/2/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import "SamplerWindowController.h"
#import "OsaScript.h"
#import "AleDelegate.h"
#include "ObjCPlayFile.h"
#include "Document.h"
#import "AleDoc21-Swift.h"    // must be here to avoid a circular reference

//#include "MidiClient.h"
#define OSC_TAG_BASE 48 // start of osc keys in unit_9_dictionary

@interface SamplerWindowController ()

@property NSSpeechSynthesizer *synth;
@property (strong) IBOutlet NSSlider *rateSlider;

@end

@implementation SamplerWindowController

@synthesize synth = _synth;
@synthesize samplerPlaysInPlayback = _samplerPlaysInPlayback;

//@synthesize samplerPlayState = _samplerPlayState;

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(windowClosing:)
     name:NSWindowWillCloseNotification
     object:nil ];
    
    [_loop0 setDelegate:self];
    [_loop1 setDelegate:self];
    [_loop2 setDelegate:self];
    [_loop3 setDelegate:self];
    [_loop4 setDelegate:self];
    [_loop5 setDelegate:self];
    [_loop6 setDelegate:self];
    [_loop7 setDelegate:self];
    [_loop8 setDelegate:self];
    [_loop9 setDelegate:self];
    [_loop10 setDelegate:self];
    [_loop11 setDelegate:self];
    [_playbackButton setDelegate:self];
    [_playbackButton2 setDelegate:self];
    
    [_textView setContinuousSpellCheckingEnabled:false];    // debug window
    
    // a thread for running Applescripts
    _osaScript = [[OsaScript alloc] init];
    [_osaScript start];
    
    _objCPlayFile = [[ObjCPlayFile alloc] init];    // core Audio player
    
    _synth = [[NSSpeechSynthesizer alloc] init];  // 'take' announcer (auto slate too?)
    [_synth setDelegate:self];
    
    // https://developer.apple.com/documentation/appkit/nsspeechmode?language=objc
    // NSSpeechModeLiteral NSSpeechModeNormal NSSpeechModePhoneme NSSpeechModeText
    // NSSpeechModePhoneme is clicks
    // the others say '4 degrees celsius' for '4 C'
    NSSpeechPropertyKey key = NSSpeechModeNormal;
    
    [_synth setObject:key
          forProperty:NSSpeechNumberModeProperty error:nil];
    
    key = NSSpeechModeNormal;
    [_synth setObject:key
          forProperty:NSSpeechCharacterModeProperty error:nil];
    [_synth setObject:key
          forProperty:NSSpeechInputModeProperty error:nil];
    
//    NSString *foo = [_synth objectForProperty:NSSpeechNumberModeProperty error:nil];
//    NSLog(@"NSSpeechNumberModeProperty: %@",foo);
    
    // check synthesizer rate setting, put it in slider range
    NSInteger rate = [[NSUserDefaults standardUserDefaults] integerForKey:@"synth_rate"];
    if(rate < _rateSlider.minValue || rate > _rateSlider.maxValue){
        
        [[NSUserDefaults standardUserDefaults] setInteger:_rateSlider.minValue forKey:@"synth_rate"];
        
    }
    
    //    NSMutableArray *voices = [[NSMutableArray alloc] initWithArray:[NSSpeechSynthesizer availableVoices]];
    NSMutableArray *shortVoices = [[NSMutableArray alloc] init];
    // com.apple.speech.synthesis.voice.
    //    for(NSString *voice in voices){
    //
    //        @try {
    //
    //            NSArray *voiceParts = [voice componentsSeparatedByString:@"."];
    //            [shortVoices addObject:[voiceParts objectAtIndex:voiceParts.count - 1]];
    //
    //        }
    //        @catch (NSException *exception) {
    //            NSLog(@"exception");
    //
    //        }
    //
    //    }
    
    // these are the two best voices, leave out the silly ones
    [shortVoices addObject:@"Daniel"];
    [shortVoices addObject:@"tessa"];    // V1.00.18, list has changed, no more 'Vicki'
    //    [shortVoices addObject:@"fiona"];
    //    [shortVoices addObject:@"karen"];
    //    [shortVoices addObject:@"moira"];
    //    for (NSString *voice in NSSpeechSynthesizer.availableVoices){
    //        // split at .
    //        NSArray *parts = [voice componentsSeparatedByString:@"."];
    //        NSLog(@"voice : %@",parts[parts.count - 1]);
    //        [shortVoices addObject:parts[parts.count - 1]];
    //    }
    
    NSString *defaultVoice = [shortVoices objectAtIndex:0];
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *registrationDefaults = [NSDictionary dictionaryWithObjectsAndKeys:defaultVoice,@"voice",nil];
    [defaults registerDefaults:registrationDefaults];
    
    // populate the combo box
    [_voiceComboBox removeAllItems];
    [_voiceComboBox addItemsWithObjectValues:shortVoices];
    [_voiceComboBox setStringValue:[defaults objectForKey:@"voice"]];
    
    [self setSamplerPlaysInPlayback:true]; // no need for this to be sticky
}

-(void)windowClosing: (NSNotification *) notification
{
    NSWindow *window = [notification object];   // ref NSNotification Class Reference
    NSWindow *myWindow = [self window];         // ref NSView Class Reference
    
    // is our window closing?
    
    if(window == myWindow){
        
        if(_osaScript) [((OsaScript*)_osaScript) stop];
    }
}

-(void)sendLoop:(NSString*)script folder:(NSString*)folder file:(NSString*) file{
    
    if(_osaScript == nil) return;
    
    NSString *cmd = [NSString stringWithFormat:@"%@\t%@\t%@",script,folder,file];
    
    [_osaScript processMsg:cmd];
    
}

- (IBAction)onButton:(id)sender {
    
    DropButton *db = (DropButton*)sender;
    
    if(db.folder == nil || db.fileName == nil || db.fileName.length == 0){
        db.state = NSControlStateValueOff;
    }
    
    // interlock fills
    switch(db.tag){
        case 12:    // stock fill
            _playbackButton2.state = NSControlStateValueOff;
            [self onLoop: _playbackButton2];
            [self loopToOsc: _playbackButton2];
            break;
        case 13:    // custom fill
            _playbackButton.state = NSControlStateValueOff;
            [self onLoop: _playbackButton];
            [self loopToOsc: _playbackButton];
            break;
    }
    
    [self onLoop: db];
    [self loopToOsc: db];
    
}

- (IBAction)onLoop:(id)sender {
    
    DropButton *db = sender;
    
    if(db == nil ||
       db.folder == nil ||
       db.fileName == nil ||
       db.folder.length == 0 ||
       db.fileName.length == 0)return;
    
    if([sender state] == NSControlStateValueOn){
        
        [self sendLoop:@"playQuickTime" folder:db.folder file:db.fileName];
        
    }else{
        
        [self sendLoop:@"stopQuickTime" folder:db.folder file:db.fileName];
        
    }
}

//- (IBAction)onSamplerRecord:(id)sender {
//    
//    if(((NSButton*)sender).state == NSControlStateValueOn)
//        [_osaScript processMsg:@"recordQuickTime 1"];
//    else
//        [_osaScript processMsg:@"recordQuickTime 0"];
//}

- (IBAction)onClearButton:(id)sender {
    [_textView selectAll:sender];
    [_textView delete:sender];
}
-(void)addToTextView:(NSString*)msg{
    
    NSTextStorage * sto = [_textView textStorage];
    NSAttributedString *ats = [[NSAttributedString alloc] initWithString:[msg stringByAppendingString:@"\n"]];
    [sto appendAttributedString:ats];
    // scroll to end of document
    [_textView scrollToEndOfDocument:nil];
    
}

- (IBAction)onPlaybackButton:(id)sender {
    [self onButton:_playbackButton];
}
- (IBAction)onPlaybackButton2:(id)sender{
    [self onButton:_playbackButton2];
}

//- (IBAction)onPlaybackButton:(id)sender {
////    NSLog(@"onPlaybackButton");
//
////    [self addToTextView:@"onPlaybackButton"];
//    _playbackButton2.state = NSControlStateValueOff;    // TODO: check this
//    [self onLoop:sender];
//    return;
//
//    [[self playbackButton2] setState:NSControlStateValueOff];   // interlocked, can only play one or the other
//
//    DropButton *db = sender;
//    NSString *pathToAudioFile = [db.folder stringByAppendingString:db.fileName];
//
//    if(pathToAudioFile == nil || pathToAudioFile.length == 0) return;
//
////    [self addToTextView:@"onPlaybackButton file exists"];
//
//    if([sender state] == NSControlStateValueOff){
//
//        if(_objCPlayFile){
//
////            [self addToTextView:@"onPlaybackButton stopAudio"];
//            [_objCPlayFile stopAudio];
//        }
//
//    }else{
//
//        if(_objCPlayFile){
//
//
//            /*int status = */[_objCPlayFile startAudio:pathToAudioFile];    // checking alias, try full path if this does not work
//
////            NSString *msg = [NSString stringWithFormat:@"onPlaybackButton startAudio %@\n status: %d",pathToAudioFile,status];
////            [self addToTextView:msg];
//        }
//
//    }
//
//    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
//    if(delegate)[delegate setSamplerKeys];
//
//}
//- (IBAction)onPlaybackButton2:(id)sender{
//    _playbackButton.state = NSControlStateValueOff;
//    [self onLoop:sender];
//    return;
//
////    [self addToTextView:@"onPlaybackButton2"];
//
//    [[self playbackButton] setState:NSControlStateValueOff];   // interlocked, can only play one or the other
//
//    DropButton *db = sender;
//    NSString *pathToAudioFile = [db.folder stringByAppendingString:db.fileName];
//
//    if(pathToAudioFile == nil || pathToAudioFile.length == 0) return;
//
////    [self addToTextView:@"onPlaybackButton2 file exists"];
//
//    if([sender state] == NSControlStateValueOff){
//
//        if(_objCPlayFile) {
//
////            [self addToTextView:@"onPlaybackButton2 stopAudio"];
//            [_objCPlayFile stopAudio];
//        }
//
//    }else{
//
//        if(_objCPlayFile){
//            /*int status = */[_objCPlayFile startAudio:pathToAudioFile];    // checking alias, try full path if this does not work
//
////            NSString *msg = [NSString stringWithFormat:@"onPlaybackButton2 startAudio %@\n status: %d",pathToAudioFile,status];
////            [self addToTextView:msg];
//        }
//
//    }
//
//    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
//    if(delegate)[delegate setSamplerKeys];
//
//}
-(void)playback:( bool)playbackOn{
    
    if(!playbackOn){
        
        [[self playbackButton] setState:false];
        [[self playbackButton2] setState:false];
        [self onLoop: _playbackButton];
        [self onLoop: _playbackButton2];
        
        return;
        
    }
    
    if(self.samplerPlaysInPlayback){
        
        // 5/19/15 Evan Daum wants MIDI messages to PT plugins for sampler/capture operation
        /*
         
         done in aleDelegate.captureFillStop, not here
         
         When beginning a playback mode cycle:
         
         If the "custom fill" flag is ON
         
         Send CC11 with value of 127 (for play), and value 55 (for stop) (when you get a stop tally from Pro Tools).  (127 is play, 55 is hard stop).
         
         else
         
         Send CC12 with value of 127 (for play), and value 55 (for stop) (when you get a stop tally from Pro Tools).  (127 is play, 55 is hard stop).
         */
        
//        unsigned char midi[] = {0xb0,0,0};
        AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
        //unsigned char midiCustomFillState = [delegate midiCustomFillState];
//        midi[1] = midiCustomFillState ? 11 : 12;
//        midi[2] = playbackOn ? 127 : 55;
//        
//        [delegate.midiClient txMidiToAcc:[NSData dataWithBytes:midi length:3]];
        
        if([delegate.lpMini isMidiCustomFillState]){
//            
//            // 'fools are so ingenious' case, other button was pushed manually
//            [[self playbackButton] setState:NSControlStateValueOff];
//            [self onPlaybackButton:_playbackButton];    // MUST be before PLAY of audio file
            
            [[self playbackButton2] setState:playbackOn];
            [self onPlaybackButton2:_playbackButton2];
            
        }else{
//            
//            // 'fools are so ingenious' case, other button was pushed manually
//            [[self playbackButton2] setState:NSControlStateValueOff];
//            [self onPlaybackButton2:_playbackButton2];
            
            [[self playbackButton] setState:playbackOn];
            [self onPlaybackButton:_playbackButton];
        }
        
    }else{
        
        // the case where the checkbox is unchecked during PLAY and either sampler is playing
        
        _playbackButton2.state = false;
        [self onPlaybackButton2:_playbackButton2];
        
        _playbackButton.state = false;
        [self onPlaybackButton:_playbackButton];
    }
    
}

- (IBAction)onAnnounceTake:(id)sender {
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    Document *doc = [delegate topDocument];
    NSString *take = [doc takeForDictionary];//[NSString stringWithFormat:@"V2 Take %@\r\n",[doc take]];
    
    if(take == nil || take.length == 0 || [take isEqualToString:@"0"]){
        
        take = @"1";
        
    }
    
    [self sayTake:take];

//
//    NSInteger rate = [[NSUserDefaults standardUserDefaults] integerForKey:@"synth_rate"];
//    NSInteger addCueName = [[NSUserDefaults standardUserDefaults] integerForKey:@"addCueName"];
//    NSLog(@"addCueName: %ld",addCueName);
//
//
//
//    // list available voices, 1.00.18, list now has language translators, but we are using just one male and one female English speaker that we like
////    for (NSString *voice in NSSpeechSynthesizer.availableVoices){
////        // split at .
////        NSArray *parts = [voice componentsSeparatedByString:@"."];
////        NSLog(@"voice : %@",parts[parts.count - 1]);
////    }
//
////    NSString *voiceID = [NSString stringWithFormat:@"com.apple.speech.synthesis.voice.%@",[_voiceComboBox stringValue]];
//
////    [_synth setVoice:voiceID];
//
//    AleDelegate *aleDelegate = (AleDelegate*)[NSApp delegate];
//    Document *doc = [aleDelegate topDocument];
////    SafetyRecorderClient *src = aleDelegate.safetyRecorderClient;
//
//    if(doc){
//
//        NSString *take = [NSString stringWithFormat:@"take %@",doc.take];
//        if(addCueName != 0){
//            take = [NSString stringWithFormat:@"cue   %@",doc.cueID];
//        }else{
//            rate = 200.0;   // normal speech rate
//        }
//        // remove blanks
//        take = [take stringByReplacingOccurrencesOfString:@" " withString:@""];
//        // replace hyphens with blanks
//        take = [take stringByReplacingOccurrencesOfString:@"-" withString:@" "];
//
////        take = [doc clipName];    // testing slate, is acceptable
////        if(src)[src say:take :[_voiceComboBox stringValue]];
//
//        NSString *voiceID = [NSString stringWithFormat:@"com.apple.speech.synthesis.voice.%@",[_voiceComboBox stringValue]];
//        [_synth setVoice:voiceID];
//        // TODO rate 1.00.18
//        if(rate >= _rateSlider.minValue || rate <= _rateSlider.maxValue){
//            [_synth setRate:(float)rate];
//        }
//        [_synth startSpeakingString:take];
//    }
//
//

}
-(void)say:(NSString*)msg :(NSString*)voice :(float)rate{
    
    // this is called only to say take numbers
        
    NSString *voiceID = [NSString stringWithFormat:@"com.apple.speech.synthesis.voice.%@",voice];
    [_synth setVoice:voiceID];
    // TODO set speed of voice 1.00.18
    [_synth setRate:rate]; // normal rate
    [_synth startSpeakingString:msg];
    
}
-(void)say:(NSString*)msg{
    
    [self say:msg :self.selectedVoice :200.0];
}

-(void)sayTake:(NSString*)msg{
    
    msg = [msg stringByReplacingOccurrencesOfString:@" " withString:@""];   // remove blanks
    msg = [msg stringByReplacingOccurrencesOfString:@"-" withString:@" "];  // replace -
    
    msg = [@"take " stringByAppendingString:msg];
    
    float rate = 200.0; // our default speech rate
    NSInteger addCueName = [[NSUserDefaults standardUserDefaults] integerForKey:@"addCueName"];
    AleDelegate *aleDelegate = (AleDelegate*)[NSApp delegate];
    Document *doc = [aleDelegate topDocument];
    NSMutableString *cue = [[NSMutableString alloc] initWithString:doc.cueID];
    // break up digit strings into 1-2 digit strings separated by blanks
    // announcement will be like 'thirty five twenty three'
    NSString *cueCopy = [cue copy];
    int oddEven = 0;
    
    for(NSUInteger i = cueCopy.length - 1; i > 0; i--){
        
        unichar c = [cueCopy characterAtIndex:i];
        if(c >= '0' && c <= '9'){
            
            oddEven++;
            if((oddEven % 2) == 0){
                [cue insertString:@" " atIndex:i];
            }
            
        }else{
            oddEven = 0;
        }
        
        
    }

    if(addCueName){
        rate = (float)[[NSUserDefaults standardUserDefaults] integerForKey:@"synth_rate"];
        msg = [msg stringByAppendingFormat:@" %@",cue];
    }

    [self say:msg :self.selectedVoice :rate];

}
- (IBAction)onCombo:(id)sender {
    
    NSComboBox *combo = (NSComboBox *)sender;
    
    [[NSUserDefaults standardUserDefaults] setValue:combo.stringValue forKey:@"voice"];
}

-(NSString*)selectedVoice{
    return [_voiceComboBox stringValue];
}
//
//- (IBAction)onSamplerPlay:(id)sender {
//    
////    
////    NSString *pathToAudioFile = [[[NSProcessInfo processInfo]environment]objectForKey:@"HOME"];
////    pathToAudioFile = [pathToAudioFile stringByAppendingString:@"/Desktop/playfile/"];
////    if(((NSButton*)sender).state == NSControlStateValueOn){
////        [self sendLoop:@"playQuickTime" folder:pathToAudioFile file:@"1k.wav"];
////    }else{
////        [self sendLoop:@"stopQuickTime" folder:pathToAudioFile file:@"1k.wav"];
////        
////    }
////    
////    return;
//
////
////    // the following uses audio callback
////    
////    if(((NSButton*)sender).state == NSControlStateValueOn){
////        //[_osaScript processMsg:@"playUntitled 1"];
////        // /Users/jamesketcham/Desktop/playfile/1k.wav
////        
////        if(_objCPlayFile){
////            
////            // temp play a 1k stereo 16 bit file in a known location
////            NSString *pathToAudioFile = [[[NSProcessInfo processInfo]environment]objectForKey:@"HOME"];
////            pathToAudioFile = [pathToAudioFile stringByAppendingString:@"/Desktop/playfile/1k.wav"];
////            [_objCPlayFile startAudio:pathToAudioFile];    // checking alias, try full path if this does not work
////        }
////    }else{
////        
////        if(_objCPlayFile) [_objCPlayFile stopAudio];
////        
////    }
////    else
////        [_osaScript processMsg:@"playUntitled 0"];
//}

//- (IBAction)onSamplerPlayLast:(id)sender {
//    
//    // we have the last two files copied from PT available for looping
//}

//- (IBAction)onBeepsTrim:(id)sender {
//    
//    // button tag is the trim value
//    NSInteger trim = ((NSButton*)sender).tag;
//    
//    AleDelegate *delegate = [NSApp delegate];
//    if(delegate)[delegate trimBeeps:trim];
//    
//}

//-(void)loopWithTag:(NSInteger) tag start:(bool)start{
//    
//    switch (tag) {
//        case 0:
//            [_loop0 setState:start ? NSControlStateValueOn : NSControlStateValueOff];
//            [self onLoop:_loop0];
//            break;
//        case 1:
//            [_loop1 setState:start ? NSControlStateValueOn : NSControlStateValueOff];
//            [self onLoop:_loop1];
//            break;
//        case 2:
//            [_loop2 setState:start ? NSControlStateValueOn : NSControlStateValueOff];
//            [self onLoop:_loop2];
//            break;
//        case 3:
//            [_loop3 setState:start ? NSControlStateValueOn : NSControlStateValueOff];
//            [self onLoop:_loop3];
//            break;
//        case 4:
//            [_loop4 setState:start ? NSControlStateValueOn : NSControlStateValueOff];
//            [self onLoop:_loop4];
//            break;
//        case 5:
//            [_loop5 setState:start ? NSControlStateValueOn : NSControlStateValueOff];
//            [self onLoop:_loop5];
//            break;
//        case 6:
//            [_loop6 setState:start ? NSControlStateValueOn : NSControlStateValueOff];
//            [self onLoop:_loop6];
//            break;
//        case 7:
//            [_loop7 setState:start ? NSControlStateValueOn : NSControlStateValueOff];
//            [self onLoop:_loop7];
//            break;
//        case 8:
//            [_loop8 setState:start ? NSControlStateValueOn : NSControlStateValueOff];
//            [self onLoop:_loop8];
//            break;
//        case 9:
//            [_loop9 setState:start ? NSControlStateValueOn : NSControlStateValueOff];
//            [self onLoop:_loop9];
//            break;
//        case 10:
//            [_loop10 setState:start ? NSControlStateValueOn : NSControlStateValueOff];
//            [self onLoop:_loop10];
//            break;
//        case 11:
//            [_loop11 setState:start ? NSControlStateValueOn : NSControlStateValueOff];
//            [self onLoop:_loop11];
//            break;
//            
//        default:
//            break;
//    }
//}
//-(void)recordQuicktime:(bool)start{
//    
//    [_recordButton setState:start ? NSControlStateValueOn : NSControlStateValueOff];
////    [self onSamplerRecord:_recordButton];
//    
//}
//-(void)playbackQuicktime:(bool)start{
//    
//    [_playbackButton setState:start ? NSControlStateValueOn : NSControlStateValueOff];
//    [self onSamplerPlay:_playbackButton];
//    
//    AleDelegate *delegate = [NSApp delegate];
//    // -(void)setLEDForUnitID:(int)unitID :(int)index :(bool)on;
//    if(delegate)[delegate setLEDForUnitID:3 :5 :start];
//    
//}
//-(void)playbackLastQuicktime:(bool)start{
//    
//}
-(void)loopToOsc:(DropButton*)btn{
    
    // if there is no file, send Loop xx
    NSString *txt = btn.fileName;
    
    if(txt == nil || txt.length == 0){
        
        switch(btn.tag){
            default: txt = [NSString stringWithFormat:@"Loop %ld",btn.tag + 1]; break; // loop 0 shows as 'loop 1'
            case 12: txt = [NSString stringWithFormat:@"Stock Fill"];break;
            case 13: txt = [NSString stringWithFormat:@"Custom Fill"];break;
        }
       
    }else{
        
        switch(btn.tag){
            default: break;     // show filename
            case 12: txt = [NSString stringWithFormat:@"Stock: %@",txt];break;   // indicate it is the stock fill
            case 13: txt = [NSString stringWithFormat:@"Custom: %@",txt];break;  // indicate it is the custom fill
        }

    }

    //  :(NSString*)txt :(NSInteger) state
    
    int fg = btn.state ? COLOR_OSC_BLACK : COLOR_OSC_WHITE;
    int bg = btn.state ? COLOR_OSC_POWDER_BLUE : COLOR_OSC_OFF;
    
    NSInteger unitID = 9;//event.data2;
    NSInteger keyNumber = btn.tag + OSC_TAG_BASE;
    
    NSString *msg = [NSString stringWithFormat:@"btn %ld_%ld,%d,%d,%@",unitID,keyNumber,fg,bg,txt];
    AleDelegate *aleDelegate = (AleDelegate*)[NSApp delegate];
    [aleDelegate txOsc:msg];

}
-(void)initLoopButtons{
    
    // send current state to Companion
    
    DropButton *array[] = {
        _loop0
        ,_loop1
        ,_loop2
        ,_loop3
        ,_loop4
        ,_loop5
        ,_loop6
        ,_loop7
        ,_loop8
        ,_loop9
        ,_loop10
        ,_loop11
        ,_playbackButton
        ,_playbackButton2
    };
    
    for(int i = 0; i < (sizeof(array) /sizeof(array[0])); i++){
        
        [self onButton:array[i]];
        
    }
}
-(void)loopFromOsc:(NSInteger)keyNumber{
    
    DropButton *array[] = {
        _loop0
        ,_loop1
        ,_loop2
        ,_loop3
        ,_loop4
        ,_loop5
        ,_loop6
        ,_loop7
        ,_loop8
        ,_loop9
        ,_loop10
        ,_loop11
        ,_playbackButton
        ,_playbackButton2
    };
    
    NSInteger tag = keyNumber - OSC_TAG_BASE;   // loop buttons are sequential in the jump table
    
    if(tag >= sizeof(array) /sizeof(array[0])){
        return;
    }
    
    array[tag].state = !array[tag].state;
    [self onButton:array[tag]];
    
}
//-(void)loopFromXKey:(NSInteger)xKey{
//
//    DropButton *db = nil;
//    switch (xKey) {
//
//        case 0: db = _loop0; break;
//        case 1: db = _loop4; break;
//        case 2: db = _loop8; break;
//        case 8: db = _loop1; break;
//        case 9: db = _loop5; break;
//        case 10: db = _loop9; break;
//        case 16: db = _loop2; break;
//        case 17: db = _loop6; break;
//        case 18: db = _loop10; break;
//        case 24: db = _loop3; break;
//        case 25: db = _loop7; break;
//        case 26: db = _loop11; break;
//
//        default:
//            break;
//    }
//
//    if(db ==  nil)return;
//
//    [db setState:![db state]];  // toggle the state
//    [self onLoop:db];
//
//}
//-(bool)getXKeyState:(int)xKey{
//
//    switch (xKey) {
//
//        case 0: return [_loop0 state];
//        case 1: return [_loop4 state];
//        case 2: return [_loop8 state];
//        case 8: return [_loop1 state];
//        case 9: return [_loop5 state];
//        case 10: return [_loop9 state];
//        case 16: return [_loop2 state];
//        case 17: return [_loop6 state];
//        case 18: return [_loop10 state];
//        case 24: return [_loop3 state];
//        case 25: return [_loop7 state];
//        case 26: return [_loop11 state];
//
//        default:
//            break;
//    }
//
//    return false;
//}
# pragma mark -
# pragma mark -------------------- setters/getters ----------------------------
-(void)setSamplerPlaysInPlayback:(bool)samplerPlaysInPlayback{
    [[NSUserDefaults standardUserDefaults] setBool:samplerPlaysInPlayback forKey:@"samplerPlaysInPlayback"];
}
-(bool)samplerPlaysInPlayback{
    return [[NSUserDefaults standardUserDefaults]boolForKey:@"samplerPlaysInPlayback"];
}
//-(void)setSamplerPlayState:(NSInteger)samplerPlayState{
//    
//    _samplerPlayState = samplerPlayState;
//    [self onSamplerPlay:_playbackButton];
//    
//    AleDelegate *delegate = [NSApp delegate];
//    // -(void)setLEDForUnitID:(int)unitID :(int)index :(bool)on;
//    if(delegate)[delegate setLEDForUnitID:3 :5 :samplerPlayState];
//    
//}
//-(NSInteger)samplerPlayState{
//    return _samplerPlayState;
//}

# pragma mark -
# pragma mark -------------------- DropButtonDelegate methods ----------------------------

-(void)stopAudio:(NSString*)folder fileName:(NSString*)fileName{
    
    if(folder == nil ||
       fileName == nil ||
       folder.length == 0 ||
       fileName.length == 0)return;
    
    [self sendLoop:@"stopQuickTime" folder:folder file:fileName];
    
}
- (IBAction)onStart:(id)sender {
}

- (IBAction)onStop:(id)sender {
}
# pragma mark -
# pragma mark -------------------- NSSpeechSynthesizerDelegate methods ----------------------------

@end
