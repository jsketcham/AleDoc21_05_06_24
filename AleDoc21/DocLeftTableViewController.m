//
//  DocLeftTableViewController.m
//  AleDoc21
//
//  Created by Pro Tools on 1/20/23.
//

#import "DocLeftTableViewController.h"
#import "Document.h"

@interface DocLeftTableViewController ()

@end

@implementation DocLeftTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    [(NSTableView*)self.view registerForDraggedTypes:@[NSPasteboardTypeString]];
}
// MARK: --------- NSTableViewDelegate -------------

- (NSDragOperation)tableView:(NSTableView *)tableView
                validateDrop:(id<NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)dropOperation{
    
//    NSLog(@"NSTableViewDropOn %d source tag %ld our tag %ld",dropOperation == NSTableViewDropOn,(((NSTableView*)info.draggingSource).tag),tableView.tag);
    
    if(dropOperation == NSTableViewDropOn && (((NSTableView*)info.draggingSource).tag == tableView.tag)){
        
        return NSDragOperationCopy;
        
    }

    return NSDragOperationNone;
}
- (BOOL)tableView:(NSTableView *)tableView
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)dropOperation{
    
    if(((NSTableView*)info.draggingSource).tag != tableView.tag){
        return false;
    }
    @try{
        
        // https://stackoverflow.com/questions/6167557/get-string-from-nspasteboard
        NSString* str = [info.draggingPasteboard  stringForType:NSPasteboardTypeString];    // client column name index
        NSString *clientTitle = _document.clientTitles[str.integerValue][@"clientTitle"];
        
        NSMutableArray *titles = _document.titles;
        NSDictionary *title = titles[row];   // the item to edit
        NSDictionary *dict = @{@"wbTitle":title[@"wbTitle"],
                               @"clientTitle":clientTitle};
        
        [titles replaceObjectAtIndex:row withObject:dict];
        
        // TODO: this only works if tableContents and clientTableContents are same length
        
        if(_document.tableContents.count == _document.clientTableContents.count){
            
            for(int i = 0; i < _document.tableContents.count; i++){
                
                NSMutableDictionary *destDictionary =  _document.tableContents[i];
                NSDictionary *sourceDictionary = _document.clientTableContents[i];
                NSString *destKey = dict[@"wbTitle"];
                NSString *srcKey =  dict[@"clientTitle"];
                
                destDictionary[destKey] = sourceDictionary[srcKey];
            }
        }
        [_document sizeTableViewToContents];  // show/hide end tc

        [_document.tableView reloadData];

        return true;

    }@catch(id anException){
        
        return false;
        
    }
    
}
@end
