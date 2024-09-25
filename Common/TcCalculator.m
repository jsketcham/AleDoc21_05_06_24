//
//  TcCalculator.m
//  VM15
//
//  Created by Barb Ketcham on 1/6/12.
//  Copyright 2012 Endpoint Technology LLC. All rights reserved.
//

#import "TcCalculator.h"
#import <Cocoa/Cocoa.h>


@implementation TcCalculator

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
        // we compile the RE (regular expression) once, doing it every time causes massive malloc buildup
        // we ran into a case at WB ADR 1 where there were '.' in the timecode
        // 12/3/19 PT has ';' in DF timecode before the frames
        (void)regcomp(&rt, "(([2][0-3])|([0-1][0-9]))(\\:|\\.)[0-5][0-9](\\:|\\.)[0-5][0-9](\\:|\\.|\\;)[0-2][0-9]", REG_EXTENDED);
        // https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man7/re_format.7.html#//apple_ref/doc/man/7/re_format
        (void)regcomp(&ft, "[0-9]+\\+(([1][0-5])|([0][0-9]))", REG_EXTENDED);   // Protools feet/frames

    }
    
    return self;
}

//- (void)dealloc
//{
//    [super dealloc];
//}
-(int) hrsToBinary:(NSString*) tc
{
    NSArray *list;
    int hh;
    
    if(![self isTc:tc]) return 0;
    
//    list = [tc componentsSeparatedByString:@":"];
        // componentsSeparatedByCharactersInSet 12/3/19 PT has a ';' before frames in DF
        NSCharacterSet *cs = [NSCharacterSet characterSetWithCharactersInString:@".:;"];
    //    list = [tc componentsSeparatedByString:@":"];
        list = [tc componentsSeparatedByCharactersInSet:cs];

    if([list count] != 4) return 0;
    
    hh = [[list objectAtIndex:0] intValue];//list.at(0).toUInt();
    
    return hh;
    
}
-(NSData*)tcToData:(NSString*)tc{
    
    NSArray *list;
    Byte tcBytes[5];
    
    if(![self isTc:tc]) return 0;
    
//    list = [tc componentsSeparatedByString:@":"];
        // componentsSeparatedByCharactersInSet 12/3/19 PT has a ';' before frames in DF
        NSCharacterSet *cs = [NSCharacterSet characterSetWithCharactersInString:@".:;"];
    //    list = [tc componentsSeparatedByString:@":"];
        list = [tc componentsSeparatedByCharactersInSet:cs];

    if([list count] != 4) return 0;
    
    tcBytes[0] = (Byte)[[list objectAtIndex:0] intValue];//list.at(0).toUInt();
    tcBytes[1] = (Byte)[[list objectAtIndex:1] intValue];
    tcBytes[2] = (Byte)[[list objectAtIndex:2] intValue];
    tcBytes[3] = (Byte)[[list objectAtIndex:3] intValue];
    tcBytes[4] = 0; // subframes, zero for now
    
    NSData *tcData = [NSData dataWithBytes:tcBytes length:4];
    
    return tcData;
}
-(int) ftToBinary:(NSString*)ftFr{
    
    NSArray *list;
    
    if(![self isFtFr:ftFr]) return 0;
    
    list = [ftFr componentsSeparatedByString:@"+"];
    if([list count] != 2) return 0;
    
    @try {
        
        int frames = [list[0] intValue] * 16;
        frames += [list[1] intValue];
        
        return frames;
        
    }
    
    @catch (NSException *exception) {
        
    }
    
    return 0;
}
-(int) tcToBinary:(NSString*) tc withType:(int) tcType
{
    int hh,mm,ss,ff;
    int fps;
    int frames;
    NSArray *list;
 
    if([self isFtFr:tc]) return [self ftToBinary:tc];

    if(![self isTc:tc]) return 0;
    
    // componentsSeparatedByCharactersInSet 12/3/19 PT has a ';' before frames in DF
    NSCharacterSet *cs = [NSCharacterSet characterSetWithCharactersInString:@".:;"];
//    list = [tc componentsSeparatedByString:@":"];
    list = [tc componentsSeparatedByCharactersInSet:cs];
    if([list count] != 4) return 0;
    
    hh = [[list objectAtIndex:0] intValue];//list.at(0).toUInt();
    mm = [[list objectAtIndex:1] intValue];
    ss = [[list objectAtIndex:2] intValue];
    ff = [[list objectAtIndex:3] intValue];
    
    switch(tcType)
    {
        case 0: fps = 24; break;
        case 1: fps = 25; break;
        default: fps = 30; break;
    }
    
    frames = ff;
    frames += ss * fps;
    frames += mm * fps * 60;
    frames += hh * fps * 60 * 60;
    
    // df adjustment
    
    if(tcType == 2)
    {
        frames -= hh * 108; // extra frames per hour
        frames -= (mm / 10) * 18;    // extra frames per 10 minutes
        frames -= (mm % 10) * 2;    // extra frames per minute
    }
    
    return frames;
}
-(int)frsModulo24Hrs:(int) frames withType:(int)tcType{
    
    int modulo; // default is FRS_24HRS_30
    
    switch(tcType)
    {
        case 0: modulo = FRS_24HRS_24; break;
        case 1: modulo = FRS_24HRS_25; break;
        case 2: modulo = FRS_24HRS_DF; break;
        default: modulo = FRS_24HRS_30; break;
    }
    
    frames %= modulo;
    
    if(frames < 0){
        frames += modulo;
    }
    
//    while(frames < 0){
//        frames += modulo;    // 2.00.00 must be non-negative
//    }
//    frames %= modulo;
    
    return frames;

}
-(NSString*) binaryToTc:(int) frames withType:(int)tcType
{
    int fps;
    ushort hh,mm,ss,ff;
//    char buffer[32];
    
    //
    
    switch(tcType)
    {
        case 0: fps = 24; break;
        case 1: fps = 25; break;
        default: fps = 30; break;
    }
    
    frames = [self frsModulo24Hrs:frames withType:tcType];

    if(tcType == 2)
    {
        hh = frames / 107892;
        frames %= 107892;
        mm = 10 * (frames / 17982);   // 10's of minutes, parends added Evan 11/22/2019
        frames %= 17982;
        
        // 1800,1798,1798....
//        for(;frames > 1799;frames -=1798){mm += 1;}        
        frames -= 2;
        mm += frames / 1798;
        frames %= 1798;
        frames += 2;
        
        ss = frames / 30;
        ff = frames % 30;
    } else
    {
        hh = frames / (fps * 60 * 60);
        frames %= fps * 60 * 60;
        mm = frames / (fps * 60);
        frames %= fps * 60;
        ss = frames / fps;
        ff = frames % fps;
    }
    
    // 12/3/19 DF frs delimiter is ';'
    unsigned char frsDelimiter = tcType == TCTYPE_DF ? ';' : ':';
    
    NSString *str = [NSString stringWithFormat:@"%02d:%02d:%02d%c%02d",
    hh,mm,ss,frsDelimiter,ff];
//    NSLog(@"%@",str);
    
//    sprintf(buffer,"%02d:%02d:%02d%c%02d",hh,mm,ss,frsDelimiter,ff);
//    NSLog(@"%02d:%02d:%02d:%02d",hh,mm,ss,ff);
    
    return str;//[NSString stringWithUTF8String:buffer];
}
-(NSString*) addBinary:(int)frs toTc:(NSString*) tc withType:(int)tcType{
    
    bool isFtFr = [self isFtFr:tc];
    
    frs = frs + [self tcToBinary:tc  withType:tcType];
    
    return isFtFr ? [self binaryToFt:frs] : [self binaryToTc:frs withType:tcType];
}
-(NSString*) subtractTc:(NSString*) tcA fromTc:(NSString*) tcB withType:(int)tcType
{
    // if tcB is ft/fr, return ft/fr
    bool isFtFr = [self isFtFr:tcB];
    
    int aFrames = [self tcToBinary:tcA withType:tcType];
    int bFrames = [self tcToBinary:tcB  withType:tcType];
    bFrames -= aFrames;
    
    bFrames = [self frsModulo24Hrs:bFrames withType:tcType];

    return isFtFr ? [self binaryToFt:bFrames] : [self binaryToTc:bFrames withType:tcType];
}
-(NSString*) addTc:(NSString*) tcA toTc:(NSString*) tcB withType:(int)tcType
{
    // if tcB is ft/fr, return ft/fr
    bool isFtFr = [self isFtFr:tcB];
    
    int aFrames = [self tcToBinary:tcA withType:tcType];
    int bFrames = [self tcToBinary:tcB  withType:tcType];
    bFrames += aFrames;
    
    bFrames = [self frsModulo24Hrs:bFrames withType:tcType];

    
    return isFtFr ? [self binaryToFt:bFrames] : [self binaryToTc:bFrames withType:tcType];
}
//-(NSComparisonResult) compareTc:(NSString*) tcA fromTc:(NSString*) tcB withType:(int)tcType
//{
//
//    int aFrames = [self tcToBinary:tcA withType:tcType];    // note that tcToBinary converts ft/fr correctly
//    int bFrames = [self tcToBinary:tcB  withType:tcType];
//
//    int frs_12hr;
//
//    switch(tcType){
//
//        default: frs_12hr = [self ignoreTcStartHours] ? (FRS_1HR_24/2) : FRS_12HRS_24; break;
//        case TCTYPE_25: frs_12hr = [self ignoreTcStartHours] ? (FRS_1HR_25/2)  : FRS_12HRS_25; break;
//        case TCTYPE_DF: frs_12hr = [self ignoreTcStartHours] ? (FRS_1HR_DF/2)  : FRS_12HRS_DF; break;
//        case TCTYPE_30: frs_12hr = [self ignoreTcStartHours] ? (FRS_1HR_30/2)  : FRS_12HRS_30; break;
//    }
//
//    aFrames -= bFrames;
//
//    while (aFrames > frs_12hr) aFrames -= 2 * frs_12hr;
//    while (aFrames < -frs_12hr) aFrames += 2 * frs_12hr;
//
//    if (aFrames < 0)
//        return NSOrderedAscending;
//    else if (aFrames > 0)
//        return NSOrderedDescending;
//    else
//        return NSOrderedSame;
//
//}

