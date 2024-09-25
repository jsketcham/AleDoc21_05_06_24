//
//  BackgroundImageView.h
//  AleDoc
//
//  Created by James Ketcham on 4/18/15.
//  Copyright (c) 2015 James Ketcham. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BackgroundImageView : NSImageView<NSDraggingSource, NSDraggingDestination, NSPasteboardItemDataProvider>

@end
