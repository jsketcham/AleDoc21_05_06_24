//
//  DocLeftTableViewController.h
//  AleDoc21
//
//  Created by Pro Tools on 1/20/23.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class Document;

@interface DocLeftTableViewController : NSViewController<NSTableViewDelegate>

@property Document *document;

@end

NS_ASSUME_NONNULL_END
