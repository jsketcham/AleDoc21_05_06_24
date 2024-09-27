//
//  Document.m
//  TestDoc
//
//  Created by James Ketcham on 7/9/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//
// 2.10.02 use this dialog as home for all alerts, so they show over the cue sheet
// https://stackoverflow.com/questions/70761392/how-to-use-nsalert-sheet-modal-from-a-utility-class

#import "Document.h"
#import "AleDelegate.h"
#import "ColNameWindowController.h"
#import "EditorWindowController.h"
#import "StreamerWindowController.h"
#import "AdrClientWindowController.h"
#import "MatrixWindowController.h"
#import "TcCalculator.h"
#import "TCFormatter.h"
#import "ArrayController.h"
#import "AleDelegate.h"
#import "DocLeftTableViewController.h"
#import "DocRightTableViewController.h"
#import "AleDoc21-Swift.h"    // must be here to avoid a circular reference


#define RESIZE_TIMEOUT 0.4

//#define TIMECODE_START_KEY @"timecodeStart"
//#define START_KEY @"Start"
//#define END_KEY @"End"
//#define CUE_ID_KEY @"cueId"
//#define DIALOG_KEY @"dialog"
//#define NOTES_KEY @"notes"
//#define ACTOR_KEY @"actor"
//#define TRACK_KEY @"Track"

@interface Document()

@property NSTimer *locateOneshot;
@property (strong) IBOutlet DocLeftTableViewController *docLeftTableViewController;
@property (strong) IBOutlet DocRightTableViewController *docRightTableViewController;

@property (strong) IBOutlet NSButton *dialogInClipNameCheck;
@property NSString *compareKey;
@property (strong) IBOutlet NSView *docView;
@property NSTimer *resizeTimer;
@property NSString *logContents;
//@property NSInteger cueToMerge; // we merge text, we do not remove cues
@property (strong) IBOutlet NSLayoutConstraint *disclosureVerticalConstraint;

@property NSInteger disclosureState;
@property (strong) IBOutlet NSBox *setupBox;
@property (strong) IBOutlet NSLayoutConstraint *vertConstraint;

@property NSColor *foreColor;
@property NSColor *backColor;
@property float point;
@property bool startEntryEnable;
//@property NSStringEncoding stringEncoding;

@property NSTimer *recCycleTimer;

@property (strong) NSArray *colTitles;
@property NSArray *clientColTitles;
//@property NSDictionary *encodings; // string encoding dictionaries
//@property NSArray *encodingKeys;
//@property NSString *encodingKey;

- (IBAction)onBehaviorCombo:(id)sender;

@end

@implementation Document

NSInteger encoding = NSMacOSRomanStringEncoding;    // default file encoding

@synthesize tableContents = _tableContents;
@synthesize arrayController = _arrayController;
@synthesize colTitles = _colTitles;
@synthesize columnSynonymDictionary = _columnSynonymDictionary;
@synthesize headerDictionary = _headerDictionary;
@synthesize tcType = _tcType;
//@synthesize loopRecord = _loopRecord;
//@synthesize punchEnable = _punchEnable;
//@synthesize beepsEnable = _beepsEnable;
//@synthesize progressBarEnable = _progressBarEnable;
@synthesize beepsTrimFrames = _beepsTrimFrames;
//@synthesize cutAndPasteClipName = _cutAndPasteClipName;
@synthesize aleMini = _aleMini;
@synthesize sendButtonTitle = _sendButtonTitle;
@synthesize ctr = _ctr; // protools counter
@synthesize tc = _tc;   // protools mtc
@synthesize dialog = _dialog;
@synthesize cueID = _cueID;
//@synthesize session = _session;
@synthesize recordToComposite = _recordToComposite;
@synthesize characterInTrackName = _characterInTrackName;
@synthesize dialogInClipName = _dialogInClipName;
@synthesize notesInClipName = _notesInClipName;
@synthesize showAllCols = _showAllCols;
//@synthesize cueToMerge = _cueToMerge;

@synthesize foreColor = _foreColor;
@synthesize backColor = _backColor;

@synthesize tableContentsDisplayFormat = _tableContentsDisplayFormat;   // the format we are in, follows MIDI eventually
//@synthesize autoPlay = _autoPlay;
@synthesize timeCodeStart = _timeCodeStart;
@synthesize inhibitGetTrackPos = _inhibitGetTrackPos;
@synthesize cueCtr = _cueCtr;
@synthesize recordCycleDictionary = _recordCycleDictionary;   //2.10.00
@synthesize titles = _titles;
@synthesize clientTitles = _clientTitles;
@synthesize clientTableContents = _clientTableContents;
@synthesize clientColTitles = _clientColTitles;
@synthesize encodings = _encodings;
@synthesize recordCycleDictionaryState = _recordCycleDictionaryState;

@synthesize tcFormatterTableView = _tcFormatterTableView;
@synthesize encodingKey = _encodingKey;
@synthesize notes = _notes;

//@synthesize streamerEnable = _streamerEnable;

//@synthesize lastCycleRowDictionary = _lastCycleRowDictionary;

//@synthesize circleRowDictionary = _circleRowDictionary;
- (id)init
{
    self = [super init];
    if (self) {
        
        self.tcFormatterTableView = [[TCFormatter alloc] init];
        
        //        [self setAleMini:[(AleDelegate*)[NSApp delegate] isAleMini]];   // hide unused user interface items
        
        // Add your subclass-specific initialization here.
        // 10/11/23 2.10.02 changed test to 'hasPrefix' because there is
        // a customer who has both tc and ft/fr cue sheets, 'Time In'
        // and 'Time Out' works for both cases
        _columnSynonymDictionary = @{@"Name":@[@"CUEID",@"CONSOLIDATED LINE NUMBER"],   // scene name is not a synonym
                              @"Start":@[@"IN",@"START TIME",@"TIME IN"],
                              @"End":@[@"OUT",@"END TIME",@"TIME OUT"],
                              @"Dialog":@[@"DIALOGUE",@"LINE"],
                              @"Character":@[@"CHARACTER NAME",@"ACTOR"],
                              @"Notes":@[@"PUBLIC NOTES",@"DIRECTOR'S NOTE"]};
        
        // mandatory ALE header items
        
        _headerDictionary = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                             @"TABS",@"FIELD_DELIM",
                             @"NTSC",@"VIDEO_FORMAT",
                             @"01",@"TAPE",
                             @"24",@"FPS",
                             @"TC",@"DISPLAY_FORMAT",   // assume the files will be in tc
                             nil];
        
        //        NSLog(@"init _headerDictionary[DIALOG_KEY] %@",_headerDictionary[DIALOG_KEY]);
        
        _tableContents = [[NSMutableArray alloc] init];
        
        tcf = [[TCFormatter alloc] init]; [tcf setDelegate:self];
        tcc = [[TcCalculator alloc] init];
        
        //        NSMutableData *data = [[NSMutableData alloc]init];
        NSKeyedArchiver *arch = [[NSKeyedArchiver alloc]initRequiringSecureCoding:false];//[[NSKeyedArchiver alloc]initForWritingWithMutableData:data];
        
        [arch encodeObject:[NSColor whiteColor] forKey:@"foreColor"];
        [arch encodeObject:[NSColor blackColor] forKey:@"backColor"];
        
        [arch finishEncoding];
        
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *registrationDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                      @"0",@"beepsTrimFrames",
                      @"0",@"characterInTrackName",
                      @"0",@"dialogInClipName",
                      [NSNumber numberWithFloat:36.0],@"point",
                      arch.encodedData,@"color",
                      [NSNumber numberWithBool:0],@"followMtcEnable",
                      [NSNumber numberWithInteger:0],@"behaviorIndex",
                      [NSNumber numberWithBool:YES],@"showTake",
                      [NSNumber numberWithBool:YES],@"hasColumnHeaders",
                      [NSNumber numberWithBool:NO],@"keepUnderscores",
                      [NSNumber numberWithInteger:1],@"cueCtr",
                      nil];
        
        [defaults registerDefaults:registrationDefaults];
        
        _timeCodeStart = @"01:00:00:00";    // assumption
        
        //        // register for display format change notification
        //        [(NSNotificationCenter *)[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayFmtDidChange:) name:@"displayFmtDidChange" object:nil];
        
        self.encodings = @{@"UTF-8":@"4",
        @"Mac OS Roman":@"30",
        @"Latin 1":@"5",
        @"ASCII":@"1",
        @"Unicode":@"10"};
        
        self.encodingKeys = @[@"UTF-8"
                              ,@"Mac OS Roman"
                              ,@"Latin 1"
                              ,@"ASCII"
                              ,@"Unicode"
                            ]; // combo box, try in order (Mac OS Roman is most likely)
        
        self.encodingKey = _encodingKeys[0];    // default encoding

    }
    return self;
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"Document";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.

    [self setDisclosureState:NSControlStateValueOff];    // show setup stuff
    [self onDisclosureButton:nil];  // hide setup stuff
    
    _arrayController.document = self;
    _docLeftTableViewController.document = self;

    // title of window is 'Untitled', how does it get set? Is 'Window' in IB
    [_tableView setDraggingSourceOperationMask:NSDragOperationLink
                                      forLocal:YES];
    [_tableView setDraggingSourceOperationMask:NSDragOperationCopy
                                      forLocal:NO];
    [_tableView setDraggingSourceOperationMask:NSDragOperationMove
                                      forLocal:NO];
    [_tableView registerForDraggedTypes:[NSArray arrayWithObjects:NSPasteboardTypeString,NSPasteboardTypeFileURL,NSPasteboardTypeURL,nil]];

    // left table

    self.titles = [[NSMutableArray alloc]initWithArray:@[
                @{@"wbTitle":@"Name",       @"clientTitle":@"Name"      },
                @{@"wbTitle":@"Start",      @"clientTitle":@"Start"     },
                @{@"wbTitle":@"End",        @"clientTitle":@"End"       },
                @{@"wbTitle":@"Character",  @"clientTitle":@"Character" },
                @{@"wbTitle":@"Dialog",     @"clientTitle":@"Dialog"    },
                @{@"wbTitle":@"Notes",      @"clientTitle":@"Notes"     },
                @{@"wbTitle":@"Take",       @"clientTitle":@"Take"      },
                @{@"wbTitle":@"Track",      @"clientTitle":@"Track"     },
                @{@"wbTitle":@"Aux1",       @"clientTitle":@"Aux1"      },
                @{@"wbTitle":@"Aux2",       @"clientTitle":@"Aux2"      },
                @{@"wbTitle":@"Aux3",       @"clientTitle":@"Aux3"      },
                @{@"wbTitle":@"Aux4",       @"clientTitle":@"Aux4"      }]];
        
    // right table
        
    self.clientTitles = [[NSMutableArray alloc]initWithArray:@[
                @{@"clientTitle":@"Name"        },
                @{@"clientTitle":@"Start"       },
                @{@"clientTitle":@"End"         },
                @{@"clientTitle":@"Character"   },
                @{@"clientTitle":@"Dialog"      },
                @{@"clientTitle":@"Notes"       },
                @{@"clientTitle":@"Take"        },
                @{@"clientTitle":@"Track"       },
                @{@"clientTitle":@"Aux1"        },
                @{@"clientTitle":@"Aux2"        },
                @{@"clientTitle":@"Aux3"        },
                @{@"clientTitle":@"Aux4"        }]];
    
     self.colTitles = @[
                @"Name",
                @"Start",
                @"End",
                @"Character",
                @"Dialog",
                @"Notes",
                @"Take",
                @"Track",
                @"Aux1",
                @"Aux2",
                @"Aux3",
                @"Aux4"
     ];   // initializes tableview columns
    
    //

    [self setRecordToComposite:true];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSData *data = [defaults objectForKey:@"color"];
    NSError *error;
    NSKeyedUnarchiver *unarch = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
    //NSKeyedUnarchiver *unarch = [[NSKeyedUnarchiver alloc]initForReadingWithData:data];
    
    [self setForeColor:[unarch decodeObjectForKey:@"foreColor"]];
    [self setBackColor:[unarch decodeObjectForKey:@"BackColor"]];
    [self setPoint:[defaults floatForKey:@"point"]];
    [_behaviorCombo selectItemAtIndex:[defaults integerForKey:@"behaviorIndex"]];
    
//    if(_aleMini)[self setTimeCodeStart:@"01:00:00:00"]; // aleMini needs a tc start for proper display
    TCFormatter *formatter = [[_timeCodeStartTextField cell]formatter];
    [formatter setDelegate:nil];    // always is timecode format, convenient fact
    
    [self selectRow:0];
}

-(void)removeAllColumns{
    
    NSArray *cols = [[_tableView tableColumns] copy];   // immutable copy (not a ref to [_tableView tableColumns])
    
    for(int i = 0; i < cols.count; i++) [_tableView removeTableColumn:[cols objectAtIndex:i]];
    
}
-(void)addBoundColumn:(NSString*)colName{
    
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:colName];
    
    col.title = colName;
    [[col headerCell] setAlignment:NSTextAlignmentCenter];
    
    // set up the sort
    //http://stackoverflow.com/questions/11095737/sorting-nstableview
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:col.identifier ascending:YES selector:@selector(compare:)];
    [col setSortDescriptorPrototype:sortDescriptor];
    
    [_tableView addTableColumn:col];
    
    // set tc formatting for Start, End
    if([colName isEqualToString:@"Start"] || [colName isEqualToString:@"End"]){
        
        NSCell *dataCell = [col dataCell];
        TCFormatter *cellFormatter = [[TCFormatter alloc] init]; [cellFormatter setDelegate:self]; // we need to inform the cell formatter whether the file was imported as tc or ft/fr
        [dataCell setFormatter:cellFormatter];
        
    }
    
    // https://developer.apple.com/library/mac/samplecode/NSTableViewBinding/Listings/MyWindowController_m.html
    // software binding of cols
    
    NSString *keyPath = [NSString stringWithFormat:@"arrangedObjects.%@",colName];
    
    [col bind:@"value" toObject:_arrayController withKeyPath:keyPath options:nil];
    [_arrayController addObserver:col forKeyPath:colName options:NSKeyValueObservingOptionNew context:nil];
    

}

+ (BOOL)autosavesInPlace
{
    return NO;//YES;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
    @throw exception;
    return nil;
}

//- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
//{
//    // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
//    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
//    // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
//    NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
//    @throw exception;
//    return YES;
//}
-(NSInteger)currentRow{
    
    return [_tableView selectedRow];
}
//- (IBAction)onSendCueToProtools:(id)sender {
//    
////    NSInteger row = [_tableView selectedRow];
////    if(row < 0) return;
////    AleDelegate *aleDelegate = (AleDelegate*)[NSApp delegate];
////
////    NSMutableDictionary *dictionary = [_tableContents objectAtIndex:row];
////
////    NSString *start = [tcf tcForString:dictionary[@"Start"]];
////
////    if([aleDelegate respondsToSelector:@selector(locate:)]){
////
////        [aleDelegate performSelector:@selector(locate:) withObject:start];  // sends MIDI notes too
////    }
//    
//    // send the text to VM-15A, update editor window
//    NSNotification *aNotification = [[NSNotification alloc]init];
//    [self tableViewSelectionDidChange:aNotification];
//    
//}

- (IBAction)onClearScreen:(id)sender {
    
    //    if(![[NSApp delegate] isKindOfClass:[AleDelegate class]]) return;
    
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    delegate.overlayWindowController.viewController.textView.text = @"";
    delegate.overlayWindowController.viewController.cueIdTextView.text = @"";
    delegate.overlayWindowController.viewController.annunciatorTextView.text = @"";
}
-(NSMutableDictionary*)makeRowDictionary{
    
    NSMutableDictionary *contents = [[NSMutableDictionary alloc] init];
    
//®
    NSArray *colTitles = self.colTitles ?  self.colTitles : self.clientColTitles;
    
    if(colTitles){
        
        for(NSString *colTitle in colTitles){
            
            contents[colTitle] = @"";
        }
    }
    
    // mandatory items
    contents[@"Start"] = @"00:00:00:00";    // ALE mandatory
    contents[@"End"] = @"";      // ALE mandatory FIXME: can we do this?
    contents[@"Take"] = @"0";               // WB mandatory
    contents[@"Track"] = @"1";              // WB mandatory
    contents[@"Name"] = [NSString stringWithFormat:@"cue_%03d",(int)self.cueCtr++];     // ALE mandatory

    return contents;
    
}

- (IBAction)onInsertRowAbove:(id)sender {
    
    NSInteger index = [[_tableView selectedRowIndexes] firstIndex];
    
    if(index < 0) return;
    
    [_arrayController insertObject:[self makeRowDictionary] atArrangedObjectIndex:index];

}

-(NSString*)actor{
    
    return [self actorForDictionary];
    
}
-(NSString*)take{
    
    return [self takeForDictionary];
    
}
-(NSString*)track{
    
    return [self trackForDictionary];
}
-(void)inpointTrimFrames:(NSInteger)trimFrames{
    
    if(_recordCycleDictionary == nil){return;}
    
    NSString *tc = self.startForDictionary; if(!tc) return;
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    int tcType = [delegate getTcType];
    
    int frames;
    
    switch (_tableContentsDisplayFormat) {
        case DISPLAY_FMT_TC:
            
            tc = [tcf formatAsTc:tc]; if(![tcc isTc:tc]) return;
            frames = [tcc tcToBinary:tc withType:tcType];
            frames += trimFrames;
            tc = [tcc binaryToTc:frames withType:tcType];
            
            break;
            
        case DISPLAY_FMT_FT:
            
            tc = [tcf formatAsFeet:tc]; if(![tcc isFtFr:tc]) return;
            frames = [tcc ftToBinary:tc];
            frames += trimFrames;
            tc = [tcc binaryToFt:frames];
            
            break;
            
        default: return;
    }
    
    _recordCycleDictionary[@"Start"] = tc;
    
    // when the inpoint is changed, capture 1st line
    delegate.matrixWindowController.captureGuide = delegate.matrixWindowController.captureFirstLineInRehearse;    // capture first
    
}
-(bool)headerInTc{
    
    NSString *fmtString = [_headerDictionary objectForKey:@"DISPLAY_FORMAT"];
    
    if(!fmtString || [fmtString isEqualToString:@"TC"]) return true; // default is tc
    
    return false;
    
}

#pragma mark -
#pragma mark ------------------- overrides -------------------------
-(void)setFileURL:(NSURL *)fileURL{
    
    [super setFileURL:fileURL];
    //    [self cueSheetTitleFromWindow]; // our extra bit, the title is ready...
}

#pragma mark -
#pragma mark ------------------- url read/write -------------------------

