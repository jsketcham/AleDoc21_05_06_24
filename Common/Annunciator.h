//
//  Annunciator.h
//  TestAnnunciator
//
//  Created by James Ketcham on 11/15/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Annunciator;
@class AleDelegate;

@protocol AnnunciatorDelegate

//-(void)showDropdown:(id)sender;
-(void)leadingEdgeService:(id)sender;

@end

@interface Annunciator : NSImageView

//@property NSImage *greenBox;
//@property NSImage *redBox;
//@property NSImage *blueBox;
//@property NSImage *whiteBox;
//@property NSImage *clearBox;

@property NSImage *backImage;

@property NSString *text;
@property NSColor *textColor;
@property NSColor *backColor;
@property float point;
@property NSInteger onIndex;
@property NSInteger offIndex;
@property NSInteger mixedIndex;
@property NSInteger index;
@property NSDate *lastEdge; // to detect toggling states
@property NSTimeInterval timeSinceLastUpEdge;
@property NSInteger state;  // button-like
@property bool stateDidChange;
@property id delegate;
@property NSTimer *leadingEdgeTimer;

// access
//-(void)toggleState;

enum{
    CLEAR_INDEX,
    GREEN_INDEX,
    RED_INDEX,
    BLUE_INDEX,
    WHITE_INDEX,
    CONTROL_INDEX,
    YELLOW_INDEX
};

@end
