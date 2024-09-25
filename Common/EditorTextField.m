//
//  EditorTextField.m
//  AleDoc
//
//  Created by James Ketcham on 11/2/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import "EditorTextField.h"
#import "Document.h"
#import "AleDelegate.h"
#import "TCFormatter.h"

@implementation EditorTextField

//- (void)drawRect:(NSRect)dirtyRect {
//    [super drawRect:dirtyRect];
//    
//    // Drawing code here.
//}

-(void)textDidEndEditing:(NSNotification *)aNotification{
    
//    NSLog(@"text did end editing");
    
    AleDelegate *aleDelegate = (AleDelegate *)[NSApp delegate];
    Document *doc = [aleDelegate topDocument];
//    [doc selectionDidChange:false];  // cause updates of text and protools, no change to editor items
    // TODO how do we cause the cue sheet to show changes in our fields?
    [doc writeChanges]; // maybe save to disk
    [doc sendDialogToStreamerForDictionary];  // send text to streamer
    
    [super textDidEndEditing:aNotification];
    
//    if(_removeFormatter){
//        [[self cell] setFormatter:nil]; // remove formatter when we are done editing
//    }
    
}
-(void)textDidBeginEditing:(NSNotification *)notification{
    
//    if(_removeFormatter){
//        
//        // the preroll cells only have a formatter when we are entering values manually
//        // that is because we do not want them changing the punctuation
//        // we are changing between ft/frs and tc manually (prerolls are this way)
//        [[self cell] setFormatter:[[TCFormatter alloc]init]];
//        
//    }
    
}

@end
