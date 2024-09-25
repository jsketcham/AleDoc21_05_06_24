//
//  FileDropTextField.m
//  AleDoc
//
//  Created by Jim on 1/25/21.
//  Copyright © 2021 James Ketcham. All rights reserved.
//

#import "FileDropTextField.h"

@implementation FileDropTextField

//- (void)drawRect:(NSRect)dirtyRect {
//    [super drawRect:dirtyRect];
//
//    // Drawing code here.
//}

// using /sampler/dropbutton.m as an example

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
    
    self.stringValue = @"0";    // init to an integer string
    
    [self registerForDraggedTypes:[NSArray arrayWithObjects:NSPasteboardTypeString,NSPasteboardTypeFileURL,nil]];
    
    // get our url if any
    // it is a non-property list item and must be encoded
    
    _key = [NSString stringWithFormat:@"FileDropTextField%d",(int)[self tag]];  // different file drop text fields must have different tags
    
//    NSMutableData *data = [[NSMutableData alloc] init];
    NSKeyedArchiver *arch = [[NSKeyedArchiver alloc] initRequiringSecureCoding:false];
    //NSKeyedArchiver *arch = [[NSKeyedArchiver alloc]initForWritingWithMutableData:data];
    [arch encodeObject:@"" forKey:@"_fileUrl"];
    [arch finishEncoding];
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *registrationDefaults = [NSDictionary dictionaryWithObjectsAndKeys:arch.encodedData ,_key,nil];
    [defaults registerDefaults:registrationDefaults];
    
    NSData *data = [defaults objectForKey:_key];
    
//    if(!data) NSLog(@"DropButton null ptr");
    NSError *error;
//    NSKeyedUnarchiver *unarch = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
//    NSKeyedUnarchiver *unarch = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    
    NSURL *aURL = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSURL class] fromData:data error:&error];//[unarch decodeObjectForKey:@"_fileUrl"];
    
    if(aURL){
        
        [self setFileUrl:aURL];
        [self getFileNameComponents];
        
        NSString *nameNoExtension = [_fileName stringByDeletingPathExtension];
        if(nameNoExtension != nil && [nameNoExtension length] > 0){
            
            // TODO show delay in the text box
//            [self setTitle:nameNoExtension];
            [self setToolTip:nameNoExtension]; // the entire name

        }
    }
//    [self readRemoteDelayFile];
    
}

-(void)getFileNameComponents{
    
    @try {
        _fileName = _fileUrl.lastPathComponent;
        _folder = [[_fileUrl.path stringByDeletingLastPathComponent] stringByAppendingString:@"/"];
    }
    @catch (NSException *exception) {
        _fileName = @"";
        _folder = @"";
    }
}
#pragma mark -
#pragma mark ***** helper fns *****
//-(void)readRemoteDelayFile{
//    NSError *error;
//    // the delay file may change between record passes, read it every time
//    NSString *fileContents = [NSString stringWithContentsOfURL:_fileUrl encoding:NSUTF8StringEncoding error:&error];
//
//    NSLog(@"fileContents: %@ error.code: %ld",fileContents,error.code);
//    // trim whitespace and newlines, split into lines
//
//    if(error.code != 0) return; // some error, exit
//
//    NSArray *array = [[fileContents stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//
//    if(array.count > 0){
//        self.stringValue = array[0];
//    }
//}
-(NSInteger)remoteDelay{
    return [self.stringValue intValue];
}
//#pragma mark -
//#pragma mark ***** setters, getters *****
//-(void)setFileUrl:(NSURL *)fileUrl{
//
//}
//-(NSURL*)fileUrl{
//
//}

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
        // https://stackoverflow.com/questions/46837475/backgroundcolor-of-nstextfield
        self.drawsBackground = true;
        self.backgroundColor = NSColor.blueColor;
        
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
    self.drawsBackground = true;
    self.backgroundColor = NSColor.whiteColor;

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
    self.drawsBackground = true;
    self.backgroundColor = NSColor.whiteColor;

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
            
//            if(_delegate) [_delegate stopAudio:_folder fileName:_fileName];
            
            //if the drag comes from a file, set the button title to the filename w/o extension
            [self setFileUrl: [NSURL URLFromPasteboard: [sender draggingPasteboard]]];
            [self getFileNameComponents];
            
//            NSMutableData *data = [[NSMutableData alloc] init];
            NSKeyedArchiver *arch = [[NSKeyedArchiver alloc] initRequiringSecureCoding:false];
            //NSKeyedArchiver *arch = [[NSKeyedArchiver alloc]initForWritingWithMutableData:data];
            [arch encodeObject:_fileUrl forKey:@"_fileUrl"];
            [arch finishEncoding];
            
            [[NSUserDefaults standardUserDefaults] setObject:arch.encodedData forKey:_key];
            
            // http://stackoverflow.com/questions/7223065/get-filename-and-extension-from-filepath-programmatically-cocoa
            NSString *fileName = [[_fileUrl lastPathComponent] stringByDeletingPathExtension];
            
            NSString *path = [_fileUrl path];
            NSLog(@"dropped file: %@",path);
            [self setToolTip:fileName]; // the entire name
//            [self readRemoteDelayFile]; // get contents of file

            //            NSLog(@"%@",[_fileUrl absoluteString]);
            [self setNeedsDisplay: YES];
            
//            [self setState:NSOffState];
        }
    }
    
    return YES;
}

@end
