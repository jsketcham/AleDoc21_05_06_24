//
//  StreamerWindowController.h
//  AleDoc21
// change
//  Created by Pro Tools on 8/31/23.
//  we had to replace the XIB to get 'bring window to front' to work

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

enum {
    TAG_ALWAYS_ON = 0,
    TAG_FADE_IN,
    TAG_BLACK_CUE_BLACK
};

@interface StreamerWindowController : NSWindowController

// global vars
@property NSInteger pictureTag;
@property double fadeSeconds;
@property bool streamerEnable;
@property bool punchEnable;
@property bool beepsEnable;
@property bool inhibitStreamerInPlayback;
@property NSColor *streamerColor;

-(void)triggerStreamer:(NSString*)tc;

@end

NS_ASSUME_NONNULL_END
