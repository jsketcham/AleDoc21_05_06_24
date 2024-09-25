//
//  LeftTableViewController.m
//  AleDoc2
//
//  Created by Pro Tools on 12/15/22.
//  Copyright © 2022 James Ketcham. All rights reserved.
//

#import "LeftTableViewController.h"
#import "AleDelegate.h"

@interface LeftTableViewController ()

@end

@implementation LeftTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    //12/15/23 
    [(NSTableView*)self.view registerForDraggedTypes:@[NSPasteboardTypeString,NSPasteboardTypeFileURL,NSPasteboardTypeURL]];
}
// MARK: --------- NSTableViewDelegate -------------

- (NSDragOperation)tableView:(NSTableView *)tableView
                validateDrop:(id<NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)dropOperation{
    
    NSLog(@"info.draggingSourceOperationMask) %ld",info.draggingSourceOperationMask);
    
    NSLog(@"info.draggingSource className %@",[info.draggingSource className]);

    if(dropOperation == NSTableViewDropOn){
        
        if ([[info.draggingSource className] isEqualToString:@"NSTableView"]){
            return ((NSTableView*)info.draggingSource).tag == tableView.tag ? NSDragOperationCopy : NSDragOperationNone;
        }
        
        return NSDragOperationLink; // assume it is a patch file
        
    }

    return NSDragOperationNone;
}
- (BOOL)tableView:(NSTableView *)tableView
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)dropOperation{
    
    NSDragOperation sourceDragMask = [info draggingSourceOperationMask];
    NSPasteboard *pboard = [info draggingPasteboard];

    if(![[info.draggingSource className] isEqualToString:@"NSTableView"]
       && [[pboard types] containsObject:NSPasteboardTypeFileURL]){
        
        NSString *fileURL;

        if ([[pboard types] containsObject:NSPasteboardTypeFileURL]) {
            fileURL = [[NSURL URLFromPasteboard:pboard] path];
    //        NSLog(@"fileURL %@",fileURL);
        }else{
            return NO;
        }

        NSString *fileName = [fileURL lastPathComponent];

        NSLog(@"file drop %@",fileName);
        NSURL *url = [NSURL fileURLWithPath:fileURL];

        AleDelegate *delegate = [NSApp delegate];
        [delegate.matrixWindowController fileWasDropped: url];
        return true;
        
    } else if([[info.draggingSource className] isEqualToString:@"NSTableView"]
       && [[pboard types] containsObject:NSPasteboardTypeString]
       && ((NSTableView*)info.draggingSource).tag == tableView.tag){
        
        @try{
                    
            // https://stackoverflow.com/questions/6167557/get-string-from-nspasteboard
            NSString* str = [pboard stringForType:NSPasteboardTypeString];    // index of the new ufx input
    //        NSLog(@"dropped item: %@",str);
            
            NSMutableArray *titles = [NSMutableArray arrayWithArray: tableView.tag == 0 ? _matrixView.delegate.inputArray: _matrixView.delegate.outputArray];
            
            for(NSDictionary *dict in [titles copy]){
                
                NSMutableArray *mutableArray = [NSMutableArray arrayWithArray:[dict objectForKey:CHILDREN_KEY]];
                
                for(NSDictionary *child in [mutableArray copy]){
                    
                    if([child[@"Channel"]integerValue] == row){
                        
                        NSDictionary *newChild = @{
                            @"ufxDictionaryItem" : str,
                            @"Channel" : child[@"Channel"],
                            @"Name" : child[@"Name"]
                        };
                        
                        [mutableArray replaceObjectAtIndex:[mutableArray indexOfObject:child] withObject:newChild];
                        
                        NSMutableDictionary *mutableDict = [NSMutableDictionary dictionaryWithDictionary:dict];
                        [mutableDict setObject:[NSArray arrayWithArray:mutableArray] forKey:CHILDREN_KEY];
                        [titles replaceObjectAtIndex:[titles indexOfObject:dict] withObject:[NSDictionary dictionaryWithDictionary:mutableDict]];
                        
                        switch(tableView.tag){
                            case 0:
                                _matrixView.delegate.inputArray = [NSArray arrayWithArray:titles];
                                break;
                            case 1:
                                _matrixView.delegate.outputArray = [NSArray arrayWithArray:titles];
                               break;
                            default:
                                break;
                        }
                        
                        [_matrixView.delegate makeRowColTitles];    // sets UFX MIDI

                        return true;
                        
                    }
                }
                
                
            }
            
            return false;

        }@catch(id anException){
            
            return false;
            
        }
        
        return false;
    }
    
    return false;
    
}
- (IBAction)onDoubleAction:(id)sender {
    
//    NSLog(@"onDoubleAction");
    
    if([sender isKindOfClass:[NSTableView class]]){
        
        NSTableView *tableView = (NSTableView*)sender;
        
        NSInteger row = [tableView selectedRow];
        
        NSMutableArray *outputArray = [NSMutableArray arrayWithArray:_matrixView.delegate.outputArray];
        
        for(NSDictionary *dict in [outputArray copy]){
            
            NSArray *array = [dict objectForKey:CHILDREN_KEY];
            
            for(NSDictionary *child in [array copy]){
                
                if([child[@"Channel"]integerValue] == row){
                    
                    if(array.count == 2){
                        
                        NSArray *childArray;
                        
                        if([array[0][@"Name"] isEqualToString:@"L"]){
                            
                            childArray = @[
                                    @{
                                        @"ufxDictionaryItem" : array[0][@"ufxDictionaryItem"],
                                        @"Channel" : array[0][@"Channel"],
                                        @"Name" : @"Mono A"
                                    },
                                    @{
                                        @"ufxDictionaryItem" : array[1][@"ufxDictionaryItem"],
                                        @"Channel" : array[1][@"Channel"],
                                        @"Name" : @"Mono B"
                                    }];

                      }else if([array[0][@"Name"] isEqualToString:@"Mono A"]){
                          
                          childArray = @[
                                  @{
                                      @"ufxDictionaryItem" : array[0][@"ufxDictionaryItem"],
                                      @"Channel" : array[0][@"Channel"],
                                      @"Name" : @"L"
                                  },
                                  @{
                                      @"ufxDictionaryItem" : array[1][@"ufxDictionaryItem"],
                                      @"Channel" : array[1][@"Channel"],
                                      @"Name" : @"R"
                                  }];
                       }

                        if(childArray){
                            
                            NSMutableDictionary *mutableDict = [NSMutableDictionary dictionaryWithDictionary:dict];
                            [mutableDict setObject:childArray forKey:CHILDREN_KEY];

                            [outputArray replaceObjectAtIndex:[outputArray indexOfObject:dict] withObject:[NSDictionary dictionaryWithDictionary:mutableDict]];
                            
                            _matrixView.delegate.outputArray = [NSArray arrayWithArray:outputArray];
                            
                            [_matrixView.delegate makeRowColTitles];    // show the LR/Mono change, set gains
                            
                            return;

                        }
                    }
                }
            }
        }
    }

}

@end
