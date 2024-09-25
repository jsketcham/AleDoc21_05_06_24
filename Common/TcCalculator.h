//
//  TcCalculator.h
//  VM15
//
//  Created by Barb Ketcham on 1/6/12.
//  Copyright 2012 Endpoint Technology LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <regex.h>

#define DF_FRS_HR   (2*9*6)
#define FRS_1HR_24 (24*60*60)
#define FRS_1HR_25 (25*60*60)
#define FRS_1HR_DF (30*60*60 - DF_FRS_HR)
#define FRS_1HR_30 (30*60*60)

#define FRS_12HRS_24 (FRS_1HR_24*12)
#define FRS_12HRS_25 (FRS_1HR_25*12)
#define FRS_12HRS_DF (FRS_1HR_DF*12)
#define FRS_12HRS_30 (FRS_1HR_30*12)

#define FRS_24HRS_24 (FRS_1HR_24*24)
#define FRS_24HRS_25 (FRS_1HR_25*24)
#define FRS_24HRS_DF (FRS_1HR_DF*24)
#define FRS_24HRS_30 (FRS_1HR_30*24)

enum{
    TCTYPE_24,
    TCTYPE_25,
    TCTYPE_DF,
    TCTYPE_30
};

@protocol TcCalculatorDelegate

-(int)getTcType;
-(NSString*)getTcStart;
-(bool)ignoreTcStartHours;

@end
@interface TcCalculator : NSObject {
    
    regex_t rt;
    regex_t ft;
    regmatch_t match;
    
@private
    
}
@property id delegate;

-(int) tcToBinary:(NSString*)tc withType:(int)tcType;
-(NSString*) binaryToTc:(int) frames withType:(int)tcType;
-(NSString*) subtractTc:(NSString*) tcA fromTc:(NSString*) tcB withType:(int)tcType;
-(NSString*) addTc:(NSString*) tcA toTc:(NSString*) tcB withType:(int)tcType;
-(BOOL) isTc:(NSString*) tc;
-(NSString*) findFirstTc:(NSString*) txt;
-(int) hrsToBinary:(NSString*) tc;
-(NSComparisonResult) compareTc:(NSString*) tcA fromTc:(NSString*) tcB withType:(int)tcType;
-(NSData*)tcToData:(NSString*)tc;
-(NSString*) timeIntervalToTc:(double)interval withType:(NSInteger) tcType;
-(double)framesToTimeInterval:(NSInteger)frames withType:(NSInteger)tcType;
-(double)subtractTcToTimeInterval:(NSString*) tcA fromTc:(NSString*) tcB withType:(int)tcType;
-(double)tcToTimeInterval:(NSString*) tc :(int)tcType;

-(BOOL) isFtFr:(NSString*) tc;
-(int) ftToBinary:(NSString*)ftFr;
-(NSString*)binaryToFt:(int)frames;

// a sensible addition 1/22/16
-(NSString*)ftToTc:(NSString*)ftFr;
-(NSString*)tcToFt:(NSString*)tc;
-(NSString*) addBinary:(int)frs toTc:(NSString*) tc withType:(int)tcType;

@end