-(NSComparisonResult) compareTc:(NSString*) tcA fromTc:(NSString*) tcB withType:(int)tcType
{
  // arithmetically the same as above
    if(!([self isTc:tcA] && [self isTc:tcB])){
        // not comparing 2 tc's 
        return NSOrderedAscending;
    }
    
    int aFrames = [self tcToBinary:tcA withType:tcType];    // note that tcToBinary converts ft/fr correctly
    int bFrames = [self tcToBinary:tcB  withType:tcType];

    int modulus;

    switch(tcType){

        default: modulus = [self ignoreTcStartHours] ? (FRS_1HR_24) : FRS_24HRS_24; break;
        case TCTYPE_25: modulus = [self ignoreTcStartHours] ? (FRS_1HR_25) : FRS_24HRS_25; break;
        case TCTYPE_DF: modulus = [self ignoreTcStartHours] ? (FRS_1HR_DF) : FRS_24HRS_DF; break;
        case TCTYPE_30: modulus = [self ignoreTcStartHours] ? (FRS_1HR_30) : FRS_24HRS_30; break;
    }

    aFrames %= modulus; // already 24 hr modulus, this is for 1 hr modulus
    bFrames %= modulus; // already 24 hr modulus, this is for 1 hr modulus

    aFrames -= bFrames;

    if(aFrames < 0 && aFrames < (-modulus / 2)){
        aFrames += modulus;

    } // 12:00:00:00 to 23:59:59:xx
    else if(aFrames > 0 && aFrames > (modulus / 2)){
        aFrames -= modulus;

    } // 12:00:00:00 to 23:59:59:xx

    if (aFrames < 0)
        return NSOrderedAscending;
    else if (aFrames > 0)
        return NSOrderedDescending;
    else
        return NSOrderedSame;

}

