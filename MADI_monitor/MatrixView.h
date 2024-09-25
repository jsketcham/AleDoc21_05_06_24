//
//  MatrixView.h
//  Ale_v3xx
//
//  Created by James Ketcham on 4/25/14.
//  Copyright (c) 2014 WB ADR. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// 2.00.00 moved from ChannelNodeData.h
#define NAME_KEY @"Name"
#define CHANNEL_KEY @"Channel"
#define BUTTON_KEY @"Buttons"
#define FEEDBACK_KEY @"Feedback"
#define CHILDREN_KEY @"Children"
#define DIM_A_KEY @"Dim A"
#define DIM_B_KEY @"Dim B"
#define DIM_C_KEY @"Dim C"
#define DIM_D_KEY @"Dim D"

//#define ROW_TITLE_KEY @"rowTitleKey"
//#define COL_TITLE_KEY @"colTitleKey"

//#define OVERLAY_KEY @"Overlay"
//#define MASK_KEY @"Mask"
//#define PARENT_KEY @"Parent"

@class MatrixView;
@class LpMini;

// size of 64x64 matrix
#define MATRIX_VIEW_RECT 768
// 2.00.00, 32 X 32 maximum matrix, size set by MatrixWindowController numRows, numCols
// see AleDoc/supporting files/inputs.plist (rows) and outputs.plist (cols)
// Item/Children/'ufxDictionaryItem' and 'ufxDictionaryItem' map the ins and outs

#define MATRIX_CELL_SIZE 16     // size of matrix cells
#define MAX_ROWS_COLS 32
@class MatrixWindowController;
@class RowView;

@interface MatrixView : NSView{
    Byte matrix[MAX_ROWS_COLS][MAX_ROWS_COLS]; 
}
@property (strong,readwrite) NSImage *backImage;
@property MatrixWindowController *delegate;

@property (weak) IBOutlet RowView *colView;
@property (weak) IBOutlet RowView *rowView;

//@property NSSize frameSize;
@property NSMutableArray<NSDictionary*> *rowTitles;
@property NSMutableArray<NSDictionary*> *colTitles;

-(void)setCrosspoint:(int)x :(int)y :(NSInteger) gain :(bool)force;

-(NSData*)getByteMatrix;
-(void)setByteMatrix:(NSData*)value;
-(void)invalidateRect;
//-(void)autoSlate;
-(void)autoSlate:(bool)on;
-(void)clearCrosspoints;    // 2.00.00
-(void)setCrosspoints:(NSInteger) gain; //2.10.02
-(void)setCrosspoint:(NSArray<NSDictionary*>*)crosspointArray :(NSInteger) gain :(bool)force;   // 2.00.00
-(void)crossPointsOff;  // 2.10.02

@end
