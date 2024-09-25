//
//  EditorWindowController.h
//  WindowController
//
//  Created by ADR2 Utility on 10/27/14.
//  Copyright (c) 2014 ADR2 Utility. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum{
    NAME_BEFORE_TAG,
    NAME_AFTER_TAG
};

@interface EditorWindowController : NSWindowController<NSTableViewDataSource,NSTableViewDelegate>

@property bool inhibitStreamer;
@property NSString *preroll;
//@property NSString *prerollToHere;  // TODO: 2.00.00 goes away
@property NSString *nameNote;
@property NSInteger beforeAfterTag;

//@property NSColor *colorStreamer0;
@property NSColor *colorStreamer1;
@property NSColor *colorStreamer2;
@property NSColor *colorStreamer3;
@property NSColor *colorStreamer4;
@property NSColor *colorStreamer5;
@property NSColor *colorStreamer6;  // V1.00.23

@property (strong) IBOutlet NSArrayController *arrayController;
//@property (weak) IBOutlet NSTableView *tableView;

//@property NSMutableArray *tableContents;
//- (IBAction)onTest:(id)sender;

// access
//-(void)saveBackingImage;
-(void) bindFields:(NSString*)cueID :(NSString*)dialog :(NSString*)notes :(NSString*)actor :(NSString*)start :(NSString*)end :(NSDictionary*)dictionary;
//-(void)toggleXKey:(NSInteger)key;
-(void)bindChecks:(id)sender;
-(void)toggleToTc;
-(void)toggleToFt;
@end