-(void)writeChanges{
    
    NSError *outError;
    
    bool saveFileAfterChanges = [[NSUserDefaults standardUserDefaults] boolForKey:@"saveFileAfterChanges"];
    
    // if not a .ale, change extension to .ale
    
    //    if(saveFileAfterChanges && _readUrl && _readTypeName) [self writeToURL:_readUrl ofType:_readTypeName error:&outError];
    
    if(saveFileAfterChanges && _readUrl/* && _readTypeName*/){
        
        NSURL *writeURL = [_readUrl URLByDeletingLastPathComponent];
        NSString *lastPathComponent = [_readUrl lastPathComponent];
        NSString *extension = [lastPathComponent pathExtension];
        NSRange range = [lastPathComponent rangeOfString:extension];
        
        if( [extension caseInsensitiveCompare:@"ale"] != NSOrderedSame ) {
            
            lastPathComponent = [lastPathComponent substringToIndex:range.location - 1];
            lastPathComponent = [lastPathComponent stringByAppendingString:@".ale"];
            
        }
        writeURL = [writeURL URLByAppendingPathComponent:lastPathComponent];
        
        [self writeToURL:writeURL ofType:_readTypeName error:&outError];
        
        if(outError){
            NSLog(@"outError");
            
        }
        
        NSSaveOperationType saveOperation = NSSaveOperation;
        id changeCountToken = [self changeCountTokenForSaveOperation:saveOperation];
        
        [ self updateChangeCountWithToken:changeCountToken forSaveOperation:saveOperation];
    }
}
//-(void)timeCodeStartFromTableContents{
//    
//    // use the first timecode for the hours
//    
//    // if cue sheet is in timecode, set the timecode start from the first good "Start" item, hh:00:00:00
//    
//    for( NSMutableDictionary *item in _tableContents){
//        
//        NSString *t = [item objectForKey:[_headerDictionary objectForKey:START_KEY]];
//        
//        if([tcc isTc:t]){
//            
//            NSArray *array = [t componentsSeparatedByString:@":"];
//            
//            if(array.count)
//                [self setTimeCodeStart:[NSString stringWithFormat:@"%@:00:00:00",array[0]]];
//            
//            break;
//            
//        }
//        
//    }
//}
-(BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError{
    
    NSError *error;

    self.readTypeName = typeName;   // may need later, trying different encodings
    self.readUrl = url;
    
    if([self readAle:url] == false){
        
        for(NSString *key in _encodingKeys){    // _encodingKeys, in order of trying
            
            error = nil;
            NSInteger enc = ((NSString*)_encodings[key]).integerValue;
            [NSString stringWithContentsOfURL:url encoding:enc error:&error];
            
            if(error == nil){
                self.encodingKey = key;
                return true;
            }
        }

    }else{
        return true;
    }
        
    return false;
    
}
-(BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError{
    
    NSLog(@"writeToURL ofType %@",typeName);
    if(_tableContents == nil || _tableContents.count == 0) return false;

    NSString *extension = [url pathExtension];
    
    bool isAle = [[extension uppercaseString] isEqualToString:@"ALE"];

    NSString *aleString = @"";
    
    if(isAle){
        
        // export as .ale (with header)
        aleString = [aleString stringByAppendingString:@"Header\n"];
        
        for(NSString  *key in [_headerDictionary allKeys]){
            
            aleString = [aleString stringByAppendingString:[NSString stringWithFormat:@"%@\t%@\n",key,[_headerDictionary objectForKey:key]]];
            
        }
        
        aleString = [aleString stringByAppendingString:@"Column\n"];
        
        // Name, Start, End (ALE style column names)
        aleString = [aleString stringByAppendingString:[_colTitles componentsJoinedByString:@"\t"]];

        aleString = [aleString stringByAppendingString:@"\nData\n"];

    }else{
        
        // export as .txt or .tab (no header)
        
        // TODO: client column names
        // change to _colTitles being a copy of _clientColTitles, replacing synonyms
        aleString = [aleString stringByAppendingString:[_colTitles componentsJoinedByString:@"\t"]];
        aleString = [aleString stringByAppendingString:@"\n"];

    }

    for(int i = 0; i < _tableContents.count; i++){
        
        NSMutableDictionary *contents = _tableContents[i];
        
        NSMutableArray *array = [[NSMutableArray alloc] init];
        
        for(int j = 0; j < _colTitles.count; j++){
                            
            NSString *key = _colTitles[j];
            
            NSString *string = contents[key];
            if(string == nil) string = @"";

            // format Start and End cols as tc or ft+fr depending on display format
            if([key isEqualToString:@"Start"] || [key isEqualToString:@"End"]){
                
                string = [_tcFormatterTableView stringForObjectValue:string]; // tc or ft+fr
            }
            [array addObject:string];

        }
        aleString = [aleString stringByAppendingString:[array componentsJoinedByString:@"\t"]]; //
        aleString = [aleString stringByAppendingString:@"\n"];
   }

    // write document to file
    NSLog(@"aleString\n%@",aleString);
    NSData *aleData = [aleString dataUsingEncoding:encoding];
    
    return [aleData writeToURL:url atomically:TRUE];

    return false;
}

//-(BOOL)writeToURLxx:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError{
//    
//    NSLog(@"writeToURL ofType %@",typeName);
//    if(_tableContents == nil || _tableContents.count == 0) return false;
//
//    NSString *extension = [url pathExtension];
//    
//    bool isAle = [[extension uppercaseString] isEqualToString:@"ALE"];
//
//    
//    NSString *aleString = @"";
//    
//    if(isAle){
//        
//        // export as .ale (with header)
//        aleString = [aleString stringByAppendingString:@"Header\n"];
//        
//        for(NSString  *key in [_headerDictionary allKeys]){
//            
//            aleString = [aleString stringByAppendingString:[NSString stringWithFormat:@"%@\t%@\n",key,[_headerDictionary objectForKey:key]]];
//            
//        }
//        
//        aleString = [aleString stringByAppendingString:@"Column\n"];
//        
//        for(int i= 0; i < _colTitles.count; i++){
//            
//            aleString = [aleString stringByAppendingString:_colTitles[i]];
//            aleString = [aleString stringByAppendingString:@"\t"];
//
//        }
//        
//        aleString = [aleString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//        aleString = [aleString stringByAppendingString:@"\n"];
//
//        aleString = [aleString stringByAppendingString:@"Data\n"];
//
//        for(int i = 0; i < _tableContents.count; i++){
//            
//            NSMutableDictionary *contents = _tableContents[i];
//            
//            for(int j = 0; j < _colTitles.count; j++){
//                
//                NSString *key = _colTitles[j];
//                
//                NSString *string = contents[key];
//                if(string == nil) string = @"";
//                
//                // format Start and End cols as tc or ft+fr depending on display format
//                if([key isEqualToString:@"Start"] || [key isEqualToString:@"End"]){
//                    
//                    string = [_tcFormatterTableView stringForObjectValue:string]; // tc or ft+fr
//                }
//                
//                aleString = [aleString stringByAppendingString:string];
//                aleString = [aleString stringByAppendingString:@"\t"];
//                
//            }
//            
//            aleString = [aleString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//            aleString = [aleString stringByAppendingString:@"\n"];
//        }
//
//    }else{
//        
//        // export as .txt or .tab (no header)
//        // what about additional columns?
//        NSLog(@"_clientColTitles.count %ld",_clientColTitles.count);
//
//        for(int i= 0; i < _clientColTitles.count; i++){
//            
//            aleString = [aleString stringByAppendingString:_clientColTitles[i]];
//            aleString = [aleString stringByAppendingString:@"\t"];
//            
//        }
//        
//        // additional cols in table
//        for(int i= (int)_clientColTitles.count; i < _colTitles.count; i++){
//
//            aleString = [aleString stringByAppendingString:_colTitles[i]];
//            aleString = [aleString stringByAppendingString:@"\t"];
//            
//        }
//        
//        aleString = [aleString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//        aleString = [aleString stringByAppendingString:@"\n"];
//
//        for(int i = 0; i < _tableContents.count; i++){
//            
//            NSMutableDictionary *contents = _tableContents[i];
//            
//            for(int j = 0; j < _colTitles.count; j++){
//                                
//                NSString *key = _colTitles[j];
//                
//                NSString *string = contents[key];
//                if(string == nil) string = @"";
//                
//                // format Start and End cols as tc or ft+fr depending on display format
//                if([key isEqualToString:@"Start"] || [key isEqualToString:@"End"]){
//                    
//                    string = [_tcFormatterTableView stringForObjectValue:string]; // tc or ft+fr
//                }
//                
//                aleString = [aleString stringByAppendingString:string];
//                aleString = [aleString stringByAppendingString:@"\t"];
//
//            }
//            
//            aleString = [aleString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//            aleString = [aleString stringByAppendingString:@"\n"];
//       }
//
//    }
//    
//    // write document to file
//    /*
//     at one point we had info.plist, exported type identifiers, com.jsk.aledoc with
//     extensions 'tab' and 'ale'.
//     we now have com.jsk.tab, extension 'tab', which shows up in the 'save as' as a choice
//     using unix 'mdls' command to look at metadata of a 'tab' we wrote out, we see
//     
//     kMDItemContentType                 = "com.jsk.aledoc"
//     kMDItemContentTypeTree             = (
//         "com.jsk.aledoc",
//         "public.data",
//         "public.item"
//     )
//     
//     so, we have an old definition stuck in a registry somewhere.
//     We are fiddling with info.plist to see if we can read, write .ale, .txt, .tab files
//     
//     we want to a) remove the association of .ale and .tab with com.jsk.aleDoc
//     b) remove Imported Type Identifiers/com.jsk.aleDoc
//     c) run AdrDocument or AleDoc21 with the corrected info.plist, and get the association right
//     
//     we hope that Imported Type Identifiers/public.plain-text, extensions 'tab' and 'txt' works
//     
//     some clues:
//     https://talk.macpowerusers.com/t/remove-association-of-file-extension-to-app-open-with-to-none/22595
//     
//     */
//    NSLog(@"aleString\n%@",aleString);
//    NSData *aleData = [aleString dataUsingEncoding:encoding];
//    
//    return [aleData writeToURL:url atomically:TRUE];
//    
//}
//
//-(BOOL)writeToURLx:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError{
//    
//    if(_tableContents == nil || _tableContents.count == 0) return false;
//    
//    NSString *aleString = @"Header\n";
//    
//    for(NSString  *key in [_headerDictionary allKeys]){
//        
//        aleString = [aleString stringByAppendingString:[NSString stringWithFormat:@"%@\t%@\n",key,[_headerDictionary objectForKey:key]]];
//        
//    }
//    
//    aleString = [aleString stringByAppendingString:@"Column\n"];
//    
//    NSArray *cols = [_tableView tableColumns];
//    
//    for(int i= 0; i < cols.count; i++){
//        
//        aleString = [aleString stringByAppendingString:[NSString stringWithFormat:@"%@%@",((NSTableColumn*)[cols objectAtIndex:i]).identifier, i == cols.count - 1 ? @"\n" : @"\t"]];
//        
//    }
//    
//    aleString = [aleString stringByAppendingString:@"Data\n"];
//    
//    for(int i = 0; i < _tableContents.count; i++){
//        
//        NSMutableDictionary *contents = _tableContents[i];
//        
//        for(int j = 0; j < cols.count; j++){
//            
//            NSString *key = ((NSTableColumn*)cols[j]).title;
//            
//            NSString *string = contents[key];
//            if(string == nil) string = @"";
//            
//            // format Start and End cols as tc
//            if([key isEqualToString:@"Start"] || [key isEqualToString:@"End"]){
//                
//                string = [tcf stringForObjectValue:string]; // tc vals in dictionary are not necessarily formatted as tc
//            }
//            
//            aleString = [aleString stringByAppendingString:[NSString stringWithFormat:@"%@%@",string,j == cols.count - 1 ? @"\n" : @"\t"]];
//            
//        }
//    }
//    
//    NSData *aleData = [aleString dataUsingEncoding:NSUTF8StringEncoding];
//    
//    // file extension has to be .ale
//    NSString *extension = [url pathExtension];
//    
//    if(![[extension uppercaseString] isEqualToString:@"ALE"]){
//        
//        NSString *path = [url absoluteString];
//        path = [path stringByDeletingPathExtension];
//        path = [NSString stringWithFormat:@"%@.ale",path];
//        url = [NSURL URLWithString:path];
//    }
//    
//    [aleData writeToURL:url atomically:TRUE];
//    
//    //    [self cueSheetTitleFromWindow]; // so that when we rename cue sheets it appears TODO initial save on rename does not call this
//    
//    return true;   // ALE OUTPUT ONLY
//}
enum{
    ALE_STATE_IDLE,
    ALE_STATE_HEADER,
    ALE_STATE_COLUMN,
    ALE_STATE_DATA
};

-(NSArray*)replaceSynonyms:(NSArray*)cols{

    NSMutableArray *avidCols = [[NSMutableArray alloc] initWithArray:cols];
    
    for(int i = 0; i < avidCols.count; i++){
        
        NSString *strToReplace = cols[i];
        
        for(NSString *key in _columnSynonymDictionary.allKeys){
            
            NSArray *synonyms = _columnSynonymDictionary[key];
            
            for(NSString *synonym in synonyms){

                if([[strToReplace uppercaseString] hasPrefix:[synonym uppercaseString]]){
                    [avidCols replaceObjectAtIndex:i withObject:key];
                 
                    break;
                }
            }
        }
    }
    
    NSArray *result = [[NSArray alloc] initWithArray:avidCols];
    return result;
    
}
-(BOOL)readAle:(NSURL *)url{
    
    self.recordCycleDictionary = nil;
    
//    self.readUrl = nil; // for auto retry when encoding is changed
    
    NSError *error;
    NSMutableArray *colTitles;
    NSMutableArray *tableContents = [[NSMutableArray alloc]init];
    
    NSString *fileContents = [NSString stringWithContentsOfURL:url encoding:encoding error:&error];
    
//    NSLog(@"fileContents:\n%@",fileContents);
    
    if(error){
        return false;
    }
        
    fileContents = [fileContents stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    
    NSArray *strs;

    if([fileContents containsString:@"\n"]) {
        strs = [fileContents componentsSeparatedByString:@"\n"];
    }else if([fileContents containsString:@"\r"]) {
        strs = [fileContents componentsSeparatedByString:@"\r"];
    }
    
    int hasHeader = false;
    
    // 2.10.02 look at file contents to decide if it is an ALE file
    if(strs && strs.count > 0){
        hasHeader = [[strs[0] uppercaseString] isEqualToString:@"HEADER"];
    }
    
    // .TAB and .TXT files start with the column titles
    int ale_state = hasHeader ? ALE_STATE_IDLE : ALE_STATE_COLUMN;
    
    NSMutableDictionary *headerDictionary = [[NSMutableDictionary alloc]init];
    NSMutableDictionary *dictionary;
    
    for(NSString *str in strs){
        
        NSString *s = [str stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        
        if(s.length == 0){continue;}
        
        int i;  // must be outside of case statement
        
        NSArray *array = [s componentsSeparatedByString:@"\t"];
        
        switch(ale_state){
            case ALE_STATE_IDLE:
                if([[array objectAtIndex:0] caseInsensitiveCompare:@"Column"] == NSOrderedSame) {
                    ale_state = ALE_STATE_COLUMN;
                    break;
                }
                if([[array objectAtIndex:0] caseInsensitiveCompare:@"Header"] == NSOrderedSame) {
                    ale_state = ALE_STATE_HEADER;
                    break;
                }
                break;
            case ALE_STATE_HEADER:
                if([[array objectAtIndex:0] caseInsensitiveCompare:@"Column"] == NSOrderedSame) {
                    ale_state = ALE_STATE_COLUMN;
                    break;
                }
                headerDictionary[[array objectAtIndex:0]] = array.count > 1 ? [array objectAtIndex:1] : @"";
                break;
            case ALE_STATE_COLUMN:
                if([[array objectAtIndex:0] caseInsensitiveCompare:@"Data"] == NSOrderedSame) {
                    ale_state = ALE_STATE_DATA;
                    break;
                }
                // replace ' ' with '_' in titles, replace synonyms
//                array = [[s stringByReplacingOccurrencesOfString:@" " withString:@"_"] componentsSeparatedByString:@"\t"];
                
                colTitles = [[NSMutableArray alloc]initWithArray: array];
                
                if(!hasHeader){ale_state = ALE_STATE_DATA;} // .TAB and .TXT case

                break;
            case ALE_STATE_DATA:
                
                dictionary = [[NSMutableDictionary alloc]init];

                for(i = 0; i < colTitles.count; i++){
                    
                    dictionary[colTitles[i]] = array.count > i ? array[i] : @"";
                    
                }
                
                [tableContents addObject:dictionary];
                
                break;
            default: return false;
        }
    }
    // tickle for github
    if(ale_state == ALE_STATE_DATA){
        
        // add 'Take' to colTitles if missing   2.10.02
        if(![colTitles containsObject:@"Take"]){
            
            [colTitles addObject:@"Take"];
        }

        // add 'Track' to colTitles if missing  2.10.02
        if(![colTitles containsObject:@"Track"]){
            
            [colTitles addObject:@"Track"];
        }

        if(hasHeader){self.headerDictionary = headerDictionary;}
        self.clientColTitles = [[NSArray alloc] initWithArray:colTitles];
        self.clientTableContents = [[NSArray alloc] initWithArray:tableContents];
        
        AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
        [delegate getSession:nil];  // 2.10.00 arms change detector
        
        // drag/drop case, window is already open
        [self selectRow:0];
        
        return true;    // or we get the indication that it was rejected
    }

    return false;
}

-(void)positionUnderMixerWindow{
        
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    if(![delegate editorWindowController]) return;
    
    NSWindow *mixerWindow = [[delegate editorWindowController]window];
    
    NSRect rect = [_docWindow frame];
    NSRect mixerRect = [mixerWindow frame];
    
    NSScreen *rightmostScreen = [delegate widestScreen];//[delegate rightmostScreen]; // rightmost full size screen
    
    // set document to maximum available height -100
    NSRect screenRect = [rightmostScreen frame];
    rect.size.height = screenRect.size.height - mixerRect.size.height - MATRIX_HEIGHT;
    
    rect.size.width = mixerRect.size.width;
    rect.origin.y = mixerRect.origin.y - rect.size.height;
    rect.origin.x = mixerRect.origin.x;
    
    [_docWindow setFrame:rect display:true];
    [_docWindow makeKeyAndOrderFront:nil];   // give it the focus
    [NSApp activateIgnoringOtherApps:YES];
    
//    if(delegate.matrixWindowController) [delegate.matrixWindowController positionUnderDocWindow];
    
    //    if(delegate.matrixWindowController){
    //
    //        NSWindow *matrixWindow = [delegate.matrixWindowController window];
    //
    //        NSRect matrixRect = matrixWindow.frame;
    //        matrixRect.size.width = mixerRect.size.width;
    //        matrixRect.size.height = MATRIX_HEIGHT;
    //        matrixRect.origin = rect.origin;
    //        matrixRect.origin.y -= MATRIX_HEIGHT;
    //
    //        [[delegate.matrixWindowController window] setFrame:matrixRect display:true];
    //        [[delegate.matrixWindowController window] makeKeyAndOrderFront:nil];   // give it the focus
    //        [NSApp activateIgnoringOtherApps:YES];
    //
    //    }
#define DPI 72.0
#define PAGE_WIDTH (8.5 * DPI)
#define PAGE_HEIGHT (11.0 * DPI)
    
}
-(void)sizeTableViewToContents{
    
    //    NSLog(@"Take sizeTableViewToContents 0 %@",_tableContents[0][@"Take"]);
    
    // FIXME problem with col headers not lining up with cols
    
    // in writing thePub_V2 we noticed that we were not making images and checking widths for all entries
    
    // size the columns
    // font is System Regular
    NSInteger enInPastSwitching = [[NSUserDefaults standardUserDefaults]integerForKey:@"enInPastSwitching"];
    NSArray *cols = [_tableView tableColumns];
    
    for(NSTableColumn *col in cols){
        
        if(self.showAllCols ) [col setHidden:false];  // show all
        else{
            
            [col setHidden:true];  // hide all, maybe un-hide
            if([col.title isEqualToString:@"Name"]){[col setHidden: false];}
            if([col.title isEqualToString:@"Character"]){[col setHidden: false];}
            if([col.title isEqualToString:@"Dialog"]){[col setHidden: false];}
            if([col.title isEqualToString:@"Notes"]){[col setHidden: false];}
            if([col.title isEqualToString:@"Start"]){[col setHidden: false];}
            if([col.title isEqualToString:@"End"]){[col setHidden: !enInPastSwitching];}
            if([col.title isEqualToString:@"Take"]){[col setHidden: false];}
            if([col.title isEqualToString:@"Track"]){[col setHidden: false];}
           
        }
    }
    // github tickler
    if(cols && cols.count && _tableContents && _tableContents.count){
        
        //        NSLog(@"Take sizeTableViewToContents 1 %@",_tableContents[0][@"Take"]);
        
        NSTableColumn *col = [cols objectAtIndex:0];
        NSCell *cell = [col dataCell];
        NSFont *font = [cell font];
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:font,NSFontAttributeName, nil];
        
        for(NSTableColumn *col in cols){

            col.minWidth = 40.0;
            
            float width = 40.0; // min width
            
            // size to title
            NSRect bounds = [col.title boundingRectWithSize:NSMakeSize(PAGE_WIDTH, PAGE_HEIGHT) options: NSStringDrawingUsesLineFragmentOrigin attributes:attributes];   //
            
            if(bounds.size.width > width) width = bounds.size.width;

            for(NSDictionary *dict in _tableContents){
                                
                NSString *msg = [dict objectForKey:col.title];
                
                if(msg == nil || msg.length == 0) continue;
                
                // ft/fr will fit in tc, make it a little bigger
                if([tcc isFtFr:msg]){
                    msg = @"00:00:00:00";
                }
                
                bounds = [msg boundingRectWithSize:NSMakeSize(PAGE_WIDTH, PAGE_HEIGHT) options: NSStringDrawingUsesLineFragmentOrigin attributes:attributes];   //
                
                if(bounds.size.width > width) width = bounds.size.width;
                
            }
            
            width += 5; // not so crowded...
            
            if(width > 800) width = 800;    // max width
            
            [col setWidth:width];
            
        }
        
//        [self positionUnderMixerWindow];
        
    }
//    [_tableView reloadData];
}
-(void)initTableWithTitles:(NSArray*)titles{
    
    [self removeAllColumns];
    
    // add the columns
    
    for(int i = 0; i < titles.count; i++){
        
        NSString *title = [titles objectAtIndex:i];
        
        [self addBoundColumn:title];
    }
}
-(void)sortByActor{
    
    //    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    [_tableView setSortDescriptors:[NSArray arrayWithObjects:
                                    [NSSortDescriptor sortDescriptorWithKey:@"Character" ascending:YES selector:@selector(compare:)],
                                    [NSSortDescriptor sortDescriptorWithKey:@"Start" ascending:YES selector:@selector(compare:)],
                                    nil]];
    
}
-(void)sortByCueID{
    
    //    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    [_tableView setSortDescriptors:[NSArray arrayWithObjects:
                                    [NSSortDescriptor sortDescriptorWithKey:@"Name" ascending:YES selector:@selector(compare:)],
                                    [NSSortDescriptor sortDescriptorWithKey:@"Start" ascending:YES selector:@selector(compare:)],
                                    nil]];
    
}
//-(void)onStop{
//
//    // service when protools stops
//    // if the row has changed and we are stopped, send the new cue
//    NSLog(@"document onStop");
//
//}

-(void)transportStart:(NSString*)tc{
    // dummy to get rid of a warning
}
-(void)transportStartIfNotPtComputer:(NSString*)tc{
    // dummy to get rid of a warning
}
-(void)trackFromDictionary:(NSDictionary*)dict{
    
    NSString *track = [dict objectForKey:@"Track"];
    NSInteger trackNumber = 0;
    if(track){
        trackNumber = [track integerValue] - 1;
    }
    
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    [delegate setCurrentTrack:trackNumber];
    
}

#pragma mark -
#pragma mark -------------- NSWindow delegate methods ---------------

//-(void)cueSheetTitleFromWindow{
////    if([[NSApp delegate] isKindOfClass:[AleDelegate class]]){
//        
//        AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
//        EditorWindowController *ed = [delegate editorWindowController];
////        if(ed)[ed setCueSheetTitle:[[_tableView window] title]];
////    }
//    
//    
//}
- (void)windowDidBecomeMain:(NSNotification *)notification{
    
    //    NSLog(@"windowDidBecomeMain");
    //    [self cueSheetTitleFromWindow];
//    [self enablesFromStreamer];
}


#pragma mark -
#pragma mark -------------- NSTableView delegate methods ---------------
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification{
    
    NSIndexSet *set = [_tableView selectedRowIndexes];
    NSLog(@"set count: %ld first index: %ld",set.count,set.firstIndex);
    if(!set || !set.count){
        // selected an empty row of the cue sheet
        self.recordCycleDictionary = nil;
        return;
    }
    
    // when 
    if(self.recordCycleDictionary != [_tableContents objectAtIndex:set.firstIndex]){
        
    }
    
    self.recordCycleDictionary = [_tableContents objectAtIndex:set.firstIndex];

}
- (IBAction)onColumnSelectorChanged:(id)sender {
    // TODO delay?
    [self sizeTableViewToContents];
}
#pragma mark -
#pragma mark ***** TableView helpers *****

