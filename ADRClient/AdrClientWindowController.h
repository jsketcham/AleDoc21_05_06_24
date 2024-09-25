//
//  AdrClientWindowController.h
//  Ale_v3xx
//
//  Created by James Ketcham on 3/12/14.
//  Copyright (c) 2014 WB ADR. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TcpClientBrowser.h"
#import "AdrClient.h"

#define X_KEY @"x"
#define Y_KEY @"y"
#define H_KEY @"h"
#define W_KEY @"w"
#define TITLE_KEY @"title"

@class AdrClientWindowController;

@protocol AdrClientWindowControllerDelegate

-(void)showTargetTrackTitle:(NSString *)title;
-(NSString*)getTargetTrackTitle;
-(void)setTargetTrackByLastMouseUpAfterQueue;
-(void)unmuteTargetByLastMouseUpAfterQueue;
-(void)grabAllAfterQueue;
-(bool)testGrabAllTimeout;
//-(void)midiKeyboardServiceAfterQueue:(NSString*)msg;
-(void)initGrabAllTimeout;
-(void)grabAllTimeout;
-(bool) isAleMini;
-(bool) getTrackPosIsInhibited;
-(void) initDisplayFormat:(NSInteger)fmt;

@end

@interface AdrClientWindowController : NSWindowController

@property bool forceAddCue;

@property NSTimer *timer;
//@property NSInteger cueCtr;
//@property TcpClientBrowser *tcpClient;    // changed to adrClient 1.00.23
@property AdrClient *adrClient; // replaces server/client connection with local thread
//@property (weak) NSImage *connectionStatusImage;
@property (strong) NSDictionary *cmdDictionary;
@property id connection;
@property NSString *yPos,*lastYPos,*xPos,*lastXPos;//,*mutedYPos;
// indices remain valid after a track height change
@property NSInteger yIndex,lastYIndex,mutedYIndex;
@property NSMutableArray *trackPos;

@property (weak) IBOutlet NSTextField *responseField;

- (IBAction)requestTextFieldReturnAction:(id)sender;

@property (nonatomic, strong, readwrite) NSMutableArray *       services;           // of NSNetService
@property (unsafe_unretained) IBOutlet NSTextView *rxTextView;
- (IBAction)onClearRxText:(id)sender;

@property NSDate *lastRx;
@property bool showTimeOfDay;
@property NSDate *punchDate;
@property id delegate;
// access

-(void)txMsg:(NSString *)msg;
//-(void)setDefaultServer:(NSString*)server;


//-(void)muteTrackForYPos:(float)yPos :(bool)mute;
-(void)muteTrackForIndex:(NSInteger)index :(bool)mute;
-(NSInteger)getIndexForYPos:(NSString*)yPos;
-(void)appendToLog:(NSString*)msg;
//-(NSInteger)yIndexForYPos;
@end
