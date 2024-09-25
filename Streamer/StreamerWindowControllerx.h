//
//  StreamerWindowController.h
//  Ale_v3xx
//
//  Created by James Ketcham on 3/31/14.
//  Copyright (c) 2014 WB ADR. All rights reserved.
//

#import <Cocoa/Cocoa.h>
//#import "DraggableItemView.h"
//#import "StreamerView.h"
//#import "DebugView.h"
#import "TcpClientBrowser.h"
//#import "ColorPopupButton.h"

@interface StreamerWindowController : NSWindowController{
    
//    NSTimer *timer;
//    NSInteger ping;
//    int ping_downctr;
    
//    NSImage *greenImage;
//    NSImage *redImage;
    
//    bool alreadyTriedOnce;  // try to fix things once only

}
enum {
    TAG_ALWAYS_ON = 0,
    TAG_FADE_IN,
    TAG_BLACK_CUE_BLACK
};

//@property NSInteger bmpWidth;
//@property NSInteger bmpHeight;
@property NSString *bmpText;
//@property double blackHoldTime;
//@property double pasteBlackTimeout;

@property NSTimer *timer;
@property bool inhibitStreamerInPlayback;

-(void)setPunchEnable:(bool)punchEnable;    // v1.00.21, Evan wants to set from MIDI accessory

//@property (strong) IBOutlet ColorPopupButton *popupStreamer0;
//@property (strong) IBOutlet ColorPopupButton *popupStreamer1;
//@property (strong) IBOutlet ColorPopupButton *popupStreamer2;
//@property (strong) IBOutlet ColorPopupButton *popupStreamer3;
//@property (strong) IBOutlet ColorPopupButton *popupEndbar;

//@property (weak) IBOutlet NSPopUpButton *popupStreamer0;
//@property (weak) IBOutlet NSPopUpButton *popupStreamer1;
//@property (weak) IBOutlet NSPopUpButton *popupStreamer2;
//@property (weak) IBOutlet NSPopUpButton *popupStreamer3;
//@property (weak) IBOutlet NSPopUpButton *popupEndbar;
//@property (weak) IBOutlet NSPopUpButton *popupProgressForeground;
//@property (weak) IBOutlet NSPopUpButton *popupProgressBackground;
//
//@property (weak) IBOutlet NSPopUpButton *popupDialogForeground;
//@property (weak) IBOutlet NSPopUpButton *popupDialogBackground;
//@property (weak) IBOutlet NSPopUpButton *popupTakeForeground;
//@property (weak) IBOutlet NSPopUpButton *popupTakeBackground;
//@property (weak) IBOutlet NSPopUpButton *popupLtcForeground;
//@property (weak) IBOutlet NSPopUpButton *popupLtcBackground;
//
//@property NSInteger colorDialogForeground;
//@property NSInteger colorDialogBackground;
//@property NSInteger colorTakeForeground;
//@property NSInteger colorTakeBackground;
//@property NSInteger colorLtcForeground;
//@property NSInteger colorLtcBackground;

- (IBAction)onPictureMatrix:(id)sender;
//@property (weak) IBOutlet NSMatrix *pictureMatrix;

@property NSArray *punchList;
@property NSString *punchListItem;
//- (IBAction)punchListCombo:(id)sender;

// access
//-(void)rxMsg:(NSString *)msg sender:sender;
//-(NSColor*)getAnnunciatorColor:(NSUInteger)index;
//-(void) getInitValues:(id)sender;

// protools counter

//- (IBAction)onButtonShowProtoolsCounter:(id)sender;
//- (IBAction)onButtonHideProtoolsCounter:(id)sender;
//- (IBAction)onProtoolsForegroundComboBox:(id)sender;
//- (IBAction)onProtoolsBackgroundComboBox:(id)sender;
- (IBAction)onProtoolsPointComboBox:(id)sender;

//@property (weak) IBOutlet NSComboBox *protoolsForegroundComboBox;
//@property (weak) IBOutlet NSComboBox *protoolsBackgroundComboBox;
@property (weak) IBOutlet NSComboBox *protoolsPointComboBox;

// LTC/MTC

//- (IBAction)onLtcForegroundComboBox:(id)sender;
//- (IBAction)onLtcBackgroundComboBox:(id)sender;
//- (IBAction)onLtcDisplayComboBox:(id)sender;
//- (IBAction)onLtcPointComboBox:(id)sender;

//@property (weak) IBOutlet NSComboBox *ltcForegroundComboBox;
//@property (weak) IBOutlet NSComboBox *ltcBackgroundComboBox;
@property (weak) IBOutlet NSComboBox *ltcDisplayComboBox;
@property (weak) IBOutlet NSComboBox *ltcPointComboBox;

//@property NSColor *rehearseColor;
//@property NSColor *recordColor;
//@property NSColor *playbackColor;
//
//@property NSColor *rehearseBgColor;
//@property NSColor *recordBgColor;
//@property NSColor *playbackBgColor;
//
//@property NSColor *textColor;
//@property NSColor *cueIdColor;
//
//@property NSColor *textBgColor;
//@property NSColor *cueIdBgColor;

@property NSColor *punchColor;
@property NSColor *streamerColor;
@property NSColor *endBarColor;

//@property (weak) IBOutlet NSColorWell *punchColorWell;

