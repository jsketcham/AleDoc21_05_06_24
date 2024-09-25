//
//  TCFormatter.h
//  VM15
//
//  Created by Barb Ketcham on 5/2/12.
//  Copyright (c) 2012 Endpoint Technology LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

//Byte tc: 1;
//Byte ft_fr: 1;
//Byte bar_beat: 1;
@class TCFormatter;
@protocol TCFormatterDelegate

-(NSString*)getTcStartForObject:(id)obj;
-(NSString*)getTcStart; // each doc has its own
-(NSInteger)getDisplayFormat;
-(int)getTcType;

@end
//
//enum{
//    
//    DISPLAY_FMT_TC,
//    DISPLAY_FMT_FT,
//    DISPLAY_FMT_BAR_BEAT
//};
//
//@interface TCFormatter : NSFormatter{
//    bool showZero;
//}
//@property id delegate;
//
////@property NSInteger displayFmt;
//
//- (NSString *)stringForObjectValue:(id)anObject;
//- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error;
//
//-(void)showZeroValue:(BOOL)sz;
//-(NSString*)tcForString:(NSString*)digits;
//
//-(id)initAsPreroll;
//-(NSString*)tcToFeet:(NSString*)tc;
//-(NSString*)tcToTc:(NSString*)tc;
//-(NSString*)ctrToObjectValue:(NSString*)ctr;
//@end

#pragma mark -
#pragma mark ----------------- no calcs, just display formatting ------------

enum{
    
    DISPLAY_FMT_NONE,       // 2.10.02 added so that zone bits[0:1] decode
    DISPLAY_FMT_TC,
    DISPLAY_FMT_FT
};

@interface TCFormatter : NSFormatter

@property id delegate;

-(NSString*)formatAsFeet:(NSString*)string;
-(NSString*)formatAsTc:(NSString*)string;
-(NSString*)tcForString:(NSString*)digits;
-(NSString*)tcForPreroll:(NSString*)digits;
@end