-(BOOL) isFtFr:(NSString*) tc
{
    
    //    regex_t rt;
    //    regmatch_t match;
    int status;
    //    (void)regcomp(&rt, "(([2][0-3])|([0-1][0-9]))\\:[0-5][0-9]\\:[0-5][0-9]\\:[0-2][0-9]", REG_EXTENDED);
    
    if(tc == nil) return false;
    
    status = regexec(&ft, [tc UTF8String], 1, &match, 0);//printf("%d %d %d\n",status,(int)match.rm_so,(int)match.rm_eo);
    
    return (status == 0) ? true : false;
}

-(BOOL) isTc:(NSString*) tc
{
    
//    regex_t rt;
//    regmatch_t match;
    int status;
//    (void)regcomp(&rt, "(([2][0-3])|([0-1][0-9]))\\:[0-5][0-9]\\:[0-5][0-9]\\:[0-2][0-9]", REG_EXTENDED);
    
    if(tc == nil) return false;
    
    status = regexec(&rt, [tc UTF8String], 1, &match, 0);//printf("%d %d %d\n",status,(int)match.rm_so,(int)match.rm_eo);
    
    int len = (int)[[tc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length];
    
    return (status == 0 && len == 11) ? true : false;
}

-(NSString*) findFirstTc:(NSString*) txt
{
    // using Posix regex.h
    // http://www.regular-expressions.info/examples.html
    // read: man regex
//    regex_t rt;
//    regmatch_t match;
    
//    int status = regcomp(&rt, "(([2][0-3])|([0-1][0-9]))\\:[0-5][0-9]\\:[0-5][0-9]\\:[0-2][0-9]", REG_EXTENDED);
//    
//    if(status != 0)
//    {
//        printf("regcomp failed\n");
//        return @"";
//    }
    
//    regcomp(&rt, "(([2][0-3])|([0-1][0-9]))\\:[0-5][0-9]\\:[0-5][0-9]\\:[0-2][0-9]", REG_EXTENDED);
    int status = regexec(&rt, [txt UTF8String], 1, &match, 0);
    //printf("%d %d %d\n",status,(int)match.rm_so,(int)match.rm_eo);
    
    if(status == 0) // found a match...
    {
        if(match.rm_so >= 0)
        {
            NSRange range;
            range.location = (NSUInteger)match.rm_so;
            range.length = 11;  // hh:mm:ss:ff
            return [txt substringWithRange:range];
        }
        
    }
    
    return nil; // no match
    
}
-(NSString*) timeIntervalToTc:(double)interval withType:(NSInteger) tcType{
    
    // interval to frames
    
    switch (tcType) {
            
        case 0: interval *= 24; break;
        case 1: interval *= 25; break;
        default: interval *= 30; break;
    }
    
    interval += .5;     // rounding
    
    int frames = (int)interval;
    
    return [self binaryToTc:frames withType:(int)tcType];
}
-(double)framesToTimeInterval:(NSInteger)frames withType:(NSInteger)tcType{
    
    double d = 0.0333333333;  // assume 30 fps
    
    switch (tcType) {
            
        case 0: d = 0.0416666666; break;
        case 1: d = 0.40; break;
        default: break;
    }
   
    return d * (double)frames;  // result in seconds
}
-(double)tcToTimeInterval:(NSString*) tc :(int)tcType{
    
    int frames = [self tcToBinary:tc withType:tcType];
    return [self framesToTimeInterval:frames withType:tcType];
}
-(double)subtractTcToTimeInterval:(NSString*) tcA fromTc:(NSString*) tcB withType:(int)tcType{
    
    int frames = [self tcToBinary:[self subtractTc:tcA fromTc:tcB withType:tcType] withType:tcType];    
    return [self framesToTimeInterval:frames withType:tcType];
    
}
-(NSString*)binaryToFt:(int)frames{
    
    while (frames < 0) frames += FRS_24HRS_24;
    while (frames >= FRS_24HRS_24) frames -= FRS_24HRS_24;
    
    int feet = frames / 16;
    int frs = frames % 16;
    
    return [NSString stringWithFormat:@"%d+%02d",feet,frs];
}
-(int)getTcType{
    
    if(_delegate) return [_delegate getTcType];
    
    id delegate = [NSApp delegate];
    
    if([delegate respondsToSelector:@selector(getTcType)]){
        
        return [delegate getTcType];
        
    }
    
    return  TCTYPE_24;  // default
}
-(NSString*)getTcStart{
    
    if(_delegate) return [_delegate getTcStart];
    
    id delegate = [NSApp delegate];
    
    if([delegate respondsToSelector:@selector(getTcStart)]){
        
        return [delegate getTcStart];
        
    }
    
    return @"01:00:00:00";  // default start
}
-(NSString*)tcToFt:(NSString*)tc{
    
    if(![self isTc:tc]) return tc; // failed
    
    NSInteger frs = [self tcToBinary:tc withType:[self getTcType]];
    NSInteger frs_10s_of_minutes = frs % 18000;
    NSInteger frs_minutes = frs % 1800;
    NSInteger frs_df = frs - (2 * frs_minutes) - (18 * frs_10s_of_minutes);
    
    if(![self ignoreTcStartHours]) frs -= [self tcToBinary:[self getTcStart] withType:[self getTcType]];
    else{
        
        NSInteger fps = 3600;
        
        switch ([self getTcType]) {
            case TCTYPE_24: fps *= 24; break;
            case TCTYPE_25: frs *= 25; break;
            case TCTYPE_DF: frs_df *= 30; break;
            case TCTYPE_30: frs *= 30; break;
                
            default:
                break;
        }
        
        frs %= fps;
        
    }
    
    frs *= 24;  // FPS for film
    frs_df *= 24;
    
    switch ([self getTcType]) {
        case TCTYPE_24: frs /= 24; break;
        case TCTYPE_25: frs /= 25; break;
        case TCTYPE_DF:frs = frs_df/30; break;
        case TCTYPE_30: frs /= 30; break;
            
        default:
            break;
    }
    
    NSString *feet = [self binaryToFt:(int)frs];
    
    return feet;
}
//-(NSString*)ftToTc:(NSString*)ftFr{
//    
//    if(![self isFtFr:ftFr]) return ftFr; // failed
//    
//    int frs = [self ftToBinary:ftFr];
//    if(![self ignoreTcStartHours]) frs += [self tcToBinary:[self getTcStart] withType:[self getTcType]];
//    NSString *tc = [self binaryToTc:frs withType:[self getTcType]];
//    
//    return tc;
//
//}
-(NSString*)ftToTc:(NSString*)ftFr{
    
    if(![self isFtFr:ftFr]) return ftFr; // failed
    
    // 2.10.02, don't have ignoreTcStartHours thought out
    NSString *start = [self getTcStart];
    NSInteger startFrs = [self tcToBinary:start withType:[self getTcType]];
    NSLog(@"start %@ startFrs %ld",start,startFrs);

    int frs = [self ftToBinary:ftFr];
    frs += startFrs;
//    if(![self ignoreTcStartHours]) frs += [self tcToBinary:[self getTcStart] withType:[self getTcType]];
    NSString *tc = [self binaryToTc:frs withType:[self getTcType]];
    
    return tc;

}

-(bool)ignoreTcStartHours{
    
    if(_delegate) return [_delegate ignoreTcStartHours];
    
    id delegate = [NSApp delegate];
    
    if([delegate respondsToSelector:@selector(ignoreTcStartHours)]){
        
        return [delegate ignoreTcStartHours];
        
    }
    
    return false;    // default is to NOT ignore TC start hours, ADR3 Tommy 1/18/17
    
}
-(NSString*)tcForString:(NSString*)str{
    return nil;
}

@end
