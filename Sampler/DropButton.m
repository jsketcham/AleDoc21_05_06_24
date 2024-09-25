//
//  DropButton.m
//  AleDoc
//
//  Created by James Ketcham on 9/2/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import "DropButton.h"
#import "ObjCPlayFile.h"
#import "SamplerWindowController.h"

#define LOOP_KEY @"LOOP_KEY"    // 2.00.00

@implementation DropButton
@synthesize delegate = _delegate;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}
-(void)awakeFromNib{
    
    _folder = @"";
    _fileName = @"";
    
    _objCPlayFile = [[ObjCPlayFile alloc] init];    // each sampler button has its own player
    
    [self registerForDraggedTypes:[NSArray arrayWithObjects:NSPasteboardTypeString,NSFilenamesPboardType,nil]];
    
    // get our url if any
    // it is a non-property list item and must be encoded
    // 2.00.00 save the URL path (NSString*)
    
    _key = [NSString stringWithFormat:@"%@%d",LOOP_KEY,(int)[self tag]];
//    NSLog(@"_key %@",_key);
        
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *registrationDefaults = [NSDictionary dictionaryWithObjectsAndKeys:@"" ,_key,nil];
    [defaults registerDefaults:registrationDefaults];
    
    NSString *urlString = [[NSUserDefaults standardUserDefaults]objectForKey:_key];
    NSURL *aURL = [NSURL fileURLWithPath:urlString];//[unarch decodeObjectForKey:@"_fileUrl"];
    
    if(aURL){
        
        [self setFileUrl:aURL];
        [self getFileNameComponents];
        
//        NSString *nameNoExtension = [_fileName stringByDeletingPathExtension];
//        if(nameNoExtension != nil && [nameNoExtension length] > 0){
//
//            [self setTitle:nameNoExtension];
//            [self setToolTip:nameNoExtension]; // the entire name
//
//        }
    }
    
}
//- (void)drawRect:(NSRect)dirtyRect
//{
//    [super drawRect:dirtyRect];
//
//    // Drawing code here.
//}
-(void)getFileNameComponents{
    
    @try {
        _fileName = _fileUrl.lastPathComponent;
        _folder = [[_fileUrl.path stringByDeletingLastPathComponent] stringByAppendingString:@"/"];
    }
    @catch (NSException *exception) {
        _fileName = @"";
        _folder = @"";
    }
    
    NSString *nameNoExtension = [_fileName stringByDeletingPathExtension];
    if(nameNoExtension != nil && [nameNoExtension length] > 0){
        
        [self setTitle:nameNoExtension];
        [self setToolTip:nameNoExtension]; // the entire name

    }
}

#pragma mark -
#pragma mark ***** drag and drop methods *****

#pragma mark - Destination Operations

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    /*------------------------------------------------------
     method called whenever a drag enters our drop zone
     --------------------------------------------------------*/
    
    NSLog(@"draggingEntered");
    
    // Check if the pasteboard contains image data and source/user wants it copied
    if (// [NSImage canInitWithPasteboard:[sender draggingPasteboard]] &&
        [sender draggingSourceOperationMask] &
        (NSDragOperationLink | NSDragOperationCopy) ) {
        
        //highlight our drop zone
        highlight=YES;
        
        [self setNeedsDisplay: YES];
        
        //accept data as a link operation (file drop) or copy (string drop)
        return NSDragOperationLink | NSDragOperationCopy;
    }
    
    return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
    /*------------------------------------------------------
     method called whenever a drag exits our drop zone
     --------------------------------------------------------*/
    //remove highlight of the drop zone
    highlight=NO;
    
    [self setNeedsDisplay: YES];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    //    NSLog(@"prepareForDragOperation");
    /*------------------------------------------------------
     method to determine if we can accept the drop
     --------------------------------------------------------*/
    
    //    printf("numberOfValidItemsForDrop: %d\n",(int)[sender numberOfValidItemsForDrop]);
    //finished with the drag so remove any highlighting
    highlight=NO;
    
    [self setNeedsDisplay: YES];
    
    //check to see if we can accept the data
    return [sender draggingSourceOperationMask] & (NSDragOperationLink | NSDragOperationCopy) ? true : false;
}
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    
    //    NSLog(@"performDragOperation");
    /*------------------------------------------------------
     method that should handle the drop data
     --------------------------------------------------------*/
    if ( [sender draggingSource] != self ) {
        
        NSDragOperation mask = [sender draggingSourceOperationMask];
        
        NSURL *fileUrl = [NSURL URLFromPasteboard: [sender draggingPasteboard]];
        
        if(fileUrl && (mask & NSDragOperationLink)){
            
            if(_delegate) [_delegate stopAudio:_folder fileName:_fileName];
            
            //if the drag comes from a file, set the button title to the filename w/o extension
            [self setFileUrl: [NSURL URLFromPasteboard: [sender draggingPasteboard]]];
            [self getFileNameComponents];
                        
            [[NSUserDefaults standardUserDefaults] setObject:fileUrl.path forKey:_key];
            // http://stackoverflow.com/questions/7223065/get-filename-and-extension-from-filepath-programmatically-cocoa
//            NSString *fileName = [[_fileUrl lastPathComponent] stringByDeletingPathExtension];
//
//            [self setToolTip:fileName]; // the entire name
//            [self setTitle:[NSString stringWithFormat:@"%@",fileName]];
            //            NSLog(@"%@",[_fileUrl absoluteString]);
            [self setNeedsDisplay: YES];
            
            [self setState:NSControlStateValueOff];
        }
    }
    
    return YES;
}

@end
