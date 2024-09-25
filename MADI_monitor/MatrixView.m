//
//  MatrixView.m
//  Ale_v3xx
//
//  Created by James Ketcham on 4/25/14.
//  Copyright (c) 2014 WB ADR. All rights reserved.
//  v2.00.00 

#import "MatrixView.h"
#import "MatrixWindowController.h"
//#import "Chunk.h" // 2.00.00 no more chunks
#import "TcpClientConnection.h"
#import "AleDelegate.h"
#import "MidiCommands.h"
#import "EditorWindowController.h"
#import "AleDoc21-Swift.h"    // must be here to avoid a circular reference

@interface MatrixView()
@property TcCalculator *tcc;
@end

@implementation MatrixView

@synthesize backImage = _backImage;
//@synthesize frameSize = _frameSize;
@synthesize rowTitles = _rowTitles;
@synthesize colTitles = _colTitles;
@synthesize rowView = _rowView;
@synthesize colView = _colView;
@synthesize tcc = _tcc;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
//        NSError *error;
//        NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:ROW_TITLE_KEY];
//        NSKeyedUnarchiver *unarch = [[NSKeyedUnarchiver alloc]initForReadingFromData:data error:&error];
//        NSSet *set = [NSSet setWithObjects:[NSMutableArray class],[NSDictionary class],[NSString class], nil];
//        _rowTitles = [unarch decodeObjectOfClasses:set forKey:ROW_TITLE_KEY];
//
//        data = [[NSUserDefaults standardUserDefaults] objectForKey:COL_TITLE_KEY];
//        unarch = [[NSKeyedUnarchiver alloc]initForReadingFromData:data error:&error];
//        _colTitles = [unarch decodeObjectOfClasses:set forKey:COL_TITLE_KEY];
//
//        [self drawBackImage:frame.size];    // 2.10.00 TODO: doess not draw
    }
    self.tcc = [[TcCalculator alloc]init];
    
    [self autoSlate:false];
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    
    [_backImage drawInRect:dirtyRect fromRect:dirtyRect operation:NSCompositingOperationCopy fraction:1.0];
    
    // V2.00.00
    NSSize size = NSMakeSize(MATRIX_CELL_SIZE - 4,MATRIX_CELL_SIZE - 4);    // inset 2 pixels
    
    for (int i = 0; i < _colTitles.count; i++){
        
        for(int j = 0; j < _rowTitles.count; j++){
            
            // get the dictionary with the Dim A, Dim B checkmarks
            int k = 0;
            
            NSString *rowTitle = _rowTitles[j][@"Title"];
            NSDictionary *inputDictionary;
            
            if(_delegate && _delegate.inputArray){
                for(;k < _delegate.inputArray.count; k++){
                    NSString *inputArrayName = _delegate.inputArray[k][@"Name"];
                    
                    if([rowTitle hasPrefix:inputArrayName]){
                        inputDictionary = _delegate.inputArray[k];
                        break;
                    }
                }
            }
            
            // y0 is top left, not bottom left
            double x = i * MATRIX_CELL_SIZE;
            double y = (_rowTitles.count - j -1) * MATRIX_CELL_SIZE;
            NSPoint point = NSMakePoint(x + 2, y + 2);  // inset 2 pixels
            
            NSRect rect;
            rect.origin = point;
            rect.size = size;

            NSBezierPath *bezierPath = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:2.0 yRadius:2.0];

            NSInteger inputFeedbackMask = ((NSString*)_rowTitles[j][FEEDBACK_KEY]).integerValue;   // mask
            NSInteger outputFeedbackMask = ((NSString*)_colTitles[i][FEEDBACK_KEY]).integerValue;  // mask
            
            // show feedbacks as blue
            NSColor *color = (inputFeedbackMask & outputFeedbackMask) != 0 ? NSColor.blueColor : NSColor.yellowColor;
            
            // dim indication
            // v2.10.02 dim is on outputs, not crosspoints
//            if(inputDictionary){
//
//                NSNumber *dimA = inputDictionary[@"Dim A"];
//                NSNumber *dimB = inputDictionary[@"Dim B"];
//
//                if((_delegate.dimA && dimA.intValue != 0) ||
//                   (_delegate.dimB && dimB.intValue != 0)
//                   ){
//
//                    color = [color colorWithAlphaComponent:0.5];
//
//                }
//            }

            // V2.00.00 top bit is crosspoint on
            // V2.10.00 Mic columns can't be toggled, indicate with a black bar
            NSString *colTitle = _colTitles[i][@"Title"];
            
            if([colTitle hasPrefix:@"Talkback"] || [colTitle hasPrefix:@"Snoop"]){
                
                // make a mark indicating this cell can't be toggled
                matrix[i][j] = 0;
                rect.origin = NSMakePoint(x + 4, y - 1 + (MATRIX_CELL_SIZE/2));  // inset 2 pixels, 1 pixel below midline
                rect.size.height = 2;
                rect.size.width = MATRIX_CELL_SIZE - 8;
                bezierPath = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:2.0 yRadius:2.0];
                
                [NSColor.blackColor set];
                [bezierPath fill];
                
            }
            else{
                
                if(matrix[i][j] & 0x80){

                    [color set];
                    [bezierPath fill];
                }
           }
        }
    }
}
-(void)drawBackImage:(NSSize)size{
    
    if(size.width == 0 || size.height == 0){
        return; // bad size
    }
    
    if(_rowTitles == nil || _colTitles == nil){
        return;
    }
    
    [_rowView drawBackImage:_rowTitles :true];
    [_colView drawBackImage:_colTitles :false];
    
    NSBezierPath *path = [[NSBezierPath alloc] init];
    
    NSRect rect = NSMakeRect(0, 0, size.width, size.height);
    
    [path appendBezierPathWithRect:rect];
    // make the grid
    [path setLineWidth:1.0];
    
    float endX = MATRIX_CELL_SIZE * _colTitles.count;
    float endY = MATRIX_CELL_SIZE * _rowTitles.count;
    
    // we have a black frame, make it the size of the matrix 
    self.frame = NSMakeRect(self.frame.origin.x, self.frame.origin.y, endX, endY);
    
    for(int i = 0; i <= _colTitles.count; i++){
        
        float x = MATRIX_CELL_SIZE * i;
        [path moveToPoint:NSMakePoint(x, 0)];
        [path lineToPoint:NSMakePoint(x, endY)];

    }
    
    for(int i = 0; i <= _rowTitles.count; i++){
        
        float y = MATRIX_CELL_SIZE * i;
        [path moveToPoint:NSMakePoint(0, y)];
        [path lineToPoint:NSMakePoint(endX, y)];

    }
    
    NSBezierPath *grid = [[NSBezierPath alloc] init];
    
    NSRect gridRect = NSMakeRect(0, 0, MATRIX_CELL_SIZE * _colTitles.count, MATRIX_CELL_SIZE * _rowTitles.count);

    [grid appendBezierPathWithRect:gridRect];
    
    for(int i = 0; i <= _colTitles.count; i += 8){
        
        float x = MATRIX_CELL_SIZE * i;
        [grid moveToPoint:NSMakePoint(x, 0)];
        [grid lineToPoint:NSMakePoint(x, endY)];

    }
    
    for(int i = 0; i <= _rowTitles.count; i += 8){
        
        float y = MATRIX_CELL_SIZE * i;
        [grid moveToPoint:NSMakePoint(0, y)];
        [grid lineToPoint:NSMakePoint(endX, y)];

    }
    
    // draw backImage
    
    [self setBackImage:[[NSImage alloc] initWithSize:size]];
    [[self backImage] lockFocus];
    [[NSColor lightGrayColor] set];
    [grid fill];
    [[NSColor darkGrayColor] set];
    [path stroke];
    [[NSColor blackColor] set];
    [grid stroke];
    [[self backImage] unlockFocus];
    
}
// -----------------------------------
// Handle Mouse Events
// -----------------------------------
-(void)mouseDown:(NSEvent *)event
{
    NSPoint clickLocation;
//    printf("mouseDown in MatrixView\n");
    
    // convert the click location into the view coords
    clickLocation = [self convertPoint:[event locationInWindow]
                              fromView:nil];
    
    // calc the x,y index
    int x_index = (int)((clickLocation.x) / MATRIX_CELL_SIZE);
    int y_index = (int)_rowTitles.count - (int)((clickLocation.y) / MATRIX_CELL_SIZE) - 1;

    // toggle the crosspoint
    if(x_index >= 0 && x_index < _colTitles.count && y_index >= 0 && y_index < _rowTitles.count){
        
        // v2.00.00
        NSUInteger flags = NSEvent.modifierFlags;
        if(flags & NSEventModifierFlagCommand){
            
            // 2.10.02 toggle inputs[?].Feedback
             
            NSInteger index = ((NSString*)_rowTitles[y_index][@"InputArray"]).intValue;
            NSInteger rowFeedback = ((NSString*)_delegate.inputArray[index][@"Feedback"]).intValue;
            NSInteger colFeedback = ((NSString*)_colTitles[x_index][@"Feedback"]).intValue;
            rowFeedback ^= colFeedback;
            
            NSMutableArray *mutableInputs = [NSMutableArray arrayWithArray:_delegate.inputArray];
            NSMutableDictionary *mutableInput = [NSMutableDictionary dictionaryWithDictionary:_delegate.inputArray[index]];
            
            mutableInput[@"Feedback"] = [NSString stringWithFormat:@"%ld",rowFeedback];
            
            [mutableInputs replaceObjectAtIndex:[_delegate.inputArray indexOfObject:_delegate.inputArray[index]] withObject:[NSDictionary dictionaryWithDictionary:mutableInput]];
            _delegate.inputArray = [NSArray arrayWithArray:mutableInputs];
            
            // also set the value in rowTitles so that it is displayed
            [_delegate makeRowColTitles];

            // cmd-click toggles feedback, saves the masks
            //NSInteger colFeedback = ((NSString*)_colTitles[x_index][@"Feedback"]).intValue;
            //NSInteger rowFeedback = ((NSString*)_rowTitles[y_index][@"Feedback"]).intValue;
//            rowFeedback ^= colFeedback; // toggle the masks
//            NSString *rowFeedbackStr = [NSString stringWithFormat:@"%ld",rowFeedback];
//
//            // we need a mutable dictionary to change the entry
//            NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:_rowTitles[y_index]];
//            dict[@"Feedback"] = rowFeedbackStr;
//
//            NSDictionary *dict2 = [[NSDictionary alloc]initWithDictionary:dict];   // NSDictionary for the array
//            [_rowTitles replaceObjectAtIndex:y_index withObject:dict2]; // array of NSDictionary
//            self.rowTitles = self.rowTitles;    // does the save

        }else{
            
            NSString *colTitle = _colTitles[x_index][@"Title"];
            
            if([colTitle hasPrefix:@"Talkback"] || [colTitle hasPrefix:@"Snoop"]){
                matrix[x_index][y_index] = 0;   // talkback, snoop can't be programmed
            }
            else{
                matrix[x_index][y_index] ^= 0x80;   // 0X80 is cross point connected, 0x00 not connected
                // 2.10.02 when linkCompAndPbRouting is set, tie comp and pb
                NSString *key = @"linkCompAndPbRouting";
                NSInteger linkCompAndPb = [[NSUserDefaults standardUserDefaults] integerForKey:key];
                NSString *rowTitle = _rowTitles[y_index][@"Title"];
                
                if(linkCompAndPb){
                    if([rowTitle hasPrefix:@"Playback"]){
                        
                        // this counts on pb, comp being LCR, and comp being right after pb
                        // the general way of doing this would be to search row titles
                        matrix[x_index][y_index + 3] &= 0x7f;
                        matrix[x_index][y_index + 3] |= matrix[x_index][y_index] & 0x80;
                                                
                    }else if([rowTitle hasPrefix:@"Comp"]){
                        
                        matrix[x_index][y_index - 3] &= 0x7f;
                        matrix[x_index][y_index - 3] |= matrix[x_index][y_index] & 0x80;
                    }
                }
            }
        }

        // V2.00.00 save for power on
        if(_delegate){
            [_delegate saveMatrixArrayForMemory:_delegate.memoryTag];
            
        }
        [self setCrosspoint:x_index :y_index :matrix[x_index][y_index] :true];
    }
    
    [self invalidateRect];
    
}
- (void)mouseMoved:(NSEvent *)theEvent {
    
    NSPoint thePoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    
    // calc the x,y index
    int x_index = (int)((thePoint.x) / MATRIX_CELL_SIZE);
    int y_index = (int)_rowTitles.count - (int)((thePoint.y) / MATRIX_CELL_SIZE) - 1;

    NSLog(@"mouseMoved x,y: %d %d",x_index,y_index);
    
    // set the tool tip to show the hover location
    NSString *tooltip = [NSString stringWithFormat:@"row: %d column: %d",y_index,x_index];
    [self setToolTip:tooltip];  // TODO timeout
}
-(void)clearCrosspoints{
    
    for(int x = 0; x < _colTitles.count; x++){
        for(int y = 0; y < _rowTitles.count; y++){
            
            [self setCrosspoint:x :y :MAX_FADER_ATTENUATION :true];
        }
    }    
}
-(void)setCrosspoints:(NSInteger) gain{
    
    for(int x = 0; x < _colTitles.count; x++){
        for(int y = 0; y < _rowTitles.count; y++){
            
            [self setCrosspoint:x :y :gain :true];
        }
    }
    
}
-(void)crossPointsOff{
    
    for(int x = 0; x < _colTitles.count; x++){
        for(int y = 0; y < _rowTitles.count; y++){
            
            matrix[x][y] &= 0x7f;   // top bit off
        }
    }

    NSRect rect;
    rect.origin = NSMakePoint(0, 0);
    rect.size = _backImage.size;
    
    [self setNeedsDisplayInRect:rect];  // might as well redraw the whole thing, drawing speed is not critical
}
-(void)setCrosspoint:(NSArray<NSDictionary*>*)crosspointArray :(NSInteger) gain :(bool)force{
    
    for(NSDictionary *dict in crosspointArray){
        
        int x = (int)[dict[@"x"] integerValue];
        int y = (int)[dict[@"y"] integerValue];
        int trim = (int)[dict[@"trim"] doubleValue];
        
        NSInteger trimmedGain = gain;   // copy to modify
        
        if(trim != 0.0){
            
            trimmedGain = [_delegate addDbToFader:trim :gain];
        }
        
        [self setCrosspoint:x :y :trimmedGain :force];
        
    }
    
}

