//
//  TableView.m
//  TestDoc
//
//  Created by James Ketcham on 7/9/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import "TableView.h"
#import "Document.h"

@interface TableView()

@property NSTimer *resizeOneshot;

@end

@implementation TableView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}
//-(void)resizeOneshotService{
//
//    Document *delegate = ( Document *)[self delegate];
//    if(delegate) [delegate sizeTableViewToContents];
//
//}
//-(void)awakeFromNib{
//
//    // resize in 1 second, do not know to get a notification that animation is done
//    [self setResizeOneshot:[NSTimer scheduledTimerWithTimeInterval:0.3  target: self selector:@selector(resizeOneshotService) userInfo:nil repeats: NO]];
//
//}

//- (void)drawRect:(NSRect)dirtyRect
//{
//    [super drawRect:dirtyRect];
//    
//    // Drawing code here.
//}
- (void)keyDown:(NSEvent *)event
{
//    printf("TableView.h keyDown\n");
    NSString  *characters;
    //    NSUInteger modifierFlags = [event modifierFlags];
    bool didHandleKeyDown = false;
    
    // get the pressed key
    characters = [event charactersIgnoringModifiers];
    
    if(characters.length <= 0) return;  // can never happen...
    
    int theChar = [characters characterAtIndex:0];
    
    if (theChar == 0x7f) {   // DELETE
        
        didHandleKeyDown = true;
        
        Document *delegate = ( Document *)[self delegate];
        
        // are we deleting rows or cols?
        NSIndexSet *rowIndexSet = [self selectedRowIndexes];
        NSIndexSet *colIndexSet = [self selectedColumnIndexes];
        
        if(rowIndexSet.count > 0) [delegate deleteSelectedRows];
        else if(colIndexSet.count > 0) [delegate deleteCols:colIndexSet];
        
    }
    
    if(!didHandleKeyDown) [super keyDown:event];
    
}
- (void)textDidEndEditing:(NSNotification *)aNotification{
    [super textDidEndEditing:aNotification];    // so the blue box comes back
//    return;

    if(self.delegate){
        [(Document*)self.delegate textDidEndEditing:aNotification]; // a routine we wrote, not the original notification

    }

}

@end
