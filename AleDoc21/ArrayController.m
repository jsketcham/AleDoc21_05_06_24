//
//  ArrayController.m
//  TestDoc
//
//  Created by James Ketcham on 7/9/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//
//  we subclassed NSArrayController to have a NSTableViewDataSource for drag/drop

#import "ArrayController.h"
#import "Document.h"

@implementation ArrayController

@synthesize document = _document;

#pragma mark -
#pragma mark ------------------- NSTableViewDataSource methods -------------------------

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView{
    
    if(_document && aTableView == _document.tableView){
//        NSLog(@"numberOfRowsInTableView %ld",_document.tableContents.count);
        return _document.tableContents ? _document.tableContents.count : 0;
    }
    
    return 0;
    
}
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex{
    
    if(_document && _document.tableContents && _document.tableContents.count > rowIndex){
        
        NSMutableDictionary *dictionary = [_document.tableContents objectAtIndex:rowIndex];
        NSString *s = [dictionary objectForKey:[aTableColumn identifier]];

        return s;
    }
    
    
    return @"";
}

// http://stackoverflow.com/questions/11095737/sorting-nstableview
- (void)tableView:(NSTableView *)aTableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{    
    [_document.tableContents sortUsingDescriptors:aTableView.sortDescriptors];
    [aTableView reloadData];    // this must be here for sort to display
}
#pragma mark -
#pragma mark ------------------- NSTableViewDataSource drag/drop methods -------------------------

- (NSDragOperation)tableView:(NSTableView*)tv
				validateDrop:(id <NSDraggingInfo>)info
				 proposedRow:(NSInteger)row
	   proposedDropOperation:(NSTableViewDropOperation)op
{
    
//	if (!_document || [info draggingSource] == _document.tableView)
//	{
//		return NSDragOperationNone;
//    }
    
    [tv setDropRow:row dropOperation:NSTableViewDropAbove];
    
    return NSDragOperationLink;
}

- (BOOL)tableView:(NSTableView*)tv
	   acceptDrop:(id <NSDraggingInfo>)info
			  row:(NSInteger)row
	dropOperation:(NSTableViewDropOperation)op
{
    
    NSPasteboard *pboard = [info draggingPasteboard];
    NSDragOperation sourceDragMask = [info draggingSourceOperationMask];
    
    if(!((sourceDragMask & NSDragOperationLink) && [[pboard types] containsObject:NSPasteboardTypeFileURL])){
        return NO;
    }

    NSString *fileURL;
    
    if ([[pboard types] containsObject:NSPasteboardTypeFileURL]) {
        fileURL = [[NSURL URLFromPasteboard:pboard] path];
//        NSLog(@"fileURL %@",fileURL);
    }else{
        return NO;
    }
    
    NSString *fileName = [fileURL lastPathComponent];
    
    if(fileName){
        [[tv window] setTitle:[fileName stringByDeletingPathExtension]];
    }
    
    NSURL *url = [NSURL fileURLWithPath:fileURL];
    NSError *error;
    
    if(_document){
        return [_document readFromURL:url ofType:@"" error:&error];
    }
    
    return false;
    
}

@end