-(void)textDidEndEditing:(NSNotification *)aNotification{
    
    //    if(_aleMini) return;    // no action for ale mini
    NSLog(@"textDidEndEditing %@",_recordCycleDictionary[@"Name"]);
    
    [self tableViewSelectionDidChange:aNotification];
    [self writeChanges];
    
    // set the current track
    // how can we get a notification when the Track column changes?
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    
    if(self.recordCycleDictionary){
        
        [delegate setCurrentTrack:[[self.recordCycleDictionary objectForKey:@"Track"] integerValue] - 1];
        [self sendDialogToStreamerForDictionary];
    }
}
-(void)makeFrontmost{
    
    [_tableView.window makeKeyAndOrderFront:nil];
    
}
#pragma mark -
#pragma mark ***** access *****
-(void)addRow: (NSString*)start :(NSString*)end :(NSString*)dialog{
    
    // for Foley 'grabAll' function
    
    NSMutableDictionary *dictionary = [self makeRowDictionary];
    
    [dictionary setObject:start forKey:@"Start"];
    [dictionary setObject:end forKey:@"End"];
    [dictionary setObject:dialog forKey:@"Dialog"]; // mandatory keys
    
    [_arrayController addObject:dictionary];

    // scroll to last row
    // http://stackoverflow.com/questions/1799728/how-to-make-nstableview-scroll-to-most-recently-added-row
    
    NSInteger numberOfRows = [_tableView numberOfRows];
    
    if(numberOfRows > 0){
        
        [_tableView scrollRowToVisible:numberOfRows - 1];
        
        // select the last row
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:numberOfRows - 1];
        [_tableView selectRowIndexes:indexSet byExtendingSelection:false];
        
    }
    
}
-(void)addRowToSelection: (NSString*)start :(NSString*)end :(NSString*)dialog{
    // for Foley 'addStreamerRow' function
    
    NSMutableDictionary *dictionary = [self makeRowDictionary];
    
    dictionary[@"Start"] = start;
    dictionary[@"End"] = end;
    dictionary[@"Dialog"] = dialog;
    
    NSIndexSet *indexSet = [_tableView selectedRowIndexes];
    if(indexSet.count == 0){return;}
    NSLog(@"firstIndex %ld lastIndex %ld",indexSet.firstIndex,indexSet.lastIndex);
    
    [_arrayController insertObject:dictionary atArrangedObjectIndex:indexSet.lastIndex + 1];
    indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(indexSet.firstIndex, indexSet.count + 1)];
    [_tableView selectRowIndexes:indexSet byExtendingSelection:true];
    
    // scroll to last row
//    // http://stackoverflow.com/questions/1799728/how-to-make-nstableview-scroll-to-most-recently-added-row
//
//    NSInteger numberOfRows = [_tableView numberOfRows];
//
//    if(numberOfRows > 0){
//
//        [_tableView scrollRowToVisible:numberOfRows - 1];
//
//        // add last row to selection
//        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:numberOfRows - 1];
//        [_tableView selectRowIndexes:indexSet byExtendingSelection:true];
//
//    }
    
}

-(void)addCueWithDialogAndStart:(NSString*) dialog :(NSString*)start{
    
    NSMutableDictionary *dictionary = [self makeRowDictionary];
    
    dictionary[@"Dialog"] = dialog;
    dictionary[@"Start"] = start;
    
    [_arrayController addObject:dictionary];    // 2.10.00, triggers binding

    // scroll to last row
    // http://stackoverflow.com/questions/1799728/how-to-make-nstableview-scroll-to-most-recently-added-row
    
    NSInteger numberOfRows = [_tableView numberOfRows];
    
    if(numberOfRows > 0){
        
        [_tableView scrollRowToVisible:numberOfRows - 1];
        
        // select the last row
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:numberOfRows - 1];
        [_tableView selectRowIndexes:indexSet byExtendingSelection:false];
        
    }

}

- (IBAction)onAddRow:(id)sender {
    
    
    NSMutableDictionary *dictionary = [self makeRowDictionary];
    
    // if doc.ctr is a valid value, use it as the start
    if([tcc isTc:_ctr] || [tcc isFtFr:_ctr]){
        
        dictionary[@"Start"] = [_ctr copy];
        dictionary[@"End"] = @"";
        
    }
    dictionary[@"Dialog"] = self.dialogForDictionary;
    [_arrayController addObject:dictionary];    // 2.10.00, triggers binding

    // scroll to last row
    // http://stackoverflow.com/questions/1799728/how-to-make-nstableview-scroll-to-most-recently-added-row
    
    NSInteger numberOfRows = [_tableView numberOfRows];
    
    if(numberOfRows > 0){
        
        [_tableView scrollRowToVisible:numberOfRows - 1];
        
        // select the last row
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:numberOfRows - 1];
        [_tableView selectRowIndexes:indexSet byExtendingSelection:false];
        
//        // 2.10.00 get the dialog for the cue if we are stopped TODO: clear this with Evan
//        AleDelegate *delegate = NSApp.delegate;
//        if(!delegate.ptHui.isPlay){
//            [delegate getDialog:nil];
//        }
        
        
    }
}

-(void)deleteRow:(NSInteger)row{
    
    [_arrayController removeObjectAtArrangedObjectIndex:row];   // 2.10.00 triggers binding
    
//    if(row >= 0){
//
//        [_tableContents removeObjectAtIndex:row];
//        [_tableView reloadData];
//    }
}
-(void)deleteRows:(NSIndexSet *)selectedRowIndexes{
    
    [_arrayController removeObjectsAtArrangedObjectIndexes:selectedRowIndexes];
    
//    if(selectedRowIndexes.count > 0){
//        [_tableContents removeObjectsAtIndexes:selectedRowIndexes];
//        [_tableView reloadData];
//
//    }
    // deselect all
    [_tableView deselectAll:nil];
    
}
-(void)deleteSelectedRows{
    
    NSIndexSet *rowIndexSet = [_tableView selectedRowIndexes];
    if(rowIndexSet.count > 0) [self deleteRows:rowIndexSet];
    // select the same rows
    [_tableView selectRowIndexes:rowIndexSet byExtendingSelection:false];
    
    [self writeChanges];    // 2.10.00 TODO: check with Evan on this
}
-(void)deleteCols:(NSIndexSet *)selectedColIndexes{
    
    if(selectedColIndexes.count > 0){
        
        NSArray *cols = [[_tableView tableColumns] copy];   // immutable copy
        
        for(int i = 0; i < cols.count; i++){
            
            if([selectedColIndexes containsIndex:i]){
                
                NSString *identifier = ((NSTableColumn*)[cols objectAtIndex:i]).identifier;
                [_tableView removeTableColumn: [_tableView tableColumnWithIdentifier:identifier]];
            }
            
        }
        
        [_tableView reloadData];

    }
    // deselect all
    [_tableView deselectAll:nil];
    
}


- (IBAction)onAddColumn:(id)sender {    // TODO: 2.00.00 never was done
}

- (IBAction)onInsertColumnLeft:(id)sender { // TODO: 2.00.00 never was done
}

- (IBAction)onRenameColumn:(id)sender {
    
    return; // TODO: 2.00.00 never was done temp no action
    
//    NSInteger col = [_tableView selectedColumn];
//
//    if(col < 0) return;
//
//    NSTableColumn *column = [[_tableView tableColumns] objectAtIndex:col];
//
//    ColNameWindowController  *controller = [[ColNameWindowController alloc] initWithWindowNibName:@"ColNameWindowController"];
//
//    [controller setOldName:[[column headerCell] stringValue]];
//
//    NSWindow *myWindow = [_tableView window];
//
//    // http://stackoverflow.com/questions/5364460/keep-nswindow-front
//    [[controller window] setLevel:[myWindow level] + 1];   // keep window in front of document window
//
//    [NSApp beginSheet:[controller window]
//       modalForWindow:myWindow
//        modalDelegate:self                                              //must have this to call 'sheetDidEnd'
//       didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)   // sets m_returnCode
//          contextInfo:nil];
//
//    [[NSApplication sharedApplication] runModalForWindow: [controller window]];
//    [[NSApplication sharedApplication] stopModal];
//
//    if(m_retCode != NSModalResponseOK) return;
//
//    [[column headerCell] setStringValue:[controller anotherName]]; // TODO what about Identifier?
//    [_tableView reloadData];
 
}
-(void)trimBeeps:(NSInteger)trim{
    
    self.beepsTrimFrames += trim;
    
//    NSInteger beepsTrimFrames = [[NSUserDefaults standardUserDefaults] integerForKey:@"beepsTrimFrames"];
//    beepsTrimFrames += trim;
//    [[NSUserDefaults standardUserDefaults] setInteger:beepsTrimFrames forKey:@"beepsTrimFrames"];
    
}
-(void)selectRow:(NSInteger)row{
    
    if(row < 0 || row > _tableContents.count) return;
    
    [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:false];
}
-(void)previousCue{
    
    if(_tableView.numberOfRows <= 0) return;
    
    NSInteger row = [_tableView selectedRow];
    
    row--;
    if(row < 0) row = 0;
    
    [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:false];
    
}
-(void)nextCue{
    
    if(!_tableView || _tableView.numberOfRows <= 0) return;
    if(!_tableContents || _tableContents.count == 0) return;
    
    NSInteger row = [_tableView selectedRowIndexes].firstIndex;
    
    if(row < 0 || row >= _tableView.numberOfRows){
        // case where there is no tableview yet
        row = 0;
        
    }else if(row < _tableView.numberOfRows - 1){
        row++;
    }else{
        row = _tableView.numberOfRows - 1;
    }
    
    self.recordCycleDictionary = [_tableContents objectAtIndex:row];
    NSLog(@"row %ld start %@",row, _recordCycleDictionary[@"Start"]);

    [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:false];
    
    [_tableView scrollRowToVisible:row];
    
}

-(void)cueWithRowIndex:(NSInteger)row{
    
    if(_tableView.numberOfRows <= 0 || row >= _tableView.numberOfRows) return;  // out of bounds
    
    [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:false];
    
    [_tableView reloadData];

}
-(void)unmergeCue{
    
    NSIndexSet *set = [_tableView selectedRowIndexes];
    if(set.count <= 1){return;} // never less than 1 cue
    NSRange range = NSMakeRange(set.firstIndex, set.count - 1);
    set = [[NSIndexSet alloc]initWithIndexesInRange:range];
    
    // triggers tableViewSelectionDidChange
    [_tableView selectRowIndexes:set byExtendingSelection:false];
}
-(void)mergeNextCue{
    
    // add to the end of the selected range
    NSIndexSet *set = [_tableView selectedRowIndexes];
    if(set.lastIndex == _tableContents.count - 1)  return;  // end of table
    
    set = [NSIndexSet indexSetWithIndex:set.lastIndex + 1];

    // triggers tableViewSelectionDidChange
    [_tableView selectRowIndexes:set byExtendingSelection:true];
}

-(NSString*)clipName{
    
    return [self clipNameForDictionary];
    
}
-(NSString*)clipNameWithDialog{
    
    return [self clipNameWithDialogForDictionary];
    
}

//-(void)addCueToDoc:(NSString*)name start:start end:(NSString*)end{
//
//    NSString *actor = [self actor]; // keep the actor name
//
//    NSInteger row = [_tableContents count]; // row index of the row we will add
//    [self onAddRow:nil];
//
//    //    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
//    NSString *actorKey = [_headerDictionary objectForKey:ACTOR_KEY];
//    NSString *nameKey = [_headerDictionary objectForKey:CUE_ID_KEY];
//
//    NSMutableDictionary *dictionary = [_tableContents objectAtIndex:row];
//    [dictionary setObject:name forKey:nameKey];
//    [dictionary setObject:start forKey:[_headerDictionary objectForKey:START_KEY]];
//    [dictionary setObject:end forKey:[_headerDictionary objectForKey:END_KEY]];
//    [dictionary setObject:@"0" forKey:@"Take"]; //NSLog(@"KEY  8");// increments before the take
//    [dictionary setObject:actor forKey:actorKey];
//
//    [_tableView reloadData];
//
//    // select the row we added so that we can cycle the new cue
//    NSIndexSet *set = [[NSIndexSet alloc] initWithIndex:row];
//    [_tableView selectRowIndexes:set byExtendingSelection:false];
//}
int m_retCode = NSModalResponseCancel;//NSCancelButton;  // initialize to something...

- (void)sheetDidEnd:(NSWindow *)sheet
         returnCode:(int)returnCode
        contextInfo:(void  *)contextInfo
{
    //    UNUSED(sheet);
    //    UNUSED(contextInfo);
    //printf("sheetDidEnd\n");
    m_retCode = returnCode;
}
-(NSString*)startTc{
    
    NSInteger row = [_tableView selectedRow];
    if(row < 0) return nil; // error return
    
    NSMutableDictionary *dictionary = [_tableContents objectAtIndex:row];

    return [tcf tcForString:dictionary[@"Start"]];
    
}
-(NSString*)endTc{
    
    NSInteger row = [_tableView selectedRow];
    if(row < 0) return nil; // error return
    
    NSMutableDictionary *dictionary = [_tableContents objectAtIndex:row];
    
    return [tcf tcForString:dictionary[@"End"]];

}
-(void)checkStartEnd:(NSMutableDictionary*)dictionary{
    
    NSString *start = [tcf tcForString:[self startForDictionary]];
    NSString *end = [tcf tcForString:[self endForDictionary]];
    
    if([tcc compareTc:end fromTc:start withType:(int)_tcType] <= 0){
        
        [self setEndTc:@"" ForDictionary:dictionary];
        //        [dictionary setObject:@"" forKey:@"End"];
        
    }
    
    end = [tcf tcForString:[self endForDictionary]];
    NSInteger index = [_tableContents indexOfObject:dictionary];
    NSLog(@"end: %@ index:%ld",end,index);
}
-(void)setEndTc:(NSString*)end{
    
    NSInteger row = [_tableView selectedRow];
    if(row < 0) return; // no row
    
    NSMutableDictionary *dictionary = [_tableContents objectAtIndex:row];
    [self setEndTc:end ForDictionary:dictionary];
    //    [dictionary setObject:[tcf tcForString:end] forKey:@"End"];
    
    [self checkStartEnd:dictionary];
}
-(void)setStartTc:(NSString*)start{
    
    // github tickler
    // 2.10.02 set start of first cue that is selected
    NSIndexSet *set = [_tableView selectedRowIndexes];
    
    if(set == nil){
        return;
    }
    NSInteger row = set.firstIndex;
    if(row < 0) return; // no row
    
    id theObject;
    NSString *error;
    [tcf getObjectValue:&theObject forString:start errorDescription:&error];
    
    NSMutableDictionary *dictionary = [_tableContents objectAtIndex:row];
    dictionary[@"Start"] = start;
    // when the start changes, arm the capture of the guide track
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    
    delegate.matrixWindowController.captureGuide = delegate.matrixWindowController.captureFirstLineInRehearse; // capture character's first line
    
    [self checkStartEnd:dictionary];
}

