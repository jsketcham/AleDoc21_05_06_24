//
//  ColNameWindowController.m
//  AleDoc
//
//  Created by James Ketcham on 8/20/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import "ColNameWindowController.h"

@interface ColNameWindowController ()

@end

@implementation ColNameWindowController

@synthesize oldName = _oldName;
@synthesize anotherName = _anotherName;

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        _oldName = @"";
        _anotherName = @"";
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (IBAction)onCancel:(id)sender {
    
    [[NSApplication sharedApplication] stopModal];
    
    [[NSApplication sharedApplication] endSheet: [self window]
                                     returnCode: NSModalResponseCancel];//NSCancelButton];
    
}

- (IBAction)onApply:(id)sender {
    
    [[NSApplication sharedApplication] stopModal];
    
    [[NSApplication sharedApplication]  endSheet: [self window]
                                      returnCode: NSModalResponseOK];
    
}

@end
