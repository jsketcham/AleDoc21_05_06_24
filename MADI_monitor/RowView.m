//
//  RowView.m
//  Ale_v3xx
//
//  Created by James Ketcham on 4/26/14.
//  Copyright (c) 2014 WB ADR. All rights reserved.
//

#import "RowView.h"
#import "MatrixWindowController.h"

@implementation RowView
@synthesize backImage = _backImage;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
//    [super drawRect:dirtyRect];
    
    // Drawing code here.
    // replace the background
    
    [_backImage drawInRect:dirtyRect fromRect:dirtyRect operation:NSCompositingOperationCopy fraction:1.0];
}
-(void)drawBackImage:(NSArray*)titles :(bool) isRow{
    // titles is an array of dictionaries
    NSAffineTransform *rotate = [[NSAffineTransform alloc] init];
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    
    NSBezierPath *path = [[NSBezierPath alloc] init];
    [path setLineWidth:1.0];
    
    NSRect rect;
    
    if(isRow){
        
        rect = NSMakeRect(0, 0, self.frame.size.width, MATRIX_CELL_SIZE * titles.count);
        
    }else{
        
        rect = NSMakeRect(0, 0, MATRIX_CELL_SIZE * titles.count, self.frame.size.width);

    }

    [path appendBezierPathWithRect:rect];
    
    [self setBackImage:[[NSImage alloc] initWithSize:rect.size]];
    [[self backImage] lockFocus];
    [context saveGraphicsState];

    [[NSColor whiteColor] set];
    [path fill];

    // underlines
    
    NSBezierPath *grid = [[NSBezierPath alloc] init];
    [grid setLineWidth:1.0];
    [grid appendBezierPathWithRect:rect];
    
    if(isRow){
        
        for(int i = 0; i < titles.count; i++){
            
            [grid moveToPoint:NSMakePoint(0,i * MATRIX_CELL_SIZE)];
            [grid lineToPoint:NSMakePoint(rect.size.width,i * MATRIX_CELL_SIZE)]; // black line above change in
        }

    }else{
        
        for(int i = 0; i < titles.count; i++){
            
            [grid moveToPoint:NSMakePoint(i * MATRIX_CELL_SIZE, 0)];
            [grid lineToPoint:NSMakePoint(i * MATRIX_CELL_SIZE, rect.size.height)]; // black line above change in
        }
    }
    [[NSColor blackColor] set];
    [grid stroke];
    
    // text
    NSBezierPath *text = [[NSBezierPath alloc] init];
    [text setLineWidth:1.0];
    [text appendBezierPathWithRect:rect];
    
    if(!isRow){
        [rotate translateXBy:MATRIX_CELL_SIZE yBy:0];
        [rotate rotateByDegrees:90];
        [rotate concat];
    }
    
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor whiteColor],NSBackgroundColorAttributeName, nil];//nil; // TODO same attributes as NSAttributedString
    
    NSPoint textPoint = NSMakePoint(5.0,  1.0);
    
    if(isRow){
        textPoint.y += MATRIX_CELL_SIZE * (titles.count - 1);   // from top down
    }
    
    for(int i = 0; i < titles.count; i++){
        
        [titles[i][@"Title"] drawAtPoint:textPoint withAttributes:attributes];
        textPoint.y -= MATRIX_CELL_SIZE;
    }
    // text strokes
    [[NSColor blackColor] set];
    [text stroke];

    [[self backImage] unlockFocus];
    [context restoreGraphicsState];

    // invalidate rect

    rect = self.frame;
    rect.origin = NSMakePoint(0, 0);
    [self setNeedsDisplayInRect:rect];
    
}

@end