-(bool)existsRowWithStart:(NSString*)start{
    
    // avoid adding rows when keyboard is used to cue to a point more than once
    
    for(NSMutableDictionary *dictionary in _tableContents){
        
        NSString *t = [tcf tcForString:[self startForDictionary:dictionary]];
        if([t isEqualToString:start]) return true;
        
    }
    return false;
}
-(NSString*)pathToOriginals{
    NSError *error;
    BOOL isDir;
    
    NSString *pathToLog = [[[NSProcessInfo processInfo]environment]objectForKey:@"HOME"];
    pathToLog = [pathToLog stringByAppendingString:[NSString stringWithFormat:@"/Originals"]];
    NSFileManager *mgr = [[NSFileManager alloc] init];
    
    if(![mgr fileExistsAtPath:pathToLog isDirectory:&isDir]){
        
        // create the ~/Logs directory
        [mgr createDirectoryAtPath:pathToLog withIntermediateDirectories:false attributes:nil error:&error];
        
    }
    
    return pathToLog;
}

-(void)writeUrlToOriginalsDirectory:(NSURL*)url ofType:(NSString *)typeName{
    NSError *error;
    BOOL isDir;
    
    NSString *fName = [url lastPathComponent];
    
    NSString *pathToOriginals = [NSString stringWithFormat:@"%@/%@",[self pathToOriginals],fName];
    NSURL *writeUrl = [[NSURL alloc] initFileURLWithPath:pathToOriginals];
    NSFileManager *mgr = [[NSFileManager alloc] init];
    
    if(![mgr fileExistsAtPath:pathToOriginals isDirectory:&isDir]){
        
        // no file of this name is in the originals directory, write it
        NSString *fileContents = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
        [fileContents writeToURL:writeUrl atomically:true encoding:NSUTF8StringEncoding error:&error];
        
    }
    
}
-(NSString*)getPathToLog{
    NSError *error;
    BOOL isDir;
    
    NSString *session = ((AleDelegate*)[NSApp delegate]).session;
    if(!session || !session.length) return nil;
    
    NSString *pathToLog = [[[NSProcessInfo processInfo]environment]objectForKey:@"HOME"];
    pathToLog = [pathToLog stringByAppendingString:[NSString stringWithFormat:@"/Logs"]];
    NSFileManager *mgr = [[NSFileManager alloc] init];
    
    if(![mgr fileExistsAtPath:pathToLog isDirectory:&isDir]){
        
        // create the ~/Logs directory
        [mgr createDirectoryAtPath:pathToLog withIntermediateDirectories:false attributes:nil error:&error];
        
    }
    pathToLog = [pathToLog stringByAppendingString:[NSString stringWithFormat:@"/%@.log",session]];
    //    NSLog(@"pathToLog: %@",pathToLog);
    return pathToLog;
    
}
-(void)saveToLog{
    
    if(_recordCycleDictionary == nil){return;}    // nothing to save
    
    NSError *error;
    NSString *pathToLog = [self getPathToLog];
    
    // http://stackoverflow.com/questions/11106584/appending-to-the-end-of-a-file-with-nsmutablestring
    
    NSString *cueId = [self cueIDForDictionary];
    NSString *start = [self startForDictionary:_recordCycleDictionary];//[self startTcForDictionary:recordCycleDictionary];
    start = _tableContentsDisplayFormat == DISPLAY_FMT_TC ? [tcf formatAsTc:start] : [tcf formatAsFeet:start];
    NSString *take = [self takeForDictionary];
    NSString *track = [self trackForDictionary];
    NSString *actor = [self actorForDictionary];
    NSString *dialog = [self dialogForDictionary];
    
    NSString *streamer1 = [_recordCycleDictionary objectForKey:@"streamer1"]; if(!streamer1) streamer1 = @"";
    NSString *streamer2 = [_recordCycleDictionary objectForKey:@"streamer2"]; if(!streamer2) streamer2 = @"";
    NSString *streamer3 = [_recordCycleDictionary objectForKey:@"streamer3"]; if(!streamer3) streamer3 = @"";
    NSString *streamer4 = [_recordCycleDictionary objectForKey:@"streamer4"]; if(!streamer4) streamer4 = @"";
    NSString *streamer5 = [_recordCycleDictionary objectForKey:@"streamer5"]; if(!streamer5) streamer5 = @"";
    NSString *streamer6 = [_recordCycleDictionary objectForKey:@"streamer6"]; if(!streamer6) streamer6 = @"";
    
    NSString *cueNote = _cueNote;
    if(cueNote == nil) cueNote = @"";
    NSString *notes = [self notesForDictionary];
    
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    NSString *numRecTracks = [NSString stringWithFormat:@"%ld",[delegate.matrixWindowController numRecTracksTag]];
    _recordCycleDictionary[@"numRecTracks"] = numRecTracks;  // 2.00.00
    
    // log item: cueId\tStart\tTake\tTrack\tactor\t\dialog\tcueNote\tnotes\tmonitorFormat\n
    NSString *textToWrite = [NSString stringWithFormat:@"%@\t%@\t%@\t%@\t%@\t%@\t%@\t%@\t%@\t%@\t%@\t%@\t%@\t%@\t%@\n"
                             ,cueId,start,take,track,actor,dialog,cueNote,notes,numRecTracks,
                             streamer1,streamer2,streamer3,streamer4,streamer5,streamer6];
    
    NSString* contents = @"";
    
    contents = [NSString stringWithContentsOfFile:pathToLog
                                         encoding:NSUTF8StringEncoding
                                            error:&error];
    if(error) { // If error object was instantiated, handle it.
        NSLog(@"saveToLog ERROR while loading from file: %@", error);
        contents = @"";
    }
    
    contents = [contents stringByAppendingString:textToWrite];
    [contents writeToFile:pathToLog atomically:YES
                 encoding:NSUTF8StringEncoding
                    error:&error];
    
    [self setLogContents:contents]; // keep a copy of the log for doing the track copy to composite operation
    
}
#define NUM_ITEMS_IN_LOG_ENTRY 15
-(NSString*)startForLogTrack:(NSInteger)track{
    
    // AQ 109 5	01:07:50:11	5	6	Charmain	Ad-libs to Cutler			1
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    NSString *cueId = [self cueIDForDictionary];
    
    // break the log on \n (log entries)
    NSArray *logItems = [_logContents componentsSeparatedByString:@"\n"];
    
    for(NSString *logItem in logItems){
        
        NSArray *logItemArray = [logItem componentsSeparatedByString:@"\t"];
        
        if(logItemArray.count < NUM_ITEMS_IN_LOG_ENTRY) continue;
        
        NSString *trackString = [logItemArray objectAtIndex:3];
        
        // tracks are 1-32 in the log
        if([cueId isEqualToString:[logItemArray objectAtIndex:0]] && ([trackString integerValue] - 1) == (track + 1)){
            
            return [logItemArray objectAtIndex:1]; // start
        }
    }
    
    return [tcf tcForString:[self startForDictionary]];
    
    //    return [delegate.recordCycleDictionary objectForKey:@"Start"];  // not found, return a default
}

-(void)readLog{
    
    NSError *error;
    BOOL isDir;
    
    NSString *pathToLog = [self getPathToLog];
    
    NSFileManager *mgr = [[NSFileManager alloc] init];
    
    NSString* contents = @"";
    
    // clear takes and tracks for _tableContents, will get filled in if there is a log entry
    
    for(NSMutableDictionary *dict in _tableContents){
        
        [dict setObject:@"0" forKey:@"Take"]; //NSLog(@"KEY  9");
        [dict setObject:@"1" forKey:@"Track"];
        
    }
    
    if(![mgr fileExistsAtPath:pathToLog isDirectory:&isDir]){
        
        // clear the take and track
        
        return; // there is not a log file yet, don't try to read it
        
    }
    
    contents = [NSString stringWithContentsOfFile:pathToLog
                                         encoding:NSUTF8StringEncoding
                                            error:&error];
    if(error) { // If error object was instantiated, handle it.
        NSLog(@"readLog ERROR while loading from file: %@", error);
        return; // no log, exit
    }
    
    _logContents = contents;    // local copy for copy track to composite
    
    // break the log on \n (log entries)
    NSArray *logItems = [contents componentsSeparatedByString:@"\n"];
    
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    
    for(NSMutableDictionary *dict in _tableContents){
        
        NSString *cueId = [self cueIDForDictionary:dict];
        
        for(NSInteger i = logItems.count; i > 0;){
            
            NSString *logItem = [logItems objectAtIndex:--i];   // pre decrement (first index is past the end of the array)
            
            NSArray *logItemArray = [logItem componentsSeparatedByString:@"\t"];
            
            if(logItemArray.count < NUM_ITEMS_IN_LOG_ENTRY) continue;    // not enough items
            
            // 2.00.00 we don't see why mono and multi track have separate cases
            // 2.00.00 add numRecTracks to dict so we can set the monitor when we change cues
//            NSLog(@"%@ %@",cueId,[logItemArray objectAtIndex:0]);
            if([cueId isEqualToString:[logItemArray objectAtIndex:0]]){ // TODO match the monitor format to the current format
                
                dict[@"streamer1"] = [logItemArray objectAtIndex:9];
                dict[@"streamer2"] = [logItemArray objectAtIndex:10];
                dict[@"streamer3"] = [logItemArray objectAtIndex:11];
                dict[@"streamer4"] = [logItemArray objectAtIndex:12];
                dict[@"streamer5"] = [logItemArray objectAtIndex:13];
                dict[@"streamer6"] = [logItemArray objectAtIndex:14];
                
                dict[@"Start"] = [logItemArray objectAtIndex:1];
                dict[@"Take"] = [logItemArray objectAtIndex:2];
                dict[@"Track"] = [logItemArray objectAtIndex:3];

                break;  // found the last cueId, next dict
                
            }
        }
    }
    [_tableView reloadData];

    if(_recordCycleDictionary){
        [self sendTakeToStreamerForDictionary];
        [delegate setCurrentTrack:[[_recordCycleDictionary objectForKey:@"Track"] integerValue] - 1];
    }
}
#pragma mark -
#pragma mark ---------------- helper fns ----------------

-(void)colorsToUserDefault{
    //    NSMutableData *data = [[NSMutableData alloc]init];
    NSKeyedArchiver *arch = [[NSKeyedArchiver alloc] initRequiringSecureCoding:false];
    //    NSKeyedArchiver *arch = [[NSKeyedArchiver alloc]initForWritingWithMutableData:data];
    
    [arch encodeObject:[NSColor whiteColor] forKey:@"foreColor"];
    [arch encodeObject:[NSColor blackColor] forKey:@"backColor"];
    
    [arch finishEncoding];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:arch.encodedData forKey:@"color"];
    
}
#pragma mark -
#pragma mark ---------------- setters/getters ----------------
-(void)setNotes:(NSString *)notes{
    
    if(_recordCycleDictionary){
        _recordCycleDictionary[@"Notes"] = notes;
    }
    
}
-(NSString*)notes{
    
    if(_recordCycleDictionary){
        
        NSString *text = _recordCycleDictionary[@"Notes"];
        text = [text stringByReplacingOccurrencesOfString:@"^" withString:@"\n"];   // convert ^ to \n
        text = [text stringByReplacingOccurrencesOfString:@"\\r" withString:@"\n"]; // convert \\r to \n
        text = [text stringByReplacingOccurrencesOfString:@"\v" withString:@"\n"];  // convert VT to \n

        return text;
    }

    return @"";
}
-(void)setEncodingKey:(NSString *)encodingKey{
    _encodingKey = encodingKey;
    encoding = ((NSString*)_encodings[encodingKey]).intValue;
    
    // re-try the same file with a different encoding
    if(_readUrl && _readTypeName){
        
//        NSError *error;
        
        [self readAle:_readUrl];
        
    }
}
-(NSString *)encodingKey{
    return _encodingKey;
}

-(void)setTcFormatterTableView:(TCFormatter *)tcFormatterTableView{
    _tcFormatterTableView = tcFormatterTableView;
    _tcFormatterTableView.delegate = self;
}
-(TCFormatter *)tcFormatterTableView{
    return _tcFormatterTableView;
}
-(void)setRecordCycleDictionaryState:(NSInteger)recordCycleDictionaryState{
    _recordCycleDictionaryState = recordCycleDictionaryState;
}
-(NSInteger)recordCycleDictionaryState{
    return _recordCycleDictionaryState;
}
-(void)setClientTableContents:(NSArray *)clientTableContents{
    _clientTableContents = clientTableContents;
    
//    NSString *s = NSStringFromClass([_titles class]);
//    NSString *s2 = NSStringFromClass([_titles[0] class]);
//    NSLog(@"s %@ s2 %@",s, s2);
    
    if(!clientTableContents || clientTableContents.count == 0){
        return;
    }
    // show client column names intact, replace synonyms here
    NSArray *clientKeys = [clientTableContents[0] allKeys];
    NSArray *correctedClientKeys = [self replaceSynonyms:clientKeys];
    
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    for(NSDictionary *dict in clientTableContents){
        
        NSMutableDictionary *rowDictionary = [self makeRowDictionary];
        
        NSArray *keys = [rowDictionary allKeys];
        
        for(NSString *key in keys){
            
            if([correctedClientKeys containsObject:key]){
                NSString *clientKey = clientKeys[[correctedClientKeys indexOfObject:key]];
                
                rowDictionary[key] = dict[clientKey];
                
                // show the client key in left tableview ('titles')
               for(NSMutableDictionary *title in [_titles copy]){
                    if([title[@"wbTitle"] isEqualToString:key]){

                        NSDictionary *dict = @{@"wbTitle":key,
                                               @"clientTitle":clientKey};
                        
                        [self willChangeValueForKey:@"titles"];
                        [_titles replaceObjectAtIndex:[_titles indexOfObject:title] withObject:dict];
                        [self didChangeValueForKey:@"titles"];

                        break;
                    }
                }
                
            }
        }
        
        [array addObject:rowDictionary];
    }
    
    self.tableContents = array;
}
-(NSArray *)clientTableContents{
    return _clientTableContents;
}
-(void)setClientColTitles:(NSArray *)clientColTitles{
    
    _clientColTitles = clientColTitles;
    
    // rignt table dictionaries from clientColTitles
    
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    for(NSString *title in clientColTitles){
        
        [array addObject:@{@"clientTitle":title}];
        
    }
    
    self.clientTitles = [[NSArray alloc] initWithArray:array];
}
-(NSArray *)clientColTitles{
    return _clientColTitles;
}
-(void)setTableContents:(NSMutableArray *)tableContents{
    _tableContents = tableContents;
    [self sizeTableViewToContents];
}
-(NSMutableArray *)tableContents{
    return _tableContents;
}
-(void)setColTitles:(NSArray *)colTitles{
    
    // TODO: add missing columns
    
    _colTitles = colTitles;
    [self initTableWithTitles:_colTitles];
}
-(NSArray *)colTitles{
    return _colTitles;
}

