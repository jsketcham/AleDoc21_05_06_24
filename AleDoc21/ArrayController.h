//
//  ArrayController.h
//  TestDoc
//
//  Created by James Ketcham on 7/9/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Document;

@interface ArrayController : NSArrayController<NSTableViewDataSource>

@property Document *document;

@end
