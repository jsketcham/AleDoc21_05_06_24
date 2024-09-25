//
//  RightTableViewController.m
//  AleDoc2
//
//  Created by Pro Tools on 12/15/22.
//  Copyright © 2022 James Ketcham. All rights reserved.
//

#import "RightTableViewController.h"

@interface RightTableViewController ()

@end

@implementation RightTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    [(NSTableView*)self.view setDraggingSourceOperationMask:NSDragOperationCopy forLocal:false];
}

// MARK: --------- table view delegate -----------

- (id<NSPasteboardWriting>)tableView:(NSTableView *)tableView
              pasteboardWriterForRow:(NSInteger)row{
    
    return [NSString stringWithFormat:@"%ld",row];
}

@end