-(void)recCycleTimerService{
    
    self.recordCycleDictionaryState = RECORD_CYCLE_DICTIONARY_IDLE;
    
    AleDelegate *delegate = NSApp.delegate;
    
    self.cueNote = @""; // new cue, erase old note
    
    delegate.matrixWindowController.captureGuide = delegate.matrixWindowController.captureFirstLineInRehearse;    // capture first line
    
    // FIXME set track name
    [delegate selectCurrentSixteenTrackMemory];
//    [delegate renameLastTrack];   // 2.10.02 do this on REC CYCLE start

    [delegate locateToInpoint:nil];
//    [delegate cueToCycleStart]; // 2.10.00 TODO: maybe cue to first frame of cue?

    NSString *trackString = [_recordCycleDictionary objectForKey:@"Track"];
    
    if(trackString){
        [delegate setCurrentTrack:[trackString integerValue] - 1];
    }
}

-(void)setRecordCycleDictionary:(NSMutableDictionary *)recordCycleDictionary{
    
    // 2.10.00 TODO: see aleDelegate.setRecordCycleDictionary for additional logic
    // case where selection is increased or decreased, or following tc
    // before gate keeper
    [self sendDialogToStreamerForDictionary:recordCycleDictionary];   // dialog overlay
    [self sendTakeToStreamerForDictionary:recordCycleDictionary];   // dialog overlay
    // gate keeper
    AleDelegate *delegate = NSApp.delegate;
    switch(delegate.cycleMotion){
        case CYCLE_MOTION_STARTING:
        case CYCLE_MOTION_ACTIVE:
            self.recordCycleDictionaryState = RECORD_CYCLE_DICTIONARY_PENDING;
            return;
        default:
            self.recordCycleDictionaryState = RECORD_CYCLE_DICTIONARY_IDLE;
            break;
    }

    [self bindEditorWindowFields:recordCycleDictionary];              // bind to editor window

    if(_recordCycleDictionary == recordCycleDictionary){
        return;
    }

    _recordCycleDictionary = recordCycleDictionary;
    
    [delegate.lpMini micSet:@"90787f" :false];  // fill button off 2.10.02

    if(!_recordCycleDictionary){
        
        [_tableView deselectAll:nil];   // new ALE, nothing selected
        return;

    }
    
    // 2.10.02 set streamer indicators
    NSString *s1 = [_recordCycleDictionary objectForKey:@"streamer1"];
    NSString *s2 = [_recordCycleDictionary objectForKey:@"streamer2"];
    NSString *s3 = [_recordCycleDictionary objectForKey:@"streamer3"];
    NSString *s4 = [_recordCycleDictionary objectForKey:@"streamer4"];
    NSString *s5 = [_recordCycleDictionary objectForKey:@"streamer5"];
    NSString *s6 = [_recordCycleDictionary objectForKey:@"streamer6"];

    [delegate txOsc:[NSString stringWithFormat:@"led 8,41,%@", (!s1 || [s1 isEqualToString:@""] ? @"false" : @"true")]];
    [delegate txOsc:[NSString stringWithFormat:@"led 8,49,%@", (!s2 || [s2 isEqualToString:@""] ? @"false" : @"true")]];
    [delegate txOsc:[NSString stringWithFormat:@"led 8,57,%@", (!s3 || [s3 isEqualToString:@""] ? @"false" : @"true")]];
    [delegate txOsc:[NSString stringWithFormat:@"led 8,42,%@", (!s4 || [s4 isEqualToString:@""] ? @"false" : @"true")]];
    [delegate txOsc:[NSString stringWithFormat:@"led 8,50,%@", (!s5 || [s5 isEqualToString:@""] ? @"false" : @"true")]];
    [delegate txOsc:[NSString stringWithFormat:@"led 8,58,%@", (!s6 || [s6 isEqualToString:@""] ? @"false" : @"true")]];

    // dialog is following timecode, don't cue
    if(delegate.ptHui.isPlay){
        return;
    }

    // set up the new _recordCycleDictionary
    self.recordCycleDictionaryState = RECORD_CYCLE_DICTIONARY_ACTIVE;

    // use a timer to delay these actions
    // this lets 'prev cue' and 'next cue' be quickly pressed
    // w/o cueing up for each one
    if(_recCycleTimer){[_recCycleTimer invalidate];}
    [self setRecCycleTimer:[NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(recCycleTimerService) userInfo:nil repeats:NO]];

}
-(NSDictionary*)recordCycleDictionary{
    return _recordCycleDictionary;
}
-(void)setCueCtr:(NSInteger)cueCtr{
    [[NSUserDefaults standardUserDefaults] setInteger:cueCtr forKey:@"cueCtr"];
}
-(NSInteger)cueCtr{
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"cueCtr"];
}

-(void)setTableContentsDisplayFormat:(NSInteger)tableContentsDisplayFormat{
    
    //    NSLog(@"setTableContentsDisplayFormat");
    
    if(_tableContentsDisplayFormat == tableContentsDisplayFormat) return;   // no change
    
    //    NSLog(@"setTableContentsDisplayFormat did change");
    
    _tableContentsDisplayFormat = tableContentsDisplayFormat;
    
    //    NSLog(@"setTableContentsDisplayFormat %ld",_tableContentsDisplayFormat);
    
    switch (_tableContentsDisplayFormat) {
        case DISPLAY_FMT_TC:
            [self toggleToTc];
            break;
        case DISPLAY_FMT_FT:
            [self toggleToFt];
            break;
            
        default: break;
    }
}
-(NSInteger)tableContentsDisplayFormat{
    
    return _tableContentsDisplayFormat;
}

-(void)setInhibitGetTrackPos:(bool)inhibitGetTrackPos{
    
    _inhibitGetTrackPos = inhibitGetTrackPos;
    
    if(!_inhibitGetTrackPos){    // get track positions on trailing edge
        
//        AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
        //        [delegate refreshTrackPos];
        
    }
    
}
-(bool)inhibitGetTrackPos{
    return _inhibitGetTrackPos;
}
//-(void)setCueSheetFollowsMtc:(bool)cueSheetFollowsMtc{
//    
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    
//}

-(void)setTimeCodeStart:(NSString *)timeCodeStart{
    
    _timeCodeStart = timeCodeStart;
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    NSArray *array = [timeCodeStart componentsSeparatedByString:@":"];
    
    [delegate.adrClientWindowController txMsg:[NSString stringWithFormat:@"setZeroFeetAtTc %@%@%@%@",array[0],array[1],array[2],array[3]]];
    
}
-(NSString*)timeCodeStart{
    
    return _timeCodeStart;
    
}
//-(void)setAutoPlay:(bool)autoPlay{
//    _autoPlay = autoPlay;
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//    [delegate setAutoPlayLED:autoPlay];
//}
//-(bool)autoPlay{
//    return _autoPlay;
//}

-(void)setForeColor:(NSColor *)foreColor{
    _foreColor = foreColor;
    
}
-(NSColor*)foreColor{
    return _foreColor;
}
-(void)setBackColor:(NSColor *)backColor{
    _backColor = backColor;
}
-(NSColor*)backColor{
    return _backColor;
}


-(void)setShowAllCols:(bool)showAllCols{
    
    [[NSUserDefaults standardUserDefaults] setBool:showAllCols forKey:@"showAllCols"];
    _showAllCols = showAllCols;
//    [self sizeTableViewToContents];
    
}
-(bool)showAllCols{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"showAllCols"];
}
//-(void)setSession:(NSString *)session{
//    
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//    
//    if(!delegate.session || ![session isEqualToString:delegate.session]){
//        [delegate setSession:session];  // in delegate because delegate.session is bound to EditorController for display
//    }
//    [self readLog];  // 2.00.00 read the log when file loads
//
//
//}
//-(NSString*)session{
//    
//    return ((AleDelegate*)[NSApp delegate]).session;
//}

-(void)setCueID:(NSString*)cueID{
    @try {
        
        NSInteger row = [_tableView selectedRow];
        if(row < 0) return;
        
        NSMutableDictionary *dictionary = [_tableContents objectAtIndex:row];
        
        //        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        NSString *key = [_headerDictionary objectForKey:@"cueId"];//[defaults objectForKey:@"cueId"];
        [dictionary setObject:cueID forKey:key];
        
    }
    @catch (NSException *exception) {
        
    }
    
}

-(NSString*)cueID{
    
    NSInteger row = [_tableView selectedRow];
    if(row < 0) return @"unnamed";
    
    NSMutableDictionary *dictionary = [_tableContents objectAtIndex:row];
    return [self cueIDForDictionary:dictionary];
    
}

-(void)setDialog:(NSString*)dialog{
    
    if(_recordCycleDictionary == nil){return;}
    
    @try {
        
        _recordCycleDictionary[@"Dialog"] = dialog;
        
        // display the dialog
        [self sendDialogToStreamerForDictionary];
        [self sizeTableViewToContents];
        [self writeChanges];    // maybe save the new dialog
        
    }
    @catch (NSException *exception) {
        
    }
}
-(NSString*) dialog{
    
    NSIndexSet *indexSet = [self selectedRowIndexes];
    
    NSMutableString *s = [[NSMutableString alloc]init];
    

    for(NSInteger i = indexSet.firstIndex; i <= indexSet.lastIndex; i++){
        
        // allow non-contiguous selection 2.10.02 12/19/23
        if([indexSet containsIndex:i]){
            [s appendString:[NSString stringWithFormat:@"%@\n",_tableContents[i][@"Dialog"]]];
        }
        
    }
    NSString *text = s;
    text = [text stringByReplacingOccurrencesOfString:@"^" withString:@"\n"];   // convert ^ to \n
    text = [text stringByReplacingOccurrencesOfString:@"\\r" withString:@"\n"]; // convert \\r to \n
    text = [text stringByReplacingOccurrencesOfString:@"\v" withString:@"\n"];  // convert VT to \n

    return [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    // Evan has a case where \r\r is in the dialog, must be a CR
//    return [s stringByReplacingOccurrencesOfString:@"\r\r" withString:@"\n"];
    
//    NSInteger row = [_tableView selectedRow];
//    if(row >= _tableContents.count || row < 0) return @"";
//    
//    return [self dialogForDictionary];
}

-(void)setCtr:(NSString *)ctr{
    
    if(!ctr) return;
    _ctr = ctr;
}
-(NSString*)ctr{
    return [_ctr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];    // remove blanks
}
-(void)setTc:(NSString *)tc{
    _tc = tc;
    
    //    // if we are in autoPlay, cue sheet follows tc
    //    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    //
    //    if(_autoPlay && [delegate.midiClient isPlay]){   // only in play...
    //
    //        NSInteger row = [_tableView selectedRow];
    //        if(row >= _tableContents.count || row < 0) return;
    //        NSDictionary *dictionary = [_tableContents objectAtIndex:row];
    //
    //        NSString *end = [tcf tcForString:[dictionary objectForKey:@"End"]];
    //
    //        if(![tcc isTc:end] || [end isEqualToString:@"00:00:00:00"] ) return;
    //
    //        if ([tcc compareTc:tc fromTc:end withType:(int)_tcType] >= 0) {
    //            // when we pass the end of the cue, go to the next row
    //            [self nextCueAutoPlay];
    //
    //        }
    //    }
}

-(NSString*)tc{
    return _tc;
}
-(void)setCharacterInTrackName:(bool)characterInTrackName{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool: characterInTrackName forKey:@"characterInTrackName"];
}
-(bool)characterInTrackName{
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"characterInTrackName"];
    
}

-(void)setDialogInClipName:(bool)dialogInClipName{
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:dialogInClipName forKey:@"dialogInClipName"];
    
}
-(bool)dialogInClipName{
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"dialogInClipName"];
    
}
-(void)setNotesInClipName:(bool)notesInClipName{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:notesInClipName forKey:@"notesInClipName"];
    
}
-(bool)notesInClipName{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"notesInClipName"];
}
-(void)setBeepsTrimFrames:(NSInteger)beepsTrimFrames{
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSString stringWithFormat:@"%d",(int)beepsTrimFrames] forKey:@"beepsTrimFrames"];
    
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    [delegate txOsc:[NSString stringWithFormat:@"beepsTrim %ld",beepsTrimFrames]];
    [delegate.xKey setLEDForUnitID:8 :18+80 : beepsTrimFrames < 0]; // BEEPS ARE OFFSET
    [delegate.xKey setLEDForUnitID:8 :26+80 : beepsTrimFrames > 0]; // BEEPS ARE

    //    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    //    [delegate setTrimLeds];   // indicate we are offset
    //    [delegate setDocLEDs];
    
}
-(NSInteger)beepsTrimFrames{
    
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"beepsTrimFrames"];
}
-(void)setRecordToComposite:(bool)recordToComposite{
    _recordToComposite = recordToComposite;
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    [delegate setLEDForUnitID:9 :32 :_recordToComposite];
    [delegate.xKey setLEDForUnitID:8 :2+80 :_recordToComposite]; // 2.10.02 indicator on XKEY
    // 2.10.02 moved from aleDelegate.setDocLeds()
    // commented out per Evan's request, we don't know what this is about
//    Byte trigger[] = {0x90,124,64};
//    //     Comp Track "armed": Note #69
//    trigger[1] = 69;
//    trigger[2] = recordToComposite ? 127 : 0;
//    [delegate.ptClient midiTx:[NSData dataWithBytes:trigger length:3]];
}
-(bool)recordToComposite{
    return _recordToComposite;
}
-(bool)streamerEnable{
    
    return [[NSUserDefaults standardUserDefaults]boolForKey:@"enStreamer"];
}

-(bool)beepsEnable{
    return [[NSUserDefaults standardUserDefaults]boolForKey:@"enBeeps"];
}

//-(void)setLoopRecord:(bool)loopRecord{
//    _loopRecord = loopRecord;
//    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
//    [delegate setDocLEDs];
//    [self onSendCueToProtools:nil];
//}
//-(bool)loopRecord{
//    return _loopRecord;
//}
//-(void)setTcType:(NSInteger)tcType{
//    
//    [_fpsComboBox selectItemAtIndex:tcType];
//}
-(int)tcType{
    
    return [self getTcType];
}
#pragma mark -
#pragma mark ------------------- access for circle take text --------------------

