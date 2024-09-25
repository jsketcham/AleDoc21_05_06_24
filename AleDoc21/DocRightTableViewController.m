//
//  DocRightTableViewController.m
//  AleDoc21
//
//  Created by Pro Tools on 1/20/23.
//

#import "DocRightTableViewController.h"

@interface DocRightTableViewController ()

@end

@implementation DocRightTableViewController

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