-(void)setCrosspoint:(int)x :(int)y :(NSInteger) gain :(bool)force{
    
    // 2.10.02 dim is done on outputs, not crosspoints
//    double dimDB = [[NSUserDefaults standardUserDefaults] doubleForKey:@"dimDB"];
    
    gain &= 0x7f;   // turn off top bit

    // if not a talkback row, dim
    // 2.10.00 talkback a,b have different sets of dims
    if(!_rowTitles || !_colTitles){
        return; // no row titles yet
    }
    int k = 0;
    NSString *rowTitle = _rowTitles[y][@"Title"];
    NSDictionary *inputDictionary;
    
    if(_delegate && _delegate.inputArray){
        for(;k < _delegate.inputArray.count; k++){
            NSString *inputArrayName = _delegate.inputArray[k][@"Name"];
            
            if([rowTitle hasPrefix:inputArrayName]){
                inputDictionary = _delegate.inputArray[k];
                break;
            }
        }
    }

    Byte oldValue = matrix[x][y];
    matrix[x][y] = gain | (oldValue & 0x80);   // keep top bit
    
    unsigned char enable = oldValue & 0x80;
    oldValue &= 0x7f;   // the gain part
    
    // only send enabled crosspoints
    // toggling crosspoint off sends max attenuation
    if((enable && (oldValue != gain)) || force){
        
        NSString *channel = _colTitles[x][@"SelectChannel"];
        NSString *controlChange = _colTitles[x][@"SelectControlChange"];
        NSString *inputChannel = _rowTitles[y][@"Channel"];
        NSString *inputControlChange = _rowTitles[y][@"ControlChange"];
        NSInteger inputFeedbackMask = ((NSString*)_rowTitles[y][FEEDBACK_KEY]).integerValue;   // mask
        NSInteger outputFeedbackMask = ((NSString*)_colTitles[x][FEEDBACK_KEY]).integerValue;  // mask

        // mute particular rows to cols by having a 'feedback' mask that matches
        // 'enable' term is to set gain to 0 when crosspoint is turned off
        if((inputFeedbackMask & outputFeedbackMask) != 0 || !enable){
            gain = 0;
        }
        
        NSString *str = [NSString stringWithFormat:@"%@ %@ 0 %@ %@ %ld",channel,controlChange,inputChannel,inputControlChange,(long)gain];
        
        AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
        [delegate sendUfxString:str];
    }
}
-(NSData*)getByteMatrix{

    return [NSData dataWithBytes:matrix length:sizeof(matrix)];
    
}
-(void)setByteMatrix:(NSData*)value{
        
    memcpy(matrix, [value bytes], sizeof(matrix) < value.length ? sizeof(matrix) : value.length);
    
    NSRect rect;
    rect.origin = NSMakePoint(0, 0);
    rect.size = _backImage.size;
    
    [self setNeedsDisplayInRect:rect];  // might as well redraw the whole thing, drawing speed is not critical
    
    [self clearCrosspoints];        // 2.00.00
    [_delegate refreshCrosspoints]; // 2.00.00
}
-(void)invalidateRect{
    
    NSRect rect;
    rect.origin = NSMakePoint(0, 0);
    rect.size = NSMakeSize(self.colTitles.count * MATRIX_CELL_SIZE, self.rowTitles.count * MATRIX_CELL_SIZE);//_backImage.size;
    
    [self drawBackImage:rect.size];
    [self setNeedsDisplayInRect:rect];  // might as well redraw the whole thing, drawing speed is not critical
    
}
NSTimer *autoSlateTimer;
-(void)autoSlateTimerService{
    
    [self autoSlate:false]; // auto slate off
    
}
// a change for github
-(void)autoSlate:(bool)on{
    
    // 2.10.02 08/10/23 added a cc for auto slate, maybe free up
    // the dedicated outputs, but today both methods are in use
    unsigned char msg[] = {0xb0,CC_AUTOSLATE,on ? 127 : 0};
    AleDelegate *aleDelegate = (AleDelegate*)[NSApp delegate];
    
    [aleDelegate.lpMini.accMidi.midiClient midiTx: [NSData dataWithBytes:msg length:3]];
    
//    [aleDelegate txToMidiAccessory:[NSData dataWithBytes:msg length:3]];
//    [aleDelegate.accClient midiTx:[NSData dataWithBytes:msg length:3]];
    
    if(autoSlateTimer && autoSlateTimer.isValid){
        [autoSlateTimer invalidate];
    }
    
    // Evan wants message to repeat, like other acc messages
    // autoslate times out 1 second before the loop start
    // and repeats every 5 seconds when off
    
    NSTimeInterval ti =  on ? [self.tcc tcToTimeInterval:aleDelegate.editorWindowController.preroll :TCTYPE_30] - 1.00 : 5.00;
        
    autoSlateTimer = [NSTimer scheduledTimerWithTimeInterval:ti target:self selector:@selector(autoSlateTimerService) userInfo:nil repeats:true];

}
// MARK: ------- setters/getters ---------
-(void)setRowView:(RowView *)rowView{
    _rowView = rowView;
    
    // case where _rowTitles is set first
    if(_rowTitles){
        [_rowView drawBackImage:_rowTitles :true];
        [self drawBackImage:self.frame.size];
    }
    
}
-(RowView *)rowView{
    return _rowView;
}
-(void)setColView:(RowView *)colView{
    _colView = colView;
    
    // case where _colTitles is set first
    if(_colTitles){
        [_colView drawBackImage: _colTitles :false];
        [self drawBackImage:self.frame.size];
    }
}
-(RowView *)colView{
    return _colView;
}
-(void)setRowTitles:(NSMutableArray *)rowTitles{
    _rowTitles = rowTitles;
    
    // case where _rowView is set first
    if(_rowView){
        [_rowView drawBackImage:_rowTitles :true];
        [self drawBackImage:self.frame.size];

    }
    
}
-(NSMutableArray*)rowTitles{
    return _rowTitles;
}
-(void)setColTitles:(NSMutableArray *)colTitles{
    _colTitles = colTitles;
    
    // case where _colView is set first
    if(_colView){
        [_colView drawBackImage: _colTitles :false];
        [self drawBackImage:self.frame.size];
    }
    
//    NSKeyedArchiver *arch = [[NSKeyedArchiver alloc] initRequiringSecureCoding:false];
//    [arch encodeObject:_colTitles forKey:COL_TITLE_KEY];
//    [arch finishEncoding];
//    [[NSUserDefaults standardUserDefaults] setObject:arch.encodedData forKey:COL_TITLE_KEY];
    
}
-(NSMutableArray*)colTitles{
    return _colTitles;
}

@end