//-(void)incrementTake{
//    
//    NSInteger row = [_tableView selectedRow];
//    if(row < 0) return;
//    
//    NSMutableDictionary *dictionary = [_tableContents objectAtIndex:row];
//    
//    [self incrementTakeForDictionary:dictionary];
//}
//-(void)cutAndPaste:(NSArray *)msgArray{
//    // increment take counter
//    
//    NSString *actor;
//    NSString *cueID;
//    NSString *clipName;
//    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
//    NSString *actorKey = [defaults objectForKey:@"actor"];
//    NSString *cueIDKey = [defaults objectForKey:@"cueId"];
//   
//    @autoreleasepool {
//        
//        NSMutableDictionary *rowDictionary = nil;
//        
//        for(NSMutableDictionary * dict in _tableContents){
//            
////            if([[msgArray objectAtIndex:0]rangeOfString:cueID].location != NSNotFound){
//            actor = [dict objectForKey:actorKey];
//            cueID = [dict objectForKey:cueIDKey];
//            clipName = [NSString stringWithFormat:@"%@_%@_%@",actor,cueID,[dict objectForKey:@"Take"]];
//            
//            if([clipName isEqualToString:[msgArray objectAtIndex:0]] ){
//            
//                rowDictionary = dict;
//                break;
//            }
//        }
//        
//        if(rowDictionary == nil) return;    // not found
//        
////        AleDelegate *aleDelegate = (AleDelegate *)[NSApp delegate];
////        EditorWindowController *ed = [aleDelegate editorWindowController];
////        
////        if(ed){
////            [ed setLastTake:[rowDictionary objectForKey:@"Take"]];
////        }
//        
//        NSInteger nextTake = [[rowDictionary objectForKey:@"Take"] integerValue] + 1;
//        [rowDictionary setObject:[NSString stringWithFormat:@"%d",(int)nextTake] forKey:@"Take"];
//        
//        [self writeChanges];    // maybe save the document
//        
//    }
//}

- (IBAction)onAddCueButton:(id)sender {
    
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    [delegate.adrClientWindowController txMsg:@"addCue"];    // gets dialog and current position
    
//    [delegate.adrClientWindowController txMsg:@"jxaGetProtoolsPosition 1"]; // add cue at current position, Evan 2/11/16
    
}
#pragma mark -
#pragma mark ---------------- v1.00.06 additions ---------------------
-(NSIndexSet*)selectedRowIndexes{
    return [_tableView selectedRowIndexes];
}
-(void)calcTcFtFrForKey:(NSString*)key :(NSMutableDictionary*)dict{
    
    NSString *t = [dict objectForKey:key]; //tc or ft/fr
    
    if(t == nil || !t.length) return;    // nothing to do
    
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    //    NSString *timeCodeStart = [delegate timeCodeStart];
    int frames = 0;
    int tcType = [delegate getTcType];
    
    switch (_tableContentsDisplayFormat) {  // the new format
            
        case DISPLAY_FMT_FT:    // display is ft/fr, tableContents is tc
            
            // if display is ft/fr and tableContents was loaded as tc, we have tc formatted as ft/fr
            // format as tc, subtract tc start, convert to ft/fr, set tableContents
            t = [tcf formatAsTc:t];
            if(![tcc isTc:t]) return;
            
            t = [tcc subtractTc:_timeCodeStart fromTc:t withType:tcType];
            frames = [tcc tcToBinary:t withType:tcType];
            t = [tcc binaryToFt:frames];
            [dict setObject:t forKey:key];
            
            break;
            
        case DISPLAY_FMT_TC:
            
            // if display is tc and tableContents was loaded as ft/fr, we have ft/fr formatted as tc
            // format as ft/fr, convert to frames, add to start tc frames, convert to tc, set tableContents
            t = [tcf formatAsFeet:t];
            if(![tcc isFtFr:t]) return;
            
            frames = [tcc ftToBinary:t];
            frames += [tcc tcToBinary:_timeCodeStart withType:tcType];
            t = [tcc binaryToTc:frames withType:tcType];
            [dict setObject:t forKey:key];
            break;
            
        default:
            break;
    }
    
}
-(void)calcTableContentsForNewTcStart:(NSInteger)displayFormat{
    
    // tableContents display has been flipping without calcs
    
    // for cases where display and tableContents match, exit
    if(displayFormat == _tableContentsDisplayFormat) return;
    
    _tableContentsDisplayFormat = displayFormat;    // go to this format
    
    // calc Start, End, Streamer1-Streamer6
    
    for(NSMutableDictionary *dict in _tableContents){
        
        [self calcTcFtFrForKey:@"Start" :dict]; //NSLog(@"%@",[dict objectForKey:@"Start"]);
        [self calcTcFtFrForKey:@"End" :dict];
        [self calcTcFtFrForKey:@"streamer1" :dict];
        [self calcTcFtFrForKey:@"streamer2" :dict];
        [self calcTcFtFrForKey:@"streamer3" :dict];
        [self calcTcFtFrForKey:@"streamer4" :dict];
        [self calcTcFtFrForKey:@"streamer5" :dict];
        [self calcTcFtFrForKey:@"streamer6" :dict];
        
    }
    
    [_tableView reloadData];

    // keep the editor window prerolls in the right format
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    EditorWindowController *ed = delegate.editorWindowController;
    
    if(ed){
        
        switch (_tableContentsDisplayFormat) {
            case DISPLAY_FMT_TC:
                [ed toggleToTc];
                break;
            case DISPLAY_FMT_FT:
                [ed toggleToFt];
                break;
            default:
                break;
        }
    }
    
}
-(void)toggleToFtForKey:(NSString*)key :(NSMutableDictionary*)dict{
    
    NSString *t = [dict objectForKey:key]; //tc or ft/fr
    
    if(t == nil || !t.length) return;    // nothing to do
    
    if(![tcc isTc:t]) return;
    
    //    if(t.length){
    //        // if it does not start with a digit, assume it is text. Return it without formatting it
    //        NSCharacterSet *digits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    //        if(![digits characterIsMember:[t characterAtIndex:0]]) return;
    //    }
    
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    //    NSString *timeCodeStart = [delegate timeCodeStart];
    int tcType = [delegate getTcType];
    
    // convert tc to binary frs, subtract timeCodeStart frs, convert to ft/fr
    
    int frames = [tcc tcToBinary:t withType:tcType];
    frames -= [tcc tcToBinary:_timeCodeStart withType:tcType];
    t = [tcc binaryToFt:frames];
    
    [dict setObject:t forKey:key];
    
    
}
-(void)toggleToFt{
    
    // FIXME this breaks AleDoc
    //    if(_tableContentsDisplayFormat == DISPLAY_FMT_FT) return;   // already ft/fr
    //    _tableContentsDisplayFormat = DISPLAY_FMT_FT;
    //    NSLog(@"doc toggleToFt");
    
    for(NSMutableDictionary *dict in _tableContents){
        
        [self toggleToFtForKey:@"Start" :dict];
        [self toggleToFtForKey:@"End" :dict];
        [self toggleToFtForKey:@"streamer1" :dict];
        [self toggleToFtForKey:@"streamer2" :dict];
        [self toggleToFtForKey:@"streamer3" :dict];
        [self toggleToFtForKey:@"streamer4" :dict];
        [self toggleToFtForKey:@"streamer5" :dict];
        [self toggleToFtForKey:@"streamer6" :dict];
        
    }
    
    [self willChangeValueForKey:@"startEntryEnable"];
    [self setStartEntryEnable:true];
    [self didChangeValueForKey:@"startEntryEnable"];
    //    [self sizeTableViewToContents]; // FIXME col headers are not aligned with cols
}
-(void)toggleToTcForKey:(NSString*)key :(NSMutableDictionary*)dict{
    
    NSString *t = [dict objectForKey:key]; //tc or ft/fr
    
    if(t == nil || !t.length) return;    // nothing to do
    
    if(![tcc isFtFr:t]) return; // not ft/fr
    
    //    if(t.length){
    //        // if it does not start with a digit, assume it is text. Return it without formatting it
    //        NSCharacterSet *digits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    //        if(![digits characterIsMember:[t characterAtIndex:0]]) return;
    //    }
    
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    //    NSString *timeCodeStart = [delegate timeCodeStart];
    int tcType = [delegate getTcType];
    
    // convert ft/fr to binary frs, add timeCodeStart frs, convert to tc
    int frames = [tcc ftToBinary:t];
    frames += [tcc tcToBinary:_timeCodeStart withType:tcType];
    t = [tcc binaryToTc:frames withType:tcType];
    
    [dict setObject:t forKey:key];
}
-(void)toggleToTc{
    
    // FIXME this breaks AleDoc
    //    if(_tableContentsDisplayFormat == DISPLAY_FMT_TC) return; // already tc
    //    _tableContentsDisplayFormat =  DISPLAY_FMT_TC;
    
    //    NSLog(@"doc toggleToTc");
    
    for(NSMutableDictionary *dict in _tableContents){
        
        [self toggleToTcForKey:@"Start" :dict];
        [self toggleToTcForKey:@"End" :dict];
        [self toggleToTcForKey:@"streamer1" :dict];
        [self toggleToTcForKey:@"streamer2" :dict];
        [self toggleToTcForKey:@"streamer3" :dict];
        [self toggleToTcForKey:@"streamer4" :dict];
        [self toggleToTcForKey:@"streamer5" :dict];
        [self toggleToTcForKey:@"streamer6" :dict];
        
    }
    
    [self willChangeValueForKey:@"startEntryEnable"];
    [self setStartEntryEnable:false];
    [self didChangeValueForKey:@"startEntryEnable"];
    
    //    [self sizeTableViewToContents];
    
}
-(bool)cueSheetFollowsMtc{
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    bool theBool = [defaults boolForKey:@"followMtcEnable"];
    
    return theBool;
    
}
-(NSArray*)selectedContents{
    
    NSIndexSet *set = [_tableView selectedRowIndexes];
    return [_tableContents objectsAtIndexes:set];
}
- (IBAction)onBehaviorCombo:(id)sender{
    //behaviorIndex
    
    NSComboBox *combo = (NSComboBox*)sender;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithInteger:combo.indexOfSelectedItem] forKey:@"behaviorIndex"];
    
}
#pragma mark -
#pragma mark ---------------- v1.00.04 additions ---------------------
- (IBAction)onDisclosureButton:(id)sender {
    
    // NSOnState is disclosure button down
    
    NSButton *btn = (NSButton*)sender;
    
    if(btn && btn.state){   // is called in awakeFromNib with nil sender
        
        [_vertConstraint setConstant:270];
        
        
    }else{
        
        [_vertConstraint setConstant:30];
    }
    
    // OS 10.12, XCode 8.2.1 doesn't set the background to gray. Resizing the window does, though.
    [_docView setNeedsDisplay:true];
    
}

-(void)locateToCurrentCue{
    
    if (!_recordCycleDictionary) return;
    
    NSString *start = [tcf tcForString:_recordCycleDictionary[@"Start"]];
    
    AleDelegate *aleDelegate = (AleDelegate*)[NSApp delegate];
    Document *doc = [aleDelegate topDocument];
    
    // 2.10.00 TODO: do we need this test?
    if([tcc compareTc:start fromTc:doc.ctr withType:[self getTcType]] == NSOrderedSame) return; // works for ft/fr too
    
    [aleDelegate locate:start];
    
}

-(void)locateOrAddCue:(NSString*)cueID :(NSString*)start{
    
    for(NSDictionary *dict in [_tableContents copy] ){
        
        if([dict[@"Name"] isEqualToString:cueID]){
            
            NSInteger index = [_tableContents indexOfObject:dict];
            NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:index];
            [_tableView selectRowIndexes:indexSet byExtendingSelection:false];
            
            NSString *tc = [tcf tcForString:dict[@"Start"]];
            
            AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
            [delegate locate:tc];
            
            return;
        }
    }
    
    NSMutableDictionary *dict = [self makeRowDictionary];
    dict[@"Name"] = cueID;
    dict[@"Start"] = start;
    [_arrayController addObject:dict];
    
    self.recordCycleDictionaryState = RECORD_CYCLE_DICTIONARY_IDLE;

    // scroll to last row
    // http://stackoverflow.com/questions/1799728/how-to-make-nstableview-scroll-to-most-recently-added-row
    
    NSInteger numberOfRows = [_tableView numberOfRows];
    
    if (numberOfRows > 0)
        [_tableView scrollRowToVisible:numberOfRows - 1];
    
    NSInteger index = [_tableContents indexOfObject:dict];
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:index];
    [_tableView selectRowIndexes:indexSet byExtendingSelection:false];
    
    [self writeChanges];
    
}

