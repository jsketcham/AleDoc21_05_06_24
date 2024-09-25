//
//  LeftTableViewController.h
//  AleDoc2
//
//  Created by Pro Tools on 12/15/22.
//  Copyright © 2022 James Ketcham. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MatrixView.h"
#import "MatrixWindowController.h"

NS_ASSUME_NONNULL_BEGIN

@interface LeftTableViewController : NSViewController<NSTableViewDelegate>

// access to rowTitles, colTitles, delegate.ufxInputDictionaryArray, delegate.ufxOutputDictionaryArray
@property MatrixView *matrixView;

@end

NS_ASSUME_NONNULL_END