//// image array for color popup
//@property NSArray *imageArray;
//@property (weak) IBOutlet NSPopUpButton *punchColorPopup;
//@property (weak) IBOutlet NSPopUpButton *punch1ColorPopup;
//@property (weak) IBOutlet NSPopUpButton *punch2ColorPopup;
//@property (weak) IBOutlet NSPopUpButton *punch3ColorPopup;

// text

//- (IBAction)onButtonShowTextSample:(id)sender;
//- (IBAction)onButtonClearTextSample:(id)sender;
//- (IBAction)onTextForegroundComboBox:(id)sender;
//- (IBAction)onTextBackgroundComboBox:(id)sender;
//- (IBAction)onTextPointComboBox:(id)sender;

//@property (weak) IBOutlet NSComboBox *textForegroundComboBox;
//@property (weak) IBOutlet NSComboBox *textBackgroundComboBox;
@property (weak) IBOutlet NSComboBox *textPointComboBox;

// test signal generator
//- (IBAction)onColorBars:(id)sender;
//- (IBAction)onSdiTestSignalComboBox:(id)sender;
//@property (weak) IBOutlet NSComboBox *sdiTestSignalComboBox;
//@property (weak) IBOutlet NSButton *colorBarCheckBox;

// streamer view
//@property (weak) IBOutlet StreamerView *streamerView;
- (IBAction)onStreamer0:(id)sender;
//- (IBAction)onStreamer1:(id)sender;
//- (IBAction)onStreamer2:(id)sender;
//- (IBAction)onStreamer3:(id)sender;

// debug view
//@property (weak) IBOutlet DebugView *debugView;
@property (unsafe_unretained) IBOutlet NSTextView *rxTextView;
@property (strong) IBOutlet NSTextView *bmpTextView;

//- (IBAction)onTxTextField:(id)sender;
@property bool inhibitPingPrinting;
//- (IBAction)onClearRxTextView:(id)sender;

// items to make bindings to streamerView.streamerImage work
@property NSInteger width;
//@property double duration;
@property NSInteger colorMsb;
@property NSInteger top;
@property NSInteger bottom;
@property NSInteger transparency;
//@property bool progressEnable;
//@property NSInteger progressX;
//@property NSInteger progressY;
//@property NSInteger progressWidth;
//@property NSInteger progressHeight;


// masking
@property NSInteger topMask;
@property NSInteger bottomMask;
@property NSInteger leftMask;
@property NSInteger rightMask;
@property NSInteger transparencyMask;

//@property NSInteger colorStreamer0;
//@property NSInteger colorStreamer1;
//@property NSInteger colorStreamer2;
//@property NSInteger colorStreamer3;
//@property NSInteger colorEndBar;
//@property NSInteger colorProgressForeground;
//@property NSInteger colorProgressBackground;

// frame rate

@property NSInteger frameRateTag;
@property bool endPunch;
@property NSInteger inputPriorityTag;

// frame rate converter

@property bool frameRateConverter;
// pop/ltc/mtc enables

//@property NSInteger popTag;
//@property bool popPunch;
//@property bool popStreamerAccum;
//@property bool popStreamer;

// end of items to make bindings to streamerView.streamerImage work
// items to make bindings to streamerView.punchImage work
//@property double playToStreamerSeconds;
//@property double streamerToMuteSeconds;
//@property double muteToRecordSeconds;
@property NSInteger x;
@property NSInteger y;
@property NSInteger diameter;
@property NSInteger colorIndex0;
@property NSInteger colorIndex1;
@property NSInteger colorIndex2;
@property NSInteger colorIndex3;
//@property bool reverseVideo;
@property bool punchEnable;
@property bool beepsEnable;
@property bool streamerEnable;
//@property bool blackCueBlack;
//@property bool pictureWhenStopped;
//@property bool streamerTriggersBeeps;
@property bool rgbFadeEnable;
//@property NSInteger beepsRepeatCount;
//@property NSInteger durationFrames;
//@property double repeatSeconds;
@property NSInteger pictureTag;
//@property NSInteger takeTag;
//@property NSInteger dialogTag;
//@property id connection;  // the streamer connection
@property bool armBeeps;    // 3/4/16 first streamer has beeps
@property double fadeSeconds;

// end of items to make bindings to streamerView.punchImage work

//- (IBAction)onBmp:(id)sender;

// access
//-(NSInteger)rehRecPbState;
//-(void)setAnnunciatorByTag:(NSInteger)tag;
//-(void)sendAnnunciatorByTag:(NSInteger)tag;
-(void)triggerStreamer:(NSString*)tc;
//-(void)pictureOnDuringStop;
//-(void)forceBlack:(bool) black;
//-(void)txDataBytes:(NSData*)data;
-(void)txMidiAsString:(NSData*)midi;
//-(void)txMsgAsBmp:(NSString*)msg;
//-(void)processMsgArray:(NSMutableArray *)msgArray :(id)connection;
//-(void)setDefaultServer:(NSString*)server;
-(void)firstCueGreaterThan:(NSString*)tc;

//-(double)annunciatorFadeSeconds;
//-(double)annunciatorFadeDelay;
//-(double)pictureFadeSeconds;
//-(double)pictureFadeDelay;
//-(void)sendAnnunciator24BitColors;

@end
