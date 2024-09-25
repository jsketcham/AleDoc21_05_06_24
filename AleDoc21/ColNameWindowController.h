//
//  ColNameWindowController.h
//  AleDoc
//
//  Created by James Ketcham on 8/20/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ColNameWindowController : NSWindowController

@property NSString *oldName;
@property NSString *anotherName;

- (IBAction)onCancel:(id)sender;
- (IBAction)onApply:(id)sender;

@end