-(void)takeFromClipList:(NSArray*)clipList{
    
    // this is called when the session name changes
    // look for the highest take number for each cue ID
    
    //    NSMutableArray *array = [[NSMutableArray alloc]init];
    //
    //    for(NSString *clip in clipList){
    //
    //        NSInteger index = [clip rangeOfString:@"Audio Clip"].location;
    //
    //        if(index != NSNotFound){
    //
    //            [array addObject:[clip substringFromIndex:index + 11]]; // remove "Audio Clip" portion
    //        }
    //    }
    
    NSLog(@"number of clips: %ld",clipList.count);
    
    // the sorted clip list from Protools, note that shortest names come first, a useful fact
    NSArray *sortedArray = [clipList sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    //    for(NSString *item in sortedArray){
    //        NSLog(@"%@",item);
    //    }
    
    //    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString *nameKey = [_headerDictionary objectForKey:@"cueId"];//[defaults objectForKey:@"cueId"];
    
    // http://stackoverflow.com/questions/2393386/best-way-to-sort-an-nsarray-of-nsdictionary-objects
    NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:nameKey  ascending:YES];
    NSArray *sortedTableContents = [_tableContents sortedArrayUsingDescriptors:[NSArray arrayWithObjects:descriptor,nil]];
    
    for(NSMutableDictionary *dict in sortedTableContents){
        
        NSString *match = [[dict objectForKey:nameKey] stringByAppendingString:@"_"];
        
        NSString *lastMatch = @"";
        for(NSString *clip in sortedArray){
            
            if([clip rangeOfString:match].location == 0){
                
                lastMatch = clip;
            }
            
        }
        
        // remove the clip name
        if(lastMatch.length){
            lastMatch = [lastMatch substringFromIndex:match.length];
            NSArray *itemArray = [lastMatch componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"- _\n"]];
            
            @try {
                
                NSInteger take = [[itemArray objectAtIndex:0] integerValue];    // take gets incremented in cycle()
                [dict setObject:[NSString stringWithFormat:@"%ld",take] forKey:@"Take"]; //NSLog(@"KEY  11");
            }
            @catch (NSException *exception) {
                [dict setObject:@"0" forKey:@"Take"]; //NSLog(@"KEY  12");
            }
            
        }else{
            
            [dict setObject:@"0" forKey:@"Take"];   //NSLog(@"KEY  13");
        }
    }
    
    // set the selected track to the current take mod 32 TODO discuss with Evan
    
    NSInteger currentTake = [[self take]integerValue] - 1;
    
    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
    [delegate setCurrentTrack:currentTake % 32];
    
    
}
#pragma mark -
#pragma mark --------- helper fns for recordCycleDictionary -----------
-(void)sendDialogToStreamerForDictionary{
    
    [self sendDialogToStreamerForDictionary:_recordCycleDictionary];
    
}
-(void)sendDialogToStreamerForDictionary:(NSDictionary*)dict{
    
    // set overlays
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    if(!dict) {
        
        delegate.overlayWindowController.viewController.textView.text = @"";
        return;
    }
    
    int rrpb = delegate.matrixWindowController.rehRecPb % 4;  // state indexes are not-pending
    
    switch (rrpb) {
            
        case MODE_CONTROL_PLAYBACK: delegate.overlayWindowController.viewController.textView.text = @"";  return;
            
        default:
            break;
    }
    
//    NSString *start = dict[@"Start"];
//    
//    if(start == nil || !start.length) return;   // not a cue with a start, exit
//    
//    NSCharacterSet *digits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
//    if(![digits characterIsMember:[start characterAtIndex:0]]) return;
    
    // .tab files don't have column id's. We guessed the Start and End, operator has to select Name, Dialog, Notes
  //
    NSString *text = @"";   // __block lets us access this var from inside the block below
    
    NSString *name = dict[@"Name"];
    
    if(_cueIdCheckBox.state == NSControlStateValueOn && name && name.length) text = [text stringByAppendingString:[NSString stringWithFormat:@"%@\n",name]];
    
    // append dialog for multiple selection
    if(_dialogCheckBox.state == NSControlStateValueOn){
        
        text = [text stringByAppendingString:[NSString stringWithFormat:@"%@\n",self.dialog]];
//        NSIndexSet *set = [_tableView selectedRowIndexes];
//        
//        //    NSLog(@"items in set: %ld",set.count);
//        // 2.10.00 dialog for multiple selection
//        
//        for(NSUInteger i = set.firstIndex; i <= set.lastIndex; i++){
//            
//            // allow non-sequential selection
//            if([set containsIndex:i]){
//                NSDictionary *dict = _tableContents[i];
//                text = [text stringByAppendingString:[NSString stringWithFormat:@"%@\n",dict[@"Dialog"]]];
//            }
//        }
    }
    
    NSString *notes = dict[@"Notes"];
    
    if(_notesCheckBox.state == NSControlStateValueOn && notes && notes.length) text = [text stringByAppendingString:[NSString stringWithFormat:@"%@\n",notes]];
    
//    text = [text stringByReplacingOccurrencesOfString:@"^" withString:@"\n"];   // convert ^ to \n
//    text = [text stringByReplacingOccurrencesOfString:@"\\r" withString:@"\n"]; // convert \\r to \n
//    text = [text stringByReplacingOccurrencesOfString:@"\v" withString:@"\n"];  // convert VT to \n
    
    delegate.overlayWindowController.viewController.textView.text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}
-(void)sendTakeToStreamerForDictionary{
    
    [self sendTakeToStreamerForDictionary:_recordCycleDictionary];
    
}
-(void)sendTakeToStreamerForDictionary:(NSDictionary*)dict{
    
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    
    if(dict == nil){
        
        delegate.overlayWindowController.viewController.cueIdTextView.text = @"";
        return;    // no dictionary
    }
    //
    NSString *take = [self takeForDictionary:dict];
    NSString *cueID = [self cueIDForDictionary:dict];
    if(self.characterInTrackName) cueID = [NSString stringWithFormat:@"%@ %@",[self actorForDictionary],cueID];   // 2.00.00 ' '

    NSString *msg = [NSString stringWithFormat:@"%@ Last take: %@ ",cueID,take];
    if(delegate.cycleMotion != CYCLE_MOTION_IDLE && (delegate.matrixWindowController.rehRecPb % 4) == MODE_CONTROL_RECORD)
        msg = [NSString stringWithFormat:@"%@ Recording take: %@ ",cueID,take];  // 2.00.00
    
    switch (delegate.matrixWindowController.rehRecPb % 4) {
        case MODE_CONTROL_PLAYBACK:
            msg = @"";
            break;
            
        default:
// github tickle
            if(take){
                if(take.length == 0) msg = @"";   // take checkbox is off
                else if([take isEqualToString:@"0"]){
                    
                    msg = [NSString stringWithFormat:@"%@ no takes ",cueID];
                }
            }
            break;
    }
    
    bool show = [[NSUserDefaults standardUserDefaults] boolForKey:@"showTake"];
    delegate.overlayWindowController.viewController.cueIdTextView.text = show ? msg : @"";
    
    // 2.10.02 don't do this, leave monitor format to mixer, cue can have different formats on different takes
    // 2.00.00 change monitor format, different cues can have different monitor formats
//    long numRecTracks = [self numRecTracksForDictionary:dict];
//    if(numRecTracks != -1 && numRecTracks != delegate.matrixWindowController.numRecTracksTag){
//
//        delegate.matrixWindowController.numRecTracksTag = numRecTracks;
//
//    }
}
-(NSString*)clipNameForDictionary{
    
    NSString *actor = [self actorForDictionary];
    NSString *take = [self takeForDictionary]; if(take.length < 2) take = [@"0" stringByAppendingString:take];
    NSString *cueID = [self cueIDForDictionary:_recordCycleDictionary];
    
    return [NSString stringWithFormat:@"%@_%@_%@",actor,cueID,take];
    
}
//-(long)numRecTracksForDictionary:(NSDictionary*)dictionary{
//    
//    // 2.00.00 set monitor to last used recording format
//    if(dictionary[@"numRecTracks"] != nil){
//        
//        return [dictionary[@"numRecTracks"] integerValue];
//        
//    }
//    
//    return -1;  // failure
//}
-(NSString*)actorForDictionary{
    
    if(_recordCycleDictionary && _recordCycleDictionary[@"Character"]){
        
        return _recordCycleDictionary[@"Character"];
    }else{
        
        return @"";
        
    }
    
}
-(NSString*)takeForDictionary{
    
    return [self takeForDictionary:_recordCycleDictionary];
    
}
-(NSString*)takeForDictionary:(NSDictionary*)dict{
    
    if(dict && dict[@"Take"]){
        
        return dict[@"Take"];
    }else{
        
        return @"";
        
    }
    
}
-(NSString*)trackForDictionary{
    return [self trackForDictionary:_recordCycleDictionary];
}
-(NSString*)trackForDictionary:(NSDictionary*)dict{
    
    if(dict && dict[@"Track"]){
        
        return dict[@"Track"];
    }else{
        
        return @"0";
        
    }

}
-(NSString*)cueIDForDictionary{
    
    return [self cueIDForDictionary:_recordCycleDictionary];
    
}
-(BOOL) stringIsNumeric:(NSString *) str {
    // https://stackoverflow.com/questions/3473788/objective-c-check-if-integer-int-number
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    NSNumber *number = [formatter numberFromString:str];
    return !!number; // If the string is not numeric, number will be nil
}
-(NSString*)cueIDForDictionary:(NSMutableDictionary*)dict{
    
    if(dict && dict[@"Name"]){
        
        // remove underscore before ending digits
        // cue_01 -> cue 01, PT uses _xx for take numbering,
        // Evan says it will randomly mistake cue_01 digits for take number
        
        NSString *result = dict[@"Name"]; // assume that it is not of the form abc_xxx
        
        NSMutableArray *array = [[NSMutableArray alloc] initWithArray: [dict[@"Name"] componentsSeparatedByString:@"_"]];
        
        if(array.count > 1){
            
            NSString *str = [array lastObject]; // possibly a number
            [array removeLastObject];   // remove it
            
            if([self stringIsNumeric : str]){
                
                // is a number, separate by 'keepUnderScores'
                bool keepUnderscores = [[NSUserDefaults standardUserDefaults] boolForKey:@"keepUnderscores"];
                NSString *separator = keepUnderscores ? @"_" : @" ";
                
                result = [array componentsJoinedByString:@"_"];
                result = [NSString stringWithFormat:@"%@%@%@",result,separator,str];
                
            }
            
        }
        
        return result;
        
    }else{
        
        return @"";
        
    }
    
}
-(NSString*) dialogForDictionary{
    
    return [self dialogForDictionary:_recordCycleDictionary];
}
-(NSString*) dialogForDictionary:(NSDictionary*)dict{
    
    if(dict && dict[@"Dialog"]){
        
        return dict[@"Dialog"];
    }else{
        
        return @"";
        
    }

}
-(NSString*) notesForDictionary{
    // tickle github
    if(_recordCycleDictionary && _recordCycleDictionary[@"Notes"]){
        
        return _recordCycleDictionary[@"Notes"];
    }else{
        
        return @"";
        
    }

}
-(NSString*)startForDictionary{
    return [self startForDictionary:_recordCycleDictionary];
}
-(NSString*)startForDictionary:(NSDictionary*)dict{
    
    if(dict && dict[@"Start"]){
        
        return [_tcFormatterTableView stringForObjectValue:dict[@"Start"]];
//        return dict[@"Start"];
    }else{
        
        return @"";//@"00:00:00:00";
        
    }

}
-(NSString*)endForDictionary{
    
    if(_recordCycleDictionary && _recordCycleDictionary[@"End"]){
        
        return [_tcFormatterTableView stringForObjectValue:_recordCycleDictionary[@"End"]];
//        return _recordCycleDictionary[@"End"];
    }else{
        
        return @"";//@"00:00:00:00";
        
    }
}
-(void)incrementTakeForDictionary{
    
    NSString *take = [_recordCycleDictionary objectForKey:@"Take"];
    NSInteger nextTake = [take integerValue] + 1;
    [_recordCycleDictionary setObject:[NSString stringWithFormat:@"%d",(int)nextTake] forKey:@"Take"]; //NSLog(@"KEY  16");
    
}
-(NSString*)clipNameWithDialogForDictionary{
    
    @autoreleasepool {
        
        NSString *actor = [self actorForDictionary];
        NSString *take = [self takeForDictionary];
        NSString *cueID = [self cueIDForDictionary];
        NSString *dlg = [self dialogForDictionary];
        
        NSString *theName = [NSString stringWithFormat:@"%@_%@_%@_%@",actor,cueID,take,dlg];
        
        if(theName.length > 240) theName = [theName substringToIndex:240];  // filenames are 255 chars max
        
        return theName;
    }
    
}


-(void)bindEditorWindowFields:(NSDictionary*)dict{
    
    //    AleDelegate *aleDelegate = (AleDelegate *)[NSApp delegate];
    AleDelegate *delegate = (AleDelegate *)[NSApp delegate];
    EditorWindowController *ed = delegate.editorWindowController;
    if(!ed)return;
//    if(!_tableContents || !_tableContents.count) return;
    
    [ed bindFields:@"Name" :@"Dialog" :@"Notes" :@"Character" :@"Start" :@"End" :dict];
    
    [ed bindChecks:self];
    
}

-(NSString*)stripNonLatin1:(NSString*)cmd{
    
    // we see non-ascii text at times
    
    NSString *result = @"";
    NSMutableData *data = [[NSMutableData alloc] initWithData:[cmd dataUsingEncoding:NSUnicodeStringEncoding]];
    unichar *pUnichar = (unichar *)[data bytes];
    
    for(NSInteger i = 1; i < data.length/sizeof(unichar); i++){ // ignore the first char, is unicode identifier 0xfeff
        
        if(pUnichar[i] < 255) continue;
        
        switch (pUnichar[i]) {
            case 0x2019:
                pUnichar[i] = 0x27; // single quote
                break;
            case 0x201c: 
            case 0x201d: pUnichar[i] = 0x22; break; // double quote
                
            default:
                NSLog(@"pUnichar[%ld]: %x",i,pUnichar[i]);
                pUnichar[i] = ' ';  // not substituted yet
                break;
        }
    }
    
    result = [[NSString alloc]initWithData:data encoding:NSUnicodeStringEncoding];
    return result;
}
#pragma mark -
#pragma mark ---------------- TCFormatterDelegate -----------------------
-(NSString*)getTcStart{
    
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//    NSString *tcStart = [delegate timeCodeStart];
//    if(tcStart == nil) tcStart = @"01:00:00:00";    // default start is 1 hour
//    return tcStart;
    
    return _timeCodeStart;
    
}
-(NSInteger)getDisplayFormat{
    
    return _tableContentsDisplayFormat;
}

-(int)getTcType{
    
    if(_delegate) return [_delegate getTcType];
    
    id delegate = [NSApp delegate];
    
    if([delegate respondsToSelector:@selector(getTcType)]){
        
        return [delegate getTcType];
        
    }
    
    return  TCTYPE_24;  // default
}
-(NSString*)getTcStartForObject:(id)obj{
    
    // find the dictionary containing the start/end object
    
    for(NSDictionary *dict in _tableContents){
        
        NSString *start = dict[@"Start"];
        NSString *end = dict[@"End"];
        
        if(obj == start || obj == end){
            
//            NSLog(@"did find start/end object");
            
            if(dict[@"Hour"]){
                
                int hr = ((NSString*)dict[@"Hour"]).intValue;
                return [NSString stringWithFormat:@"%02d:00:00:00",hr];

            }
            
            return [self getTcStart];    // no Hour, return the generic value
        }
    }
    
    return [self getTcStart];    // no Hour, return the generic value
}

#pragma mark -
#pragma mark ---------------- TcCalculatorDelegate -----------------------

-(bool)ignoreTcStartHours{
    return true;
}

#pragma mark -
#pragma mark ---------------- additions for start/end dropdowns -----------------------

-(void)setStartTc:(NSString*)tc ForDictionary:(NSMutableDictionary*)dictionary{
 
    if(![tcc isTc:tc] && ![tcc isFtFr:tc]) return;

    if(dictionary){
        [dictionary setObject:tc forKey:@"Start"];
    }
    
}
-(void)setEndTc:(NSString*)tc ForDictionary:(NSMutableDictionary*)dictionary{
    
    if(![tcc isTc:tc] && ![tcc isFtFr:tc]) return;

    if(dictionary){
        [dictionary setObject:tc forKey:@"End"];
    }
}

@end
